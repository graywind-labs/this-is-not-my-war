import fs from 'node:fs/promises';
import path from 'node:path';
import {createCanvas,loadImage,GlobalFonts} from '@napi-rs/canvas';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const out='D:/这不是我的战争/artifacts/t1704_promo_v3';
await fs.mkdir(out+'/原始截图',{recursive:true});
GlobalFonts.registerFromPath('C:/Windows/Fonts/msyh.ttc','Yahei');
GlobalFonts.registerFromPath('C:/Windows/Fonts/msyhbd.ttc','Yahei Bold');
const C={bg:'#172B27',card:'#203B34',gold:'#D5AA67',ink:'#F7F1E6',muted:'#BBC7BA',line:'#456155'};
let cv,c;const used=new Set();const images=new Map();const exported=[];const checks=[];
function rect(x,y,w,h,col){c.fillStyle=col;c.fillRect(x,y,w,h);}
function text(s,x,y,size=28,color=C.ink,bold=false){c.fillStyle=color;c.font=`${size}px "${bold?'Yahei Bold':'Yahei'}"`;c.textBaseline='top';c.fillText(s,x,y);checks.push({text:s,x,y,width:c.measureText(s).width,size});}
function wrap(s,x,y,w,size=28,color=C.ink,bold=false,line=1.5){c.font=`${size}px "${bold?'Yahei Bold':'Yahei'}"`;let buf='',yy=y;for(const ch of s){if(ch==='\n'||c.measureText(buf+ch).width>w){text(buf,x,yy,size,color,bold);buf=ch==='\n'?'':ch;yy+=size*line;}else buf+=ch;}if(buf)text(buf,x,yy,size,color,bold);return yy+size*line;}
async function im(name,crop,box,cover=false){let img=images.get(name);if(!img){img=await loadImage(base+'/'+name);images.set(name,img);}used.add(name);let [sx,sy,sw,sh]=crop??[0,0,img.width,img.height];let [x,y,w,h]=box;const r=cover?Math.max(w/sw,h/sh):Math.min(w/sw,h/sh);c.save();c.beginPath();c.rect(x,y,w,h);c.clip();c.drawImage(img,sx,sy,sw,sh,x+(w-sw*r)/2,y+(h-sh*r)/2,sw*r,sh*r);c.restore();}
function start(num,tag,title,sub){cv=createCanvas(1920,1080);c=cv.getContext('2d');rect(0,0,1920,1080,C.bg);text('这不是我的战争',119,42,26,C.gold,true);text(tag,1510,44,22,C.muted);text(title,64,112,60,C.ink,true);text(sub,66,197,27,C.muted);rect(64,1008,1792,1,C.line);text('叙事重构 · AI沙盒与涌现式世界',64,1030,20,C.muted);text(`实机画面  /  ${String(num).padStart(2,'0')}`,1670,1030,20,C.gold);}
function label(n,s,x,y){text(n,x,y,25,C.gold,true);text(s,x+55,y,27,C.ink,true);}
async function save(name){await fs.writeFile(out+'/'+name,cv.toBuffer('image/png'));exported.push(name);}

// 01: title and two actual gameplay views.
start(1,'AI NPC × 模拟经营','这不是我的战争','想办法组织一群不属于战争的人，守住边境驿站。');
rect(64,282,625,660,C.card);text('玩家身份',100,318,24,C.gold,true);
wrap('玩家扮演一个边境驿站征兵官，\n想办法说服平民上战场、\n”鼓励”他们干活、\n不让他们当逃兵。',100,374,545,34,C.ink,true,1.7);
text('征召平民  /  调配劳动力  /  挽留逃兵',100,721,25,C.gold);
wrap('用 AI NPC 增强模拟经营游戏里\n“人员管理”的乐趣。',100,791,532,29,C.muted);
await im('screenshots/01_station.png',[290,235,1240,845],[718,282,1138,660],true);
rect(1360,670,496,272,C.bg);await im('screenshots_extra/07_battle_detail.png',[760,260,660,470],[1370,680,476,252],true);
rect(718,899,422,43,C.bg);text('低模 3D 驿站  ·  守城实机',738,907,22,C.gold);
await save('01_主视觉.png');

