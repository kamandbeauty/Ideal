// @vitest-environment jsdom
import {afterEach,it,expect,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,within} from '@testing-library/react';
import FinanceSummary from '../src/FinanceSummary';
import {AppNotices} from '../src/AppAnnouncements';
import type {SupabaseClient} from '@supabase/supabase-js';
afterEach(cleanup);
it('renders finance values and works with the selected home-screen shortcuts',()=>{
 const navigate=vi.fn();
 render(<FinanceSummary transactions={[{id:'a',amount:420,transaction_type:'expense',category:'water'},{id:'b',amount:580,transaction_type:'expense',category:'cleaning'}]} cash={24000} debts={{one:400,two:0,three:300}} latest="آذر ۱۴۰۵" accountCount={2} canManage onNavigate={navigate}/>);
 expect(screen.getByText('۲ صندوق')).toBeTruthy();
 expect(within(screen.getByRole('list',{name:'ریز توزیع هزینه‌ها'})).getByText('۴۲٪')).toBeTruthy();
 fireEvent.click(screen.getByRole('button',{name:/مانده کل صندوق‌ها/}));expect(navigate).toHaveBeenLastCalledWith('ledger');
 fireEvent.click(screen.getByRole('button',{name:'ثبت هزینه'}));expect(navigate).toHaveBeenLastCalledWith('expenses');
 fireEvent.click(screen.getByRole('button',{name:'دریافت از اهالی'}));expect(navigate).toHaveBeenLastCalledWith('payments');
 fireEvent.click(screen.getByRole('button',{name:'اعلام شارژ'}));expect(navigate).toHaveBeenLastCalledWith('periods');
 fireEvent.click(screen.getByRole('button',{name:/آخرین شارژ: آذر/}));expect(navigate).toHaveBeenLastCalledWith('invoices');
});
it('keeps write shortcuts hidden for non-manager users and shows real empty state',()=>{
 render(<FinanceSummary transactions={[]} cash={0} debts={{}} canManage={false} onNavigate={()=>{}}/>);
 expect(screen.queryByRole('button',{name:'ثبت هزینه'})).toBeNull();
 expect(screen.getByText('هزینه‌ای ثبت نشده است.')).toBeTruthy();
 expect(screen.getByRole('button',{name:/صورتحساب‌های ساختمان/})).toBeTruthy();
});
it('offers accessible notification button and keyboard dismissal in the header',async()=>{
 const rpc=vi.fn(async()=>({data:[],error:null}));render(<AppNotices compact db={{rpc} as unknown as SupabaseClient}/>);
 const trigger=screen.getByRole('button',{name:'اطلاعیه‌های اپلیکیشن'});expect(trigger.getAttribute('aria-expanded')).toBe('false');
 fireEvent.click(trigger);expect(await screen.findByText('اطلاعیه‌ای وجود ندارد.')).toBeTruthy();expect(trigger.getAttribute('aria-expanded')).toBe('true');
 fireEvent.keyDown(window,{key:'Escape'});expect(trigger.getAttribute('aria-expanded')).toBe('false');expect(screen.queryByText('اطلاعیه‌ای وجود ندارد.')).toBeNull();
});
