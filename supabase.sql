-- VMC Scheduler Supabase schema
-- Run this once in Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  role text not null default 'student' check (role in ('student','teacher','admin')),
  phone text not null default '',
  department text not null default '',
  id_number text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity integer not null check (capacity > 0),
  room_code text not null default '',
  location text not null default '',
  description text not null default '',
  amenities text[] not null default '{}',
  image_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete restrict,
  participants integer not null check (participants > 0),
  booking_date date not null,
  start_time time not null,
  end_time time not null,
  purpose text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  constraint valid_booking_time check (start_time < end_time)
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  event_date date not null,
  event_time time,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null default 'system',
  message text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  id integer primary key default 1 check (id = 1),
  open_days integer[] not null default '{1,2,3,4,5}',
  open_time time not null default '07:00',
  close_time time not null default '18:00',
  updated_at timestamptz not null default now()
);
insert into public.app_settings(id) values (1) on conflict (id) do nothing;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id,name,email,role,phone,department,id_number)
  values(
    new.id,
    coalesce(new.raw_user_meta_data->>'name',''),
    coalesce(new.email,''),
    case when new.raw_user_meta_data->>'role' = 'teacher' then 'teacher' else 'student' end,
    coalesce(new.raw_user_meta_data->>'phone',''),
    coalesce(new.raw_user_meta_data->>'department',''),
    coalesce(new.raw_user_meta_data->>'id_number','')
  ) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.guard_profile_role()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then new.role := old.role; end if;
  return new;
end $$;
drop trigger if exists guard_profile_role_trigger on public.profiles;
create trigger guard_profile_role_trigger before update on public.profiles for each row execute function public.guard_profile_role();

create or replace function public.guard_booking_status()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.user_id is distinct from old.user_id then new.user_id := old.user_id; end if;
  if new.status is distinct from old.status and not public.is_admin() then
    if not (old.status = 'pending' and new.status = 'cancelled') then new.status := old.status; end if;
  end if;
  return new;
end $$;
drop trigger if exists guard_booking_status_trigger on public.bookings;
create trigger guard_booking_status_trigger before update on public.bookings for each row execute function public.guard_booking_status();

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.bookings enable row level security;
alter table public.events enable row level security;
alter table public.notifications enable row level security;
alter table public.app_settings enable row level security;

-- Re-runnable policies
do $$ begin
  drop policy if exists "profiles own or admin select" on public.profiles;
  drop policy if exists "profiles own update" on public.profiles;
  drop policy if exists "rooms authenticated select" on public.rooms;
  drop policy if exists "rooms admin insert" on public.rooms;
  drop policy if exists "rooms admin update" on public.rooms;
  drop policy if exists "rooms admin delete" on public.rooms;
  drop policy if exists "bookings own or admin select" on public.bookings;
  drop policy if exists "bookings own insert" on public.bookings;
  drop policy if exists "bookings own or admin update" on public.bookings;
  drop policy if exists "events visible select" on public.events;
  drop policy if exists "events own insert" on public.events;
  drop policy if exists "events own update" on public.events;
  drop policy if exists "events own delete" on public.events;
  drop policy if exists "notifications own select" on public.notifications;
  drop policy if exists "notifications own update" on public.notifications;
  drop policy if exists "notifications admin insert" on public.notifications;
  drop policy if exists "settings authenticated select" on public.app_settings;
  drop policy if exists "settings admin update" on public.app_settings;
exception when undefined_object then null; end $$;

