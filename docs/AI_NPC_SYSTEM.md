# AI_NPC_SYSTEM.md

## 模块目标

AI NPC 系统负责让 NPC 看起来像有职业、有记忆、有意图的人，而不是普通兵种单位。

## NPC 初始名单

T0301 已在 `data/npc_profiles.json` 补齐 8 名初始 NPC 档案：

| 职业 | id | 姓名 | 性别 | 初始是否已入伍 / 可接收指令 |
|---|---|---|---|---|
| 马夫 | `stableman_01` | 托马 | male | 否 |
| 厨子 | `cook_01` | 布鲁诺 | male | 否 |
| 园丁 | `gardener_01` | 伊沃 | male | 否 |
| 铁匠 | `blacksmith_01` | 格伦 | male | 否 |
| 老兵副官 | `veteran_deputy_01` | 艾达 | female | 是 |
| 神父 | `priest_01` | 马塞尔 | male | 否 |
| 医生 | `doctor_01` | 莉娜 | female | 否 |
| 工程师 | `engineer_01` | 欧文 | male | 否 |

开局仍只有老兵副官 `veteran_deputy_01` 已入伍并可接收守备官指令；其他 NPC 必须通过后续征召/对话流程同意后才会获得指令入口。

## 熟练度架构

NPC 没有写死的程序职业。`background_job` 只记录叙事出身，工作效率、训练倾向、装备表现和后续 AI 判断都应优先读取固定熟练度维度。

每名 NPC 都必须拥有且只能拥有以下 13 个熟练度：

| 类型 | 熟练度 |
|---|---|
| 职业熟练度 | 养马、厨艺、耕种、打铁、教练、酿酒、医术、工程 |
| 武器熟练度 | 剑盾、长杆、弓、弩、骑术 |

职业倾向由高熟练度推导。例如养马高的人可被看作马厩专家，医术高的人可被看作医生，但系统不应把“马夫 / 医生 / 工程师”等作为权威职业枚举。

## 当前运行时实现

T0304 已实现最小 NPC 生成、基础状态读取/更新、面板显示和直线移动闭环：

- `NPCSystem` 从 `data/npc_profiles.json` 读取 8 名初始 NPC 档案。
- 通用 `res://scenes/npc/NPC.tscn` 由 `NPCSystem` 实例化到 `Main/WorldRoot/Station/NPCs`。
- 每个 NPC 保存唯一 `npc_id`，主场景头顶调试标签只显示姓名、HP 和当前行动，职业与入伍状态保留在 NPC 面板中。
- 点击 NPC 会打印对应 ID，并通过 `EventBus.npc_clicked(npc_id)` 广播，打开 `Main/UI/NPCPanel`。
- `NPCSystem` 提供 `get_npc(...)`、`get_npc_state(...)`、`update_npc_state(...)` 和 `set_npc_state_value(...)`，后续系统可通过这些接口读取或修改 NPC 基础状态。
- `NPCSystem` 提供固定熟练度枚举与 `normalize_skills(...)`，确保每名 NPC 都拥有完整 13 维熟练度，且不会保留未定义技能。
- NPC 状态修改后会通过 `EventBus.npc_state_changed(npc_id)` 通知 UI 刷新。
- `NPCSystem.move_npc_to_building(...)` / `debug_move_npc_to_building(...)` 可让 NPC 前往指定建筑入口；当前用于调试验证和后续行动系统接入。
- `NPC.gd` 负责简单直线移动，到达目标后发出 `movement_arrived`，由 `NPCSystem` 写回 `current_location`、`current_location_name` 和 `location_context` 地点信息占位。

T0305 后，`ActionSystem` 已能通过调试接口安排 NPC 执行工作、吃饭和睡觉：系统会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑，到达后进入持续行动状态，并随 `TimeSystem.logical_time_tick` 逐步推进，而不是瞬时完成。吃饭当前以 20 分钟为基准，完整进餐恢复约 50 点饱食度；睡觉以 6.5 小时消耗 100 点疲劳为基准，按逻辑秒细分结算。T0801 起，工作以 `data/action_defs.json` 的 `duration_seconds` 作为单位周期基准，开始时占用建筑工位，周期时长会按 NPC 对应熟练度、力量/智力属性和建筑等级缩短；单位完成时结算资源投入、产出、饱食消耗和疲劳增长，完成、失败或中断会释放工位并广播地点内部状态。T0806 后，马厩工作使用养马与力量，消耗粮食并产出 `horse_readiness` 马匹整备库存；T0901 后，该库存可由 `EquipmentSystem` 转换为 NPC 坐骑槽，但日常工作模式仍不骑乘。T0807 后，酒窖工作使用酿酒与智力，消耗粮食并产出 `wine` 酒库存；酒出售换钱仍由后续商人交易系统处理。行动开始、完成或失败都会写入 `MemorySystem` 的结构化事件。

