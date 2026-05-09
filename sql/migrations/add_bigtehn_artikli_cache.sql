-- ============================================================================
-- BigTehn artikli cache — mirror SQL Server tabele dbo.R_Artikli
-- ============================================================================
-- Cilj: Lokalni read-only mirror master kataloga artikala iz BigTehn QBigTehn
-- (SQL Server) baze, sa istim imenima kolona (snake_case) i tipovima koji
-- odgovaraju Jet metadata-i iz legacy MDB exporta.
--
-- Izvor (legacy):
--   .cursor/legacy-mdb-export/QBigTehn_APL/tables.txt
--   - TABLE: R_Artikli         (linije 889–967, 67 kolona, PK = "Sifra artikla")
--   - TABLE: R_Grupa           (linije 969–973)
--   - TABLE: R_Podgrupa        (linije 975–980)
--   - TABLE: R_Poreklo         (linije 982–988)
--   - TABLE: R_Tarife          (linije 990–1004, PK = ID, UQ = Tarifa)
--
-- Mapiranje Jet → Postgres:
--   type=1  (Boolean) → boolean
--   type=3  (Integer) → smallint
--   type=4  (Long)    → integer
--   type=5  (Currency)→ numeric(19,4)
--   type=7  (Double)  → double precision
--   type=8  (DateTime)→ timestamp
--   type=10 (Text(N)) → varchar(N)
--   type=12 (Memo)    → text
--
-- BigBit veza: BBSifra artikla (req=True u BigTehn-u) je `bb_sifra_artikla`
-- u ovom cache-u. ImportIzBB_Module.bas koristi tu kolonu za sync iz BB_T_26.MDB
-- → EXT_R_Artikli → R_Artikli.
--
-- Idempotentno (CREATE IF NOT EXISTS / DROP TRIGGER + CREATE), pa je bezbedno
-- za re-run. Sync se popunjava kasnijom batch migracijom / scheduled job-om.
-- ============================================================================

