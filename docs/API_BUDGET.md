# API_BUDGET.md

## T0308 特殊互动 Prompt 稳定性成本

成品路径不新增 endpoint、`call_type`、重试或二次判定；四个 toggle 仍最多开启一个，关闭时不加载模块，开启后仍只使用本轮一次 `/npc/dialogue`。新增文字只提高单次动态 Prompt 长度。

2026-09-01 使用 DeepSeek `deepseek-v4-flash`、temperature 0、`LLM_FALLBACK_TO_MOCK=false` 进行同一 14-probe 矩阵重复迭代。可精确汇总的三轮四重复与最初两重复共 196 次真实调用、1,493,938 input / 20,243 output tokens、估算 ¥0.18606944；另有 2 次请求没有可恢复的精确 usage：1 次在验证脚本记录组装错误后、usage 快照前中断，1 次为最终士气 escape 可达性保护检查。两次都确认真实 provider 成功，但不估造 token / 费用，也未混入上述账目。最终保留矩阵为 56 次、428,244 input / 5,577 output tokens、估算 ¥0.04940504，56/56 成功且 0 fallback。

## T0307 四类特殊互动真实验收成本

2026-09-01 使用 `backend/.env` 的 DeepSeek `deepseek-v4-flash`，强制 `LLM_FALLBACK_TO_MOCK=false`。最终可复放审计保存 29 次 `/npc/dialogue`：0 失败、0 fallback，估算 ¥0.014049；其中大量 Prompt token 命中 provider cache。为寻找不依赖单一关键词且能在正式人设中稳定到达的输入，本轮完整探索窗口实际产生 169 次 provider attempt，append-only 账本合计 1,236,614 input tokens、18,532 output tokens、1,061,632 cache-hit prompt tokens、174,982 cache-miss prompt tokens，估算 ¥0.233279。

T0307 不修改成品调用频率：toggle 关闭仍不附加对应模块，打开仍只复用本轮一次 `/npc/dialogue`。新增 `--resume-passed` 仅用于开发验收，复用审计中已经通过的响应并只调用未通过 case，避免因模型非确定性反复重跑完整矩阵；Godot 响应复放、事件 / 见闻和记忆压缩检查全部为本地 0 调用。

## T0306 高频战斗记忆压缩成本

本任务不新增 endpoint、`call_type`、请求频率、重试或输出字段。五类高频战斗事件在 Godot 供应商投影前按严格语义键合并；测试夹具每类 4 条（3 条同键、1 条异键）均变为 2 条，其他事件不变。实际节省量取决于一段连续交战中相同攻击者 / 目标 / 武器或相同伤害来源的重复次数；聚合元数据会占少量固定字符，但重复越多收益越高。当前环境没有 `OPENAI_API_KEY / DEEPSEEK_API_KEY / LLM_API_KEY`，本轮真实调用与费用均为 0。

本轮从正式数据定义读取专名后的同一夹具，在“逐条紧凑投影 → 聚合投影”的 JSON 字符数分别为：`attack_made 2178→1383`、`damage_taken 1320→963`、`building_damaged 964→774`、`defense_device_triggered 1381→989`、`horse_damaged 1244→919`；这是专项数据而非整次 Prompt token 账单。

## T0299 事件语义降噪成本

本任务只调整 Godot 本地事件写入与确定性摘要，不修改 Prompt、Schema、endpoint、provider、重试或调用次数。专项和运行态验收不发起 LLM 请求，真实 API 调用为 0；移除模式事件还会减少后续对话 / 计划 payload 中的冗余记忆文本。

## T0296 情绪气泡几何调整成本

本任务只删除 Godot 世界背景 Mesh 并调整人物框 Polygon2D 尾巴，不修改 Prompt、Schema、endpoint、provider、重试或调用次数。自动化与 Godot MCP 验收真实 API 调用为 0；删除世界背景 Mesh 还减少了每个 NPC 情绪节点的一份网格和材质实例。

## T0295 暂停情绪动作成本

本任务只调整 Godot 本地 AnimationPlayer 和临时表现计时的暂停边界，不修改 Prompt、Schema、endpoint、provider、重试或调用次数。暂停时对话仍沿既有每轮请求，不会因动画豁免产生额外请求；自动化与 Godot MCP 验收真实 API 调用为 0。

## T0294 情绪气泡视觉修复成本

本任务只修改 Godot 本地 Emoji 绘制方式和人物框气泡布局，不修改 Prompt、Schema、endpoint、provider、重试或调用次数。GM 预览、自动化和 Godot MCP 验收均不调用供应商，真实 API 调用为 0；世界 SubViewport 只在 Emoji 变化时刷新一次，不产生持续远程或渲染请求。

## T0293 对话情绪同步动作成本

本任务只让既有 `happy / angry` 结构化情绪在 Godot 本地同步触发临时动作，并撤下错误思考试片；不修改 Prompt、Schema、endpoint、provider、重试或成功路径调用次数。自动化和 Godot MCP 验收不调用供应商，真实 API 调用为 0。

## T0291 战时对话并行调用边界

本任务只调整Godot客户端的会话 / 战斗状态所有权，不修改 Prompt、Schema、endpoint、`call_type`、重试或每轮调用次数。战斗模式切换不再取消已经在途的玩家对话请求，但不会额外发起请求；后续轮次继续沿既有一次 `/npc/dialogue` 合同读取最新战局上下文。本地 HTTP Mock 用于通信回归，真实供应商调用为 0，无新增 token 或费用。

## T0289 对话情绪字段成本

本任务不新增 endpoint、`call_type`、触发次数或重试；每次既有 `/npc/dialogue` 只增加一个短枚举选择规则，输出继续使用原有 `emotion` 字段，因此调用次数不变、输出 token 增量接近 0。Mock / 本地表现验收不调用真实供应商。2026-08-31 检查进程环境与项目 `.env` 均未发现可用 API Key，故没有真实 provider 调用、token 或费用可记录，T0289 保持 Partial。

## T0285 工作鼓励与四类动态模块（Mock 阶段）

本任务不新增 endpoint、call_type、重试或二次判定，仍复用每轮一次 `/npc/dialogue`。四个特殊 toggle 最多开启一个；关闭时不把对应判断 Prompt / 输出字段加入 provider 请求，工作开启时仅增加一个三值字段，不增加调用次数。GM 与自动化使用 `LLM_PROVIDER=mock`，真实供应商调用为 0、费用为 0；用户确认交互后再单独记录真实 API 验收与 usage。

## T0284 策略 toggle 调用边界（Mock 阶段）

本任务不新增 endpoint 或 call_type，仍复用每轮一次 `/npc/dialogue`。toggle 关闭时不向 provider 发送策略上下文，也不把 `combat_strategy_decision` 加入动态输出合同；开启时只在同一请求增加当前策略、合法候选和一个保持 / 切换结构，不增加调用次数、重试或二次判断。自动化及 GM 使用显式 Mock，本阶段真实供应商调用为 0、费用为 0；用户确认交互后再单独做真实 API 验收并记录 usage。

## T0283 鼓舞 toggle 调用边界（Mock 阶段）

本任务不新增 endpoint 或 call_type，仍复用每轮一次 `/npc/dialogue`。toggle 关闭时不把 `wartime_reaction` 放入 provider 动态输出合同；开启时仅增加 `is_morale_encouragement_request` 与一个三值结构字段，不增加调用次数、重试或第二次判定。GM 与自动化均使用显式 `LLM_PROVIDER=mock`，本阶段真实供应商调用为 0、费用为 0；用户确认 Mock 交互后再单独记录真实 API 验收与 usage。

## T0254 攻击 / 对话事件分离调用边界

本任务不新增 endpoint、`call_type`、Prompt、Schema、重试或供应商调用。普通对话攻击仍沿既有 `/npc/dialogue` 请求一次 NPC 反应，逃离攻击仍为 0 次；变化只在 Godot 本地会话 history 与事件提交。纯攻击结束时不再发送空的对话判别，而是调用既有 `guard_attack` 计划重评估入口，因此不会为了伪对话额外消耗一次对话判别预算。本地 Mock / 生命周期回归不产生真实供应商调用，无需真实 provider 效果验收。

## T0251 建筑受损见闻字段调用边界

本任务只在 Godot 本地过滤受损建筑状态差量中的 `operational_efficiency`，不新增 endpoint、`call_type`、Prompt、Schema、重试或远程模型调用；本地回归产生 0 次供应商调用，无需真实 provider 验收。

## T0238 陨石坑淡化调用边界

本任务只修改 Godot 本地配置、逻辑时间表现状态和材质 Alpha，不新增 endpoint、`call_type`、Prompt / Schema、重试或远程 API 调用；专项、回归与 Godot MCP 验收产生 0 次供应商调用，无需真实 provider 验收。

## T0237 避战事件摘要调用边界

本任务只修改 Godot 本地确定性事件摘要模板与回归断言，不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或远程 API 调用；专项与 Godot MCP 验收产生 0 次供应商调用，无需真实 provider 验收。

## T0167 马匹毛色与取马路径调用边界

本任务只调整本地 JSON 毛色 / 空间合同及 Godot NavigationServer3D 路径验证，不新增 endpoint、Prompt、Schema、LLM 或远程 API 调用；专项和视觉验收产生 0 次供应商调用。

## T0166 GM 面板整理调用边界

本任务只调整 Godot 本地调试 UI 和回归脚本，不新增 endpoint、Prompt、Schema、LLM 或远程 API 调用；专项与回归产生 0 次供应商调用。

## T0165 陨石奇观表现

- 全部由 Godot 本地配置、程序网格、粒子与既有 CC0 岩石完成；不调用 LLM、图像生成或远程运行时 API，模型调用次数为 0。

## T0164 建筑名称渐隐调用边界

本任务只修改 Godot 本地 Label3D 与镜头运动采样，不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用。专项与视觉验收产生 0 次供应商调用。

## T0163 陨石自由落点调用边界

本任务只移除 Godot 本地落点矩形校验，不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用。专项及回归产生 0 次供应商调用，无需真实 provider 验收。

## T0162 马匹身份、槽位与面板调用边界

本任务只新增 Godot 本地马匹配置、权威状态、世界投影与 UI，不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用。名称和毛色来自本地有限模板池，不由模型生成；专项与回归产生 0 次供应商调用，无需真实 provider 验收。

## T0161 GM 一键征召配装调用边界

