import {ArrowLeft,Plus,Wallet,ReceiptText} from 'lucide-react';
import {amountText,categories} from './billingLabels';
export type SummaryTx={id:string;amount:number|string;transaction_type:string;category?:string;reverses_id?:string|null};
const colors=['#168b79','#56aac0','#e8a44a','#7a8bd0','#c76f98','#77a95c','#eb7c6b','#9ba9b6'];
export function expenseDistribution(txs:SummaryTx[]){
 const reversed=new Set(txs.filter(t=>t.transaction_type==='adjustment_in'&&t.reverses_id).map(t=>t.reverses_id));
 const totals:Record<string,number>={};
 for(const tx of txs){if(tx.transaction_type!=='expense'||reversed.has(tx.id))continue;const cat=tx.category&&categories[tx.category]?tx.category:'other';const amount=Number(tx.amount);if(!Number.isSafeInteger(amount)||amount<=0)throw new Error('مبلغ هزینه معتبر نیست.');totals[cat]=(totals[cat]||0)+amount;if(!Number.isSafeInteger(totals[cat]))throw new Error('مبلغ از محدوده نمایش خارج است.')}
 return Object.entries(totals).sort((a,b)=>b[1]-a[1]).map(([key,value],i)=>({key,label:categories[key],value,color:colors[i%colors.length]}));
}
export default function FinanceSummary({transactions,cash,debts,latest,latestDate,canManage,onNavigate}:{transactions:SummaryTx[];cash:number;debts:Record<string,number>;latest?:string;latestDate?:string;canManage:boolean;onNavigate:(v:'ledger'|'payments'|'expenses'|'periods'|'reports')=>void}){
 let parts:ReturnType<typeof expenseDistribution>=[],total=0,error=false;
 try{parts=expenseDistribution(transactions);total=parts.reduce((n,x)=>n+x.value,0);if(!Number.isSafeInteger(total))throw new Error()}catch{error=true}
 let angle=0;const gradient=parts.map(p=>{const start=angle;angle+=p.value/total*100;return p.color+' '+start+'% '+angle+'%'}).join(',');
 const overdue=Object.values(debts).filter(v=>v>0);
 return <div className="finance-summary"><div className="finance-summary-grid"><button className="summary-balance" onClick={()=>onNavigate('ledger')}><span>مانده صندوق‌ها <Wallet size={20}/></span><strong>{amountText(cash)}</strong><small>گردش صندوق <ArrowLeft size={15}/></small></button><button className="summary-tile" onClick={()=>onNavigate('reports')}><span>واحدهای بدهکار</span><strong>{new Intl.NumberFormat('fa-IR').format(overdue.length)} واحد</strong><small>{amountText(overdue.reduce((n,v)=>n+v,0))}</small></button><button className="summary-tile" onClick={()=>onNavigate('periods')}><span>آخرین شارژ صادرشده</span><strong>{latest||'—'}</strong><small>{latestDate||'هنوز شارژی صادر نشده است'}</small></button></div>
 {canManage&&<div className="finance-quick"><button className="outline" onClick={()=>onNavigate('expenses')}><Plus size={16}/> ثبت هزینه</button><button className="outline" onClick={()=>onNavigate('payments')}><Wallet size={16}/> دریافت از اهالی</button><button className="outline" onClick={()=>onNavigate('periods')}><ReceiptText size={16}/> اعلام شارژ</button></div>}
 <section className="panel"><div className="panel-head"><div><h2>توزیع هزینه‌ها</h2><p>هزینه‌های واقعی همه دوره‌ها، بدون اسناد معکوس‌شده</p></div></div>{error?<p role="alert">مبلغ هزینه‌ها قابل نمایش نیست.</p>:!parts.length?<p className="empty-inline">هزینه‌ای ثبت نشده است.</p>:<div className="expense-chart"><div className="expense-donut" style={{background:'conic-gradient('+gradient+')'}} aria-hidden="true"><div><b>{amountText(total)}</b><small>کل هزینه خالص</small></div></div><ul>{parts.map(p=><li key={p.key}><span className="chart-dot" style={{background:p.color}}/><span>{p.label}</span><b>{amountText(p.value)}</b><small>{new Intl.NumberFormat('fa-IR',{maximumFractionDigits:1}).format(p.value/total*100)}٪</small></li>)}</ul></div>}</section>
 </div>
}
