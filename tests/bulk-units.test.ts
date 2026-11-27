import {expect,it} from 'vitest';
import {bulkUnits} from '../src/bulkUnits';
it('builds a consecutive batch with common attributes',()=>{
 const rows=bulkUnits('b',10,3,' A ',80,2,1);
 expect(rows.map(r=>r.number)).toEqual(['10','11','12']);
 expect(rows[0]).toEqual({building_id:'b',number:'10',block:'A',area:80,occupants:2,parking:1});
});
it('rejects invalid ranges and numeric fields',()=>{
 expect(()=>bulkUnits('b',1,201,'',0,0,0)).toThrow();
 expect(()=>bulkUnits('b',1,2,'',-1,0,0)).toThrow();
});
