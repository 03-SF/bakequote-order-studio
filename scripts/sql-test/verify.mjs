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
console.log(`${passed} local PostgreSQL runtime checks passed. Supabase services remain unverified.`);
await db.close();
