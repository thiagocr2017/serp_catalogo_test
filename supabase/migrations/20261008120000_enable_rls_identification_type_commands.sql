-- This table is private idempotency state used only by SECURITY DEFINER RPCs.
-- Keep RLS enabled without client policies and without direct client grants.
alter table public.identification_type_create_commands enable row level security;

revoke all on public.identification_type_create_commands
  from public, anon, authenticated;