本任务只调用 Godot 本地 NPC、库存、装备和马匹接口，不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用。GM 调试征召不会请求或伪造 NPC 对话接受，因此专项和回归产生 0 次供应商调用，无需真实 provider 验收。

## T0130-P5R3 艾达档案外貌同步验收成本

本任务只替换既有 `npc_setting.appearance` 的内容，不新增 Prompt / Schema 字段、endpoint、重试或成品调用次数。先通过本地共享档案专项与 Mock 对话适配器；因环境已有真实 Key，2026-08-21 又运行 8 名 NPC 的正式 `/npc/dialogue` smoke：DeepSeek `deepseek-v4-flash` 共 8 次，全部成功且 `fallback_used=false`，艾达更新后的外貌字段随既有载荷正常进入请求。该旧 smoke 脚本只输出调用数、provider、model 与 fallback 汇总，未持久化本轮 token 合计；不据此虚构费用数字。

## T0129C-A5-P6d-3 正式治疗接近调用边界

本任务不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用次数。目标投影、NavigationAgent / RVO 接近、到位扣费、helper / HP / 经验结算和清理均为本地权威逻辑，产生 0 次模型调用；既有完成后计划重估调用合同未改变，因此无需新增真实 provider 验收费用。

## T0129C-A5-P6d-2 正式升级协助调用边界

本任务不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用次数。施工槽选择、NavigationAgent / RVO 移动、到位提交、upgrade helper 清理和升级倒计时均为本地权威逻辑，产生 0 次模型调用；既有完成后计划重估调用合同未改变，因此无需新增真实 provider 验收费用。

## T0129C-A5-P6d-1 正式修复协助调用边界

本任务不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或模型调用次数。维修槽选择、NavigationAgent / RVO 移动、到位提交、helper 清理和修复进度均为本地权威逻辑，产生 0 次模型调用；因此无需新增真实 provider 验收费用。

## T0129C-A5-P6c 正式实体接近调用边界

本任务不新增 endpoint、`call_type`、Prompt / Schema 字段、重试或成功路径调用次数。日计划 `talk_to_npc` 仍先发生既有 1 次 `dialogue_intent_revalidation`，实体赶路、RVO 接近、目标重定向和等待工位均为 0 次模型调用；进入合法距离后才按既有合同发起 1 次 NPC-NPC 邀请。由于没有修改模型输入输出效果，本轮使用确定性非 Mock 测试桥验证邀请接受链，没有新增真实 provider 验收费用。

## T0120 NPC 可见文案润色真实 smoke

本任务不改 Prompt、Schema、调用频率或行为规则，六份 Prompt hash 与 T0119 最终真实验收一致，因此未重跑 180 次完整行为矩阵。按 LLM 内容任务验收规则，2026-08-10 补跑 1 次莉娜 `/npc/daily_reflection`：DeepSeek `deepseek-v4-flash` 首次成功，5,117 input / 642 output tokens，估算 ¥0.00150884，`fallback_used=false`。结果继续正确记录诊所升级、皮甲 / 弓和后方医疗职责已经落实，并只把十份酒视作礼数，不替代医疗安排。

## T0119 征募与逃离真实验收成本

2026-08-10 在自动 Mock fallback 关闭的正式路径上，使用 DeepSeek `deepseek-v4-flash` 保存改动前基线并运行最终四套行为矩阵：

| 阶段 | 调用 | input tokens | output tokens | 估算费用 |
|---|---:|---:|---:|---:|
| 改动前基线 | 24 | 240,748 | 5,485 | ¥0.10620760 |
| 最终征募矩阵 | 86 | 1,009,685 | 9,998 | ¥0.19951908 |
| 最终日计划逃离矩阵 | 32 | 346,080 | 18,484 | ¥0.15863584 |
| 最终战时心理矩阵 | 32 | 288,432 | 3,074 | ¥0.22069584 |
| 最终逃离挽留矩阵 | 30 | 370,152 | 3,421 | ¥0.12335432 |

最终四套矩阵合计 180 次，2,014,349 input / 34,977 output tokens，估算 ¥0.70220508；180 / 180 HTTP 与真实 provider 成功，全部 `fallback_used=false`。基线与最终原始输入输出、request id、call type、NPC、场景、token、费用和 Prompt hash 保存在 `docs/audits/T0119_NPC_RECRUITMENT_ESCAPE/`，不含 API Key 或请求头。另行通过计划范围判别、正式修订和熟睡反思真实回归；这些辅助调用不计入上表 180 次正式矩阵。

## T0116 对话意图执行前复核

- 每个实际开始执行的 `talk_to_npc / seek_guard_officer` 计划阶段最多增加 1 次正式 `dialogue_intent_revalidation`；同一日 / 小时 / 计划版本 / 计划项在途去重，迟到结果不重放。
- 只有业务响应自相矛盾时才允许同一真实 provider 纠错 1 次；无 Key、超时、HTTP / JSON / Schema 失败不转 Mock，而是进入当前小时计划重估。
- 2026-07-30 最终真实 DeepSeek 三分支验收：3 次成功，11,424 input / 263 output tokens，估算 ¥0.00342008，continue / modify / cancel_and_replan 各 1 次，全部 `fallback_used=false`。Prompt 调试期间的失败 / 探索请求仍保留在 LLM 审计账本中。

## T0115 主动交涉竞态修复与验证成本

本任务不新增 endpoint、`call_type`、Prompt 字段或正常业务触发。`failed_action_repeated` 在 Godot 落地前使用既有 stage-two 最多 3 次重试；与旧错误路径相比，它不再先应用必败项并由状态监听器另开一轮 `plan_revision_judgement + revise_plan`。主动交涉点击、草稿回滚、移动 start result 和陈旧失败隔离均为本地状态操作。

本地先通过后端 Mock / Schema 与 Godot 确定性回归，再用 DeepSeek `deepseek-v4-flash`、显式禁止 Mock fallback 跑 2 次 `/npc/revise_plan`，均首次成功：13,869 input / 238 output tokens，估算 ¥0.01120900。

验证期间另有两个应计副作用：既有 `verify_daily_plan_reevaluation.gd` 未完全隔离当前真实后端，触发 1 次 `plan_revision_judgement` 与 1 次 `revise_plan`；Godot MCP 冻结启动 `Main.tscn` 仍会执行 `_ready` 的开局计划批次，触发 8 次 `plan_day`。连同正式修订验收，本任务时段共 12 次真实调用，224,388 input / 5,996 output tokens，估算 ¥0.06101488，全部成功且 `fallback_used=false`。这些是开发验证成本，不改变成品频率；后续 MCP 运行时复现应先隔离后端或关闭启动批次，不能把 frozen 当作 `_ready` 隔离。

## T0113 对话权威实况验收成本

本任务不新增 endpoint、`call_type` 或正常对话调用频率，只在既有 `/npc/dialogue` 输入中增加三个很小的事实对象；单次增量远小于人物记忆与行动目录。正式请求仍受每日 ¥20、单次 ¥0.05 在途预留和禁止自动 Mock fallback 约束。

真实验证使用 DeepSeek `deepseek-v4-flash` 复放问题发生时约 35k input token 的两份格伦审计上下文。最终用于判断效果的 4 次 Model Adapter 复放与 1 次完整 endpoint 验收均成功、`fallback_used=false`。开发过程另有 1 次在打印结果时触发本地脚本属性错误后的重复调用，以及 1 次因把供应商压缩版审计 payload 直接回灌 endpoint、缺少重复轮次字段而在模型成功后触发业务校验失败；随后补回审计中被压缩的重复字段并通过。账本共记录 7 次供应商调用，247,019 input / 738 output tokens，估算 ¥0.10185564；这些都属于开发验收，不改变成品调用频率。

## T0107 战斗基础与 Prompt 隔离验收成本

本任务的战斗属性、塔防槽位、器械 HP、敌群、远程距离与骑兵冲击均在 Godot 程序侧结算，不新增 endpoint、`call_type`、正常业务模型触发或 Prompt 字段。由于运行时装备槽会保存完整配置副本，LLMBridge 在既有装备上下文上增加旧字段白名单投影，明确剔除防御、穿透、攻速修正和 `charge_*` 等新战斗配置，避免它们进入六类 NPC Prompt。

本地 `verify_dialogue_prompt.py` mock 与 T0107 Godot payload 边界均通过。按项目真实验收规则，使用 DeepSeek `deepseek-v4-flash`、temperature 0、显式关闭 fallback 运行既有对话业务矩阵 8 次；8 次全部成功且 `fallback_used=false`。持久化成本账本记录合计 50,115 input / 733 output tokens，估算 ¥0.02272980。该费用只属于开发验收，不改变成品调用频率、每日 ¥20 门禁、单次 ¥0.05 在途预留或真实失败关闭规则。

## T0106 全量紧凑短期记忆的成本边界

本任务不新增 endpoint、`call_type` 或调用频率；只把普通五类调用的亲历 / 见闻从“各最后 8 条”改为当前短期索引全部记录，并让熟睡总结使用唯一的全量紧凑 `day_events`。因此增量成本与一次总结窗口内尚未轮转的事件数量线性相关，不会跨成功总结无限累积。

程序不传原始事件对象。专项 Godot 夹具中 13 条亲历 + 15 条见闻的权威结构为 15,275 字符，模型投影为 5,372 字符，减少约 64.8%。真实因果夹具的 13 + 13 条紧凑记忆为 2,897 字符；若沿用旧的各最后 8 条则为 1,611 字符，本次全量多 1,286 字符，约相当于 300–400 个粗估输入 token。实际供应商总输入还包含固定系统 Prompt、人物、驿站和行动目录，因此不能把这 1,286 字符直接当作整次调用倍数。

真实 DeepSeek `deepseek-v4-flash` 验收 1 次，关键缺铁事件位于第 1 条，之后各有 12 条记录且当前库存为 20。调用首次成功、`fallback_used=false`，usage 为 7,403 input / 81 output tokens，估算 ¥0.00643604；回复正确区分“当时铁料不足”和“后来库存变化”。熟睡总结删除重复的 `npc.short_term_memory` 后，反思请求不会因本次全量策略把同一批事件计算两次。

## T0105B 弥撒跨小时完成优先的调用边界

本任务只调整 Godot 本地行动计时与计划派发，不新增 endpoint、`call_type`、Prompt、模型字段或正常业务调用。跨小时等待、弥撒结束后的当前计划接管都使用已有运行态和已经生成的日计划，不触发失败型计划重估。

