-- Identity and ownership foundation. No operator/admin roles exist in this schema.
begin;
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  phone text not null default '' check (char_length(phone) <= 40),
  locale text not null default 'en' check (locale in ('en','ur')),
  initial_experience text check (initial_experience in ('customer','baker')),
  image_path text check (image_path is null or (split_part(image_path,'/',1) = id::text and image_path ~ '^[0-9a-f-]+/[0-9a-f-]+\.(jpg|png|webp)$')),
  created_at timestamptz not null default now()
);
create table public.customer_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  identity_complete boolean not null default false
);
create table public.baker_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  identity_complete boolean not null default false
);
create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.baker_profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  image_path text check (image_path is null or (split_part(image_path,'/',1) = id::text and image_path ~ '^[0-9a-f-]+/profile/[0-9a-f-]+\.(jpg|png|webp)$')),
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.profiles add constraint completed_profile_name check (initial_experience is null or char_length(btrim(display_name)) between 1 and 100);
comment on column public.profiles.initial_experience is 'Initial navigation/onboarding intent only; not an admin claim. Dual-role product policy is unresolved.';
comment on column public.businesses.onboarding_complete is 'Full business onboarding belongs to Phase 3; clients cannot set this field.';

alter table public.profiles enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.baker_profiles enable row level security;
alter table public.businesses enable row level security;
revoke all on public.profiles,public.customer_profiles,public.baker_profiles,public.businesses from public,anon,authenticated;
grant select on public.profiles,public.customer_profiles,public.baker_profiles,public.businesses to authenticated;
grant update(display_name,phone,locale,image_path) on public.profiles to authenticated;
grant update(name,image_path) on public.businesses to authenticated;
create policy profiles_read_self on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy customers_read_self on public.customer_profiles for select to authenticated using (id=(select auth.uid()));
create policy bakers_read_self on public.baker_profiles for select to authenticated using (id=(select auth.uid()));
create policy businesses_read_owner on public.businesses for select to authenticated using (owner_id=(select auth.uid()));
create policy businesses_update_owner on public.businesses for update to authenticated using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));

create function public.initialize_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Metadata is untrusted: never copy role/admin/ownership/onboarding flags.
  insert into public.profiles(id,display_name)
  values (new.id,left(coalesce(new.raw_user_meta_data->>'display_name',''),100))
  on conflict(id) do nothing;
  return new;
end $$;
revoke all on function public.initialize_profile() from public,anon,authenticated;
create trigger bakequote_auth_profile after insert on auth.users
for each row execute function public.initialize_profile();
-- Support existing development identities, with no metadata-derived privileges.
insert into public.profiles(id) select id from auth.users on conflict(id) do nothing;

create function public.complete_identity(p_experience text,p_name text,p_phone text default '',p_business_name text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); chosen text;
begin
  if actor is null or not exists(select 1 from auth.users where id=actor and email_confirmed_at is not null)
    then raise exception 'Verified account required' using errcode='42501'; end if;
  if p_experience is null or p_experience not in ('customer','baker')
    or p_name is null or char_length(btrim(p_name)) not between 1 and 100
    or p_phone is null or char_length(p_phone)>40
    or (p_experience='baker' and (p_business_name is null or char_length(btrim(p_business_name)) not between 1 and 100))
    then raise exception 'Invalid identity details' using errcode='22023'; end if;
  select initial_experience into chosen from public.profiles where id=actor for update;
  if not found then raise exception 'Profile missing' using errcode='23503'; end if;
  if chosen is not null and chosen<>p_experience then raise exception 'Initial experience already selected' using errcode='42501'; end if;
  update public.profiles set initial_experience=p_experience,display_name=btrim(p_name),phone=p_phone where id=actor;
  if p_experience='customer' then
    insert into public.customer_profiles(id,identity_complete) values(actor,true) on conflict(id) do nothing;
  else
    insert into public.baker_profiles(id,identity_complete) values(actor,true) on conflict(id) do nothing;
    insert into public.businesses(owner_id,name) values(actor,btrim(p_business_name)) on conflict(owner_id) do nothing;
  end if;
end $$;
revoke all on function public.complete_identity(text,text,text,text) from public,anon;
grant execute on function public.complete_identity(text,text,text,text) to authenticated;
commit;
