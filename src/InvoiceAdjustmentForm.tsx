import {useEffect,useRef,useState} from 'react';
import type {FormEvent} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {amountText} from './billingLabels';

type Invoice={id:string;principal:number;discount:number;penalty:number;paid_amount:number};
type Entry={id:string;before_discount:number;after_discount:number;before_penalty:number;after_penalty:number;reason:string;created_at:string};
const date=(s:string)=>new Intl.DateTimeFormat('fa-IR-u-ca-persian',{year:'numeric',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit'}).format(new Date(s));
const errorText=(e:unknown)=>e&&typeof e==='object'&&'message'in e?String(e.message):'ثبت اصلاح صورتحساب ناموفق بود.';

export default function InvoiceAdjustmentForm({db,buildingId,invoice,onSaved}:{db:SupabaseClient;buildingId:string;invoice:Invoice;onSaved:()=>void}){
 const [history,setHistory]=useState<Entry[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState(''),[success,setSuccess]=useState('');
 const request=useRef<{signature:string;key:string}|null>(null);
 useEffect(()=>{let live=true;db.from('invoice_adjustments').select('id,before_discount,after_discount,before_penalty,after_penalty,reason,created_at').eq('building_id',buildingId).eq('invoice_id',invoice.id).order('created_at',{ascending:false}).range(0,49).then(({data,error})=>{if(!live)return;if(error)setError(error.message);else setHistory((data||[]) as Entry[])});return()=>{live=false}},[db,buildingId,invoice.id]);
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();const form=e.currentTarget,f=new FormData(form),discount=Number(f.get('discount')),penalty=Number(f.get('penalty')),reason=String(f.get('reason')||'').trim();const total=invoice.principal-discount+penalty;
  if(!Number.isSafeInteger(discount)||discount<0||discount>invoice.principal||!Number.isSafeInteger(penalty)||penalty<0||total>1e12||total<invoice.paid_amount||!reason){setError('مبلغ تخفیف و جریمه را بررسی کنید؛ جمع نهایی نباید کمتر از پرداخت‌های ثبت‌شده باشد.');return}
  const args={b:buildingId,invoice_id:invoice.id,new_discount:discount,new_penalty:penalty,reason};const signature=JSON.stringify(args);if(request.current?.signature!==signature)request.current={signature,key:crypto.randomUUID()};
  if(!confirm('اصلاح تخفیف و جریمه با سابقهٔ حسابداری ثبت شود؟'))return;setBusy(true);setError('');setSuccess('');try{const {error}=await db.rpc('adjust_invoice',{...args,request_id:request.current.key});if(error)throw error;request.current=null;setSuccess('اصلاح صورتحساب ثبت شد.');form.reset();onSaved()}catch(e){setError(errorText(e))}finally{setBusy(false)}
 }
 return <section className="billing-item"><h3>تعدیل صورتحساب</h3><p>تخفیف و جریمه با مبلغ جدید ثبت می‌شوند و تغییر قبلی در سوابق می‌ماند.</p><form className="finance-form" onSubmit={submit}><div className="form-grid"><label>تخفیف (تومان)<input name="discount" type="number" min="0" max={invoice.principal} step="1" defaultValue={invoice.discount} required/></label><label>جریمه (تومان)<input name="penalty" type="number" min="0" max="1000000000000" step="1" defaultValue={invoice.penalty} required/></label></div><label>علت اصلاح<input name="reason" maxLength={500} required/></label><button className="primary" disabled={busy}>ثبت اصلاح صورتحساب</button></form>{error&&<p role="alert">{error}</p>}{success&&<p role="status">{success}</p>}{history.length>0&&<details><summary>سوابق تعدیل ({history.length})</summary>{history.map(x=><article className="finance-row" key={x.id}><div><b>{date(x.created_at)}</b><p>{x.reason}</p></div><small>تخفیف {amountText(x.before_discount)} ← {amountText(x.after_discount)} · جریمه {amountText(x.before_penalty)} ← {amountText(x.after_penalty)}</small></article>)}</details>}</section>;
}
