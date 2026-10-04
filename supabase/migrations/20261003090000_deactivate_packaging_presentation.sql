create or replace function public.deactivate_packaging_presentation(
  p_presentation_id uuid,
  p_expected_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.packaging_presentation_rpc_result
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.packaging_presentations%rowtype;
begin
  if exists (
    select 1
    from public.products p
    where p.packaging_presentation_id = p_presentation_id
      and p.deleted_at is null
  ) then
    raise exception using errcode = 'P0001', message = 'PRESENTATION_IN_USE';
  end if;

  update public.packaging_presentations
  set is_active = false,
      version = version + 1,
      updated_at = now(),
      updated_by = p_actor_name,
      updated_device_name = p_device_name,
      updated_device_identifier = p_device_identifier
  where id = p_presentation_id
    and is_active
    and version = p_expected_version
  returning * into v;

  if not found then
    if exists (
      select 1
      from public.packaging_presentations
      where id = p_presentation_id
    ) then
      raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
    else
      raise exception using errcode = 'P0001', message = 'NOT_FOUND';
    end if;
  end if;

  perform public.audit_configuration_sales(
    'configuration',
    'packaging_presentations',
    v.id,
    'DEACTIVATE',
    p_actor_name,
    p_device_name,
    p_device_identifier,
    'is_active',
    'true',
    'false'
  );

  return (v.id, v.name, v.sort_order, v.is_active, v.version)::public.packaging_presentation_rpc_result;
end;
$$;

revoke all on function public.deactivate_packaging_presentation(
  uuid,
  integer,
  text,
  text,
  text
) from public;

grant execute on function public.deactivate_packaging_presentation(
  uuid,
  integer,
  text,
  text,
  text
) to anon, authenticated;
