// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,within,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import ResidentFacilities from '../src/ResidentFacilities';
import Facilities from '../src/Facilities';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
function mockDb(){
 const rows:Record<string,unknown[]>={common_spaces:[{id:'s',name:'سالن',description:'',status:'active'}],reservation_rules:[{space_id:'s',allowed_days:[0,1,2,3,4,5,6],opens_at:'08:00',closes_at:'20:00',capacity:5,fee:0,max_active_per_unit:1,requires_approval:true}],maintenance_requests:[],space_reservations:[],maintenance_costs:[],expenses:[],assets:[],contractors:[],service_schedules:[],accounts:[{id:'a',name:'نقدی'}]};
 const rpc=vi.fn(async()=>({data:'ok',error:null}));
 const db={rpc,from:(table:string)=>{const q={select:()=>q,eq:()=>q,order:()=>q,range:async()=>({data:rows[table],error:null}),then:(done:(x:unknown)=>void)=>Promise.resolve({data:rows[table],error:null}).then(done),insert:async()=>({error:null}),upsert:async()=>({error:null})};return q}} as unknown as SupabaseClient;
 vi.spyOn(window,'confirm').mockReturnValue(true);return{db,rpc};
}
it('resident submits repair through the authenticated RPC',async()=>{const {db,rpc}=mockDb();render(<ResidentFacilities db={db} buildingId="b" unitId="u"/>);await screen.findByText('درخواست‌های تعمیرات واحد');const form=screen.getByRole('button',{name:'ثبت درخواست'}).closest('form')!;fireEvent.change(within(form).getByLabelText('عنوان'),{target:{value:'نشتی'}});fireEvent.change(within(form).getByLabelText('توضیحات'),{target:{value:'آب چکه می‌کند'}});fireEvent.submit(form);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('create_maintenance_request',expect.objectContaining({b:'b',u:'u',title:'نشتی',description:'آب چکه می‌کند'})))});
it('resident sends local slot to the server without relying on browser timezone',async()=>{const {db,rpc}=mockDb();render(<ResidentFacilities db={db} buildingId="b" unitId="u"/>);await screen.findByText('مشاعات و رزرو');const form=screen.getByRole('button',{name:'ثبت رزرو'}).closest('form')!;fireEvent.change(within(form).getByLabelText('تاریخ (میلادی)'),{target:{value:'2030-01-01'}});fireEvent.change(within(form).getByLabelText('ساعت شروع'),{target:{value:'10:00'}});fireEvent.change(within(form).getByLabelText('ساعت پایان'),{target:{value:'11:00'}});fireEvent.change(within(form).getByLabelText('تعداد نفرات'),{target:{value:'2'}});fireEvent.submit(form);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('reserve_space_local',expect.objectContaining({b:'b',u:'u',s:'s',local_date:'2030-01-01',start_time:'10:00',end_time:'11:00',guest_count:2})))});
it('manager can initiate a repair request',async()=>{const {db,rpc}=mockDb();render(<Facilities db={db} buildingId="b" canManage/>);await screen.findByText('درخواست‌های تعمیرات');const form=screen.getByRole('button',{name:'ثبت درخواست'}).closest('form')!;fireEvent.change(within(form).getByLabelText('عنوان'),{target:{value:'پمپ'}});fireEvent.change(within(form).getByLabelText('توضیحات'),{target:{value:'خاموش است'}});fireEvent.submit(form);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('create_maintenance_request',expect.objectContaining({b:'b',u:null,title:'پمپ'})))});
