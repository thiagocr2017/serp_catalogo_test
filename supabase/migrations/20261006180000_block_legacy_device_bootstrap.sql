-- Keep destructive installation operations unavailable until Auth bootstrap
-- replaces the legacy device-identity flow.
revoke all on function public.claim_local_superadmin(text)
  from public, anon, authenticated;

revoke all on function public.purge_test_data_and_go_production(text, text)
  from public, anon, authenticated;
