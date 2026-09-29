create trigger warehouses_audit
after insert or update on public.warehouses
for each row execute function public.write_audit_log();

create trigger inventory_locations_audit
after insert or update on public.inventory_locations
for each row execute function public.write_audit_log();
