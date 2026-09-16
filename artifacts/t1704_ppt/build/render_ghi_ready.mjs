import fs from 'node:fs/promises';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const p=await PresentationFile.importPptx(await FileBlob.load(base+'/output/这不是我的战争_项目介绍_v6_ghi_ready.pptx'));
await fs.mkdir(base+'/build/v6_ghi_rendered',{recursive:true});
for(const n of [13,15,16]){const png=await p.export({slide:p.slides.items[n-1],format:'png',scale:1});await fs.writeFile(base+'/build/v6_ghi_rendered/'+n+'.png',new Uint8Array(await png.arrayBuffer()));}
