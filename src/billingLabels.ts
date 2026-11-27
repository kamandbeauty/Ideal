export const categories:Record<string,string>={monthly:'ثابت ماهانه',water:'آب',electricity:'برق',gas:'گاز',cleaning:'نظافت',insurance:'بیمه',maintenance:'تعمیرات و تأسیسات',other:'سایر'};
export const methods:Record<string,string>={equal:'مساوی',area:'متراژ',people:'نفرات',parking:'پارکینگ',storage:'انباری',default:'شارژ پیش‌فرض هر واحد',mixed:'تقسیم ترکیبی'};
export const responsibilities:Record<string,string>={resident:'ساکن',owner:'مالک',unit:'واحد',other:'شخص دیگر'};
export const amountText=(v:number|string)=>new Intl.NumberFormat('fa-IR').format(Number(v))+' تومان';
export const todayTehran=()=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Tehran',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export type ChargeLine={title:string;category:string;note:string;responsibility:string;method:string;total:number|string;amount:number|string;weights?:Record<string,number>};
export type BillingUnit={id:string;number:string;default_owner_charge?:number|string;default_resident_charge?:number|string};
