create or replace function public.apply_inventory_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.inventory_balances (
    product_id, warehouse_id, location_id, quantity, updated_at
  ) values (
    new.product_id, new.warehouse_id, new.location_id, new.quantity, now()
  )
  on conflict (product_id, location_id) do update
    set quantity = public.inventory_balances.quantity + excluded.quantity,
        warehouse_id = excluded.warehouse_id,
        updated_at = now();

  update public.products
     set current_stock = current_stock + new.quantity,
         updated_by = coalesce(new.actor_name, 'device:' || new.device_identifier),
         updated_device_name = new.device_name,
         updated_device_identifier = new.device_identifier
   where id = new.product_id;

  if not found then
    raise exception 'El producto % no existe', new.product_id;
  end if;

  return new;
end;
$$;

revoke insert, update, delete on public.inventory_balances
  from anon, authenticated;
