# Cursor Instrukcija — PB tab "Saveti" (Engineering Tips / Baza znanja)

Dodaje se novi tab **Saveti** (📚) u modul **Projektovanje** (`projektni-biro`).
Cilj: inženjeri dele iskustva, kratke savete, otkrića tehnologija, dobavljača, materijala, CAD trikova, standarda. Sve sa kategorijama, slobodnim tag-ovima, pretragom, prilozima i lajk brojačem.

> **Stack pravila (već važe u repo-u, ponavljam ovde):**
> - Vanilla JS, ES modules. **Bez** frameworka.
> - State: pub/sub pattern (`subscribe*`, `emit`, `snapshot`). **Bez** Redux/Zustand.
> - UI fajlovi: `<Module>Html()` za render, `wire<Module>()` za event listenere — funkcije, ne klase.
> - DOM: `escHtml()` za sanitizaciju, `document.querySelector`. Bez virtualnog DOM-a.
> - CSS: postojeće custom properties (`--surface1`, `--surface2`) i klase (`pb-*`, `form-card`).
> - RPC: uvek `sbReq('rpc/<name>', 'POST', body)` kroz **service** sloj. UI nikad direktno ne poziva supabase.
> - Greška → `throw`, UI hvata i prikazuje `showToast(e?.message)` ili error banner.
> - **Bez komentara** u kodu osim kada je WHY non-obvious.
> - SQL migracije: idempotentne (`IF NOT EXISTS`, `DROP IF EXISTS`), rollback fajl uz svaku.
> - **Smart quotes alert:** Cursor / Edit alati ponekad zamene `"` sa `"` u JS template literalima — kida HTML atribute. Ručno proveri sve template stringove pre commit-a.

---

## 0. TL;DR — šta korisnik dobija

**Tab "Saveti"** u Projektovanju, između *Analiza* i *Podešavanja*:
- **Lista** savjeta kao kartice: naslov, kategorija badge, autor + datum, excerpt, broj lajkova, broj priloga.
- **Filteri** u top traci: chips za kategorije (multi-select), search input (full-text), toggle "Najnoviji / Najpopularniji", checkbox "Samo moji".
- **Detalj modal**: pun markdown render, prilozi (slike inline + PDF download), spoljni URL, povezani projekat (klikabilan), tag-ovi, dugme 👍 Korisno (X), Edit/Delete (ako sme).
- **Editor modal**: naslov, kategorija (select), telo (markdown textarea sa preview tab-om), tag-ovi (chips input), opcioni projekat, opcioni URL, attach fajlovi (drag&drop), status (draft / published).

**Permisije**:
- **Pisanje**: inženjeri projektovanja (isti filter kao `pb_get_mechanical_projecting_engineers`) + admin.
- **Čitanje + lajk**: svi prijavljeni.
- **Edit/Delete**: samo autor (dok je vlasnik) + admin.

**Bez** komentara u MVP, **bez** notifikacija. Komentari + notifikacije = P2.

---

## 1. SQL migracija

Fajl: `sql/migrations/add_pb_eng_tips.sql` (+ `add_pb_eng_tips.down.sql`).

Sledi pattern iz `add_pb_module.sql` — `BEGIN; … NOTIFY pgrst; COMMIT;` na kraju.

### 1.1 Enum statusa

