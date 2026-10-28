-- The community bulletin board (Business Plan 2): Jobs, Items for Sale,
-- Community Notices and Business Opportunities.
--
-- plan.md 14a warned that boards like this bring scams and a moderation
-- load, so: posts wait for the team before going live, expire after 30
-- days, a person may have at most 5 open (pending or live) at once, and
-- anyone signed in can report a live post. "Featured" (paid promotion of a
-- commercial post) is set by the team only.

create table if not exists public.community_posts (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null check (kind in ('job', 'for_sale', 'notice', 'opportunity')),
  title       text not null check (length(btrim(title)) between 3 and 80),
  body        text not null check (length(btrim(body)) between 10 and 1000),
  price_ec    numeric(10, 2) check (price_ec is null or price_ec >= 0),
  area        text not null default '' check (length(area) <= 60),
  contact     text not null check (length(btrim(contact)) between 5 and 60),
  image_url   text check (image_url is null or image_url ~ '^https://'),
  author_id   uuid not null references auth.users (id) on delete cascade,
  status      text not null default 'pending'
                check (status in ('pending', 'live', 'rejected', 'removed')),
  status_note text check (status_note is null or length(status_note) <= 300),
  featured    boolean not null default false,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '30 days',
  decided_by  uuid references auth.users (id) on delete set null,
  decided_at  timestamptz
);

create index if not exists community_posts_live_idx
  on public.community_posts (status, kind, created_at desc);

alter table public.community_posts enable row level security;

-- The public sees live, unexpired posts; authors see their own; the team all.
drop policy if exists community_posts_read on public.community_posts;
create policy community_posts_read on public.community_posts for select
  using (
    (status = 'live' and expires_at > now())
    or author_id = auth.uid()
    or coalesce(public.is_team_admin(), false)
  );

drop policy if exists community_posts_insert on public.community_posts;
create policy community_posts_insert on public.community_posts for insert
  to authenticated
  with check (author_id = auth.uid());

-- An author may take their own post down; only the team decides the rest.
drop policy if exists community_posts_author_delete on public.community_posts;
create policy community_posts_author_delete on public.community_posts for delete
  using (author_id = auth.uid());

drop policy if exists community_posts_team on public.community_posts;
create policy community_posts_team on public.community_posts for update
  using (coalesce(public.is_team_admin(), false))
  with check (coalesce(public.is_team_admin(), false));

-- Whatever a client sends, a new post starts pending, unfeatured, for 30
-- days, and a person cannot flood the board.
create or replace function public.guard_community_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.is_team_admin(), false) then
    return new;
  end if;
  new.status := 'pending';
  new.featured := false;
  new.status_note := null;
  new.decided_by := null;
  new.decided_at := null;
  new.created_at := now();
  new.expires_at := now() + interval '30 days';
  if (select count(*) from public.community_posts
       where author_id = new.author_id
         and status in ('pending', 'live')
         and expires_at > now()) >= 5 then
    raise exception 'You have 5 posts open. Take one down, or wait for one to expire.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_community_post on public.community_posts;
create trigger guard_community_post before insert on public.community_posts
  for each row execute function public.guard_community_post();

-- The team approves or rejects a pending post, or removes a live one.
create or replace function public.decide_community_post(
  p_post uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce(public.is_team_admin(), false) then
    raise exception 'Only the team moderates the board' using errcode = '42501';
  end if;
  if p_status not in ('live', 'rejected', 'removed') then
    raise exception 'Unknown decision' using errcode = '22023';
  end if;
  update public.community_posts
     set status = p_status,
         status_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_by = auth.uid(),
         decided_at = now()
   where id = p_post;
end;
$$;

revoke all on function public.decide_community_post(uuid, text, text) from public;
grant execute on function public.decide_community_post(uuid, text, text) to anon, authenticated;

-- Reports from anyone signed in; read by the team.
create table if not exists public.community_post_reports (
  post_id    uuid not null references public.community_posts (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  reason     text not null check (length(btrim(reason)) between 3 and 300),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.community_post_reports enable row level security;

drop policy if exists community_reports_insert on public.community_post_reports;
create policy community_reports_insert on public.community_post_reports for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists community_reports_team on public.community_post_reports;
create policy community_reports_team on public.community_post_reports for select
  using (coalesce(public.is_team_admin(), false));
