-- In-app messages between a customer and a business (2026-10-28 redesign).
--
-- One conversation per customer and business. Only those two can read it
-- (the business through anyone who administers it); the team cannot browse
-- private chats, but sees a conversation someone reports. A business can
-- block a customer (App Store guideline 1.2 for user-to-user messaging);
-- messages are capped at 1,000 characters and 30 an hour per sender.

create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses (id) on delete cascade,
  customer_id     uuid not null references auth.users (id) on delete cascade,
  blocked         boolean not null default false,
  created_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  unique (business_id, customer_id)
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references auth.users (id) on delete cascade,
  body            text not null check (length(btrim(body)) between 1 and 1000),
  created_at      timestamptz not null default now(),
  read_at         timestamptz
);

create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);
create index if not exists conversations_customer_idx
  on public.conversations (customer_id, last_message_at desc);
create index if not exists conversations_business_idx
  on public.conversations (business_id, last_message_at desc);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create or replace function public.in_conversation(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversations c
     where c.id = p_conversation
       and (c.customer_id = auth.uid() or coalesce(public.administers(c.business_id), false))
  );
$$;

drop policy if exists conversations_read on public.conversations;
create policy conversations_read on public.conversations for select
  using (customer_id = auth.uid() or coalesce(public.administers(business_id), false));

drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select
  using (public.in_conversation(conversation_id));

revoke insert, update, delete on public.conversations from anon, authenticated;
revoke insert, update, delete on public.messages from anon, authenticated;

-- Sends a message. A customer names the business (the conversation is
-- created on first message); a business replies within a conversation.
create or replace function public.send_message(
  p_body text,
  p_business uuid default null,
  p_conversation uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_conv public.conversations;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_uid is null then
    raise exception 'Sign in to send messages' using errcode = '42501';
  end if;
  if length(v_body) = 0 or length(v_body) > 1000 then
    raise exception 'A message is 1 to 1,000 characters' using errcode = '22023';
  end if;
  if (select count(*) from public.messages
       where sender_id = v_uid and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'You have sent a lot of messages. Try again in a while.' using errcode = '22023';
  end if;

  if p_conversation is not null then
    select * into v_conv from public.conversations where id = p_conversation;
    if not found or not (v_conv.customer_id = v_uid or coalesce(public.administers(v_conv.business_id), false)) then
      raise exception 'No such conversation' using errcode = 'P0002';
    end if;
  else
    if not exists (
      select 1 from public.businesses
       where id = p_business and subscription_status <> 'delisted' and not is_prospect
    ) then
      raise exception 'No such business' using errcode = 'P0002';
    end if;
    if coalesce(public.administers(p_business), false) then
      raise exception 'You cannot message your own business' using errcode = '22023';
    end if;
    insert into public.conversations (business_id, customer_id)
    values (p_business, v_uid)
    on conflict (business_id, customer_id) do update set business_id = excluded.business_id
    returning * into v_conv;
  end if;

  if v_conv.blocked and v_conv.customer_id = v_uid then
    raise exception 'This business is not taking messages from you' using errcode = '42501';
  end if;

  insert into public.messages (conversation_id, sender_id, body)
  values (v_conv.id, v_uid, v_body);
  update public.conversations set last_message_at = now() where id = v_conv.id;
  return v_conv.id;
end;
$$;

-- Marks the other side's messages read.
create or replace function public.mark_conversation_read(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not public.in_conversation(p_conversation) then
    raise exception 'No such conversation' using errcode = 'P0002';
  end if;
  update public.messages
     set read_at = now()
   where conversation_id = p_conversation
     and sender_id <> auth.uid()
     and read_at is null;
end;
$$;

-- A business blocks or unblocks a customer in one conversation.
create or replace function public.set_conversation_blocked(
  p_conversation uuid,
  p_blocked boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select business_id into v_business from public.conversations where id = p_conversation;
  if v_business is null or not coalesce(public.administers(v_business), false) then
    raise exception 'Only the business can block' using errcode = '42501';
  end if;
  update public.conversations set blocked = p_blocked where id = p_conversation;
end;
$$;

-- Reports: either side can flag a conversation; the team reads the report
-- and, through it, the conversation.
create table if not exists public.conversation_reports (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  reason          text not null check (length(btrim(reason)) between 3 and 300),
  created_at      timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.conversation_reports enable row level security;

drop policy if exists conversation_reports_insert on public.conversation_reports;
create policy conversation_reports_insert on public.conversation_reports for insert
  to authenticated
  with check (user_id = auth.uid() and public.in_conversation(conversation_id));

drop policy if exists conversation_reports_team on public.conversation_reports;
create policy conversation_reports_team on public.conversation_reports for select
  using (coalesce(public.is_team_admin(), false));

-- The team may read a conversation only once someone has reported it.
drop policy if exists messages_team_reported on public.messages;
create policy messages_team_reported on public.messages for select
  using (
    coalesce(public.is_team_admin(), false)
    and exists (select 1 from public.conversation_reports r
                 where r.conversation_id = messages.conversation_id)
  );

revoke all on function public.send_message(text, uuid, uuid) from public;
revoke all on function public.mark_conversation_read(uuid) from public;
revoke all on function public.set_conversation_blocked(uuid, boolean) from public;
grant execute on function public.send_message(text, uuid, uuid) to anon, authenticated;
grant execute on function public.mark_conversation_read(uuid) to anon, authenticated;
grant execute on function public.set_conversation_blocked(uuid, boolean) to anon, authenticated;

-- Live updates in an open chat.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
