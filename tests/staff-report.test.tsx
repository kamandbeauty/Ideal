// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import Staff from '../src/Staff';
import UnitReport from '../src/UnitReport';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
it('assigns a staff role via server after confirmation',async()=>{const rpc=vi.fn(async(name:string)=>({data:name==='list_staff'?[]:'id',error:null}));const db={rpc} as unknown as SupabaseClient;vi.spyOn(window,'confirm').mockReturnValue(true);render(<Staff db={db} buildingId="b"/>);await screen.findByText('نقشی ثبت نشده است.');fireEvent.change(screen.getByLabelText('شماره موبایل'),{target:{value:'09121234567'}});fireEvent.click(screen.getByRole('button',{name:'ثبت دسترسی'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('assign_staff',{b:'b',phone:'09121234567',staff_role:'accountant'}));});
it('shows only net creditors when filter is selected',async()=>{const data=[{unit_id:'1',unit_number:'۱',issued:100,paid:0,debt:100,credit:0,net_debt:100},{unit_id:'2',unit_number:'۲',issued:0,paid:0,debt:0,credit:50,net_debt:-50}];const rpc=vi.fn(()=>({range:async()=>({data,error:null})}));const db={rpc} as unknown as SupabaseClient;render(<UnitReport db={db} buildingId="b" period=""/>);await screen.findByText('۱');fireEvent.change(screen.getByLabelText('نمایش'),{target:{value:'credit'}});expect(screen.queryByText('۱')).toBeNull();expect(screen.getByText('۲')).toBeTruthy();expect(rpc).toHaveBeenCalledWith('report_unit_balances',{b:'b',p:null});});
