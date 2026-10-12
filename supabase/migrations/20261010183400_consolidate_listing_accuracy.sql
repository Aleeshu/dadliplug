-- Consolidate the duplicated listing-accuracy schema.
--
-- Two migrations landed close together and created the same things twice:
--   `closed_today` (20261010183300) and `is_closed_today` (20261011190000)
--   `info_reports` (20261010183300) and `listing_reports` (20261011190000)
--
-- Both sets are live in the Flutter model, so this is not one being dead — it
-- is two names for one concept, which is worse than either alone. A later
-- reader cannot tell which is authoritative, and a bug fixed in one silently
-- leaves the other broken.
--
-- The phase 4 names win: the model and screens are already written against
-- `Business.isClosedToday` and `ListingReport`.
--
-- The duplicates are dropped rather than kept as aliases. Two columns that
-- must be hand-synchronised is a bug waiting to happen, and both are empty.

drop table if exists public.info_reports;

alter table public.businesses
  drop column if exists closed_today,
  drop column if exists closed_note;

-- `closed_note` had no home after this. If a closure reason is ever wanted it
-- belongs in a deliberate column, not smuggled in beside a boolean.
notify pgrst, 'reload schema';