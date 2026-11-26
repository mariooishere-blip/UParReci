-- Apply this migration in Supabase SQL Editor to an existing UParReči database.
alter table public.profiles add column if not exists username_changed_at timestamptz;
update public.profiles set username_changed_at=created_at where username is not null and username_changed_at is null;
alter table public.materials drop constraint if exists valid_grade;
alter table public.materials add constraint valid_grade check ((school_level='Osnovna škola' and grade between 1 and 9) or (school_level='Srednja škola' and grade between 1 and 4));
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
create trigger enforce_username_change_cooldown_trigger before update on public.profiles for each row execute procedure public.enforce_username_change_cooldown();