2026-05-24 起新增协助修复行为；2026-05-25 起新增协助升级行为。`debug_assign_repair_assist(npc_id, building_id)` 与 `debug_assign_upgrade_assist(npc_id, building_id)` 都是带建筑参数的独立行为，可让 NPC 在广场协助正在修复或正在升级的建筑，并按工程熟练度加速对应倒计时；NPC 如果在室内，会先前往广场再开始协助。如果 NPC 离开广场或被改派其他行动，`BuildingSystem` 会移除其协助人数和速度加成。协助修复/升级事件写为 `location_id == "plaza"` 的 `local_public`。当前行动仍是最小闭环，计划系统只能安排意图并调用行动白名单，不能让 LLM 直接结算资源、建筑或 HP。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` / `debug_damage_npc(...)` 负责权威 HP 扣除。HP 降到 0 时 NPC 进入昏迷而不是死亡，停止移动，`current_action` 变为 `unconscious`，头顶标签与 NPC 面板会显示昏迷状态。昏迷 NPC 不能移动或执行工作、吃饭、睡觉、协助修复/升级等行动。

T0502 起，昏迷 NPC 会随 `TimeSystem.logical_time_tick` 自然恢复 HP，当前速率为每游戏小时 2 HP；HP 达到 Max HP 的 30% 后自动复苏，`unconscious=false`，`current_action=idle`，后续移动和行动指派重新允许。复苏会写入 `revived` 事件并按当前信息地点 `local_public` 广播。

T0503 起，其他可行动 NPC 可通过 `ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 协助治疗昏迷目标。治疗者会前往目标所在信息地点；目标必须处于昏迷状态，每个目标最多 2 名治疗者。治疗开始和持续治疗会消耗全局第纳尔；医术熟练度会转化为额外 HP 恢复速度，低医术几乎没有额外加成，医生的高医术会明显快于自然恢复。治疗开始/完成事件会写入治疗者和目标的事件库，并写入同地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。该功能只覆盖“他人治疗昏迷者”，不等同后续 NPC 主动去诊所治疗或医疗床位系统。

T0808 起，小诊所治疗补齐为两个独立行动：`work_clinic_doctor` 让医生占用诊所医生工位坐诊或研读医学著作，`receive_clinic_treatment` 让受伤且未昏迷 NPC 占用病床接受治疗。只有医生在诊所工位且病人进入病床时，诊所治疗才会推进；治疗随逻辑时间消耗第纳尔，医术、智力和诊所等级提高 HP 恢复速度。医生没有病人时会以很慢节奏通过 `skill_improved` 事件记录研读医学著作并提升医术，治疗中也会少量提升医术；T0904 后这些医术增长同步进入统一经验与技能点规则。

T0903 起，训练场补齐为两个独立行动：`work_training_instructor` 让有主武器或坐骑的 NPC 占用教官工位，`receive_weapon_training` 让有主武器或坐骑的 NPC 在已有教官时占用受训位。训练项目由 NPC 当前装备决定：主武器对应剑盾、长杆、弓或弩，坐骑对应骑术；同时有武器和坐骑时两项都会提升。教官没有受训者时，会极慢提升自己当前装备对应熟练度；有受训者时，受训者按自己的装备提升对应熟练度，教官只提升“教练”。训练速度读取教官“教练”、训练场等级、以及教官和受训者在当前训练项目上的熟练度差；教官项目熟练度低于受训者时提升很慢。训练消耗疲劳和饱食，并通过 `skill_improved` 事件写入独自练习、受训或指导训练事实；T0904 后训练成长也同步增加总经验并可能产生未分配技能点。

T0904 起，`NPCSystem.increase_npc_skill(...)` 是统一成长入口。普通职业工作完成时会以很慢速度提升该行动配置的职业熟练度；诊所研读 / 治疗、训练场独自练习 / 受训 / 指导训练也复用同一入口。每次熟练度实际增加都会写入运行时 `progression.skill_experience` 和 `progression.total_experience`；当前每 5 点总经验产生 1 个 `unspent_skill_points`。技能点不由 AI 自动分配，必须由玩家在 NPC 面板或 GM 调试入口调用 `NPCSystem.assign_npc_attribute_point(...)` 分配到力量或智力。AI 后续可以根据背景、近期行为和目标给出建议或倾向，但不能自行消耗技能点，也不能直接改写力量 / 智力权威状态。属性分配会写入 `attribute_improved` 事件，summary 使用“守备官”。

