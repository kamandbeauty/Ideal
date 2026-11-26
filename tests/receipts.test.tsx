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
