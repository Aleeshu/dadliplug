-- Push notifications (Firebase Cloud Messaging).
--
-- Two alerts, both opt-in by their nature:
--   * a business you turned the bell on for posts an announcement;
--   * someone asks to review your business (plan.md Phase 6).
--
-- Sending is server-side only. A trigger queues the alert in push_outbox and
-- pings the `push` Edge Function, which sends whatever is queued and marks it
-- done. The function only ever sends queued rows, so calling it directly can
-- at worst deliver an alert that was already due; it cannot invent one.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- Device tokens
-- ---------------------------------------------------------------------------

create table if not exists public.push_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  platform   text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- A phone registers its own token. A token that moves to another account
-- (shared phone, new sign-in) is re-owned by whoever registered it last.
drop policy if exists push_tokens_own on public.push_tokens;
create policy push_tokens_own on public.push_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.push_tokens to authenticated;

create or replace function public.register_push_token(p_token text, p_platform text default 'android')
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  insert into public.push_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), coalesce(p_platform, 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;
grant execute on function public.register_push_token(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Outbox
-- ---------------------------------------------------------------------------

create table if not exists public.push_outbox (
  id         bigint generated always as identity primary key,
  kind       text not null check (kind in ('announcement', 'review_request')),
  ref_id     uuid not null,
  created_at timestamptz not null default now(),
  sent_at    timestamptz,
  sent_count integer,
  error      text
);

create index if not exists push_outbox_unsent_idx
  on public.push_outbox (created_at) where sent_at is null;

-- Server only.
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;

create or replace function public.queue_push()
returns trigger
language plpgsql security definer set search_path = public, extensions
as $$
begin
  insert into public.push_outbox (kind, ref_id) values (tg_argv[0], new.id);
  -- Fire and forget. If the function is down, the row waits for the next
  -- ping; nothing is lost.
  perform net.http_post(
    url := 'https://ftenxsusyuiqatnvasny.supabase.co/functions/v1/push',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return new;
end;
$$;

drop trigger if exists business_announcements_push on public.business_announcements;
create trigger business_announcements_push
  after insert on public.business_announcements
  for each row execute function public.queue_push('announcement');

drop trigger if exists review_requests_push on public.review_requests;
create trigger review_requests_push
  after insert on public.review_requests
  for each row execute function public.queue_push('review_request');
