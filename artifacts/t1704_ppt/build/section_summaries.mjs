import fs from 'node:fs/promises';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt/build';
const P=Presentation.create({slideSize:{width:1280,height:720}});
const groups=[['核心技术',['为 LLM 装上“眼睛”：信息空间、事件与见闻','为 LLM 装上“手脚”：24 小时计划与局部修订','分层记忆：短期记忆、长期记忆与根本人设','自动化执行：寻路、避障、进门排队与索敌']],['游戏创意',['守城压力强化目标感','围绕守城，让对话具有实际意义','情绪表达与交互反馈增强趣味性','经营系统与 AI NPC 双向影响，丰富策略性','以人员管理强化“管理者”幻想']],['核心玩法',['对话征召：说服平民入伍','士气与逃离：鼓舞成员，挽留逃兵','劳动力调配：争取配合，安排生产与防守','经营与防守：分配资源，组织防线','记忆与关系：了解人物经历，调整管理策略']]];
function text(s,t,x,y,w,h,size,color,bold=false){const a=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none'}});a.text=t;a.text.style={typeface:'Microsoft YaHei',fontSize:size,color,bold,autoFit:'none'};}
for(let i=0;i<groups.length;i++){const [title,items]=groups[i];const s=P.slides.add();s.background.fill='#172B27';text(s,'章节概览',60,36,300,32,18,'#D5AA67');text(s,title,60,95,1140,88,58,'#F7F1E6',true);items.forEach((t,j)=>{const y=227+j*76;text(s,String(j+1).padStart(2,'0'),64,y,95,48,27,'#D5AA67',true);text(s,t,151,y,1063,55,29,'#F7F1E6');});text(s,'这不是我的战争',60,681,500,26,14,'#B9C4B8');text(s,title+'概览',1030,681,220,26,14,'#D5AA67');const png=await P.export({slide:s,format:'png',scale:1});await fs.writeFile(base+'/summary_'+(i+1)+'.png',new Uint8Array(await png.arrayBuffer()));}
await(await PresentationFile.exportPptx(P)).save(base+'/section_summaries.pptx');
