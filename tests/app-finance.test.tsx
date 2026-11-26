// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import AppFinance from '../src/AppFinance';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
const report={income_toman:'14000',expense_toman:'3000',net_toman:'11000',entries:2};
const entry={id:'i',kind:'income',title:'فروش',amount_toman:14000,entry_date:'2026-01-01',note:'دستی',created_by:'admin',voided_at:null,void_reason:null};
it('shows only server report and voids only with a reason and confirmation',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='app_finance_report'?[report]:name==='app_finance_list'?[entry]:null,error:null}));const confirm=vi.spyOn(window,'confirm').mockReturnValue(false);vi.spyOn(window,'prompt').mockReturnValue('خطای ثبت');
 render(<AppFinance db={{rpc} as unknown as SupabaseClient}/>);await screen.findByText('۱۴٬۰۰۰ تومان');expect(screen.getByText('۱۱٬۰۰۰ تومان')).toBeTruthy();fireEvent.click(screen.getByRole('button',{name:'ابطال سند فروش'}));expect(rpc).not.toHaveBeenCalledWith('void_app_finance',expect.anything());confirm.mockReturnValue(true);fireEvent.click(screen.getByRole('button',{name:'ابطال سند فروش'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('void_app_finance',{p_id:'i',p_reason:'خطای ثبت'}));
});
it('retries an uncertain manual write using the same request id',async()=>{
 let attempts=0;const rpc=vi.fn(async(name:string)=>name==='record_app_finance'?{data:null,error:++attempts===1?{message:'offline'}:null}:{data:name==='app_finance_report'?[report]:[],error:null});vi.spyOn(window,'confirm').mockReturnValue(true);vi.spyOn(crypto,'randomUUID').mockReturnValue('90000000-0000-4000-8000-000000000001');
 render(<AppFinance db={{rpc} as unknown as SupabaseClient}/>);await screen.findByText('۱۴٬۰۰۰ تومان');fireEvent.change(screen.getByLabelText('عنوان'),{target:{value:'درآمد'}});fireEvent.change(screen.getByLabelText('مبلغ (تومان)'),{target:{value:'100'}});fireEvent.submit(screen.getByRole('button',{name:'ثبت سند دستی'}).closest('form')!);await screen.findByRole('alert');fireEvent.click(screen.getByRole('button',{name:'ارسال مجدد همان درخواست'}));await waitFor(()=>expect(rpc.mock.calls.filter(x=>x[0]==='record_app_finance')).toHaveLength(2));const calls=rpc.mock.calls.filter(x=>x[0]==='record_app_finance');expect(calls[0][1]).toEqual(calls[1][1]);
});
it('does not fabricate totals when reporting is denied',async()=>{const rpc=vi.fn(async()=>({data:null,error:{message:'Not authorized'}}));render(<AppFinance db={{rpc} as unknown as SupabaseClient}/>);expect((await screen.findByRole('alert')).textContent).toContain('Not authorized');expect(screen.queryByText('درآمد دستی')).toBeNull()});