专项测试在 `Main.tscn` 加入场景树前关闭自动计划执行，并把测试用后端地址指向不可用的本地端口，避免开局计划和熟睡总结触发真实供应商。三次完整专项均通过，测试前后持久化 API 账本长度不变，本任务实际 provider 调用为 0。T0105A 历史验证成本保留如下，不归入本任务。

## T0105A 弥撒结束语义与验证成本

运行时分流完全发生在 Godot，不新增 endpoint、`call_type`、Prompt、正常业务模型调用或弥撒结束后的计划重估。自然完成由 ActionSystem 本地结算；当时实现的计划小时边界完成路径已由 T0105B 取代，外部中断同样不调用模型。

开发验证中，若干会实例化 `Main.tscn` 的既有回归没有隔离当前真实后端，产生 8 次熟睡总结和 8 次开局日计划；随后临时让专项通过完整 `_on_hour_started` 自动派发全部 NPC，又让园丁的既有完成后重估监听产生 1 次 `revise_plan`。DeepSeek `deepseek-v4-flash` 共 17 次调用，全部首次成功且 `fallback_used=false`：

- `daily_reflection` 8 次：939,003 input / 4,383 output tokens，估算 ¥0.947769。
- `plan_day` 8 次：168,953 input / 5,342 output tokens，估算 ¥0.13435316。
- `revise_plan` 1 次：25,715 input / 101 output tokens，估算 ¥0.02566612；request id 为 `godot_revise_plan_2139_0003`。
- 合计：1,133,671 input / 9,826 output tokens，估算 ¥1.10778828。

发现后，小时边界专项恢复为隔离调用同一计划派发入口并显式传入边界，不再开启全局自动执行；本任务也不再运行会触发正式开局 / 反思批次的夹具。这些均为测试副作用，不是功能新增成本；每日 ¥20 门禁、单次 ¥0.05 在途预留和禁止自动 Mock fallback 均不变。

## T0103 NPC-NPC 防复述真实验收

本任务不新增 endpoint、`call_type` 或正常业务调用次数；通过更早返回 `should_end_dialogue=true`，已解决话题会减少后续逐轮 `/npc/dialogue` 调用。`max_rounds=0` 与必要事项可继续的成本边界不变。

Mock / Schema / Godot 回归后，使用 DeepSeek `deepseek-v4-flash`、显式关闭 fallback 复验邀请接受 / 拒绝、第 6 轮兜底和四组已解决话题。最终四组均当轮结束，文本最高相似度 0.254～0.571，无逐字或高相似复述。Prompt 迭代共发生 19 次实际 provider 调用：117,347 input / 1,460 output tokens，估算 ¥0.04851532；19 次供应商调用全部成功且 `fallback_used=false`。其中两次本地后置断言失败分别用于发现旧拒绝夹具语境不成立、模型会自行添加后续安排，不属于 provider 失败。

## T0101 守备官背景真实对话验收

- provider / model：DeepSeek `deepseek-v4-flash`，显式 `LLM_FALLBACK_TO_MOCK=false`、temperature 0。
- 最终三问分别验证：身份过去未知；三年前来到驿站且来站前经历未知；开局前三年只概括尽责、和睦、无可确认具体旧事，并转回当前食堂事务。最终 3 次均首次成功、`fallback_used=false`。
- 为接受“没提过 / 没跟我说过”等合规自然同义表达，并从“未编重大剧情”继续收紧到“不得顺手补日常例子 / 引语”，本任务累计发生 16 次实际 provider 调用。16 次供应商调用全部成功、无 fallback；部分早期运行只在本地后置语义断言失败，不是 provider 失败。
- 累计 usage：154,937 input / 1,916 output tokens，估算 ¥0.07873828。

## T0100 宗教信仰字段与验收成本

本任务只为既有人设增加一个短 `religion` 字符串及六份 Prompt 的一句边界说明，不新增 endpoint、`call_type`、正常调用次数、触发条件或输出字段。每次人物上下文只增加“天主教”及字段名的少量输入；NPCPanel 显示与 Godot / Pydantic 投影均为本地操作。

基础 Schema、六份 Prompt、显式 Mock 与 Godot payload 验收通过后，使用真实 DeepSeek `deepseek-v4-flash` 逐人追问信仰和本职工作。最终 8 次正式验收全部首次成功且 `fallback_used=false`。首次托马调用也由 provider 成功返回“信天主”，但旧测试只接受精确“天主教”而后置失败；修正为接受等价世界内表达后重跑 8 人。两轮共 9 次实际 provider 尝试：51,791 input / 842 output tokens（cache hit 27,392 / miss 24,399），估算 ¥0.02663084。该费用属于开发验收，不改变成品频率；每日 ¥20 门禁、单次 ¥0.05 在途预留与禁止自动 Mock fallback 均不变。

## T0099 对话 UI 修改与验证成本

日期分组、Tab 快捷键和首次攻击确认全部发生在 Godot UI，本身不新增 endpoint、`call_type`、Prompt 字段或正常业务调用次数。对话确认成功后仍只走玩家主动触发的既有惩戒路径；取消确认不调用 LLM。

对话 UI 专项使用显式隔离的 `LLM_PROVIDER=mock` 后端。随后 Godot MCP 为实机输入和确认窗验证冻结启动 `Main.tscn`；冻结只停止玩法帧，不阻止 `_ready` 中正式开局计划批次，因此仍产生 8 次非预期真实 `plan_day`。DeepSeek `deepseek-v4-flash` 合计 166,408 input / 5,338 output tokens，估算 ¥0.16905584；8 次均首次成功，`fallback_used=false`。这属于验证副作用，不是 T0099 的运行时成本增量；每日 ¥20 门禁、单次 ¥0.05 在途预留、真实 usage 结算和禁止自动 Mock fallback 均未改变。

## T0098 合并祈祷 / 弥撒成本

运行时模式转换完全发生在 Godot，不新增 endpoint、`call_type` 或正常 LLM 次数；与旧设计相比，弥撒开始 / 结束不再触发 `plan_revision_judgement + revise_plan`，因此会减少教堂场景中的模型调用。Prompt 和候选也移除了一个独立行为及四类失败提示。

按项目规则先完成 Mock / endpoint 验收，再用真实 DeepSeek `deepseek-v4-flash` 验证 1 次日计划和 1 组对话承诺判别 + 正式修订，共 3 次调用：16,964 input / 790 output tokens，估算 ¥0.018544；全部首次成功且 `fallback_used=false`，计划只选择 `pray_at_chapel`。每日 ¥20 门禁、单次 ¥0.05 在途预留、真实 usage 结算和生产禁止自动 Mock fallback 均未改变。

## T0097 计划决策编译成本

本任务不新增 endpoint、`call_type` 或正常调用次数。计划项输出去除内部 kind、优先级、固定地点和通用目标回显，通常会减少输出 token；按行为字段清洗与编译完全在后端本地完成，不产生额外 LLM 调用。必要目标错误继续使用既有业务失败 / 正式修订纠错边界，不使用 Mock 伪装成功。

真实 DeepSeek `deepseek-v4-flash` 验收共 6 次：1 次完整日计划、2 组弥撒范围判别 + 正式修订、1 次 NPC 目标正式修订。合计 36,889 input / 1,089 output tokens，估算 ¥0.039067，全部首次成功且 `fallback_used=false`。原始模型计划项没有返回 `action_kind / priority / internal target`；升级协助使用 `building_id`，找 NPC 使用 `target_npc_id`，固定弥撒只返回 action。每日 ¥20 门禁、单次 ¥0.05 在途预留、真实 usage 结算和生产禁止自动 Mock fallback 均未改变。

## T0095/T0096 Pending 与熟睡总结水位成本

pending 生命周期修改完全发生在 Godot 权威模拟层，不新增 endpoint、`call_type` 或模型请求。熟睡总结继续使用既有 `/npc/daily_reflection`，每个 21:00 窗口仍最多成功一次；新增的 `summary_window / reflection_period` 是小型结构化边界，不增加正常调用次数。漏掉一晚不会补请求，下一次成功调用覆盖更长的未总结区间。

本轮先完成 Schema / Mock / endpoint 验收，再按项目规则使用真实 DeepSeek `deepseek-v4-flash` 验证一次更新后的 Prompt：4,528 input / 223 output tokens，总计 4,751 tokens，估算 ¥0.004974，首次成功且 `fallback_used=false`。Godot MCP 采用冻结帧启动，没有触发开局计划批次。每日 ¥20 门禁、单次 ¥0.05 在途预留、真实 usage 结算和禁止自动 Mock fallback 均未改变。

## T0094 对话实况、弥撒重估与夜间窗口成本（教堂调用已由 T0098 取消）

T0094 当时未新增 endpoint 或 `call_type`。睡眠打断实况只给既有 `/npc/dialogue` 增加一个短、可选的 `interrupted_activity_context`；当时弥撒开始和明确承诺使用既有判别 + 修订链。T0098 已取消弥撒开始 / 结束触发的失败重估，只保留明确对话承诺确实需要改变当前安排时的通用对话判别。21:00 夜间窗口只改变 Godot 调度 / 去重，不增加单个总结的 provider 调用数；同窗累计睡眠仍最多成功提交一次自动总结，失败保持真实错误并可重试。

本任务期间活动账本由 200 次 / ¥3.66845792 增至 225 次 / ¥3.78598564，共增加 25 次真实调用、434,333 input tokens、11,694 output tokens、估算 ¥0.11752772；最终每日剩余额度 ¥16.21401436。明细如下：

- 有意的语义验收 5 次：弥撒 active / 对话承诺各 1 次判别 + 1 次修订，以及睡眠打断对话 1 次；合计 30,336 input / 369 output tokens、¥0.02404936，全部首次成功且 `fallback_used=false`。
- 4 个 Godot 对话回归进程沿用了当前真实后端配置，产生 4 次非预期真实对话：68,593 input / 334 output tokens、¥0.06374164。调用均成功且无 fallback，但不属于功能常态新增成本。
- Godot MCP 两次普通主场景启动各触发 8 名 NPC 的开局 `plan_day`，共 16 次：335,404 input / 10,991 output tokens、¥0.02973672。调用用于运行态 UI 验收，不属于 T0094 正常业务增量。

以上记录均使用 DeepSeek `deepseek-v4-flash`，没有自动 Mock fallback，也未改变每日 ¥20 门禁、单次 ¥0.05 在途预留、真实 usage 结算或失败关闭规则。后续 UI / Godot 回归应显式隔离 Mock 后端或禁用正式启动批次，避免只读验收再次消耗真实额度。

