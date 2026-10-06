-- Despachar un traslado debe crear la salida de stock en la misma transaccion.
-- La confirmacion del borrador es el punto unico que valida el documento,
-- registra TRANSFER_OUT y avanza a DESPACHADA.
create or replace function public.dispatch_transfer(
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

  -- Un reintento tras respuesta perdida no debe duplicar la salida.
  if v_document.status = 'DESPACHADA' then
    return;
  end if;
  if v_document.status <> 'BORRADOR' then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DRAFT';
  end if;

  perform public.confirm_inventory_document(
    p_document_id,
    p_actor_name,
    p_device_name,
    p_device_identifier
  );
end;
$$;

revoke all on function public.dispatch_transfer(uuid, text, text, text)
  from public;
grant execute on function public.dispatch_transfer(uuid, text, text, text)
  to anon, authenticated;
