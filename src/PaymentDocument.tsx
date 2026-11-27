import {useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
const bucket='apartment-yar-payment-documents';
export async function attachPaymentImage(db:SupabaseClient,b:string,p:string,file:File){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5242880||file.size<=0)throw new Error('تصویر JPG، PNG یا WebP حداکثر ۵ مگابایت انتخاب کنید.');
 const {data,error}=await db.rpc('create_payment_document',{b,p,mime:file.type});if(error)throw error;
 const slot=data?.[0];if(!slot)throw new Error('جایگاه بارگذاری ایجاد نشد.');
 if(slot.status==='ready')throw new Error('برای این دریافت قبلاً تصویر ثبت شده است.');
 const upload=await db.storage.from(bucket).upload(slot.object_path,file,{contentType:file.type,upsert:false});
 // If upload succeeded before a lost response, confirming the already-present image
 // recovers the original upload without writing a second cash transaction.
 const result=await db.rpc('confirm_payment_document',{b,document_id:slot.document_id});
 if(result.error)throw upload.error||result.error;
}
export default function PaymentDocument({db,buildingId,paymentId}:{db:SupabaseClient;buildingId:string;paymentId:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(''),[link,setLink]=useState('');
 async function run(fn:()=>Promise<void>){setBusy(true);setMessage('');setLink('');try{await fn()}catch(e){setMessage(e instanceof Error?e.message:e&&typeof e==='object'&&'message' in e?String(e.message):'عملیات ناموفق بود.')}finally{setBusy(false)}}
 return <div className="payment-document"><label className="outline">پیوست تصویر<input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={e=>{const file=e.target.files?.[0];e.target.value='';if(file)void run(async()=>{await attachPaymentImage(db,buildingId,paymentId,file);setMessage('تصویر ثبت شد.')})}}/></label><button type="button" className="outline" disabled={busy} onClick={()=>void run(async()=>{const {data,error}=await db.from('payment_documents').select('object_path,status').eq('building_id',buildingId).eq('payment_id',paymentId).maybeSingle();if(error)throw error;if(!data||data.status!=='ready'){setMessage('تصویر آماده‌ای ثبت نشده است.');return}const signed=await db.storage.from(bucket).createSignedUrl(data.object_path,60);if(signed.error)throw signed.error;setLink(signed.data.signedUrl)})}>مشاهده پیوست</button>{link&&<a className="link" href={link} target="_blank" rel="noopener noreferrer">باز کردن تصویر (۶۰ ثانیه)</a>}{message&&<small role="status">{message}</small>}</div>
}
