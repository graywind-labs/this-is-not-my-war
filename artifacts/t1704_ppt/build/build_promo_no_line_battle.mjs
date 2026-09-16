import fs from 'node:fs/promises';
import {createCanvas,loadImage,GlobalFonts} from '@napi-rs/canvas';
const out='D:/这不是我的战争/artifacts/t1704_promo_v3';
GlobalFonts.registerFromPath('C:/Windows/Fonts/msyh.ttc','Yahei');
GlobalFonts.registerFromPath('C:/Windows/Fonts/msyhbd.ttc','Yahei Bold');
let cv=createCanvas(1920,1080),c=cv.getContext('2d');
function text(s,x,y,size,col='#F7F1E6',bold=false){c.font=`${size}px "${bold?'Yahei Bold':'Yahei'}"`;c.fillStyle=col;c.textBaseline='top';c.fillText(s,x,y);}
const shot=process.argv[2]||'battle_001';
const status=JSON.parse(await fs.readFile('D:/这不是我的战争/artifacts/t1704_promo_v2/captures_towers/99_wave4_cleared.json','utf8'));
if(status.active_enemy_count!==0)throw Error('Fourth wave has not cleared');
const img=await loadImage('D:/这不是我的战争/artifacts/t1704_promo_v2/captures_towers/'+shot+'.png');
c.drawImage(img,0,0,1920,1080);
c.fillStyle='#172B27';c.fillRect(0,856,1920,224);
c.fillStyle='#D5AA67';text('这不是我的战争',119,879,24,'#D5AA67',true);
text('把平民组织起来，击退敌军守住驿站',64,929,51,'#F7F1E6',true);
text('全员征召配装 · 城墙升级 · 箭塔与部队协同防守',66,1005,27,'#BBC7BA');
c.fillStyle='#456155';c.fillRect(1560,899,1,133);
text('第四波',1610,913,45,'#D5AA67',true);text('守城实机 / 05',1612,984,25,'#BBC7BA');
await fs.writeFile(out+'/05_守城成果.png',cv.toBuffer('image/png'));
const names=(await fs.readdir(out)).filter(n=>/^0[1-5]_.*\.png$/.test(n)).sort();
if(names.length!==5)throw Error('Expected exactly five final images');
cv=createCanvas(1440,1290);c=cv.getContext('2d');c.fillStyle='#10211d';c.fillRect(0,0,1440,1290);
for(let i=0;i<5;i++){const x=24+i%2*708,y=24+Math.floor(i/2)*422;const im=await loadImage(out+'/'+names[i]);c.drawImage(im,x,y,684,385);text(names[i].replace('.png',''),x,y+391,18);}
text('这不是我的战争',748,937,42,'#F7F1E6',true);text('宣传图 / 去除标题短线',748,1000,30,'#D5AA67');text('5 张 · 1920 × 1080 · PNG',748,1050,24,'#BBC7BA');
await fs.writeFile(out+'/五张总览.png',cv.toBuffer('image/png'));
console.log('Updated image 05 and five-image overview; images 01–04 unchanged.');