## T0092 等价合同精简成本

本任务不新增 endpoint、`call_type` 或正常调用次数。压缩只发生在 provider 边界：Godot 业务请求和完整成功响应保持兼容，模型输入删除确定性重复内容，模型输出删除由后端可推导的字段。

`tools/verify_llm_contract_compaction.py` 使用六类同形 payload 计算紧凑 JSON 字符量。输入减少：对话 3.62%、日计划 7.77%、范围判别 11.49%、正式修订 8.29%、战时判定 5.61%、每日反思 6.88%。供应商输出相对完整稳定响应减少：48.00%、45.29%、41.67%、61.30%、28.84%、7.47%。字符比例只用于稳定回归，不等同于供应商 tokenizer。

真实 DeepSeek 同 request ID 前后对比提供 token 证据：

- 战时对话：5,998 → 5,656 input tokens（-5.70%），160 → 116 output tokens（-27.50%）。
- 行动失败范围判别：6,229 → 5,661 input tokens（-9.12%），140 → 85 output tokens（-39.29%）。

最终六类各取一个成功调用的 usage 合计为 31,048 input / 1,251 output tokens：对话 5,656 / 116、日计划 5,284 / 672、范围判别 5,661 / 85、正式修订 6,578 / 79、战时判定 3,866 / 90、每日反思 4,003 / 209；均 `fallback_used=false`。每日 ¥20 门禁、单次 ¥0.05 预留、真实 usage 结算和禁止自动 Mock fallback 均未改变。

## T0091 对话目标合同成本

`talk_to_npc` 候选不再重复传输每个目标 NPC 的 `location_id`，日计划与正式修订输入略微缩短；调用频率、两阶段重估边界、真实 provider、每日 ¥20 门禁和单次 ¥0.05 预留不变。模型若冗余返回地点由同一次 HTTP 响应确定性规范化，不为此新增业务纠错调用；真正的白名单外目标、错误 kind 或其他合同错误仍走原真实 provider 纠错边界，不进入 Mock。

本次目标路径真实验收使用 2 次 provider 调用：正式修订输入 7,025 / 输出 301 tokens、估算 ¥0.00674892；NPC-NPC 邀请输入 5,677 / 输出 141 tokens、估算 ¥0.00257212。合计 13,144 tokens、¥0.00932104，两次均首次成功且 `fallback_used=false`。

## T0090 开发期额度重置与请求预留校准

2026-07-28 清理前，上海自然日账本包含 347 次真实 provider 尝试，总估算 ¥6.58959012；平均单次 ¥0.01899017，中位数 ¥0.02087412，P90 ¥0.02695700，P95 ¥0.02998008，P99 ¥0.03258096，最大单次 ¥0.04262264。按 `call_type` 分组：`plan_day` 127 次、均值 ¥0.01719384、最大 ¥0.02558880；`revise_plan` 96 次、均值 ¥0.02131534、最大 ¥0.03198916；`plan_revision_judgement` 70 次、均值 ¥0.02216605、最大 ¥0.03118688；`dialogue` 54 次、均值 ¥0.01496437、最大 ¥0.04262264。

当前 Flash 开发配置的 `LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY` 从 ¥1.77 调整为 ¥0.05。新值约为总均值的 2.63 倍，高于截至清理前的实测最大值约 17%，并覆盖当时 P99；8 路开局计划的总在途预留从 ¥14.16 降为 ¥0.40。每日 ¥20 上限、按实际 provider usage 结算、账本故障失败关闭、HTTP 429 / `budget_exceeded` 和禁止自动 Mock fallback 的规则不变。

这是按当前 `deepseek-v4-flash`、现有 Prompt / 上下文规模和开发流量校准的工程预留，不再覆盖供应商声明的 1M 上下文与 384K 最大输出理论极端成本。如果模型、价格、Prompt、上下文规模变化，或滚动统计的 P99 / 最大值接近 ¥0.05，必须提高该值；DeepSeek 控制台账单仍是最终财务事实。

清理操作只移除活动账本中 `day=2026-07-28` 的 347 条记录，保留其他日期 23 条；清理前完整账本保存到 `backend/logs/archive/llm_cost_ledger.before_reset_2026-07-28.20260728-162413.jsonl`。配置变更后两次真实 DeepSeek 对话均完成 provider 结算、`fallback_used=false`，合计 ¥0.00327664；第一次只因本地验收脚本漏收“无从知晓”同义词而在业务成功后的文本断言失败，补充后第二次通过。两条验收记录保存到 `backend/logs/archive/llm_cost_ledger.before_final_reset_2026-07-28.20260728-162818.jsonl` 后再次从活动账本清除。该目录被 `.gitignore` 排除，仅供本地恢复，不作为版本库资产。

最终后端重启快照：provider=`deepseek`、model=`deepseek-v4-flash`、`fallback_to_mock=false`、`daily_limit_cny=20`、`request_reserve_cny=0.05`、`daily.attempt_count=0`、`daily.estimated_cost_cny=0`、`in_flight_reserved_cny=0`、`remaining_cny=20`。

## T0089 教堂失败替代倾向成本

本任务不新增 endpoint、`call_type` 或正常行动失败调用次数。教堂失败仍使用既有“1 次 `plan_revision_judgement`，判别非空后再 1 次 `revise_plan`”链；变化只是在 `failure_context` 增加一个短 `failure_id`，并用 Prompt 减少模型保留无效原计划或选中不符合原意行动的概率。

真实验收使用 DeepSeek `deepseek-v4-flash` 覆盖两个方向，各执行 1 次判别 + 1 次修订，共 4 次 provider 调用，全部首次成功、`fallback_used=false`。账本记录合计 25,724 输入 token、647 输出 token、估算 ¥0.02237672；这些调用仅属于开发验收，不改变每日 ¥20 持久化预算。

## T0087 对话合同拆分成本

本任务不新增 endpoint 或常态调用次数，只缩小每种 `/npc/dialogue` 的输出字段集合；输入 Prompt 增加当前 `dialogue_kind` 的精确字段提示，token 增量很小。非法旧字段直接记为 `model_output_invalid`，不会自动用 Mock 伪装成功。非权威元数据的 `null` 默认化不重试供应商，并通过 `model_normalizations` 留痕，因此不会增加调用。

正式合同验收共发生 19 次 DeepSeek `deepseek-v4-flash` 对话尝试（包含两次在调整测试断言 / 非权威空值兼容前中断的重跑），合计约 111,882 输入 token、2,779 输出 token、估算 ¥0.03678208；最终玩家 / NPC-NPC / 逃离和邀请分支均 `fallback_used=false`。此外，Godot UI 回归第一次启动后端时未显式覆盖 `.env`，意外让 4 个本应为 Mock 的测试请求走了真实 provider，额外约 97,284 输入 token、567 输出 token、¥0.09114248；发现后关闭该进程，后续本地合同仍使用显式 Mock。以上均为开发验收，不改变每日 ¥20 持久化预算。

## T0093/T0086 提前完成行动的连续段重估成本

五类 `reevaluate_current_hour_on_completion` 行动每次在原计划小时内成功完成时，新增 1 次正式 `call_type=revise_plan`，但不先调用 `plan_revision_judgement`；因此正常成本仍是“0 次范围判别 + 1 次修订”。T0093 后一次请求会覆盖当前小时起连续相同 action + target 的原计划段，不为每个小时分别调用。修订等待继续申请 TimeSystem 慢速，正式路径拒绝 Mock / fallback，失败沿既有最多 3 次真实尝试边界处理。完成时已经跨小时、计划项已经变化、NPC 不可行动 / 不在工作模式或行动不是日计划拥有时不产生该调用。

用户体验收益是避免协助、病床和饮酒在小时早段结束后长期空闲，并一次清理后续连续失效安排；代价是多小时修订的单次输出会略长。吃饭、睡觉、祈祷、弥撒、拜访、生产周期和持续服务未加入该标记，不会因本任务额外调用。T0093 真实验收新增 1 次三小时 `action_completed` 修订，DeepSeek `deepseek-v4-flash` 一次成功把 8–10 点改为 `work_clinic_doctor`，6,391 input / 142 output tokens，估算 ¥0.00378988，`fallback_used=false`；该开发验收不改变每日 20 元持久化预算。

## T0085 升级结束重估与无效重试成本

本任务不新增 endpoint 或 `call_type`。修复前，诊所升级结束后的 1 次范围判别虽然正确选中当前小时，但 `/npc/revise_plan` 连续返回可执行的 `work_clinic_doctor` 后，被“合并计划至少 6 个工作阶段”业务校验拒绝；Godot 3 次重试叠加后端每次 1 次纠错，形成 6 次无效修订调用，约等待 32.2 秒且仍保留旧计划。

T0085 移除该工作数量硬拒绝后，正常路径恢复为 1 次范围判别 + 1 次修订；工作阶段统计字段与 Prompt 文本不会产生额外调用。真实验收额外执行 1 次对话与 2 次修订，其中升级结束修订 request id=`verify_upgrade_completion_real_revision`，provider=`deepseek`、model=`deepseek-v4-flash`、`fallback_used=false`，直接返回 `work_clinic_doctor @ clinic`。三次验收账本估算费用合计约 ¥0.00989，只属于开发验收，不改变成品预算。

## T0083 应征结果表现与事件标题成本

本任务不新增 endpoint、`call_type`、字段、重试或模型调用。逐回复元数据、绿色 / 红色提示和事件标题精简都在 Godot 本地处理；专项使用显式 Mock，MCP 使用手工注入的合法既有响应，未调用真实 provider，也未增加 API 成本。

## T0082 应征持续开关与完整摘要成本

本任务不新增 endpoint、`call_type`、重试、模型字段或自动调用。toggle 保持只改变玩家下一次主动发送消息的既有 `is_recruitment_request` 布尔值；玩家没有继续发送就不会新增 `/npc/dialogue`。应征取消锁、挂起超时完成和完整会话 summary 都在 Godot 本地执行。完成后的计划判别仍是一场会话一次，不因 summary 展开为全文而重复请求或广播。

验收本身不需要真实模型语义。首次按 `startup_mode=1` 运行 Godot MCP 主场景时，既有正式启动流程自动发起 8 路 DeepSeek 日计划，持久化账本日尝试由 172 增至 180，日估算费用由 ¥3.30259164 增至 ¥3.42799564，即约 ¥0.125404；0 在途预留。确认后，后续本任务 MCP 验收临时使用静止调试模式并显式指向 Mock 后端，完成后恢复正式启动配置，没有再增加无关真实调用。

