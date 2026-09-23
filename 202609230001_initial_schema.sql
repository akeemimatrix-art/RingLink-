-- RingLink initial Supabase schema
-- Designed for the Android-first MVP.
-- Run this migration in the Supabase SQL editor or through Supabase CLI migrations.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;

create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default 'RingLink User',
  account_role text not null default 'customer' check (account_role in ('customer', 'provider', 'business', 'admin')),
  phone text,
  avatar_url text,
  bio text,
  city text default 'Kampala',
  gender text check (gender is null or gender in ('male', 'female', 'other')),
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  name text not null unique,
  slug text not null unique,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.provider_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  profession text not null,
  years_experience integer not null default 0 check (years_experience >= 0 and years_experience <= 100),
  location_label text not null default 'Kampala',
  location extensions.geography(point, 4326),
  is_available boolean not null default true,
  is_verified boolean not null default false,
  average_rating numeric(3,2) not null default 0 check (average_rating >= 0 and average_rating <= 5),
  total_reviews integer not null default 0 check (total_reviews >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists provider_profiles_location_gix
  on public.provider_profiles using gist (location);
create index if not exists provider_profiles_available_idx
  on public.provider_profiles (is_available, is_verified);

create table if not exists public.provider_services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(user_id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  service_name text not null,
  created_at timestamptz not null default now(),
  unique (provider_id, category_id, service_name)
);

create index if not exists provider_services_category_idx
  on public.provider_services (category_id, provider_id);

create table if not exists public.business_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  business_name text not null,
  description text,
  phone text,
  city text default 'Kampala',
  location_label text not null default 'Kampala',
  location extensions.geography(point, 4326),
  is_available boolean not null default true,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists business_profiles_location_gix
  on public.business_profiles using gist (location);
create index if not exists business_profiles_available_idx
  on public.business_profiles (is_available, is_verified);

create table if not exists public.business_services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.business_profiles(user_id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  service_name text not null,
  created_at timestamptz not null default now(),
  unique (business_id, category_id, service_name)
);

create index if not exists business_services_category_idx
  on public.business_services (category_id, business_id);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_type text not null check (plan_type in ('individual', 'business')),
  status text not null default 'pending' check (status in ('pending', 'active', 'past_due', 'expired', 'cancelled')),
  price_usd numeric(10,2) not null check (price_usd >= 0),
  starts_at timestamptz,
  expires_at timestamptz,
  activated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop index if exists public.subscriptions_one_active_idx;
drop index if exists public.subscriptions_one_pending_idx;
create unique index if not exists subscriptions_one_open_idx
  on public.subscriptions (user_id) where status in ('active', 'pending');
create index if not exists subscriptions_user_status_idx
  on public.subscriptions (user_id, status, expires_at);

create or replace function private.validate_subscription_plan()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  role_name text;
begin
  select account_role into role_name
  from public.profiles
  where id = new.user_id;

  if new.plan_type = 'individual' and role_name is distinct from 'provider' then
    raise exception 'Individual subscriptions are for provider accounts.';
  end if;

  if new.plan_type = 'business' and role_name is distinct from 'business' then
    raise exception 'Business subscriptions are for business accounts.';
  end if;

  if new.plan_type = 'individual' and new.price_usd <> 5.00 then
    raise exception 'The individual RingLink plan price must be US$5.00.';
  end if;

  if new.plan_type = 'business' and new.price_usd <> 9.99 then
    raise exception 'The business RingLink plan price must be US$9.99.';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_subscription_plan() from public, anon, authenticated;

drop trigger if exists validate_subscription_plan on public.subscriptions;
create trigger validate_subscription_plan
before insert or update of user_id, plan_type, price_usd on public.subscriptions
for each row execute procedure private.validate_subscription_plan();

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  document_type text not null check (document_type in ('national_id', 'driving_licence', 'teacher_id', 'business_document')),
  document_path text not null,
  notes text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

create index if not exists verification_requests_status_idx
  on public.verification_requests (status, submitted_at);
create unique index if not exists verification_requests_one_open_idx
  on public.verification_requests (user_id) where status in ('pending', 'approved');

create table if not exists public.saved_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  address_label text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  is_favorite boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists saved_locations_user_idx
  on public.saved_locations (user_id, is_favorite desc, label);

create table if not exists public.ring_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  service_name text not null,
  radius_meters double precision not null default 1500 check (radius_meters between 100 and 50000),
  origin extensions.geography(point, 4326) not null,
  status text not null default 'ringing' check (status in ('ringing', 'accepted', 'expired', 'cancelled')),
  winner_provider_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '60 seconds'),
  closed_at timestamptz
);

