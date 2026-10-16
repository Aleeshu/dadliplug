-- Bulletin Board post types, from the Dadliplug design: each announcement is
-- an important update (closures, road works), a special offer, community news,
-- or ordinary business news. Drives the coloured label on the card.
alter table public.business_announcements
  add column if not exists kind text not null default 'business';

alter table public.business_announcements
  drop constraint if exists business_announcements_kind;
alter table public.business_announcements
  add constraint business_announcements_kind
  check (kind in ('important', 'offer', 'community', 'business'));

-- The demo closure notice is the important kind.
update public.business_announcements a
set kind = 'important'
from public.businesses b
where b.id = a.business_id
  and b.name like 'IslandAds Demo%'
  and a.title ilike '%closed%';
