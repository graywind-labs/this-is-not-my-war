import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createCanvas} from '@napi-rs/canvas';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const skill='C:/Users/JT/.codex/plugins/cache/openai-primary-runtime/presentations/26.909.12148/skills/presentations';
const source=await fs.readFile(base+'/build/approved_script.md','utf8');
const section=(h,next)=>source.slice(source.indexOf(h),next?source.indexOf(next,source.indexOf(h)+h.length):undefined);
const pres=Presentation.create({slideSize:{width:1280,height:720}});
const ink='#F3EBDD',gold='#D5AB67',muted='#B7B1A7',bg='#19211F';
function wrap(t,w,size){const c=createCanvas(10,10).getContext('2d');c.font=size+'px Microsoft YaHei';return t.split('\n').map(p=>{let lines=[],line='';for(const ch of p){if(c.measureText(line+ch).width>w-30 && line && !'，。、；：！？）”’.'.includes(ch)){lines.push(line);line=ch;}else line+=ch;}lines.push(line);return lines.join('\n');}).join('\n');}
function text(s,t,x,y,w,h,size=27,color=ink,bold=false){const a=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});a.text=wrap(t,w,size);a.text.style={typeface:'Microsoft YaHei',fontSize:size,color,bold,autoFit:'none'};return a;}
async function photo(s,name,x,y,w,h){s.images.add({blob:new Uint8Array(await fs.readFile(base+'/screenshots/'+name)),contentType:'image/png',alt:name,fit:'contain',position:{left:x,top:y,width:w,height:h}});}
function placeholder(s,id,caption){const box=s.shapes.add({geometry:'rect',position:{left:670,top:202,width:546,height:350},fill:'#242E29',line:{fill:'#687766',width:1}});text(s,'待补截图  '+id,710,290,460,40,25,gold);text(s,caption,710,345,460,130,23,muted);}
async function slide(title,rows,opts={}){let s=pres.slides.add();s.background.fill=bg;text(s,title,64,48,1152,84,42,ink,true);let n=pres.slides.items.length;text(s,String(n).padStart(2,'0'),1164,658,52,28,18,muted);let w=opts.full?1152:548;let start=170;let gap=opts.gap??162;for(let i=0;i<rows.length;i++){let [head,body]=rows[i];text(s,head,64,start+i*gap,w,43,27,gold,true);text(s,body,64,start+47+i*gap,w,gap-48,25,ink);}if(opts.photo)await photo(s,opts.photo,670,190,546,370);if(opts.ph)placeholder(s,opts.ph[0],opts.ph[1]);if(opts.caption)text(s,opts.caption,680,578,520,56,18,muted);s.speakerNotes.textFrame.setText((opts.notes??'')+'\n来源：docs/PROJECT_SUBMISSION.md 用户确认定稿脚本。\n'+(opts.asset??'配图占位按用户要求保留。'));return s;}
let s=pres.slides.add();s.background.fill=bg;
text(s,'这不是我的战争',64,96,1152,96,64,ink,true);
text(s,'叙事重构·AI沙盒与涌现式世界',68,214,1100,50,28,gold);
await photo(s,'01_station.png',592,300,624,352);
text(s,'玩家扮演一个边境驿站\n征兵官，想办法说服平民\n上战场、”鼓励”他们干活、\n不让他们当逃兵。',68,352,464,250,32,ink);
s.speakerNotes.textFrame.setText(section('### 1. 产品定位','### 2.')+'\n配图：01_station.png，当前正式工程截图。拍摄时暂停时间、隐藏 UI，调整观景镜头。');
await slide('产品定位',[['玩法定位','用AI NPC来增强模拟经营游戏里”人员管理“的乐趣，实质上是AI小镇的一种。'],['所选赛道','叙事重构 ai沙盒与涌现式世界']],{photo:'03_npc.png',caption:'布鲁诺人物面板：身份、技能、需求与入伍状态',notes:section('### 1. 产品定位','### 2.'),gap:188,asset:'03_npc.png，正式人物面板实机截图。'});
await slide('美术、题材与叙事定位',[['美术定位','低模3D玩具风，轻量化而不廉价'],['题材定位','西欧中世纪文艺复兴时期，参考1444年的西班牙地区'],['叙事定位','无厘头黑色幽默表层+小人物的悲剧内核，从一个独特的视角看置身于战争中的普通人']],{photo:'02_gate.png',notes:section('### 1. 产品定位','### 2.'),asset:'02_gate.png，正式工程站内与城门实机截图。'});
await slide('为 LLM 装上“眼睛”',[['建筑的信息空间','将建筑内的人员、设施和状态转化为 LLM 能够理解的信息。'],['状态与变化','进入建筑时获取当前状态，空间内发生变化时接收相应信息。'],['有依据的判断','经营决策进入 NPC 的认知，不同人物保留各自的信息差。']],{photo:'05_building.png',caption:'铁匠铺面板：建筑、制造与工位信息',asset:'05_building.png，当前全屏建筑面板截图。',notes:section('#### 2.1','#### 2.2')});
await slide('事件、广播与见闻',[['按公开程度传播','私有事件保留给亲历者，同空间事件传递给在场者，驿站公开事件向全站广播。'],['统一短期记忆','玩家与 AI、AI 与 AI 的对话，与经营和战斗经历共同进入这套系统。'],['亲历与获知分开','事件库记录亲历，见闻库记录获知的信息。睡眠、昏迷等状态限制接收。']],{ph:['B','同一事件在亲历者事件库\n与在场者见闻库中的记录'],notes:section('#### 2.1','#### 2.2')});
await slide('为 LLM 装上“手脚”',[['24 小时完整计划','计划阶段披露可执行行动，跨天生成新一天的完整计划，再由程序执行。'],['失败后局部修订','先评估需要修改哪些小时，再填充选中时段的新计划，保留其他安排。'],['关键节点判断','战时交互、残血、疲劳或饥饿临界点按规则调用 LLM，兼顾成本与灵活性。']],{photo:'04_plan.png',caption:'计划界面示例。图中为第一日预设，跨天计划由 LLM 生成。',notes:section('#### 2.2','#### 2.3'),asset:'04_plan.png，第一日预设计划界面，只展示计划结构，不作为真实生成效果证据。'});
await slide('分层记忆',[['短期记忆','事件库与见闻库统一记录亲历、对话与获知的信息，压缩重复内容并保留关键结果。'],['长期记忆','每日睡眠反思形成玩家可见的日记与知识图谱，积累个人经历与对世界的认识。'],['根本人设','职业背景、性格、价值取向与基本诉求，为变化的经历提供稳定参照。']],{ph:['C','有真实经历的日记与知识图谱\n推荐选同一个 NPC 的两种视图'],notes:section('#### 2.3','#### 2.4')});
await slide('自动化的行动执行',[['寻路与避障','计划目标转换为工位与空间路线，导航网格结合 RVO 和实体碰撞执行移动。'],['进门排队','按到达顺序分配通行令牌，队首通行，其他人保留行动与预约等待。'],['索敌与战斗','程序按行为模式、目标优先级、距离与可达性选取目标，按武器射程衔接攻击。']],{ph:['D','建筑门口的排队现场\n或接敌时的自动移动与攻击'],notes:section('#### 2.4','### 3.')});
await slide('守城压力与对话目标',[['守城压力强化目标感','敌袭迫近，玩家需要争取人手、组织生产并准备防线，围绕守住驿站持续决策。'],['对话具有实际意义','征召士兵、防止逃跑、鼓舞士气、调配劳动力。人物顾虑与局势变化决定交涉方式。']],{ph:['E','敌袭预告与防守现场\n保留能体现生存压力的 HUD'],gap:205,notes:section('#### 3.1','#### 3.3')});
await slide('情绪表达与交互反馈',[['NPC 的情绪表达','动作、语气音效和 emoji 配合回复，让玩家直观感知人物态度。'],['玩家的语音与情绪','语音输入同时识别语言和情绪，经玩家确认后进入对话，让表达方式参与交互。']],{ph:['F','带情绪动作与 emoji 的真实回复\n或带情绪描述的语音识别草稿'],gap:205,notes:section('#### 3.3','#### 3.4')});
await slide('涌现性与“管理者”幻想',[['双向影响丰富策略','经营决策经事件系统进入 NPC 认知。人物结合性格、状态与记忆作出的选择，再影响玩家安排。'],['人员管理构成核心体验','征召平民、“鼓励”干活、鼓舞士气、防止逃跑。争取配合，根据战斗结果验证管理成果、调整管理方式。']],{ph:['G','一项经营安排与人物回应\n用同一实际过程表现双向影响'],gap:205,notes:section('#### 3.4','### 4.')});
const gameplay=[
['对话征召','#### 4.1','#### 4.2',[['玩家操作','点选 NPC，查看职业、状态和经历，通过文字或语音交谈，针对顾虑争取入伍。'],['系统反馈','人设、记忆与情境影响回应，态度表现与应征结果帮助玩家调整交涉。'],['策略意义','开局只有副官艾达已入伍。选择动员对象、话术和投入精力，构成人员管理的第一层决策。']],['H','一段具有代表性的真实征召对话\n需同时看到说辞、回应与应征结果']],
['士气与逃离','#### 4.2','#### 4.3',[['玩家操作','观察战时状态，交谈以鼓舞、安抚或施压，出现逃离意向时尝试挽留。'],['系统反馈','NPC 可能受到鼓舞，也可能动摇或坚持逃离，交涉结果与后续行为共同提供反馈。'],['策略意义','征召后仍需维护队伍。战前承诺与战场现实进入同一判断上下文，人员退出会削弱防线。']],['I','真实战场动摇或逃离挽留\n展示玩家输入、回应与人物状态']],
['劳动力调配','#### 4.3','#### 4.4',[['玩家操作','观察日程、技能、饥饿和疲劳，通过对话、自然语言指令、公告牌与日程表达安排。'],['系统反馈','NPC 结合指令、状态与记忆制定或修订计划，玩家从行动和生产结果判断落实情况。'],['策略意义','生产、训练、治疗与防守竞争同一批人手。入伍后仍有自主性，施加影响始终需要说服。']],['J','劳动指令与实际日程或行动\n保留人物需求与工作状态']],
['经营与防守','#### 4.4','#### 4.5',[['玩家操作','制造与交易物资、修复升级建筑、分配装备与坐骑、部署器械并拉响警铃。'],['系统反馈','资源、生产、建筑状态呈现经营结果，自动战斗验证防守效果，昏迷者等待治疗或恢复。'],['策略意义','人手、装备、生活保障和设施共同决定守城结果。经营驱动动员，人员选择作用于经营与防守。']],['K','装备、器械部署或实际守城战\n选能看清人物与设施协作的画面']],
['记忆与关系 UI','#### 4.5','### 5.',[['玩家操作','查看事件、见闻、日记与知识图谱，了解人物经历，据此调整对话与安排。'],['系统反馈','对话与经营决策进入记忆，公开事件传播，反思形成日记与知识图谱并参与后续判断。'],['策略意义','征召、劳动和战斗累积为个人经历。人员管理具有连续性，也呈现普通人眼中的战争荒诞性。']],['L','与具体管理经历相关的记忆页面\n推荐与征召或战时挽留使用同一人物']]
];
for(const [title,h,end,rows,ph] of gameplay)await slide(title,rows,{ph,notes:section(h,end)});
await fs.mkdir(base+'/build/rendered',{recursive:true});
await (await PresentationFile.exportPptx(pres)).save(base+'/build/candidate.pptx');
for(let i=0;i<pres.slides.items.length;i++){let sl=pres.slides.items[i];let png=await pres.export({slide:sl,format:'png',scale:1});await fs.writeFile(base+'/build/rendered/'+String(i+1).padStart(2,'0')+'.png',new Uint8Array(await png.arrayBuffer()));console.log('rendered',i+1);}
const {finalizePresentation}=await import(pathToFileURL(skill+'/container_tools/artifact_tool_utils.mjs').href);
let result=await finalizePresentation({workspaceDir:base,candidatePath:base+'/build/candidate.pptx',finalPath:base+'/output/这不是我的战争_项目介绍_v1_ready.pptx',pythonExecutable:'C:/Users/JT/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:skill+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:skill+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit'],fontPolicy:{basis:'design',families:['Microsoft YaHei']},requiredNativeTableOwnerSlides:[],requiredNativeChartOwnerSlides:[],verifyArtifactToolImport:true,receiptPath:base+'/build/validation_ready.json'});
console.log(JSON.stringify(result));
