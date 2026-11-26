import {expect,it} from 'vitest';
import {appFinanceCsv} from '../src/appFinanceCsv';
it('escapes CSV quotes and neutralizes spreadsheet formulas in user text',()=>{
 const csv=appFinanceCsv([{id:'id',kind:'income',title:'  =HYPERLINK("x")',amount_toman:7000,entry_date:'2026-01-01',note:'\t+cmd',created_by:'u',created_at:'now',voided_at:null,voided_by:null,void_reason:null}]);
 expect(csv.startsWith('\ufeff')).toBe(true);expect(csv).toContain('"\'  =HYPERLINK(""x"")"');expect(csv).toContain('"\'\t+cmd"');expect(csv).toContain('"7000"');
});
