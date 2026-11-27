import {useEffect,useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {amountText,categories,methods,responsibilities} from './billingLabels';
import type {ChargeLine} from './billingLabels';
export function LineItems({lines}:{lines:ChargeLine[]}){
 return <div className="invoice-lines">{lines.map((l,i)=><details className="billing-line" key={i}><summary><span><b>{l.title}</b><small>{categories[l.category]||l.category} · {responsibilities[l.responsibility]||l.responsibility}</small></span><strong>{amountText(l.amount)}</strong></summary><div className="billing-line-meta"><div><span>روش تقسیم</span><b>{methods[l.method]||l.method}</b></div><div><span>مبلغ کل هزینه</span><b>{amountText(l.total)}</b></div><div><span>سهم این واحد</span><b>{amountText(l.amount)}</b></div></div>{l.weights&&<p className="finance-hint">{Object.entries(l.weights).filter(([,v])=>Number(v)>0).map(([k,v])=>methods[k]+' '+new Intl.NumberFormat('fa-IR').format(v)+'٪').join(' · ')}</p>}{l.note&&<p>{l.note}</p>}</details>)}</div>
}
export default function InvoiceLines({db,buildingId,invoiceId}:{db:SupabaseClient;buildingId:string;invoiceId:string}){
 const [lines,setLines]=useState<ChargeLine[]|null>(null),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 useEffect(()=>{let alive=true;setLines(null);setError('');(async()=>{try{const {data,error}=await db.rpc('invoice_charge_lines',{b:buildingId,invoice:invoiceId});if(error)throw error;if(!Array.isArray(data)||data.some(x=>!Number.isSafeInteger(Number(x.amount))||!Number.isSafeInteger(Number(x.total))))throw new Error('جزئیات معتبر نیست.');if(alive)setLines(data)}catch(e){if(alive)setError(e instanceof Error?e.message:'جزئیات صورتحساب دریافت نشد.')}})();return()=>{alive=false}},[db,buildingId,invoiceId,retry]);
 return <section className="invoice-lines-section"><h3>ریز اقلام صورتحساب</h3>{error?<p role="alert">{error} <button className="outline" onClick={()=>setRetry(r=>r+1)}>تلاش مجدد</button></p>:lines===null?<p>در حال دریافت جزئیات...</p>:lines.length?<LineItems lines={lines}/>:<p>جزئیاتی ثبت نشده است.</p>}</section>
}
