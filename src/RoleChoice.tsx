import './role-choice.css';

type Role='manager'|'resident';
function People({highlight}:{highlight:Role}){
 return <svg className="role-people" viewBox="0 0 150 95" fill="none" aria-hidden="true" strokeLinecap="round" strokeLinejoin="round" strokeWidth="5">
  <path d="M18 79H7v-5c0-9 12-10 16-16v-7c-4-4-4-9-4-14 0-10 5-15 13-15 8 0 13 5 13 15 0 5 0 10-4 14v7" stroke={highlight==='resident'?'#8bae4f':'#b6b8b5'}/>
  <path d="M132 79h11v-5c0-9-12-10-16-16v-7c4-4 4-9 4-14 0-10-5-15-13-15-8 0-13 5-13 15 0 5 0 10 4 14v7" stroke={highlight==='resident'?'#8bae4f':'#b6b8b5'}/>
  <path d="M39 79v-7c0-10 17-14 23-20v-8c-4-4-5-11-5-17 0-13 7-20 18-20s18 7 18 20c0 6-1 13-5 17v8c6 6 23 10 23 20v7H39Z" stroke={highlight==='manager'?'#8bae4f':'#b6b8b5'}/>
 </svg>;
}
export default function RoleChoice({onChoose}:{onChoose:(role:Role)=>void}){
 return <main className="role-screen" dir="rtl"><div className="role-inner"><h1>مدیریت ساختمان آپارتمان‌یار</h1><div className="role-options" aria-label="انتخاب نقش"><button type="button" onClick={()=>onChoose('manager')}><People highlight="manager"/><span>مدیر ساختمان</span><small aria-hidden="true">•••</small></button><button type="button" onClick={()=>onChoose('resident')}><People highlight="resident"/><span>از اهالی ساختمان</span><small aria-hidden="true">•••</small></button></div><p>برای شروع لطفاً نقش خود را مشخص نمایید</p><small className="role-explanation">انتخاب نقش فقط مسیر ورود را تعیین می‌کند؛ دسترسی‌ها پس از ورود بررسی می‌شوند.</small></div></main>;
}
