import fs from 'node:fs/promises';
import {createCanvas,loadImage} from '@napi-rs/canvas';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const im=await loadImage(base+'/screenshots_extra/06_battle.png');
const c=createCanvas(1720,141);c.getContext('2d').drawImage(im,100,480,1720,141,0,0,1720,141);await fs.writeFile(base+'/build/battle_strip.png',c.toBuffer('image/png'));
