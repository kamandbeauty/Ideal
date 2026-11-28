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
 const invoice={id:'i',invoice_number:'INV-1',period_title:'خرداد',principal:100,discount:0,penalty:0,previous_debt:0,paid_amount:20,due_on:'2026-07-01',issued_on:'2026-06-01',status:'partially_paid',responsibility:'resident'};
 const rpc=vi.fn(async(name:string)=>name==='my_resident_units'?{data:[unit],error:null}:name==='resident_invoices'?{data:[invoice],error:null}:{data:[{debt:80,credit:0,net_debt:80}],error:null});
 const rows=[{id:'p',amount:20,method:'cash',paid_at:'2026-06-02T00:00:00Z'}];
 const query={select:()=>query,eq:()=>query,order:()=>query,range:async()=>({data:rows,error:null})};
 const db={rpc,from:()=>query} as unknown as SupabaseClient;
 render(<ResidentPortal db={db} session={session} goBack={()=>{}}/>);
 await screen.findByText('مجموع بدهی');expect(rpc).toHaveBeenCalledWith('resident_invoices',{b:'b',u:'u'});expect(rpc).toHaveBeenCalledWith('unit_balance',{b:'b',u:'u'});
 fireEvent.click(screen.getAllByRole('button',{name:'صورتحساب‌ها'})[0]);fireEvent.click(screen.getByRole('button',{name:/خرداد/}));expect(screen.getByText('بدهی قبلی (اطلاع‌رسانی)')).toBeTruthy();expect(screen.getByText(/شماره INV-1/)).toBeTruthy();
});
it('does not show fabricated data when authorization lookup fails',async()=>{
 const db={rpc:vi.fn(async()=>({data:null,error:{message:'دسترسی ممنوع'}}))} as unknown as SupabaseClient;
 render(<ResidentPortal db={db} session={session} goBack={()=>{}}/>);await waitFor(()=>expect(screen.getByRole('alert').textContent).toContain('دسترسی ممنوع'));expect(screen.queryByText('مجموع بدهی')).toBeNull();
});
it('opens only the unit selected by a valid account-bound link and removes its token from the address',async()=>{
 window.history.replaceState({},'', '/resident#link='+ 'a'.repeat(64));
 const units=[{building_id:'b',building_name:'اول',unit_id:'u1',unit_number:'۱',kind:'tenant'},{building_id:'b',building_name:'دوم',unit_id:'u2',unit_number:'۲',kind:'tenant'}];
 const rpc=vi.fn(async(name:string)=>name==='my_resident_units'?{data:units,error:null}:name==='resolve_resident_link'?{data:[{building_id:'b',unit_id:'u2'}],error:null}:name==='resident_invoices'?{data:[],error:null}:{data:[{debt:0,credit:0,net_debt:0}],error:null});
 const query={select:()=>query,eq:()=>query,order:()=>query,range:async()=>({data:[],error:null})};
 render(<ResidentPortal db={{rpc,from:()=>query} as unknown as SupabaseClient} session={session} goBack={()=>{}}/>);
 await screen.findByText('مجموع بدهی');expect(rpc).toHaveBeenCalledWith('resolve_resident_link',{token:'a'.repeat(64)});expect(rpc).toHaveBeenCalledWith('resident_invoices',{b:'b',u:'u2'});expect(window.location.hash).toBe('');
});
it('rejects invalid links without loading financial information',async()=>{
 window.history.replaceState({},'', '/resident#link=invalid');
 const rpc=vi.fn(async(name:string)=>name==='my_resident_units'?{data:[{building_id:'b',unit_id:'u'}],error:null}:{data:null,error:{message:'invalid'}});
 render(<ResidentPortal db={{rpc} as unknown as SupabaseClient} session={session} goBack={()=>{}}/>);
 await screen.findByRole('alert');expect(rpc).not.toHaveBeenCalledWith('resident_invoices',expect.anything());window.history.replaceState({},'', '/');
});
