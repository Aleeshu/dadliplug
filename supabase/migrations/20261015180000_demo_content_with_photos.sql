-- Richer demo content: real photos, proper advertisements, offers and events,
-- so the redesigned screens can be judged as they will look with a real
-- business on them.
--
-- Still demo data, still labelled as such, still removed with:
--   delete from public.businesses where name like 'IslandAds Demo%';
-- (ads and events cascade with the business).
--
-- Photos are freely licensed from Wikimedia Commons, hosted in the public
-- `media` bucket, and credited where they appear. None is presented as the
-- demo business's own premises except where it is a public place (Dickenson
-- Bay, St. John's Public Market).

do $$
declare
  media constant text :=
    'https://ftenxsusyuiqatnvasny.supabase.co/storage/v1/object/public/media/demo/';
  kitchen uuid;
  salon uuid;
  today timestamptz := date_trunc('day', now());
begin
  select id into kitchen from public.businesses where name = 'IslandAds Demo Kitchen';
  select id into salon from public.businesses where name = 'IslandAds Demo Salon';
  if kitchen is null or salon is null then
    return; -- not a database with the demo seed
  end if;

  -- -------------------------------------------------------------------------
  -- Listings
  -- -------------------------------------------------------------------------

  update public.businesses set
    description =
      'Beachfront Caribbean kitchen on Dickenson Bay: jerk chicken off the '
      'drum, grilled catch of the day, fungee and saltfish, and cold Wadadli '
      'at sunset. Demo listing for testing Dadliplug, not a real business.',
    -- On the bay, where the listing says it is. The old pin sat inland.
    latitude = 17.1563,
    longitude = -61.8466,
    photos = jsonb_build_array(
      jsonb_build_object('url', media || 'kitchen_bay.jpg',
        'caption', 'Dickenson Bay. Photo: Paul Kowalow, CC BY-SA 3.0'),
      jsonb_build_object('url', media || 'kitchen_plate.jpg',
        'caption', 'Photo: Mulling it Over, CC BY-SA 2.0'),
      jsonb_build_object('url', media || 'kitchen_jerk.jpg',
        'caption', 'Photo: Jon Sullivan, public domain')
    ),
    menu = jsonb_build_array(
      jsonb_build_object('name', 'Jerk chicken plate',
        'detail', 'Rice and peas, slaw, plantain', 'price', 'EC$38'),
      jsonb_build_object('name', 'Grilled catch of the day',
        'detail', 'Lime butter, seasoned rice, salad', 'price', 'EC$55'),
      jsonb_build_object('name', 'Fungee and saltfish',
        'detail', 'The national dish, Saturdays', 'price', 'EC$35'),
      jsonb_build_object('name', 'Wadadli beer', 'price', 'EC$10')
    ),
    price_range = 'EC$25-60'
  where id = kitchen;

  update public.businesses set
    description =
      'Braids, twists, cuts and colour in the heart of St. John''s. Walk-ins '
      'welcome before noon. Demo listing for testing Dadliplug, not a real '
      'business.',
    photos = jsonb_build_array(
      jsonb_build_object('url', media || 'salon_interior.jpg',
        'caption', 'Photo: Daderot, CC0')
    ),
    menu = jsonb_build_array(
      jsonb_build_object('name', 'Box braids', 'detail', 'Shoulder length', 'price', 'EC$180'),
      jsonb_build_object('name', 'Wash and style', 'price', 'EC$60'),
      jsonb_build_object('name', 'Kids'' cut', 'detail', 'Under 12', 'price', 'EC$35')
    )
  where id = salon;

  -- -------------------------------------------------------------------------
  -- Advertisements and offers
  -- -------------------------------------------------------------------------

  -- The running lunch ad becomes a proper offer with a till code.
  update public.business_ads set
    title = 'Jerk Chicken Lunch Special',
    body = 'Jerk chicken plate with rice and peas and a drink, EC$30 weekdays '
      '11am to 3pm. Say the code at the till.'
      || E'\n\nPhoto: Jon Sullivan, public domain',
    image_url = media || 'kitchen_jerk.jpg',
    offer_code = 'LUNCH30'
  where business_id = kitchen and ends_at is null;

  if not exists (
    select 1 from public.business_ads
    where business_id = kitchen and title = 'Sunset Happy Hour'
  ) then
    insert into public.business_ads
      (business_id, title, body, image_url, starts_at, ends_at, offer_code)
    values (
      kitchen,
      'Sunset Happy Hour',
      'Two Wadadli for EC$15 from 5pm until the sun is down. Every day this '
      'month.' || E'\n\nPhoto: Roger Green, CC BY-SA 4.0',
      media || 'sunset_eden.jpg',
      now() - interval '1 day',
      today + interval '30 days',
      'SUNSET15'
    );
  end if;

  -- The salon is on Basic, so its ad has no offer code (a Featured perk).
  if not exists (
    select 1 from public.business_ads
    where business_id = salon and title = 'Back-to-School Braids'
  ) then
    insert into public.business_ads (business_id, title, body, image_url, starts_at)
    values (
      salon,
      'Back-to-School Braids',
      'Neat, long-lasting braids for the new term. Book on WhatsApp and come '
      'in before 10am for the quickest chair.' || E'\n\nPhoto: Daderot, CC0',
      media || 'salon_interior.jpg',
      now() - interval '2 days'
    );
  end if;

  -- -------------------------------------------------------------------------
  -- Events. Times are Antigua evenings: 18:00 in Antigua is 22:00 UTC.
  -- -------------------------------------------------------------------------

  -- Featured flags are the team's to set; the guard trigger would undo them
  -- here, so it is paused for this block.
  alter table public.business_events disable trigger business_events_protect_featured;

  update public.business_events set
    title = 'Fish Fry Friday',
    body = 'Fresh catch fried to order, johnny cakes, steel pan from 7pm and '
      'a children''s corner. Bring the family.'
      || E'\n\nDemo event. Photo: Mulling it Over, CC BY-SA 2.0',
    starts_at = today + interval '5 days 22 hours',
    ends_at = today + interval '6 days 2 hours',
    location_note = 'Dickenson Bay',
    image_url = media || 'kitchen_plate.jpg',
    tags = array['Food', 'Music', 'Family Friendly'],
    organizer = 'IslandAds Demo Kitchen',
    latitude = 17.1563, longitude = -61.8466,
    phone = '+1 268 555 0100'
  where business_id = kitchen;

  if not exists (select 1 from public.business_events where title = 'Reggae on the Beach') then
    insert into public.business_events
      (business_id, title, body, starts_at, ends_at, location_note, image_url,
       tags, organizer, website, phone, latitude, longitude, is_featured)
    values (
      kitchen,
      'Reggae on the Beach',
      'A night of great music, food and Caribbean vibes at Dickenson Bay. '
      'Local artists, food vendors and more.'
        || E'\n\nDemo event. Photo: Roger Green, CC BY-SA 4.0',
      today + interval '9 days 22 hours',
      today + interval '10 days 3 hours',
      'Dickenson Bay, Antigua',
      media || 'sunset_eden.jpg',
      array['Music', 'Food', 'Entertainment'],
      'Antigua Events Co. (demo)',
      'example.com',
      '+1 268 555 0123',
      17.1563, -61.8466,
      true
    );
  end if;

  update public.business_events set
    title = 'Braids & Beauty Pop-up',
    body = 'Quick braids, nail art and styling tips at the salon. Walk-ins '
      'welcome.' || E'\n\nDemo event. Photo: Daderot, CC0',
    starts_at = today + interval '4 days 14 hours',
    ends_at = today + interval '4 days 19 hours',
    location_note = 'St. John''s',
    image_url = media || 'salon_interior.jpg',
    tags = array['Beauty', 'Local'],
    organizer = 'IslandAds Demo Salon'
  where business_id = salon;

  if not exists (select 1 from public.business_events where title = 'Local Art & Craft Market') then
    insert into public.business_events
      (business_id, title, body, starts_at, ends_at, location_note, image_url,
       tags, organizer, latitude, longitude, is_featured)
    values (
      salon,
      'Local Art & Craft Market',
      'Island-made crafts, art, preserves and fresh produce under one roof. '
      'Support local makers.'
        || E'\n\nDemo event. Photo: David Stanley, CC BY 2.0',
      today + interval '12 days 13 hours',
      today + interval '12 days 20 hours',
      'St. John''s Public Market',
      media || 'market_stjohns.jpg',
      array['Shopping', 'Art', 'Local'],
      'St. John''s Craft Collective (demo)',
      17.1170, -61.8460,
      true
    );
  end if;

  alter table public.business_events enable trigger business_events_protect_featured;
end;
$$;
