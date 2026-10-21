-- Daily specials (plan.md section 11 and Phase 7): "catch of the day",
-- "sold out". A special lasts until midnight Antigua time; the app hides one
-- posted on an earlier island day, so nobody has to remember to take it down.

alter table public.businesses
  add column if not exists special text
    check (special is null or length(btrim(special)) between 1 and 140),
  add column if not exists special_posted_at timestamptz,
  add column if not exists special_sold_out boolean not null default false;

-- The posting time is the server's, never the client's: a phone with a wrong
-- clock, or a client that sends a date next year, cannot keep a special up.
create or replace function public.stamp_special()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.special_posted_at := case when new.special is null then null else now() end;
  elsif new.special is distinct from old.special then
    new.special_posted_at := case when new.special is null then null else now() end;
    -- A new special starts in stock.
    new.special_sold_out := false;
  else
    new.special_posted_at := old.special_posted_at;
  end if;
  if new.special is null then
    new.special_sold_out := false;
  end if;
  return new;
end;
$$;

drop trigger if exists stamp_special on public.businesses;
create trigger stamp_special
  before insert or update on public.businesses
  for each row execute function public.stamp_special();

-- Demo: today's catch at the demo kitchen, so the feature is visible.
update public.businesses
   set special = 'Catch of the day: grilled red snapper with fungee, EC$45'
 where name = 'IslandAds Demo Kitchen';
