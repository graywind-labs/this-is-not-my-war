import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {createCanvas,loadImage} from '@napi-rs/canvas';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const skill='C:/Users/JT/.codex/plugins/cache/openai-primary-runtime/presentations/26.909.12148/skills/presentations';
const data=JSON.parse(await fs.readFile(base+'/build/v2_content.json','utf8'));
const P=Presentation.create({slideSize:{width:1280,height:720}});
const C={paper:'#F2ECDF',ink:'#24342F',rust:'#A04B35',gold:'#D5AA67',dark:'#172B27',white:'#F7F1E6',muted:'#7C8075',line:'#C4BCAA',blank:'#E6DFD1'};
const measure=createCanvas(10,10).getContext('2d');
function wrap(t,w,sz){measure.font=`${sz}px Microsoft YaHei`;return t.split('\n').map(p=>{let lines=[],l='';for(const ch of p){if(measure.measureText(l+ch).width>w-38&&l&&!('，。、；：！？）”'.includes(ch))){lines.push(l);l=ch;}else l+=ch;}lines.push(l);return lines.join('\n');}).join('\n');}
function shape(s,x,y,w,h,fill,line='none',geo='rect'){return s.shapes.add({geometry:geo,position:{left:x,top:y,width:w,height:h},fill,line:{fill:line,width:line==='none'?0:1}});}
function txt(s,t,x,y,w,h,sz=25,col=C.ink,bold=false){let a=shape(s,x,y,w,h,'none');a.text=wrap(t,w,sz);a.text.style={typeface:'Microsoft YaHei',fontSize:sz,bold,color:col,autoFit:'none'};return a;}
function line(s,x,y,w,color=C.line){shape(s,x,y,w,1,color);}
async function photo(s,name,x,y,w,h,crop=null,fit='cover'){let p=name.startsWith('art:')?'D:/这不是我的战争/assets/tutorial/lowpoly_v1/'+name.slice(4):base+'/screenshots/'+name;let bytes=await fs.readFile(p);if(crop){const im=await loadImage(bytes);const sx=Math.round(im.width*crop.left),sy=Math.round(im.height*crop.top),sw=Math.round(im.width*(1-crop.left-crop.right)),sh=Math.round(im.height*(1-crop.top-crop.bottom));const cv=createCanvas(sw,sh);cv.getContext('2d').drawImage(im,sx,sy,sw,sh,0,0,sw,sh);bytes=cv.toBuffer('image/png');}return s.images.add({blob:new Uint8Array(bytes),contentType:'image/png',alt:name+(crop?' — full-screen screenshot detail crop':''),fit,position:{left:x,top:y,width:w,height:h}});}