```sql
DO $$ BEGIN
  CREATE TYPE public.pb_eng_tip_status AS ENUM ('draft', 'published');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### 1.2 Tabele

```sql
-- Kategorije (admin upravlja iz PB Podešavanja)
CREATE TABLE IF NOT EXISTS public.pb_eng_tip_categories (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naziv        TEXT NOT NULL UNIQUE,
  slug         TEXT NOT NULL UNIQUE,
  ikona        TEXT,                       -- emoji ili Unicode (📦, 🏭, 🔧)
  boja         TEXT,                       -- HEX npr. #4f8cff (badge boja)
  redosled     INTEGER NOT NULL DEFAULT 0,
  je_aktivna   BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Saveti
CREATE TABLE IF NOT EXISTS public.pb_eng_tips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naslov        TEXT NOT NULL CHECK (length(naslov) BETWEEN 3 AND 200),
  telo          TEXT NOT NULL CHECK (length(telo) >= 10),    -- markdown
  category_id   UUID REFERENCES public.pb_eng_tip_categories(id) ON DELETE SET NULL,
  tags          TEXT[] NOT NULL DEFAULT '{}',
  vendor        TEXT,                                         -- opciono ime dobavljača
  url           TEXT,                                         -- opcioni spoljni link
  project_id    UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  status        public.pb_eng_tip_status NOT NULL DEFAULT 'draft',
  author_id     UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  author_email  TEXT,
  likes_count   INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  views_count   INTEGER NOT NULL DEFAULT 0 CHECK (views_count >= 0),
  search_tsv    TSVECTOR
                  GENERATED ALWAYS AS (
                    setweight(to_tsvector('simple', coalesce(naslov, '')), 'A') ||
                    setweight(to_tsvector('simple', array_to_string(coalesce(tags, '{}'::text[]), ' ')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(vendor, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(telo, '')), 'C')
                  ) STORED,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by    TEXT,
  updated_by    TEXT,
  deleted_at    TIMESTAMPTZ
);

-- Lajkovi
CREATE TABLE IF NOT EXISTS public.pb_eng_tip_likes (
  tip_id      UUID NOT NULL REFERENCES public.pb_eng_tips(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL,                                   -- auth.uid()
  user_email  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tip_id, user_id)
);

-- Prilozi (slike, PDF) — Storage bucket pb-eng-tip-files
CREATE TABLE IF NOT EXISTS public.pb_eng_tip_files (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tip_id       UUID NOT NULL REFERENCES public.pb_eng_tips(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,                                  -- "<tip_id>/<uuid>__<sanitized_name>"
  file_name    TEXT NOT NULL,
  mime_type    TEXT,
  size_bytes   BIGINT,
  is_image     BOOLEAN GENERATED ALWAYS AS (mime_type LIKE 'image/%') STORED,
  uploaded_by  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 1.3 Indeksi

```sql
CREATE INDEX IF NOT EXISTS pb_eng_tips_status_idx
  ON public.pb_eng_tips(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_category_idx
  ON public.pb_eng_tips(category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_author_idx
  ON public.pb_eng_tips(author_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_created_idx
  ON public.pb_eng_tips(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_likes_idx
  ON public.pb_eng_tips(likes_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS pb_eng_tips_search_idx
  ON public.pb_eng_tips USING GIN (search_tsv);
CREATE INDEX IF NOT EXISTS pb_eng_tips_tags_idx
  ON public.pb_eng_tips USING GIN (tags);
CREATE INDEX IF NOT EXISTS pb_eng_tip_files_tip_idx
  ON public.pb_eng_tip_files(tip_id);
```

### 1.4 Triggeri (updated_at + likes_count + audit)

```sql
DROP TRIGGER IF EXISTS pb_eng_tips_updated_at ON public.pb_eng_tips;
CREATE TRIGGER pb_eng_tips_updated_at
  BEFORE UPDATE ON public.pb_eng_tips
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS pb_eng_tip_categories_updated_at ON public.pb_eng_tip_categories;
CREATE TRIGGER pb_eng_tip_categories_updated_at
  BEFORE UPDATE ON public.pb_eng_tip_categories
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Likes count: maintained-by-trigger umesto runtime COUNT
CREATE OR REPLACE FUNCTION public.pb_eng_tip_likes_count_sync()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pb_eng_tips
       SET likes_count = likes_count + 1
     WHERE id = NEW.tip_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pb_eng_tips
       SET likes_count = GREATEST(0, likes_count - 1)
     WHERE id = OLD.tip_id;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS pb_eng_tip_likes_count_trg ON public.pb_eng_tip_likes;
CREATE TRIGGER pb_eng_tip_likes_count_trg
  AFTER INSERT OR DELETE ON public.pb_eng_tip_likes
  FOR EACH ROW EXECUTE FUNCTION public.pb_eng_tip_likes_count_sync();
```

### 1.5 Helper funkcija — "ko sme da piše savete?"

Reuse postojeći filter mehanike inženjera (vidi `pb_get_mechanical_projecting_engineers` u `sql/migrations/pb_mechanical_engineers_rpc.sql`). Napravi pomoćnu funkciju:

```sql
CREATE OR REPLACE FUNCTION public.can_write_pb_eng_tips()
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ok  boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;
  IF public.current_user_is_admin() THEN
    RETURN true;
  END IF;
  -- Reuse iste pravila kao pb_get_mechanical_projecting_engineers
  -- (employee.role = 'Mašinsko projektovanje' / Inženjering i projektovanje)
  SELECT EXISTS (
    SELECT 1 FROM public.employees e
     WHERE e.auth_user_id = v_uid
       AND e.deleted_at IS NULL
       AND COALESCE(e.sektor, '') ILIKE '%Inženjering%'
  ) INTO v_ok;
  RETURN v_ok;
END $$;

REVOKE ALL ON FUNCTION public.can_write_pb_eng_tips() FROM public;
GRANT EXECUTE ON FUNCTION public.can_write_pb_eng_tips() TO authenticated;
```

> **Napomena za Cursor:** ako u employees ne postoji adekvatno polje (sektor / role) za "Inženjering i projektovanje", proveri kako `pb_get_mechanical_projecting_engineers` filtrira i kopiraj **identičan** WHERE — ne izmišljaj novi.

### 1.6 RLS — pb_eng_tips

```sql
ALTER TABLE public.pb_eng_tips ENABLE ROW LEVEL SECURITY;

-- SELECT: svi prijavljeni vide published; autor + admin vide i svoje draft-ove
DROP POLICY IF EXISTS pb_eng_tips_select ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_select ON public.pb_eng_tips
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL AND (
      status = 'published'
      OR public.current_user_is_admin()
      OR author_id IN (
        SELECT id FROM public.employees WHERE auth_user_id = auth.uid()
      )
    )
  );

-- INSERT: samo inženjeri projektovanja + admin
DROP POLICY IF EXISTS pb_eng_tips_insert ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_insert ON public.pb_eng_tips
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_pb_eng_tips());

-- UPDATE: autor (svoj red) + admin
DROP POLICY IF EXISTS pb_eng_tips_update ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_update ON public.pb_eng_tips
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR author_id IN (SELECT id FROM public.employees WHERE auth_user_id = auth.uid())
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR author_id IN (SELECT id FROM public.employees WHERE auth_user_id = auth.uid())
  );

-- DELETE radi se soft-delete kroz RPC (vidi 1.8); SQL DELETE samo admin
DROP POLICY IF EXISTS pb_eng_tips_delete ON public.pb_eng_tips;
CREATE POLICY pb_eng_tips_delete ON public.pb_eng_tips
  FOR DELETE TO authenticated
  USING (public.current_user_is_admin());
```

Analogne RLS politike postavi i za:
- `pb_eng_tip_categories` — SELECT svi, INSERT/UPDATE/DELETE samo admin.
- `pb_eng_tip_likes` — SELECT svi, INSERT/DELETE samo svoj red (`user_id = auth.uid()`).
- `pb_eng_tip_files` — SELECT svi (uz published parent), INSERT/DELETE autor parent tip-a + admin.

### 1.7 Seed kategorija

```sql
INSERT INTO public.pb_eng_tip_categories (naziv, slug, ikona, boja, redosled) VALUES
  ('Materijali',   'materijali',   '🧱', '#7c3aed', 10),
  ('Dobavljači',   'dobavljaci',   '🏭', '#0ea5e9', 20),
  ('Mašine',       'masine',       '⚙️', '#f59e0b', 30),
  ('CAD trikovi',  'cad-trikovi',  '🎨', '#10b981', 40),
  ('Algoritmi',    'algoritmi',    '🧮', '#ef4444', 50),
  ('Standardi',    'standardi',    '📐', '#6366f1', 60),
  ('Bezbednost',   'bezbednost',   '🦺', '#dc2626', 70),
  ('Razno',        'razno',        '💡', '#64748b', 99)
ON CONFLICT (slug) DO NOTHING;
```

### 1.8 RPC funkcije (sve `SECURITY DEFINER`, public wrapper za PostgREST)

Sve RPC funkcije pišu se u **public** schema (kao i ostatak PB modula). Svaka:
- prima JSON body,
- vraća JSON,
- proverava `auth.uid()` i baca exception ako nije authenticated,
- proverava permisije gde treba.

**1.8.1 `public.pb_list_eng_tips(p_filter jsonb)`**
- Input: `{ search?: text, category_ids?: uuid[], tags?: text[], my_only?: bool, include_drafts?: bool, sort?: 'recent'|'popular', limit?: int, offset?: int }`.
- Output: array `{ id, naslov, excerpt, category_id, category_naziv, category_ikona, category_boja, tags, vendor, project_id, project_code, project_name, author_id, author_full_name, status, likes_count, views_count, files_count, is_liked_by_me, created_at, updated_at }`.
- `excerpt` = prvih 240 karaktera `telo` bez markdown markup-a (regex strip).
- Pretraga: ako `search` zadat, `search_tsv @@ websearch_to_tsquery('simple', search)` + ranking.

**1.8.2 `public.pb_get_eng_tip(p_id uuid)`**
- Output: full row + niz priloga (`files: [{ id, file_name, mime_type, is_image, size_bytes, signed_url }]`) + `is_liked_by_me` + `category` + `project` + `author` join.
- Side-effect: `UPDATE pb_eng_tips SET views_count = views_count + 1 WHERE id = p_id` (best-effort, ignore errors).
- `signed_url` generiše se preko `storage.create_signed_url(bucket, path, ttl)` ili u service sloju (kao kod `pb-task-files`).

**1.8.3 `public.pb_save_eng_tip(p_payload jsonb)`**
- Insert ili update (po `p_payload->>'id'`).
- Check `public.can_write_pb_eng_tips()` za insert; za update — autor ili admin.
- Polja: `naslov, telo, category_id, tags, vendor, url, project_id, status`.
- Vraća: pun red.

**1.8.4 `public.pb_soft_delete_eng_tip(p_id uuid)`**
- Postavi `deleted_at = now()`. Autor ili admin.
- Vraća: `{ ok: true }`.

**1.8.5 `public.pb_toggle_eng_tip_like(p_id uuid)`**
- Ako lajk za `(p_id, auth.uid())` postoji → DELETE. Inače → INSERT.
- Vraća: `{ liked: bool, likes_count: int }`.

**1.8.6 `public.pb_add_eng_tip_file(p_tip_id uuid, p_storage_path text, p_file_name text, p_mime_type text, p_size_bytes bigint)`**
- Autor parent tip-a ili admin.
- Insert u `pb_eng_tip_files`.

**1.8.7 `public.pb_delete_eng_tip_file(p_file_id uuid)`**
- Autor parent tip-a ili admin.
- DELETE iz `pb_eng_tip_files`. Service sloj briše objekat iz Storage-a.

**1.8.8 `public.pb_list_eng_tip_categories()`**
- Svi prijavljeni. Vraća sve aktivne kategorije sortirane po `redosled, naziv`.

**1.8.9 `public.pb_upsert_eng_tip_category(p_payload jsonb)` + `public.pb_delete_eng_tip_category(p_id uuid)`**
- Samo admin. Za PB Podešavanja tab.

Sve RPC-i: `GRANT EXECUTE TO authenticated;` + `REVOKE FROM public;` + `NOTIFY pgrst, 'reload schema';` na kraju migracije.

### 1.9 Storage bucket

```sql
INSERT INTO storage.buckets (id, name, public)
  VALUES ('pb-eng-tip-files', 'pb-eng-tip-files', false)
  ON CONFLICT (id) DO NOTHING;
```

Storage policy: prijavljeni mogu SELECT (signed URL kreira RPC); INSERT/DELETE samo autor parent tip-a + admin. Vidi pattern u `add_pb_task_files.sql`.

### 1.10 Rollback fajl

`sql/migrations/add_pb_eng_tips.down.sql`:

```sql
BEGIN;
DROP TABLE IF EXISTS public.pb_eng_tip_files CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tip_likes CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tips CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tip_categories CASCADE;
DROP TYPE IF EXISTS public.pb_eng_tip_status;
DROP FUNCTION IF EXISTS public.can_write_pb_eng_tips();
DROP FUNCTION IF EXISTS public.pb_eng_tip_likes_count_sync() CASCADE;
DROP FUNCTION IF EXISTS public.pb_list_eng_tips(jsonb);
DROP FUNCTION IF EXISTS public.pb_get_eng_tip(uuid);
DROP FUNCTION IF EXISTS public.pb_save_eng_tip(jsonb);
DROP FUNCTION IF EXISTS public.pb_soft_delete_eng_tip(uuid);
DROP FUNCTION IF EXISTS public.pb_toggle_eng_tip_like(uuid);
DROP FUNCTION IF EXISTS public.pb_add_eng_tip_file(uuid, text, text, text, bigint);
DROP FUNCTION IF EXISTS public.pb_delete_eng_tip_file(uuid);
DROP FUNCTION IF EXISTS public.pb_list_eng_tip_categories();
DROP FUNCTION IF EXISTS public.pb_upsert_eng_tip_category(jsonb);
DROP FUNCTION IF EXISTS public.pb_delete_eng_tip_category(uuid);
DELETE FROM storage.buckets WHERE id = 'pb-eng-tip-files';
NOTIFY pgrst, 'reload schema';
COMMIT;
```

---

## 2. Service layer — `src/services/pbEngTips.js` (NOV fajl)

Pattern: kao `src/services/pb.js`. Export funkcije, svaka `sbReqThrow('rpc/<name>', 'POST', body)`.

```js
import { sbReqThrow, sbReq } from './supabase.js';
import { getCurrentUser, getIsOnline } from '../state/auth.js';

export async function listEngTips({ search, categoryIds, tags, myOnly, includeDrafts, sort, limit, offset } = {}) {
  if (!getIsOnline()) return [];
  const data = await sbReqThrow('rpc/pb_list_eng_tips', 'POST', {
    p_filter: {
      search: search || null,
      category_ids: categoryIds?.length ? categoryIds : null,
      tags: tags?.length ? tags : null,
      my_only: !!myOnly,
      include_drafts: !!includeDrafts,
      sort: sort || 'recent',
      limit: limit ?? 100,
      offset: offset ?? 0,
    },
  });
  return Array.isArray(data) ? data : [];
}

export async function getEngTip(id) { /* sbReqThrow('rpc/pb_get_eng_tip', ...) */ }
export async function saveEngTip(payload) { /* validate naslov/telo length; sbReqThrow('rpc/pb_save_eng_tip', ...) */ }
export async function softDeleteEngTip(id) { /* … */ }
export async function toggleEngTipLike(id) { /* … */ }

export async function listEngTipCategories() { /* … */ }
export async function upsertEngTipCategory(payload) { /* admin only */ }
export async function deleteEngTipCategory(id) { /* admin only */ }

// File upload — analogno src/services/drawings.js / pb-task-files
export async function uploadEngTipFile(tipId, file) {
  // 1. upload u storage bucket 'pb-eng-tip-files', path = `${tipId}/${crypto.randomUUID()}__${sanitizeName(file.name)}`
  // 2. RPC pb_add_eng_tip_file da upiše red u pb_eng_tip_files
  // 3. vrati { id, file_name, mime_type, is_image, signed_url }
}
export async function deleteEngTipFile(fileId, storagePath) {
  // 1. storage.remove([storagePath])
  // 2. RPC pb_delete_eng_tip_file(fileId)
}

export async function getEngTipFileSignedUrl(storagePath, ttlSeconds = 3600) {
  // storage.createSignedUrl pattern (vidi services/drawings.js)
}

// Permisija frontend gate (RLS je izvor istine; ovo je samo za UI)
export async function canCurrentUserWriteEngTip() {
  // Pokušaj RPC `rpc/can_write_pb_eng_tips`. Ako 404, fallback na getPbEngineers() match by email.
}
```

> **Validacija u service sloju** (pre RPC poziva): naslov 3–200 char, telo ≥ 10 char, max 10 tag-ova po savetu, max 8 fajlova po savetu, fajl ≤ 5MB, mime ∈ {`image/*`, `application/pdf`}. Greška → `throw new Error('…')`.

---

## 3. State — `src/state/pbEngTips.js` (NOV fajl)

Pub/sub state, pattern kao ostali state fajlovi:

```js
const state = {
  categories: [],
  tips: [],            // lista (rezultat listEngTips)
  filter: {
    search: '',
    categoryIds: [],   // multi-select
    tags: [],
    myOnly: false,
    includeDrafts: false,
    sort: 'recent',    // 'recent' | 'popular'
  },
  loading: false,
  error: null,
  selectedTipId: null, // za detalj modal
  canWrite: false,
};
const listeners = new Set();
export function subscribeEngTips(fn) { listeners.add(fn); return () => listeners.delete(fn); }
export function snapshotEngTips() { return { ...state, filter: { ...state.filter } }; }
function emit() { for (const fn of listeners) fn(snapshotEngTips()); }

export function setEngTipsFilter(patch) { state.filter = { ...state.filter, ...patch }; emit(); }
export function setEngTips(tips) { state.tips = tips; emit(); }
export function setEngTipCategories(cats) { state.categories = cats; emit(); }
export function setEngTipsLoading(b) { state.loading = b; emit(); }
export function setEngTipsError(e) { state.error = e; emit(); }
export function setSelectedTipId(id) { state.selectedTipId = id; emit(); }
export function setEngTipsCanWrite(b) { state.canWrite = b; emit(); }
```

LocalStorage persistence: `filter` se čuva pod `SESSION_KEYS.PB_ENG_TIPS_FILTER` da posle reloada filter ostane (osim `search`, koji ostaje samo u memoriji).

---

## 4. UI layer

### 4.1 `src/ui/pb/savetiTab.js` (NOV fajl)

Export:
```js
export function renderSavetiTab(mountEl, ctx) { /* … */ }
```

`ctx` prosleđuje:
- `projects` (za select projekta u editor-u),
- `canEdit` = rezultat `canCurrentUserWriteEngTip()`,
- `onRefresh()` callback (re-fetch posle save/delete).

**Layout (mobile + desktop):**

```
┌──────────────────────────────────────────────────────────────┐
│ [📚 Saveti]    [Search ...........]  [⊕ Novi savet]          │
│ Chips:  [Sve] [Materijali] [Dobavljači] [Mašine] [...]       │
│ Toggle: ◯ Najnoviji  ◯ Najpopularniji   ☐ Samo moji  ☐ Drafts│
├──────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐   │
│ │ 🧱 Materijali · 2026-05-18 · Marko Petrović            │   │
│ │ Inox 316L za vlažne sredine — iskustvo sa Sika dobavl. │   │
│ │ "Posle 6 meseci u praonici nije bilo rđe…"             │   │
│ │ #316L #korozija #Sika  📎2  👍 12                       │   │
│ └────────────────────────────────────────────────────────┘   │
│ ┌────────────────────────────────────────────────────────┐   │
│ │ 🏭 Dobavljači · ...                                     │   │
│ └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**HTML/JS skeleton:**

```js
import { escHtml, showToast } from '../../lib/dom.js';
import { listEngTips, listEngTipCategories, toggleEngTipLike, canCurrentUserWriteEngTip } from '../../services/pbEngTips.js';
import { snapshotEngTips, setEngTipsFilter, setEngTips, setEngTipCategories, setSelectedTipId, setEngTipsCanWrite, subscribeEngTips } from '../../state/pbEngTips.js';
import { openTipDetailModal } from './tipDetailModal.js';
import { openTipEditorModal } from './tipEditorModal.js';

export function renderSavetiTab(mountEl, ctx) {
  mountEl.innerHTML = savetiTabHtml();
  wireSavetiTab(mountEl, ctx);
  void loadCategoriesAndTips(ctx);
}

function savetiTabHtml() { /* vraća HTML toolbara + chips placeholder + list placeholder */ }
function wireSavetiTab(root, ctx) { /* event listeneri + subscribe state */ }
async function loadCategoriesAndTips(ctx) { /* paralelno fetch */ }

function renderTipsList(root, tips, ctx) { /* mapira karticu po tipu */ }
function renderTipCard(tip, ctx) { /* HTML kartice */ }
```

**Detalji kartice (HTML):**
```html
<article class="pb-tip-card" data-tip-id="{id}" role="button" tabindex="0" aria-label="Otvori savet {naslov}">
  <header class="pb-tip-card-head">
    <span class="pb-tip-cat-badge" style="background: {category.boja}1a; color: {category.boja}">
      {category.ikona} {category.naziv}
    </span>
    <span class="pb-tip-card-meta">{relativeDate(created_at)} · {author_full_name}</span>
    {status === 'draft' ? `<span class="pb-tip-draft-badge">DRAFT</span>` : ''}
  </header>
  <h3 class="pb-tip-card-title">{naslov}</h3>
  <p class="pb-tip-card-excerpt">{excerpt}…</p>
  <footer class="pb-tip-card-foot">
    <span class="pb-tip-tags">{tags.map(t => `<span class="pb-tip-tag">#${t}</span>`).join('')}</span>
    <span class="pb-tip-card-stats">
      {files_count > 0 ? `📎 ${files_count}` : ''}
      <button class="pb-tip-like-btn{is_liked_by_me ? ' liked' : ''}" data-tip-like="{id}">👍 {likes_count}</button>
    </span>
  </footer>
</article>
```

Klik na karticu (osim na lajk dugme) → `openTipDetailModal({ tipId, onChanged: () => ctx.onRefresh() })`.
Klik na lajk dugme → optimistic update + `toggleEngTipLike(id)`.

**Pretraga**: debounce 250ms na input → `setEngTipsFilter({ search }); reloadTips()`.

**Kategorije chips**:
- `[Sve]` chip — reset filter.
- Klik na kategoriju → toggle u `categoryIds` (multi-select). Aktivni chipovi imaju `aria-pressed="true"` i puniju pozadinu.

### 4.2 `src/ui/pb/tipDetailModal.js` (NOV fajl)

Modal sa zatamnjenjem (postojeći `.modal-overlay` pattern u repou, vidi `src/ui/pb/shared.js` openTaskEditorModal).

Sadržaj:
- Header: kategorija badge + naslov + close `×`.
- Meta linija: autor · datum · projekat (ako postoji, klikabilan → navigateToAppPath ka PB Planu sa pre-selected project).
- Body: render markdown → HTML (koristi postojeću `markdownToHtml()` helper ako postoji; inače minimalan parser za `**bold**`, `*italic*`, `\n\n` → `<p>`, ` ``` ` → `<pre>`, `[text](url)` → `<a target="_blank" rel="noopener">`). **Sanitize** sa `escHtml()` PRE markdown render-a, ili koristi DOMPurify ako je već u repou.
- Prilozi: slike inline (`<img class="pb-tip-image" loading="lazy">`), PDF-ovi kao `<a download>` sa ikonom.
- Tag-ovi: chipovi.
- Footer: 👍 Korisno (X) dugme + Edit + Delete (ako sme).

`openTipDetailModal({ tipId, onChanged })`:
1. `await getEngTip(tipId)` → popuni modal.
2. Animiraj fade-in (CSS `.modal-overlay.open`).
3. ESC ili klik na backdrop → zatvori.

### 4.3 `src/ui/pb/tipEditorModal.js` (NOV fajl)

`openTipEditorModal({ tip, projects, categories, canEdit, onSaved })`:
- Forma: naslov (text), kategorija (select), telo (textarea sa tab-om "Pregled" koji renderuje markdown), tag-ovi (chip input — Enter dodaje, Backspace briše), vendor (text), URL (text), projekat (searchable select sa `projects` listom), status (radio: Draft / Objavljen).
- Drop zona za fajlove: drag&drop + klik za file picker. Pre upload-a — validacija mime + size. Posle upload-a — prikaži thumbnail (slike) / ikonu (PDF) + dugme za brisanje.
- Sačuvaj: `await saveEngTip(payload)` → ako su novi fajlovi → `uploadEngTipFile(tipId, file)` paralelno (Promise.all) → `onSaved()` → close modal.
- Validacija inline (crveni border na invalid polje) pre POST-a.

Markdown helper: ako u repou ne postoji generic `markdownToHtml`, ne uvodi zavisnost (marked.js npm) — napisi mini parser u `src/ui/pb/markdown.js` (NOV fajl, ~50 linija): `**bold**`, `*italic*`, `\n` u `<br>`, fenced code blocks, linkovi, liste. Sanitize ulaz sa `escHtml()` PRVO.

---

## 5. Integracija u `src/ui/pb/index.js`

### 5.1 Dodaj `saveti` u tab listu

```js
const TAB_EMOJI = {
  plan:        '📋',
  kanban:      '🗂️',
  gantt:       '📈',
  izvestaji:   '📑',
  analiza:     '📊',
  saveti:      '📚',     // NOV
  podesavanja: '⚙️',
};
```

### 5.2 Render tab dugme između `analiza` i `podesavanja`

```js
${pbTabBtn('analiza', 'Analiza', state.activeTab === 'analiza')}
${pbTabBtn('saveti',  'Saveti',  state.activeTab === 'saveti')}
${isAdmin() ? pbTabBtn('podesavanja', 'Podešavanja', state.activeTab === 'podesavanja') : ''}
```

### 5.3 U `mountActiveTab()` dodaj granu

```js
if (tab === 'saveti') {
  const { renderSavetiTab } = await import('./savetiTab.js');
  renderSavetiTab(body, {
    projects,
    onRefresh: () => loadAll(true),
  });
  return;
}
```

> Lazy import-uj `savetiTab.js` da ne uvećaš initial bundle za korisnike koji ne otvaraju ovaj tab.

### 5.4 U `loadPbState`/`savePbState` (`shared.js`) dodaj polje

`activeTab` već postoji — samo dozvoli vrednost `'saveti'`. Ako postoji whitelist tabova, dodaj `'saveti'` u listu.

### 5.5 PB Podešavanja tab — Kategorije

U `src/ui/pb/podesavanjaTab.js` (postoji), dodaj sekciju **"Kategorije saveta"** sa CRUD-om (lista + inline edit + dodaj + brisanje). Koristi `listEngTipCategories`, `upsertEngTipCategory`, `deleteEngTipCategory`. Samo admin (već je gate u tab-u).

---

## 6. CSS — `src/styles/pb-eng-tips.css` (NOV fajl) ili `src/styles/legacy.css` apend

Stilovi u skladu sa postojećim `--surface*` tokenima:

```css
.pb-saveti-toolbar { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; margin-bottom: 12px; }
.pb-saveti-search { flex: 1 1 240px; max-width: 480px; }
.pb-saveti-chips { display: flex; flex-wrap: wrap; gap: 6px; margin: 8px 0 16px; }
.pb-saveti-chip { padding: 4px 10px; border-radius: 999px; background: var(--surface2); cursor: pointer; font-size: 13px; }
.pb-saveti-chip[aria-pressed="true"] { background: var(--accent); color: #fff; }

.pb-tips-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; }
.pb-tip-card { background: var(--surface1); border: 1px solid var(--border1); border-radius: 8px; padding: 14px; cursor: pointer; transition: box-shadow .15s; }
.pb-tip-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.pb-tip-card-head { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 12px; }
.pb-tip-cat-badge { padding: 2px 8px; border-radius: 999px; font-weight: 600; font-size: 11px; }
.pb-tip-draft-badge { background: var(--surface3); color: var(--text2); padding: 2px 6px; border-radius: 4px; font-size: 10px; }
.pb-tip-card-title { margin: 8px 0 6px; font-size: 15px; font-weight: 600; }
.pb-tip-card-excerpt { color: var(--text2); font-size: 13px; line-height: 1.5; }
.pb-tip-card-foot { display: flex; justify-content: space-between; gap: 8px; margin-top: 10px; flex-wrap: wrap; font-size: 12px; }
.pb-tip-tag { background: var(--surface2); padding: 1px 6px; border-radius: 4px; margin-right: 4px; font-size: 11px; }
.pb-tip-like-btn { background: transparent; border: 1px solid var(--border1); border-radius: 999px; padding: 2px 10px; cursor: pointer; }
.pb-tip-like-btn.liked { background: var(--accent); color: #fff; border-color: var(--accent); }
```

Mobile: na `max-width: 640px` lista → jedna kolona. Modali → full-screen sheet (vidi pattern u `src/ui/podesavanja/podesavanjePredmeta/napomenaModal.js`).

---

## 7. Acceptance criteria (test checklist)

**Funkcionalno:**
- [ ] Kao admin: vidim tab "Saveti" u Projektovanju, vidim sve savete uključujući tuđe draft-ove.
- [ ] Kao inženjer projektovanja: vidim tab, mogu da kreiram novi savet, vidim svoje draft-ove + tuđe published.
- [ ] Kao običan prijavljen korisnik (ne inženjer): vidim tab, vidim samo published, NE vidim dugme "Novi savet", lajk radi.
- [ ] Nedostupan tab (offline): prikaže banner "Saveti zahtevaju internet", ne ruši UI.
- [ ] Pretraga "316L" → vraća savet sa naslovom/telom/tag-om koji sadrži 316L (full-text rank → najbolji prvi).
- [ ] Multi-select kategorije: ako kliknem `Materijali` + `Dobavljači` → vidim samo tipove iz te dve kategorije.
- [ ] Sort toggle: `Najpopularniji` → `likes_count DESC`; `Najnoviji` → `created_at DESC`.
- [ ] Lajk: prvi klik → 👍 12 → 👍 13 (highlight); drugi klik → 👍 12 (unhighlight). Optimistic UI, rollback ako RPC fail.
- [ ] Editor: validacija — naslov < 3 char → crveni border + showToast. Telo prazno → blokira save.
- [ ] Upload: PNG 2MB → uploaduje se, pojavljuje se thumbnail. DOCX → odbije se sa porukom.
- [ ] Detalj modal: markdown se renderuje, `<script>` u telu se eskejpa (sanitize check).
- [ ] Edit svog tipa: dugme Edit prisutno; preuzima trenutne vrednosti; save radi.
- [ ] Edit tuđeg tipa: dugme Edit nije prisutno. (Kao admin: prisutno je.)
- [ ] Brisanje: soft-delete, savet nestaje iz liste, audit log ima zapis (ako `audit_row_change` postoji).
- [ ] Povezani projekat: klik na "Povezano: BIGTEHN-9811" → zatvara modal, prebacuje na Plan tab sa selected project.
- [ ] PB Podešavanja → Kategorije: admin može da doda novu kategoriju i ona se odmah pojavi u Saveti chip-ovima (re-fetch posle save).

**Performance:**
- [ ] Lista od 200 savjeta učitava se < 600ms (lokalno + Supabase free tier).
- [ ] Pretraga koristi GIN index (`EXPLAIN` u SQL editoru pokazuje `Bitmap Index Scan on pb_eng_tips_search_idx`).
- [ ] Lazy import `savetiTab.js` — Network tab pokazuje chunk učitan tek pri kliku na tab.

**Sigurnost:**
- [ ] Direktni POST na `rpc/pb_save_eng_tip` od običnog korisnika (bez prava pisanja) → 403/permission denied.
- [ ] SELECT preko PostgREST tabele `pb_eng_tips` (van RPC-a) — nema curenja draft-ova drugih korisnika.
- [ ] Storage signed URL ima TTL ≤ 1h.
- [ ] HTML injection u naslov/telo se eskejpa u listi I u detalj modal-u (sanity test sa `<script>alert(1)</script>`).

**Smart quotes provera:**
- [ ] `git diff` ne sadrži `"`, `"`, `'`, `'` u .js fajlovima. (Cursor / Edit alat zna da uvali Unicode curly quotes u template literale i poruke — pre commit-a `grep -P "[‘’“”]" src/` mora biti prazno.)

---

## 8. File checklist

**Novi fajlovi:**
- `sql/migrations/add_pb_eng_tips.sql`
- `sql/migrations/add_pb_eng_tips.down.sql`
- `src/services/pbEngTips.js`
- `src/state/pbEngTips.js`
- `src/ui/pb/savetiTab.js`
- `src/ui/pb/tipDetailModal.js`
- `src/ui/pb/tipEditorModal.js`
- `src/ui/pb/markdown.js` (ako ne postoji već generic helper)
- `src/styles/pb-eng-tips.css` (ili apend u `legacy.css`)

**Izmenjeni fajlovi:**
- `src/ui/pb/index.js` — dodaj tab dugme + lazy import + `TAB_EMOJI`.
- `src/ui/pb/shared.js` — dozvoli `activeTab = 'saveti'` u state load/save.
- `src/ui/pb/podesavanjaTab.js` — sekcija "Kategorije saveta" (CRUD).
- `src/lib/constants.js` — `SESSION_KEYS.PB_ENG_TIPS_FILTER`.
- `src/main.js` / glavni CSS import — uključi `pb-eng-tips.css` ako ide u zaseban fajl.

**Bez izmena, samo provera:**
- `src/ui/router.js` — `projektni-biro` modul je već u listi; ne treba ništa.
- `src/services/supabase.js` — `sbReqThrow` koristimo postojeći.

---

## 9. Implementacioni redosled za Cursor

Predlažem da Cursor radi u 5 koraka, sa stop-and-verify pauzom posle svakog:

1. **SQL** — napiši migraciju + rollback, primeni u Supabase SQL Editor (manual), verifikuj `pb_list_eng_tips` RPC vraća prazan niz bez greške.
2. **Service + State** — `pbEngTips.js` + `state/pbEngTips.js`. Manual test iz konzole: `await listEngTips({})` → `[]`.
3. **UI tab skeleton** — `savetiTab.js` (samo toolbar + chips + prazna lista) + integracija u `pb/index.js`. Klikni tab → render bez greške.
4. **Detalj + Editor modal** — `tipDetailModal.js` + `tipEditorModal.js`. Test: kreiraj 1 savet, otvori detalj.
5. **Lajkovi + prilozi + Podešavanja CRUD** — toggleLike, upload/delete file, kategorije u Podešavanjima. Verifikuj sve iz checklist-a u sekciji 7.

---

## 10. Otvorena pitanja koja Cursor mora da reši samostalno (a NE da izmišlja)

Cursor mora prvo da pročita kod pre nego što doda:

1. **Format datuma**: postoji li već `formatRelativeDate(iso)` helper? Ako da — reuse. Ako ne — napisati u `src/lib/dom.js` (ne novi fajl).
2. **Markdown render**: postoji li markdown helper u repou (možda kroz `marked` npm)? Ako postoji — reuse. Ako ne — napisati mini parser u `src/ui/pb/markdown.js` (~50 LOC, bez npm zavisnosti).
3. **Filter sektora za "inženjer projektovanja"**: pročitati `sql/migrations/pb_mechanical_engineers_rpc.sql` i kopirati IDENTIČAN WHERE u `can_write_pb_eng_tips()`. Ne izmišljati novi.
4. **Modal pattern**: pročitati postojeći `openTaskEditorModal` u `src/ui/pb/shared.js` i koristiti isti DOM root + close handlers.
5. **Storage signed URL**: pročitati `src/services/drawings.js` ili `pb` upload patterns za fajlove — replicirati isti pattern (signed URL TTL, error handling, retry).

---

## 11. Ne radi (out of scope za ovaj task)

- **Komentari** — odgođeno za P2 (zaseban tip `pb_eng_tip_comments` tabela).
- **Notifikacije** — bez Telegram/email push-a (postojeći `pb_notifications` modul ostaje samo za zadatke).
- **In-app "novo" badge** — bez `last_seen_at` po korisniku.
- **Multi-language tagovi** — tagovi su slobodan tekst, bez normalize-a (`festo` i `Festo` su različiti tagovi za sada).
- **Import iz Google Docs / Wiki** — ručan unos preko editora.
- **Versioning / istorija izmena** — `updated_at` je dovoljan; revizija dolazi preko `audit_row_change` trigera (ako je već instaliran globalno).

---

## Završna napomena

Posle implementacije, otvori PR sa naslovom: `feat(pb): Engineering Tips tab — baza znanja inženjera projektovanja`.

Body PR-a treba da sadrži:
- Screenshot liste (sa par seed savjeta).
- Screenshot editor modala.
- Screenshot detalj modala (sa slikom + tag-ovima + lajkom).
- Output `EXPLAIN ANALYZE` za pretragu (potvrda da GIN radi).
- Checklist iz sekcije 7 sa ✅ pored svake stavke.
