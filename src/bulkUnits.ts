export function bulkUnits(buildingId:string, first:number,count:number,block:string,area:number,occupants:number,parking:number){
 if(!buildingId||!Number.isSafeInteger(first)||first<1||!Number.isInteger(count)||count<1||count>200||!Number.isSafeInteger(first+count-1)||!Number.isFinite(area)||area<0||area>99999999.99||![occupants,parking].every(v=>Number.isInteger(v)&&v>=0&&v<=2147483647))throw new Error('مشخصات واحدها معتبر نیست. تعداد باید بین ۱ و ۲۰۰ باشد.');
 return Array.from({length:count},(_,i)=>({building_id:buildingId,number:String(first+i),block:block.trim(),area,occupants,parking}));
}
