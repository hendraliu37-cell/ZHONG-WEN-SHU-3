create table if not exists public.test_history (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (id, user_id)
);

create index if not exists test_history_user_updated_idx
  on public.test_history (user_id, updated_at desc);

alter table public.test_history enable row level security;

drop policy if exists "test history select own" on public.test_history;
create policy "test history select own"
  on public.test_history for select
  using (auth.uid() = user_id);

drop policy if exists "test history insert own" on public.test_history;
create policy "test history insert own"
  on public.test_history for insert
  with check (auth.uid() = user_id);

drop policy if exists "test history update own" on public.test_history;
create policy "test history update own"
  on public.test_history for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "test history delete own" on public.test_history;
create policy "test history delete own"
  on public.test_history for delete
  using (auth.uid() = user_id);
