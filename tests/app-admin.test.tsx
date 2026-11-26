// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import AppAdmin from '../src/AppAdmin';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
it('loads real overview and paginated searchable buildings',async()=>{
 const buildings=Array.from({length:21},(_,i)=>({id:String(i),name:'ساختمان '+i,unit_count:i,manager_count:1,created_at:'2026-01-01T12:00:00Z'}));
 const rpc=vi.fn(async(name:string,args?:Record<string,unknown>)=>({data:name==='app_admin_overview'?[{buildings:23,units:80,active_plans:1}]:name==='app_admin_buildings'?(args?.page_offset===20?[buildings[20]]:buildings):[],error:null}));
 render(<AppAdmin db={{rpc} as unknown as SupabaseClient} onBack={()=>{}}/>);await screen.findByText('۲۳');expect(screen.getByText('۸۰')).toBeTruthy();
 fireEvent.click(screen.getByRole('button',{name:'ساختمان‌ها'}));await screen.findByText('ساختمان 0');expect(screen.queryByText('ساختمان 20')).toBeNull();
 fireEvent.click(screen.getByRole('button',{name:'صفحه بعد'}));await screen.findByText('ساختمان 20');expect(rpc).toHaveBeenCalledWith('app_admin_buildings',{search_text:'',page_offset:20});
 fireEvent.change(screen.getByLabelText('جستجوی نام ساختمان'),{target:{value:' آفتاب '}});fireEvent.click(screen.getByRole('button',{name:'جستجو'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('app_admin_buildings',{search_text:'آفتاب',page_offset:0}));
});
it('shows server denial without inventing overview figures',async()=>{
 const rpc=vi.fn(async()=>({data:null,error:{message:'Not authorized'}}));render(<AppAdmin db={{rpc} as unknown as SupabaseClient} onBack={()=>{}}/>);
 expect((await screen.findByRole('alert')).textContent).toContain('Not authorized');expect(screen.queryByText('ساختمان‌های ثبت‌شده')).toBeNull();
});
it('displays subscription plan audit details',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='app_admin_plan_history'?[{id:'a',actor_id:'user-1',old_values:{title:'قدیم',unit_price_toman:7000,duration_days:90,active:true},new_values:{title:'سالانه',unit_price_toman:9000,duration_days:365,active:false},created_at:'2026-01-01T12:00:00Z'}]:[{buildings:0,units:0,active_plans:0}],error:null}));
 render(<AppAdmin db={{rpc} as unknown as SupabaseClient} onBack={()=>{}}/>);fireEvent.click(screen.getByRole('button',{name:'تاریخچه تعرفه'}));expect(await screen.findByText('ویرایش تعرفه · سالانه')).toBeTruthy();expect(screen.getByText(/پیشین: قدیم، ۷٬۰۰۰/)).toBeTruthy();expect(screen.getByText(/جدید: ۹٬۰۰۰/)).toBeTruthy();
});
