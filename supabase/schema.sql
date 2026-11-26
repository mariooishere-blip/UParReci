-- UParReči database setup. Run in Supabase SQL Editor as project owner.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  bio text not null default '' check (char_length(bio) <= 240),
  avatar_url text,
  role text not null default 'user' check (role in ('user','admin')),
  suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  username_changed_at timestamptz,
  constraint username_format check (username is null or username ~ '^[A-Za-z0-9_]{3,20}$')
);
create unique index if not exists profiles_username_lower_idx on public.profiles (lower(username));

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 140),
  description text not null default '' check (char_length(description) <= 300),
  subject text not null,
  school_level text not null check (school_level in ('Osnovna škola','Srednja škola')),
  grade integer not null,
  material_type text not null,
  content text not null check (char_length(content) >= 20),
  pdf_url text,
  cover_url text,
  status text not null default 'published' check (status in ('published','removed')),
  likes_count integer not null default 0 check (likes_count >= 0),
  views_count integer not null default 0 check (views_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint valid_grade check ((school_level='Osnovna škola' and grade between 1 and 9) or (school_level='Srednja škola' and grade between 1 and 4))
);
create index if not exists materials_created_idx on public.materials(created_at desc) where status='published';
create index if not exists materials_subject_idx on public.materials(subject, grade) where status='published';
create index if not exists materials_user_idx on public.materials(user_id);

-- Prevent owners from changing server-maintained counters through direct table updates.
create or replace function public.protect_material_counters()
returns trigger language plpgsql set search_path=public
as $$ begin
  if not public.is_admin() then
    new.likes_count := old.likes_count;
    new.views_count := old.views_count;
  end if;
  return new;
end; $$;
drop trigger if exists protect_material_counters_trigger on public.materials;
create trigger protect_material_counters_trigger before update on public.materials
for each row execute procedure public.protect_material_counters();

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(material_id,user_id)
);
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(content) between 2 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists comments_material_idx on public.comments(material_id,created_at);
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  material_id uuid references public.materials(id) on delete set null,
  reporter_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 1000),
  status text not null default 'open' check (status in ('open','reviewed','dismissed')),
  created_at timestamptz not null default now()
);
create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(material_id,user_id)
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and suspended=false); $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare wanted text;
begin
  wanted := nullif(new.raw_user_meta_data->>'username','');
  if wanted is not null and wanted !~ '^[A-Za-z0-9_]{3,20}$' then wanted := null; end if;
  insert into public.profiles(id,username,username_changed_at) values(new.id,wanted,case when wanted is null then null else now() end);
  return new;
exception when unique_violation then
  -- If a username collides during the signup race, create an unclaimed profile
  -- and require the user to choose another name in the onboarding screen.
  insert into public.profiles(id,username) values(new.id,null) on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.sync_like_count()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
 if tg_op='INSERT' then update public.materials set likes_count=likes_count+1 where id=new.material_id; return new; end if;
 update public.materials set likes_count=greatest(0,likes_count-1) where id=old.material_id; return old;
end;
$$;
drop trigger if exists likes_count_insert on public.likes;
create trigger likes_count_insert after insert on public.likes for each row execute procedure public.sync_like_count();
drop trigger if exists likes_count_delete on public.likes;
create trigger likes_count_delete after delete on public.likes for each row execute procedure public.sync_like_count();

