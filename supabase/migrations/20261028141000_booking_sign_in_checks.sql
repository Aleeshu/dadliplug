-- cancel_booking and answer_booking matched no row for an anonymous caller
-- (so did nothing), but answered "no such booking" instead of refusing.
-- Refuse outright, like every other guarded function
-- (scripts/check_anon_guards.py).

create or replace function public.cancel_booking(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  update public.bookings
     set status = 'cancelled', decided_at = now()
   where id = p_booking
     and customer_id = auth.uid()
     and status in ('pending', 'confirmed');
  if not found then
    raise exception 'No such booking to cancel' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.answer_booking(
  p_booking uuid,
  p_confirm boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select business_id into v_business from public.bookings
   where id = p_booking and status = 'pending';
  if v_business is null or not coalesce(public.administers(v_business), false) then
    raise exception 'No such booking waiting' using errcode = 'P0002';
  end if;
  update public.bookings
     set status = case when p_confirm then 'confirmed' else 'declined' end,
         business_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_at = now()
   where id = p_booking;
end;
$$;
