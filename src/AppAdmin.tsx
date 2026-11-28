import AppFinance from './AppFinance';
import {useEffect,useState} from 'react';
import type {FormEvent} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {AppAnnouncementsAdmin} from './AppAnnouncements';
import './app-admin.css';

type Stats={buildings:number;units:number;active_plans:number;users:number;active_users_30d:number};
type Building={id:string;name:string;created_at:string;unit_count:number;manager_count:number};
type AppUser={id:string;full_name:string;phone_masked:string;created_at:string;last_sign_in_at:string|null;building_count:number};
type Backup={archive_name:string;part_count:number;total_bytes:number;last_part_at:string};
type Tab='overview'|'buildings'|'users'|'announcements'|'finance'|'backups';
const fa=(n:number|string)=>Number(n||0).toLocaleString('fa-IR');
const day=(s:string)=>new Intl.DateTimeFormat('fa-IR-u-ca-persian',{dateStyle:'medium',timeStyle:'short'}).format(new Date(s));
const size=(n:number)=>n<1024*1024?fa(Math.ceil(n/1024))+' کیلوبایت':Number(n/1024/1024).toFixed(1).replace('.', '٫')+' مگابایت';
const errorText=(e:unknown)=>e&&typeof e==='object'&&'message' in e?String(e.message):'دریافت اطلاعات ممکن نیست.';
const tabs:[Tab,string][]=[['overview','نمای کلی'],['buildings','ساختمان‌ها'],['users','کاربران'],['announcements','اطلاعیه سراسری'],['finance','مالی اپلیکیشن'],['backups','بکاپ و بازیابی']];