create index if not exists ring_requests_customer_idx
  on public.ring_requests (customer_id, created_at desc);
create index if not exists ring_requests_status_idx
  on public.ring_requests (status, expires_at);
create index if not exists ring_requests_origin_gix
  on public.ring_requests using gist (origin);

create table if not exists public.ring_participants (
  ring_id uuid not null references public.ring_requests(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'ringing' check (status in ('ringing', 'declined', 'accepted', 'cancelled', 'expired')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (ring_id, provider_id)
);

create index if not exists ring_participants_provider_idx
  on public.ring_participants (provider_id, created_at desc, status);

create table if not exists public.ring_acceptances (
  ring_id uuid primary key references public.ring_requests(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  accepted_at timestamptz not null default now()
);

create table if not exists public.ring_declines (
  ring_id uuid not null references public.ring_requests(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  declined_at timestamptz not null default now(),
  primary key (ring_id, provider_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  last_message_preview text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, provider_id),
  check (customer_id <> provider_id)
);

create index if not exists conversations_customer_idx
  on public.conversations (customer_id, updated_at desc);
create index if not exists conversations_provider_idx
  on public.conversations (provider_id, updated_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message_type text not null default 'text' check (message_type in ('text', 'image', 'voice', 'location', 'system')),
  body text,
  media_path text,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (coalesce(length(trim(body)), 0) > 0 or media_path is not null)
);

create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  ring_id uuid references public.ring_requests(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default now(),
  unique (ring_id),
  check (customer_id <> provider_id)
);

create index if not exists reviews_provider_idx
  on public.reviews (provider_id, created_at desc);

-- Utility functions. Security-definer functions are kept in a private schema and use an explicit search_path.
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and account_role = 'admin'
  );
$$;

revoke all on function private.is_admin() from public, anon, authenticated;
grant execute on function private.is_admin() to authenticated;

create or replace function private.provider_listing_active(p_provider_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.provider_profiles pp
    join public.profiles p on p.id = pp.user_id and p.account_role = 'provider'
    where pp.user_id = p_provider_id
      and pp.is_verified = true
      and pp.is_available = true
      and exists (
        select 1 from public.subscriptions s
        where s.user_id = p_provider_id
          and s.status = 'active'
          and s.expires_at > now()
      )
  );
$$;

revoke all on function private.provider_listing_active(uuid) from public, anon, authenticated;
grant execute on function private.provider_listing_active(uuid) to authenticated;

create or replace function private.business_listing_active(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.business_profiles bp
    join public.profiles p on p.id = bp.user_id and p.account_role = 'business'
    where bp.user_id = p_business_id
      and bp.is_verified = true
      and bp.is_available = true
      and exists (
        select 1 from public.subscriptions s
        where s.user_id = p_business_id
          and s.status = 'active'
          and s.expires_at > now()
      )
  );
$$;

revoke all on function private.business_listing_active(uuid) from public, anon, authenticated;
grant execute on function private.business_listing_active(uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  insert into public.profiles (id, email, display_name, account_role, phone)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'RingLink User'),
    case
      when (new.raw_user_meta_data ->> 'account_role') in ('provider', 'business', 'customer')
        then new.raw_user_meta_data ->> 'account_role'
      else 'customer'
    end,
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = excluded.display_name,
    phone = coalesce(excluded.phone, public.profiles.phone),
    updated_at = now();
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.protect_role_changes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.account_role = 'admin' and not private.is_admin() then
    if tg_op = 'INSERT' or old.account_role <> 'admin' then
      raise exception 'Admin role cannot be self-assigned.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_profile_role_escalation on public.profiles;
create trigger prevent_profile_role_escalation
before insert or update of account_role on public.profiles
for each row execute procedure public.protect_role_changes();

create or replace function public.protect_verification_flags()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_table_name = 'profiles' then
    if new.is_verified = true and (tg_op = 'INSERT' or old.is_verified = false) and not private.is_admin() then
      raise exception 'Verification status can only be granted by an administrator.';
    end if;
  elsif tg_table_name = 'provider_profiles' then
    if new.is_verified = true and (tg_op = 'INSERT' or old.is_verified = false) and not private.is_admin() then
      raise exception 'Verification status can only be granted by an administrator.';
    end if;
  elsif tg_table_name = 'business_profiles' then
    if new.is_verified = true and (tg_op = 'INSERT' or old.is_verified = false) and not private.is_admin() then
      raise exception 'Verification status can only be granted by an administrator.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_verification on public.profiles;
create trigger protect_profile_verification
before insert or update of is_verified on public.profiles
for each row execute procedure public.protect_verification_flags();

drop trigger if exists protect_provider_verification on public.provider_profiles;
create trigger protect_provider_verification
before insert or update of is_verified on public.provider_profiles
for each row execute procedure public.protect_verification_flags();

drop trigger if exists protect_business_verification on public.business_profiles;
create trigger protect_business_verification
before insert or update of is_verified on public.business_profiles
for each row execute procedure public.protect_verification_flags();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute procedure public.touch_updated_at();
drop trigger if exists provider_profiles_touch_updated_at on public.provider_profiles;
create trigger provider_profiles_touch_updated_at before update on public.provider_profiles
for each row execute procedure public.touch_updated_at();
drop trigger if exists business_profiles_touch_updated_at on public.business_profiles;
create trigger business_profiles_touch_updated_at before update on public.business_profiles
for each row execute procedure public.touch_updated_at();
drop trigger if exists subscriptions_touch_updated_at on public.subscriptions;
create trigger subscriptions_touch_updated_at before update on public.subscriptions
for each row execute procedure public.touch_updated_at();
drop trigger if exists conversations_touch_updated_at on public.conversations;
create trigger conversations_touch_updated_at before update on public.conversations
for each row execute procedure public.touch_updated_at();

create or replace function public.nearby_providers(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters double precision default 1500,
  p_category_id uuid default null,
  p_query text default '',
  p_limit integer default 30
)
returns table (
  provider_id uuid,
  display_name text,
  avatar_url text,
  phone text,
  city text,
  profession text,
  location_label text,
  is_available boolean,
  is_verified boolean,
  average_rating numeric,
  total_reviews integer,
  distance_meters double precision,
  category_ids uuid[],
  category_names text[],
  service_names text[]
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  with origin as (
    select extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography as geo
  ),
  ranked as (
    select
      pp.user_id as provider_id,
      p.display_name,
      p.avatar_url,
      p.phone,
      p.city,
      pp.profession,
      pp.location_label,
      pp.is_available,
      pp.is_verified,
      pp.average_rating,
      pp.total_reviews,
      extensions.st_distance(pp.location, origin.geo) as distance_meters,
      coalesce(s.category_ids, '{}'::uuid[]) as category_ids,
      coalesce(s.category_names, '{}'::text[]) as category_names,
      coalesce(s.service_names, '{}'::text[]) as service_names
    from public.provider_profiles pp
    join public.profiles p on p.id = pp.user_id
    cross join origin
    left join lateral (
      select
        array_agg(distinct ps.category_id) as category_ids,
        array_agg(distinct c.name) as category_names,
        array_agg(distinct ps.service_name) as service_names
      from public.provider_services ps
      join public.categories c on c.id = ps.category_id and c.is_active = true
      where ps.provider_id = pp.user_id
    ) s on true
    where private.provider_listing_active(pp.user_id)
      and pp.location is not null
      and extensions.st_dwithin(
        pp.location,
        origin.geo,
        least(greatest(coalesce(p_radius_meters, 1500), 100), 50000)
      )
      and (
        p_category_id is null
        or exists (
          select 1 from public.provider_services ps
          where ps.provider_id = pp.user_id and ps.category_id = p_category_id
        )
      )
      and (
        trim(coalesce(p_query, '')) = ''
        or p.display_name ilike '%' || trim(p_query) || '%'
        or pp.profession ilike '%' || trim(p_query) || '%'
        or exists (
          select 1 from public.provider_services ps
          where ps.provider_id = pp.user_id
            and ps.service_name ilike '%' || trim(p_query) || '%'
        )
        or exists (
          select 1
          from public.provider_services ps
          join public.categories c on c.id = ps.category_id
          where ps.provider_id = pp.user_id
            and c.name ilike '%' || trim(p_query) || '%'
        )
      )
    order by extensions.st_distance(pp.location, origin.geo), pp.average_rating desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  )
  select * from ranked;
$$;

revoke all on function public.nearby_providers(double precision, double precision, double precision, uuid, text, integer) from public, anon;
grant execute on function public.nearby_providers(double precision, double precision, double precision, uuid, text, integer) to authenticated;

create or replace function public.nearby_businesses(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters double precision default 1500,
  p_category_id uuid default null,
  p_query text default '',
  p_limit integer default 30
)
returns table (
  business_id uuid,
  business_name text,
  phone text,
  city text,
  description text,
  location_label text,
  is_available boolean,
  is_verified boolean,
  distance_meters double precision,
  category_ids uuid[],
  category_names text[],
  service_names text[]
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  with origin as (
    select extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography as geo
  )
  select
    bp.user_id as business_id,
    bp.business_name,
    bp.phone,
    bp.city,
    bp.description,
    bp.location_label,
    bp.is_available,
    bp.is_verified,
    extensions.st_distance(bp.location, origin.geo) as distance_meters,
    coalesce(s.category_ids, '{}'::uuid[]) as category_ids,
    coalesce(s.category_names, '{}'::text[]) as category_names,
    coalesce(s.service_names, '{}'::text[]) as service_names
  from public.business_profiles bp
  cross join origin
  left join lateral (
    select
      array_agg(distinct bs.category_id) as category_ids,
      array_agg(distinct c.name) as category_names,
      array_agg(distinct bs.service_name) as service_names
    from public.business_services bs
    join public.categories c on c.id = bs.category_id and c.is_active = true
    where bs.business_id = bp.user_id
  ) s on true
  where private.business_listing_active(bp.user_id)
    and bp.location is not null
    and extensions.st_dwithin(bp.location, origin.geo, least(greatest(coalesce(p_radius_meters, 1500), 100), 50000))
    and (
      p_category_id is null
      or exists (
        select 1 from public.business_services bs
        where bs.business_id = bp.user_id and bs.category_id = p_category_id
      )
    )
    and (
      trim(coalesce(p_query, '')) = ''
      or bp.business_name ilike '%' || trim(p_query) || '%'
      or coalesce(bp.description, '') ilike '%' || trim(p_query) || '%'
      or exists (
        select 1 from public.business_services bs
        where bs.business_id = bp.user_id
          and bs.service_name ilike '%' || trim(p_query) || '%'
      )
      or exists (
        select 1 from public.business_services bs
        join public.categories c on c.id = bs.category_id
        where bs.business_id = bp.user_id
          and c.name ilike '%' || trim(p_query) || '%'
      )
    )
  order by extensions.st_distance(bp.location, origin.geo)
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

revoke all on function public.nearby_businesses(double precision, double precision, double precision, uuid, text, integer) from public, anon;
grant execute on function public.nearby_businesses(double precision, double precision, double precision, uuid, text, integer) to authenticated;

create or replace function private.populate_ring_participants()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  insert into public.ring_participants (ring_id, provider_id)
  select new.id, pp.user_id
  from public.provider_profiles pp
  where pp.is_available = true
    and pp.location is not null
    and private.provider_listing_active(pp.user_id)
    and extensions.st_dwithin(pp.location, new.origin, new.radius_meters)
    and exists (
      select 1 from public.provider_services ps
      where ps.provider_id = pp.user_id and ps.category_id = new.category_id
    )
  order by extensions.st_distance(pp.location, new.origin)
  limit 25;

  return new;
end;
$$;

drop trigger if exists ring_request_populate_participants on public.ring_requests;
create trigger ring_request_populate_participants
after insert on public.ring_requests
for each row execute procedure private.populate_ring_participants();

create or replace function private.process_ring_acceptance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  ring_row public.ring_requests%rowtype;
begin
  select * into ring_row
  from public.ring_requests
  where id = new.ring_id
  for update;

  if ring_row.id is null then
    raise exception 'Ring request not found.';
  end if;

  if new.provider_id <> (select provider_id from public.ring_participants where ring_id = new.ring_id and provider_id = new.provider_id) then
    raise exception 'Provider is not a participant in this Ring.';
  end if;

  if ring_row.status <> 'ringing' then
    raise exception 'This Ring has already been closed.';
  end if;

  if ring_row.expires_at <= now() then
    update public.ring_requests
      set status = 'expired', closed_at = now()
    where id = new.ring_id and status = 'ringing';
    update public.ring_participants
      set status = 'expired', responded_at = coalesce(responded_at, now())
    where ring_id = new.ring_id and status = 'ringing';
    raise exception 'This Ring has expired.';
  end if;

  if not exists (
    select 1 from public.ring_participants rp
    where rp.ring_id = new.ring_id
      and rp.provider_id = new.provider_id
      and rp.status = 'ringing'
  ) then
    raise exception 'You can no longer accept this Ring.';
  end if;

  update public.ring_requests
    set status = 'accepted', winner_provider_id = new.provider_id, closed_at = now()
  where id = new.ring_id;

  update public.ring_participants
    set status = case when provider_id = new.provider_id then 'accepted' else 'cancelled' end,
        responded_at = coalesce(responded_at, now())
  where ring_id = new.ring_id;

  return new;
end;
$$;

drop trigger if exists process_ring_acceptance on public.ring_acceptances;
create trigger process_ring_acceptance
before insert on public.ring_acceptances
for each row execute procedure private.process_ring_acceptance();

create or replace function private.process_ring_decline()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  update public.ring_participants
  set status = 'declined', responded_at = now()
  where ring_id = new.ring_id and provider_id = new.provider_id and status = 'ringing';
  return new;
end;
$$;

drop trigger if exists process_ring_decline on public.ring_declines;
create trigger process_ring_decline
after insert on public.ring_declines
for each row execute procedure private.process_ring_decline();

create or replace function private.create_conversation_from_ring()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.status = 'accepted' and new.winner_provider_id is not null then
    insert into public.conversations (customer_id, provider_id)
    values (new.customer_id, new.winner_provider_id)
    on conflict (customer_id, provider_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists ring_request_create_conversation on public.ring_requests;
create trigger ring_request_create_conversation
after update of status on public.ring_requests
for each row when (new.status = 'accepted')
execute procedure private.create_conversation_from_ring();

create or replace function public.get_or_create_conversation(p_provider_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  result_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_provider_id = auth.uid() then
    raise exception 'You cannot message yourself.';
  end if;

  if not exists (
    select 1 from public.profiles where id = auth.uid() and account_role = 'customer'
  ) then
    raise exception 'Only customer accounts can start a provider conversation.';
  end if;

  if not exists (select 1 from public.provider_profiles where user_id = p_provider_id) then
    raise exception 'Provider not found.';
  end if;

  insert into public.conversations (customer_id, provider_id)
  values (auth.uid(), p_provider_id)
  on conflict (customer_id, provider_id)
  do update set updated_at = now()
  returning id into result_id;

  return result_id;
end;
$$;

revoke all on function public.get_or_create_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_conversation(uuid) to authenticated;

create or replace function private.refresh_provider_rating(p_provider_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  update public.provider_profiles pp
  set average_rating = coalesce((select round(avg(r.rating)::numeric, 2) from public.reviews r where r.provider_id = p_provider_id), 0),
      total_reviews = (select count(*) from public.reviews r where r.provider_id = p_provider_id),
      updated_at = now()
  where pp.user_id = p_provider_id;
end;
$$;

create or replace function private.refresh_rating_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform private.refresh_provider_rating(coalesce(new.provider_id, old.provider_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists refresh_rating_after_review on public.reviews;
create trigger refresh_rating_after_review
after insert or update or delete on public.reviews
for each row execute procedure private.refresh_rating_trigger();

-- Public review insert is restricted by RLS and the following trigger verifies a winning Ring.
create or replace function private.validate_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.customer_id <> auth.uid() then
    raise exception 'Customer identity mismatch.';
  end if;

  if new.ring_id is null then
    raise exception 'Review must reference an accepted Ring.';
  end if;

  if not exists (
    select 1 from public.ring_requests rr
    where rr.id = new.ring_id
      and rr.customer_id = new.customer_id
      and rr.winner_provider_id = new.provider_id
      and rr.status = 'accepted'
  ) then
    raise exception 'Review must reference a Ring won by this provider.';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_review_before_insert on public.reviews;
create trigger validate_review_before_insert
before insert on public.reviews
for each row execute procedure private.validate_review();

-- Expire stale Rings when the application explicitly touches them.
create or replace function public.expire_ring(p_ring_id uuid)
returns boolean
language sql
security invoker
set search_path = public, pg_catalog
as $$
  update public.ring_requests
  set status = 'expired', closed_at = now()
  where id = p_ring_id
    and customer_id = auth.uid()
    and status = 'ringing'
    and expires_at <= now()
  returning true;
$$;

revoke all on function public.expire_ring(uuid) from public, anon;
grant execute on function public.expire_ring(uuid) to authenticated;

create or replace function public.get_ring_contact(p_ring_id uuid)
returns table (contact_user_id uuid, display_name text, phone text, avatar_url text, account_role text)
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  ring_row public.ring_requests%rowtype;
  contact_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select * into ring_row from public.ring_requests where id = p_ring_id;
  if ring_row.id is null or ring_row.status <> 'accepted' then
    return;
  end if;

  if ring_row.customer_id = auth.uid() then
    contact_id := ring_row.winner_provider_id;
  elsif ring_row.winner_provider_id = auth.uid() then
    contact_id := ring_row.customer_id;
  else
    return;
  end if;

  return query
  select p.id, p.display_name, p.phone, p.avatar_url, p.account_role
  from public.profiles p
  where p.id = contact_id;
end;
$$;

revoke all on function public.get_ring_contact(uuid) from public, anon;
grant execute on function public.get_ring_contact(uuid) to authenticated;

create or replace function private.close_ring_participants()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.status = 'cancelled' then
    update public.ring_participants
    set status = 'cancelled', responded_at = coalesce(responded_at, now())
    where ring_id = new.id and status = 'ringing';
  elsif new.status = 'expired' then
    update public.ring_participants
    set status = 'expired', responded_at = coalesce(responded_at, now())
    where ring_id = new.id and status = 'ringing';
  end if;
  return new;
end;
$$;

drop trigger if exists close_ring_participants_after_update on public.ring_requests;
create trigger close_ring_participants_after_update
after update of status on public.ring_requests
for each row execute procedure private.close_ring_participants();

-- Data API privileges. RLS policies below are the actual authorization rules.
grant usage on schema public to authenticated;
grant usage on schema private to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.provider_profiles to authenticated;
grant select, insert, update, delete on public.provider_services to authenticated;
grant select, insert, update, delete on public.business_profiles to authenticated;
grant select, insert, update, delete on public.business_services to authenticated;
grant select, insert, update, delete on public.subscriptions to authenticated;
grant select, insert, update, delete on public.verification_requests to authenticated;
grant select, insert, update, delete on public.saved_locations to authenticated;
grant select, insert, update, delete on public.ring_requests to authenticated;
grant select, insert, update, delete on public.ring_participants to authenticated;
grant select, insert, update, delete on public.ring_acceptances to authenticated;
grant select, insert, update, delete on public.ring_declines to authenticated;
grant select, insert, update, delete on public.conversations to authenticated;
grant select, insert, update, delete on public.messages to authenticated;
grant select, insert, update, delete on public.reviews to authenticated;

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.provider_profiles enable row level security;
alter table public.provider_services enable row level security;
alter table public.business_profiles enable row level security;
alter table public.business_services enable row level security;
alter table public.subscriptions enable row level security;
alter table public.verification_requests enable row level security;
alter table public.saved_locations enable row level security;
alter table public.ring_requests enable row level security;
alter table public.ring_participants enable row level security;
alter table public.ring_acceptances enable row level security;
alter table public.ring_declines enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;

-- Profiles: users can manage themselves; active provider profiles are publicly readable to authenticated users.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.provider_profiles pp
    where pp.user_id = public.profiles.id
      and private.provider_listing_active(pp.user_id)
  )
  or private.is_admin()
);

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
for insert to authenticated
with check (id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
for update to authenticated
using (id = auth.uid() or private.is_admin())
with check (id = auth.uid() or private.is_admin());

-- Categories are public to authenticated users; only admins can mutate them.
drop policy if exists categories_select on public.categories;
create policy categories_select on public.categories
for select to authenticated using (is_active = true or private.is_admin());

drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
for all to authenticated
using (private.is_admin()) with check (private.is_admin());

-- Provider profiles: active verified listings are visible, owners/admins can see their own records.
drop policy if exists provider_profiles_select on public.provider_profiles;
create policy provider_profiles_select on public.provider_profiles
for select to authenticated
using (user_id = auth.uid() or private.provider_listing_active(user_id) or private.is_admin());

drop policy if exists provider_profiles_insert on public.provider_profiles;
create policy provider_profiles_insert on public.provider_profiles
for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_role = 'provider'));

drop policy if exists provider_profiles_update on public.provider_profiles;
create policy provider_profiles_update on public.provider_profiles
for update to authenticated
using (user_id = auth.uid() or private.is_admin())
with check (user_id = auth.uid() or private.is_admin());

-- Provider services.
drop policy if exists provider_services_select on public.provider_services;
create policy provider_services_select on public.provider_services
for select to authenticated
using (provider_id = auth.uid() or private.provider_listing_active(provider_id) or private.is_admin());

drop policy if exists provider_services_insert on public.provider_services;
create policy provider_services_insert on public.provider_services
for insert to authenticated
with check (provider_id = auth.uid() or private.is_admin());

drop policy if exists provider_services_update on public.provider_services;
create policy provider_services_update on public.provider_services
for update to authenticated
using (provider_id = auth.uid() or private.is_admin())
with check (provider_id = auth.uid() or private.is_admin());

drop policy if exists provider_services_delete on public.provider_services;
create policy provider_services_delete on public.provider_services
for delete to authenticated
using (provider_id = auth.uid() or private.is_admin());

-- Business profiles and services are public only when the business listing is active; owners/admins can manage them.
drop policy if exists business_profiles_select on public.business_profiles;
create policy business_profiles_select on public.business_profiles
for select to authenticated
using (user_id = auth.uid() or private.business_listing_active(user_id) or private.is_admin());

drop policy if exists business_profiles_insert on public.business_profiles;
create policy business_profiles_insert on public.business_profiles
for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_role = 'business'));

drop policy if exists business_profiles_update on public.business_profiles;
create policy business_profiles_update on public.business_profiles
for update to authenticated
using (user_id = auth.uid() or private.is_admin())
with check (user_id = auth.uid() or private.is_admin());

drop policy if exists business_services_select on public.business_services;
create policy business_services_select on public.business_services
for select to authenticated
using (business_id = auth.uid() or private.business_listing_active(business_id) or private.is_admin());

drop policy if exists business_services_insert on public.business_services;
create policy business_services_insert on public.business_services
for insert to authenticated
with check (business_id = auth.uid() or private.is_admin());
drop policy if exists business_services_update on public.business_services;
create policy business_services_update on public.business_services
for update to authenticated
using (business_id = auth.uid() or private.is_admin())
with check (business_id = auth.uid() or private.is_admin());
drop policy if exists business_services_delete on public.business_services;
create policy business_services_delete on public.business_services
for delete to authenticated
using (business_id = auth.uid() or private.is_admin());

-- Subscriptions are private to owners/admins.
drop policy if exists subscriptions_select on public.subscriptions;
create policy subscriptions_select on public.subscriptions
for select to authenticated
using (user_id = auth.uid() or private.is_admin());

drop policy if exists subscriptions_insert on public.subscriptions;
create policy subscriptions_insert on public.subscriptions
for insert to authenticated
with check (user_id = auth.uid() and status = 'pending');

drop policy if exists subscriptions_update on public.subscriptions;
create policy subscriptions_update on public.subscriptions
for update to authenticated
using (private.is_admin()) with check (private.is_admin());

-- Verification requests: users can create; admins can review; a rejected request may be resubmitted by its owner without changing its decision status.
drop policy if exists verification_select on public.verification_requests;
create policy verification_select on public.verification_requests
for select to authenticated
using (user_id = auth.uid() or private.is_admin());

drop policy if exists verification_insert on public.verification_requests;
create policy verification_insert on public.verification_requests
for insert to authenticated
with check (user_id = auth.uid() and status = 'pending');

drop policy if exists verification_update_owner_rejected on public.verification_requests;
create policy verification_update_owner_rejected on public.verification_requests
for update to authenticated
using (user_id = auth.uid() and status = 'rejected')
with check (user_id = auth.uid() and status = 'rejected');

drop policy if exists verification_update_admin on public.verification_requests;
create policy verification_update_admin on public.verification_requests
for update to authenticated
using (private.is_admin()) with check (private.is_admin());

-- Saved locations.
drop policy if exists saved_locations_owner on public.saved_locations;
create policy saved_locations_owner on public.saved_locations
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Rings.
drop policy if exists ring_requests_customer_select on public.ring_requests;
create policy ring_requests_customer_select on public.ring_requests
for select to authenticated
using (customer_id = auth.uid() or private.is_admin());

drop policy if exists ring_requests_customer_insert on public.ring_requests;
create policy ring_requests_customer_insert on public.ring_requests
for insert to authenticated
with check (
  customer_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_role = 'customer')
);

drop policy if exists ring_requests_customer_update on public.ring_requests;
create policy ring_requests_customer_update on public.ring_requests
for update to authenticated
using (private.is_admin() or (customer_id = auth.uid() and status = 'ringing'))
with check (
  private.is_admin()
  or (customer_id = auth.uid() and (status = 'cancelled' or (status = 'expired' and expires_at <= now())))
);

-- Participants are visible to the participating provider or originating customer.
drop policy if exists ring_participants_select on public.ring_participants;
create policy ring_participants_select on public.ring_participants
for select to authenticated
using (
  provider_id = auth.uid()
  or exists (select 1 from public.ring_requests rr where rr.id = ring_id and rr.customer_id = auth.uid())
  or private.is_admin()
);

-- Provider accepts/declines through dedicated tables; they cannot directly alter participant status.
drop policy if exists ring_acceptances_insert on public.ring_acceptances;
create policy ring_acceptances_insert on public.ring_acceptances
for insert to authenticated
with check (
  provider_id = auth.uid()
  and exists (
    select 1 from public.ring_participants rp
    where rp.ring_id = ring_acceptances.ring_id
      and rp.provider_id = auth.uid()
      and rp.status = 'ringing'
  )
);

drop policy if exists ring_acceptances_select on public.ring_acceptances;
create policy ring_acceptances_select on public.ring_acceptances
for select to authenticated
using (
  provider_id = auth.uid()
  or exists (select 1 from public.ring_requests rr where rr.id = ring_id and rr.customer_id = auth.uid())
  or private.is_admin()
);

drop policy if exists ring_declines_insert on public.ring_declines;
create policy ring_declines_insert on public.ring_declines
for insert to authenticated
with check (
  provider_id = auth.uid()
  and exists (
    select 1 from public.ring_participants rp
    where rp.ring_id = ring_declines.ring_id
      and rp.provider_id = auth.uid()
      and rp.status = 'ringing'
  )
);

drop policy if exists ring_declines_select on public.ring_declines;
create policy ring_declines_select on public.ring_declines
for select to authenticated
using (provider_id = auth.uid() or private.is_admin());

-- Conversations and messages.
drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
for select to authenticated
using (customer_id = auth.uid() or provider_id = auth.uid() or private.is_admin());

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations
for insert to authenticated
with check (customer_id = auth.uid() or provider_id = auth.uid() or private.is_admin());

drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations
for update to authenticated
using (customer_id = auth.uid() or provider_id = auth.uid() or private.is_admin())
with check (customer_id = auth.uid() or provider_id = auth.uid() or private.is_admin());

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
for select to authenticated
using (
  exists (
    select 1 from public.conversations c
    where c.id = conversation_id and (c.customer_id = auth.uid() or c.provider_id = auth.uid())
  )
  or private.is_admin()
);

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.conversations c
    where c.id = conversation_id and (c.customer_id = auth.uid() or c.provider_id = auth.uid())
  )
);

-- Reviews.
drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews
for select to authenticated
using (true);

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
for insert to authenticated
with check (customer_id = auth.uid());

-- Storage buckets for public profile photos and private verification documents.
insert into storage.buckets (id, name, public)
values ('profile-media', 'profile-media', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('verification-documents', 'verification-documents', false)
on conflict (id) do nothing;

drop policy if exists profile_media_insert on storage.objects;
create policy profile_media_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists profile_media_update on storage.objects;
create policy profile_media_update on storage.objects
for update to authenticated
using (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists profile_media_delete on storage.objects;
create policy profile_media_delete on storage.objects
for delete to authenticated
using (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists verification_documents_insert on storage.objects;
create policy verification_documents_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'verification-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists verification_documents_select on storage.objects;
create policy verification_documents_select on storage.objects
for select to authenticated
using (
  bucket_id = 'verification-documents'
  and ((storage.foldername(name))[1] = auth.uid()::text or private.is_admin())
);

drop policy if exists verification_documents_update on storage.objects;
create policy verification_documents_update on storage.objects
for update to authenticated
using (bucket_id = 'verification-documents' and ((storage.foldername(name))[1] = auth.uid()::text or private.is_admin()))
with check (bucket_id = 'verification-documents' and ((storage.foldername(name))[1] = auth.uid()::text or private.is_admin()));

drop policy if exists verification_documents_delete on storage.objects;
create policy verification_documents_delete on storage.objects
for delete to authenticated
using (bucket_id = 'verification-documents' and ((storage.foldername(name))[1] = auth.uid()::text or private.is_admin()));

-- Realtime for chats, provider ring participants and ring status.
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.ring_participants;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.ring_requests;
  exception when duplicate_object then null;
  end;
end $$;

-- Helpful indexes.
create index if not exists profiles_role_idx on public.profiles(account_role);
create index if not exists provider_services_provider_idx on public.provider_services(provider_id);
