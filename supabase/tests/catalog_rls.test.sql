BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT no_plan();
INSERT INTO auth.users(id,email_confirmed_at,raw_user_meta_data) VALUES
 ('90000000-0000-4000-8000-000000000001',now(),'{}'),
 ('90000000-0000-4000-8000-000000000002',now(),'{}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
SELECT public.complete_identity('baker','Catalog A','','Catalog A');
RESET ROLE;
SELECT set_config('bq.test.business',(SELECT id::text FROM public.businesses WHERE owner_id='90000000-0000-4000-8000-000000000001'),true);
SELECT set_config('bq.test.code',(SELECT code FROM public.businesses WHERE id=current_setting('bq.test.business')::uuid),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
SELECT throws_ok(format('SELECT public.activate_business(%L,0)',current_setting('bq.test.business')),'22023',NULL,'Incomplete business cannot activate');
SELECT public.save_baker_workspace(current_setting('bq.test.business')::uuid,0,
 '{"name":"Catalog A","description":"Public description","owner_name":"Private owner","contact_phone":"Private phone","location":"Public location","pickup_address":"Private address","pickup_enabled":true,"delivery_enabled":true,"minimum_paisa":0}',
 '[{"id":"91000000-0000-4000-8000-000000000001","name":"Cake","description":"Test","kind":"cake","active":true,"minimum_quantity":1,"variants":[{"id":"92000000-0000-4000-8000-000000000001","label":"2 lb","units":907,"price_paisa":300000,"active":true}],"options":[{"id":"93000000-0000-4000-8000-000000000001","kind":"finish","label":"Buttercream","price_paisa":50000,"active":true},{"id":"93000000-0000-4000-8000-000000000002","kind":"extra","label":"Topper","price_paisa":30000,"active":true}]}]',
 '[{"id":"94000000-0000-4000-8000-000000000001","name":"Delivery","fee_paisa":30000,"active":true}]');
SELECT is((SELECT count(*)::int FROM public.products WHERE id='91000000-0000-4000-8000-000000000001'),1,'Owner catalog saved');
SELECT throws_ok(format('SELECT public.activate_business(%L,0)',current_setting('bq.test.business')),'40001',NULL,'Stale activation rejected');
SELECT public.activate_business(current_setting('bq.test.business')::uuid,1);
SELECT is((public.catalog_estimate('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',ARRAY['93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002']::uuid[],1,'94000000-0000-4000-8000-000000000001')->>'total_paisa')::bigint,410000::bigint,'Server PKR 4100 estimate');
SELECT throws_ok($$SELECT public.catalog_estimate('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','{}',0,NULL)$$,'22023',NULL,'Minimum quantity enforced');
SELECT set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
SELECT public.complete_identity('baker','Catalog B','','Catalog B');
SELECT is((SELECT count(*)::int FROM public.products WHERE id='91000000-0000-4000-8000-000000000001'),0,'Other baker cannot read owner catalog records');
SELECT throws_ok(format('SELECT public.activate_business(%L,2)',current_setting('bq.test.business')),'42501',NULL,'Other baker cannot activate business');
SELECT throws_ok(format('SELECT public.set_baker_image(%L,2,''cover'',NULL,NULL)',current_setting('bq.test.business')),'42501',NULL,'Other baker cannot change business image');
SELECT throws_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('order-references','unrelated/file.png')$$,'42501',NULL,'Order private uploads remain closed');
SELECT throws_ok($$INSERT INTO storage.objects(bucket_id,name) VALUES('conversation-attachments','unrelated/file.png')$$,'42501',NULL,'Conversation private uploads remain closed');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true);
SELECT ok(public.public_business(current_setting('bq.test.code')) ? 'name','Active public business readable');
SELECT ok(NOT(public.public_business(current_setting('bq.test.code')) ?| ARRAY['owner_id','owner_name','contact_phone','pickup_address']),'Public projection excludes private fields');
SELECT throws_ok('SELECT * FROM public.products','42501',NULL,'Anonymous raw catalog tables closed');
SELECT * FROM finish();
ROLLBACK;
