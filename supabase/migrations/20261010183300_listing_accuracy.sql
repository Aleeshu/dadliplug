-- Consolidate the duplicated listing-accuracy schema.
--
-- Two migrations landed close together and created the same things twice:
--   `closed_today` (mine) and `is_closed_today` (Gemini's)
--   `info_reports` (mine) and `listing_reports` (Gemini's)
--
-- Both sets are live in the app's data model, so this is not a case of one
-- being dead — it is a case of two names for one concept, which is worse than
-- either on its own. A later reader has no way to tell which one is
-- authoritative, and a bug fixed in one silently leaves the other broken.
--
-- Gemini's names win because the Flutter model and screens are already written
-- against them:
--   Business.isClosedToday   -> is_closed_today
--   ListingReport            -> listing_reports
--
-- The duplicates are dropped here rather than left as aliases. Two columns
-- that must be kept in sync by hand is a bug waiting to happen; the data in
-- both is empty at this point, so nothing is lost.

drop table if exists public.info_reports;

alter table public.businesses
  drop column if exists closed_today,
  drop column if exists closed_note;

-- `last_verified_at` already exists from the phase 4 migration and carries the
-- same meaning, so `closed_note` has no home and goes with the rest. If a
-- closure reason is ever wanted, it belongs in `offer` or a dedicated field
-- added deliberately rather than smuggled in alongside a boolean.
notify pgrst, 'reload schema';