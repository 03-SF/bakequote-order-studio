begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
-- Insert Auth identities as a migration/test administrator; the trigger is exercised.
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('10000000-0000-0000-0000-000000000001','customer@example.test',now(),'{"role":"admin","is_admin":true,"display_name":"Customer"}'),
 ('10000000-0000-0000-0000-000000000002','baker-a@example.test',now(),'{}'),
 ('10000000-0000-0000-0000-000000000003','baker-b@example.test',now(),'{}'),
 ('10000000-0000-0000-0000-000000000004','unverified@example.test',null,'{}');
select is((select count(*)::int from public.profiles where id::text like '10000000-%'),4,'Auth trigger initializes profiles');
select is((select initial_experience from public.profiles where id='10000000-0000-0000-0000-000000000001'),null,'Metadata cannot set experience or privileged roles');
select ok(not has_table_privilege('anon','public.profiles','SELECT'),'Anonymous profile select not granted');
select ok(not has_column_privilege('authenticated','public.profiles','initial_experience','UPDATE'),'Experience cannot be directly changed');
select ok(not has_column_privilege('authenticated','public.businesses','owner_id','UPDATE'),'Ownership cannot be directly changed');
select ok(not has_table_privilege('authenticated','public.businesses','INSERT'),'Business insertion restricted to RPC');
select ok(not has_function_privilege('anon','public.complete_identity(text,text,text,text)','EXECUTE'),'Anonymous cannot onboard');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.complete_identity('customer','Customer','','')$$,'Customer onboarding');
select lives_ok($$select public.complete_identity('customer','Customer','','')$$,'Onboarding retry is idempotent');
select throws_ok($$select public.complete_identity('admin','Admin','','')$$,'22023',null,'No operator/admin onboarding');
select throws_ok($$select public.complete_identity('baker','Customer','','Other bakery')$$,'42501',null,'Initial experience cannot silently switch');
select is((select count(*)::int from public.profiles),1,'Only own profile visible');
select is((with changed as (update public.profiles set display_name='Intruder' where id='10000000-0000-0000-0000-000000000002' returning id) select count(*)::int from changed),0,'Cannot update another profile');
select throws_ok($$update public.profiles set initial_experience='baker'$$,'42501',null,'Cannot update role column');
select lives_ok($$update public.profiles set phone='123',locale='ur'$$,'Own safe profile fields editable');

select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.complete_identity('baker','Baker A','','Bakery A')$$,'Baker creates owned private draft');
select is((select count(*)::int from public.businesses),1,'Baker sees own business');
select is((select onboarding_complete from public.businesses),false,'Full onboarding remains incomplete');
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select lives_ok($$select public.complete_identity('baker','Baker B','','Bakery B')$$,'Second baker onboarding');
select is((select count(*)::int from public.businesses),1,'Second baker sees only own business');
select is((with changed as (update public.businesses set name='Intruder' where owner_id='10000000-0000-0000-0000-000000000002' returning id) select count(*)::int from changed),0,'Baker cannot alter another business');
select throws_ok($$update public.businesses set owner_id='10000000-0000-0000-0000-000000000002'$$,'42501',null,'Cannot transfer ownership');
select throws_ok($$update public.businesses set onboarding_complete=true$$,'42501',null,'Cannot self-publish completed onboarding');
select throws_ok($$insert into storage.objects(bucket_id,name) values('order-references','10000000-0000-0000-0000-000000000003/reference.png')$$,'42501',null,'Private order uploads denied until membership exists');
select throws_ok($$insert into storage.objects(bucket_id,name) values('conversation-attachments','10000000-0000-0000-0000-000000000003/message.png')$$,'42501',null,'Private conversation uploads denied');
select throws_ok($$insert into storage.objects(bucket_id,name) values('profile-images','10000000-0000-0000-0000-000000000002/11111111-1111-1111-1111-111111111111.png')$$,'42501',null,'Cannot upload in another profile path');
select lives_ok($$insert into storage.objects(bucket_id,name) values('profile-images','10000000-0000-0000-0000-000000000003/11111111-1111-1111-1111-111111111111.png')$$,'Owner can insert profile object metadata');
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from storage.objects where bucket_id='profile-images'),0,'Private image metadata hidden from unrelated user');
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select throws_ok($$select public.complete_identity('customer','Unverified','','')$$,'42501',null,'Unverified identity cannot complete onboarding');
reset role;
select * from finish();
rollback;
