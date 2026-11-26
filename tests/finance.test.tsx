// @vitest-environment jsdom
import React from 'react';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {cleanup, fireEvent, render, screen, waitFor, within} from '@testing-library/react';
import Finance from '../src/Finance';
import type {SupabaseClient} from '@supabase/supabase-js';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
const building='building-a';
function setup(){
 const data:Record<string,unknown[]>={accounts:[{id:'a',name:'صندوق',kind:'cash'}],charge_periods:[{id:'period',title:'اردیبهشت',issued_on:'2026-05-01',due_on:'2026-05-30',status:'draft'}],invoices:[],financial_transactions:[]};
 const rpc=vi.fn(async(name:string)=>name==='preview_charge_period'?{data:[{unit_id:'unit',amount:100}],error:null}:{data:null,error:null});
 const db={from:(table:string)=>({select:()=>({eq:()=>({order:()=>({range:async()=>({data:data[table],error:null})})})})}),rpc} as unknown as SupabaseClient;
 vi.spyOn(window,'confirm').mockReturnValue(true);
 render(<Finance db={db} buildingId={building} units={[{id:'unit',number:'۱'}]} canManage/>);return {rpc};
}
describe('finance UI integration with mocked Supabase',()=>{
 it('previews and issues only after confirmation',async()=>{const {rpc}=setup();await screen.findByText('موجودی صندوق‌ها');fireEvent.click(screen.getByRole('button',{name:'مدیریت شارژ'}));fireEvent.click(screen.getByRole('button',{name:'پیش‌نمایش'}));await screen.findByText('پیش‌نمایش اردیبهشت');expect(rpc).toHaveBeenCalledWith('preview_charge_period',{p:'period'});fireEvent.click(screen.getByRole('button',{name:'تأیید و صدور صورتحساب'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('issue_charge_period',{p:'period'}));});
 it('sends a manual payment through the RPC with an idempotency key',async()=>{const {rpc}=setup();await screen.findByText('موجودی صندوق‌ها');fireEvent.click(screen.getByRole('button',{name:'دریافت دستی'}));const panel=screen.getByRole('button',{name:'ثبت دریافت'}).closest('form')!;fireEvent.change(within(panel).getByLabelText('واحد'),{target:{value:'unit'}});fireEvent.change(within(panel).getByLabelText('صندوق'),{target:{value:'a'}});fireEvent.change(within(panel).getByLabelText('مبلغ (تومان)'),{target:{value:'500'}});fireEvent.submit(panel);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('record_manual_payment',expect.objectContaining({b:building,u:'unit',a:'a',amount:500,method:'cash',request_id:expect.any(String)})));});
 it('does not record an expense when confirmation is declined',async()=>{const {rpc}=setup();await screen.findByText('موجودی صندوق‌ها');fireEvent.click(screen.getByRole('button',{name:'هزینه‌ها'}));const panel=screen.getByRole('button',{name:'ثبت هزینه'}).closest('form')!;fireEvent.change(within(panel).getByLabelText('عنوان هزینه'),{target:{value:'نظافت'}});fireEvent.change(within(panel).getByLabelText('صندوق'),{target:{value:'a'}});fireEvent.change(within(panel).getByLabelText('مبلغ (تومان)'),{target:{value:'300'}});vi.mocked(window.confirm).mockReturnValue(false);fireEvent.submit(panel);expect(rpc).not.toHaveBeenCalled();});
});