T0502A 起，昏迷 NPC 不接收地点/广场公开广播、建筑/地点状态广播、公告或进入快照，见闻库暂停更新；事件库仍记录发生在自己身上的受伤、昏迷、复苏等亲历事件。复苏后见闻接收自动恢复，但不会补收昏迷期间错过的信息。

2026-06-03 起，睡觉 NPC 使用同一条见闻接收规则：当 `current_action == "sleep_in_dormitory"` 时，该 NPC 不会把同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照写入见闻库；自己的入睡和醒来仍进入事件库。睡醒回到可行动状态后，只从后续广播继续接收见闻，不补收睡觉期间错过的信息。

T1004/T1005/T1405 起，NPC 每天首次进入睡觉状态后，必须持续睡眠满 1 个游戏小时才会触发 `DailyReflectionSystem`。系统把当天事件库和见闻库摘要交给 `/npc/daily_reflection`（开发期可使用 Mock，Prompt 任务必须使用真实 API 验收），后端不可用时使用本地模板，生成第一人称日记、记忆摘要和知识图谱当前键值更新。总结从发起请求到应用完成期间，NPC 进入不可打断的深度睡眠锁：玩家对话、消息、行动改派和普通中断都会被拒绝；已入伍 NPC 仍可保存新指令，但计划重评估延后到醒来后执行。结果由 `NPCSystem.apply_daily_reflection(...)` 把 `diary_entry` 追加到长期 `diary`，并把 `knowledge_graph_updates` 按 `subject + relation` 替换式写入 `knowledge_graph.by_subject`；随后清空该 NPC 当天短期事件 / 见闻索引。NPC 面板可查看日记和 LLM 状态，GM 面板可强制触发、查看长期记忆和查看 LLM 状态。模板降级必须保留模型失败日志，不得用 mock 日记伪装真实模型成功。

T1305 起，胜利和失败结算会为每名 NPC 生成结局总结快照。`GameState.set_game_over(...)` 读取 NPC 当前权威状态、入伍状态、最后位置、长期日记和当天事件，生成确定性 Mock 字段：最终状态（可行动 / 昏迷 / 逃离）、是否入伍、对守备官最终看法、后续命运和记忆依据。该结局总结只用于 HUD 结算页展示，不会写回事件库、见闻库或长期记忆，也不会让 AI 反向改写 HP、逃离、入伍或地点事实。NPC 不死亡，因此结算文案不使用“阵亡”或“死亡”描述 NPC。

T0701-T0705 已实现 Godot 前端对话、最小征召、指令发布和主动交涉最小闭环。已入伍 NPC 可从 NPC 面板打开 `OrderPanel`，自由查看、修改并发布一条持续生效的 `current_order`；`NPCSystem.publish_npc_order(...)` 只在文本变化时更新指令、写入私有 `order_assigned` 并发出计划重评估请求。若 NPC 正处于首次睡眠总结锁，指令仍保存，但重评估延后到醒来后。T0015 后 GM 面板可调用 `NPCSystem.set_npc_recruited(...)` 将选中 NPC 设为入伍，用于调试指令、装备和训练入口；正式征召仍由对话中的同意结果驱动。`NPCSystem.debug_start_proactive_talk(...)` 可让 NPC 进入主动找守备官交涉状态，显示问号气泡，点击后打开既有对话面板并让 NPC 预先确定的开场问题先入库；1 小时无人点击则状态结束。

T1001 起，`DailyPlanSystem` 可生成规则版 24 小时计划并保存到 NPC `plan` 字段，写入 `plan_created` 事件，并按 `hour_started` 调用 `ActionSystem` 执行当前小时行动；同一小时内由计划启动的行动提前完成，会再次执行同一行动。T1002/T1005/T1006 起，行动异常、实际对话打断、主动交涉结束 / 超时、守备官攻击、战斗警报占位和新指令会触发计划重评估；玩家只是打开或关闭对话窗不会打断行动、不会取消 LLM、不会触发重评估。只有玩家真正发送消息或在对话窗中攻击时，才取消目标 NPC 正在等待的可取消 LLM 请求并打断工作、吃饭、睡觉等普通行动。若发送消息后未得到 NPC 回复就结束对话，本轮 LLM 请求会取消，且未完成的对话不入库、不触发对话重评估；攻击例外，攻击事实先扣 HP 并入库，结束时仍触发一次重评估。

