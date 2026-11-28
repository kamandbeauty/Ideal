import JalaliDateField from './JalaliDateField';
import {useRef,useState} from 'react';
import type {FormEvent} from 'react';
import {Plus,Trash2} from 'lucide-react';
import {amountText,categories,methods,responsibilities,todayTehran} from './billingLabels';
import type {BillingUnit} from './billingLabels';
export type Item={title:string;category:string;note:string;responsibility:'owner'|'resident';method:string;amount:number;units:string[]|null};
type Draft=Omit<Item,'amount'|'units'>&{key:number;amount:string;all:boolean;units:string[]};
const blank=(key:number):Draft=>({key,title:'',category:'monthly',note:'',responsibility:'resident',method:'equal',amount:'',all:true,units:[]});
export function serializeItems(drafts:Draft[],units:BillingUnit[]):Item[]{
 return drafts.map(d=>{
  const selected=d.all?units:units.filter(u=>d.units.includes(u.id));
  if(!selected.length||(!d.all&&selected.length!==d.units.length))throw new Error('حداقل یک واحد معتبر برای هر ردیف انتخاب کنید.');
  const amount=d.method==='default'?selected.reduce((n,u)=>n+Number(d.responsibility==='owner'?u.default_owner_charge||0:u.default_resident_charge||0),0):Number(d.amount);
  if(!Number.isSafeInteger(amount)||amount<1||amount>1e12||!d.title.trim())throw new Error('عنوان و مبلغ معتبر برای تمام ردیف‌ها وارد کنید.');
  return {title:d.title.trim(),category:d.category,note:d.note.trim(),responsibility:d.responsibility,method:d.method,amount,units:d.all?null:[...d.units].sort()};
 });
}
export default function DetailedChargeForm({units,busy,onSave}:{units:BillingUnit[];busy:boolean;onSave:(v:{title:string;issued_on:string;due_on:string;items:Item[]})=>Promise<void>}){
 const [rows,setRows]=useState<Draft[]>([blank(1)]);const next=useRef(2);
 const [title,setTitle]=useState(''),[issued,setIssued]=useState(todayTehran),[due,setDue]=useState(todayTehran),[error,setError]=useState('');
 function update(key:number,values:Partial<Draft>){setRows(prev=>prev.map(r=>r.key===key?{...r,...values}:r))}
 async function save(e:FormEvent){e.preventDefault();setError('');try{const items=serializeItems(rows,units);if(!title.trim()||!issued||!due||due<issued||items.reduce((n,r)=>n+r.amount,0)>1e12)throw new Error('عنوان، بازه تاریخ یا مجموع مبلغ معتبر نیست.');await onSave({title:title.trim(),issued_on:issued,due_on:due,items})}catch(e){setError(e instanceof Error?e.message:'ثبت اطلاعات ممکن نیست.')}} 
 return <form className="panel finance-form detailed-charge" onSubmit={save}><h2>تعریف شارژ تفصیلی</h2><p className="finance-hint">هزینه‌های قابل تقسیم را در یک دوره جمع کنید. صدور صورتحساب از پیش‌نمایش انجام می‌شود. این فرم پرداخت واقعی از صندوق ثبت نمی‌کند.</p><label>عنوان دوره<input value={title} onChange={e=>setTitle(e.target.value)} required maxLength={120} placeholder="مثلاً شارژ آذر"/></label><div className="form-grid"><JalaliDateField label="تاریخ اعلام" value={issued} onChange={setIssued} required/><JalaliDateField label="مهلت پرداخت" value={due} onChange={setDue} min={issued} required/></div>
 {rows.map((r,i)=><fieldset className="billing-item" key={r.key}><legend>ردیف هزینه {new Intl.NumberFormat('fa-IR').format(i+1)}</legend><div className="form-grid"><label>موضوع هزینه<input value={r.title} onChange={e=>update(r.key,{title:e.target.value})} required maxLength={120}/></label><label>دسته‌بندی<select value={r.category} onChange={e=>update(r.key,{category:e.target.value})}>{Object.entries(categories).map(([k,v])=><option value={k} key={k}>{v}</option>)}</select></label><label>مسئول پرداخت<select value={r.responsibility} onChange={e=>update(r.key,{responsibility:e.target.value as Draft['responsibility']})}>{['resident','owner'].map(k=><option value={k} key={k}>{responsibilities[k]}</option>)}</select></label><label>نحوه تقسیم<select value={r.method} onChange={e=>update(r.key,{method:e.target.value})}>{Object.entries(methods).filter(([k])=>k!=='mixed').map(([k,v])=><option value={k} key={k}>{v}</option>)}</select></label></div>
 {r.method==='default'?<div className="finance-hint">مجموع شارژ پیش‌فرض واحدهای مشمول: {amountText((r.all?units:units.filter(u=>r.units.includes(u.id))).reduce((n,u)=>n+Number(r.responsibility==='owner'?u.default_owner_charge||0:u.default_resident_charge||0),0))}</div>:<label>مبلغ کل هزینه (تومان)<input type="number" min="1" max="1000000000000" step="1" value={r.amount} onChange={e=>update(r.key,{amount:e.target.value})} required/></label>}
 <label>شرح (اختیاری)<textarea value={r.note} maxLength={1000} onChange={e=>update(r.key,{note:e.target.value})}/></label><label>برای چه واحدهایی؟<select value={r.all?'all':'selected'} onChange={e=>update(r.key,{all:e.target.value==='all'})}><option value="all">همه واحدها</option><option value="selected">واحدهای منتخب</option></select></label>{!r.all&&<div className="billing-unit-list">{units.map(u=><label key={u.id}><input type="checkbox" checked={r.units.includes(u.id)} onChange={e=>update(r.key,{units:e.target.checked?[...r.units,u.id]:r.units.filter(id=>id!==u.id)})}/> واحد {u.number}</label>)}</div>}
 {rows.length>1&&<button type="button" className="outline" onClick={()=>setRows(prev=>prev.filter(x=>x.key!==r.key))}><Trash2 size={16}/> حذف ردیف</button>}</fieldset>)}
 <p className="finance-hint">مسئول پرداخت در صورتحساب مشخص می‌شود؛ تسویه هر حساب مستقل انجام می‌شود.</p>
 {error&&<p role="alert" className="form-error">{error}</p>}
 <button type="button" className="outline" disabled={rows.length>=50||busy} onClick={()=>setRows(prev=>[...prev,blank(next.current++)])}><Plus size={17}/> افزودن ردیف هزینه</button><button className="primary" disabled={busy||!units.length}>ثبت پیش‌نویس تفصیلی</button></form>
}
