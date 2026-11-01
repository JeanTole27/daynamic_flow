-- =====================================================================
-- Corregir un fichaje (gerente).
--
-- Para cuando alguien olvidó marcar salida o marcó a una hora equivocada.
-- Solo el gerente de la empresa, con motivo obligatorio. Queda registro de
-- quién corrigió, cuándo y por qué, y se avisa al empleado.
-- =====================================================================

alter table public.time_entries
  add column corrected_by uuid references public.profiles (id) on delete set null,
  add column corrected_at timestamptz,
  add column correction_note text check (char_length(correction_note) <= 500);

create or replace function public.fix_time_entry(
  p_entry_id uuid,
  p_clock_in timestamptz,
  p_clock_out timestamptz,
  p_note text
)
returns public.time_entries
language plpgsql security definer set search_path = ''
as $$
declare
  v_org uuid := public.current_org_id();
  v_entry public.time_entries;
  v_note text := btrim(coalesce(p_note, ''));
begin
  if not public.is_manager() then
    raise exception 'not_allowed' using errcode = 'P0001';
  end if;
  select * into v_entry from public.time_entries
  where id = p_entry_id and org_id = v_org
  for update;
  if not found then
    raise exception 'entry_not_found' using errcode = 'P0001';
  end if;
  if char_length(v_note) not between 1 and 500 then
    raise exception 'correction_note_required' using errcode = 'P0001';
  end if;
  if p_clock_in is null or p_clock_out is null
     or p_clock_out <= p_clock_in
     or p_clock_out > now() + interval '1 minute'
     or p_clock_out - p_clock_in > interval '24 hours' then
    raise exception 'invalid_entry_times' using errcode = 'P0001';
  end if;

  update public.time_entries set
    clock_in_at = p_clock_in,
    clock_out_at = p_clock_out,
    corrected_by = auth.uid(),
    corrected_at = now(),
    correction_note = v_note
  where id = v_entry.id
  returning * into v_entry;

  insert into public.notifications (profile_id, text_es, text_en) values (
    v_entry.employee_id,
    'Tu gerente corrigió tu fichaje del ' || public.shift_label(v_entry.clock_in_at, v_org) || ': ' || v_note,
    'Your manager corrected your clock-in on ' || public.shift_label(v_entry.clock_in_at, v_org) || ': ' || v_note
  );
  return v_entry;
end;
$$;

revoke execute on function public.fix_time_entry(uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.fix_time_entry(uuid, timestamptz, timestamptz, text) to authenticated;
