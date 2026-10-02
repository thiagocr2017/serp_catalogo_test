-- Corrección de retornos escalares con múltiples columnas (42601)
--
-- Nueve RPC de creación terminaban devolviendo una subconsulta escalar
-- con asterisco. Una subconsulta escalar debe devolver una sola columna,
-- por lo que PostgreSQL rechazaba la llamada en tiempo de ejecución con
-- "subquery must return only one column" (42601) justo después de
-- insertar la fila. Se reemplaza por select-into en una variable de tipo
-- fila y retorno de esa variable, el patrón usado por el resto de RPC.

CREATE OR REPLACE FUNCTION public.create_category(p_name text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS categories
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.categories%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.categories (
    name, created_by, created_device_name, created_device_identifier
  ) values (
    btrim(p_name), p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  select * into v_row from public.categories where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_customer(p_name text, p_phone text, p_email text, p_address text, p_tax_id text, p_credit_limit numeric, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS customers
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.customers (name, phone, email, address, tax_id, credit_limit, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_phone, p_email, p_address, p_tax_id, coalesce(p_credit_limit, 0), p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_expense(p_concept text, p_beneficiary text, p_amount numeric, p_currency_code character, p_money_account_id uuid, p_expense_date date, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS expenses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.expenses%rowtype;
begin
  if btrim(p_concept) = '' or p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.expenses (concept, beneficiary, amount, currency_code, money_account_id, expense_date, created_by, created_device_name, created_device_identifier)
  values (btrim(p_concept), p_beneficiary, p_amount, p_currency_code, p_money_account_id, p_expense_date, p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  perform public.audit_payments('payments', 'expenses', v_id, 'CREATE', p_actor_name, p_device_name, p_device_identifier, 'expense', null, p_amount::text);
  select * into v_row from public.expenses where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_inventory_count(p_warehouse_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_counts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.inventory_counts%rowtype;
begin
  insert into public.inventory_counts (warehouse_id, status, created_by, created_device_name, created_device_identifier)
  values (p_warehouse_id, 'DRAFT', p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  select * into v_row from public.inventory_counts where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_inventory_location(p_warehouse_id uuid, p_code text, p_name text, p_is_default boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_locations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.inventory_locations%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (
    select 1 from public.warehouses
    where id = p_warehouse_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'WAREHOUSE_NOT_FOUND';
  end if;
  if exists (
    select 1 from public.inventory_locations
    where warehouse_id = p_warehouse_id and code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_LOCATION_CODE';
  end if;
  if p_is_default then
    update public.inventory_locations set is_default = false
    where warehouse_id = p_warehouse_id and is_active;
  end if;
  insert into public.inventory_locations (
    warehouse_id, code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_warehouse_id, btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  select * into v_row from public.inventory_locations where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_money_account(p_name text, p_account_type text, p_currency_code character, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS money_accounts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.money_accounts%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_account_type not in ('CASH', 'BANK', 'VAULT', 'PENDING_DEPOSITS', 'OTHER') then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.money_accounts (name, account_type, currency_code, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_account_type, p_currency_code, p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  select * into v_row from public.money_accounts where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_payment_method(p_name text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS payment_methods
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.payment_methods%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.payment_methods (name, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  select * into v_row from public.payment_methods where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_product_with_initial_stock(p_product jsonb, p_initial_stock integer, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS products
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.products%rowtype;
begin
  insert into public.products (
    sku, barcode, name, description, category_id,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost,
    image_position_x, image_position_y, image_scale,
    catalog_sort_order, reorder_point,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_product->>'sku',
    p_product->>'barcode',
    p_product->>'name',
    p_product->>'description',
    (p_product->>'category_id')::uuid,
    (p_product->>'unit_price')::numeric,
    (p_product->>'package_price')::numeric,
    (p_product->>'min_order_quantity')::integer,
    (p_product->>'minimum_sale_quantity')::integer,
    (p_product->>'packaging_presentation_id')::uuid,
    (p_product->>'cbm_per_moq')::numeric,
    (p_product->>'factory_cost')::numeric,
    (p_product->>'image_position_x')::numeric,
    (p_product->>'image_position_y')::numeric,
    (p_product->>'image_scale')::numeric,
    (p_product->>'catalog_sort_order')::integer,
    (p_product->>'reorder_point')::integer,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;

  if p_initial_stock is not null and p_initial_stock <> 0 then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier
    )
    select v_id, w.id, l.id, extensions.gen_random_uuid(), p_initial_stock, 'INITIAL_STOCK',
           p_actor_name, p_device_name, p_device_identifier
    from public.warehouses w, public.inventory_locations l
    where w.is_default = true and l.is_default = true
    limit 1;
  end if;

  select * into v_row from public.products where id = v_id;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_warehouse(p_code text, p_name text, p_is_default boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS warehouses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.warehouses%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.warehouses
    where code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_WAREHOUSE_CODE';
  end if;
  if p_is_default then
    update public.warehouses set is_default = false where is_active;
  end if;
  insert into public.warehouses (
    code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  select * into v_row from public.warehouses where id = v_id;
  return v_row;
end;
$function$;