T1003/T1403 起，首次制定每日计划可通过 `/npc/plan_day` 开发期 Mock 或真实后端生成 24 阶段计划，请求包含当前 `current_order`、短期/长期记忆、地点、资源、建筑状态和行动白名单；成功时写入对应来源，失败或输出不合法时写入 `plan_created(source=rule_plan_fallback)`。`/npc/plan_day` 真实 provider 路径已使用 `data/prompts/daily_plan_system_prompt.txt`，后端会校验 24 个 hour 覆盖、行动白名单和至少 6 个工作阶段，不合规则时记录 usage 失败并由 Godot 走规则计划降级。

T1004/T1005/T1405 起，首次睡眠总结可通过 `/npc/daily_reflection` 开发期 Mock 或真实后端把当天短期经历沉淀为长期日记和知识图谱当前键值，失败时模板降级；知识图谱同一 `subject + relation` 替换旧值，日记按条追加。T1402 后 `/npc/dialogue` 真实 provider 路径已使用 `data/prompts/dialogue_system_prompt.txt`，覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留；T1404 后 `/npc/battle_judgement` 真实 provider 路径已使用 `data/prompts/battle_judgement_system_prompt.txt`，并由后端拒绝越界低血量心理结果；T1405 后 `/npc/daily_reflection` 真实 provider 路径已使用 `data/prompts/daily_reflection_system_prompt.txt`，并完成真实 API 验收。Godot 客户端不保存供应商 API Key。

## LLM Mock 与真实 API 规则

Mock 只用于开发期验证 Schema、通信和自动化脚本。任何 NPC 对话、每日计划、计划修订、战时判定、逃离挽留、主动交涉或首次睡眠总结的 Prompt 打磨任务，都必须在基础 mock 测试通过后用真实 API Key 对相关业务路径做真实 provider 验收；没有真实 Key 时不能把 LLM 行为标记为完全完成。

真实 provider 失败、超时、无 Key、返回非 JSON 或 Schema 校验失败时，系统必须释放 TimeSystem 慢速请求，并在 usage / 日志中保留 request id、call_type、provider、model、NPC id 和真实失败原因。允许规则 / 模板降级维持计划、判定或睡眠流程，但降级来源必须可见；不得用 mock 回复、mock 计划或 mock 日记伪装模型成功。

T1401A 后，自动 mock fallback 默认关闭；只有显式 `LLM_PROVIDER=mock`、`/mock/model` 或显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试路径会返回 mock 内容。真实 provider 失败和模型输出不合 Schema 会作为错误或规则 / 模板降级暴露，并写入 `/debug/llm_usage`。

T1402 后，NPC 对话 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对 `/npc/dialogue` 的日常对话、提出应征、战时结构化意向和逃离挽留各完成一次真实调用，`fallback_used=false`。后续对话质量调参优先修改 `data/prompts/dialogue_system_prompt.txt`，不要把职业人设、NPC 档案或游戏设计全文硬编码进 Python 逻辑。

T1403 后，每日计划 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对 `/npc/plan_day` 完成一次真实调用，返回 24 阶段计划、只使用 `allowed_actions` / `idle` 且工作阶段不少于 6，`fallback_used=false`。后续计划质量调参优先修改 `data/prompts/daily_plan_system_prompt.txt`，不要把 NPC 档案、行动配置或游戏设计全文硬编码进 Python 逻辑。

T1404 后，战时公开对话与低血量心理 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对战时 `/npc/dialogue` 与 `/npc/battle_judgement` 各完成一次真实调用，返回的结构化意向均在允许枚举内，`fallback_used=false`。后续战时心理质量调参优先修改 `data/prompts/dialogue_system_prompt.txt` 与 `data/prompts/battle_judgement_system_prompt.txt`，不要把 NPC 记忆摘要、战场事实或允许结果写死进 Python 逻辑。

## 当前地点状态

T0304 起，NPC 运行时 `states` 会补齐以下地点字段：

- `current_location`：当前地点 id，默认 `plaza`，到达建筑后更新为建筑 id。
- `current_location_name`：当前地点显示名，到达建筑后由 `BuildingSystem` 填入。
- `movement_target` / `movement_target_name`：移动中的目标地点；到达后清空。
- `location_context`：地点当前状态读取占位，不包含地点历史事件。进入广场时包含当前广场在场 NPC、广场在场 NPC 状态、当前公告文本和所有建筑的可传播外部状态；进入可进入建筑时包含该建筑外部状态（等级、完好/受损/正在修复/正在升级）和内部状态（在场 NPC、建筑内 NPC 状态、每个工位的占用/空闲状态）。在场 NPC 状态分为生命状态和行动状态两个平行类别：生命状态只表达健康、受伤、昏迷；昏迷者如有治疗者会写明正在治疗的人，没有治疗者则不写。行动状态来自 `current_action`，但会翻译成精简中文，例如待命、前往食堂、吃饭、睡觉、协助治疗某人、协助修复某建筑。HP 具体数值、剩余修复/升级时长和工位数量不进入 NPC 需要传播的状态上下文。