create policy "profiles own or admin select" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles own update" on public.profiles for update to authenticated using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "rooms authenticated select" on public.rooms for select to authenticated using (true);
create policy "rooms admin insert" on public.rooms for insert to authenticated with check (public.is_admin());
create policy "rooms admin update" on public.rooms for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "rooms admin delete" on public.rooms for delete to authenticated using (public.is_admin());
create policy "bookings own or admin select" on public.bookings for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "bookings own insert" on public.bookings for insert to authenticated with check (user_id = auth.uid());
create policy "bookings own or admin update" on public.bookings for update to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "events visible select" on public.events for select to authenticated using (published or user_id = auth.uid() or public.is_admin());
create policy "events own insert" on public.events for insert to authenticated with check (user_id = auth.uid());
create policy "events own update" on public.events for update to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "events own delete" on public.events for delete to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "notifications own select" on public.notifications for select to authenticated using (user_id = auth.uid());
create policy "notifications own update" on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notifications admin insert" on public.notifications for insert to authenticated with check (public.is_admin() or user_id = auth.uid());
create policy "settings authenticated select" on public.app_settings for select to authenticated using (true);
create policy "settings admin update" on public.app_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.rooms(name,capacity,room_code,location,description,amenities)
select * from (values
 ('Computer Laboratory',40,'CL-01','Main Building','Computer laboratory for classes and practical activities',array['Computers','Projector']),
 ('Audio Visual Room',60,'AVR','Main Building','Room for presentations, screenings, and seminars',array['Projector','Sound System']),
 ('Conference Room',24,'CR-01','Administration Building','Meeting and conference room',array['TV Display','Whiteboard'])
) as v(name,capacity,room_code,location,description,amenities)
where not exists(select 1 from public.rooms);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('room-images','room-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true, file_size_limit=5242880, allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists "room images public read" on storage.objects;
drop policy if exists "room images admin insert" on storage.objects;
drop policy if exists "room images admin update" on storage.objects;
drop policy if exists "room images admin delete" on storage.objects;
create policy "room images public read" on storage.objects for select using (bucket_id='room-images');
create policy "room images admin insert" on storage.objects for insert to authenticated with check (bucket_id='room-images' and public.is_admin());
create policy "room images admin update" on storage.objects for update to authenticated using (bucket_id='room-images' and public.is_admin());
create policy "room images admin delete" on storage.objects for delete to authenticated using (bucket_id='room-images' and public.is_admin());

-- Server-side availability + conflict protection. This keeps other users' booking details private.
create or replace function public.room_is_available(p_room_id uuid, p_date date, p_start time, p_end time, p_participants integer)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists(
    select 1 from public.rooms r
    join public.app_settings s on s.id=1
    where r.id=p_room_id and r.active and p_participants between 1 and r.capacity
      and extract(dow from p_date)::integer = any(s.open_days)
      and p_start >= s.open_time and p_end <= s.close_time and p_start < p_end
      and not exists(
        select 1 from public.bookings b
        where b.room_id=p_room_id and b.booking_date=p_date
          and b.status not in ('rejected','cancelled')
          and p_start < b.end_time and p_end > b.start_time
      )
  );
$$;
grant execute on function public.room_is_available(uuid,date,time,time,integer) to authenticated;

create or replace function public.validate_booking()
returns trigger language plpgsql security definer set search_path = public
as $$
declare r public.rooms%rowtype; s public.app_settings%rowtype;
begin
  select * into r from public.rooms where id=new.room_id;
  select * into s from public.app_settings where id=1;
  if r.id is null or not r.active then raise exception 'This room is not available for booking.'; end if;
  if new.participants < 1 or new.participants > r.capacity then raise exception 'Participant count exceeds room capacity.'; end if;
  if not (new.start_time < new.end_time) then raise exception 'End time must be later than start time.'; end if;
  if not (extract(dow from new.booking_date)::integer = any(s.open_days)) then raise exception 'School is closed on the selected day.'; end if;
  if new.start_time < s.open_time or new.end_time > s.close_time then raise exception 'Selected time is outside school operating hours.'; end if;
  if exists(select 1 from public.bookings b where b.id<>coalesce(new.id,gen_random_uuid()) and b.room_id=new.room_id and b.booking_date=new.booking_date and b.status not in ('rejected','cancelled') and new.start_time < b.end_time and new.end_time > b.start_time) then
    raise exception 'Room already has an overlapping booking.';
  end if;
  if exists(select 1 from public.bookings b where b.id<>coalesce(new.id,gen_random_uuid()) and b.user_id=new.user_id and b.booking_date=new.booking_date and b.status not in ('rejected','cancelled') and new.start_time < b.end_time and new.end_time > b.start_time) then
    raise exception 'You already have another booking that overlaps this time.';
  end if;
  return new;
end $$;
drop trigger if exists validate_booking_trigger on public.bookings;
create trigger validate_booking_trigger before insert or update of room_id,booking_date,start_time,end_time,participants on public.bookings for each row execute function public.validate_booking();

-- Automatic notifications generated securely in the database.
create or replace function public.notify_booking_insert()
returns trigger language plpgsql security definer set search_path=public
as $$
declare room_name text; requester text; a record;
begin
  select name into room_name from public.rooms where id=new.room_id;
  select name into requester from public.profiles where id=new.user_id;
  insert into public.notifications(user_id,category,message) values(new.user_id,'booking','Your booking for '||room_name||' on '||new.booking_date||' was submitted for review.');
  for a in select id from public.profiles where role='admin' loop
    insert into public.notifications(user_id,category,message) values(a.id,'booking','New booking from '||requester||': '||room_name||' on '||new.booking_date||'.');
  end loop;
  return new;
end $$;
drop trigger if exists notify_booking_insert_trigger on public.bookings;
create trigger notify_booking_insert_trigger after insert on public.bookings for each row execute function public.notify_booking_insert();

create or replace function public.notify_booking_status()
returns trigger language plpgsql security definer set search_path=public
as $$
declare room_name text;
begin
  if new.status is distinct from old.status then
    select name into room_name from public.rooms where id=new.room_id;
    insert into public.notifications(user_id,category,message) values(new.user_id,'booking','Your booking for '||room_name||' is now '||new.status||'.');
  end if;
  return new;
end $$;
drop trigger if exists notify_booking_status_trigger on public.bookings;
create trigger notify_booking_status_trigger after update of status on public.bookings for each row execute function public.notify_booking_status();

create or replace function public.notify_published_event()
returns trigger language plpgsql security definer set search_path=public
as $$
declare p record; creator text;
begin
  if new.published and (tg_op='INSERT' or old.published is distinct from new.published) then
    select name into creator from public.profiles where id=new.user_id;
    for p in select id from public.profiles where id<>new.user_id loop
      insert into public.notifications(user_id,category,message) values(p.id,'event',creator||' published an event: '||new.title||' on '||new.event_date||'.');
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists notify_published_event_trigger on public.events;
create trigger notify_published_event_trigger after insert or update of published on public.events for each row execute function public.notify_published_event();

-- =========================================================
-- Admin-controlled branding, permissions, user management + realtime sync
-- Run this section once after the original schema has been applied.
-- =========================================================

alter table public.app_settings add column if not exists app_name text not null default 'VMC Scheduler';
alter table public.app_settings add column if not exists tagline text not null default 'Classroom Scheduling & Facility Booking';
alter table public.app_settings add column if not exists logo_url text not null default '';
alter table public.app_settings add column if not exists permissions jsonb not null default jsonb_build_object(
  'student', jsonb_build_object('view_rooms',true,'book_rooms',true,'manage_own_bookings',true,'calendar',true,'profile',true,'notifications',true),
  'teacher', jsonb_build_object('view_rooms',true,'book_rooms',true,'manage_own_bookings',true,'calendar',true,'profile',true,'notifications',true)
);

update public.app_settings
set permissions = coalesce(permissions, jsonb_build_object(
  'student', jsonb_build_object('view_rooms',true,'book_rooms',true,'manage_own_bookings',true,'calendar',true,'profile',true,'notifications',true),
  'teacher', jsonb_build_object('view_rooms',true,'book_rooms',true,'manage_own_bookings',true,'calendar',true,'profile',true,'notifications',true)
));

create or replace function public.has_permission(p_permission text)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.is_admin() or coalesce(
    (
      select (s.permissions -> p.role ->> p_permission)::boolean
      from public.profiles p
      cross join public.app_settings s
      where p.id = auth.uid() and s.id = 1
    ), false
  );
$$;

drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own update" on public.profiles for update to authenticated
using ((id = auth.uid() and public.has_permission('profile')) or public.is_admin())
with check ((id = auth.uid() and public.has_permission('profile')) or public.is_admin());

drop policy if exists "rooms authenticated select" on public.rooms;
create policy "rooms authenticated select" on public.rooms for select to authenticated using (public.has_permission('view_rooms'));

drop policy if exists "bookings own or admin select" on public.bookings;
create policy "bookings own or admin select" on public.bookings for select to authenticated
using (public.is_admin() or (user_id = auth.uid() and public.has_permission('manage_own_bookings')));

drop policy if exists "bookings own insert" on public.bookings;
create policy "bookings own insert" on public.bookings for insert to authenticated
with check (user_id = auth.uid() and public.has_permission('book_rooms'));

drop policy if exists "bookings own or admin update" on public.bookings;
create policy "bookings own or admin update" on public.bookings for update to authenticated
using (public.is_admin() or (user_id = auth.uid() and public.has_permission('manage_own_bookings')))
with check (public.is_admin() or (user_id = auth.uid() and public.has_permission('manage_own_bookings')));

drop policy if exists "events visible select" on public.events;
create policy "events visible select" on public.events for select to authenticated
using (public.is_admin() or (public.has_permission('calendar') and (published or user_id = auth.uid())));

drop policy if exists "events own insert" on public.events;
create policy "events own insert" on public.events for insert to authenticated
with check (user_id = auth.uid() and public.has_permission('calendar'));

drop policy if exists "events own update" on public.events;
create policy "events own update" on public.events for update to authenticated
using (public.is_admin() or (user_id = auth.uid() and public.has_permission('calendar')))
with check (public.is_admin() or (user_id = auth.uid() and public.has_permission('calendar')));

drop policy if exists "events own delete" on public.events;
create policy "events own delete" on public.events for delete to authenticated
using (public.is_admin() or (user_id = auth.uid() and public.has_permission('calendar')));

drop policy if exists "notifications own select" on public.notifications;
create policy "notifications own select" on public.notifications for select to authenticated
using (user_id = auth.uid() and public.has_permission('notifications'));

drop policy if exists "notifications own update" on public.notifications;
create policy "notifications own update" on public.notifications for update to authenticated
using (user_id = auth.uid() and public.has_permission('notifications'))
with check (user_id = auth.uid() and public.has_permission('notifications'));

create or replace function public.room_is_available(p_room_id uuid, p_date date, p_start time, p_end time, p_participants integer)
returns boolean language plpgsql stable security definer set search_path = public
as $$
declare r public.rooms%rowtype; s public.app_settings%rowtype;
begin
  if not public.has_permission('book_rooms') then return false; end if;
  select * into r from public.rooms where id=p_room_id and active=true;
  if not found then return false; end if;
  select * into s from public.app_settings where id=1;
  if p_participants < 1 or p_participants > r.capacity then return false; end if;
  if not (extract(dow from p_date)::int = any(s.open_days)) then return false; end if;
  if p_start < s.open_time or p_end > s.close_time or p_start >= p_end then return false; end if;
  return not exists(select 1 from public.bookings b where b.room_id=p_room_id and b.booking_date=p_date and b.status in ('pending','approved') and p_start < b.end_time and p_end > b.start_time);
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('site-assets','site-assets',true,3145728,array['image/jpeg','image/png','image/webp','image/svg+xml'])
on conflict (id) do update set public=true, file_size_limit=3145728, allowed_mime_types=array['image/jpeg','image/png','image/webp','image/svg+xml'];

drop policy if exists "site assets public read" on storage.objects;
drop policy if exists "site assets admin insert" on storage.objects;
drop policy if exists "site assets admin update" on storage.objects;
drop policy if exists "site assets admin delete" on storage.objects;
create policy "site assets public read" on storage.objects for select using (bucket_id='site-assets');
create policy "site assets admin insert" on storage.objects for insert to authenticated with check (bucket_id='site-assets' and public.is_admin());
create policy "site assets admin update" on storage.objects for update to authenticated using (bucket_id='site-assets' and public.is_admin());
create policy "site assets admin delete" on storage.objects for delete to authenticated using (bucket_id='site-assets' and public.is_admin());

-- Enable realtime for shared system data so changes made by an Admin propagate to
-- every currently signed-in Teacher/Student without a manual refresh.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='app_settings') then
    alter publication supabase_realtime add table public.app_settings;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms') then
    alter publication supabase_realtime add table public.rooms;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='bookings') then
    alter publication supabase_realtime add table public.bookings;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='events') then
    alter publication supabase_realtime add table public.events;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='profiles') then
    alter publication supabase_realtime add table public.profiles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
