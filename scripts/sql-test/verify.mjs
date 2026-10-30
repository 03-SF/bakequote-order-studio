process.on('uncaughtException', e => { console.error('FAIL',e.message,e.code??'',e.where??''); process.exit(1); });
// Real PostgreSQL/WASM semantics with modeled Auth/Storage schemas.
// This does NOT run Supabase services, HTTP, email, or native callbacks.
import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
let passed = 0;
const check = (condition, label) => { assert.ok(condition, label); console.log(`PASS ${++passed}: ${label}`); };
await db.exec(`
 CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;
 CREATE SCHEMA auth; CREATE SCHEMA storage;
 CREATE TABLE auth.users(id uuid PRIMARY KEY,raw_user_meta_data jsonb DEFAULT '{}',email_confirmed_at timestamptz);
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 CREATE TABLE storage.objects(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,bucket_id text REFERENCES storage.buckets(id),name text NOT NULL,UNIQUE(bucket_id,name));
 ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
 CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1] $$;
 GRANT USAGE ON SCHEMA public,auth,storage TO anon,authenticated;
 GRANT ALL ON storage.objects TO anon,authenticated;
`);
const dir = new URL('../../supabase/migrations/',import.meta.url);
for (const file of (await readdir(dir)).filter(f=>f.endsWith('.sql')).sort()) {
 await db.exec((await readFile(new URL(file,dir),'utf8')).replace(/^\uFEFF/,''));
 console.log(`APPLIED ${file}`);
 if(file.startsWith('20261026000200')) await db.exec(`INSERT INTO auth.users(id) VALUES('00000000-0000-4000-8000-000000000004'); UPDATE public.profiles SET locale='ur';`);
 if(file.startsWith('20261026000300')) check((await db.query(`SELECT locale FROM public.profiles`)).rows[0].locale==='en','legacy locale migrated to English');
}
const a='00000000-0000-4000-8000-000000000001', b='00000000-0000-4000-8000-000000000002', c='00000000-0000-4000-8000-000000000003';
await db.query(`INSERT INTO auth.users(id,email_confirmed_at,raw_user_meta_data) VALUES($1,now(),'{"role":"admin"}'),($2,now(),'{}'),($3,now(),'{}')`,[a,b,c]);
async function as(role,id,fn) {await db.exec(`RESET ROLE`);await db.query(`SELECT set_config('request.jwt.claim.sub',$1,false)`,[id??'']);await db.exec(`SET ROLE ${role}`);try{return await fn();}finally{await db.exec('RESET ROLE');}}
async function denied(fn,label,code) {let error;try{await fn();}catch(e){error=e;}check(error && (!code || error.code===code),`${label}${error?` [${error.code}]`:''}`);}
const scalar=async(sql,params=[])=>Object.values((await db.query(sql,params)).rows[0])[0];
await as('authenticated',a,async()=>{
 check(await scalar('SELECT count(*)::int FROM public.profiles')===1,'profile initialized and only self visible');
 await denied(()=>db.query(`UPDATE public.profiles SET initial_experience='baker' WHERE id=$1`,[a]),'direct role assignment denied','42501');
 await db.query(`SELECT public.complete_identity('baker','Baker A','','A bakery')`);
 await db.query(`SELECT public.complete_identity('baker','Baker A','','A bakery')`);
 check(await scalar('SELECT count(*)::int FROM public.businesses')===1,'identity retry creates one owned draft');
});
await as('authenticated',b,()=>db.query(`SELECT public.complete_identity('baker','Baker B','','B bakery')`));
await as('authenticated',c,()=>db.query(`SELECT public.complete_identity('customer','Customer','','')`));
const businessA=await scalar('SELECT id FROM public.businesses WHERE owner_id=$1',[a]);
const businessB=await scalar('SELECT id FROM public.businesses WHERE owner_id=$1',[b]);
await as('authenticated',b,async()=>{
 check((await db.query('SELECT id FROM public.profiles WHERE id=$1',[a])).rows.length===0,'unrelated private profile hidden');
 check((await db.query(`UPDATE public.profiles SET phone='unauthorized' WHERE id=$1 RETURNING id`,[a])).rows.length===0,'unrelated private profile cannot be modified');
});
const privatePath=`${a}/50000000-0000-4000-8000-000000000009.png`;
await as('authenticated',a,async()=>{
 await db.query(`INSERT INTO storage.objects(bucket_id,name) VALUES('profile-images',$1)`,[privatePath]);
 check((await db.query('SELECT name FROM storage.objects WHERE name=$1',[privatePath])).rows.length===1,'owner private image metadata readable');
});
await as('authenticated',b,async()=>check((await db.query('SELECT name FROM storage.objects WHERE name=$1',[privatePath])).rows.length===0,'unrelated private image metadata hidden'));
const codeA=await scalar('SELECT code FROM public.businesses WHERE id=$1',[businessA]);
check(codeA!==await scalar('SELECT code FROM public.businesses WHERE id=$1',[businessB]),'unique server-generated business codes');
await as('authenticated',b,async()=>{
 check(await scalar('SELECT count(*)::int FROM public.businesses WHERE id=$1',[businessA])===0,'baker cannot read another private business');
 await denied(()=>db.query('SELECT public.activate_business($1,0)',[businessA]),'baker cannot activate another business','42501');
});
await as('authenticated',a,()=>denied(()=>db.query('SELECT public.activate_business($1,0)',[businessA]),'incomplete activation denied','22023'));
const product='10000000-0000-4000-8000-000000000001',variant='20000000-0000-4000-8000-000000000001',finish='30000000-0000-4000-8000-000000000001',extra='30000000-0000-4000-8000-000000000002',zone='40000000-0000-4000-8000-000000000001';
const details={name:'A bakery',description:'Public description',owner_name:'Private owner',contact_phone:'private phone',location:'Public area',pickup_address:'Private exact address',pickup_enabled:true,delivery_enabled:true,minimum_paisa:0};
const products=[{id:product,name:'Cake',description:'Example',kind:'cake',active:true,minimum_quantity:1,variants:[{id:variant,label:'2 lb',units:907,price_paisa:300000,active:true}],options:[{id:finish,label:'Buttercream',kind:'finish',price_paisa:50000,active:true},{id:extra,label:'Topper',kind:'extra',price_paisa:30000,active:true}]}];
const zones=[{id:zone,name:'Local',fee_paisa:30000,active:true}];
const save=(rev,ps=products,ds=details,zs=zones,id=businessA)=>db.query('SELECT public.save_baker_workspace($1,$2,$3,$4,$5)',[id,rev,JSON.stringify(ds),JSON.stringify(ps),JSON.stringify(zs)]);
await as('authenticated',b,()=>denied(()=>save(0),'cross-baker workspace write denied','42501'));
await as('authenticated',a,async()=>{
 await denied(()=>save(null),'null revision cannot bypass stale-save guard','40001');
 await save(0);
 check(await scalar('SELECT count(*)::int FROM public.products')===1,'catalog persisted');
 await denied(()=>save(0),'stale duplicate save rejected','40001');
 const malformed=structuredClone(products);malformed[0].variants[0].price_paisa=-1;
 await denied(()=>save(1,malformed),'negative price rejected','22023');
 check(await scalar('SELECT revision FROM public.businesses WHERE id=$1',[businessA])===1,'failed save rolled back revision');
 await denied(()=>db.query(`UPDATE public.businesses SET onboarding_complete=true`),'direct activation denied','42501');
});
await as('anon',null,async()=>{
 check(await scalar('SELECT public.public_business($1)',[codeA])===null,'draft public lookup hidden');
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[finish,extra],zone]),'anonymous draft estimate denied','42501');
 await denied(()=>db.query('SELECT * FROM public.profiles'),'anonymous private profile rejected','42501');
});
await as('authenticated',a,()=>db.query('SELECT public.activate_business($1,1)',[businessA]));
await as('anon',null,async()=>{
 const pub=await scalar('SELECT public.public_business($1)',[codeA]);
 check(pub.name==='A bakery' && !('owner_id' in pub) && !('owner_name' in pub) && !('contact_phone' in pub) && !('pickup_address' in pub),'public projection contains only approved fields');
 const price=await scalar('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[finish,extra],zone]);
 check(price.subtotal_paisa===380000 && price.delivery_paisa===30000 && price.total_paisa===410000,'server PKR 4,100 regression');
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[finish,finish],zone]),'duplicate options rejected','22023');
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,0,$4)',[product,variant,[],zone]),'minimum quantity enforced','22023');
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[businessB],zone]),'unrelated product option rejected','22023');
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[],businessB]),'unrelated delivery zone rejected','22023');
});
await as('authenticated',a,async()=>{
 await save(2,products,{...details,minimum_paisa:400000});
 await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[finish,extra],zone]),'minimum subtotal excludes delivery','22023');
 await save(3,products,details);
});
const imagePath=`${businessA}/${product}/50000000-0000-4000-8000-000000000001.png`;
await as('authenticated',a,async()=>{
 await db.query(`INSERT INTO storage.objects(bucket_id,name) VALUES('product-images',$1)`,[imagePath]);
 await db.query(`SELECT public.set_baker_image($1,4,'product',$2,$3)`,[businessA,product,imagePath]);
 check(await scalar('SELECT image_path FROM public.products WHERE id=$1',[product])===imagePath,'owned product image pointer saved');
 check((await db.query(`DELETE FROM storage.objects WHERE name=$1 RETURNING id`,[imagePath])).rows.length===0,'referenced image cannot be deleted');
});
await as('authenticated',a,async()=>{
 for(const slot of ['profile','cover']) {
  const path=`${businessA}/${slot}/50000000-0000-4000-8000-000000000003.png`;
  await db.query(`INSERT INTO storage.objects(bucket_id,name) VALUES('business-images',$1)`,[path]);
  check((await db.query(`SELECT name FROM storage.objects WHERE name=$1`,[path])).rows.length===1,`owner ${slot} upload metadata visible`);
  await db.query(`DELETE FROM storage.objects WHERE name=$1`,[path]);
 }
});
await as('authenticated',b,async()=>{
 await denied(()=>db.query(`INSERT INTO storage.objects(bucket_id,name) VALUES('product-images',$1)`,[`${businessA}/${product}/50000000-0000-4000-8000-000000000002.png`]),'cross-baker product upload denied','42501');
 await denied(()=>db.query(`SELECT public.set_baker_image($1,5,'product',$2,$3)`,[businessA,product,imagePath]),'cross-baker image pointer denied','42501');
 for(const bucket of ['order-references','conversation-attachments']) await denied(()=>db.query('INSERT INTO storage.objects(bucket_id,name) VALUES($1,$2)',[bucket,`${b}/test.png`]),`${bucket} upload closed`,'42501');
});
await as('authenticated',a,async()=>{
 await db.query(`SELECT public.set_baker_image($1,5,'product',$2,NULL)`,[businessA,product]);
 check((await db.query('DELETE FROM storage.objects WHERE name=$1 RETURNING id',[imagePath])).rows.length===1,'unreferenced replaced image cleanup allowed');
 const inactive=structuredClone(products);inactive[0].active=false;await save(6,inactive);
 check(await scalar('SELECT count(*)::int FROM public.products')===1,'deactivation preserves catalog record');
});
await as('anon',null,()=>denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,1,$4)',[product,variant,[],zone]),'inactive product unavailable','22023'));
await as('authenticated',a,async()=>{
 await db.exec('BEGIN');
 try {
  const heavy=structuredClone(products);heavy[0].active=true;heavy[0].variants[0].price_paisa=100000000000;
  heavy[0].options=Array.from({length:20},(_,i)=>({id:`60000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,label:'Large extra',kind:'extra',price_paisa:100000000000,active:true}));
  await save(7,heavy);
  await denied(()=>db.query('SELECT public.catalog_estimate($1,$2,$3,10000,$4)',[product,variant,heavy[0].options.map(o=>o.id),zone]),'oversized estimate rejected before client precision loss','22023');
 } finally {await db.exec('ROLLBACK');}
});
// Phase 4 customer discovery: real PostgreSQL execution with modeled identities.
await as('authenticated',a,()=>save(7));
await as('anon',null,async()=>{
 const menu=(await db.query('SELECT * FROM public.public_menu($1,NULL,1)',[codeA.toLowerCase()])).rows;
 check(menu.length===1,'public menu code normalizes and returns bounded active products');
 const item=Object.values(menu[0])[0];
 check(!('business_id' in item) && !('active' in item) && !('active' in item.options[0]),'menu explicit projection excludes internal fields');
 check((await db.query('SELECT * FROM public.public_menu($1,$2,1)',[codeA,product])).rows.length===0,'menu keyset cursor has no repeated item');
 await denied(()=>db.query('SELECT * FROM public.public_menu($1,NULL,31)',[codeA]),'oversized menu page rejected','22023');
 await denied(()=>db.query('SELECT public.set_saved_business($1,true)',[businessA]),'anonymous saves denied','42501');
});
await as('authenticated',c,async()=>{
 await db.query('SELECT public.set_saved_business($1,true)',[businessA]);
 await db.query('SELECT public.set_saved_business($1,true)',[businessA]);
 check(await scalar('SELECT count(*)::int FROM public.saved_businesses')===1,'saved bakery duplicate retry is idempotent');
 check((await db.query('SELECT * FROM public.saved_bakeries(NULL,20)')).rows[0].profile.name==='A bakery','saved bakery returns public profile');
});
await as('authenticated',b,async()=>{
 check(await scalar('SELECT count(*)::int FROM public.saved_businesses')===0,'other account cannot read saved bakeries');
 await denied(()=>db.query('INSERT INTO public.saved_businesses VALUES($1,$2)',[c,businessB]),'direct cross-account saved insert denied','42501');
 await denied(()=>db.query('SELECT public.set_business_publication($1,8,false)',[businessA]),'other baker cannot unpublish business','42501');
});
await as('authenticated',a,()=>db.query('SELECT public.set_business_publication($1,8,false)',[businessA]));
await as('anon',null,async()=>{
 check(await scalar('SELECT public.public_business($1)',[codeA])===null,'unpublished bakery hidden');
 check((await db.query('SELECT * FROM public.public_menu($1)',[codeA])).rows.length===0,'unpublished menu hidden');
});
await as('authenticated',c,async()=>{
 check((await db.query('SELECT * FROM public.saved_bakeries()')).rows[0].profile===null,'saved unavailable bakery exposes no private fallback');
 await db.query('SELECT public.set_saved_business($1,false)',[businessA]);
 check(await scalar('SELECT count(*)::int FROM public.saved_businesses')===0,'unavailable saved bakery can be removed');
 await denied(()=>db.query('SELECT public.set_saved_business($1,true)',[businessA]),'cannot newly save unpublished bakery','22023');
});
// Phase 4: isolated allocations are fixtures, never written to the live service.
await as('authenticated',a,async()=>{
 await db.query('SELECT public.set_business_publication($1,9,true)',[businessA]);
 await db.query("SELECT public.save_availability($1,0,'Asia/Karachi',2,2)",[businessA]);
 await denied(()=>db.query("SELECT public.save_availability($1,0,'UTC',0,1)",[businessA]),'availability stale revision rejected','40001');
 await denied(()=>db.query("SELECT public.save_availability($1,1,'Bad/Timezone',0,1)",[businessA]),'invalid timezone rejected','22023');
 await denied(()=>db.query("SELECT public.save_availability($1,1,'UTC',-1,1)",[businessA]),'negative lead rejected','22023');
});
const today=await scalar("SELECT (now() AT TIME ZONE 'Asia/Karachi')::date");
const day=await scalar("SELECT (now() AT TIME ZONE 'Asia/Karachi')::date+5");
await as('authenticated',a,async()=>{
 await denied(()=>db.query('SELECT public.set_blocked_date($1,1,$2::date-1,true)',[businessA,today]),'past date cannot be blocked','22023');
 await db.query('SELECT public.set_blocked_date($1,1,$2,true)',[businessA,day]);
 check((await scalar('SELECT public.bakery_availability($1,$2,1)',[codeA,day])).days[0].state==='blocked','blocked date persists');
 await db.query('SELECT public.set_blocked_date($1,2,$2,false)',[businessA,day]);
});
await as('authenticated',b,async()=>{
 await denied(()=>db.query("SELECT public.save_availability($1,3,'UTC',0,1)",[businessA]),'other baker settings denied','42501');
 await denied(()=>db.query('SELECT public.set_blocked_date($1,3,$2,true)',[businessA,day]),'other baker blocking denied','42501');
});
check(await scalar('SELECT revision FROM public.availability_settings WHERE business_id=$1',[businessA])===3,'denied mutations leave target unchanged');
for (const status of ['pending','confirmed','baking','ready','delivered','declined','withdrawn','cancelled']) {
 await db.query('INSERT INTO public.capacity_allocations VALUES($1,gen_random_uuid(),$2,$3)',[businessA,day,status]);
}
check(await scalar('SELECT public.capacity_used($1,$2)',[businessA,day])===4,'only confirmed baking ready delivered consume capacity');
await as('anon',null,async()=>{
 const result=await scalar('SELECT public.bakery_availability($1,$2,1)',[codeA,day]);
 check(result.days[0].state==='full' && !('daily_capacity' in result) && !('order_id' in result),'public full state excludes private occupancy');
 await denied(()=>db.query('SELECT * FROM public.capacity_allocations'),'allocation identities private','42501');
 await denied(()=>db.query('SELECT public.bakery_availability($1,$2,63)',[codeA,day]),'calendar range bounded','22023');
});
await as('authenticated',a,()=>denied(()=>db.query('SELECT public.set_blocked_date($1,3,$2,true)',[businessA,day]),'block cannot cancel existing bookings','23514'));
await db.query("UPDATE public.capacity_allocations SET status='cancelled' WHERE business_id=$1",[businessA]);
check(await scalar('SELECT public.capacity_used($1,$2)',[businessA,day])===0,'cancellation releases capacity');
for (const [date,today,lead,expected] of [['2027-01-01','2026-12-31',1,'available'],['2027-01-01','2026-12-31',2,'lead-time-restricted'],['2026-12-30','2026-12-31',0,'past'],['2028-02-29','2028-02-28',1,'available']]) {
 check(await scalar('SELECT public.availability_state($1,$2,$3,2,0,false)',[date,today,lead])===expected,`date boundary ${date} ${expected}`);
}
check(await scalar("SELECT (('2026-12-31 20:00:00+00'::timestamptz AT TIME ZONE 'Asia/Karachi')::date)::text")==='2027-01-01','business timezone crosses year independently of device');
await as('authenticated',c,async()=>{
 await db.query('SELECT public.record_bakery_open($1)',[businessA]);
 await db.query('SELECT public.record_bakery_open($1)',[businessA]);
 check(await scalar('SELECT count(*)::int FROM public.recent_businesses')===1,'recent open deduplicates');
 check((await db.query('SELECT * FROM public.recent_bakeries()')).rows[0].profile.name==='A bakery','recent public projection');
});
await as('authenticated',b,async()=>{
 check(await scalar('SELECT count(*)::int FROM public.recent_businesses')===0,'recent history belongs to user');
 await denied(()=>db.query('INSERT INTO public.recent_businesses(user_id,business_id) VALUES($1,$2)',[c,businessB]),'recent cross-account writes denied','42501');
});
for(let i=1;i<=21;i++) {
 const uid=`70000000-0000-4000-8000-${String(i).padStart(12,'0')}`;
 await db.query('INSERT INTO auth.users(id,email_confirmed_at) VALUES($1,now())',[uid]);
 await as('authenticated',uid,()=>db.query("SELECT public.complete_identity('baker','Recent fixture','','Recent fixture')"));
 const bid=await scalar('UPDATE public.businesses SET onboarding_complete=true WHERE owner_id=$1 RETURNING id',[uid]);
 await as('authenticated',c,()=>db.query('SELECT public.record_bakery_open($1)',[bid]));
}
await as('authenticated',c,()=>checkAsyncRecent());
async function checkAsyncRecent() {check(await scalar('SELECT count(*)::int FROM public.recent_businesses')===20,'recent history stays bounded at 20');}
await as('authenticated',a,()=>db.query('SELECT public.set_business_publication($1,10,false)',[businessA]));
await as('anon',null,()=>scalar('SELECT public.bakery_availability($1)',[codeA]).then(r=>check(r===null,'unpublished availability hidden by direct code')));
await as('authenticated',a,()=>db.query('SELECT public.set_business_publication($1,11,true)',[businessA]));
let draft, reviewed, order;
const requestInput={product_id:product,variant_id:variant,option_ids:[finish,extra],quantity:1,service_date:day instanceof Date ? day.toISOString().slice(0,10) : String(day).slice(0,10),
 fulfilment:'delivery',zone_id:zone,address:'Fixture delivery address',contact_name:'Fixture customer',phone:'03000000000',cake_message:'Happy day',instructions:'Fixture instructions',attachments:[]};
await as('authenticated',c,async()=>{
 draft=await scalar('SELECT to_jsonb(public.open_request_draft($1))',[businessA]);
 check((await scalar('SELECT to_jsonb(public.open_request_draft($1))',[businessA])).id===draft.id,'one open draft per account and bakery');
 draft=await scalar('SELECT to_jsonb(public.save_request_draft($1,0,$2))',[draft.id,requestInput]);
 await denied(()=>db.query('SELECT public.save_request_draft($1,0,$2)',[draft.id,requestInput]),'stale draft edit rejected','40001');
 reviewed=await scalar('SELECT to_jsonb(public.review_request($1,1))',[draft.id]);
 check(reviewed.review.estimate.total_paisa===410000,'request review uses authoritative PKR 4100 estimate');
});
await as('authenticated',b,async()=>{
 check((await db.query('SELECT * FROM public.request_drafts WHERE id=$1',[draft.id])).rows.length===0,'unrelated draft private');
 await denied(()=>db.query('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token]),'other account cannot submit draft','42501');
});
const refPath=`${c}/${draft.id}/80000000-0000-4000-8000-000000000001.png`;
await as('authenticated',c,async()=>{
 await db.query('SELECT public.register_request_upload($1,$2)',[draft.id,refPath]);
 await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('order-references',$1)",[refPath]);
 draft=await scalar('SELECT to_jsonb(public.save_request_draft($1,1,$2))',[draft.id,{...requestInput,attachments:[refPath]}]);
 reviewed=await scalar('SELECT to_jsonb(public.review_request($1,2))',[draft.id]);
});
await as('authenticated',a,async()=>{
 check((await db.query('SELECT name FROM storage.objects WHERE name=$1',[refPath])).rows.length===0,'baker cannot read unsubmitted reference image');
});
// Changed catalog must force a fresh review, even when customer's input is unchanged.
await as('authenticated',a,()=>db.query('SELECT public.set_blocked_date($1,3,$2,true)',[businessA,day]));
await as('authenticated',c,()=>denied(()=>db.query('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token]),'newly blocked date rejected at submission','23514'));
check(await scalar('SELECT count(*)::int FROM public.order_requests')===0,'unavailable date creates no order');
await as('authenticated',a,()=>db.query('SELECT public.set_blocked_date($1,4,$2,false)',[businessA,day]));
await db.query('UPDATE public.businesses SET revision=revision+1 WHERE id=$1',[businessA]);
await as('authenticated',c,async()=>{
 await denied(()=>db.query('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token]),'changed catalog review rejected','40001');
 check(await scalar('SELECT count(*)::int FROM public.order_requests')===0,'failed submission writes no request');
 reviewed=await scalar('SELECT to_jsonb(public.review_request($1,2))',[draft.id]);
});
await db.exec("CREATE FUNCTION public.test_event_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'isolated test failure'; END $$; CREATE TRIGGER test_event_failure BEFORE INSERT ON public.request_events FOR EACH ROW EXECUTE FUNCTION public.test_event_failure();");
await as('authenticated',c,async()=>{
 await denied(()=>db.query('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token]),'late event failure rolls back submission','P0001');
 check(await scalar('SELECT count(*)::int FROM public.order_requests')===0 && await scalar('SELECT count(*)::int FROM public.request_quotes')===0 && await scalar('SELECT submitted_order_id FROM public.request_drafts WHERE id=$1',[draft.id])===null,'late failure leaves no partial request or quote');
});
await db.exec('DROP TRIGGER test_event_failure ON public.request_events; DROP FUNCTION public.test_event_failure();');
await as('authenticated',c,async()=>{
 order=await scalar('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token]);
 check(await scalar('SELECT public.submit_request($1,$2)',[draft.id,reviewed.review_token])===order,'submission retry returns same order');
 check(await scalar('SELECT count(*)::int FROM public.order_requests')===1,'duplicate submission creates one request');
 await denied(()=>db.query('SELECT public.submit_request($1,gen_random_uuid())',[draft.id]),'same idempotency key different token rejected','40001');
 await denied(()=>db.query('SELECT public.save_request_draft($1,2,$2)',[draft.id,requestInput]),'submitted content cannot be overwritten','23514');
 check(await scalar('SELECT count(*)::int FROM public.request_quotes')===1 && await scalar('SELECT count(*)::int FROM public.request_events')===1,'initial quote and event persisted atomically');
 check((await db.query('DELETE FROM storage.objects WHERE name=$1 RETURNING id',[refPath])).rows.length===0,'cleanup cannot delete submitted reference');
});
check(await scalar('SELECT public.capacity_used($1,$2)',[businessA,day])===0,'pending request consumes no capacity');
await as('authenticated',a,async()=>{
 check((await db.query('SELECT * FROM public.order_requests WHERE id=$1',[order])).rows.length===1,'correct baker reads request');
 check((await db.query('SELECT name FROM storage.objects WHERE name=$1',[refPath])).rows.length===1,'correct baker reads submitted private reference');
 await denied(()=>db.query("UPDATE public.order_requests SET status='confirmed' WHERE id=$1",[order]),'phase 6 actions unavailable','42501');
});
await as('authenticated',b,async()=>{
 check((await db.query('SELECT * FROM public.order_requests WHERE id=$1',[order])).rows.length===0,'other baker cannot read order');
 check((await db.query('SELECT * FROM public.request_quotes WHERE order_id=$1',[order])).rows.length===0,'other baker cannot read quote');
 check((await db.query('SELECT name FROM storage.objects WHERE name=$1',[refPath])).rows.length===0,'other baker cannot read reference');
 await denied(()=>db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('order-references',$1)",[`${c}/${draft.id}/80000000-0000-4000-8000-000000000002.png`]),'unrelated image upload denied','42501');
});
await db.query("UPDATE public.products SET name='Changed future catalog',active=false WHERE id=$1",[product]);
check((await scalar('SELECT snapshot FROM public.order_requests WHERE id=$1',[order])).product_name===products[0].name,'historical product snapshot remains unchanged');
await as('authenticated',c,async()=>{
 const next=await scalar('SELECT to_jsonb(public.open_request_draft($1))',[businessA]);
 await db.query('SELECT public.save_request_draft($1,0,$2)',[next.id,requestInput]);
 await denied(()=>db.query('SELECT public.review_request($1,1)',[next.id]),'inactive product cannot review new request','22023');
});
await db.query('UPDATE public.products SET active=true WHERE id=$1',[product]);
await as('authenticated',c,async()=>{
 const next=await scalar('SELECT to_jsonb(public.open_request_draft($1))',[businessA]);
 await db.query('SELECT public.save_request_draft($1,1,$2)',[next.id,{...requestInput,attachments:[refPath]}]);
 await denied(()=>db.query('SELECT public.review_request($1,2)',[next.id]),'reference from another draft cannot be attached','42501');
 await db.query('SELECT public.save_request_draft($1,2,$2)',[next.id,{...requestInput,quantity:0}]);
 await denied(()=>db.query('SELECT public.review_request($1,3)',[next.id]),'request minimum quantity revalidated','22023');
 await db.query('SELECT public.save_request_draft($1,3,$2)',[next.id,{...requestInput,service_date:'2026-02-30'}]);
 await denied(()=>db.query('SELECT public.review_request($1,4)',[next.id]),'request impossible date rejected','22008');
 for(let i=1;i<=3;i++) await db.query('SELECT public.register_request_upload($1,$2)',[next.id,`${c}/${next.id}/90000000-0000-4000-8000-00000000000${i}.png`]);
 await denied(()=>db.query('SELECT public.register_request_upload($1,$2)',[next.id,`${c}/${next.id}/90000000-0000-4000-8000-000000000004.png`]),'fourth active upload registration denied','22023');
 const abandoned=`${c}/${next.id}/90000000-0000-4000-8000-000000000001.png`;
 await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES('order-references',$1)",[abandoned]);
 await db.query('SELECT public.retire_request_upload($1)',[abandoned]);
 check((await db.query('DELETE FROM storage.objects WHERE name=$1 RETURNING id',[abandoned])).rows.length===1,'abandoned unsubmitted image can be cleaned');
});
const confirmOp='a0000000-0000-4000-8000-000000000001';
const transitionOp='a0000000-0000-4000-8000-000000000002';
const due=await scalar("SELECT ($1::date + time '12:00') AT TIME ZONE 'Asia/Karachi'",[day]);
await as('authenticated',a,()=>denied(()=>db.query("SELECT public.confirm_order_local($1,1,1,'12:00',$2)",[order,confirmOp]),'confirmation without customer agreement rejected','40001'));
check(await scalar('SELECT status FROM public.order_requests WHERE id=$1',[order])==='pending','rejected confirmation leaves order pending');
await as('authenticated',c,()=>db.query("SELECT public.record_order_agreement($1,1,'Customer agreed',NULL)",[order]));
const revisedEstimate={subtotal_paisa:500000,delivery_paisa:0,total_paisa:500000,lines:[{label:'Revised quote',amount_paisa:500000}]};
await as('authenticated',a,async()=>{
 const revised=await scalar('SELECT to_jsonb(public.revise_order_quote($1,1,$2,$3))',[order,revisedEstimate,'Change requested']);
 check(revised.version===2,'baker creates a new immutable quote version');
 await denied(()=>db.query("SELECT public.confirm_order_local($1,3,2,'12:00',$2)",[order,confirmOp]),'new quote invalidates previous agreement','40001');
 await denied(()=>db.query('SELECT public.revise_order_quote($1,1,$2,$3)',[order,revisedEstimate,'Stale revision']),'stale quote revision rejected','40001');
});
await as('authenticated',c,async()=>{
 const rows=(await db.query('SELECT version,estimate FROM public.request_quotes WHERE order_id=$1 ORDER BY version',[order])).rows;
 check(rows.length===2 && rows[0].estimate.total_paisa===410000 && rows[1].estimate.total_paisa===500000,'quote history preserves both amounts');
 await denied(()=>db.query("SELECT public.record_order_agreement($1,1,'Stale quote',NULL)",[order]),'customer cannot agree to obsolete quote','40001');
 await db.query("SELECT public.record_order_agreement($1,2,'Customer agreed to revised quote',NULL)",[order]);
});
await as('authenticated',a,async()=>{
 const confirmed=await scalar("SELECT to_jsonb(public.confirm_order_local($1,4,2,'12:00',$2))",[order,confirmOp]);
 check(confirmed.status==='confirmed','agreed current quote confirms');
 check(await scalar("SELECT (due_at AT TIME ZONE 'Asia/Karachi')::time = time '12:00' FROM public.order_requests WHERE id=$1",[order]),'due time uses bakery timezone');
 const retry=await scalar('SELECT to_jsonb(public.confirm_order($1,4,2,$2,$3))',[order,due,confirmOp]);
 check(retry.id===order && retry.status==='confirmed','confirmation exact retry is idempotent');
 await denied(()=>db.query('SELECT public.confirm_order($1,4,1,$2,$3)',[order,due,confirmOp]),'confirmation operation ID cannot be reused with different input','40001');
 const baking=await scalar("SELECT to_jsonb(public.transition_order($1,5,'baking',$2))",[order,transitionOp]);
 check(baking.status==='baking','owner advances confirmed order');
 await denied(()=>db.query("SELECT public.transition_order($1,5,'decorating',$2)",[order,transitionOp]),'transition retry with changed action rejected','40001');
 await denied(()=>db.query("SELECT public.transition_order($1,6,'decorating',gen_random_uuid())",[order]),'new transitions into Decorating are rejected','23514');
 const ready=await scalar("SELECT to_jsonb(public.transition_order($1,6,'ready',gen_random_uuid()))",[order]);
 check(ready.status==='ready','baking advances directly to ready');
 const delivered=await scalar("SELECT to_jsonb(public.transition_order($1,7,'delivered',gen_random_uuid()))",[order]);
 check(delivered.status==='delivered','ready advances to delivered');
});
check(await scalar('SELECT public.capacity_used($1,$2)',[businessA,day])===1,'delivered order still consumes capacity');
await as('authenticated',b,()=>denied(()=>db.query("SELECT public.transition_order($1,5,'baking',$2)",[order,transitionOp]),'unrelated baker cannot retrieve order through operation replay','42501'));
check(await scalar('SELECT status FROM public.order_requests WHERE id=$1',[order])==='delivered','denied operation leaves order unchanged');
const manualOp='a0000000-0000-4000-8000-000000000003';
let manual;
await as('authenticated',a,async()=>{
 manual=await scalar("SELECT to_jsonb(public.add_manual_order($1,'Fixture','03000000000','{}',10000,$2,$3,false))",[businessA,day,manualOp]);
 check(manual.source==='manual' && manual.customer_id===null,'manual order has no customer identity');
 check((await scalar("SELECT to_jsonb(public.add_manual_order($1,'Fixture','03000000000','{}',10000,$2,$3,false))",[businessA,day,manualOp])).id===manual.id,'manual create retry returns original');
 await denied(()=>db.query("SELECT public.add_manual_order($1,'Changed','03000000000','{}',10000,$2,$3,false)",[businessA,day,manualOp]),'manual retry with changed input rejected','40001');
});
await as('authenticated',b,()=>denied(()=>db.query("SELECT public.add_manual_order($1,'Fixture','03000000000','{}',10000,$2,$3,false)",[businessB,day,manualOp]),'other baker cannot replay manual order operation','40001'));
// Isolated fixture representing an order that was already in the legacy state.
await db.query("UPDATE public.order_requests SET status='decorating' WHERE id=$1",[manual.id]);
await db.query("UPDATE public.capacity_allocations SET status='decorating' WHERE order_id=$1",[manual.id]);
await db.query("INSERT INTO public.order_events(order_id,kind,actor_id) VALUES($1,'legacy_decorating',$2)",[manual.id,a]);
check(await scalar('SELECT public.capacity_used($1,$2)',[businessA,day])===2,'legacy Decorating continues to consume capacity');
const legacyEvents=await scalar('SELECT count(*)::int FROM public.order_events WHERE order_id=$1',[manual.id]);
await as('authenticated',a,async()=>{
 const legacy=await scalar("SELECT to_jsonb(public.transition_order($1,1,'ready',gen_random_uuid()))",[manual.id]);
 check(legacy.status==='ready','legacy Decorating advances to Ready');
});
check(await scalar('SELECT count(*)::int FROM public.order_events WHERE order_id=$1',[manual.id])===legacyEvents+1,'legacy history is preserved and a new event is added');
const targetDay=await scalar('SELECT ($1::date+3)::text',[day]);
const blockedDay=await scalar('SELECT ($1::date+4)::text',[day]);
const rescheduleOp='a0000000-0000-4000-8000-000000000099';
const beforeSchedule=await scalar('SELECT jsonb_build_object(\'snapshot\',snapshot,\'due\',due_at,\'version\',version) FROM public.order_requests WHERE id=$1',[manual.id]);
await db.query('INSERT INTO public.blocked_dates(business_id,service_date) VALUES($1,$2)',[businessA,blockedDay]);
await as('authenticated',b,()=>denied(()=>db.query("SELECT public.reschedule_order_local($1,2,$2,'15:30',$3)",[manual.id,targetDay,rescheduleOp]),'other baker cannot reschedule','42501'));
await as('authenticated',a,async()=>{
 await denied(()=>db.query("SELECT public.reschedule_order_local($1,2,$2,'15:30',$3)",[manual.id,blockedDay,rescheduleOp]),'blocked reschedule rejected','23514');
 check(JSON.stringify(await scalar('SELECT jsonb_build_object(\'snapshot\',snapshot,\'due\',due_at,\'version\',version) FROM public.order_requests WHERE id=$1',[manual.id]))===JSON.stringify(beforeSchedule),'blocked reschedule leaves order unchanged');
 const moved=await scalar("SELECT to_jsonb(public.reschedule_order_local($1,2,$2,'15:30',$3))",[manual.id,targetDay,rescheduleOp]);
 check(moved.snapshot.service_date===targetDay,'reschedule changes service date');
 check(await scalar("SELECT (due_at AT TIME ZONE 'Asia/Karachi')=($2::date+time '15:30') FROM public.order_requests WHERE id=$1",[manual.id,targetDay]),'reschedule stores bakery-local due time');
 await db.query("SELECT public.reschedule_order_local($1,2,$2,'15:30',$3)",[manual.id,targetDay,rescheduleOp]);
 check(await scalar("SELECT count(*)::int FROM public.order_events WHERE order_id=$1 AND kind='rescheduled'",[manual.id])===1,'reschedule retry creates one event');
 await denied(()=>db.query("SELECT public.reschedule_order_local($1,2,$2,'16:30',$3)",[manual.id,targetDay,rescheduleOp]),'changed reschedule retry rejected','40001');
});
check(await scalar('SELECT service_date::text=$2 FROM public.capacity_allocations WHERE order_id=$1',[manual.id,targetDay]),'reschedule moves capacity allocation');
const scheduleEvent=await scalar("SELECT details FROM public.order_events WHERE order_id=$1 AND kind='rescheduled'",[manual.id]);
check(scheduleEvent.old_date===await scalar('SELECT $1::date::text',[day]) && scheduleEvent.new_date===targetDay && 'old_due_at' in scheduleEvent && scheduleEvent.new_due_at!=null,'reschedule history retains old and new schedule');
await db.query("UPDATE public.order_requests SET status='confirmed' WHERE id=$1",[order]);
await db.query("UPDATE public.capacity_allocations SET status='confirmed' WHERE order_id=$1",[order]);
const cancelVersion=await scalar('SELECT version FROM public.order_requests WHERE id=$1',[order]);
await db.query('UPDATE public.availability_settings SET daily_capacity=1 WHERE business_id=$1',[businessA]);
const fullBefore=await scalar("SELECT jsonb_build_object('snapshot',snapshot,'due',due_at,'version',version) FROM public.order_requests WHERE id=$1",[order]);
await as('authenticated',a,()=>denied(()=>db.query("SELECT public.reschedule_order_local($1,$2,$3,'15:30',gen_random_uuid())",[order,cancelVersion,targetDay]),'full destination rejected','23514'));
check(JSON.stringify(await scalar("SELECT jsonb_build_object('snapshot',snapshot,'due',due_at,'version',version) FROM public.order_requests WHERE id=$1",[order]))===JSON.stringify(fullBefore),'full destination preserves original order');
check(await scalar('SELECT service_date=$2::date FROM public.capacity_allocations WHERE order_id=$1',[order,day]),'full destination preserves original allocation');
const cancelOp='a0000000-0000-4000-8000-000000000091';
const approveOp='a0000000-0000-4000-8000-000000000092';
await as('authenticated',c,async()=>{
 await db.query("SELECT public.cancellation_command($1,$2,'request',$3)",[order,cancelVersion,cancelOp]);
 await db.query("SELECT public.cancellation_command($1,$2,'request',$3)",[order,cancelVersion,cancelOp]);
 await denied(()=>db.query("SELECT public.cancellation_command($1,$2,'request',gen_random_uuid())",[order,cancelVersion+1]),'open cancellation cannot be duplicated','23514');
});
await as('authenticated',b,()=>denied(()=>db.query("SELECT public.cancellation_command($1,$2,'approve',$3)",[order,cancelVersion+1,approveOp]),'unrelated baker cannot approve cancellation','42501'));
await as('authenticated',a,async()=>{
 await denied(()=>db.query("SELECT public.transition_order($1,$2,'baking',gen_random_uuid())",[order,cancelVersion+1]),'open cancellation blocks production transition','23514');
 await db.query("SELECT public.cancellation_command($1,$2,'approve',$3)",[order,cancelVersion+1,approveOp]);
 await db.query("SELECT public.cancellation_command($1,$2,'approve',$3)",[order,cancelVersion+1,approveOp]);
 await denied(()=>db.query("SELECT public.cancellation_command($1,$2,'reject',$3)",[order,cancelVersion+1,approveOp]),'changed cancellation retry rejected','40001');
});
check(await scalar("SELECT count(*)::int FROM public.order_events WHERE order_id=$1 AND kind='cancelled'",[order])===1,'cancellation retry creates one event');
check(await scalar("SELECT status FROM public.capacity_allocations WHERE order_id=$1",[order])==='cancelled','approved cancellation releases allocation');
const auditSql=await readFile(new URL('./audit_reschedule_consistency.sql',import.meta.url),'utf8');
const audit=(await db.query(auditSql)).rows[0];
check(Number(audit.allocated_orders)>=2 && Number(audit.allocation_date_mismatch)===0,'read-only rescheduling consistency audit runs on modeled data');
await as('authenticated',c,()=>denied(()=>db.query("SELECT public.request_account_deletion('DELETE')"),'unfinished account deletion unavailable','42501'));
console.log(`${passed} local PostgreSQL runtime checks passed. Supabase services remain unverified.`);
await db.close();
