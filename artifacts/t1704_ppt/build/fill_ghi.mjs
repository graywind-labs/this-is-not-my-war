import fs from 'node:fs/promises';
import {createCanvas,loadImage} from '@napi-rs/canvas';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const p=Presentation.create({slideSize:{width:1280,height:720}});
const sets=[
 [13,[['G_response.png',[610,349,1305,503],[759,532,456,108],'真实对话局部：格伦反对频繁切换工作；NPC 的表述不等于程序结算规则']]],
 [15,[['H_result.png',[1262,20,1466,434],[60,165,143,291],'布鲁诺实机形象'],['H_recruit_2.png',[610,518,1306,708],[216,173,1004,275],'真实征召对话：明确厨房与后勤分工后，布鲁诺同意应征']]],
 [16,[['I_history.png',[542,616,1376,756],[60,167,796,134],'正式对话记录中的真实挽留回复；逃离起始状态由现有 GM 入口触发'],['I_result.png',[1262,20,1466,434],[60,307,69,140],'挽留后的布鲁诺'],['I_result.png',[1495,573,1890,683],[143,307,503,140],'真实事件结果：布鲁诺被挽留下来，停止逃离驿站']]]
];
for(const [n,images] of sets){const s=p.slides.add();s.background.fill='#172B27';for(const [name,crop,box,alt] of images){const im=await loadImage(base+'/screenshots_ghi/'+name);const [l,t,r,b]=crop;const c=createCanvas(r-l,b-t);c.getContext('2d').drawImage(im,l,t,r-l,b-t,0,0,r-l,b-t);const [x,y,w,h]=box;s.images.add({blob:new Uint8Array(c.toBuffer('image/png')),contentType:'image/png',alt,fit:'contain',position:{left:x,top:y,width:w,height:h}});}}
await(await PresentationFile.exportPptx(p)).save(base+'/build/ghi_additions.pptx');