这些字段先服务于最小行动闭环与后续见闻系统，不接 LLM，也不代表 NPC 已有真实日程计划。

## 事件、见闻与短期记忆

T0405 后，NPC 的短期记忆不再视为一个扁平文本列表，而由两类运行时记录组成：

- NPC 事件库：发生在该 NPC 身上的事件，例如醒来、制定计划、进入/离开地点、工作、吃饭、睡觉、对话、收到或修改守备官指令、被给予金钱/装备、升级、受击、昏迷、治疗、复苏、逃离等。
- NPC 见闻库：该 NPC 从地点/广场即时广播、状态变化广播、公告或他人公开事件中获得的信息；昏迷或睡觉期间暂停更新。

NPC 进入地点时，系统生成 `location_entered` 事件并写入进入者事件库；该事件只记录“某人进入了某地”，不附带完整建筑状态。进入者随后在见闻库获得一次当前状态快照：进入广场时获得当前广场在场 NPC、广场在场 NPC 的生命状态/行动状态、当前公告文本和所有建筑可传播外部状态，进入某个可进入建筑时获得该建筑外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态/行动状态和工位占用。已经在该地点的其他 NPC 只收到 `location_entered` 本地公开事件，不再额外收到完整人员状态。NPC 不会因为进入某建筑而继承该建筑过去发生的事件。

NPC 离开地点时，系统生成 `location_exited` 事件，`location_id` 使用其离开的地点；该事件写入离开者事件库，并以 `local_public` 广播给仍在该地点的 NPC。离开事件本身表达了“谁离开了这里”，不再额外广播完整 `people_present`。

NPC 从一个室内信息地点前往另一个室内信息地点时，当前实现会在事件和地点信息层插入广场中转：离开原地点、进入广场、离开广场、进入目标地点。物理表现仍是低模阶段的直线移动占位，不代表最终导航模型。

后续建筑或地点状态变化只进入字段级见闻，例如建筑受损、升级完成、公告变化或某个工位占用变化；未变化的建筑状态和在场人员不重复传递。对话全文也作为对话事件 `payload` 保存，供后续对话、计划和首次睡眠总结引用。

T0603 对话请求的目标 NPC 输入应包含 `npc_id`、`npc_name`、`npc_setting`、`npc_state`、`short_memory`、`long_memory` 和 `location_context`；说话者输入包含 `speaker_name`、`speaker_text` 和 `speaker_context`。T0703A 实现后，所有面向目标 NPC 的对话请求还必须加入该 NPC 的 `current_order`。如果说话者是守备官，名称固定为“守备官”；如果说话者是 NPC，`speaker_context` 应包含发起者健康/受伤状态与外表特征。NPC-NPC 对话由当前轮次与最大轮次控制，接近最大轮次时后端更倾向结束对话。

对 LLM 来说，亲历事件和见闻必须分开摘要：亲历对情绪和判断权重更高，见闻则代表当场听到/看到的信息、公共压力和场景认知。

面向 NPC 的所有玩家相关事件摘要、见闻摘要、对话上下文和后续日记/反思输入，必须把玩家称为“守备官”。“玩家”只作为开发文档里的外部说明词使用，不进入 NPC 可见文本或 LLM 世界内上下文。

当前运行时可通过 `MemorySystem.get_npc_short_term_memory(npc_id)` 获取 `{ event_log, witness_log }` 两个容器，也可通过 `get_npc_short_term_memory_ids(...)` 获取事件 ID 版本。`NPCPanel` 已分开显示事件库和见闻库，并使用固定高度滚动区避免记忆增长撑高面板；地点状态见闻会写明具体建筑名称和状态，例如“围墙受损”“食堂内现在有布鲁诺、莉娜”“在场人员状态：布鲁诺健康，行动：吃饭”“菜园里的 garden_plot_01 状态变为空闲”。T0704 后，守备官给钱可从 NPC 面板触发；T0901 后，守备官也可在 NPC 面板为已入伍 NPC 装备主武器，并可通过 GM 装备盔甲和坐骑。T1006 起，守备官攻击入口移入对话窗：攻击先复用 `NPCSystem.apply_damage_to_npc(...)` 扣 HP 并写入惩戒攻击 `damage_taken` 事件，再请求 NPC 对攻击作出 LLM 回复。给钱、装备和攻击会进入目标 NPC 事件库，公开交互会进入同地点 NPC 的见闻库，并随 `LLMBridge` 后续对话上下文的短期记忆摘要传给后端。“要求休息/请求治疗”不作为 NPC 面板按钮，相关意图由已入伍 NPC 的自然语言指令表达。

