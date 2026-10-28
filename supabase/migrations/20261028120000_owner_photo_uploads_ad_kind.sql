-- Owners upload their own photos (2026-10-28 redesign: create-ad wizard,
-- gallery "+"), and advertisements carry a type.
--
-- Uploads: into media/business/<business id>/..., only for a business the
-- caller administers. The app resizes and compresses before uploading
-- (plan.md Phase 10, "photo cleanup on upload"); the bucket stays public
-- for reading, as listing photos are public.

drop policy if exists media_owner_insert on storage.objects;
create policy media_owner_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'business'
    and coalesce(public.administers(((storage.foldername(name))[2])::uuid), false)
  );

drop policy if exists media_owner_delete on storage.objects;
create policy media_owner_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'business'
    and coalesce(public.administers(((storage.foldername(name))[2])::uuid), false)
  );

-- The ad's type, chosen in the first step of the wizard.
alter table public.business_ads
  add column if not exists kind text not null default 'general'
    check (kind in ('special_offer', 'new_product', 'event', 'general'));

-- Existing offers are special offers.
update public.business_ads set kind = 'special_offer'
 where offer_code is not null and kind = 'general';
