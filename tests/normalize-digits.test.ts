import {expect,it} from 'vitest';
import {normalizeDigits} from '../src/normalizeDigits';
it('normalizes Persian and Arabic-Indic digits, including mixed OTP codes',()=>{
  expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹')).toBe('0123456789');
  expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩')).toBe('0123456789');
  expect(normalizeDigits('۱٢3۴٥6')).toBe('123456');
  expect(normalizeDigits('+۹۸ ٩١٢-۱۲۳۴۵۶۷')).toBe('+98 912-1234567');
});
