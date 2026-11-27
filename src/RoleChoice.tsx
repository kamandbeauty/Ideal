import {ArrowLeft,Building2,Home,ShieldCheck,UsersRound} from 'lucide-react';
import './role-choice.css';
type Role='manager'|'resident';

export default function RoleChoice({onChoose}:{onChoose:(role:Role)=>void}){
 return <main className="role-screen" dir="rtl">
  <div className="role-inner">
   <div className="role-brand"><span><Building2 size={34}/></span><b>آپارتمان‌یار</b><small>مدیریت ساده ساختمان</small></div>
   <h1>به آپارتمان‌یار خوش آمدید</h1>
   <p>برای شروع، نقش خود را در ساختمان انتخاب کنید.</p>
   <div className="role-options" aria-label="انتخاب نقش">
    <button type="button" aria-label="مدیر ساختمان" onClick={()=>onChoose('manager')}>
     <span className="role-tile-icon"><UsersRound size={31}/></span><span className="role-tile-title">مدیر ساختمان</span><small>مدیریت واحدها، شارژ و صندوق</small><ArrowLeft className="role-arrow" size={19}/>
    </button>
    <button type="button" aria-label="از اهالی ساختمان" onClick={()=>onChoose('resident')}>
     <span className="role-tile-icon"><Home size={31}/></span><span className="role-tile-title">از اهالی ساختمان</span><small>مشاهده صورتحساب و پرداخت‌ها</small><ArrowLeft className="role-arrow" size={19}/>
    </button>
   </div>
   <small className="role-explanation"><ShieldCheck size={18}/> انتخاب نقش فقط مسیر ورود را تعیین می‌کند؛ دسترسی‌ها پس از ورود بررسی می‌شوند.</small>
  </div>
 </main>;
}
