// @vitest-environment jsdom
import React from 'react';
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,fireEvent,render,screen} from '@testing-library/react';
import RoleChoice from '../src/RoleChoice';
afterEach(cleanup);
it('offers distinct accessible paths for manager and resident',()=>{
 const choose=vi.fn();render(<RoleChoice onChoose={choose}/>);
 fireEvent.click(screen.getByRole('button',{name:'مدیر ساختمان'}));expect(choose).toHaveBeenLastCalledWith('manager');
 fireEvent.click(screen.getByRole('button',{name:'از اهالی ساختمان'}));expect(choose).toHaveBeenLastCalledWith('resident');
 expect(screen.getByText(/دسترسی‌ها پس از ورود بررسی می‌شوند/)).toBeTruthy();
});
