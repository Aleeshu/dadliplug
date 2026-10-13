-- Separated out from the team-admin bootstrap on purpose.
--
-- This is a DEVELOPMENT convenience and it changes who is allowed in, so it
-- does not belong quietly beside a security fix.
--
-- What it does: stamps `email_confirmed_at` on every new account, so sign-up
-- never depends on a confirmation email arriving.
--
-- Why that was needed: Supabase's bundled SMTP is rate-limited to roughly two
-- emails an hour and only delivers to team members. With email confirmation
-- enabled, sign-up either takes an hour or never completes, which makes the
-- app impossible to test with real accounts.
--
-- WHAT IT COSTS, and this is the part that matters:
--
--   * Anyone can register using an email address they do not own. An attacker
--     could register `maria@somebar.com` and then, if that business ever claims
--     its listing, appear to be that business.
--   * The app's trust story leans on verified visits, which lean on verified
--     accounts. Unverified email quietly undermines that chain.
--   * This applies to production as well as development. There is no
--     environment check in it.
--
-- SO: remove this file, or gate it, before launch. If confirmation emails are
-- wanted in production, the answer is a real SMTP provider (Resend, Postmark,
-- SES) configured in the Supabase dashboard — not this trigger.
--
-- Until then, it is the only way to create accounts for testing on a project
-- whose mail quota is exhausted.

create or replace function public.auto_confirm_email()
returns trigger
language plpgsql
security definer set search_path = auth
as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end;
$$;

create trigger auto_confirm_on_signup
  before insert on auth.users
  for each row execute function public.auto_confirm_email();

-- Confirm accounts created while this was pending.
update auth.users
set email_confirmed_at = now()
where email_confirmed_at is null;