// 02: preserve the rejection-to-acceptance sequence.
start(2,'核心体验 / 对话征召','针对人物顾虑，争取平民入伍','玩家选择说辞，AI NPC 结合职业与顾虑回应，应征结果提供明确反馈。');
await im('screenshots_ghi/H_result.png',[1262,20,204,414],[64,285,310,625],true);
rect(64,858,310,100,C.card);text('布鲁诺',87,877,34,C.ink,true);text('厨子 → 同意应征',87,924,22,C.gold);
label('01','先提出顾虑',421,280);
rect(420,326,1436,238,'#1c160f');await im('screenshots_ghi/H_recruit_2.png',[610,408,697,92],[444,341,1388,204]);
label('02','明确分工，再次争取',421,596);
rect(420,645,1436,313,'#1c160f');await im('screenshots_ghi/H_recruit_2.png',[610,518,697,188],[444,662,1388,281]);
await save('02_对话征召.png');

// 03: actual announcement, response, revised announcement.
start(3,'核心体验 / 劳动力交涉','经营安排引发回应，人物回应改变安排','同一批人承担生产与防守，安排岗位也需要争取人物配合。');
await im('screenshots_ghi/G_response.png',[1322,65,142,369],[64,285,309,627],false);
rect(64,858,309,100,C.card);text('格伦',88,876,34,C.ink,true);text('铁匠 / 工作安排交涉',88,925,22,C.gold);
label('01','发布备战安排',420,280);
rect(420,325,1436,135,'#20231e');await im('screenshots_ghi/G_decision.png',[645,328,630,64],[444,338,1388,108]);
label('02','格伦反对频繁切换工作',420,494);
rect(420,539,1436,241,'#1c160f');await im('screenshots_ghi/G_response.png',[611,419,693,74],[444,559,1388,199]);
label('03','根据回应修订安排',420,814);
rect(420,859,1436,100,'#20231e');await im('screenshots_ghi/G_revised_decision.png',[645,328,630,64],[444,865,1388,88]);
await save('03_劳动力交涉.png');

// 04: formal history plus authoritative result; no rewritten dialogue.
start(4,'核心体验 / 逃离挽留','征召之后，还要让他们愿意留下','玩家尝试改变逃离决定，交涉结果落实为人物后续行为。');
await im('screenshots_ghi/I_result.png',[1262,20,204,414],[64,284,309,626],true);
rect(64,858,309,100,C.card);text('布鲁诺',88,876,34,C.ink,true);text('逃离 → 被挽留下来',88,925,22,C.gold);
label('01','尝试挽留：承诺回到食堂，照顾伤员',420,282);
rect(420,329,1436,282,'#202721');await im('screenshots_ghi/I_history.png',[543,621,812,129],[443,353,1388,220]);
label('02','系统结果：停止逃离驿站',420,656);
rect(420,708,1436,250,'#1c160f');await im('screenshots_ghi/I_result.png',[1497,620,391,53],[460,737,1356,188]);
await save('04_逃离挽留.png');

// Independent original captures and a compact review sheet.
const bad=checks.filter(x=>x.x+x.width>1900||x.y+x.size>1080);if(bad.length)throw Error(JSON.stringify(bad));
for(const name of used)await fs.copyFile(base+'/'+name,out+'/原始截图/'+name.replaceAll('/','__'));
cv=createCanvas(1440,1290);c=cv.getContext('2d');rect(0,0,1440,1290,'#10211d');
for(let i=0;i<4;i++){let x=24+(i%2)*708,y=24+Math.floor(i/2)*422;const img=await loadImage(out+'/'+exported[i]);c.drawImage(img,x,y,684,385);text(exported[i].replace('.png',''),x,y+391,18,C.ink);}
text('这不是我的战争',748,937,42,C.ink,true);text('宣传图片 / 第一版',748,1000,30,C.gold);text('5 张 · 1920 × 1080 · PNG',748,1050,24,C.muted);
await fs.writeFile(out+'/五张总览.png',cv.toBuffer('image/png'));
await fs.writeFile(out+'/素材记录.json',JSON.stringify({images:exported,originals:[...used],size:[1920,1080],screenshotPixels:'Original screenshots cropped and scaled only; no dialogue rewriting',pptModified:false},null,2));
console.log('Created 5 promotional images, contact sheet, and original screenshot copies.');