## T0080 门口失败与升级协助认知成本

本任务不新增 endpoint、`call_type`、模型重试规则或常态调用频率。变化只是把既有 `action_failure` 两段式链从“升级开始时”延后到 NPC 实际抵达入口时：门口失败后仍为 1 次 `/npc/plan_revision_judgement`，只有返回非空小时才再调用 1 次 `/npc/revise_plan`。室内 active 行动的触发频率不变。

`assist_upgrade` 候选增加少量室外执行、无需入内和工作阶段布尔 / 文本字段，四份相关 Prompt 增加对应解释；没有新增输出字段。开发验收在 `LLM_FALLBACK_TO_MOCK=false` 下额外执行真实 DeepSeek 对话与正式修订各 1 次：对话明确可在广场搬料递工具，修订选择 `assist_upgrade(target=workshop, location=plaza)`，均为正式 provider、`fallback_used=false`。这些调用只属于验收，不改变成品预算。

## T0078 NPC 主动交涉后续行动成本

本任务不新增 endpoint 或 `call_type`。NPC 主动交涉形成有效会话后仍调用 1 次 `/npc/plan_revision_judgement`；若结束时当前计划仍为 `seek_guard_officer`，required 当前小时保证判别非空，因此再调用 1 次 `/npc/revise_plan`。也就是该路径固定为 2 次对话后计划调用。取消锁本身为 0 次模型调用；挂起超时只在到期时按完成进入同一 2 次链，不另发对话请求。问号无人响应仍沿用 1 次直接当前小时修订。

真实 DeepSeek `deepseek-v4-flash` 在 `LLM_FALLBACK_TO_MOCK=false` 下通过普通变化 / 空判别、自主 NPC-NPC required 当前小时、NPC 主动找守备官 required 当前小时、当前小时正式修订及行动失败判别 / 修订，所有最终请求一次成功、`fallback_used=false`。测试还确认模型遗漏程序 required 时 endpoint 会以 `required_revision_hours_authoritative_union` 归并范围；该归并不选择行动，不新增 provider 调用。这些调用只属于开发验收。

## T0077 每日 20 元硬预算与运行期成本

当前 `deepseek-v4-flash` 使用 DeepSeek 官方人民币价：缓存命中输入 ¥0.02 / 百万 token、缓存未命中输入 ¥1 / 百万 token、输出 ¥2 / 百万 token；官方同时给出 1M 上下文与最大 384K 输出。价格来源：<https://api-docs.deepseek.com/zh-cn/quick_start/pricing/>（核对日期 2026-07-27）。

后端新增 `backend/logs/llm_cost_ledger.jsonl`，每个正式供应商 HTTP 尝试在拿到 usage 后独立追加 `prompt_tokens / prompt_cache_hit_tokens / prompt_cache_miss_tokens / completion_tokens / estimated_cost_cny`。因此自动重试、最终业务失败和并发请求都不会只按最后一次结果统计。账本以 `Asia/Shanghai` 自然日为键，`/debug/llm_usage.summary.provider_usage.daily` 每次从文件重放；重建 ModelAdapter 或重启后端不会清零当天用量。`session` 只表示本次后端运行，不跨重启。

正式 DeepSeek 环境默认：

```text
LLM_INPUT_CACHE_HIT_COST_PER_M_TOKENS=0.02
LLM_INPUT_COST_PER_M_TOKENS=1
LLM_OUTPUT_COST_PER_M_TOKENS=2
LLM_COST_LEDGER_ENABLED=true
LLM_COST_LEDGER_PATH=backend/logs/llm_cost_ledger.jsonl
LLM_DAILY_BUDGET_MAX_CNY=20
LLM_DAILY_BUDGET_TIMEZONE=Asia/Shanghai
LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY=0.05
```

T0090 后，每次 HTTP 前先在进程内原子预留 ¥0.05；该值来自当前开发流量分布，不再覆盖 Flash 官方最大输入 / 输出的理论极端上界。`当日已结算 + 所有在途预留 + 本次预留 > ¥20` 时，请求不发给供应商，业务端点返回 HTTP 429 / `budget_exceeded`。实际 usage 到达后释放预留并按缓存拆分结算。账本或价格不可用时失败关闭，不能用“估算为 0”放行。价格、模型、Prompt、上下文规模或费用分布变化时必须重新统计并调整预留；DeepSeek 控制台账单仍是最终财务事实，GM 显示明确标为本地估算。

真实验收（2026-07-27）：单次 `/npc/dialogue` 返回 200、真实 provider、0 fallback；prompt 5,827（缓存命中 2,944 / 未命中 2,883）、completion 180、合计 6,007，估算 ¥0.00330188。完整 audit 为 `call_started -> provider_request_sent -> provider_response_received -> provider_output_parsed -> call_completed`，provider response 与独立成本账本 usage 一致。

## T0076 自主对话后续行动成本

本任务不新增 endpoint 或 `call_type`。一次有实际内容的自主 NPC-NPC 对话仍为双方各 1 次 `plan_revision_judgement`；变化是发起者的判别强制包含结束时当前小时，因此发起者必有 1 次 `/npc/revise_plan`，受邀者只有判别非空时才有第二层。正常单次会话由原来的 `2-4` 次对话后计划调用收敛为 `3-4` 次。赶路、等待、邀请或正式会话跨普通整点本身不增加调用，也不补播旧小时；对话失败仍复用既有行动失败两阶段链。

真实 DeepSeek `deepseek-v4-flash` 专项在 `LLM_FALLBACK_TO_MOCK=false` 下完成：普通变化判别 / 未来修订、普通空判别、发起者强制当前小时判别 / 当前小时修订、行动失败判别 / 修订。T0078 起，模型遗漏 required 小时时由 endpoint 显式归并程序权威范围，不再让整条链因确定性小时遗漏而失败；正式修订仍由真实 provider 输出并返回非空 `immediate_action`。这些调用属于开发验收，不改变上述成品触发频率。

## T0073 指令计划影响验收成本

本任务不新增 endpoint、`call_type`、正常游戏触发频率或重试规则。发布变化后的指令仍按既有高优先级路径直接产生一次当前小时 `/npc/revise_plan`，不额外调用范围判别；相同文本和关闭面板仍为 0 次调用。

开发验收新增 1 次真实 DeepSeek `deepseek-v4-flash` 修订调用：`request_id=godot_revise_plan_1436_0002`，NPC `veteran_deputy_01`，输入 22,884 / 输出 266 tokens，结果成功、`fallback_used=false`，计划由 `idle` 改为 `visit_location(chapel)`。该调用只属于开发验收，不改变成品运行预算。

## T0071 对话私有上下文隔离成本

本任务不新增 endpoint、`call_type`、游戏内请求频率、重试或输出字段。NPC-NPC 对话删除整份 `speaker_npc`，并把 `speaker_context.state` 收为空字典；所有请求中的 `talk_to_npc` 候选同时删除目标实时地点、行动和入伍状态，因此输入 token 只会减少。回复者自己的长短期记忆不裁剪。

开发验收新增 1 次真实 DeepSeek `deepseek-v4-flash` 对话调用：输入 5,581 / 输出 207 tokens，`fallback_used=false`。模型明确表示不知道说话者未公开的安排，没有猜测私有事实。该调用只属于开发验收，不改变成品运行频率。

## T0070 名册与知识增量成本

本任务不新增 endpoint、`call_type`、正常触发频率或重试。每名登记成员新增两个布尔标签，离站者不再从名单移除，因此离站后的请求会比旧合同多保留该人物的一行；知识图谱由 222 条增至 226 条，并把 8 条仓库关系更新为容量已实现后的语义。实际增量随六类请求中注入的目标 NPC 长期记忆而变化。

真实专项只增加 1 次 DeepSeek `deepseek-v4-flash` 对话调用，`fallback_used=false`；模型准确列出 8 人的入伍 / 在站状态，并复述艾达训练场的独练与带训成长区别。仓库容量和 UI 验收不触发 LLM。

## T0069 持久化日志与调用成本

持久化审计是供应商调用旁路，不新增正常游戏 LLM 请求、重试或 token；本轮真实验收仅额外执行战时对话和战斗心理各 1 次，均为 DeepSeek `deepseek-v4-flash`、0 fallback。T0069 当时 `/debug/llm_usage` 和预算守门只使用当前进程内存 usage；该限制已由 T0077 的独立 `llm_cost_ledger.jsonl` 取代。审计 JSONL 与费用账本用途仍不同，禁止把生命周期日志行数直接当作计费调用数。

默认 `LLM_AUDIT_LOG_INCLUDE_PAYLOADS=true` 会增加本地磁盘写入量，但不增加模型输入 / 输出 token。当前未设置自动轮转或保留期；长期服务器运行需由部署配置负责日志轮转、磁盘配额和访问权限，不能通过删减 NPC 正式上下文来控制日志体积。

## T0068 T0067 调用证据导出

T0068 只读取本机已有 Codex 会话证据、当前测试构造器和正式 Prompt 文件，不启动测试场景、不调用 DeepSeek，因此新增真实调用数和 token 均为 0。生成的 `docs/audits/T0067_LLM_94_CALLS/call_inventory.csv` 重新汇总为 T0067 原有 94 次：Main 78 + 独立矩阵 16，输入 1,876,789、输出 61,520，未改变 T0067 的成本口径。

当前 usage 运行态是内存数据，后端重启后清零；T0067 当时也没有持久化完整动态 payload、解析前原始响应或 SSE 分块。此次只恢复出 Main 尾部 11 个唯一 request id，其余 67 次只能保留 call type 聚合；16 次静态定向矩阵可从未再改动的测试构造器和排序 JSON 规则确定性重建完整 provider body。审计包对这两类证据使用不同标签，不能把后者或聚合占位解释为 78 次 Main 的原始逐请求日志。

## T0067 真实全分支验收调用

