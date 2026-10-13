alter table public.sales_invoices
  add column source_quote_id uuid references public.sales_quotes(id);

create unique index sales_invoices_source_quote_uidx
  on public.sales_invoices(source_quote_id)
  where source_quote_id is not null;

alter table public.sales_quotes
  add column converted_invoice_id uuid references public.sales_invoices(id);

create table public.sales_quote_invoice_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  invoice_id uuid references public.sales_invoices(id),
  created_at timestamptz not null default now()
);

alter table public.sales_quote_invoice_commands enable row level security;
revoke all on public.sales_quote_invoice_commands from public, anon, authenticated;

create or replace function public.create_draft_invoice_from_quote(
  p_command_id uuid,
  p_quote_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_quote public.sales_quotes%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_command public.sales_quote_invoice_commands%rowtype;
  v_claimed uuid;
  v_hash bytea := extensions.digest(
    convert_to(jsonb_build_object(
      'operation', 'create_draft_invoice_from_quote',
      'quote_id', p_quote_id
    )::text, 'UTF8'),
    'sha256'
  );
begin
  select * into v_quote
    from public.sales_quotes
   where id = p_quote_id
   for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'QUOTE_NOT_FOUND';
  end if;

  if v_quote.converted_invoice_id is not null then
    return v_quote.converted_invoice_id;
  end if;
  if v_quote.status <> 'ACCEPTED' then
    raise exception using errcode = 'P0001', message = 'QUOTE_NOT_ACCEPTED';
  end if;
  if not exists (
    select 1 from public.sales_quote_lines where quote_id = p_quote_id
  ) then
    raise exception using errcode = 'P0001', message = 'QUOTE_HAS_NO_LINES';
  end if;

  insert into public.sales_quote_invoice_commands(command_id, payload_hash)
  values (p_command_id, v_hash)
  on conflict do nothing
  returning command_id into v_claimed;
  if v_claimed is null then
    select * into v_command
      from public.sales_quote_invoice_commands
     where command_id = p_command_id
     for update;
    if v_command.payload_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_command.invoice_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    return v_command.invoice_id;
  end if;

  insert into public.sales_invoices (
    invoice_number, customer_id, customer_name, status, total_amount,
    currency_code, exchange_rate, notes, source_quote_id,
    created_by, created_device_name, created_device_identifier
  ) values (
    'FAC-' || lpad(nextval('public.sales_invoice_number_seq')::text, 6, '0'),
    v_quote.customer_id, v_quote.customer_name, 'DRAFT', v_quote.total_amount,
    v_quote.currency_code, v_quote.exchange_rate, v_quote.notes, v_quote.id,
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_invoice;

  insert into public.sales_invoice_lines (
    invoice_id, product_id, quantity, unit_price, discount_percent,
    total_price, product_sku, product_name
  )
  select v_invoice.id, line.product_id, line.quantity, line.unit_price,
         line.discount_percent, line.total_price, line.product_sku,
         line.product_name
    from public.sales_quote_lines line
   where line.quote_id = p_quote_id
   order by line.id;

  update public.sales_quotes
     set status = 'CONVERTED',
         converted_invoice_id = v_invoice.id,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_quote_id;

  update public.sales_quote_invoice_commands
     set invoice_id = v_invoice.id
   where command_id = p_command_id;

  perform public.audit_payments(
    'sales', 'sales_invoices', v_invoice.id, 'CREATE_DRAFT_FROM_QUOTE',
    p_actor_name, p_device_name, p_device_identifier,
    'source_quote_id', p_quote_id::text, v_quote.quote_number
  );

  return v_invoice.id;
end;
$$;

revoke all on function public.create_draft_invoice_from_quote(
  uuid, uuid, text, text, text
) from public, anon, authenticated;
grant execute on function public.create_draft_invoice_from_quote(
  uuid, uuid, text, text, text
) to authenticated;