function start(i,dark=false,title=null){let s=P.slides.add();s.background.fill=dark?C.dark:C.paper;let label=i<=3?'产品定位':i<=8?'核心技术':i<=11?'游戏创意':'核心玩法';txt(s,label,60,26,350,25,16,dark?C.gold:C.rust,true);txt(s,title??data[i-1].title,60,65,1160,77,46,dark?C.white:C.ink,true);line(s,60,678,1160,dark?'#41514A':C.line);txt(s,'这不是我的战争',60,686,430,24,14,dark?'#8F9C91':C.muted);txt(s,String(i).padStart(2,'0'),1150,686,70,25,14,dark?C.gold:C.rust);s.speakerNotes.textFrame.setText(data[i-1].notes+'\nV2：保留上一版确认内容，重排视觉。示意图为机制说明，不冒充运行截图。');return s;}
function note(s,t){s.speakerNotes.textFrame.setText(s.speakerNotes.textFrame.text+'\n'+t);}
function evidence(s,id,caption,x,y,w,h,dark=false){shape(s,x,y,w,h,dark?'#243B33':C.blank);line(s,x,y+h,w,dark?'#647569':C.line);txt(s,`${id}  /  ${caption}`,x+18,y+h-40,w-36,34,18,dark?'#B9C4B8':C.muted);}
function cols(s,i,y=483,dark=false,sz=23){let rs=data[i-1].rows;rs.forEach(([h,b],j)=>{let x=60+j*396;txt(s,h,x,y,366,34,25,dark?C.gold:C.rust,true);txt(s,b,x,y+44,366,143,sz,dark?C.white:C.ink);});}
function arrow(s,x,y,w=58,h=14,rot=0,color=C.rust){let a=shape(s,x,y,w,h,color,'none','rightArrow');if(rot)a.position={left:x,top:y,width:w,height:h,rotation:rot};}
function node(s,t,x,y,w,h=54,dark=false){shape(s,x,y,w,h,dark?'#334B40':'#E3DDCE');txt(s,t,x+12,y+9,w-24,h-10,23,dark?C.white:C.ink,true);}
// 01 — Full scene cover, high-contrast editorial title.
let s=P.slides.add();s.background.fill=C.dark;
await photo(s,'01_station.png',0,0,1280,720);
shape(s,0,0,1280,720,'linear(0deg, #10251F/98 0%, #10251F/92 32%, #10251F/15 74%, #10251F/4 100%)');
txt(s,'叙事重构·AI沙盒与涌现式世界',62,52,1040,36,22,C.gold);
txt(s,'这不是\n我的战争',60,145,650,244,91,C.white,true);
txt(s,'玩家扮演一个边境驿站征兵官，\n想办法说服平民上战场、\n”鼓励”他们干活、不让他们当逃兵。',66,478,620,154,27,C.white);
s.speakerNotes.textFrame.setText(data[0].notes+'\nV2 封面使用全屏全景截图作为背景，渐变仅用于文字对比。');
// 02 — Personnel as the product anchor.
s=start(2);txt(s,'人员管理',58,167,710,108,88,C.rust,true);
txt(s,data[1].rows[0][1],64,315,648,140,31);
line(s,64,493,604);txt(s,'所选赛道',64,523,604,38,24,C.rust,true);txt(s,data[1].rows[1][1],64,571,620,64,25);
await photo(s,'03_npc.png',780,160,440,486,{left:.65,top:.01,right:.01,bottom:.07},'contain');
// 03 — Image-led art direction with an inset narrative photograph.
s=start(3,true,'美术、题材与叙事');
await photo(s,'art:prologue_dormitory_sleep.png',0,153,748,510,null,'cover');
shape(s,0,153,748,510,'linear(90deg, #172B27/0 0%, #172B27/0 66%, #172B27/84 100%)');
data[2].rows.forEach(([h,b],j)=>{txt(s,h,786,175+j*157,434,37,25,C.gold,true);txt(s,b,786,219+j*157,434,113,24,C.white);});
s.speakerNotes.textFrame.setText(data[2].notes+'\nV2 配图：assets/tutorial/lowpoly_v1/prologue_dormitory_sleep.png，项目正式序章资产，用于美术与叙事定位，不作 AI 效果证据。');
// 04 — A bounded information space and its actual inspector.
s=start(4);txt(s,'建筑即信息空间',64,171,700,49,32,C.rust,true);
shape(s,64,242,720,166,'none',C.line);
[['人员',82],['设施',310],['状态',538]].forEach(([a,x])=>{shape(s,x,273,50,50,C.dark,'none','ellipse');txt(s,a,x+63,280,155,43,29,C.ink,true);});
txt(s,'进入时获取快照 · 变化时接收增量',86,349,675,46,24,C.muted);
await photo(s,'05_building.png',903,163,294,278,{left:.789,top:.015,right:.005,bottom:.60},'contain');
data[3].rows.forEach(([h,b],j)=>{let x=64+j*396;txt(s,h,x,461,366,35,25,C.rust,true);txt(s,b,x,506,366,141,23);});
// 05 — Three visibility lanes.
s=start(5);const lanes=[['私有','本人 / 交互亲历者'],['同一信息空间','当时在场的其他人'],['驿站公开','全站可接收信息的 NPC']];
lanes.forEach(([h,b],j)=>{let y=170+j*84;txt(s,String(j+1).padStart(2,'0'),64,y,97,53,35,C.rust,true);node(s,h,168,y,230);arrow(s,423,y+18,100,14);node(s,b,551,y,595);});
cols(s,5,464,false,22);evidence(s,'B','事件 / 见闻对照',889,405,323,38);
// 06 — A plan timeline, editable hour blocks.
s=start(6,true);txt(s,'24',60,155,260,118,105,C.gold,true);txt(s,'小时完整计划',67,273,280,48,29,C.white);
txt(s,'00',363,166,65,30,18,C.gold);txt(s,'12',774,166,65,30,18,C.gold);txt(s,'23',1147,166,65,30,18,C.gold);
for(let j=0;j<24;j++){shape(s,366+j*34,207,29,48,'#667C67');shape(s,366+j*34,290,29,48,[8,9,10].includes(j)?C.gold:'#344B3E');}
txt(s,'原计划',366,256,250,30,18,'#ADB7AA');txt(s,'仅修改选中时段（范围示意）',366,351,815,41,23,C.gold);
cols(s,6,458,true,23);
// 07 — Layers of memory with their different persistence.
s=start(7);let ys=[168,329,490];let widths=[760,810,860];
data[6].rows.forEach(([h,b],j)=>{shape(s,60,ys[j],widths[j],141,j===2?C.dark:j===1?'#DAD4C2':'#E5DFD1');txt(s,h,81,ys[j]+15,211,44,29,j===2?C.gold:C.rust,true);txt(s,b,309,ys[j]+18,widths[j]-270,114,23,j===2?C.white:C.ink);});
evidence(s,'C','日记 / 知识图谱',950,168,268,463);
// 08 — Deterministic execution, distinct from deliberation.
s=start(8);const flow=['计划目标','移动执行','门口通行','接敌攻击'];
flow.forEach((t,j)=>{node(s,t,60+j*300,194,236,73);if(j<3)arrow(s,305+j*300,224,42,13);});
txt(s,'工位与路线',74,281,250,36,22,C.muted);txt(s,'导航 / RVO / 碰撞',374,281,275,36,22,C.muted);txt(s,'FIFO 通行令牌',674,281,269,36,22,C.muted);txt(s,'索敌与射程衔接',974,281,270,36,22,C.muted);
evidence(s,'D','排队或自动接敌实机图',60,346,1160,95);cols(s,8,476,false,22);
// 09 — Pressure supplies purpose, backed by the game world.
s=start(9,true);await photo(s,'art:prologue_sealed_order.png',675,158,605,510);
shape(s,675,158,605,510,'linear(0deg, #172B27/60 0%, #172B27/0 100%)');
data[8].rows.forEach(([h,b],j)=>{txt(s,h,64,190+j*204,575,47,30,C.gold,true);txt(s,b,64,249+j*204,575,135,27,C.white);});
txt(s,'E / 守城实战图待补',826,617,389,39,18,C.white);
s.speakerNotes.textFrame.setText(data[8].notes+'\nV2 背景：正式序章军令图 prologue_sealed_order.png，表现守城处境；E 仍待补真正战斗过程。');
// 10 — Two sides of emotional interaction.
s=start(10);txt(s,'玩家表达',64,171,500,60,45,C.ink,true);txt(s,'NPC 反馈',706,171,510,60,45,C.rust,true);arrow(s,583,201,76,17);
txt(s,'语言 + 情绪',66,236,504,44,27,C.muted);txt(s,'动作 / 语气音效 / emoji',708,236,506,44,27,C.muted);
evidence(s,'F1','语音识别草稿',64,303,512,167);evidence(s,'F2','情绪回复画面',706,303,510,167);
txt(s,data[9].rows[1][0],64,507,512,38,27,C.rust,true);txt(s,data[9].rows[1][1],64,554,512,106,24);
txt(s,data[9].rows[0][0],706,507,510,38,27,C.rust,true);txt(s,data[9].rows[0][1],706,554,510,106,24);
// 11 — A legible feedback loop rather than another paragraph stack.
s=start(11,true);node(s,'经营决策',65,199,231,66,true);node(s,'NPC 获知信息',417,199,251,66,true);arrow(s,308,224,93,16,0,C.gold);
node(s,'玩家调整安排',65,379,231,66,true);node(s,'NPC 作出选择',417,379,251,66,true);arrow(s,308,404,93,16,180,C.gold);arrow(s,512,305,66,16,90,C.gold);arrow(s,147,305,66,16,270,C.gold);
txt(s,'双向影响丰富策略',64,489,630,45,31,C.gold,true);txt(s,data[10].rows[0][1],64,543,630,104,25,C.white);
txt(s,data[10].rows[1][0],759,195,456,70,34,C.gold,true);txt(s,data[10].rows[1][1],759,291,456,211,28,C.white);evidence(s,'G','经营安排与真实回应',759,532,456,108,true);
// 12 — A spacious interaction case layout.
s=start(12);evidence(s,'H','征召对话：玩家输入 / 人物回应 / 应征结果',60,165,1160,291);cols(s,12,484,false,23);
// 13 — War morale, darker visual rhythm.
s=start(13,true);evidence(s,'I','战时鼓舞 / 逃离挽留',60,167,796,281,true);
txt(s,'士气\n与去留',902,196,310,153,53,C.gold,true);txt(s,'交涉结果与后续行为\n共同提供反馈',907,373,315,70,23,C.white);cols(s,13,483,true,23);
// 14 — Crop to the real plan window, leaving an input evidence companion.
s=start(14);await photo(s,'04_plan.png',60,166,614,296,{left:.275,top:.241,right:.275,bottom:.247},'contain');
evidence(s,'J','劳动指令 / 实际行动',720,167,496,295);
txt(s,'第一日预设计划界面；跨天计划由 LLM 生成',66,465,618,28,16,C.muted);cols(s,14,508,false,22);
// 15 — Preparation and defence with contextual game photography.
s=start(15,true);await photo(s,'02_gate.png',0,156,704,318);
evidence(s,'K','配装 / 器械 / 实际战斗',748,168,470,286,true);cols(s,15,493,true,22);
// 16 — Different views on the same person's history.
s=start(16);evidence(s,'L1','亲历 / 见闻',60,166,557,290);evidence(s,'L2','日记 / 知识图谱',661,166,557,290);cols(s,16,486,false,23);

