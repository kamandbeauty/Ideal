// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import Receipts from '../src/Receipts';
import userEvent from '@testing-library/user-event';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
it('uploads a receipt and submits for review without recording a payment',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='create_receipt_upload'?[{receipt_id:'r',object_path:'b/r'}]:null,error:null}));
 const upload=vi.fn(async()=>({error:null}));const query={select:()=>query,eq:()=>query,order:()=>query,range:async()=>({data:[],error:null})};
 const db={rpc,from:()=>query,storage:{from:()=>({upload})}} as unknown as SupabaseClient;vi.spyOn(window,'confirm').mockReturnValue(true);
 render(<Receipts db={db} buildingId="b" unitId="u" manager={false}/>);await screen.findByText('اعلام واریزی ثبت نشده است.');fireEvent.change(screen.getByLabelText('مبلغ (تومان)'),{target:{value:'100'}});fireEvent.change(screen.getByLabelText('شماره پیگیری (اختیاری)'),{target:{value:'123'}});fireEvent.change(screen.getByLabelText('متن اعلام واریزی'),{target:{value:'واریز شارژ'}});await userEvent.upload(screen.getByLabelText(/تصویر رسید/),new File(['png'],'proof.png',{type:'image/png'}));fireEvent.submit(screen.getByRole('button',{name:'ارسال برای بررسی'}).closest('form')!);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('submit_receipt',{rid:'r'}));expect(upload).toHaveBeenCalledWith('b/r',expect.any(File),{contentType:'image/png',upsert:false});expect(rpc).not.toHaveBeenCalledWith('record_manual_payment',expect.anything());
});
it('requires explicit confirmation before posting an identified receipt to the selected account',async()=>{
 const receipt={id:'r',unit_id:'u',amount:100,reference:'123',note:'واریز',object_path:'b/r',status:'reviewed',manager_note:'',payment_id:null,created_at:'2026-01-01'};
 const rpc=vi.fn(async()=>({data:'payment',error:null}));
 const receiptQuery={select:()=>receiptQuery,eq:()=>receiptQuery,order:()=>receiptQuery,range:async()=>({data:[receipt],error:null})};
 const accountsQuery={select:()=>accountsQuery,eq:()=>accountsQuery,order:async()=>({data:[{id:'account',name:'بانک'}],error:null})};
 const db={rpc,from:(name:string)=>name==='accounts'?accountsQuery:receiptQuery} as unknown as SupabaseClient;
 const confirm=vi.spyOn(window,'confirm').mockReturnValue(false);
 render(<Receipts db={db} buildingId="b" manager units={[{id:'u',number:'۱'}]}/>);
 await screen.findByText('واریز');fireEvent.change(screen.getByLabelText('صندوق دریافت'),{target:{value:'account'}});
 const button=screen.getByRole('button',{name:'ثبت دریافت پس از تأیید واریز'});
 fireEvent.submit(button.closest('form')!);expect(confirm).toHaveBeenCalled();expect(rpc).not.toHaveBeenCalled();
 confirm.mockReturnValue(true);fireEvent.submit(button.closest('form')!);
 await waitFor(()=>expect(rpc).toHaveBeenCalledWith('post_receipt_payment',{b:'b',rid:'r',a:'account'}));
 expect(await screen.findByText('دریافت به رسید متصل و در حسابداری ثبت شد.')).toBeTruthy();
});
it('does not show a posting form for an already linked or rejected receipt',async()=>{
 const receipts=[{id:'r1',unit_id:'u',amount:100,note:'ثبت شده',status:'reviewed',payment_id:'p'}, {id:'r2',unit_id:'u',amount:200,note:'رد شده',status:'rejected',payment_id:null}];
 const rq={select:()=>rq,eq:()=>rq,order:()=>rq,range:async()=>({data:receipts,error:null})};const aq={select:()=>aq,eq:()=>aq,order:async()=>({data:[],error:null})};
 const db={from:(name:string)=>name==='accounts'?aq:rq} as unknown as SupabaseClient;
 render(<Receipts db={db} buildingId="b" manager/>);await screen.findByText('ثبت شده');expect(screen.queryByRole('button',{name:'ثبت دریافت پس از تأیید واریز'})).toBeNull();
});
