-- Remove leftover MCP/smoke test tables (public, RLS disabled; security advisor rls_disabled_in_public)
DROP TABLE IF EXISTS public._mcp_sql_chunk CASCADE;
DROP TABLE IF EXISTS public._smoke_mcp_b64 CASCADE;
