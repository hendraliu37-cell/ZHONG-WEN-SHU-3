-- M0/M2/M4: profiles, materials cache, pronunciation scores.
-- Creates tables that were previously applied ad-hoc via MCP.

-- 1. PROFILES
create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  handle           text not null,
  public_id        int not null,
  display_name     text not null,
  track            text not null default 'both'
                     check (track in ('simplified','traditional','both')),
  xp               int not null default 0,
  streak           int not null default 0,
  avatar_url       text,
  last_active_date text,
  created_at       timestamptz not null default now()
);

create unique index if not exists profiles_handle_idx on public.profiles (lower(handle));
create unique index if not exists profiles_public_id_idx on public.profiles (public_id);

alter table public.profiles enable row level security;

-- Users can read all profiles (for leaderboard) but only update their own.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (true);

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- 2. HANDLE AVAILABILITY CHECK
create or replace function public.handle_available(p_handle text)
returns boolean
language sql
stable
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles where lower(handle) = lower(p_handle)
  );
$$;

grant execute on function public.handle_available(text) to authenticated;

-- 3. AUTO-CREATE PROFILE ON SIGNUP
-- Triggered by Supabase Auth on user insert. Extracts handle, display_name, track
-- from raw_user_meta_data, generates a unique numeric_id from a sequence.
create sequence if not exists public.public_id_seq start 100000;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  next_id int;
  preferred_track text;
begin
  next_id := nextval('public.public_id_seq')::int;
  preferred_track := coalesce(new.raw_user_meta_data ->> 'track', 'both');
  if preferred_track not in ('simplified','traditional','both') then
    preferred_track := 'both';
  end if;
  insert into public.profiles (id, handle, public_id, display_name, track)
  values (
    new.id,
    lower(coalesce(nullif(trim(new.raw_user_meta_data ->> 'handle'), ''), 'user' || next_id)),
    next_id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'Pengguna'),
    preferred_track
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. MATERIALS CACHE (curriculum-gen)
create table if not exists public.materials (
  cache_key  text primary key,
  track      text not null default 'simplified',
  level      text not null default '',
  content    jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.materials enable row level security;

drop policy if exists materials_select on public.materials;
create policy materials_select on public.materials
  for select to authenticated
  using (true);

-- 5. PRONUNCIATION SCORES CACHE (scoring-proxy)
create table if not exists public.pronunciation_scores (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  reference_text  text not null,
  score           int not null,
  words           jsonb,
  created_at      timestamptz not null default now()
);

create index if not exists pron_scores_user_idx on public.pronunciation_scores (user_id);

alter table public.pronunciation_scores enable row level security;

drop policy if exists pron_scores_select on public.pronunciation_scores;
create policy pron_scores_select on public.pronunciation_scores
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists pron_scores_insert on public.pronunciation_scores;
create policy pron_scores_insert on public.pronunciation_scores
  for insert to authenticated
  with check (user_id = auth.uid());

-- 6. STORAGE BUCKET: avatars
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,  -- 2 MB
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists avatars_select on storage.objects;
create policy avatars_select on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert on storage.objects;
create policy avatars_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists avatars_update on storage.objects;
create policy avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and owner = auth.uid())
  with check (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists avatars_delete on storage.objects;
create policy avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and owner = auth.uid());