create or replace function public.increment_material_views(material_id uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin update public.materials set views_count=views_count+1 where id=material_id and status='published'; end; $$;
revoke all on function public.increment_material_views(uuid) from public;
grant execute on function public.increment_material_views(uuid) to anon, authenticated;

-- Case-insensitive username availability helper (does not reveal account details).
create or replace function public.username_available(candidate text)
returns boolean language sql stable security definer set search_path=public
as $$ select candidate ~ '^[A-Za-z0-9_]{3,20}$' and not exists(select 1 from public.profiles where lower(username)=lower(candidate)); $$;
grant execute on function public.username_available(text) to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.materials enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.bookmarks enable row level security;

-- Enforce the 14-day username change interval on the database server.
create or replace function public.enforce_username_change_cooldown()
returns trigger language plpgsql set search_path=public
as $$
begin
  if not public.is_admin() then
    -- Ignore any client-supplied timestamp so it cannot be reset to bypass the cooldown.
    new.username_changed_at := old.username_changed_at;
    if old.username is distinct from new.username then
      if old.username is not null and old.username_changed_at is not null
         and old.username_changed_at > now() - interval '14 days' then
        raise exception 'USERNAME_CHANGE_COOLDOWN';
      end if;
      new.username_changed_at := now();
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists enforce_username_change_cooldown_trigger on public.profiles;
create trigger enforce_username_change_cooldown_trigger before update on public.profiles
for each row execute procedure public.enforce_username_change_cooldown();

-- Users cannot promote themselves or clear an administrator suspension.
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql set search_path=public
as $$
begin
  if not public.is_admin() then
    new.role := old.role;
    new.suspended := old.suspended;
  end if;
  return new;
end;
$$;
drop trigger if exists protect_profile_privileges_trigger on public.profiles;
create trigger protect_profile_privileges_trigger before update on public.profiles
for each row execute procedure public.protect_profile_privileges();

create policy "Profiles are publicly readable" on public.profiles for select using (true);
create policy "Users create own profile" on public.profiles for insert with check (auth.uid()=id and role='user' and suspended=false);
create policy "Users update own profile" on public.profiles for update using (auth.uid()=id and role='user') with check (auth.uid()=id and role='user');
create policy "Admins manage profiles" on public.profiles for all using (public.is_admin()) with check (public.is_admin());

create policy "Published materials readable" on public.materials for select using (status='published' or user_id=auth.uid() or public.is_admin());
create policy "Users create own materials" on public.materials for insert with check (auth.uid()=user_id and exists(select 1 from public.profiles p where p.id=auth.uid() and not p.suspended));
create policy "Owners update own materials" on public.materials for update using (auth.uid()=user_id and status='published') with check (auth.uid()=user_id);
create policy "Owners delete own materials" on public.materials for delete using (auth.uid()=user_id or public.is_admin());
create policy "Admins update materials" on public.materials for update using (public.is_admin()) with check (public.is_admin());

create policy "Likes readable" on public.likes for select using (true);
create policy "Users add own likes" on public.likes for insert with check (auth.uid()=user_id);
create policy "Users remove own likes" on public.likes for delete using (auth.uid()=user_id or public.is_admin());

create policy "Comments readable on published materials" on public.comments for select using (exists(select 1 from public.materials m where m.id=material_id and m.status='published'));
create policy "Users add own comments" on public.comments for insert with check (auth.uid()=user_id and exists(select 1 from public.profiles p where p.id=auth.uid() and not p.suspended));
create policy "Users delete own comments" on public.comments for delete using (auth.uid()=user_id or public.is_admin());

create policy "Users create reports" on public.reports for insert with check (auth.uid()=reporter_id);
create policy "Admins view reports" on public.reports for select using (public.is_admin());
create policy "Admins update reports" on public.reports for update using (public.is_admin()) with check (public.is_admin());

create policy "Users view own bookmarks" on public.bookmarks for select using (auth.uid()=user_id);
create policy "Users create own bookmarks" on public.bookmarks for insert with check (auth.uid()=user_id);
create policy "Users delete own bookmarks" on public.bookmarks for delete using (auth.uid()=user_id);

-- Storage buckets. Set file size/MIME restrictions in Dashboard too.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('materials','materials',true,10485760,array['application/pdf']),
       ('covers','covers',true,5242880,array['image/png','image/jpeg','image/webp']),
       ('avatars','avatars',true,3145728,array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create policy "Public read material files" on storage.objects for select using (bucket_id in ('materials','covers','avatars'));
create policy "Users upload own files" on storage.objects for insert to authenticated with check (
  bucket_id in ('materials','covers','avatars') and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "Users update own files" on storage.objects for update to authenticated using ((storage.foldername(name))[1]=auth.uid()::text) with check ((storage.foldername(name))[1]=auth.uid()::text);
create policy "Users delete own files" on storage.objects for delete to authenticated using ((storage.foldername(name))[1]=auth.uid()::text);

-- IMPORTANT: assign the first admin manually in SQL after confirming the account:
-- update public.profiles set role='admin' where username='YOUR_EXACT_USERNAME';
-- Never expose a service-role key in browser code.
