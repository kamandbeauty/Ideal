import {useState} from 'react';
type Contact={name?:string[];tel?:string[]};
type ContactPicker={select:(properties:string[],options:{multiple:boolean})=>Promise<Contact[]>};
export default function ContactFields({kind,label}:{kind:'owner'|'tenant';label:string}){
 const [name,setName]=useState(''),[phone,setPhone]=useState(''),[error,setError]=useState('');
 const picker=(navigator as Navigator&{contacts?:ContactPicker}).contacts;
 async function choose(){if(!picker)return;setError('');try{const contacts=await picker.select(['name','tel'],{multiple:false});const first=contacts[0];if(first){setName(first.name?.[0]||'');setPhone(first.tel?.[0]||'')}}catch{setError('انتخاب مخاطب انجام نشد؛ می‌توانید دستی وارد کنید.')}}
 return <fieldset className="billing-item"><legend>اطلاعات {label} (اختیاری)</legend><label>نام {label}<input className="field" name={kind+'_name'} value={name} onChange={e=>setName(e.target.value)} maxLength={120}/></label><label>موبایل {label}<input className="field" name={kind+'_phone'} value={phone} onChange={e=>setPhone(e.target.value)} dir="ltr" maxLength={30}/></label>{picker&&<button type="button" className="outline" onClick={()=>void choose()}>انتخاب از مخاطبین</button>}{error&&<small>{error}</small>}</fieldset>
}
