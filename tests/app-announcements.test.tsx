// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {AppAnnouncementsAdmin,AppNotices} from '../src/AppAnnouncements';
afterEach(()=>{cleanup();vi.restoreAllMocks()});
const item={id:'a',title:'خبر مهم',body:'متن سراسری',published_at:'2026-01-01T12:00:00Z',archived_at:null};
it('shows active app notices only when requested',async()=>{
 const rpc=vi.fn(async()=>({data:[item],error:null}));render(<AppNotices db={{rpc} as unknown as SupabaseClient}/>);expect(rpc).not.toHaveBeenCalled();fireEvent.click(screen.getByRole('button',{name:'اطلاعیه‌های اپلیکیشن'}));expect(await screen.findByText('متن سراسری')).toBeTruthy();expect(rpc).toHaveBeenCalledWith('current_app_announcements');
});
it('requires confirmation to publish and archive',async()=>{
 const rpc=vi.fn(async(name:string)=>({data:name==='app_admin_announcements'?[item]:null,error:null}));const confirm=vi.spyOn(window,'confirm').mockReturnValue(false);
 render(<AppAnnouncementsAdmin db={{rpc} as unknown as SupabaseClient}/>);await screen.findByText('متن سراسری');fireEvent.change(screen.getByLabelText('عنوان اطلاعیه'),{target:{value:'اطلاعیه جدید'}});fireEvent.change(screen.getByLabelText('متن اطلاعیه'),{target:{value:'متن جدید'}});
 const form=screen.getByRole('button',{name:'انتشار برای همه کاربران'}).closest('form')!;fireEvent.submit(form);expect(rpc).not.toHaveBeenCalledWith('publish_app_announcement',expect.anything());fireEvent.click(screen.getByRole('button',{name:'بایگانی اطلاعیه خبر مهم'}));expect(rpc).not.toHaveBeenCalledWith('archive_app_announcement',expect.anything());
 confirm.mockReturnValue(true);fireEvent.submit(form);await waitFor(()=>expect(rpc).toHaveBeenCalledWith('publish_app_announcement',{p_title:'اطلاعیه جدید',p_body:'متن جدید'}));await screen.findByText('اطلاعیه منتشر شد.');await waitFor(()=>expect((screen.getByRole('button',{name:'بایگانی اطلاعیه خبر مهم'}) as HTMLButtonElement).disabled).toBe(false));fireEvent.click(screen.getByRole('button',{name:'بایگانی اطلاعیه خبر مهم'}));await waitFor(()=>expect(rpc).toHaveBeenCalledWith('archive_app_announcement',{p_id:'a'}));
});
it('shows a failure without pretending announcements were received',async()=>{
 const rpc=vi.fn(async()=>({data:null,error:{message:'دسترسی ممنوع'}}));render(<AppNotices db={{rpc} as unknown as SupabaseClient}/>);fireEvent.click(screen.getByRole('button',{name:'اطلاعیه‌های اپلیکیشن'}));expect((await screen.findByRole('alert')).textContent).toContain('دسترسی ممنوع');expect(screen.queryByText('اطلاعیه‌ای وجود ندارد.')).toBeNull();
});
