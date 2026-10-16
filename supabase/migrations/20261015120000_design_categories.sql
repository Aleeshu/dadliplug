-- The nine categories from the Dadliplug design replace the prototype's eight.
--
-- Old -> new:
--   food         -> food
--   retail       -> shopping
--   trades       -> services
--   professional -> services
--   beauty       -> health_beauty
--   medical      -> health_beauty
--   tourism      -> entertainment
--   online       -> other
--
-- "online" was also how the app decided a listing had no map pin. That is now
-- decided by the listing having no coordinates, whatever its category.
--
-- The column was free text, so a typo filed a listing under nothing in
-- particular with no error. It is now CHECK-constrained, the same lesson as
-- subscription_status (20261012170000).

update public.businesses set category = case category
  when 'retail' then 'shopping'
  when 'trades' then 'services'
  when 'professional' then 'services'
  when 'beauty' then 'health_beauty'
  when 'medical' then 'health_beauty'
  when 'tourism' then 'entertainment'
  when 'online' then 'other'
  else category
end;

-- Anything still outside the new set was never a valid category. "Other"
-- rather than a guess at a real industry.
update public.businesses
set category = 'other'
where category not in (
  'food', 'shopping', 'services', 'health_beauty', 'entertainment',
  'automotive', 'real_estate', 'education', 'other'
);

alter table public.businesses
  add constraint businesses_category_check check (category in (
    'food', 'shopping', 'services', 'health_beauty', 'entertainment',
    'automotive', 'real_estate', 'education', 'other'
  ));