const rev=process.env.DECK_REV??'v2';
await fs.mkdir(`${base}/build/${rev}_rendered`,{recursive:true});
const candidate=`${base}/build/${rev}_candidate.pptx`;
await (await PresentationFile.exportPptx(P)).save(candidate);
for(let i=0;i<P.slides.items.length;i++){let sl=P.slides.items[i];let png=await P.export({slide:sl,format:'png',scale:1});await fs.writeFile(`${base}/build/${rev}_rendered/${String(i+1).padStart(2,'0')}.png`,new Uint8Array(await png.arrayBuffer()));console.log('rendered',i+1);}
const {finalizePresentation}=await import(pathToFileURL(skill+'/container_tools/artifact_tool_utils.mjs').href);
const result=await finalizePresentation({workspaceDir:base,candidatePath:candidate,finalPath:`${base}/output/这不是我的战争_项目介绍_${rev}.pptx`,pythonExecutable:'C:/Users/JT/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:skill+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:skill+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit'],fontPolicy:{basis:'design',families:['Microsoft YaHei']},requiredNativeChartOwnerSlides:[],requiredNativeTableOwnerSlides:[],verifyArtifactToolImport:true,receiptPath:`${base}/build/${rev}_validation.json`});
console.log(JSON.stringify({final:result.finalPath,integrity:result.packageIntegrity?.status}));
