revoke insert, update, delete, truncate, references, trigger
on table public.sales_agents
from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
on table public.catalog_agents
from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
on table public.packaging_presentations
from anon, authenticated;

grant select on table public.sales_agents to anon, authenticated;
grant select on table public.catalog_agents to anon, authenticated;
grant select on table public.packaging_presentations to anon, authenticated;
