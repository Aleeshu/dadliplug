# Backend

**Supabase, linked and live.** Project `antiguamap`, ref `ftenxsusyuiqatnvasny`,
region `us-east-1`.

Schema, RLS policies, and the role-protection triggers are applied. Everything
in this file has been run against the real database, not just written down.

## Migrations

Three, applied in order:

| File | What it does |
| --- | --- |
| `20261010183000_initial_schema.sql` | Tables, indexes, updated-at triggers, profile-creation trigger |
| `20261010183100_rls_policies.sql` | Row Level Security on every table |
| `20261010183200_protect_role_column.sql` | Triggers guarding columns RLS cannot restrict |

```powershell
supabase db push --include-all
```

## Credentials

The publishable key is in `.env` (gitignored) and in `.env.example`. It is safe
to commit: it is public by design and protected by RLS, not by secrecy.

The **service_role key must never ship in the app.** It bypasses RLS entirely.
Anything the client cannot do safely goes through a Supabase Edge Function
instead.

## What was verified

Run against the live database, not assumed:

- All 7 tables exist and **RLS is enabled on every one**
- The `on_auth_user_created` trigger creates a profile with the correct display
  name and `user` role
- Anonymous REST reads are blocked
- **A signed-in user cannot promote themselves to `team_admin`**
- A user cannot rename themselves *and* escalate in one statement
- A regular user cannot insert a business
- Test artifacts deleted afterwards

## The role-protection trap

This is the one worth understanding.

An UPDATE policy can restrict **which row** a user touches. It cannot restrict
**which column**. So this policy lets a user update their own row freely:

```sql
create policy "profiles_update_own" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
```

`id = auth.uid()` passes whether they are fixing their display name or setting
`role = 'team_admin'`.

The obvious fix — `grant update (display_name)` — **does not work**. Supabase
grants table-wide `UPDATE` on `public.*` to `authenticated` by default, and a
column grant adds to that rather than subtracting from it. The escalation still
went through.

So the column is guarded by a trigger in `20261010183200_protect_role_column.sql`,
which raises unless the caller is already a team admin. Triggers run below the
policy layer and cannot be side-stepped by a permissive GRANT.

## Manual verification

`sql/verify_schema.sql` — checks RLS is on and counts policies. Run in the
Supabase SQL editor.

## What is not done yet

- **Email confirmation is enabled** and Supabase's bundled SMTP is rate-limited
  (2/hour, and only to team members). Sign-up through the app will fail for
  anyone else until real SMTP is configured. Turn off "Confirm email" in
  Authentication → Providers for development, then configure SMTP before launch.
- No seed data. The first businesses get entered by the team.
- Photo storage bucket not created.
- Review denormalisation: the client model assumes reviews sit inline on the
  business document; the schema keeps them in their own table. The Phase 5 data
  layer has to reconcile that, and it is a real decision — inline reads fast but
  duplicates, separate rows are correct but need a join.

## Before launch

- Restrict the Google Maps API key by bundle id and package name
- Configure real SMTP for confirmations and password resets
- Give the first team admin their `team_admin` role
- Decide whether the anon key stays publishable or moves to a custom header