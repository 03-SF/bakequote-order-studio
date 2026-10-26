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
console.log(`${passed} local PostgreSQL runtime checks passed. Supabase services remain unverified.`);
await db.close();
