import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';
const source=readFileSync('qml/values.qml.inc','utf8').replace(/^(property|signal).*\n/gm,'');
function harness(){
 const ctx={Document:{Notebook:1},ndiError:'',ndiEnabled:{},Date,JSON};
 vm.createContext(ctx);vm.runInContext(source,ctx);
 let events=[];ctx.ndiRequest=(action,body)=>events.push({action,body});
 let pages=['a'];let doc={id:'notebook',fileType:1,get pageCount(){return pages.length},idForPage:i=>pages[i]};
 return {ctx,events,pages,doc};
}
test('creation invokes stock API and callback once; captures actual new ID',()=>{
 const {ctx,events,pages,doc}=harness();let callbacks=0,stock=0;
 const controller={addPageWithTemplateAndPageSize:(id,index,template,size,done)=>{stock++;pages.push('b');done()}};
 ctx.ndiAddPage(controller,doc,1,'Blank',{},()=>callbacks++);
 assert.equal(stock,1);assert.equal(callbacks,1);assert.equal(events.length,1);assert.equal(events[0].body.created[0],'b');
});
test('no successful new ID means no date; unrelated concurrent pages are ambiguous',()=>{
 const {ctx,events,pages,doc}=harness();let ticket=ctx.ndiBegin(doc,1,'add');ctx.ndiFinish(doc,ticket,null);assert.equal(events.length,0);
 pages.push('b','c');ctx.ndiFinish(doc,ticket,null);assert.equal(events.length,0);
});
test('duplication requires matching success signal IDs',()=>{
 const {ctx,events,pages,doc}=harness();let ticket=ctx.ndiBegin(doc,2,'duplicate');pages.push('b','c');
 ctx.ndiFinish(doc,ticket,[0,1]);assert.equal(events.length,0);ctx.ndiFinish(doc,ticket,[1,2]);assert.equal(events.length,0);
 ticket.signaled=[];ctx.ndiFinish(doc,ticket,[1,2]);assert.equal(events.length,1);
});
test('duplication can report one successful page at a time',()=>{
 const {ctx,events,pages,doc}=harness();let ticket=ctx.ndiBegin(doc,2,'duplicate');pages.push('b');
 assert.notEqual(ctx.ndiFinish(doc,ticket,[1]),true);assert.equal(events.length,0);pages.push('c');
 assert.equal(ctx.ndiFinish(doc,ticket,[2]),true);assert.equal(events.length,1);assert.equal(events[0].body.created.length,2);
});
test('PDFs, stale tickets and different notebooks do not record',()=>{
 const {ctx,events,pages,doc}=harness();doc.fileType=2;assert.equal(ctx.ndiBegin(doc,1,'add'),null);doc.fileType=1;
 let ticket=ctx.ndiBegin(doc,1,'add');pages.push('b');ticket.started-=10001;ctx.ndiFinish(doc,ticket,null);assert.equal(events.length,0);
 ticket.started=Date.now();doc.id='other';ctx.ndiFinish(doc,ticket,null);assert.equal(events.length,0);
});
test('optional recorder failure does not prevent stock callback',()=>{
 const {ctx,pages,doc}=harness();let callbacks=0;ctx.ndiRequest=()=>{throw Error('storage down')};
 const controller={addPageWithTemplateAndPageSize:(id,index,template,size,done)=>{pages.push('b');done()}};
 ctx.ndiAddPage(controller,doc,1,'Blank',{},()=>callbacks++);assert.equal(callbacks,1);
});
test('no global controller; forwards native receiver, return and callback arguments',()=>{
 const {ctx,doc}=harness();const size={width:100};const receiver={};let received;
 const controller={addPageWithTemplateAndPageSize(id,index,template,s,done){
   assert.equal(this,controller);assert.deepEqual([id,index,template,s],['notebook',-1,'Blank',size]);
   done.call(receiver,'created',42);return 17;
 }};
 assert.equal(ctx.ndiAddPage(controller,doc,-1,'Blank',size,function(...args){received=[this,...args]}),17);
 assert.deepEqual(received,[receiver,'created',42]);assert.equal(ctx.DocumentController,undefined);
});
test('even thrown observer functions cannot block native add or its callback',()=>{
 const {ctx,doc}=harness();let stock=0,callbacks=0;
 ctx.ndiBegin=()=>{throw Error('observer broken')};ctx.ndiFinish=()=>{throw Error('writer broken')};
 const controller={addPageWithTemplateAndPageSize(id,index,template,size,done){stock++;done();}};
 ctx.ndiAddPage(controller,doc,1,'Blank',{},()=>callbacks++);
 ctx.ndiAddPage(controller,doc,1,'Blank',{});
 assert.equal(stock,2);assert.equal(callbacks,1);
});
test('stock callback runs before optional recording',()=>{
 const {ctx,doc}=harness();const order=[];
 ctx.ndiFinish=()=>order.push('record');
 const controller={addPageWithTemplateAndPageSize(id,index,template,size,done){done();}};
 ctx.ndiAddPage(controller,doc,1,'Blank',{},()=>order.push('stock'));
 assert.deepEqual(order,['stock','record']);
});
