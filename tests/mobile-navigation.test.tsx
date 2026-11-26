// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen} from '@testing-library/react';
import MobileNavigation from '../src/MobileNavigation';
afterEach(cleanup);
it('keeps common pages visible and offers permitted extra pages in a closing menu',()=>{
 const onPage=vi.fn(),onResident=vi.fn();render(<MobileNavigation page="dashboard" canManage canFinance appAdmin onPage={onPage} onResident={onResident} onAdmin={()=>{}} onLogout={()=>{}}/>);
 expect(screen.getByRole('button',{name:'خانه'}).getAttribute('aria-current')).toBe('page');fireEvent.click(screen.getByRole('button',{name:'بیشتر'}));expect(screen.getByRole('button',{name:'بیشتر'}).getAttribute('aria-expanded')).toBe('true');fireEvent.click(screen.getByRole('button',{name:'رسیدها'}));expect(onPage).toHaveBeenCalledWith('receipts');expect(screen.queryByRole('button',{name:'رسیدها'})).toBeNull();fireEvent.click(screen.getByRole('button',{name:'بیشتر'}));fireEvent.click(screen.getByRole('button',{name:'پنل ساکن'}));expect(onResident).toHaveBeenCalledOnce();
});
it('does not offer restricted actions and closes on Escape',()=>{
 render(<MobileNavigation page="units" canManage={false} canFinance={false} appAdmin={false} onPage={()=>{}} onResident={()=>{}} onAdmin={()=>{}} onLogout={()=>{}}/>);expect(screen.queryByRole('button',{name:'مالی'})).toBeNull();fireEvent.click(screen.getByRole('button',{name:'بیشتر'}));expect(screen.queryByRole('button',{name:'مدیریت اپ'})).toBeNull();expect(screen.queryByRole('button',{name:'رسیدها'})).toBeNull();fireEvent.keyDown(window,{key:'Escape'});expect(screen.queryByRole('button',{name:'پنل ساکن'})).toBeNull();
});
