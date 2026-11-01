-- =====================================================================
-- Borrar cuenta (requisito de Google Play).
--
-- Lo llama solo la Edge Function `delete-account`, con la service role:
-- ningún usuario puede ejecutarlo directamente.
--
-- purge_organization borra todos los datos de una empresa y devuelve los
-- ids de sus usuarios para que la función los elimine de Auth. Se usa
-- cuando quien borra su cuenta es el único gerente.
-- =====================================================================

create or replace function public.purge_organization(p_org uuid)
returns setof uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_people uuid[];
begin
  select coalesce(array_agg(id), '{}') into v_people
  from public.profiles where org_id = p_org;

  delete from public.work_photos where org_id = p_org;
  delete from public.time_entries where org_id = p_org;
  delete from public.swap_offers where org_id = p_org;
  delete from public.shift_requests where org_id = p_org;
  delete from public.shifts where org_id = p_org;
  delete from public.availability where employee_id = any (v_people);
  delete from public.notifications where profile_id = any (v_people);
  delete from public.notification_prefs where profile_id = any (v_people);
  delete from public.chat_messages
  where thread_id in (select id from public.chat_threads where org_id = p_org);
  delete from public.chat_members
  where thread_id in (select id from public.chat_threads where org_id = p_org);
  delete from public.chat_threads where org_id = p_org;
  delete from public.sites where org_id = p_org;
  delete from public.profiles where org_id = p_org;
  delete from public.organizations where id = p_org;

  return query select unnest(v_people);
end;
$$;

revoke execute on function public.purge_organization(uuid) from public, anon, authenticated;
grant execute on function public.purge_organization(uuid) to service_role;