-- ------------------------------------------------------------
-- 1. Lookup: bigtehn_grupa_cache  (R_Grupa)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.bigtehn_grupa_cache (
  grupa       varchar(10)  PRIMARY KEY,
  opis        varchar(50)  NOT NULL,
  synced_at   timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.bigtehn_grupa_cache IS
  'Mirror QBigTehn.dbo.R_Grupa. PK: grupa.';

-- ------------------------------------------------------------
-- 2. Lookup: bigtehn_podgrupa_cache  (R_Podgrupa)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.bigtehn_podgrupa_cache (
  podgrupa     varchar(10)  PRIMARY KEY,
  opis         varchar(50)  NOT NULL,
  grupa_veza   varchar(10),
  synced_at    timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bigtehn_podgrupa_cache_grupa_idx
  ON public.bigtehn_podgrupa_cache (grupa_veza);

COMMENT ON TABLE public.bigtehn_podgrupa_cache IS
  'Mirror QBigTehn.dbo.R_Podgrupa. grupa_veza je soft FK ka bigtehn_grupa_cache.grupa.';

-- ------------------------------------------------------------
-- 3. Lookup: bigtehn_poreklo_cache  (R_Poreklo)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.bigtehn_poreklo_cache (
  poreklo         varchar(5)   PRIMARY KEY,
  opis            varchar(50)  NOT NULL,
  podgrupa_veza   varchar(10),
  popust_proc     numeric(19,4),
  synced_at       timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bigtehn_poreklo_cache_podgrupa_idx
  ON public.bigtehn_poreklo_cache (podgrupa_veza);

COMMENT ON TABLE public.bigtehn_poreklo_cache IS
  'Mirror QBigTehn.dbo.R_Poreklo. podgrupa_veza soft FK ka bigtehn_podgrupa_cache.';

-- ------------------------------------------------------------
-- 4. Lookup: bigtehn_tarife_cache  (R_Tarife)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.bigtehn_tarife_cache (
  id                 integer       PRIMARY KEY,
  tarifa             varchar(5)    NOT NULL,
  osnovna_stopa      double precision,
  zeleznica_stopa    double precision,
  gradska_stopa      double precision,
  ratna_stopa        double precision,
  posebna_stopa      double precision,
  opis               text,
  vazi_od            timestamp,
  vazi_do            timestamp,
  pdv_grupa          varchar(10),
  synced_at          timestamptz   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS bigtehn_tarife_cache_tarifa_uq
  ON public.bigtehn_tarife_cache (tarifa);

COMMENT ON TABLE public.bigtehn_tarife_cache IS
  'Mirror QBigTehn.dbo.R_Tarife. PK = id (Long iz SQL-a), tarifa je UNIQUE business key.';

-- ------------------------------------------------------------
-- 5. Glavna tabela: bigtehn_artikli_cache  (R_Artikli)
-- ------------------------------------------------------------
--
-- 67 kolona iz dbo.R_Artikli. Snake_case mapiranje:
--   "Sifra artikla"        → sifra_artikla        (PK)
--   "Kataloski broj"       → kataloski_broj
--   "BarKod"               → barkod
--   "PLU"                  → plu
--   "ExtSifra"             → ext_sifra
--   "Naziv"                → naziv
--   "Jedinica mere"        → jedinica_mere
--   "Pakovanje"            → pakovanje
--   "InoJm"                → ino_jm
--   "Kutija"               → kutija
--   "Transportno pakovanje"→ transportno_pakovanje
--   "Poreklo"              → poreklo
--   "Grupa"                → grupa
--   "Podgrupa"             → podgrupa
--   "Tarifa robe"          → tarifa_robe
--   "Tarifa usluga"        → tarifa_usluga
--   "Uvek porez na robu"   → uvek_porez_na_robu
--   "Uvek porez na usluge" → uvek_porez_na_usluge
--   "VP cena" / "MP cena"  → vp_cena / mp_cena
--   "NabDevCena"           → nab_dev_cena
--   "ProdDevCena"          → prod_dev_cena
--   "Minimalna kolicina"   → minimalna_kolicina
--   "ArtTaksa"             → art_taksa
--   "Odlozeno"             → odlozeno
--   "Neoporezivi deo"      → neoporezivi_deo
--   "MaxRabatProc"         → max_rabat_proc
--   "Memo"                 → memo
--   "KngSifra" / "KngSifra_2" → kng_sifra / kng_sifra_2
--   "ArtAkciza"            → art_akciza
--   "ZavTrosProiz"         → zav_tros_proiz
--   "CarStopa"             → car_stopa
--   "IDRaster"             → id_raster
--   "CarTarifa"            → car_tarifa
--   "ZemljaPorekla"        → zemlja_porekla
--   "Polica"               → polica
--   "INONaziv"             → ino_naziv
--   "SifDob"               → sif_dob
--   "WebOpis"              → web_opis
--   "OpisArtikla"          → opis_artikla
--   "Tezina" / "TezinaKg"  → tezina / tezina_kg
--   "PDFLink"              → pdf_link
--   "ZaBrisanje"           → za_brisanje
--   "Aktivan"              → aktivan
--   "CenaZaUpisUCen"       → cena_za_upis_u_cen
--   "IDMestoIzdavanja"     → id_mesto_izdavanja
--   "Proizvodjac"          → proizvodjac
--   "HPS"                  → hps
--   "PotpisArt"            → potpis_art
--   "DatumIVremeArt"       → datum_i_vreme_art
--   "KolUPak"              → kol_u_pak
--   "KLRucProc"            → kl_ruc_proc
--   "OsnJM"                → osn_jm
--   "SlikaSimbolaLink"     → slika_simbola_link
--   "MPKaloProc" / "VPKaloProc" → mp_kalo_proc / vp_kalo_proc
--   "WordLokacija"         → word_lokacija
--   "NeVodiZalihe"         → ne_vodi_zalihe
--   "Zapremina" / "Povrsina" → zapremina / povrsina
--   "RSort"                → r_sort
--   "AkcijskiRabat"        → akcijski_rabat
--   "Napomena2"            → napomena2
--   "IDKvalitetArtikla"    → id_kvalitet_artikla
--   "Debljina"             → debljina
--   "BBSifra artikla"      → bb_sifra_artikla
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.bigtehn_artikli_cache (
  sifra_artikla            integer        PRIMARY KEY,
  kataloski_broj           varchar(20)    NOT NULL,
  barkod                   varchar(50),
  plu                      integer,
  ext_sifra                varchar(20),
  naziv                    varchar(50)    NOT NULL,
  jedinica_mere            varchar(5),
  pakovanje                varchar(10),
  ino_jm                   varchar(5),
  kutija                   double precision,
  transportno_pakovanje    double precision,
  poreklo                  varchar(5)     NOT NULL,
  grupa                    varchar(10)    NOT NULL,
  podgrupa                 varchar(10)    NOT NULL,
  tarifa_robe              varchar(5)     NOT NULL,
  tarifa_usluga            varchar(5)     NOT NULL,
  uvek_porez_na_robu       boolean,
  uvek_porez_na_usluge     boolean,
  vp_cena                  double precision,
  mp_cena                  double precision,
  nab_dev_cena             double precision,
  prod_dev_cena            double precision,
  minimalna_kolicina       double precision,
  art_taksa                double precision,
  odlozeno                 smallint,
  neoporezivi_deo          double precision,
  max_rabat_proc           double precision,
  memo                     text,
  kng_sifra                varchar(10),
  art_akciza               double precision,
  kng_sifra_2              varchar(10),
  zav_tros_proiz           double precision,
  car_stopa                double precision,
  id_raster                integer,
  car_tarifa               varchar(20),
  zemlja_porekla           varchar(20),
  polica                   varchar(10),
  ino_naziv                varchar(50),
  sif_dob                  integer,
  web_opis                 varchar(255),
  opis_artikla             varchar(50),
  tezina                   double precision,
  pdf_link                 varchar(255),
  za_brisanje              boolean,
  aktivan                  boolean,
  cena_za_upis_u_cen       double precision,
  id_mesto_izdavanja       integer,
  proizvodjac              varchar(50),
  hps                      varchar(50),
  potpis_art               varchar(50),
  datum_i_vreme_art        timestamp,
  kol_u_pak                double precision,
  kl_ruc_proc              numeric(19,4),
  osn_jm                   varchar(5),
  slika_simbola_link       varchar(250),
  mp_kalo_proc             double precision,
  word_lokacija            varchar(250),
  vp_kalo_proc             double precision,
  ne_vodi_zalihe           boolean,
  tezina_kg                double precision,
  zapremina                double precision,
  povrsina                 double precision,
  r_sort                   integer,
  akcijski_rabat           double precision,
  napomena2                varchar(255),
  id_kvalitet_artikla      integer,
  debljina                 double precision,
  bb_sifra_artikla         integer        NOT NULL,
  synced_at                timestamptz    NOT NULL DEFAULT now()
);

-- IDX-evi po BigTehn definiciji (linije 959–967 u tables.txt)
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_grupa_idx
  ON public.bigtehn_artikli_cache (grupa);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_podgrupa_idx
  ON public.bigtehn_artikli_cache (podgrupa);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_poreklo_idx
  ON public.bigtehn_artikli_cache (poreklo);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_tarifa_robe_idx
  ON public.bigtehn_artikli_cache (tarifa_robe);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_tarifa_usluga_idx
  ON public.bigtehn_artikli_cache (tarifa_usluga);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_id_raster_idx
  ON public.bigtehn_artikli_cache (id_raster) WHERE id_raster IS NOT NULL;
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_id_kvalitet_idx
  ON public.bigtehn_artikli_cache (id_kvalitet_artikla) WHERE id_kvalitet_artikla IS NOT NULL;
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_id_mesto_idx
  ON public.bigtehn_artikli_cache (id_mesto_izdavanja) WHERE id_mesto_izdavanja IS NOT NULL;

-- Korisni dodatni indeksi za UI pretragu (nisu u BigTehn-u, ali su lokalno potrebni)
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_naziv_idx
  ON public.bigtehn_artikli_cache (lower(naziv));
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_kataloski_idx
  ON public.bigtehn_artikli_cache (lower(kataloski_broj));
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_bb_sifra_idx
  ON public.bigtehn_artikli_cache (bb_sifra_artikla);
CREATE INDEX IF NOT EXISTS bigtehn_artikli_cache_aktivan_idx
  ON public.bigtehn_artikli_cache (aktivan) WHERE aktivan IS TRUE;

COMMENT ON TABLE public.bigtehn_artikli_cache IS
  'Read-only mirror QBigTehn.dbo.R_Artikli (master katalog artikala iz BigTehn-a). 67 kolona prati izvornu definiciju 1:1 (snake_case naming). Sync se obavlja batch migracijom iz SQL Server-a, lokalna izmena nije dozvoljena (RLS).';

COMMENT ON COLUMN public.bigtehn_artikli_cache.sifra_artikla IS
  'PK iz QBigTehn-a (dbo.R_Artikli."Sifra artikla", Jet type=4, Long).';
COMMENT ON COLUMN public.bigtehn_artikli_cache.bb_sifra_artikla IS
  'Sifra artikla iz BigBit master baze (BB_T_26.MDB → R_Artikli). NOT NULL u izvoru. ImportIzBB_Module.bas (legacy) održava ovu vezu.';

-- ------------------------------------------------------------
-- 6. RLS — read-only za sve authenticated; pisanje samo service_role / admin
-- ------------------------------------------------------------

ALTER TABLE public.bigtehn_artikli_cache  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bigtehn_grupa_cache    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bigtehn_podgrupa_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bigtehn_poreklo_cache  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bigtehn_tarife_cache   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bigtehn_artikli_select  ON public.bigtehn_artikli_cache;
CREATE POLICY bigtehn_artikli_select  ON public.bigtehn_artikli_cache
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS bigtehn_grupa_select    ON public.bigtehn_grupa_cache;
CREATE POLICY bigtehn_grupa_select    ON public.bigtehn_grupa_cache
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS bigtehn_podgrupa_select ON public.bigtehn_podgrupa_cache;
CREATE POLICY bigtehn_podgrupa_select ON public.bigtehn_podgrupa_cache
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS bigtehn_poreklo_select  ON public.bigtehn_poreklo_cache;
CREATE POLICY bigtehn_poreklo_select  ON public.bigtehn_poreklo_cache
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS bigtehn_tarife_select   ON public.bigtehn_tarife_cache;
CREATE POLICY bigtehn_tarife_select   ON public.bigtehn_tarife_cache
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.bigtehn_artikli_cache  TO authenticated;
GRANT SELECT ON public.bigtehn_grupa_cache    TO authenticated;
GRANT SELECT ON public.bigtehn_podgrupa_cache TO authenticated;
GRANT SELECT ON public.bigtehn_poreklo_cache  TO authenticated;
GRANT SELECT ON public.bigtehn_tarife_cache   TO authenticated;

-- ------------------------------------------------------------
-- 7. Linkovi iz Reversi modula (opciona referenca na BigTehn šifru)
--    Postojeće šifre rev_tools / rev_cutting_tool_catalog mogu da
--    optionally referenciraju master artikl preko sifra_artikla.
-- ------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='rev_tools') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='rev_tools'
                     AND column_name='bigtehn_sifra_artikla') THEN
      ALTER TABLE public.rev_tools
        ADD COLUMN bigtehn_sifra_artikla integer
          REFERENCES public.bigtehn_artikli_cache(sifra_artikla);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='rev_cutting_tool_catalog') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='rev_cutting_tool_catalog'
                     AND column_name='bigtehn_sifra_artikla') THEN
      ALTER TABLE public.rev_cutting_tool_catalog
        ADD COLUMN bigtehn_sifra_artikla integer
          REFERENCES public.bigtehn_artikli_cache(sifra_artikla);
    END IF;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS rev_tools_bigtehn_sifra_idx
  ON public.rev_tools (bigtehn_sifra_artikla)
  WHERE bigtehn_sifra_artikla IS NOT NULL;

CREATE INDEX IF NOT EXISTS rev_cts_bigtehn_sifra_idx
  ON public.rev_cutting_tool_catalog (bigtehn_sifra_artikla)
  WHERE bigtehn_sifra_artikla IS NOT NULL;
