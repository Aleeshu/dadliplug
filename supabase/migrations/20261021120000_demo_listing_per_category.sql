-- One demo listing for every category, so each Categories row, filter chip
-- and leaderboard has something real-looking to show.
--
-- Same rules as the first seed (20261012160000): only on a database with the
-- demo seed already present (never alongside real customers), names start
-- 'IslandAds Demo' so they come out with
--   delete from public.businesses where name like 'IslandAds Demo%';
-- and every description says it is a demo. Phone numbers are 555 numbers.
-- Photos are freely licensed (Wikimedia Commons) and credited in captions;
-- none shows an identifiable real business as if it were the demo's own.
--
-- The set deliberately covers the cases the app treats differently: one
-- Featured, Basic and Growing plans, an online-only business with no pin
-- (Other), and a listing with no ratings yet.

do $$
declare
  media constant text :=
    'https://ftenxsusyuiqatnvasny.supabase.co/storage/v1/object/public/media/demo/';
begin
  if not exists (select 1 from public.businesses where name = 'IslandAds Demo Kitchen') then
    return; -- not a demo database
  end if;

  insert into public.businesses (
    name, category, area, description, tier, subscription_status,
    address, how_to_find_us, latitude, longitude, phone, whatsapp, website,
    hours, price_range, tags, seeded_rating, seeded_review_count,
    views, calls, whatsapp_taps, created_at, last_verified_at, photos, menu
  )
  select v.* from (values
    (
      'IslandAds Demo Boutique', 'shopping', 'Heritage Quay, St. John''s',
      'Island-made clothing, straw bags and gifts, two minutes from the cruise '
      'pier. Demo listing for testing Dadliplug, not a real business.',
      'basic', 'basic',
      'Heritage Quay', 'Ground floor, by the clock tower', 17.1215, -61.8466,
      '+1 268 555 0110', '+12685550110', null,
      '{"days":[1,2,3,4,5,6],"opensAt":9,"closesAt":18}'::jsonb, 'EC$20-150',
      array['accepts_cards', 'accepts_usd'], 4.4, 18, 920, 31, 58,
      now() - interval '120 days', now() - interval '5 days',
      jsonb_build_array(jsonb_build_object('url', media || 'shop_heritage.jpg',
        'caption', 'Heritage Quay. Photo: UKWiki, public domain')),
      jsonb_build_array(
        jsonb_build_object('name', 'Batik sarong', 'price', 'EC$65'),
        jsonb_build_object('name', 'Woven straw tote', 'price', 'EC$90'),
        jsonb_build_object('name', 'Island-print T-shirt', 'price', 'EC$45'))
    ),
    (
      'IslandAds Demo Handyman', 'services', 'All Saints',
      'Plumbing, carpentry, tiling and hurricane shutters. Free quotes across '
      'the island. Demo listing for testing Dadliplug, not a real business.',
      'growing', 'growing',
      null, 'Call ahead: we come to you', 17.0602, -61.7934,
      '+1 268 555 0120', '+12685550120', null,
      '{"days":[1,2,3,4,5,6],"opensAt":7,"closesAt":16}'::jsonb, 'EC$80+',
      array['cash_only'], 4.7, 23, 640, 77, 102,
      now() - interval '200 days', now() - interval '9 days',
      jsonb_build_array(jsonb_build_object('url', media || 'services_level.jpg',
        'caption', 'Photo: Shixart1985, CC BY 2.0')),
      jsonb_build_array(
        jsonb_build_object('name', 'Leak repair', 'detail', 'Call-out included', 'price', 'EC$120'),
        jsonb_build_object('name', 'Hurricane shutters', 'detail', 'Per window, fitted', 'price', 'EC$350'),
        jsonb_build_object('name', 'Tiling', 'detail', 'Per square metre', 'price', 'EC$75'))
    ),
    (
      'IslandAds Demo Sailing Tours', 'entertainment', 'English Harbour',
      'Half-day sails and sunset cruises from Nelson''s Dockyard, snorkel stop '
      'included. Demo listing for testing Dadliplug, not a real business.',
      'featured', 'featured',
      'Nelson''s Dockyard', 'Meet at the dockyard gate, 15 minutes early', 17.0072, -61.7623,
      '+1 268 555 0130', '+12685550130', 'https://example.com',
      '{"days":[1,2,3,4,5,6,7],"opensAt":8,"closesAt":18}'::jsonb, 'US$60-120',
      array['accepts_usd', 'accepts_cards', 'family_friendly'], 4.9, 57, 2310, 64, 188,
      now() - interval '300 days', now() - interval '3 days',
      jsonb_build_array(jsonb_build_object('url', media || 'tour_dockyard.jpg',
        'caption', 'Nelson''s Dockyard. Photo: Thank You (23 Millions+) views, CC BY 2.0')),
      jsonb_build_array(
        jsonb_build_object('name', 'Half-day sail', 'detail', 'With snorkel stop', 'price', 'US$75'),
        jsonb_build_object('name', 'Sunset cruise', 'detail', 'Drinks included', 'price', 'US$60'),
        jsonb_build_object('name', 'Private charter', 'detail', 'Up to 8 people', 'price', 'US$650'))
    ),
    (
      'IslandAds Demo Auto Care', 'automotive', 'Friars Hill Road',
      'Servicing, tyres, brakes and AC for every make. Rental cars on request. '
      'Demo listing for testing Dadliplug, not a real business.',
      'basic', 'basic',
      'Friars Hill Road', 'Opposite the gas station, blue gate', 17.1295, -61.8305,
      '+1 268 555 0140', '+12685550140', null,
      '{"days":[1,2,3,4,5,6],"opensAt":8,"closesAt":17}'::jsonb, 'EC$60+',
      array['accepts_cards', 'parking'], 4.3, 12, 410, 52, 39,
      now() - interval '150 days', now() - interval '12 days',
      jsonb_build_array(jsonb_build_object('url', media || 'auto_tools.jpg',
        'caption', 'Photo: ProjectManhattan, CC BY-SA 3.0')),
      jsonb_build_array(
        jsonb_build_object('name', 'Oil change', 'price', 'EC$150'),
        jsonb_build_object('name', 'AC regas', 'price', 'EC$220'),
        jsonb_build_object('name', 'Car rental', 'detail', 'Per day', 'price', 'US$55'))
    ),
    (
      'IslandAds Demo Realty', 'real_estate', 'Falmouth',
      'Long-term rentals, villa sales and property management around Falmouth '
      'and English Harbour. Demo listing for testing Dadliplug, not a real '
      'business.',
      'basic', 'basic',
      'Falmouth Main Road', 'Upstairs, above the pharmacy', 17.0185, -61.7795,
      '+1 268 555 0150', '+12685550150', 'https://example.com',
      '{"days":[1,2,3,4,5],"opensAt":9,"closesAt":17}'::jsonb, null,
      array['accepts_usd'], 4.8, 9, 530, 18, 47,
      now() - interval '90 days', now() - interval '6 days',
      jsonb_build_array(jsonb_build_object('url', media || 'estate_hilltop.jpg',
        'caption', 'Above English Harbour. Photo: Vincent van Zeijst, CC BY-SA 4.0')),
      jsonb_build_array(
        jsonb_build_object('name', 'Two-bed apartment, Falmouth', 'detail', 'Monthly', 'price', 'EC$3,800'),
        jsonb_build_object('name', 'Property management', 'detail', 'Of monthly rent', 'price', '10%'))
    ),
    (
      'IslandAds Demo Academy', 'education', 'St. John''s',
      'After-school lessons in maths and English, CSEC prep, and evening '
      'computer classes for adults. Demo listing for testing Dadliplug, not a '
      'real business.',
      'growing', 'growing',
      'Factory Road', 'Second building on the left', 17.1255, -61.8395,
      '+1 268 555 0160', '+12685550160', null,
      '{"days":[1,2,3,4,5],"opensAt":8,"closesAt":20}'::jsonb, 'EC$40/class',
      array['wifi', 'accessibility'], 4.6, 15, 380, 22, 61,
      now() - interval '60 days', now() - interval '4 days',
      jsonb_build_array(jsonb_build_object('url', media || 'edu_hall.jpg',
        'caption', 'Photo: Paul The Writer, CC0')),
      jsonb_build_array(
        jsonb_build_object('name', 'CSEC maths prep', 'detail', '10 weeks', 'price', 'EC$450'),
        jsonb_build_object('name', 'Adult computer basics', 'detail', '6 evenings', 'price', 'EC$300'))
    ),
    (
      'IslandAds Demo Online Store', 'other', 'Island-wide delivery',
      'Phone accessories and electronics, ordered on WhatsApp and delivered '
      'across Antigua next day. Online only, so no pin on the map. Demo '
      'listing for testing Dadliplug, not a real business.',
      'basic', 'basic',
      null, null, null, null,
      '+1 268 555 0170', '+12685550170', 'https://example.com',
      '{"days":[1,2,3,4,5,6,7],"opensAt":8,"closesAt":20}'::jsonb, 'EC$15-400',
      array['accepts_cards'], 0, 0, 120, 4, 33,
      -- New, and with no ratings: the "no rating yet" case.
      now() - interval '5 days', now() - interval '1 day',
      jsonb_build_array(jsonb_build_object('url', media || 'other_laptop.jpg',
        'caption', 'Photo: Shixart1985, CC BY 2.0')),
      jsonb_build_array(
        jsonb_build_object('name', 'Phone case', 'price', 'EC$35'),
        jsonb_build_object('name', 'Fast charger', 'price', 'EC$60'),
        jsonb_build_object('name', 'Island-wide delivery', 'price', 'EC$15'))
    )
  ) as v
  where not exists (select 1 from public.businesses b where b.name = v.column1);

  -- An offer from the Featured one, and an event, so they show up in Offers
  -- and on the calendar.
  insert into public.business_ads (business_id, title, body, image_url, starts_at, offer_code)
  select b.id, 'Sunset Cruise: Kids Sail Free',
    'One child free with every paying adult on the sunset cruise this month. '
    'Mention the code when you book.'
      || E'\n\nPhoto: Thank You (23 Millions+) views, CC BY 2.0',
    media || 'tour_dockyard.jpg', now() - interval '1 day', 'KIDSFREE'
  from public.businesses b
  where b.name = 'IslandAds Demo Sailing Tours'
    and not exists (select 1 from public.business_ads a where a.business_id = b.id);

  insert into public.business_events
    (business_id, title, body, starts_at, ends_at, location_note, image_url,
     tags, organizer, latitude, longitude)
  select b.id, 'Sunset Sail from the Dockyard',
    'Two hours along the south coast as the sun goes down, with rum punch and '
    'steel pan on deck.' || E'\n\nDemo event. Photo: Thank You (23 Millions+) views, CC BY 2.0',
    date_trunc('day', now()) + interval '6 days 21 hours',
    date_trunc('day', now()) + interval '6 days 23 hours',
    'Nelson''s Dockyard, English Harbour', media || 'tour_dockyard.jpg',
    array['Music', 'Family Friendly'], 'IslandAds Demo Sailing Tours',
    17.0072, -61.7623
  from public.businesses b
  where b.name = 'IslandAds Demo Sailing Tours'
    and not exists (select 1 from public.business_events e where e.business_id = b.id);

  -- The team admin can open every demo's business tools, as with the first two.
  alter table public.profiles disable trigger profiles_protect_role;
  update public.profiles p
  set business_ids = (
    select array(
      select distinct unnest(coalesce(p.business_ids, '{}') || (
        select coalesce(array_agg(b.id), '{}') from public.businesses b
        where b.name like 'IslandAds Demo%'
      ))
    )
  )
  where p.role = 'team_admin';
  alter table public.profiles enable trigger profiles_protect_role;
end;
$$;
