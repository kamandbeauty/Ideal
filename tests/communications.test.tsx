// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import Communications from '../src/Communications';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
it('resident opens a private conversation and sends text via server RPC',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='open_resident_conversation'?'conversation':null,error:null}));
 const db={rpc,from:(table:string)=>{const r=table==='messages'?[{id:'m',body:'سلام',sender_id:'user',created_at:'2026-05-01T12:00:00Z'}]:[];const q={select:()=>q,eq:()=>q,order:()=>q,range:async()=>({data:r,error:null})};return q}} as unknown as SupabaseClient;
 render(<Communications db={db} buildingId="b" unitId="u" manager={false} userId="user"/>);await screen.findByText('اطلاعیه‌ای وجود ندارد.');fireEvent.click(screen.getByRole('button',{name:'گفتگو'}));fireEvent.change(screen.getByLabelText('متن پیام'),{target:{value:'سلام'}});fireEvent.click(screen.getByRole('button',{name:'ارسال پیام'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('send_conversation_message',{b:'b',c:'conversation',body:'سلام'}));expect(rpc).toHaveBeenCalledWith('open_resident_conversation',{b:'b',u:'u'});
});
