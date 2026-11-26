import {useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';

export default function ResidentLink({db,residentId}:{db:SupabaseClient;residentId:string}){
 const [url,setUrl]=useState('');const [busy,setBusy]=useState(false);const [message,setMessage]=useState('');
 async function change(action:'issue'|'revoke'){
  if(!window.confirm(action==='issue'?'لینک جدید ساخته و لینک قبلی این شخص باطل شود؟':'تمام لینک‌های این شخص باطل شود؟'))return;
  setBusy(true);setMessage('');setUrl('');
  try{
   const {data,error}=await db.rpc(action==='issue'?'issue_resident_link':'revoke_resident_links',{resident_id:residentId});if(error)throw error;
   if(action==='issue')setUrl(`${window.location.origin}/resident#link=${data}`);else setMessage('لینک‌های این شخص باطل شدند.');
  }catch(e){setMessage(e&&typeof e==='object'&&'message' in e?String(e.message):'عملیات انجام نشد.')}finally{setBusy(false)}
 }
 return <span><button type="button" className="link" disabled={busy} onClick={()=>void change('issue')}>ساخت لینک اختصاصی</button>{' '}<button type="button" className="link" disabled={busy} onClick={()=>void change('revoke')}>ابطال لینک</button>{message&&<small role="status">{message}</small>}{url&&<span><small>لینک ۷ روز معتبر است و فقط با ورود حساب متصل کار می‌کند. فقط برای همان شخص بفرستید؛ اکنون کپی کنید، دوباره قابل مشاهده نیست.</small><input aria-label="لینک اختصاصی ساکن" dir="ltr" readOnly value={url} onFocus={e=>e.currentTarget.select()}/></span>}</span>;
}
