// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {Session,SupabaseClient} from '@supabase/supabase-js';
import ResidentPortal from '../src/ResidentPortal';
afterEach(()=>cleanup());
const session={user:{id:'resident'}} as Session;
it('loads only selected unit data and displays real invoice details',async()=>{
 const unit={building_id:'b',building_name:'آفتاب',unit_id:'u',unit_number:'۱',kind:'tenant'};
 const invoice={id:'i',invoice_number:'INV-1',period_title:'خرداد',principal:100,discount:0,penalty:0,previous_debt:0,paid_amount:20,due_on:'2026-07-01',issued_on:'2026-06-01',status:'partially_paid'};
 const rpc=vi.fn(async(name:string)=>name==='my_resident_units'?{data:[unit],error:null}:name==='resident_invoices'?{data:[invoice],error:null}:{data:[{debt:80,credit:0,net_debt:80}],error:null});
 const rows=[{id:'p',amount:20,method:'cash',paid_at:'2026-06-02T00:00:00Z'}];
 const query={select:()=>query,eq:()=>query,order:()=>query,range:async()=>({data:rows,error:null})};
 const db={rpc,from:()=>query} as unknown as SupabaseClient;
 render(<ResidentPortal db={db} session={session} goBack={()=>{}}/>);
 await screen.findByText('مجموع بدهی');expect(rpc).toHaveBeenCalledWith('resident_invoices',{b:'b',u:'u'});expect(rpc).toHaveBeenCalledWith('unit_balance',{b:'b',u:'u'});
 fireEvent.click(screen.getAllByRole('button',{name:'صورتحساب‌ها'})[0]);fireEvent.click(screen.getByRole('button',{name:/خرداد/}));expect(screen.getByText('بدهی قبلی (اطلاع‌رسانی)')).toBeTruthy();expect(screen.getByText('شماره INV-1')).toBeTruthy();
});
it('does not show fabricated data when authorization lookup fails',async()=>{
 const db={rpc:vi.fn(async()=>({data:null,error:{message:'دسترسی ممنوع'}}))} as unknown as SupabaseClient;
 render(<ResidentPortal db={db} session={session} goBack={()=>{}}/>);await waitFor(()=>expect(screen.getByRole('alert').textContent).toContain('دسترسی ممنوع'));expect(screen.queryByText('مجموع بدهی')).toBeNull();
});