## NPC 行为层级

## NPC 行为模式

T1103A 起，NPC 当前模式已作为权威运行时状态保存在 `states.behavior_mode` 并可由 NPC 面板 / GM 快照展示。模式至少包括：

- `work` / 工作模式：沿用当前计划系统、行动异常、对话打断和计划重评估机制。
- `rally` / 集结模式：守备官摇响警铃后，已入伍、有主武器且当前可行动的 NPC 前往城门外防线；到达后等待接敌。
- `combat` / 战斗模式：已入伍且有主武器的 NPC 接敌后按兵种、装备、熟练度和守备官手动选择的战斗策略行动。
- `avoid_combat` / 避战模式：非战斗人员（未入伍，或已入伍但无主武器）遇敌后按敌人接近方位逐步远离，但不离开驿站；该模式不同于已入伍持武器 NPC 在战斗模式中的“避战策略”。

模式切换属于程序强制层。LLM 不能直接设置模式，只能通过结构化意向触发程序校验后的模式变化，例如战时对话结果触发逃离、避战对话同意应征后改变入伍状态、低血量心理判定触发斗志或逃离。低血量判定覆盖战时所有未昏迷、未逃离 NPC，但只有已入伍且有主武器、实际处于 `combat` 模式的 NPC 可获得斗志激昂或继续参战；避战 / 非战斗人员只可能触发逃离或继续避战。避战 NPC 只有在已入伍且有主武器、场上仍有敌军时才从避战切入战斗。当前 T1103A/T1103B/T1103C 已实现程序状态机、切换边界和非战斗人员避战移动；T1103D 起，工作 / 战斗与工作 / 避战互转不写入 `npc_mode_changed`，只保留避战开始 / 结束、攻击、受伤等具体事实事件；T1104 起，`combat` 模式中的入伍持武器 NPC 会按程序数值自动攻击范围内敌人并写入攻击事件；T1105 起，当前战斗策略由玩家在 NPC 面板手动选择，并由装备 / 兵种限制可选项。T1201 已实现战时公开对话心理结果；T1202 已实现低血量自身心理判定；T1203 已实现逃离驿站行为。

进入 `rally`、`combat` 或 `avoid_combat` 时，若 NPC 正在进行普通行动、移动、计划修订或可取消 LLM 活动，会被中断并进入新模式；若正在与守备官对话，会通过 `DialogSystem.force_end_dialogue_for_npc(...)` 强制关闭对话、取消未完成回复并进入新模式。睡觉 NPC 只有被敌人直接攻击时才从睡觉进入战斗或避战。

退出规则：

- `rally`：到达集合点后等待 1 游戏小时仍未接敌，返回 `work` 并继续当前计划，不触发计划重评估。
- `combat`：场上敌军全部消失后返回 `work`，并触发计划重评估。
- `avoid_combat`：场上敌军全部消失后返回 `work`；除非避战期间发生对话、受伤、应征等额外异常，否则不因单纯避战结束自动调用 LLM 重评估。T1103B/T1103C 已让非战斗人员进入避战后按敌方方位短距离四散移动；避战中被征召成功但仍无主武器时继续避战，装备主武器且仍有敌军时进入 `combat`，无敌军时回到 `work`。
- 昏迷复苏：有敌军时按入伍状态和主武器进入 `combat` 或 `avoid_combat`；无敌军时进入 `work` 并重评估计划。

NPC 行为分三层：

### 1. 程序强制层

不需要 LLM：

- HP 清零 → 昏迷
- HP 恢复到 30% → 复苏
- 饱食度过低 → 优先吃饭
- 疲劳过高 → 优先睡觉
- 工作位占用 → 等待、失败或换行动
- 警铃 → 符合条件的已入伍且有主武器 NPC 进入集结模式
- 已入伍且有主武器 NPC 接敌 → 进入战斗模式
- 战斗模式中的已入伍持武器 NPC → 由逻辑时间触发，并按玩家手动选择的当前战斗策略、战斗动作秒、装备、力量、防御和攻击间隔执行基础自动攻击或策略移动
- 非战斗人员接敌 → 进入避战模式，并按敌方方位生成短步长四散移动目标
- 战斗中敌军全灭 → 战斗 NPC 返回工作模式并重评估计划；避战 NPC 返回工作模式但不因单纯避战结束重评估计划

程序强制层触发吃饭、睡觉或工作时，只能启动持续行动；不能直接把饱食、疲劳、资源或产出改成最终值。权威数值应随逻辑时间推进，由程序按行动定义结算。

### 2. 计划层

低频调用 LLM：

