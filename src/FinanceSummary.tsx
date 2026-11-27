import {ArrowLeft,Plus,Wallet,ReceiptText,UsersRound,CalendarDays,ChartPie} from 'lucide-react';
import {amountText,categories} from './billingLabels';

export type SummaryTx={id:string;amount:number|string;transaction_type:string;category?:string;reverses_id?:string|null};
const chartColors=['#7544C9','#AB8DE3','#E5AF6D','#5397C4','#C879A4','#429C99','#6668B8','#AA9DBE'];
const fa=(n:number)=>new Intl.NumberFormat('fa-IR').format(n);
export function expenseDistribution(txs:SummaryTx[]){
 const reversed=new Set(txs.filter(t=>t.transaction_type==='adjustment_in'&&t.reverses_id).map(t=>t.reverses_id));
 const totals:Record<string,number>={};
 for(const tx of txs){
  if(tx.transaction_type!=='expense'||reversed.has(tx.id))continue;
  const cat=tx.category&&categories[tx.category]?tx.category:'other';
  const amount=Number(tx.amount);
  if(!Number.isSafeInteger(amount)||amount<=0)throw new Error('مبلغ هزینه معتبر نیست.');
  totals[cat]=(totals[cat]||0)+amount;
  if(!Number.isSafeInteger(totals[cat]))throw new Error('مبلغ از محدوده نمایش خارج است.');
 }
 return Object.entries(totals).sort((a,b)=>b[1]-a[1]).map(([key,value],i)=>({key,label:categories[key],value,color:chartColors[i%chartColors.length]}));
}
type SummaryPage='ledger'|'payments'|'expenses'|'periods'|'reports'|'invoices';
type Props={
 transactions:SummaryTx[];cash:number;debts:Record<string,number>;
 latest?:string;latestDate?:string;accountCount?:number;canManage:boolean;
 onNavigate:(v:SummaryPage)=>void;
};

export default function FinanceSummary({transactions,cash,debts,latest,latestDate,accountCount,canManage,onNavigate}:Props){
 let parts:ReturnType<typeof expenseDistribution>=[],total=0,error=false;
 try{parts=expenseDistribution(transactions);total=parts.reduce((n,x)=>n+x.value,0);if(!Number.isSafeInteger(total))throw new Error()}catch{error=true}
 let angle=0;
 const gradient=parts.map(p=>{const start=angle;angle+=p.value/total*100;return p.color+' '+start+'% '+angle+'%'}).join(',');
 const overdue=Object.values(debts).filter(v=>v>0);
 return <div className="finance-summary">
  <div className="finance-summary-grid">
   <button type="button" className="summary-balance" onClick={()=>onNavigate('ledger')}>
    <div className="summary-balance-label"><span>مانده کل صندوق‌ها</span><span className="balance-icon"><Wallet size={22}/></span></div>
    <strong>{fa(cash)} <small>تومان</small></strong>
    <div className="summary-balance-footer"><span>گردش صندوق <ArrowLeft size={15}/></span>{accountCount!==undefined&&<small>{fa(accountCount)} صندوق</small>}</div>
   </button>
   <button type="button" className="summary-tile" onClick={()=>onNavigate('reports')}>
    <div className="summary-tile-label"><span>واحدهای بدهکار</span><span className="summary-tile-icon"><UsersRound size={18}/></span></div>
    <strong>{fa(overdue.length)} <small>واحد</small></strong>
    <small>{amountText(overdue.reduce((n,v)=>n+v,0))}</small>
   </button>
   <button type="button" className="summary-tile" onClick={()=>onNavigate('periods')}>
    <div className="summary-tile-label"><span>آخرین شارژ</span><span className="summary-tile-icon"><CalendarDays size={18}/></span></div>
    <strong>{latest||'—'}</strong><small>{latestDate||'هنوز شارژی صادر نشده است'}</small>
   </button>
  </div>
  {canManage&&<section className="quick-section">
   <div className="section-title compact-section-title"><h2>عملیات سریع</h2><button type="button" className="link" onClick={()=>onNavigate('periods')}>امور شارژ <ArrowLeft size={14}/></button></div>
   <div className="finance-quick">
    <button type="button" className="quick-action" onClick={()=>onNavigate('expenses')}><span><Plus size={24}/></span>ثبت هزینه</button>
    <button type="button" className="quick-action" onClick={()=>onNavigate('payments')}><span><Wallet size={23}/></span>دریافت از اهالی</button>
    <button type="button" className="quick-action" onClick={()=>onNavigate('periods')}><span><ReceiptText size={23}/></span>اعلام شارژ</button>
   </div>
  </section>}
  <section className="panel expense-panel">
   <div className="panel-head"><div><h2>توزیع هزینه‌ها</h2><p>همه دوره‌ها، بدون اسناد معکوس‌شده</p></div><button type="button" className="link" onClick={()=>onNavigate('reports')}>گزارش‌ها <ArrowLeft size={14}/></button></div>
   {error?<p role="alert">مبلغ هزینه‌ها قابل نمایش نیست.</p>:!parts.length?<div className="chart-empty"><span><ChartPie size={26}/></span><div><b>هزینه‌ای ثبت نشده است.</b><p>پس از ثبت هزینه‌ها، نمودار واقعی اینجا نمایش داده می‌شود.</p></div></div>:<div className="expense-chart">
    <div className="expense-donut" style={{background:'conic-gradient('+gradient+')'}} aria-hidden="true"><div><b>{fa(total)}</b><small>تومان هزینه خالص</small></div></div>
    <ul aria-label="ریز توزیع هزینه‌ها">{parts.map(p=><li key={p.key}><span className="chart-dot" style={{background:p.color}}/><span className="chart-category">{p.label}<small>{amountText(p.value)}</small></span><b>{new Intl.NumberFormat('fa-IR',{maximumFractionDigits:1}).format(p.value/total*100)}٪</b></li>)}</ul>
   </div>}
  </section>
  <button type="button" className="latest-invoice-link" onClick={()=>onNavigate('invoices')}><span className="latest-invoice-icon"><ReceiptText size={22}/></span><span><b>{latest?'آخرین شارژ: '+latest:'صورتحساب‌های ساختمان'}</b><small>{latestDate||'مشاهده صورتحساب‌های صادرشده'}</small></span><ArrowLeft className="latest-invoice-arrow" size={19}/></button>
 </div>
}
