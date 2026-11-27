import {useState} from 'react';
type Entry={id:string;account_id:string;amount:number;transaction_type:string;description:string;occurred_at:string;document_no:string};
const incoming=(t:Entry)=>['receipt','adjustment_in'].includes(t.transaction_type);
const fmt=(v:number)=>new Intl.NumberFormat('fa-IR').format(v)+' تومان';
const day=(v:string)=>new Intl.DateTimeFormat('fa-IR-u-ca-persian',{dateStyle:'medium',timeZone:'Asia/Tehran'}).format(new Date(v));
const localDate=(v:string)=>new Intl.DateTimeFormat('en-CA',{year:'numeric',month:'2-digit',day:'2-digit',timeZone:'Asia/Tehran'}).format(new Date(v));
export default function CashLedger({transactions,accounts}:{transactions:Entry[];accounts:{id:string;name:string}[]}){
 const [account,setAccount]=useState(''),[from,setFrom]=useState(''),[to,setTo]=useState('');
 const rows=transactions.filter(t=>!account||t.account_id===account).sort((a,b)=>a.occurred_at.localeCompare(b.occurred_at)||a.document_no.localeCompare(b.document_no));
 let balance=0;const entries=rows.map(t=>{balance+=(incoming(t)?1:-1)*Number(t.amount);return {...t,balance}});
 const visible=entries.filter(t=>(!from||localDate(t.occurred_at)>=from)&&(!to||localDate(t.occurred_at)<=to));
 const opening=entries.filter(t=>from&&localDate(t.occurred_at)<from).slice(-1)[0]?.balance??0;
 const closing=visible.slice(-1)[0]?.balance??opening;
 return <section className="panel"><h2>گردش صندوق</h2><div className="form-grid"><label>صندوق<select value={account} onChange={e=>setAccount(e.target.value)}><option value="">همه صندوق‌ها</option>{accounts.map(a=><option key={a.id} value={a.id}>{a.name}</option>)}</select></label><label>از تاریخ (میلادی)<input type="date" value={from} onChange={e=>setFrom(e.target.value)}/></label><label>تا تاریخ (میلادی)<input type="date" value={to} onChange={e=>setTo(e.target.value)}/></label></div>{from&&to&&from>to?<p role="alert">بازه تاریخ معتبر نیست.</p>:<><div className="finance-stats">{[['مانده ابتدای بازه',opening],['مانده پایان بازه',closing],['مانده فعلی',balance]].map(([label,value])=><div className="stat" key={label}><p>{label}</p><strong>{fmt(Number(value))}</strong></div>)}</div>{!visible.length?<p className="empty-inline">گردشی در بازه انتخابی ثبت نشده است.</p>:visible.slice().reverse().map(t=><div className="finance-row" key={t.id}><div><b>{t.description||'سند مالی'}</b><p>{day(t.occurred_at)} · {incoming(t)?'ورودی':'خروجی'} · {accounts.find(a=>a.id===t.account_id)?.name}</p><small>مانده پس از سند: {fmt(t.balance)}</small></div><strong>{incoming(t)?'+':'−'} {fmt(Number(t.amount))}</strong></div>)}</>}</section>
}