export default function AppAdmin({db,onBack}:{db:SupabaseClient;onBack:()=>void}){
 const [tab,setTab]=useState<Tab>('overview');
 const [stats,setStats]=useState<Stats|null>(null);
 const [buildings,setBuildings]=useState<Building[]>([]);
 const [users,setUsers]=useState<AppUser[]>([]);
 const [backups,setBackups]=useState<Backup[]>([]);
 const [input,setInput]=useState('');
 const [search,setSearch]=useState('');
 const [offset,setOffset]=useState(0);
 const [loading,setLoading]=useState(false);
 const [error,setError]=useState('');
 const [retry,setRetry]=useState(0);

 useEffect(()=>{
  let alive=true;
  if(tab==='announcements'||tab==='finance')return;
  setLoading(true);setError('');
  if(tab!=='overview')setStats(null);
  if(tab!=='buildings')setBuildings([]);
  if(tab!=='users')setUsers([]);
  if(tab!=='backups')setBackups([]);
  let request:ReturnType<SupabaseClient['rpc']>;
  if(tab==='overview')request=db.rpc('app_admin_overview');
  else if(tab==='buildings')request=db.rpc('app_admin_buildings',{search_text:search,page_offset:offset});
  else if(tab==='users')request=db.rpc('app_admin_users',{search_text:search,page_offset:offset});
  else request=db.rpc('app_admin_backup_inventory');
  Promise.resolve(request).then(({data,error})=>{
   if(error)throw error;if(!alive)return;
   if(tab==='overview')setStats(data?.[0]||null);
   else if(tab==='buildings')setBuildings(data||[]);
   else if(tab==='users')setUsers(data||[]);
   else setBackups(data||[]);
  }).catch(e=>{if(alive)setError(errorText(e))}).finally(()=>{if(alive)setLoading(false)});
  return()=>{alive=false};
 },[db,tab,offset,search,retry]);

 function switchTab(next:Tab){setTab(next);setOffset(0);setInput('');setSearch('');setError('')}
 function find(e:FormEvent){e.preventDefault();setOffset(0);setSearch(input.trim());setRetry(n=>n+1)}
 const hasNext=tab==='buildings'?buildings.length>20:users.length>20;
 return <main className="admin-app" dir="rtl">
  <header className="admin-header"><div><span>آپارتمان‌یار</span><h1>مدیریت اپلیکیشن</h1><p>مدیریت سرویس و ساختمان‌ها</p></div><button className="outline" onClick={onBack}>بازگشت به برنامه</button></header>
  <nav className="admin-tabs" aria-label="بخش‌های مدیریت اپلیکیشن">{tabs.map(([id,label])=><button key={id} className={tab===id?'selected':''} onClick={()=>switchTab(id)} aria-current={tab===id?'page':undefined}>{label}</button>)}</nav>
  {tab==='finance'?<AppFinance db={db}/>:tab==='announcements'?<AppAnnouncementsAdmin db={db}/>:<>
   <div className="finance-banner">دسترسی این پنل در پایگاه‌داده کنترل می‌شود. شماره کاربران در فهرست به‌صورت پوشیده نمایش داده می‌شود.</div>
   {(tab==='buildings'||tab==='users')&&<form onSubmit={find} className="admin-search"><label>{tab==='buildings'?'جستجوی نام ساختمان':'جستجوی نام یا شماره کاربر'}<input value={input} onChange={e=>setInput(e.target.value)} maxLength={100}/></label><button className="primary">جستجو</button></form>}
   {loading&&<p>در حال دریافت اطلاعات...</p>}
   {error&&<div role="alert" className="notice error">{error}<button className="outline" onClick={()=>setRetry(n=>n+1)}>تلاش مجدد</button></div>}
   {!loading&&!error&&tab==='overview'&&stats&&<>
    <div className="admin-stats">
     <div className="panel"><span>ساختمان‌های ثبت‌شده</span><strong>{fa(stats.buildings)}</strong></div>
     <div className="panel"><span>واحدهای ثبت‌شده</span><strong>{fa(stats.units)}</strong></div>
     <div className="panel"><span>کاربران ثبت‌نام‌شده</span><strong>{fa(stats.users)}</strong></div>
     <div className="panel"><span>کاربران فعال در ۳۰ روز</span><strong>{fa(stats.active_users_30d)}</strong></div>
     <div className="panel"><span>وضعیت این اپلیکیشن</span><strong>رایگان</strong><small className="admin-online">سرویس فعال</small></div>
    </div>
    <div className="admin-note panel"><b>ساختمان فعال</b><p>فعلاً همهٔ ساختمان‌های ثبت‌شده در فهرست فعال هستند؛ محصول هنوز وضعیت توقف یا بایگانی ساختمان ندارد.</p><button className="outline" onClick={()=>switchTab('buildings')}>دیدن فهرست ساختمان‌ها</button></div>
   </>}
   {!loading&&!error&&tab==='buildings'&&<><section className="panel"><h2>ساختمان‌های فعال</h2><p className="admin-subtitle">نمایش نام، تعداد واحد و مدیران؛ اطلاعات مالی و ساکنان در این فهرست افشا نمی‌شود.</p>{!buildings.length?<p>ساختمانی پیدا نشد.</p>:buildings.slice(0,20).map(b=><div className="finance-row" key={b.id}><div><b>{b.name}</b><p>واحد: {fa(b.unit_count)} · مدیر: {fa(b.manager_count)}</p><p>ثبت: {day(b.created_at)}</p></div><span className="admin-status">فعال</span></div>)}</section><Pager offset={offset} hasNext={hasNext} setOffset={setOffset}/></>}
   {!loading&&!error&&tab==='users'&&<><section className="panel"><h2>حساب‌های کاربری</h2><p className="admin-subtitle">شماره تماس پوشیده است. فهرست فقط برای مدیر اپ در پایگاه‌داده قابل دریافت است.</p>{!users.length?<p>کاربری پیدا نشد.</p>:users.slice(0,20).map(u=><div className="finance-row" key={u.id}><div><b>{u.full_name}</b><p>شماره: {u.phone_masked} · ساختمان: {fa(u.building_count)}</p><p>آخرین ورود: {u.last_sign_in_at?day(u.last_sign_in_at):'هنوز وارد نشده'}</p></div></div>)}</section><Pager offset={offset} hasNext={hasNext} setOffset={setOffset}/></>}
   {!loading&&!error&&tab==='backups'&&<><section className="panel"><div className="admin-backup-head"><div><h2>بکاپ‌های رمزگذاری‌شده</h2><p className="admin-subtitle">آرشیوهای دیتابیس و فایل‌ها از مخزن خصوصی Supabase خوانده می‌شوند.</p></div><a className="primary admin-action" href="https://github.com/kamandbeauty/Ideal/actions/workflows/supabase-backup.yml" target="_blank" rel="noreferrer">اجرای بکاپ / بازیابی در GitHub</a></div>{!backups.length?<div className="empty-inline"><p>هنوز فایلی در مخزن بکاپ ثبت نشده است.</p><p>برای اجرای دستی یا زمان‌بندی، Secrets گردش‌کار GitHub باید تنظیم شده باشند.</p></div>:backups.map(b=><div className="finance-row" key={b.archive_name}><div><b dir="ltr">{b.archive_name}</b><p>قطعه‌ها: {fa(b.part_count)} · حجم: {size(b.total_bytes)}</p><p>آخرین قطعه: {day(b.last_part_at)}</p></div></div>)}</section><div className="admin-note panel"><b>بازیابی</b><p>بازیابی فقط به پروژهٔ Supabase جدا و خالی اجرا می‌شود و به تأیید صریح در گردش‌کار نیاز دارد.</p></div></>}
  </>}
 </main>;
}
function Pager({offset,hasNext,setOffset}:{offset:number;hasNext:boolean;setOffset:(fn:(n:number)=>number)=>void}){
 return <div className="admin-pagination"><button className="outline" disabled={offset===0} onClick={()=>setOffset(n=>Math.max(0,n-20))}>صفحه قبل</button><span>صفحه {fa(offset/20+1)}</span><button className="outline" disabled={!hasNext||offset>=100000} onClick={()=>setOffset(n=>n+20)}>صفحه بعد</button></div>
}
