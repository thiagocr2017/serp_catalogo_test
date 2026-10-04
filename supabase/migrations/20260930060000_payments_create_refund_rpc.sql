-- ============================================================
-- RPC: create_refund
--
-- La capa de datos de pagos (SupabasePaymentDataSource.createRefund)
-- invoca este RPC, pero la fundación del módulo solo había creado la
-- tabla `refunds`. Completa el contrato faltante.
--
-- Reglas (.specs/modules/payments/sdd-historical.md §7): el reembolso puede ser total o
-- parcial y nace en PENDING; la autorización del gerente y el cambio de
-- estado del pago (REFUNDED) corresponden al flujo de confirmación, que
-- se implementará con el módulo de pagos completo.
-- ============================================================

create or replace function public.create_refund(
  p_payment_id uuid,
  p_amount numeric,
  p_currency_code char(3),
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.refunds
language plpgsql security definer set search_path = '' as $$
declare
  v_payment public.payments%rowtype;
  v_refund public.refunds%rowtype;
begin
  -- Validaciones
  if p_amount is null or p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select * into v_payment
    from public.payments
   where id = p_payment_id
     for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_FOUND';
  end if;
  if v_payment.status not in ('CONFIRMED', 'REFUNDED') then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_REFUNDABLE';
  end if;

  -- Registrar reembolso (pendiente de autorización)
  insert into public.refunds (
    payment_id,
    amount,
    currency_code,
    reason,
    created_by,
    created_device_name,
    created_device_identifier
  )
  values (
    p_payment_id,
    p_amount,
    p_currency_code,
    btrim(p_reason),
    p_actor_name,
    p_device_name,
    p_device_identifier
  )
  returning * into v_refund;

  -- Auditoría
  perform public.audit_payments(
    'payments',
    'refunds',
    v_refund.id,
    'CREATE',
    p_actor_name,
    p_device_name,
    p_device_identifier,
    'refund',
    null,
    v_refund.amount::text
  );

  return v_refund;
end;
$$;

revoke all on function public.create_refund(uuid, numeric, char, text, text, text, text) from public;
grant execute on function public.create_refund(uuid, numeric, char, text, text, text, text) to anon, authenticated;