正式 Main 后端使用 DeepSeek `deepseek-v4-flash`、thinking 关闭、temperature 0.2、`LLM_FALLBACK_TO_MOCK=false`。按真实 request id 去重后共有 78 次供应商请求、77 次业务有效、1 次普通开局 `plan_day` 业务校验失败、0 fallback：`battle_judgement` 7 次（输入 123,776 / 输出 876 tokens）、`dialogue` 43 次（输入 1,073,589 / 输出 8,842）、`plan_day` 28 次（输入 589,862 / 输出 49,188），合计输入 1,787,227、输出 58,906。43 次对话包含为验证输出捕获、调整真实场景和复测波动而重复运行的矩阵；28 次计划包含首版日计划工具在类型检查失败前误触发的 8 次全员计划、后续真实对话场景启动时的正常开局计划，以及最终冻结场景检查触发的 8 次正常开局计划。

最终冻结检查中，神父计划请求 `godot_plan_day_3568_0012` 的供应商生成完成，但输出未通过 `DailyPlanResponse` 业务校验。修复前 `record_model_output_invalid(...)` 会在已存在的成功 usage 后再追加一条失败 usage，因此当时 `/debug/llm_usage` 原始快照显示 79 条、并把该请求的输入 20,799 / 输出 1,837 tokens 双计。现已优先按上游 usage timestamp，并结合非空 request id、call type 和 NPC，原地把精确原记录标为 `SchemaValidationError`，保留原 token、成本、finish reason 与尝试次数；调用数、token 和预算只累计一次，重复报告也保持幂等。无 request id 或找不到对应上游记录时仍保留独立失败记录，避免丢失诊断。

另一个独立 Flask 正式 provider 定向矩阵完成 16 次调用，输入 89,562、输出 2,614 tokens，16 次业务有效、0 fallback。两部分合计 94 次实际供应商请求、93 次业务有效、1 次业务无效、0 fallback；输入 1,876,789、输出 61,520、总计 1,938,309 tokens。当前 provider 未返回可用价格配置，因此 `estimated_cost=0` 只表示本地没有成本估算，不能解释为实际调用免费。

这些调用都是开发验收成本，不改变正常游戏触发频率。新增测试脚本默认只在已配置非 Mock provider、关闭自动 fallback 时运行；`REAL_DIALOGUE_SCENARIO` 可限制单个真实对话场景，避免为复测一个结果重复整套矩阵。

## T0061 人物上下文收敛成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试、触发条件或输出字段。`signature_lines` 从 8 人档案、`NPCPromptProfile`、共享 `NPCIdentity`、对话 `npc_setting` 和六类正式 Prompt 移除，使每次人物上下文略微缩短；`speech_style`、3 篇初始日记和完整知识图谱仍按原有路径注入，不为节省 token 删除人格连续性或建筑常识。T0100 后新增的短 `religion` 成本见本文件顶部记录。

前两篇日记重写和建筑 `relation_label / value_label` 叙事化属于既有长期记忆内容替换；守备官认识从原有多条开放评估收束为每人一条职责事实，使全体种子关系总数从 227 条降至 222 条，不增加调用频率。`confidence / day / time` 仅在玩家【知识】弹窗隐藏，原始数据、运行态、后端参数、反思更新和 GM 调试仍传输完整字段，因此没有 Schema 迁移或额外调用。文案与 UI 显示本身不会触发模型请求。

T0061 的真实 provider 专项在关闭自动 Mock fallback 的条件下，使用 DeepSeek `deepseek-v4-flash` 完成 3 次业务调用、0 失败：分别核验托马的宏观身世与到站时间线、莉娜的到站群像与昏迷救助常识、欧文的守备官职责与城墙器械位规则，三次均为 `fallback_used=false`。当前六类 Godot 专项最大序列化 payload 字符数为：dialogue 48330、plan_day 47118、plan_revision_judgement 50053、revise_plan 49952、battle_judgement 32057、daily_reflection 29242。字符数不是 provider token 数；这些开发验收调用不改变成品正常频率。

## T0060 文案与时间标签成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段。日记运行态仍是 8 字段结构，只在 `LLMBridge._build_existing_diary_entries(...)` 投影为既有 `list[str]`；与只传正文相比，每条日记的时间标签约增加 6–18 个字符。当前 Godot 专项最大序列化 payload 字符数为：dialogue 48436、plan_day 47382、plan_revision_judgement 50305、revise_plan 50216、battle_judgement 32382、daily_reflection 29508。字符数不是 provider token 数，实际 token 与费用仍以 usage 为准。

最终真实 provider 专项使用 3 次验收调用，验证独特人生记忆和“近日”敌情传达前边界。调试验收谓词和时间标签投影前，另有 4 次返回成功的校准调用；一次 LLMBridge 集成测试最初误用本地真实配置并记录 `ProviderIdleTimeout`，随后改用显式 Mock 后端通过。故本轮开发共产生 8 次真实 provider 尝试，最终专项为 3 次调用、0 失败；所有路径均关闭自动 Mock fallback。这些开发调用不改变成品正常频率。

## T0059 初始长期记忆输入成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段，但会显著增加六类既有请求的固定输入：每名 NPC 当前有 3 篇初始日记和约 25 个知识主体（15 建筑、7 名其他 NPC、守备官、至少 2 个个人故事主体）。这些内容用于开局即具备人物连续性，不能以空记忆替代。

为避免同一长图谱在单次请求内重复付费，LLMBridge 已移除正式 payload 中旧 `NPCContext.knowledge_graph` 镜像；计划、判别、修订、战时心理与反思只使用 `npc.long_term_memory`。对话只在顶层 `long_memory` 放目标记忆，`target_npc` 不再复制；T0071 后正式 payload 已彻底删除 `speaker_npc`，不再传输另一人的短期或长期私人上下文。当前本地最大序列化 payload 字符数以专项运行输出为准，字符数不是 provider token 数，真实 token / 费用仍以 usage 为准。

若长期记忆随多日反思继续增长，应优先做可验证的按主体检索、旧日记压缩或供应商静态前缀缓存；不得删除与当前人物 / 地点 / 对话对象相关的关键认知，也不得让模型自行猜测被裁掉的建筑规则。当前任务先保证语义完整和单次不重复，不新增第二套摘要或隐藏 Mock fallback。

真实 provider 专项最终在 `LLM_FALLBACK_TO_MOCK=false`、连接超时 30 秒、流空闲超时 180 秒的受控配置下通过：DeepSeek `deepseek-v4-flash` 完成莉娜 / 欧文两次独特记忆追问，usage 为 2 次调用、0 失败、`fallback_used=false`。这些是开发验收调用，不改变成品运行频率。

## T0058 五项资源快照与单条升级规则增量

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段。六类既有请求的唯一顶层 `station_context` 增加 5 个短资源项和 1 条规则；计划 / 判别 / 修订原有 `current_resource_states` 从全量库存收窄为同一五项，因此不会继续为隐藏库存支付输入 token。资源每次请求实时读取，但不会单独触发 LLM 调用。

验收额外使用真实 DeepSeek 对话和日计划各一次：对话准确复述五项数量并理解协助升级，日计划实际选择 `assist_upgrade`；两次均 `fallback_used=false`。这些是开发验收调用，不改变成品运行频率。

## T0055 单条规则增量

本任务只在既有 `station_rules` 增加一条短规则，并补充六份系统 Prompt 的解释；不新增 call type、请求、重试或输出字段。固定输入 token 有小幅增加，人员、建筑、行为和规则仍只在顶层注入一次。开发验收针对“离开菜园后是否自动产出”增加一次真实对话语义检查，结果为 `deepseek-v4-flash / fallback_used=false`；这不改变游戏内正常调用频率。

## T0054 共享世界常识的输入成本

本任务不新增 `call_type`、endpoint、重试或游戏内调用频率。六类既有请求的唯一顶层 `station_context` 增加完整建筑目录、工作模式行为类型目录与精简规则；T0055 后当前为五条。人员仍随离站缩短，建筑 / 行为目录由正式配置生成，不在嵌套 NPC、speaker 或 target 中重复。增长只发生在输入 token，输出合同不变。

目录提供稳定世界边界，单次可用候选仍由 `allowed_actions / allowed_decisions` 传入，因而不能为了省 token 删除这些动态权威字段。若后续目录明显增长，优先压缩名称 / 描述或引入经验证的静态前缀缓存，不得改为让模型自行猜测建筑、行为或战斗资格。真实 DeepSeek 已覆盖对话、日计划、判别、修订、战时心理与反思，全部使用真实 provider 且 `fallback_used=false`；没有因本任务引入额外业务调用。

## T0053 上下文增量与跨小时失败调用边界

计划修改范围判别不再省略人物上下文：每次 `/npc/plan_revision_judgement` 增加动态 `station_context`、统一 `NPCContext`（含身份 / 状态 / 指令 / 短期记忆 / `long_term_memory` 日记与知识图谱 / 地点）、合法行动候选及实时建筑 / 资源状态。该增量换取对话、计划、失败判别、正式修订和战时心理的人格一致性；仍沿用既有请求级 usage、token 与费用记录，不增加新的 call_type。

等待目标计划本身仍不调用 LLM。只有日计划来源的等待跨入“不再与同一目标对话”的当前计划项时，程序才产生一次真实行动失败判别；返回空范围则停止，非空才增加一次正式修订调用。因此该路径的新增调用上限与普通 T0050 行动失败相同，为 1 次判别 + 按需 1 次修订，不轮询、不按等待帧计费。战时判定没有新增触发次数，只扩展既有 payload 的长期记忆内容。

## T0052 计划等待不增加调用

本任务不新增端点、`call_type`、Prompt 字段或成功路径调用次数。守备官在 NPC 计划中不能创建对话请求，因此不会为了同一 NPC 取消计划后再补发一份计划；NPC-NPC 动作等待期间也不调用 `/npc/dialogue`、不写行动失败、不启动 `/npc/plan_revision_judgement`。只有目标计划 terminal 且重新校验通过后，才按既有预算发起一次邀请请求。即时失败修订继续过滤计划 / LLM 活动目标，避免选择一个只能排队的目标并制造额外修订循环。

本轮改动不涉及 Prompt、Schema 或 provider 输出效果；互斥 / 等待时序由本地状态活动、fake provider 自动化和 Godot MCP 运行态验证。随后使用已配置后端完成真实 DeepSeek `deepseek-v4-flash` NPC-NPC 邀请接受、邀请拒绝和正式对话业务路径，`response_kind=reply_to_npc`、`fallback_used=false`；等待阶段本身仍为 0 次模型调用。

## T0051 会话收口与请求预算