exception when undefined_object then null;
end $$;

-- =========================================================
-- Production hardening + change notifications
-- Run after the previous sections.
-- =========================================================

-- Avoid recursive permission evaluation when a user edits their own profile.
drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own update" on public.profiles for update to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- Notify users when an administrator changes shared system configuration.
create or replace function public.notify_system_settings_change()
returns trigger language plpgsql security definer set search_path=public
as $$
declare p record;
begin
  if tg_op = 'UPDATE' then
    for p in select id from public.profiles where id <> auth.uid() loop
      insert into public.notifications(user_id,category,message)
      values(p.id,'system','An administrator updated system settings or branding. Your interface has been synchronized.');
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists notify_system_settings_change_trigger on public.app_settings;
create trigger notify_system_settings_change_trigger after update on public.app_settings
for each row execute function public.notify_system_settings_change();

-- Notify users when an administrator changes a user's role.
create or replace function public.notify_role_change()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if new.role is distinct from old.role and public.is_admin() then
    insert into public.notifications(user_id,category,message)
    values(new.id,'system','Your account role was updated to '||new.role||'.');
  end if;
  return new;
end $$;
drop trigger if exists notify_role_change_trigger on public.profiles;
create trigger notify_role_change_trigger after update of role on public.profiles
for each row execute function public.notify_role_change();

