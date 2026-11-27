// @vitest-environment jsdom
import {afterEach,it,expect,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import DetailedChargeForm from '../src/DetailedChargeForm';
import InvoiceLines from '../src/InvoiceLines';
import {fromJalali,toJalali} from '../src/JalaliDateField';
import {expenseDistribution} from '../src/FinanceSummary';
import type {SupabaseClient} from '@supabase/supabase-js';
afterEach(cleanup);
it('round trips Persian calendar dates and validates leap days',()=>{
 expect(toJalali('2026-11-27')).toBe('۱۴۰۵/۰۹/۰۶');
 expect(fromJalali('۱۴۰۵/۹/۶')).toBe('2026-11-27');
 expect(fromJalali('١٤٠٥/٩/٦')).toBe('2026-11-27');
 expect(fromJalali('1402/12/30')).toBe('');
 expect(fromJalali('1399/12/30')).toBe('2021-03-20');
});
it('sends actual selected unit identifiers and default amounts in a detailed charge',async()=>{
 const save=vi.fn(async()=>{});
 render(<DetailedChargeForm onSave={save} busy={false} units={[{id:'u1',number:'۱',default_owner_charge:500},{id:'u2',number:'۲',default_owner_charge:600}]}/>);
 fireEvent.change(screen.getByLabelText('عنوان دوره'),{target:{value:'آذر'}});
 fireEvent.change(screen.getByLabelText('موضوع هزینه'),{target:{value:'شارژ مالک'}});
 fireEvent.change(screen.getByLabelText('مسئول پرداخت'),{target:{value:'owner'}});
 fireEvent.change(screen.getByLabelText('نحوه تقسیم'),{target:{value:'default'}});
 fireEvent.change(screen.getByLabelText('برای چه واحدهایی؟'),{target:{value:'selected'}});
 fireEvent.click(screen.getByLabelText('واحد ۲'));
 fireEvent.click(screen.getByRole('button',{name:'ثبت پیش‌نویس تفصیلی'}));
 await waitFor(()=>expect(save).toHaveBeenCalledWith(expect.objectContaining({title:'آذر',items:[expect.objectContaining({amount:600,responsibility:'owner',method:'default',units:['u2']})]})));
});
it('renders only server-returned line items and uses targeted invoice RPC',async()=>{
 const rpc=vi.fn(async()=>({data:[{title:'آب',category:'water',responsibility:'resident',method:'people',total:1000,amount:250,note:'توضیح'}],error:null}));
 render(<InvoiceLines db={{rpc} as unknown as SupabaseClient} buildingId="b" invoiceId="i"/>);
 await screen.findByText('آب',{exact:true});expect(rpc).toHaveBeenCalledWith('invoice_charge_lines',{b:'b',invoice:'i'});
 expect(screen.getByText('نفرات')).toBeTruthy();
});
it('excludes reversed expenses from category distribution',()=>{
 expect(expenseDistribution([{id:'one',amount:500,transaction_type:'expense',category:'gas'},{id:'two',amount:300,transaction_type:'expense',category:'water'},{id:'rev',amount:500,transaction_type:'adjustment_in',reverses_id:'one'}])).toEqual([expect.objectContaining({key:'water',value:300})]);
});
