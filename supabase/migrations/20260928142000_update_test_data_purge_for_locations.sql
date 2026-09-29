create or replace function public.purge_test_data_and_go_production(
  p_actor_name text,
  p_device_identifier text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  settings_row public.app_settings%rowtype;
begin
  select * into settings_row
  from public.app_settings where id = true for update;

  if settings_row.app_mode <> 'TEST' then
    raise exception 'La aplicación ya está en modo producción';
  end if;
  if settings_row.superadmin_device_identifier is distinct from p_device_identifier then
    raise exception 'Solo el equipo superadministrador puede eliminar los datos de prueba';
  end if;

  alter table public.inventory_transactions
    disable trigger inventory_transactions_no_update_or_delete;
  delete from public.inventory_transactions;
  alter table public.inventory_transactions
    enable trigger inventory_transactions_no_update_or_delete;

  delete from public.inventory_balances;
  delete from public.audit_logs;
  delete from public.bulk_promotion_products;
  delete from public.bulk_promotion_categories;
  delete from public.bulk_promotions;
  delete from public.products;
  delete from public.categories;
  delete from storage.objects where bucket_id = 'product-images';

  update public.app_settings
  set app_mode = 'PRODUCTION',
      updated_at = now(),
      updated_by = p_actor_name,
      updated_device_identifier = p_device_identifier
  where id = true;
end;
$$;

grant execute on function public.purge_test_data_and_go_production(text, text)
  to anon, authenticated;