“完成对话”和“取消对话”都会调用客户端取消接口终止仍在等待的 NPC 回复；“挂起对话”不会取消请求，也不会重复发起请求。玩家在等待时完成后，迟到回复按失效 request id 丢弃，不能为同一句话补发第二次模型调用。两小时挂起超时同样只收口现有请求：普通会话取消，含攻击会话完成。会话提交 / 丢弃、事件广播和暂存权威结果应用都在 Godot 内完成，不新增后端端点或额外 LLM 调用；完成后的计划修改判别仍沿用 T0049/T0050 预算。

## T0050 通用判别层成本边界

T0050 将第六个正式调用通用化为 `call_type=plan_revision_judgement`。每场有实际完成内容的守备官-NPC 对话为目标 NPC 增加 1 次判别；NPC-NPC 对话为两名参与者分别增加 1 次；每次日常行动失败也先增加 1 次判别。判别输出只含是否修订与小时集合，应保持短输出；`revision_hours=[]` 时必须停止，不产生 `/npc/revise_plan` 成本。非空时才再调 1 次 `revise_plan`，修订输出只覆盖精确选中小时。

因此单场守备官-NPC 有效对话和单次行动失败的计划后处理成本都是“1 次判别 + 0 或 1 次修订”，NPC-NPC 为“2 次独立判别 + 0 至 2 次独立修订”。指令变化、战斗 / 复苏和 GM 等其他非对话触发不增加判别调用。判别和后续修订使用不同 request id，分别记录 provider / model / token / 费用、失败原因和 TimeSystem 慢速释放状态。行动失败修订落地后若再次失败，新失败会重新产生一次判别，但仍受同小时连续 3 次落地失败上限保护。

## T0046 上下文成本与真实验收

本任务不增加 LLM `call_type` 或游戏内调用频率。T0046 首次为每个携带 NPC 人设的请求增加一份顶层 `station_context`；T0054 在同一位置扩充建筑、行为和规则，仍不在嵌套 NPC 上下文重复。反思响应移除 `memory_summary`，同时减少输出 token 与后续长期上下文体积。公告牌通告 / 参考日程为程序状态与见闻传播，不发起新 LLM 调用。

2026-07-21 真实 `deepseek / deepseek-v4-flash` 验收时自动 Mock fallback 关闭：反思 1 次、共享场景上下文 4 类业务通过；8 人计划采样 8/8 成功、0 fallback、0 重试，input 126323 / output 13974 tokens。

## T0043A 服务依赖失败的调用预算

本任务不增加新的 LLM `call_type`。医生 / 教官 / 主持者离岗和教堂互斥由 ActionSystem 同步结算；行动失败只复用既有 `revise_plan` 请求链路，因此成本影响仅是确实发生失败时的一次既有计划重评估。依赖者等待仍在前往工位的同批服务者不会提前制造修订调用。

2026-07-21 使用已有 DeepSeek 配置复验 `plan_day`、`revise_plan` 和 `dialogue`，provider=`deepseek`、model=`deepseek-v4-flash`，均未使用 fallback；本任务没有新增接口或常驻调用。

## T0043 位置与资格字段成本边界

建筑位置细化不新增任何 LLM 调用类型、频率或重试。`allowed_actions.context` 增加资格 / 可用性提示，当前地点上下文增加逐位置显示名、容量和占用状态，只带来少量输入 token；不得为每个编号位置复制行动候选，NPC 仍只看到每种行动一条候选。团队效率、受损效率和升级进度由 Godot 权威推进，不调用模型。

本轮若修改实际 Prompt 模板，仍须先跑 mock / schema 测试；环境已有真实 Key 时，再对计划候选资格理解做真实 provider smoke。没有真实 Key 时必须在 T0043 验收结果中明确“真实 API 未验收”，不能以 Mock 代替。

2026-07-21 验收：环境使用真实 `deepseek / deepseek-v4-flash`，自动 Mock fallback 关闭。`/npc/plan_day`、`/npc/revise_plan`、`/npc/dialogue` 均通过且 `fallback_used=false`；额外的非神职园丁计划请求携带可见但 `eligible=false` 的 `lead_mass`，真实结果未选择该行动。位置细化没有增加正式调用类型或游戏内触发频率。

## T0041 对话行动参考成本边界

每次 `/npc/dialogue` 现在都会携带目标 NPC 的动态 `allowed_actions`，但不会因此增加调用次数；增加的是单次对话输入 token。当前目录包含静态行动、可交谈 NPC、可访问地点和实时协助目标，具体条数会随世界状态变化，usage 仍按每个对话 request id 记录真实输入 token 与费用。为保证单一事实源，不在 Prompt 另写一份较短但可能过期的手工清单；如后续需要压缩，应从同一候选目录做无损投影，并保留“列表外当前做不到”的语义。

## T0025/T0030 NPC-NPC 对话调用边界

自主 NPC-NPC 对话先调用一次正式 `call_type=dialogue` 邀请判定；受邀者接受后，每个正式回复轮次再各调用一次，拒绝时只有邀请这 1 次。T0030 后正式对话没有调用次数硬上限：默认软阈值为 5，模型应在事情说完时结束，并从第 6 轮起在无紧急 / 必要事项时告别收尾；紧急 / 必要事项允许继续，因此单场成本必须以 usage 实际记录监控，不能再按固定 4 次封顶估算。行动失败修订调用正式 `call_type=revise_plan`。两类当前场景请求都携带 `requires_time_slowdown=true`，每次邀请 / 回复使用独立 request id，Godot 在请求成功、失败、取消或会话被权威模式打断后释放对应慢速请求。正式路径要求非 Mock provider、`model_fallback_used=false`，不会用 Mock 或规则内容伪装成功。计划修订最多 3 次真实尝试；这些是业务重试边界，不是客户端输出 token 上限。

## 目标

控制 LLM 调用成本，避免 8 个 NPC 高频调用导致 Demo 不可运行。

正式成本与并发边界：

- 玩家电脑上的 Godot 客户端只请求游戏服务器后端，不直接调用 LLM Provider。
- 服务器后端统一持有供应商 API Key，并负责限流、排队、批处理、降级、token/费用统计和异常熔断。
- 本地开发可以显式使用 mock provider 或本机后端验证接口；这不代表玩家最终必须自行启动后端或自行配置 API Key。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式；即使实现，也必须与默认服务器后端模式隔离，不能让 Godot 导出客户端默认保存真实 Key。
- Mock provider 只用于开发期 Schema / 通信 / 自动化验证。真实 API 测试通过后，生产 / 演示路径必须关闭自动 mock fallback；模型失败应返回可处理错误并记录真实原因，或进入明确标记的规则 / 模板降级。

## 调用优先级

| 优先级 | 任务 |
|---|---|
| 高 | 玩家正在对话的 NPC |
| 高 | 集结 / 战斗 / 避战模式下的战时公开对话 |
| 高 | 守备官发布新指令后立即触发的计划重评估 |
| 高 | 战时 HP 低于 30% 的自身心理判定 |
| 中 | 逃离挽留对话 |
| 中 | NPC 主动找玩家交涉 |
| 中 | 行动异常重评估 |
| 低 | NPC 间闲聊 |
| 最高 | 首次睡眠总结 |
| 低 | 每日计划，可批处理 |

## 调用记录字段

每次模型调用记录：

- 时间
- 调用类型
- 关联事件 id 或触发事件 id
- 关联 NPC id
- Godot 侧请求 id
- provider、model、base_url 标识（不含 Key）
- 是否申请 TimeSystem 慢速
- 慢速申请与释放时间
- 输入 token
- 输出 token
- 估算费用
- 是否成功
- 失败原因
- HTTP 状态或异常类型
- 是否使用 mock、规则降级或模板降级

正式供应商请求不设置客户端单次输出 token 上限。供应商自身的上下文窗口仍然存在；若返回 `finish_reason=length`、空内容或非法 JSON，后端会记录真实原因并使用对应业务的紧凑提示重试一次。`LLM_BUDGET_MAX_*` 是可选的累计预算守门，默认 `0` 关闭，只限制累计调用、累计 token 或累计费用，不限制单次生成长度。

## LLM 等待与时间减速

会影响当前场景即时状态的 LLM 调用，需要由 Godot 侧在发起请求前调用 `TimeSystem.request_time_slowdown(...)`。请求成功、失败、超时或降级后必须释放。

默认慢速倍率为 `1/60`：默认速度下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。该倍率只影响逻辑时间、资源/状态/战斗等数值结算，不影响 Godot 全局运行速度、NPC 移动速度或动画速度。

正式开局和跨天后的新一天计划期间，`GameStartupSystem` / `DailyPlanSystem` 直接暂停 `TimeSystem`，因此每个计划请求不重复登记慢速。T0022 将 8 名 NPC 调整为 8 路并发；单人失败只重试真实请求，最多 3 次，8 份 `llm_plan_day` 全部就绪后才恢复时间。任一 NPC 仍失败则整批保持暂停，不使用 Mock 或规则降级。常规运行中的对话、通用计划修改判别、单次每日计划、计划修订、战时低血量心理判定和首次睡眠总结都属于会影响即时状态的正式业务请求，payload 默认为 `requires_time_slowdown=true`。集结 / 战斗 / 避战模式下的守备官对话会影响当前战局意向，应按高优先级立即申请慢速；战时 HP 低于 30% 的自身心理判定同样是高优先级，并且判定等待期间目标 NPC 不可被守备官对话。首次睡眠总结虽然频率低，但它锁定 NPC 当下状态，必须申请慢速并确保请求结束后释放。health / usage 等只读请求和显式 `/mock/model` 后端调试不申请慢速。

T0029/T0030 后 NPC-NPC 邀请判定也属于对话请求，等待期间受邀者继续当前工作，但逻辑时间仍按邀请 request id 降速；接受后的每轮正式回复重新登记新的慢速请求。无硬轮次上限不改变降速规则，每次调用仍必须独立注册并在结束后释放。

T0049/T0050 后，六类正式业务都提供异步 Godot 路径，避免用短同步等待阻塞主线程。T0021 后正式业务不再设置 75 / 90 秒响应总时长：Godot 只对连接本地 / 游戏后端使用 2 秒短连接保护，请求发出后等待后端完成。后端对供应商使用流式 SSE；连接超时和流完全无数据的空闲超时分别配置，持续收到 token 或 keep-alive 时继续等待，不限制模型生成总时长。`LLMBridge.debug_get_llm_runtime_snapshot()` 会记录每个请求的 call_type、是否注册 / 释放慢速及时间戳，便于确认成功、失败、取消、连接 / 空闲错误和降级路径没有遗留减速。

