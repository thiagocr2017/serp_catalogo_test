-- Sales return preview requires an authenticated application session.
revoke all on function public.sales_preview_return(uuid) from public, anon;
grant execute on function public.sales_preview_return(uuid) to authenticated;
