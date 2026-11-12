-- JuanGo cloud: account sync + word lists shared by code.
-- Run once in Supabase → SQL Editor → New query → Run.

-- 1. Each signed-in user's backup (the same JSON as 設定 › 匯出備份).
create table if not exists public.user_backups (
  user_id    uuid primary key references auth.users on delete cascade default auth.uid(),
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  constraint backup_size check (pg_column_size(data) < 5000000)
);
alter table public.user_backups enable row level security;

drop policy if exists "own backup" on public.user_backups;
create policy "own backup" on public.user_backups
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2. Shared word lists: anyone with the code can copy one; only the owner can change or delete it.
create or replace function public.new_share_code() returns text
language sql volatile as $$
  -- 8 characters without look-alikes (no 0/O, 1/I/L)
  select string_agg(substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ', 1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, 8)
$$;

create table if not exists public.shared_lists (
  code       text primary key default public.new_share_code(),
  owner      uuid not null references auth.users on delete cascade default auth.uid(),
  name       text not null check (char_length(name) between 1 and 60),
  data       jsonb not null,
  word_count int  not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint list_size check (pg_column_size(data) < 1000000)
);
alter table public.shared_lists enable row level security;

-- owners see and manage their own lists; nobody can browse other people's
drop policy if exists "owner manages" on public.shared_lists;
create policy "owner manages" on public.shared_lists
  for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());

-- fetching by code goes through this function only, so lists can't be listed or searched
create or replace function public.get_shared_list(p_code text)
returns table (code text, name text, data jsonb, word_count int, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.code, s.name, s.data, s.word_count, s.updated_at
  from public.shared_lists s
  where s.code = upper(replace(trim(p_code), '-', ''))
$$;
revoke all on function public.get_shared_list(text) from public;
grant execute on function public.get_shared_list(text) to anon, authenticated;
