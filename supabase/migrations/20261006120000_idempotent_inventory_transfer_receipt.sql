-- Hace seguras las transiciones de estado bajo reintentos de red y asegura
-- que solo documentos de tipo TRANSFER puedan avanzar por este ciclo.
create or replace function public.mark_transfer_in_transit(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_document public.inventory_documents;
begin
  select d.* into v_document
  from public.inventory_documents d
  where d.id = p_document_id
  for update;

  if not found or v_document.document_type <> 'TRANSFER' then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_FOUND';
  end if;
  if v_document.status = 'EN_TRANSITO' then
    return;
  end if;
  if v_document.status <> 'DESPACHADA' then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DISPATCHED';
  end if;

  update public.inventory_documents
     set status = 'EN_TRANSITO'
   where id = p_document_id;
end;
$$;

revoke all on function public.mark_transfer_in_transit(uuid, text, text, text)
  from public;
grant execute on function public.mark_transfer_in_transit(uuid, text, text, text)
  to anon, authenticated;

create or replace function public.receive_transfer(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_document public.inventory_documents;
  v_line public.inventory_document_lines%rowtype;
begin
  select d.* into v_document
  from public.inventory_documents d
  where d.id = p_document_id
  for update;

  if not found or v_document.document_type <> 'TRANSFER' then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_FOUND';
  end if;
  if v_document.status = 'RECIBIDA' then
    return;
  end if;
  if v_document.status <> 'EN_TRANSITO' then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_IN_TRANSIT';
  end if;

  update public.inventory_documents
     set status = 'RECIBIDA'
   where id = p_document_id;

  for v_line in
    select l.*
      from public.inventory_document_lines l
     where l.document_id = p_document_id
     order by l.id
  loop
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id, document_line_id,
      notes
    ) values (
      v_line.product_id,
      v_document.destination_warehouse_id,
      v_document.destination_location_id,
      extensions.gen_random_uuid(),
      abs(v_line.quantity),
      'TRANSFER_IN',
      p_actor_name, p_device_name, p_device_identifier, p_document_id,
      v_line.id, v_document.document_number
    );
  end loop;
end;
$$;

revoke all on function public.receive_transfer(uuid, text, text, text)
  from public;
grant execute on function public.receive_transfer(uuid, text, text, text)
  to anon, authenticated;
