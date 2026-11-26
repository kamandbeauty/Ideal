export type FinanceExportRow={id:string;kind:string;title:string;amount_toman:number|string;entry_date:string;note:string;created_by:string;created_at:string;voided_at:string|null;voided_by:string|null;void_reason:string|null};
// Spreadsheet applications may interpret cells starting with whitespace and formula characters as formulas.
function cell(value:unknown){let s=String(value??'');if(/^[\s\u0000-\u001f]*[=+@\-\t\r\n]/u.test(s))s="'"+s;return `"${s.replace(/"/g,'""')}"`}
export function appFinanceCsv(rows:FinanceExportRow[]){
 const header=['شناسه سند','نوع','عنوان','مبلغ تومان','تاریخ سند میلادی','توضیح','شناسه ثبت‌کننده','زمان ثبت','وضعیت','زمان ابطال','شناسه ابطال‌کننده','دلیل ابطال'];
 const records=rows.map(r=>[r.id,r.kind==='income'?'درآمد':'هزینه',r.title,String(r.amount_toman),r.entry_date,r.note,r.created_by,r.created_at,r.voided_at?'باطل':'فعال',r.voided_at,r.voided_by,r.void_reason]);
 return '\ufeff'+[header,...records].map(row=>row.map(cell).join(',')).join('\r\n');
}
