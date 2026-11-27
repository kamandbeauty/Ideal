import {useEffect,useRef,useState} from 'react';
import {normalizeDigits} from './normalizeDigits';
const formatter=new Intl.DateTimeFormat('en-US-u-ca-persian-nu-latn',{year:'numeric',month:'numeric',day:'numeric',timeZone:'UTC'});
const dayMs=86400000;
function parts(ms:number){const p=formatter.formatToParts(new Date(ms));return ['year','month','day'].map(k=>Number(p.find(x=>x.type===k)?.value))}
export function toJalali(iso:string){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(iso))return '';
 const ms=Date.parse(iso+'T00:00:00Z');if(!Number.isFinite(ms)||new Date(ms).toISOString().slice(0,10)!==iso)return '';
 const [y,m,d]=parts(ms);return [y,m,d].map(n=>String(n).padStart(2,'0')).join('/').replace(/\d/g,c=>'۰۱۲۳۴۵۶۷۸۹'[Number(c)]);
}
export function fromJalali(value:string){
 const m=normalizeDigits(value.trim()).match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})$/);
 if(!m)return '';const [year,month,day]=m.slice(1).map(Number);
 if(year<1278||year>1579||month<1||month>12||day<1||day>31)return '';
 const target=year*10000+month*100+day;
 let lo=Math.floor(Date.UTC(year+621,0,1)/dayMs),hi=Math.floor(Date.UTC(year+622,11,31)/dayMs);
 while(lo<=hi){const mid=Math.floor((lo+hi)/2),[y,m,d]=parts(mid*dayMs),key=y*10000+m*100+d;if(key===target)return new Date(mid*dayMs).toISOString().slice(0,10);if(key<target)lo=mid+1;else hi=mid-1}
 return '';
}
type Props={name?:string;label:string;defaultValue?:string;value?:string;onChange?:(iso:string)=>void;min?:string;max?:string;required?:boolean;onValidity?:(ok:boolean)=>void};
export default function JalaliDateField({name,label,defaultValue='',value,onChange,min,max,required=false,onValidity}:Props){
 const initial=value??defaultValue;
 const [text,setText]=useState(()=>toJalali(initial)),[iso,setIso]=useState(initial);
 const ref=useRef<HTMLInputElement>(null);const last=useRef(initial);
 useEffect(()=>{if(value!==undefined&&value!==last.current){setText(toJalali(value));setIso(value);last.current=value}},[value]);
 const valid=iso&&(!min||iso>=min)&&(!max||iso<=max);
 useEffect(()=>{const ok=!text?!required:Boolean(valid);ref.current?.setCustomValidity(!ok&&text?'تاریخ شمسی نامعتبر یا خارج از بازه است.':'');onValidity?.(ok)},[text,valid,required,onValidity]);
 function change(raw:string){const digits=normalizeDigits(raw);if(/^\d{5,8}$/.test(digits))raw=[digits.slice(0,4),digits.slice(4,6),digits.slice(6)].filter(Boolean).join('/');else if(/^\d{4}\/\d{3,4}$/.test(digits))raw=digits.slice(0,7)+'/'+digits.slice(7);setText(raw);const parsed=fromJalali(raw);setIso(parsed);last.current=parsed;onChange?.(parsed)}
 return <label>{label}<input ref={ref} type="text" dir="ltr" inputMode="numeric" placeholder="۱۴۰۵/۰۹/۰۶" value={text} maxLength={10} required={required} onChange={e=>change(e.target.value)} onBlur={()=>{if(valid)setText(toJalali(iso))}} aria-invalid={Boolean(text&&!valid)}/>{name&&<input type="hidden" name={name} value={valid?iso:''}/>}<small className="billing-subtext">سال/ماه/روز (شمسی)</small></label>
}