- 每天早晨制定 24 小时计划
- 遇到重大异常后重新评估计划
- 守备官发布不同于原内容的新指令后立即重新评估计划
- 对玩家产生主动交涉意图

计划层的时间触发以 TimeSystem 的逻辑时间为准。T1001 规则版计划提供计划生成、保存、事件写入和按小时执行接口；计划项执行仍走 ActionSystem 的行动白名单、移动、工位、资源和状态结算。T1003 的每日计划生成通过 `LLMBridge.request_npc_daily_plan(...)` 调用 Model Adapter / 后端 `/npc/plan_day`，请求包含 `current_order`、人设、状态、技能、短期记忆、长期记忆、地点、资源、建筑状态和行动白名单；开发期可应用 Mock 24 小时计划，真实 provider 失败或输出不合法时应用规则降级计划并记录失败原因。T1002 的计划修订通过 `LLMBridge.request_npc_plan_revision(...)` 调用 Model Adapter / 后端 `/npc/revise_plan`，请求包含 `current_order`，但指令只提供倾向，不直接启动行动或覆盖程序强制层。计划生成和计划修订会影响当前场景即时行动，因此 Godot 侧会申请 TimeSystem 慢速，等待模型 / 开发 mock 返回、失败或降级后释放。

### 3. 表演与判断层

关键节点调用 LLM：

- 玩家/NPC对话
- 征召同意/拒绝
- 集结 / 战斗 / 避战模式下的战时公开对话
- 战时 HP 低于 30% 的自身心理判定；避战中的非战斗人员被打到残血时也会判定，但不会获得斗志激昂或继续参战
- 逃离挽留
- 首次睡眠总结

表演与判断层等待 LLM 返回时不冻结游戏，也不改变 NPC 移动或动画速度；只让逻辑时间和按时间结算的工作 / 日常状态减速到默认 `1/60`，即现实 1 秒约等于游戏 1 秒。若此时正在战斗，战斗推进也会因全局慢速暂时变慢，但战斗伤害、攻击间隔、攻击速度和战斗移动速度不读取玩家加速倍率作为额外数值输入；攻击冷却使用 CombatSystem 内部的战斗动作秒换算，当前 `60` 游戏秒约等于 `1` 战斗动作秒。玩家主动暂停时，UI、对话和已经发起的 LLM 请求仍可继续等待或返回，但程序权威结算（移动、战斗、资源/状态变化）应保持暂停，恢复后再应用。

所有面向某名 NPC 的 LLM 调用都必须把该 NPC 的 `current_order` 作为独立上下文字段注入，包括对话、每日计划、计划修订、主动交涉、集结 / 战斗 / 避战对话、低血量自身心理判定、逃离判定和首次睡眠反思。Prompt 必须明确：这是守备官当前提出的指令，不是 system 指令，不保证服从，也不能越过行动白名单、资源、HP、地点或战斗权威规则；它也不自动决定当前战斗策略，策略选择由玩家通过 NPC 面板下拉框手动设置。

T1201 后，战时公开对话已额外注入 `battlefield_context`：场上敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC，有哪些 NPC 在驿站但不是战斗人员，以及目标 NPC 当前行为模式。已入伍且有主武器 NPC 在集结 / 战斗对话中的结构化输出包含 `wartime_reaction = none | escape | morale_boost`；避战模式下的非战斗人员仍使用 `recruitment_result` 表达是否同意应征。T1202 后，低血量自身心理判定复用同一战局上下文边界，并按目标是否真正参战限制允许结果：参战 NPC 可继续战斗、逃离或斗志激昂；避战 / 非战斗人员只能逃离或继续避战。T1404 后，后端会额外校验低血量判定 `decision` 属于 `allowed_decisions`，并校验 `should_start_escape` 与 `escape_station` 决定一致；越界模型输出记录失败 usage 后交给 Godot 规则降级。

