-- "Fish Fry Friday" was seeded five days out, which landed on a Tuesday.
-- Move it to the next Friday evening in Antigua (18:00 local = 22:00 UTC).
update public.business_events e
set starts_at = f.friday + interval '22 hours',
    ends_at = f.friday + interval '26 hours'
from (
  select case
    when date_trunc('week', now()) + interval '4 days 22 hours' > now()
      then date_trunc('week', now()) + interval '4 days'
    else date_trunc('week', now()) + interval '11 days'
  end as friday
) f
where e.title = 'Fish Fry Friday'
  and e.business_id in (
    select id from public.businesses where name like 'IslandAds Demo%'
  );
