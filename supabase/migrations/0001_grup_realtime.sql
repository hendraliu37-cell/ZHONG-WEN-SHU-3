-- M3 Grup Realtime: rooms, members, messages + RLS + RPCs.
-- Applied to project avdfneyqqmgzwzrmjtkv via Supabase MCP on 2026-06-13.
-- This file is the repo record (the migrations folder did not exist before;
-- earlier schema — profiles, avatars bucket — was applied directly via MCP).

create table if not exists public.rooms (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,
  name       text not null,
  level_tag  text not null default '',
  owner      uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id   uuid not null references public.rooms(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_messages (
  id            bigint generated always as identity primary key,
  room_id       uuid not null references public.rooms(id) on delete cascade,
  sender_id     uuid references auth.users(id) on delete set null,
  author_name   text not null,
  author_handle text not null default '',
  is_guru       boolean not null default false,
  body          text not null,
  created_at    timestamptz not null default now()
);

create index if not exists room_messages_room_created_idx
  on public.room_messages (room_id, created_at);
create index if not exists room_members_user_idx
  on public.room_members (user_id);

-- Security-definer membership check: bypasses RLS so member-scoped policies
-- (incl. room_members itself) don't recurse.
create or replace function public.is_room_member(p_room uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.room_members m
    where m.room_id = p_room and m.user_id = auth.uid()
  );
$$;

alter table public.rooms        enable row level security;
alter table public.room_members enable row level security;
alter table public.room_messages enable row level security;

-- rooms
drop policy if exists rooms_select on public.rooms;
create policy rooms_select on public.rooms
  for select to authenticated
  using (public.is_room_member(id));
drop policy if exists rooms_update on public.rooms;
create policy rooms_update on public.rooms
  for update to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
drop policy if exists rooms_delete on public.rooms;
create policy rooms_delete on public.rooms
  for delete to authenticated
  using (owner = auth.uid());

-- room_members
drop policy if exists members_select on public.room_members;
create policy members_select on public.room_members
  for select to authenticated
  using (public.is_room_member(room_id));
drop policy if exists members_delete on public.room_members;
create policy members_delete on public.room_members
  for delete to authenticated
  using (user_id = auth.uid());

-- room_messages
drop policy if exists messages_select on public.room_messages;
create policy messages_select on public.room_messages
  for select to authenticated
  using (public.is_room_member(room_id));
drop policy if exists messages_insert on public.room_messages;
create policy messages_insert on public.room_messages
  for insert to authenticated
  with check (
    public.is_room_member(room_id)
    and sender_id = auth.uid()
    and is_guru = false
  );

-- Unique invite-code generator (Crockford-ish base32, no ambiguous chars).
create or replace function public.gen_room_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  c text;
  i int;
begin
  loop
    c := 'ZWS-';
    for i in 1..5 loop
      c := c || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.rooms where code = c);
  end loop;
  return c;
end;
$$;

create or replace function public.create_room(p_name text, p_level text default '')
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.rooms;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.rooms (code, name, level_tag, owner)
  values (public.gen_room_code(), coalesce(nullif(trim(p_name), ''), 'Ruang'), coalesce(p_level, ''), auth.uid())
  returning * into r;
  insert into public.room_members (room_id, user_id, role)
  values (r.id, auth.uid(), 'owner')
  on conflict do nothing;
  return r;
end;
$$;

create or replace function public.join_room(p_code text)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.rooms;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  select * into r from public.rooms where code = upper(trim(p_code));
  if not found then
    raise exception 'room not found';
  end if;
  insert into public.room_members (room_id, user_id, role)
  values (r.id, auth.uid(), 'member')
  on conflict do nothing;
  return r;
end;
$$;

grant execute on function public.create_room(text, text) to authenticated;
grant execute on function public.join_room(text)        to authenticated;
grant execute on function public.is_room_member(uuid)   to authenticated;

-- Realtime: stream inserts on room_messages.
alter publication supabase_realtime add table public.room_messages;
