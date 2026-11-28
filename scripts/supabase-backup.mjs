import {closeSync,createReadStream,openSync} from 'node:fs';
import {mkdtemp, mkdir, readFile, readdir, rm, stat, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';

const buckets=['apartment-yar-receipts','apartment-yar-payment-documents'];
const required=(name)=>{const value=process.env[name];if(!value)throw new Error(`Missing required environment variable: ${name}`);return value};
const run=(command,args,options={})=>new Promise((resolve,reject)=>{const child=spawn(command,args,{stdio:['ignore','inherit','inherit'],...options});child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error(`${command} exited with code ${code}`)))});
function storageUrl(base,bucket,object=''){const suffix=object?'/'+object.split('/').map(encodeURIComponent).join('/') :'';return `${base.replace(/\/$/,'')}/storage/v1/object/${bucket}${suffix}`}
async function api(base,key,url,options={}){const response=await fetch(url,{...options,headers:{apikey:key,authorization:`Bearer ${key}`,...options.headers}});if(!response.ok)throw new Error(`Supabase Storage request failed (${response.status})`);return response}
async function listObjects(base,key,bucket,prefix=''){
 const entries=[];for(let offset=0;;offset+=1000){const response=await api(base,key,`${base.replace(/\/$/,'')}/storage/v1/object/list/${bucket}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({prefix,limit:1000,offset,sortBy:{column:'name',order:'asc'}})});const page=await response.json();entries.push(...page);if(page.length<1000)break}
 const files=[];
 for(const entry of entries){const name=prefix?`${prefix}/${entry.name}`:entry.name;if(entry.id===null)files.push(...await listObjects(base,key,bucket,name));else files.push(name)}
 return files;
}
async function downloadBuckets(root,base,key){
 for(const bucket of buckets){for(const object of await listObjects(base,key,bucket)){const response=await api(base,key,storageUrl(base,bucket,object));const target=path.join(root,'objects',bucket,...object.split('/'));await mkdir(path.dirname(target),{recursive:true});await writeFile(target,Buffer.from(await response.arrayBuffer()),{mode:0o600})}}
}
async function uploadBuckets(root,base,key){
 const objectRoot=path.join(root,'objects');
 for(const bucket of buckets){const folder=path.join(objectRoot,bucket);let entries=[];try{entries=await readdir(folder,{withFileTypes:true,recursive:true})}catch{continue}
  for(const entry of entries){if(!entry.isFile())continue;const object=entry.parentPath?path.relative(folder,path.join(entry.parentPath,entry.name)):entry.name;const body=await readFile(path.join(folder,object));await api(base,key,storageUrl(base,bucket,object),{method:'POST',headers:{'content-type':'application/octet-stream','x-upsert':'true'},body})}
 }
}
async function ensureRecoveryBuckets(base,key){
 const existing=await (await api(base,key,`${base.replace(/\/$/,'')}/storage/v1/bucket`)).json();
 for(const id of buckets){if(existing.some(bucket=>bucket.id===id))continue;await api(base,key,`${base.replace(/\/$/,'')}/storage/v1/bucket`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({id,name:id,public:false,file_size_limit:5242880,allowed_mime_types:['image/jpeg','image/png','image/webp']})})}
}
async function encryptedArchive(root,passphrase){
 const passFile=path.join(root,'.passphrase');await writeFile(passFile,passphrase,{mode:0o600});
 const archive=path.join(root,'backup.tar.gz'),encrypted=`${archive}.gpg`;
 await run('tar',['-czf',archive,'-C',root,'schema.sql','data.sql','auth-data.sql','objects']);
 await run('gpg',['--batch','--yes','--pinentry-mode','loopback','--passphrase-file',passFile,'--symmetric','--cipher-algo','AES256','--output',encrypted,archive]);
 await rm(passFile,{force:true});await rm(archive,{force:true});return encrypted;
}
async function unpack(encrypted,root,passphrase){
 const passFile=path.join(root,'.passphrase');await writeFile(passFile,passphrase,{mode:0o600});const archive=path.join(root,'restore.tar.gz');
 await run('gpg',['--batch','--yes','--pinentry-mode','loopback','--passphrase-file',passFile,'--decrypt','--output',archive,encrypted]);
 await run('tar',['-xzf',archive,'-C',root]);await rm(passFile,{force:true});await rm(archive,{force:true});
}
const [mode,...args]=process.argv.slice(2);
const temp=await mkdtemp(path.join(os.tmpdir(),'apartment-yar-backup-'));
try{
 if(mode==='backup'){
  const dbUrl=required('SUPABASE_DB_URL'),base=required('SUPABASE_URL'),key=required('SUPABASE_SERVICE_ROLE_KEY'),pass=required('BACKUP_PASSPHRASE');
  await mkdir(path.join(temp,'objects'),{recursive:true});
  await run('supabase',['db','dump',`--remote=${dbUrl}`,'--schema','public','--file',path.join(temp,'schema.sql')]);
  await run('supabase',['db','dump',`--remote=${dbUrl}`,'--schema','public','--data-only','--use-copy','--file',path.join(temp,'data.sql')]);
  await run('docker',['run','--rm','-v',`${temp}:/backup`,'postgres:17-alpine','pg_dump',`--dbname=${dbUrl}`,'--data-only','--no-owner','--no-acl','--column-inserts','--table=auth.users','--table=auth.identities','--file=/backup/auth-data.sql']);
  await downloadBuckets(temp,base,key);const encrypted=await encryptedArchive(temp,pass);const name=`${new Date().toISOString().replaceAll(':','-')}.tar.gz.gpg`;
  const encryptedInfo=await stat(encrypted);if(encryptedInfo.size>5*1024*1024*1024)throw new Error('Encrypted archive exceeds the 5 GB total backup limit.');
  const partPrefix=path.join(temp,'backup.part.');await run('split',['--bytes=40M','--numeric-suffixes=0','--suffix-length=4',encrypted,partPrefix]);
  const parts=(await readdir(temp)).filter(file=>file.startsWith('backup.part.')).sort();
  for(const part of parts){const partPath=path.join(temp,part),partInfo=await stat(partPath),object=`${name}.part${part.slice('backup.part.'.length)}`;await api(base,key,storageUrl(base,'apartment-yar-db-backups',object),{method:'POST',duplex:'half',headers:{'content-type':'application/octet-stream','content-length':String(partInfo.size),'x-upsert':'false'},body:createReadStream(partPath)})}
  const cutoff=Date.now()-30*24*60*60*1000;
  for(const old of await listObjects(base,key,'apartment-yar-db-backups')){const created=Date.parse(old.replace(/\.part\d+$/,'').replace(/\.tar\.gz\.gpg$/,''));if(Number.isFinite(created)&&created<cutoff)await api(base,key,storageUrl(base,'apartment-yar-db-backups',old),{method:'DELETE'})}
  console.log(`Encrypted database and storage backup uploaded in ${parts.length} parts: ${name}`);
 }else if(mode==='restore'){
  const [objectPath,confirmation]=args;if(confirmation!=='RESTORE_TO_RECOVERY_PROJECT')throw new Error('Restore requires the exact confirmation RESTORE_TO_RECOVERY_PROJECT.');
  if(!objectPath||objectPath.includes('..')||objectPath.startsWith('/'))throw new Error('Provide a valid backup object path.');
  const base=required('SUPABASE_URL'),key=required('SUPABASE_SERVICE_ROLE_KEY'),dbUrl=required('SUPABASE_RESTORE_DB_URL'),pass=required('BACKUP_PASSPHRASE');
  if(!process.env.SUPABASE_RESTORE_PROJECT_IS_EMPTY||process.env.SUPABASE_RESTORE_PROJECT_IS_EMPTY!=='true')throw new Error('Restore is allowed only when SUPABASE_RESTORE_PROJECT_IS_EMPTY=true for a separate recovery project.');
  const encrypted=path.join(temp,'backup.gpg');const objects=(await listObjects(base,key,'apartment-yar-db-backups')).filter(item=>item.startsWith(`${objectPath}.part`)).sort();
  if(!objects.length)throw new Error('No backup parts were found for the requested path.');
  for(let index=0;index<objects.length;index++){if(!objects[index].endsWith(`.part${String(index).padStart(4,'0')}`))throw new Error('Backup parts are incomplete or out of order.');const response=await api(base,key,storageUrl(base,'apartment-yar-db-backups',objects[index]));const bytes=Buffer.from(await response.arrayBuffer());await writeFile(`${encrypted}.part${String(index).padStart(4,'0')}`,bytes,{mode:0o600})}
  const archiveFd=openSync(encrypted,'w',0o600);try{await run('cat',[...objects.map((_,index)=>`${encrypted}.part${String(index).padStart(4,'0')}`)],{stdio:['ignore',archiveFd,'inherit']})}finally{closeSync(archiveFd)}
  await unpack(encrypted,temp,pass);
  await writeFile(path.join(temp,'restore-privileges.sql'),'ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;\nALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;\nALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;\n',{mode:0o600});
  await run('docker',['run','--rm','-v',`${temp}:/backup`,'postgres:17-alpine','psql',`--dbname=${dbUrl}`,'--no-psqlrc','--set','ON_ERROR_STOP=1','--file=/backup/restore-privileges.sql','--file=/backup/schema.sql','--file=/backup/auth-data.sql','--file=/backup/data.sql']);
  const restoreUrl=required('SUPABASE_RESTORE_URL'),restoreKey=required('SUPABASE_RESTORE_SERVICE_ROLE_KEY');
  await ensureRecoveryBuckets(restoreUrl,restoreKey);
  await writeFile(path.join(temp,'storage-policies.sql'),`drop policy if exists apartment_receipt_upload on storage.objects;\ndrop policy if exists apartment_receipt_download on storage.objects;\ndrop policy if exists payment_documents_upload on storage.objects;\ndrop policy if exists payment_documents_download on storage.objects;\ncreate policy apartment_receipt_upload on storage.objects for insert to authenticated with check (bucket_id='apartment-yar-receipts' and exists(select 1 from public.payment_receipts r where r.object_path=name and r.status='uploading' and r.submitted_by=auth.uid() and public.is_unit_resident(r.building_id,r.unit_id)));\ncreate policy apartment_receipt_download on storage.objects for select to authenticated using (bucket_id='apartment-yar-receipts' and exists(select 1 from public.payment_receipts r where r.object_path=name and ((r.submitted_by=auth.uid() and public.is_unit_resident(r.building_id,r.unit_id)) or (r.status<>'uploading' and public.has_building_role(r.building_id,array['manager']::public.building_role[])))));\ncreate policy payment_documents_upload on storage.objects for insert to authenticated with check (bucket_id='apartment-yar-payment-documents' and exists(select 1 from public.payment_documents d where d.object_path=name and d.status='uploading' and public.has_building_role(d.building_id,array['manager']::public.building_role[])));\ncreate policy payment_documents_download on storage.objects for select to authenticated using (bucket_id='apartment-yar-payment-documents' and exists(select 1 from public.payment_documents d where d.object_path=name and d.status='ready' and public.has_building_role(d.building_id,array['manager']::public.building_role[])));\n`,{mode:0o600});
  await run('docker',['run','--rm','-v',`${temp}:/backup`,'postgres:17-alpine','psql',`--dbname=${dbUrl}`,'--no-psqlrc','--set','ON_ERROR_STOP=1','--file=/backup/storage-policies.sql']);
  await uploadBuckets(temp,restoreUrl,restoreKey);
  console.log('Database and private receipt/document files restored to the configured recovery project.');
 }else throw new Error('Choose backup or restore.');
}finally{await rm(temp,{recursive:true,force:true})}