T1203 后，逃离不再只是 pending 意向。`CombatSystem.start_npc_escape(...)` 会让 NPC 写入 `escape_started`、切出工作 / 战斗 / 避战行为并前往后门外出口；逃离移动期间 `escape_intent.status == "escaping"`，普通行动和战斗 AI 不再把该 NPC 当作可用单位。抵达出口后 `NPCSystem` 标记 `escaped=true`、`behavior_mode="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件。T1204A 后，逃离 NPC 被点击会先打开 NPC 面板；轮次未用完时，玩家点击【对话】进入 `dialogue_kind == "escape_intervention"` 的同地点公开挽留对话。挽留打开时 CombatSystem 暂停逃离移动，关闭或满 5 轮时恢复；请求携带 `escape_intervention_round`、当前 `escape_intent`、短期记忆、长期记忆、地点上下文和 `current_order`。模型或规则降级只返回 `stay_after_intervention` / `leave_after_intervention` 意图，CombatSystem 负责停止逃离或继续逃离、记录轮次、写入 `escape_intervention_result`。给钱 / 守备官攻击分别调整程序权威的逃离移动倍率；逃离挽留中的攻击不向 NPC LLM 发送消息，不产生 NPC 回复，只计 1 轮并关闭面板。逃离期间昏迷会暂停为 `paused_unconscious`，复苏后继续逃离。

## 已入伍 NPC 指令机制

正式玩家指令系统不是 ActionSystem 的行动下拉，也不是 RTS 式强制命令：

- 只有 `recruited=true` 的 NPC 面板显示可用“指令”按钮。
- 点击后打开自由文本指令撰写与发布面板；已有指令会预填，供玩家直接修改。
- 点击“发布”时，新文本只有与原 `current_order.text` 不同才覆盖旧指令、递增修订号并触发后续效果。
- 指令变化会写入目标 NPC 的 `private` `order_assigned` 事件；summary 为“守备官制定了新的指令。”，完整新旧文本写入 payload。
- 指令变化后立即请求统一计划重评估入口；关闭面板或发布相同文本都不修改数据、不写事件、不触发重评估。
- NPC 后续是否执行、何时执行、如何调整或拒绝，由计划、判断、人格、记忆和现场状态共同决定。

`ActionSystem.debug_assign_*` 等直接行动接口仍可用于 GM 和自动化验证，但不代表正式玩家指令语义。

T0703A/T1002 后，统一重评估入口仍表现为 `EventBus.npc_plan_reevaluation_requested(npc_id, reason)`；`NPCSystem.get_last_plan_reevaluation_request()` 保存最近请求、最新 `current_order` 和处理结果供 GM / 自动化观察。`DailyPlanSystem` 监听该信号并调用 `LLMBridge` 修订计划；结果可能是模型 / 开发 mock 修订结果或 `rule_fallback_applied`，都会写入 `plan_revised` 事件并尝试执行当前小时行动。真实 provider 失败时必须保留失败日志，不得用 mock 修订伪装成功。`LLMBridge` 同时把最新指令注入对话、计划修订顶层输入和共享 NPC 上下文，并保存最近注入快照。

## 主动找玩家机制

NPC 可以在计划中选择“主动找玩家交涉”。T0705 当前先提供规则 / GM 调试触发；真实计划层主动意图仍归后续计划系统。

表现方式：

- NPC 头顶出现问号气泡。
- 玩家点击后进入对话；若有主动交涉状态，点击优先打开对话，不先打开 NPC 面板。
- NPC 想说的话在触发时已经确定，写入发起者事件库；点击气泡时不临时调用 LLM 生成开场。
- 对话结束后 NPC 重新评估计划。
- 若 1 游戏小时内未点击，主动交涉状态结束并重新评估计划。

当前运行时实现：

- `NPCSystem.start_proactive_talk(...)` / `debug_start_proactive_talk(...)` 设置 `states.proactive_talk`，并把 `current_action` 置为 `proactive_talk`。
- 触发时写入 `private` 的 `proactive_talk_started` 事件，payload 保存 `prompt_text` 和持续时间。
- `NPC.gd` 运行时创建 `ProactiveTalkBubble`，主动交涉有效时显示 `?`。
- 点击后 `DialogSystem.start_proactive_player_dialogue(...)` 复用玩家-NPC 对话窗口，把 `prompt_text` 作为 NPC 第一条历史显示，并写入 `proactive_talk_message`。
- 玩家后续回复继续走现有 `/npc/dialogue` 与 `dialogue_turn` 事件逻辑；开发期可用 Mock，Prompt 验收必须使用真实 API。
- 对话结束或超时后的计划重评估会进入 T1002 统一链路，应用模型 / 开发 mock 修订或规则降级计划；真实 provider 失败时不得自动 mock 成功。

触发原因：

- 想索要金钱、装备。
- 想询问信息。
- 想表达恐惧或不满。
- 想报告战场或地点见闻。
- 想主动应征、退出入伍或逃离。

## 征召机制

开局只有副官可接收守备官指令。
其他 NPC 必须通过对话同意应征后，才获得指令入口。

征召结果：

- 接受
- 拒绝

## 入伍后

NPC 入伍后仍然保留人格和记忆。  
玩家可以向其自由撰写工作、训练、休息、治疗、防守等指令，并直接管理装备；指令会进入后续 LLM 上下文，但不会硬性覆盖自主计划或权威结算。

## 关键原则

> NPC 的职业经历、熟练度倾向与记忆必须持续影响其行为。  