-- Notify all users when an administrator creates, updates, or removes a room.
create or replace function public.notify_room_change()
returns trigger language plpgsql security definer set search_path=public
as $$
declare p record; room_name text; action_text text;
begin
  if tg_op='INSERT' then room_name:=new.name; action_text:='added a new room';
  elsif tg_op='UPDATE' then room_name:=new.name; action_text:='updated room information for';
  else room_name:=old.name; action_text:='removed the room'; end if;
  if public.is_admin() then
    for p in select id from public.profiles where id <> auth.uid() loop
      insert into public.notifications(user_id,category,message)
      values(p.id,'room','An administrator '||action_text||' '||room_name||'.');
    end loop;
  end if;
  return coalesce(new,old);
end $$;
drop trigger if exists notify_room_change_trigger on public.rooms;
create trigger notify_room_change_trigger after insert or update or delete on public.rooms
for each row execute function public.notify_room_change();

-- Keep Realtime publication entries idempotent.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='app_settings') then alter publication supabase_realtime add table public.app_settings; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms') then alter publication supabase_realtime add table public.rooms; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='bookings') then alter publication supabase_realtime add table public.bookings; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='events') then alter publication supabase_realtime add table public.events; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='profiles') then alter publication supabase_realtime add table public.profiles; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then alter publication supabase_realtime add table public.notifications; end if;
exception when undefined_object then null;
end $$;
