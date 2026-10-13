-- Social accounts on a listing.
--
-- plan.md 4 lists "other socials" as part of what a customer sees on a business
-- profile. For most Antigua businesses this is how they are actually reachable
-- — a phone number is optional in a way an Instagram handle is not.
--
-- Stored as bare handles rather than full URLs. A business should not be able
-- to render "javascript:" into the app, and normalising on write means the
-- client can build a link without parsing.

alter table public.businesses
  add column if not exists instagram text,
  add column if not exists facebook text,
  add column if not exists tiktok text,
  add column if not exists whatsapp_business text;

comment on column public.businesses.instagram is
  'Bare handle without the @. Display only; the app builds the link.';

comment on column public.businesses.facebook is
  'Page or profile name without the URL. Display only.';

comment on column public.businesses.tiktok is
  'Bare handle without the @. Display only.';

comment on column public.businesses.whatsapp_business is
  'Separate from the customer-facing whatsapp number: this is the line a '
  'customer messages about a booking or an event.';