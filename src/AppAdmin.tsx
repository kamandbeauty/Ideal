import {useEffect,useState} from 'react';
import type {FormEvent} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {AppAnnouncementsAdmin} from './AppAnnouncements';
import {AppSubscriptionAdmin} from './Subscriptions';
import './app-admin.css';
type Stats={buildings:number;units:number;active_plans:number};
type Building={id:string;name:string;created_at:string;unit_count:number;manager_count:number};
type Values={title:string;duration_days:number;unit_price_toman:number;active:boolean};
type Audit={id:string;actor_id:string;old_values:Values|null;new_values:Values;created_at:string};
type Tab='overview'|'buildings'|'plans'|'history'|'announcements';
const fa=(n:number)=>Number(n).toLocaleString('fa-IR');
const day=(s:string)=>new Intl.DateTimeFormat('fa-IR-u-ca-persian',{dateStyle:'medium',timeStyle:'short'}).format(new Date(s));
const errorText=(e:unknown)=>e&&typeof e==='object'&&'message' in e?String(e.message):'دریافت اطلاعات ممکن نیست.';
export default function AppAdmin({db,onBack}:{db:SupabaseClient;onBack:()=>void}){
 const [tab,setTab]=useState<Tab>('overview');const [stats,setStats]=useState<Stats|null>(null);const [buildings,setBuildings]=useState<Building[]>([]);const [history,setHistory]=useState<Audit[]>([]);const [input,setInput]=useState('');const [search,setSearch]=useState('');const [offset,setOffset]=useState(0);const [loading,setLoading]=useState(false);const [error,setError]=useState('');const [retry,setRetry]=useState(0);
 useEffect(()=>{let alive=true;if(tab==='plans'||tab==='announcements')return;setLoading(true);setError('');setStats(null);setBuildings([]);setHistory([]);const request=tab==='overview'?db.rpc('app_admin_overview'):tab==='buildings'?db.rpc('app_admin_buildings',{search_text:search,page_offset:offset}):db.rpc('app_admin_plan_history',{page_offset:offset});
 Promise.resolve(request).then(({data,error})=>{if(error)throw error;if(!alive)return;if(tab==='overview')setStats(data?.[0]||null);else if(tab==='buildings')setBuildings(data||[]);else setHistory(data||[])}).catch(e=>{if(alive)setError(errorText(e))}).finally(()=>{if(alive)setLoading(false)});return()=>{alive=false}},[db,tab,offset,search,retry]);
 function switchTab(next:Tab){setTab(next);setOffset(0);setInput('');setSearch('');setError('')}
 function find(e:FormEvent){e.preventDefault();setOffset(0);setSearch(input.trim());setRetry(n=>n+1)}
 const rows=tab==='buildings'?buildings:history;
 return <main className="admin-app" dir="rtl"><header className="admin-header"><div><span>آپارتمان‌یار</span><h1>مدیریت اپلیکیشن</h1><p>مدیریت جدا از ساختمان‌ها</p></div><button className="outline" onClick={onBack}>بازگشت به برنامه</button></header><nav className="admin-tabs" aria-label="بخش‌های مدیریت اپلیکیشن">{([['overview','نمای کلی'],['buildings','ساختمان‌ها'],['plans','تعرفه اشتراک'],['history','تاریخچه تعرفه'],['announcements','اطلاعیه سراسری']] as const).map(([id,label])=><button key={id} className={tab===id?'selected':''} onClick={()=>switchTab(id)} aria-current={tab===id?'page':undefined}>{label}</button>)}</nav>
 {tab==='announcements'?<AppAnnouncementsAdmin db={db}/>:tab==='plans'?<AppSubscriptionAdmin db={db} onBack={()=>switchTab('overview')}/>:<><div className="finance-banner">این پنل اطلاعات عملیاتی محدود را نشان می‌دهد. پرداخت بازار و فعال‌سازی اشتراک هنوز پیاده‌سازی نشده‌اند.</div>{tab==='buildings'&&<form onSubmit={find} className="admin-search"><label>جستجوی نام ساختمان<input value={input} onChange={e=>setInput(e.target.value)} maxLength={100}/></label><button className="primary">جستجو</button></form>}{loading&&<p>در حال دریافت اطلاعات...</p>}{error&&<div role="alert" className="notice error">{error}<button className="outline" onClick={()=>setRetry(n=>n+1)}>تلاش مجدد</button></div>}
 {!loading&&!error&&tab==='overview'&&stats&&<div className="admin-stats"><div className="panel"><span>ساختمان‌های ثبت‌شده</span><strong>{fa(stats.buildings)}</strong></div><div className="panel"><span>واحدهای ثبت‌شده</span><strong>{fa(stats.units)}</strong></div><div className="panel"><span>تعرفه‌های فعال</span><strong>{fa(stats.active_plans)}</strong></div></div>}
 {!loading&&!error&&tab==='buildings'&&<section className="panel"><h2>ساختمان‌های ثبت‌شده</h2>{!buildings.length?<p>ساختمانی پیدا نشد.</p>:buildings.slice(0,20).map(b=><div className="finance-row" key={b.id}><div><b>{b.name}</b><p>واحد: {fa(b.unit_count)} · مدیر: {fa(b.manager_count)}</p><p>ثبت: {day(b.created_at)}</p></div></div>)}</section>}
 {!loading&&!error&&tab==='history'&&<section className="panel"><h2>تاریخچه تغییر تعرفه‌ها</h2>{!history.length?<p>تغییری ثبت نشده است.</p>:history.slice(0,20).map(h=><div className="finance-row admin-audit" key={h.id}><div><b>{h.old_values?'ویرایش تعرفه':'ایجاد تعرفه'} · {h.new_values.title}</b><p>{day(h.created_at)} · شناسه مدیر: <span dir="ltr">{h.actor_id}</span></p>{h.old_values&&<p>پیشین: {h.old_values.title}، {fa(h.old_values.unit_price_toman)} تومان، {fa(h.old_values.duration_days)} روز، {h.old_values.active?'فعال':'غیرفعال'}</p>}<p>جدید: {fa(h.new_values.unit_price_toman)} تومان، {fa(h.new_values.duration_days)} روز، {h.new_values.active?'فعال':'غیرفعال'}</p></div></div>)}</section>}
 {!loading&&!error&&(tab==='buildings'||tab==='history')&&<div className="admin-pagination"><button className="outline" disabled={offset===0} onClick={()=>setOffset(n=>Math.max(0,n-20))}>صفحه قبل</button><span>صفحه {fa(offset/20+1)}</span><button className="outline" disabled={rows.length<=20||offset>=100000} onClick={()=>setOffset(n=>n+20)}>صفحه بعد</button></div>}</>}
 </main>;
}
