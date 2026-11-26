// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {AppSubscriptionAdmin,SubscriptionQuotes} from '../src/Subscriptions';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
it('shows server calculated price, with purchase disabled',async()=>{
 const rpc=vi.fn(async()=>({data:[{plan_id:'p',title:'سالانه',duration_days:365,unit_count:2,unit_price_toman:7000,total_toman:14000}],error:null}));
 render(<SubscriptionQuotes db={{rpc} as unknown as SupabaseClient} buildingId="b"/>);await screen.findByText(/برآورد کل/);expect(screen.getByText(/۱۴٬۰۰۰/)).toBeTruthy();expect((screen.getByRole('button',{name:'خرید بازار در دست توسعه'}) as HTMLButtonElement).disabled).toBe(true);expect(rpc).toHaveBeenCalledWith('quote_subscription_plans',{b:'b'});expect(screen.getByText(/تمدید خودکار نیست/)).toBeTruthy();
});
it('saves per-period price only after confirmation',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='list_subscription_plans_admin'?[]:'p',error:null}));const confirm=vi.spyOn(window,'confirm').mockReturnValue(false);
 render(<AppSubscriptionAdmin db={{rpc} as unknown as SupabaseClient} onBack={()=>{}}/>);await waitFor(()=>expect((screen.getByRole('button',{name:'ذخیره تعرفه'}) as HTMLButtonElement).disabled).toBe(false));
 fireEvent.change(screen.getByLabelText('عنوان دوره'),{target:{value:'سالانه'}});fireEvent.change(screen.getByLabelText('مدت دوره (روز)'),{target:{value:'365'}});fireEvent.change(screen.getByLabelText('قیمت هر واحد برای این دوره (تومان)'),{target:{value:'7000'}});
 const form=screen.getByRole('button',{name:'ذخیره تعرفه'}).closest('form')!;fireEvent.submit(form);expect(rpc).not.toHaveBeenCalledWith('save_subscription_plan',expect.anything());confirm.mockReturnValue(true);fireEvent.submit(form);
 await waitFor(()=>expect(rpc).toHaveBeenCalledWith('save_subscription_plan',{plan_id:null,p_title:'سالانه',p_days:365,p_price:7000,p_active:true}));
});

it('does not display prices if server denies the building',async()=>{
 const rpc=vi.fn(async()=>({data:null,error:{message:'Not authorized'}}));
 render(<SubscriptionQuotes db={{rpc} as unknown as SupabaseClient} buildingId="other"/>);
 expect((await screen.findByRole('alert')).textContent).toContain('Not authorized');expect(screen.queryByText(/برآورد کل/)).toBeNull();
});
