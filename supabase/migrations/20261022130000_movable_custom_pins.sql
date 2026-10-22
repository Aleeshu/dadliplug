-- Phase 7: move and customise the map pin (plan.md section 3).
--
-- Basic and Featured: the owner moves their pin at any time and can use one
-- of their photos as the pin image, so the pin itself attracts a tap.
-- Growing: the default pin only; the team corrects its position on request.
-- A trial gets every paid tool, so a trial listing can do both.

alter table public.businesses
  add column if not exists pin_image_url text
    check (pin_image_url is null or pin_image_url ~ '^https://');

create or replace function public.protect_pin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.is_team_admin(), false) then
    return new;
  end if;
  if (new.latitude is distinct from old.latitude
      or new.longitude is distinct from old.longitude
      or new.pin_image_url is distinct from old.pin_image_url)
     and not (old.subscription_status = 'trial' or old.tier in ('basic', 'featured'))
  then
    raise exception 'Moving or customising the pin is part of Basic and Featured. Ask the Dadliplug team to move it.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_pin_fields on public.businesses;
create trigger protect_pin_fields before update on public.businesses
  for each row execute function public.protect_pin_fields();

-- The Sailing Tours demo (Featured) shows the custom pin from its own photo.
update public.businesses
   set pin_image_url = photos -> 0 ->> 'url'
 where name = 'IslandAds Demo Sailing Tours'
   and jsonb_array_length(photos) > 0;
