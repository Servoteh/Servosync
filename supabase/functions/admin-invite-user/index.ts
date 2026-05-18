/**
 * Edge: admin-invite-user
 * Kreira Supabase Auth korisnika + user_roles red (samo admin JWT).
 *
 * Deploy: supabase functions deploy admin-invite-user
 * Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto)
 */

// @ts-ignore Deno
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type InviteBody = {
  email?: string;
  role?: string;
  full_name?: string;
  team?: string;
  project_id?: string | null;
  managed_sub_department_ids?: number[] | null;
  password?: string;
};

async function getUserFromJwt(jwt: string): Promise<{ email: string } | null> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${jwt}`, apikey: ANON_KEY || SERVICE_ROLE },
  });
  if (!res.ok) return null;
  const u = await res.json();
  const email = String(u?.email || '').toLowerCase();
  return email ? { email } : null;
}

async function isAdminEmail(email: string): Promise<boolean> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/user_roles?email=eq.${encodeURIComponent(email)}&role=eq.admin&is_active=eq.true&select=id&limit=1`,
    {
      headers: {
        apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`,
      },
    },
  );
  if (!res.ok) return false;
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0;
}

function randomPassword(len = 24): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  let out = '';
  const arr = new Uint8Array(len);
  crypto.getRandomValues(arr);
  for (let i = 0; i < len; i++) out += chars[arr[i] % chars.length];
  return out;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'method_not_allowed' }), {
      status: 405,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return new Response(JSON.stringify({ ok: false, error: 'server_misconfigured' }), {
      status: 500,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization') || '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return new Response(JSON.stringify({ ok: false, error: 'unauthorized' }), {
      status: 401,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const caller = await getUserFromJwt(jwt);
  if (!caller || !(await isAdminEmail(caller.email))) {
    return new Response(JSON.stringify({ ok: false, error: 'forbidden' }), {
      status: 403,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  let body: InviteBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: 'invalid_json' }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const email = String(body.email || '').trim().toLowerCase();
  const role = String(body.role || 'viewer').trim().toLowerCase();
  const fullName = String(body.full_name || '').trim();
  const team = String(body.team || '').trim();
  const projectId = body.project_id || null;
  const managedIds = Array.isArray(body.managed_sub_department_ids)
    ? body.managed_sub_department_ids.filter((n) => Number.isFinite(Number(n)))
    : null;
  const password = String(body.password || '').trim() || randomPassword();

  if (!email || !email.includes('@')) {
    return new Response(JSON.stringify({ ok: false, error: 'invalid_email' }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const allowedRoles = ['admin', 'hr', 'menadzment', 'pm', 'leadpm', 'viewer', 'magacioner'];
  if (!allowedRoles.includes(role)) {
    return new Response(JSON.stringify({ ok: false, error: 'invalid_role' }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const adminHeaders = {
    apikey: SERVICE_ROLE,
    Authorization: `Bearer ${SERVICE_ROLE}`,
    'Content-Type': 'application/json',
  };

  let authUserId: string | null = null;

  const createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    }),
  });

  if (createRes.ok) {
    const created = await createRes.json();
    authUserId = created?.id ?? null;
  } else {
    const errText = await createRes.text();
    if (createRes.status === 422 || errText.toLowerCase().includes('already')) {
      const listRes = await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`,
        { headers: adminHeaders },
      );
      if (listRes.ok) {
        const list = await listRes.json();
        const users = list?.users ?? list;
        if (Array.isArray(users) && users[0]?.id) authUserId = users[0].id;
      }
    }
    if (!authUserId) {
      return new Response(
        JSON.stringify({ ok: false, error: 'auth_create_failed', detail: errText.slice(0, 400) }),
        { status: 400, headers: { ...CORS, 'Content-Type': 'application/json' } },
      );
    }
  }

  const rolePayload: Record<string, unknown> = {
    email,
    role,
    project_id: projectId,
    is_active: true,
    full_name: fullName,
    team,
    must_change_password: true,
    created_by: caller.email,
    managed_sub_department_ids: role === 'menadzment' ? managedIds : null,
  };

  const insRes = await fetch(`${SUPABASE_URL}/rest/v1/user_roles`, {
    method: 'POST',
    headers: { ...adminHeaders, Prefer: 'return=representation' },
    body: JSON.stringify(rolePayload),
  });

  if (!insRes.ok) {
    const detail = await insRes.text();
    return new Response(
      JSON.stringify({ ok: false, error: 'user_roles_insert_failed', detail: detail.slice(0, 400) }),
      { status: 400, headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  }

  const rows = await insRes.json();
  const userRole = Array.isArray(rows) ? rows[0] : rows;

  return new Response(
    JSON.stringify({
      ok: true,
      auth_user_id: authUserId,
      user_role: userRole,
      temporary_password: password,
    }),
    { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } },
  );
});
