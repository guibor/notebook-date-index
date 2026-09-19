import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const ctx=vm.createContext({}); vm.runInContext(fs.readFileSync('qml/date-tree.js','utf8'),ctx);
const group=(day,estimated=false)=>({day,pages:[{id:day,number:4,estimated}]});
test('minimal tablet Qt contract excludes unavailable accessibility attachment',()=>{
 assert.doesNotMatch(fs.readFileSync('qml/popup.qml.inc','utf8'),/Accessible\./);
});
test('month hierarchy, stable page identity, estimate labels',()=>{
 const rows=ctx.rows([group('2026-09-18',true),group('2026-09-19')],{'d:2026-09-18':true});
 assert.equal(rows[0].title,'September 2026');
 assert.equal(rows[1].title,'Saturday 19');
 assert.equal(rows[2].detail,'1 page · 1 estimated');
 assert.equal(rows[3].pageId,'2026-09-18');
 assert.equal(rows[3].title,'Page 4');
});
test('multi-year hierarchy defaults to recent year and limits long history',()=>{
 const groups=['2024-01-01','2026-09-18','2026-08-01','2026-07-01','2026-06-01'].map(d=>group(d));
 const rows=ctx.rows(groups,{});
 assert.equal(rows[0].title,'2026'); assert.equal(rows[1].title,'September');
 assert.equal(rows.filter(r=>r.kind==='day').length,1);
 const old=ctx.rows(groups,{'y:2024':true,'m:2024-01':true});
 assert.ok(old.some(r=>r.pageId==='2024-01-01'));
 assert.equal(groups[0].day,'2024-01-01','input was mutated');
});
test('collapsed rows and empty state',()=>{
 assert.equal(ctx.rows([],{}).length,0);
 assert.equal(ctx.rows([group('2026-09-18')],{'m:2026-09':false}).length,1);
});
test('late view/notebook responses never overwrite the active panel',()=>{
 const popup=fs.readFileSync('qml/popup.qml.inc','utf8');
 const refresh=popup.slice(popup.indexOf('function ndiRefresh()'),popup.indexOf('\nConnections {'));
 const pending=[];
 const state={mode:'created',requestGeneration:0};
 const root={document:{id:'notebook-a',fileType:1}};
 const context=vm.createContext({root,ndiPopup:state,Document:{Notebook:1},Values:{ndiIds:()=>[],ndiRequest:(action,body,done)=>pending.push(done)}});
 vm.runInContext(refresh,context);
 context.ndiRefresh(); state.mode='modified'; context.ndiRefresh();
 pending[1]({enabled:false,groups:[{day:'2026-09-19'}],timezone:'UTC'});
 pending[0]({enabled:true,groups:[{day:'2020-01-01'}],timezone:'Asia/Jerusalem'});
 assert.equal(state.groups[0].day,'2026-09-19'); assert.equal(state.timezone,'UTC');
 context.ndiRefresh(); root.document.id='notebook-b';
 pending[2]({enabled:true,groups:[{day:'2020-01-01'}]});
 assert.equal(state.groups[0].day,'2026-09-19');
});
