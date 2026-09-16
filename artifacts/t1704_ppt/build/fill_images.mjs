import fs from 'node:fs/promises';
import {createCanvas,loadImage} from '@napi-rs/canvas';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const P=Presentation.create({slideSize:{width:1280,height:720}});
const sets=[
[9,'06_battle.png',[850,360,1290,640],[60,346,1160,95],'自动接敌实机局部；使用现有 GM 配装和第三波快速开战，非 AI 征召证据'],
[11,'07_battle_detail.png',[600,100,1550,900],[675,158,605,510],'实际战斗；通过现有 GM 配装和第三波快速开战，程序自动执行移动、索敌与攻击'],
[17,'01_notice.png',[630,240,1290,830],[720,167,496,295],'正式公告牌发布劳动力安排，NPC 见闻库记录广播；不表示该安排已经通过 LLM 执行'],
[18,'04_equipment.png',[1140,680,1920,1045],[748,168,470,286],'艾达正式装备与人物界面；拍摄于 GM 战斗配装之前'],
[19,'02_witness.png',[530,255,1390,813],[60,166,557,290],'布鲁诺的真实见闻记录，含场所变化与本轮守备官发布的公告；非伪造记忆']
];
for(const [part,name,crop,box,alt] of sets){const s=P.slides.add();s.background.fill='#172B27';const im=await loadImage(base+'/screenshots_extra/'+name);const [l,t,r,b]=crop;const cv=createCanvas(r-l,b-t);cv.getContext('2d').drawImage(im,l,t,r-l,b-t,0,0,r-l,b-t);const [x,y,w,h]=box;s.images.add({blob:new Uint8Array(cv.toBuffer('image/png')),contentType:'image/png',alt,fit:part===11?'cover':'contain',position:{left:x,top:y,width:w,height:h}});}
await(await PresentationFile.exportPptx(P)).save(base+'/build/image_additions.pptx');
await fs.writeFile(base+'/build/image_additions_map.json',JSON.stringify(sets));
