-- =====================================================================
-- Registro de gerentes desde la app.
--
-- Un usuario recién registrado (sin perfil) crea su organización y queda
-- como su gerente activo. Los empleados siguen entrando solo por
-- invitación: la Edge Function `invite-employee` les crea el perfil en la
-- organización del gerente, así que nunca llegan aquí sin perfil.
-- =====================================================================

create or replace function public.create_organization(
  p_org_name text,
  p_full_name text,
  p_timezone text default 'America/Bogota'
)
returns public.profiles
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_org_name text := btrim(coalesce(p_org_name, ''));
  v_full_name text := btrim(coalesce(p_full_name, ''));
  v_timezone text := coalesce(nullif(btrim(p_timezone), ''), 'America/Bogota');
  v_org uuid;
  v_profile public.profiles;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  -- Un usuario pertenece a una sola organización. Un invitado ya tiene
  -- perfil, así que no puede crearse otra empresa.
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'already_registered' using errcode = 'P0001';
  end if;
  if char_length(v_org_name) not between 1 and 120 then
    raise exception 'invalid_org_name' using errcode = 'P0001';
  end if;
  if char_length(v_full_name) not between 1 and 120 then
    raise exception 'invalid_name' using errcode = 'P0001';
  end if;
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = v_timezone) then
    v_timezone := 'America/Bogota';
  end if;

  select email into v_email from auth.users where id = v_uid;

  insert into public.organizations (name, timezone)
  values (v_org_name, v_timezone)
  returning id into v_org;

  insert into public.profiles (id, org_id, full_name, email, role, status)
  values (v_uid, v_org, v_full_name, coalesce(v_email, ''), 'manager', 'active')
  returning * into v_profile;

  insert into public.chat_threads (org_id, is_general, name)
  values (v_org, true, 'General');

  return v_profile;
end;
$$;

revoke execute on function public.create_organization(text, text, text) from public, anon;
grant execute on function public.create_organization(text, text, text) to authenticated;