`current_order` 会进入所有面向该 NPC 的 LLM 请求，因此必须限制为单条当前有效指令，不重复注入全部历史版本。历史修改通过 `private` `order_assigned` 事件进入短期记忆摘要；常规请求只额外携带当前文本和最小元数据，避免指令修订不断放大上下文。

## 当前实现状态

- T0602 已实现默认 `mock` provider 的 `ModelAdapter.generate(...)`，可以按调用类型返回稳定 JSON；该能力只作为开发期脚手架和自动化验证入口。
- Mock 调用会记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态和失败原因；mock 费用固定为 0。生产 / 演示真实 provider 失败时不得自动返回 mock 内容伪装成功。
- T1401 已实现 `deepseek` / `openai_compatible` 真实 Model Adapter。DeepSeek 默认 `LLM_BASE_URL=https://api.deepseek.com`、`LLM_MODEL=deepseek-v4-flash`；真实 Key 只从 `LLM_API_KEY` 或服务器 / 本地后端环境读取。T1401A 后 `LLM_FALLBACK_TO_MOCK` 默认关闭，真实 provider 无 Key、请求失败、超时、HTTP 错误、非 JSON 或业务 Schema 校验失败时返回可处理错误并写入 usage；自动 mock fallback 只在显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试中启用。
- T0049/T0050 后，六类正式 call_type（含通用 `plan_revision_judgement`）均不向供应商发送 `max_tokens`。供应商返回空内容、非法 JSON 或 `finish_reason=length` 时会按 call_type 紧凑重试一次；`/health` 快照显示 `client_output_token_limit_applied=false`，usage 继续记录真实 `finish_reason`、内容长度、尝试次数和失败原因。
- T0021 后，正式供应商请求统一使用 `stream=true` 聚合最终 JSON。旧 `LLM_TIMEOUT_SECONDS` 已拆为 `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS` 与 `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS`；空闲超时只在流完全没有 token、keep-alive 或其他字节时触发，不是总生成时长上限。
- T0603 已实现 `POST /npc/dialogue` 业务接口，内部复用 `ModelAdapter.generate("dialogue", ...)`，因此对话调用也会产生 usage 记录；业务响应仍只返回 Schema 校验后的模型内容，usage 通过 `GET /debug/llm_usage` 暴露给调试入口。
- 真实 provider 调用会读取供应商返回的 prompt / completion token；DeepSeek 额外拆分缓存命中 / 未命中输入。T0077 后环境构造的 V4 Flash 默认带官方人民币单价和每日 20 元持久化预算；费用账本拿不到 provider usage 时不伪造已结算 token，账本 / 定价异常会让后续预算路径失败关闭。
- T1406 的进程内 `LLM_BUDGET_MAX_*` 兼容守门继续保留，默认 `0`；T0077 新增默认启用的 `LLM_DAILY_BUDGET_MAX_CNY=20`、持久化日账本与单次在途预留。两层任一拒绝都会返回 HTTP 429 / `budget_exceeded`，usage 记录 `BudgetExceeded / budget_blocked`，不自动 mock fallback。
- `POST /mock/model` 可用于后端调试；后续实现对话、计划、判定接口时，服务层应复用 Model Adapter 的 usage 信息，并补齐是否申请 TimeSystem 慢速、慢速申请与释放时间等 Godot 侧字段。
- T0604 已在 Godot 侧实现 `LLMBridge`；T0049/T0050 后对话、通用计划修改判别、每日计划、计划修订、低血量心理判定和首次睡眠总结都按 payload 注册 TimeSystem 慢速请求，并在成功、失败、取消或超时后释放。T1401 新增同步“成本统计”只读入口；T0077 新增不阻塞主线程的 `request_llm_usage_async()`，GM 面板可见时每 3 秒在顶栏显示本次后端运行 provider 尝试 token / 人民币与今日持久化金额 / 上限。用量查询自身不申请 TimeSystem 慢速、不计入模型成本。更完整的多玩家限流、跨进程并发队列和服务器部署治理仍归 T1407。
- T0604A 已将 Godot 侧传输层改为原生 `HTTPClient`，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件，并继续保证失败、超时和降级路径都会释放慢速请求。
- T0109 不新增 endpoint、call_type、重试或供应商调用。显式取消和场景退出现在会协作终止仍在等待的 Godot `HTTPClient` 传输并 join 工作线程；已经发送到后端 / 供应商的尝试仍按后端真实 usage 与审计记录保留，客户端取消不会伪造成功、抹掉成本或触发 Mock fallback。
- T0108 只更新既有长期记忆内容，不增加正常运行调用次数。2026-07-30 最终真实验收使用 DeepSeek `deepseek-v4-flash` 完成 3 次对话，29,784 input / 459 output tokens、估算 ¥0.00185080，全部 `fallback_used=false`；包含一次为放宽表面措辞断言而重跑的完整迭代后，本任务共发生 6 次成功 provider 调用，59,568 input / 888 output tokens、估算 ¥0.02132864。
- T1006/T0051 起，玩家对话 UI 使用 `LLMBridge.request_npc_dialogue_async(...)` 发起异步 `/npc/dialogue`：发送消息或普通对话攻击才申请慢速和 NPC LLM 活动状态。玩家在回复返回前点击“完成对话”会取消 request id、释放慢速、清除活动状态并丢弃迟到回复，但已立即进入 history 的真实守备官消息会随完整会话入库并触发判别；“取消对话”同样取消请求但不入库、不判别；“挂起对话”不取消请求，NPC 和 TimeSystem 等待状态照常持续。普通对话攻击仍计入 `call_type=dialogue`，攻击事实先由 Godot 结算且锁定取消；T0254 后固定攻击说明不进入 history，纯攻击结束不发空对话判别而走既有 `guard_attack` 重评估。逃离挽留攻击不调用 LLM、不申请慢速、不计入 API 成本，并自动完成会话但不生成无台词 `dialogue_turn`。
- T0050/T0085 后，日常行动异常、NPC-NPC 和守备官-NPC 实际对话都先请求异步 `/npc/plan_revision_judgement`，仅非空判别再请求 `/npc/revise_plan`。T0086/T0093 的五类成功完成事件属于确定性后续安排，跳过判别并直接修订当前小时起连续相同 action + target 的计划段。修订输出与 `revision_hours` 完全一致；精确小时、白名单或目标组合不合法时后端可携带业务错误让同一真实 provider 纠正一次，Godot 也会拒绝当前小时原样重复已完成的 action + target。工作阶段较少不再触发纠错或 Godot 重试。正式路径仍拒绝 Mock / fallback，最终失败保留原计划。
- T1003/T1403/T0022/T0085 后，每日计划通过 `/npc/plan_day` 走 Model Adapter。正式开局和新一天会暂停时间并同时发起 8 个真实请求。后端校验 24 个 hour 覆盖与行动白名单；通常至少 6 个工作阶段是 Prompt 建议，不是重试来源。Godot 正式路径只接受 `llm_plan_day`，其他真实失败仍保持暂停且不使用 Mock / 规则计划。
- T1004/T1005/T1405/T0024 起，首次睡眠总结可通过异步 `/npc/daily_reflection` 走 Model Adapter。Godot 侧默认 `requires_time_slowdown=true`，不设置业务响应总时长；总结发起到完成期间 NPC 处于不可打断的深度睡眠锁，因此它不是后台无感调用。符合条件的 8 名 NPC 最多 8 路并发，快照记录实际峰值。后端成功体携带 provider / model / fallback 元数据；真实结果写为 `llm_daily_reflection`，显式开发 Mock 才写 `mock_daily_reflection`。真实 provider 不可用、未配置、缺少来源证明或输出不合法时，`DailyReflectionSystem` 使用本地模板兜底，仍会追加日记、替换式更新知识图谱当前键值并清空该 NPC 当天短期记忆；模板来源和原始失败原因必须可查。
- T1201 后，战时公开对话复用 `call_type=dialogue`，请求 payload 额外携带 `interaction_context=rally|combat|avoid_combat` 和 `battlefield_context`；`LLMBridge` 最近上下文注入快照会标记是否携带战场上下文。低血量自身心理判定使用独立、异步的 `call_type=battle_judgement`，不能与旧式“战斗触发全员判定”混淆；后者已被取消。T1404 后，真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，后端会拒绝越界 `decision` 与逃离布尔不一致结果并写入失败 usage；真实 DeepSeek 已完成战时 `/npc/dialogue` 与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。
- T1204A 后，逃离挽留中“玩家发送消息并等待 NPC 回复”的轮次复用 `call_type=dialogue` 和 `/npc/dialogue`，payload 使用 `dialogue_kind=escape_intervention`、`interaction_context=escape_intervention` 和 `escape_intervention_round=1..5`。它会影响当前逃离状态，因此仍按对话类请求申请 TimeSystem 慢速；后端失败时 Godot 规则降级为 stay/continue 意图，并释放慢速请求、保留真实失败日志。逃离挽留面板内的攻击只由 Godot 权威结算并计 1 轮，不请求 `/npc/dialogue`。
- T0063 不新增 call_type、接口或额外运行时调用；只在既有六类 payload 中增加个人 `wine`、`drink` 候选与行为说明。2026-07-27 已按 Schema / fake-provider / Mock 先验收，再在 `LLM_FALLBACK_TO_MOCK=false` 下用真实 DeepSeek `deepseek-v4-flash` 覆盖 plan_day、dialogue、plan_revision_judgement、revise_plan、battle_judgement 和 daily_reflection，成功结果均为真实 provider、`fallback_used=false`。

## 真实 API 验收与失败可见性

- 每个涉及 LLM / Prompt 的任务应先跑 mock / schema 自动化测试，再用真实 API Key 对本任务涉及的业务路径做至少一次真实 provider 测试。
- 没有真实 Key 时，不能把真实 LLM 行为标记为完全验收；任务状态应为 Partial / Blocked，或在验收结果中明确真实 API 未测。
- 生产 / 演示配置必须关闭自动 mock fallback。预算超限、无 Key、provider 错误、超时、非 JSON 或 Schema 失败时，返回可处理错误；只有明确保留降级语义的其他系统才能使用规则 / 模板结果，正式每日计划不降级。
- Usage / 日志必须能回答“哪个 request、哪个 call_type、哪个 provider/model、哪个 NPC、为什么失败、是否降级、花了多少 token/费用估算”。这比在失败后生成一段看似正常的 mock 回复更重要。
