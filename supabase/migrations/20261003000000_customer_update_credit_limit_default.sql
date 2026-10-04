-- Empty credit limit means "without credit limit" and must persist as 0.
-- create_customer already coalesces NULL to 0; update_customer must match it.

create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.customers
     set name = btrim(p_name),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = coalesce(p_credit_limit, 0),
         province = nullif(btrim(p_province), ''),
         gira = nullif(btrim(p_gira), ''),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text, text, text) to anon, authenticated;
