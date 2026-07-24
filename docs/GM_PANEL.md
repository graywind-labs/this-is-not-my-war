# GM_PANEL.md

T0061 不新增 GM 命令或按钮。玩家可直接在 `Main.tscn` 的 NPC 面板“背景 / 日记 / 知识”查看移除代表性表达后的 9 项档案、八人相互拼接的身世 / 到站日记，以及叙事化建筑认识；“知识”详情只显示主体、关系和值。既有 `long_memory <npc_id>` 继续显示同一份完整运行态长期记忆，保留每条知识的 `confidence / day / time`，可用于核对玩家 UI 只是隐藏可信度与更新时间而没有删除底层字段，也可核对每人的守备官种子只有一条职位职责。GMPanel 不复制档案或记忆文案、不改写知识记录，也不创建第二套玩家显示规则。

T0060 不新增 GM 命令或按钮。其 8 人档案、3 篇种子日记和知识图谱继续由 NPC 面板与 `long_memory <npc_id>` 复用同一运行态来源；T0061 已取代当时的固定代表性表达、前两篇微观写法、守备官开放评估措辞和知识面板元数据展示。六类 payload 的日记时间标签仍由 LLMBridge 投影，GMPanel 不创建第二套时间事实。

T0059 不新增 GM 命令或按钮。NPC 面板“日记 / 知识”从 `Main.tscn` 开局即可直接阅读初始长期记忆；既有 `long_memory <npc_id>` 也会立即显示该 NPC 的 3 篇种子日记和当前 `key_value_replace_v1` 图谱。`reflect_npc <npc_id> force` 仍调用 DailyReflectionSystem，在种子基线上追加一篇真实 / 明确降级来源的反思并替换知识键；GMPanel 不自行生成、覆盖或结算记忆。

T0058 复用既有“驿站上下文”按钮与 `station_context` 命令，不新增入口。输出新增“公开基础资源（5）”，直接显示 LLMBridge 从 ResourceSystem 当前读取的粮食、餐食、木材、石料和铁；“精简驿站规则（6）”可看到升级缓慢推进、成员可协助加快的规则。该入口只读，不修改资源、启动升级、指派 NPC 或结算加速。

T0057 不新增 GM 入口：用“指定行动”为 NPC 安排依赖某座建筑的行动，在其前往途中或开始活动后，用建筑分组“升级”启动同一建筑升级；随后通过 NPC 最近行动结果与 `plan_request` 观察 `<action_id>_failed_building_upgrading`、`trigger_kind=action_failure`、建筑升级中文摘要和判别 / 按需修订结果。该组合只调用 ActionSystem、BuildingSystem 与 DailyPlanSystem 既有权威入口，GMPanel 不直接写失败原因或伪造重估。

T0056 不新增 GM 入口：基础 HP / 照料额外 HP、成长、逐马繁育概率与冷却都可在 `Main.tscn` 马厩面板直接观察；既有马匹查看、生态推进与强制繁育命令继续调用 HorseSystem，可辅助验证概率重置和冷却，但 GMPanel 不自行写繁育概率或冷却。

T0055 不新增 GM 入口：既有“驿站上下文”按钮与 `station_context` 命令会直接读取更新后的 `data/station_context.json`，现在应在“精简驿站规则（5）”中看到持续参与、周期完成后结算、离岗后不自行产出的规则。该入口仍为只读，不推进周期、不添加资源、不修改活动进度。

T0054 在“后端 / LLMBridge”分组新增只读“驿站上下文”按钮与 `station_context` 命令，调用 `LLMBridge.debug_build_station_context()` 显示当前正式请求会共用的 `setting_summary`、动态在站 `resident_roster`、完整 `building_roster`、配置化 `work_mode_actions` 和精简 `station_rules`。该入口只观察由 NPCSystem / BuildingSystem / ActionSystem 与 `data/station_context.json` 组合出的上下文，不新增或修改 NPC、建筑、行动、士气、逃离或战斗事实。

T0053 新增命令 `expire_plan_dialogues`，只调用 `ActionSystem.expire_invalid_daily_plan_dialogues()` 扫描当前已经存在的日计划对话等待，并显示实际过期的发起者 ID；它不创建 pending、不改计划、不伪造失败。自然日计划产生 `talk_to_npc` 且目标正在制定 / 重估计划后，可推进时间，再执行该命令并通过“最近行动结果”和 `plan_request` 观察 `talk_to_npc_failed_plan_superseded`、`trigger_kind=action_failure` 及判别 / 按需修订结果。正式日计划来源元数据只能由 DailyPlanSystem 派发写入；`npc_talk` 是 GM 直接动作，本身不会被跨小时计划项规则误判为过期。

T0052 未新增专用 GM 命令或按钮。前端按钮状态可直接在 `Main.tscn` 观察；需要构造内部时序时，先用既有 `plan_revise <target_npc_id> [reason]` 让目标进入 `kind=plan`，再立即执行 `npc_talk <speaker_npc_id> <target_npc_id> [opening_text]`，用 `llm_state <target_npc_id>` 与“最近行动结果”观察目标思考期间没有邀请 / 失败、计划结束后自动进入原邀请流程。GMPanel 仍只调用 DailyPlanSystem / ActionSystem / NPCSystem 的既有接口，不新增等待或对话权威。

T0051 未新增专用 GM 命令：弹窗拖动、三种会话按钮、橙点与头顶气泡都可在 `Main.tscn` 前端直接验证；既有“推进 1 小时”时间入口可连续触发两次，用于观察挂起会话的 2 游戏小时超时。GM 面板自身继续使用既有 GM 按钮拖动，不改为通用窗口 handle，也不增加第二套会话权威。

> 本文件记录 GM 调试面板的用途、入口、命令和维护规则。每次更新 GM 面板都必须同步更新本文档。

T0046 不新增 GM 入口：公告牌双 Tab、通告草稿取消、参考日程增删改 / 发布、日记只保留第一人称文本和知识图谱中文显示都可在 `Main.tscn` 直接手动验证。广场公告、地点快照、短期 / 长期记忆的旧 GM 查询继续复用同一底层接口，不创建第二个公告牌或长期记忆事实源。

T0049/T0050 不新增“强制判别”按钮。实际对话必须经 DialogSystem 自然结束、日常行动失败必须经 ActionSystem / DailyPlanSystem 权威失败链触发通用判别；GM 只通过既有 `npc_talk` 或“指定行动”构造真实场景，通过 `plan_request` 观察最近判别和修订结果。`plan_revise` 保留为非对话手动触发，固定修订当前小时，不能指定判别范围或伪造对话 / 失败事实。

T0043A 复用“指定行动”通用下拉，不增加重复专用按钮。下拉自动包含 `pray_at_chapel`、`lead_mass` 与新增 `attend_mass`：先把具备资格的 NPC 指派为 `lead_mass`，再给其他 NPC 指派 `attend_mass`，可观察祭坛 / 祈祷席占用；随后改派或中断主持者，可观察参加者的 `attend_mass_failed_leader_left` 与祈祷席释放。主持期间指派 `pray_at_chapel` 应得到互斥失败。诊疗 / 训练同理可先启动医生 / 教官和承载者，再改派服务者验证中断。

T0025 提供命令级验证入口 `npc_talk <speaker_npc_id> <target_npc_id> [opening_text]`：它只调用 ActionSystem 的自主对话公开入口。T0029/T0030/T0049 后，该命令便于构造“发起者追踪目标 → 目标先用真实 LLM 接受 / 拒绝 → 接受后才打断双方普通工作并释放工位 → 无硬轮次上限且由任一方结束标记收尾 → 拒绝或正式结束后双方各自判别计划 → 非空才修订精确小时”的链路，不在 GMPanel 内写对话、行动或判别事实。邀请等待或拒绝时不显示气泡；接受后双方显示可点击三点气泡，关闭旁听不会打断会话。因此无需新增重复 GM 按钮或命令。

## 目标

GM 面板用于把“已经实现但用户难以在主界面直接验证”的关键系统能力暴露到 `Main.tscn` 前端。它只调用已有系统接口或 `debug_*` 接口，不作为新的权威结算系统。

当前重点覆盖 M1-M4 已完成内容中原本主要靠脚本验证的能力：

- 资源增减、扣除失败和负数保护。
- 建筑选中、受损、倒计时修复、倒计时升级和全建筑外部状态广播。
- NPC 选中、状态修改、移动到建筑、立即进入地点。
- NPC 扣血、HP 清零昏迷、昏迷后行动阻断、昏迷自然恢复和复苏。
- 昏迷或睡觉期间见闻暂停；睡觉 NPC 不会接收同地点/同建筑 public 见闻，睡醒后恢复。
- 通过“指定行动”下拉统一指派工作、训练场教官/受训者、诊疗位/病床、普通祈祷、主持弥撒、参加弥撒、吃饭、睡觉等普通行动，并保留协助修复、协助升级、协助治疗昏迷者等带目标参数的行动调试入口。
- TimeSystem 设定时间、推进模拟小时、LLM 等待减速请求、有效倍率 / 慢速请求 / 时间上限请求快照。
- LLMBridge 后端 health check、开发期 NPC 对话 Mock、提出应征 Mock、正式请求共享驿站上下文快照，以及后端 LLM usage / 成本统计 / 预算状态 / 失败原因 / Godot LLM 等待运行态与逐请求慢速注册 / 释放查询。
- 地点快照、广场公告、广场公开事件、守备官给钱/攻击等记忆事件。
- NPC 短期记忆容器，区分事件库和见闻库。
- 已入伍 NPC 当前自然语言指令、修订号、最近计划重评估请求 / 应用结果、最近一次通用计划修改判别（含触发类型）和最近一次 NPC LLM 指令注入。
- 每日计划与 T1002/T1003/T0022/T0023/T0049/T0050 修订：通过真实 LLM 生成 24 小时计划，失败显示真实错误且不自动降级；另有明确分离的纯规则日计划调试入口。也可执行当前小时计划、查看当前计划、手动触发当前 NPC 的真实 LLM 当前小时修订。`plan_revise` 不产生 Mock 或规则修订，也不模拟对话 / 行动失败判别。
- 首次睡眠总结与长期记忆：触发当前 NPC 首次睡眠总结、查看长期日记 / 知识图谱当前键值、最近一次总结结果和当前 LLM 活动状态。
- NPC 主动找守备官交涉的调试触发、问号气泡状态，以及实际对话后的计划修改判别或无人响应超时后的当前小时修订。
- 具体装备系统：为已入伍 NPC 按具体物品库存装备主武器和盔甲，通过 HorseSystem 分配 / 取消分配具体马，并查看当前兵种判定快照。
- T0035-T0038 制造与马匹调试：设置铁匠铺 / 工械坊目标、提交单个阶段、查看项目 / 具体库存，以及查看、伤害、推进、强制繁育和分配逐匹马。
- T0904 成长系统：查看 NPC 总经验、未分配技能点，并由玩家把技能点分配到力量或智力。
- T0015 调试征召：可将当前选中 NPC 设为入伍，便于验证指令、装备和训练入口。
- T1101-T1304 敌人波次、目标优先级、双方基础攻击、战斗动作秒、警铃集结、非战斗人员避战、不同兵种战斗策略、敌人在场时间上限、战斗开始 / 结束流程、逃离驿站、逃离挽留、波次日程、失败条件和第 5 波胜利调试：生成第一波或指定波次敌人，按已触发记录跳到下一波，触发警铃集结，查看敌人目标 / NPC 集结 / 避战 / 逃离 / 挽留轮次 / 逃离速度 / 可战斗人员可用性 / 战斗策略 / 我方攻击 / 当前战斗 / 波次日程 / 最近战斗开始和结束结果 / 最近失败或胜利结果 / TimeSystem 倍率快照，模拟未入伍或无主武器 NPC 避战，手动触发 NPC 逃离，手动推进战斗 AI，清空当前敌人；T1104C 后敌人不再攻击围墙，城门破坏后转向仓库 / 主厅。T1105 的正式策略选择入口在 NPC 面板“装备武器”旁的下拉框，GM 只通过敌人快照观察当前策略，不另设权威策略按钮。

GM 命令仍可使用 `give_money` / `attack_npc` 这类开发语义；写入 NPC 事件库、见闻库和事件 summary 时，玩家身份必须显示为“守备官”。

## 开关

GM 面板脚本位于：

```text
res://scripts/ui/GMPanel.gd
```

顶部常量控制是否启用：

```gdscript
const GM_ENABLED := true
```

- 开发验证时设为 `true`。
- 上线、正式录屏或不希望显示 GM 时设为 `false`。
- 不要删除 GM 节点和文档；后续开发仍需要它作为不可见功能的验证入口。

## 界面

运行 `res://scenes/main/Main.tscn` 后，屏幕左侧会出现半透明 `GM` 按钮。

- 拖动 `GM` 按钮可改变位置。
- 点击 `GM` 按钮会在按钮附近打开或关闭 GM 面板；面板会随按钮位置重定位，并夹在可用屏幕范围内，避免固定覆盖左上角 HUD。
- 面板顶部有命令输入框和执行按钮。
- 面板中部分组提供常用按钮和输入框。
- 面板底部显示最近执行结果。

## 分组

资源：

- 选择资源 ID 和数量。
- 选择器会列出 11 个 `item_*` 具体成品库存；旧 `weapons / armor / defense_devices / horse_readiness` 聚合键不再出现，避免创建第二权威库存。
- 增加资源。
- 扣除资源。
- 查看资源快照。

时间：

- 设置天、时、分、秒。
- 推进模拟 1 小时：调用 `TimeSystem.debug_advance_hour()`，即使当前暂停也会按真实逻辑时间发出一次 `logical_time_tick(3600.0, 1.0)`，让建筑升级、行动周期、NPC 状态等订阅系统同步推进；单次调试推进上限为 1 游戏小时，避免跨过中间结算。
- 注册一次 GM 手动 LLM 减速。
- 清空所有减速请求。
- 查看时间倍率快照，包括玩家选择倍率、实际有效倍率、LLM 慢速请求和 TimeSystem 上限请求；T1104A 后生成敌人时可观察 `combat_enemy_presence` 上限，清敌后应消失。

建筑：

- 选择建筑。
- 打开建筑面板。
- 造成建筑受损。
- 调用修复；修复会先扣资源并创建倒计时作业，建筑快照可观察剩余时间、进度、协助人数和加速倍率。
- 调用升级；升级会先扣资源并创建倒计时作业。T0043 后开始升级会立即封闭建筑、清退室内 NPC 并释放位置，完成后可从建筑快照观察新增位置、效率和 Max HP。
- 查看建筑快照；T0043 后快照包含逐位置 `name/type/occupied_by/status`、`is_enterable`、condition、精确损伤 / 活动效率和逐级升级效果。
- 用“造成建筑受损”配合建筑面板和“推进模拟 1 小时”验证受损降效、修复跨效率分档、升级封闭和周期变化；GMPanel 只调用 BuildingSystem / TimeSystem，不自行改效率或位置。

制造 / 马匹：

- 制造行可选铁匠铺 / 工械坊与该建筑合法配方；“设置目标”保留换目标确认拒绝，“强制换目标”显式传入 `force=true`。
- “完成阶段”读取当前 `project_revision` 并调用 `CraftingSystem.complete_stage(...)`；材料不足、revision 过期、成品入库与项目重置仍由 CraftingSystem / ResourceSystem 结算。
- “制造快照”显示目标、revision、已完成 / 总阶段、当前阶段、部分进度、活动工人与具体成品库存。
- 马匹行按具体 horse ID 查看快照、扣 HP，按游戏秒推进马匹生态，或强制生成一匹小马；分配 / 取消分配同时使用当前 NPC 和马匹选项。
- 马匹入伍 / 主武器资格、成年状态、在厩位置、唯一分配、受伤、生态和繁育全由 `HorseSystem` 公开 / `debug_*` 接口处理；GMPanel 不直接写马匹字典。

NPC：

- 选择 NPC。
- 打开 NPC 面板。
- 移动到指定建筑入口。
- 立即进入地点信息节点。
- 设置 NPC 状态字段。
- 扣除 NPC HP；HP 清零后由 `NPCSystem` 触发昏迷；战斗中 HP 首次跌破 30% 且仍大于 0 时由正式低血量判定链路处理。
- 用自然恢复规则推进指定 NPC 的昏迷恢复，便于快速验证复苏。
- 查看 NPC 快照。
- 为已入伍 NPC 发布自然语言指令、查看当前指令，并查看最近一次计划重评估请求、对话后判别及其应用结果；未入伍 NPC 发布会被 `NPCSystem` 拒绝。
- 为当前选中 NPC 生成真实 LLM 24 小时计划、生成纯规则调试计划、执行当前小时计划、查看计划或立即触发计划修订；计划入口调用 `DailyPlanSystem`，不在 GMPanel 中自行决定行动结算。T0049/T0050 后 `plan_revise` 是非对话调试触发，固定以 `revision_hours=[current_hour]` 修订当前阶段；对话或行动失败的范围必须由真实会话 / 权威行动失败触发后的 LLM 判别产生。T0022 后 `plan_generate` 要求已配置的非 Mock provider，成功来源为 `llm_plan_day`；失败只显示真实错误，不规则降级。`plan_generate_rule` 仍是独立的显式纯规则调试入口，不会被正式开局或新一天调用。
- 为当前选中 NPC 触发首次睡眠总结、查看长期记忆、最近一次反思结果和 LLM 状态；首次睡眠总结入口调用 `DailyReflectionSystem`，不在 GMPanel 中自行写日记、清短期记忆或更新知识图谱。T0024 后 `reflection_result` 同时输出反思批次并发快照，包括上限、当前活动数、实际峰值、启动 / 完成数、请求 ID 和逐 NPC 结果；`llm_state` 继续只读取单个 NPC 当前活动与睡眠锁状态。
- 将当前选中 NPC 设为入伍；该入口只调用 `NPCSystem.set_npc_recruited(...)`，用于调试验证，正式征召仍由对话同意结果驱动。
- 触发当前选中 NPC 主动找守备官交涉，并查看该 NPC 的主动交涉状态；触发后 NPC 头顶出现 `?`，点击后进入既有对话面板。
- 通过 `npc_talk` 指定发起者、目标和可选开场目的，直接触发已有 NPC-NPC 自主对话行动；目标合法性、移动、邀请接受 / 拒绝、双方预定、接受后的工作打断、软性轮次指导和结束标记仍由 ActionSystem / DialogSystem 校验。
- 选择武器类型和盔甲部位，为当前选中且已入伍 NPC 装备武器或盔甲；装备入口调用 `EquipmentSystem`，只消耗该定义的具体 `item_*` 库存。坐骑不再使用通用“装备坐骑”入口，改由“制造 / 马匹”分组调用 HorseSystem 分配具体马。
- 查看当前选中 NPC 的兵种判定快照，包括主武器类型、武器 class、是否有坐骑和装备槽内容。
- 为当前选中 NPC 分配技能点到力量或智力；该入口只调用 `NPCSystem.assign_npc_attribute_point(...)`，无未分配技能点或属性已达上限时会失败。技能点由玩家分配，AI 只可作为后续建议来源。

行动：

- 指派指定行动；该下拉列出 `data/action_defs.json` 中的普通行动，包括工作、诊所、训练、吃饭、睡觉、普通祈祷和主持弥撒等入口，不包含需要额外目标参数的协助行动。
- 工作类行动会占用目标可进入建筑的真实工位，并按 NPC 对应熟练度、力量 / 智力属性和建筑等级缩短单位周期。T0035 后铁匠铺 / 工械坊必须先有合法目标，每个完整周期只向 CraftingSystem 提交一个阶段，阶段材料与具体成品由系统原子结算。T0037 后 `work_stable` 提供养马照料劳动，不再消耗粮食产出抽象马匹整备；马匹进食由 HorseSystem 按持续周期扣粮。菜园、酒窖等其他工作继续使用各自现有结算。工位占满、无目标或资源不足时由行动 / 权威系统返回失败。
- “指派行动”下拉可直接选择 `work_clinic_doctor` 和 `receive_clinic_treatment` 验证小诊所：医生自动占诊疗位、伤员自动占病床；多名在岗医生共同提高全部病床恢复，治疗随逻辑时间扣第纳尔。无病人时医生研读医学著作。
- 通过行动分组内的“修复目标”建筑下拉选择目标，再指派 NPC 协助该建筑的修复；协助修复是一个统一行为，建筑由该下拉或命令参数决定。
- 通过行动分组内的“升级目标”建筑下拉选择目标，再指派 NPC 协助该建筑的升级；协助升级同样是带建筑参数的统一行为。
- 通过行动分组内的“治疗目标”NPC 下拉选择昏迷目标，再指派当前选中 NPC 协助治疗；协助治疗是带目标 NPC 参数的统一行为，目标必须昏迷，每个昏迷目标最多 2 名治疗者。
- 训练、吃饭、睡觉、祈祷和主持弥撒都通过行动下拉指派；`train_instructor`、`train_student`、`eat`、`sleep` 等命令继续保留。多名在岗教官共同提高全部训练位成长；吃饭 / 睡觉分别申请用餐席 / 宿舍床位；普通祈祷申请祈祷席且不依赖神父，`lead_mass` 申请祭坛并验证“主持弥撒”能力。满位、封闭、无装备或无教官等日常计划行动失败仍由 ActionSystem 写入，并先触发通用计划修改判别，非空才修订所选阶段。

战斗 / 敌人：

- 选择敌人波次。
- “生成第一波敌人”固定调用 `CombatSystem.debug_spawn_wave(1)`，用于快速验证 T1101 第一波正门外生成。
- “生成所选波次”按波次下拉调用 `CombatSystem.debug_spawn_wave(...)`。
- “跳到下一波”调用 `CombatSystem.debug_trigger_next_wave()`，按 `CombatSystem` 已记录的 `triggered_wave_numbers` 触发下一未触发波次，用于快速验证 T1301 自动波次日程；该入口不修改时间、不自行写战斗事件。
- “警铃集结”调用 `CombatSystem.debug_trigger_combat_alarm()`，触发与 HUD 警铃相同的集结流程：所有 NPC 写入警铃事件，入伍且有主武器的可行动 NPC 前往城门外防线。
- “敌人快照”读取 `CombatSystem.debug_get_combat_snapshot()`，显示当前活动敌人数量、波次、波次日程、敌人目标、当前行动、NPC 集结状态、非战斗人员避战目标、逃离目标、逃离挽留轮次、逃离速度倍率、可战斗人员可用性 `combatant_availability`、入伍持武器 NPC 战斗策略、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量自身心理判定结果、最近逃离结果、行为模式快照、最近警铃结果、最近生成结果、最近 AI 推进结果、最近我方攻击结果、最近失败结果、最近胜利结果、最近模式切换结果、最近避战结果和 TimeSystem 倍率快照；T1104C 后可用该快照确认敌人目标不会是围墙，T1105 后可用该快照确认策略下拉框选择已进入 CombatSystem 状态，T1106 后可用该快照确认 `combat_started` / `combat_ended` 的运行态和结算统计，T1201 后可用该快照确认 `morale_boost` 或逃离流程的最近应用结果，T1202 后可用该快照确认 `last_low_hp_judgement_result` 与 `active_battle.low_hp_judgements`，T1204A/T0051 后可用 `active_escapes` / `last_escape_result` 确认逃离开始、挽留打开或挂起时持续暂停、完成 / 取消 / 满 5 轮后恢复、挽留后留下 / 继续、给钱减速、攻击加速且无 NPC 回复并自动完成、昏迷暂停、复苏继续和离站完成；T1301 后可用 `wave_schedule` 确认下一波、已触发波次和最近手动跳波结果；T1303 后可用 `combatant_availability` 和 `last_failure_result.reason == "no_available_combatants"` 确认无可战斗人员失败；T1304 后可用 `last_victory_result.reason == "five_waves_survived"` 和 `settlement_snapshot` 确认第 5 波胜利快照。
- “推进敌人AI”调用 `CombatSystem.debug_step_enemy_ai(60.0)`，用于手动推进 60 游戏秒的目标选择、移动、我方基础自动攻击和敌方攻击；T1104B 后这约等于 1 秒战斗动作。命名保留为兼容旧入口。
- “清空敌人”调用 `CombatSystem.debug_clear_enemies()`，删除当前 `Station/Enemies` 下由 CombatSystem 生成的敌人。
- “行为模式快照”调用 `NPCSystem.debug_get_behavior_mode_snapshot()`，查看每名 NPC 的 `behavior_mode`、进入原因、进入时间、当前行动和兼容 `combat_mode`。
- “模拟避战”调用 `CombatSystem.debug_trigger_npc_avoidance(selected_npc_id)`，用于让当前选中的非战斗人员（未入伍，或已入伍但无主武器）在已有活动敌人时进入避战，并按敌方方位生成短步长四散移动目标；已入伍且有主武器的 NPC 会被拒绝，按战斗逻辑处理。
- “触发逃离”调用 `CombatSystem.debug_start_npc_escape(selected_npc_id)`，用于让当前选中且未昏迷、未逃离的 NPC 前往后门外出口；该入口只触发正式逃离系统，`escape_started` / `escaped` 事件和 `escaped=true` 标记仍由系统结算。T1204A 后可用该入口制造逃离状态，再在主界面点击逃离 NPC 打开 NPC 面板，通过【对话】进入五轮挽留；也可用 `give_money` 或逃离挽留面板里的攻击按钮验证逃离速度变化。
- “推进集结等待”调用 `CombatSystem.debug_advance_rally_wait(3600.0)`，用于快速验证 NPC 到达集合点后等待 1 游戏小时仍未接敌会返回工作模式且不触发计划重评估。
- 该分组不自行结算伤害、集结结果、逃离结果或时间倍率，只调用 CombatSystem / NPCSystem / TimeSystem 的公开 / `debug_*` 接口；警铃集结会经 CombatSystem 调用 ActionSystem / NPCSystem / MemorySystem。T1104 后，我方攻击和敌人受击由 CombatSystem 结算并写入 `attack_made`，敌方攻击 NPC 先按 NPC 盔甲防御减伤再复用 `NPCSystem.apply_damage_to_npc(...)`，敌方攻击建筑复用 `BuildingSystem.apply_damage_to_building(...)`。T1104A 后，活动敌人存在时 CombatSystem 注册 `combat_enemy_presence` 时间上限，把 TimeSystem 有效倍率上限压到 `x1`，清敌后释放；T1104B 后，GM 推进 60 游戏秒约等于 1 秒战斗动作，便于观察攻速基准。T1106 后，战斗开始 / 结束事件和受伤 / 昏迷 / 击退统计由 CombatSystem 写入并通过敌人快照展示。T1201 后，敌人快照可观察最近一次战时对话心理结果和斗志 buff；T1202 后，通过生成敌人并用 `damage_npc` / NPC 扣血入口让 HP 跨过 30%，可在敌人快照观察低血量自身心理判定结果；T1204A 后，逃离调试、挽留暂停 / 恢复、轮次置灰、速度变化、逃离攻击无回复、昏迷暂停和正式逃离结果可在敌人快照观察。GM 仍只显示这些状态，不自行决定倍率、冷却、HP、击退统计、心理结果、逃离完成或胜负。

行为模式后续调试入口：

- T1103B/T1103C 已可查看每名 NPC 的 `behavior_mode`、模式进入原因和模式进入时间，并可推进集结等待时间；敌人快照可查看 `active_avoidances`，`avoid_npc <npc_id>` 可手动触发非战斗人员避战。
- 后续仍需补充可视化：当前敌人接触范围判定、斗志 buff 剩余时间的专用 UI。
- 手动触发 / 验证：战时心理结果、斗志 buff、低血量自身心理判定、逃离驿站和逃离挽留都可通过正式入口与敌人快照验证；低血量判定可用敌人在场时的 NPC 扣血入口触发，逃离可用 `escape_npc <npc_id>` 触发，挽留可在主界面点击逃离 NPC 打开 NPC 面板后点击【对话】触发。
- 查看最近一次战时对话的 `wartime_reaction`、`battle_psychology_result`、`morale_boost` / `escape_intent` 状态，最近一次低血量自身心理判定的 `last_low_hp_judgement_result`、`active_battle.low_hp_judgements`，以及逃离流程的 `active_escapes` / `last_escape_result`，其中 T1204A 会显示挽留轮次、速度倍率和暂停 / 继续状态。
- 这些入口只能调用 CombatSystem / NPCSystem / DialogSystem / LLMBridge 的公开或 `debug_*` 接口，不在 GMPanel 内自行决定模式、buff、逃离或战斗伤害。

后端 / LLMBridge：

- 后端健康检查，调用 `LLMBridge.check_health()` 并刷新 HUD 后端状态。
- 查看后端 LLM usage / 成本统计 / 预算状态，调用 `LLMBridge.debug_request_llm_usage()` 读取 `GET /debug/llm_usage`，显示 provider、model、调用次数、token、费用估算、fallback 次数、预算上限、已用量、剩余额度、最近预算错误、最近失败、HTTP 状态或异常类型、Schema 失败和降级来源；同时读取 `LLMBridge.debug_get_llm_runtime_snapshot()`，显示当前等待中的 LLM 请求数、pending slowdown request id、NPC 活动请求、异步请求数量、有效逻辑倍率、最近一次 TimeSystem 倍率变化原因，以及每个请求的 call_type、慢速是否注册 / 释放和时间戳。该入口只读，不申请 TimeSystem 慢速。
- 对当前选中 NPC 发送 `/npc/dialogue` 开发期 Mock 请求。
- 对当前选中 NPC 发送带 `is_recruitment_request=true` 的开发期应征 Mock 请求。
- 查看最近一次共享 NPC LLM 上下文注入的目标、调用类型和 `current_order`；`station_context` 显示当前在站成员、建筑、行为目录、五项公开基础资源和六条规则；`plan_request` 还显示最近一次通用 `plan_revision_judgement` 的 `trigger_kind`、结果及 `revision_hours`。
- 该分组只显示后端返回，不写入对话事件、不修改入伍状态。`dialogue_mock` / `dialogue_recruit` 只用于开发和 Schema 验证，不作为真实 API 验收；真实 provider 失败应通过 usage / 日志查看原因，不用 mock 回复伪装成功。

记忆 / 见闻 / 广场：

- 写入广场公告。
- 查看地点快照；广场快照包含当前在场 NPC 的 `people_statuses`、当前公告和所有建筑外部状态，可进入建筑快照包含该建筑外部 + 内部状态，`people_statuses` 可观察在场 NPC 的生命状态、行动状态和昏迷治疗者。
- 查看 NPC 短期记忆。
- 写入守备官给钱事件。
- 写入守备官攻击 NPC 事件。
- 广场公开广播事件。
- 查看全局事件列表。

上述玩家交互事件写入后，summary 应显示为“守备官给了……”或“守备官攻击了……”，不显示以“玩家”为主语的旧式文本。

## 命令

命令输入框支持以下命令：

```text
help
refresh
snapshot
events
plaza_events
add_resource <resource_id> <amount>
spend_resource <resource_id> <amount>
set_time <day> <hour> <minute> <second>
advance_hour
time_snapshot
slowdown [request_id] [scale] [reason]
release_slowdown <request_id>
clear_slowdowns
select_npc <npc_id>
select_building <building_id>
move_npc <npc_id> <building_id>
enter_location <npc_id> <location_id>
set_npc_state <npc_id> <key> <value>
recruit_npc <npc_id>
assign_attribute <npc_id> <strength|intelligence>
publish_order <npc_id> <text>
order <npc_id>
plan_request
plan_generate [npc_id|all]
plan_generate_rule [npc_id|all]
plan_execute [npc_id|all]
plan <npc_id>
plan_revise <npc_id> [reason]
reflect_npc <npc_id> [force]
long_memory <npc_id>
reflection_result
llm_state <npc_id>
start_proactive <npc_id> <text>
proactive <npc_id>
npc_talk <speaker_npc_id> <target_npc_id> [opening_text]
equip_weapon <npc_id> <weapon_id> [visibility]
equip_armor <npc_id> <slot> [visibility]
unit_type <npc_id>
craft_target <blacksmith|workshop> <recipe_id|none> [force]
craft_stage <blacksmith|workshop> [npc_id]
craft_snapshot [blacksmith|workshop]
horse_snapshot [horse_id]
horse_damage <horse_id> <amount>
horse_advance <game_seconds>
horse_birth
horse_assign <npc_id> <horse_id> [visibility]
horse_unassign <npc_id> [visibility]
spawn_wave [wave_number]
enemy_wave [wave_number]
next_wave
jump_wave
enemies
alarm
rally
step_enemies [game_seconds]
clear_enemies
behavior_modes
avoid_npc <npc_id>
advance_rally_wait [game_seconds]
escape_npc <npc_id>
assign_action <npc_id> <action_id>
work <npc_id> <building_id>
train_instructor <npc_id>
train_student <npc_id>
assist_repair <npc_id> <building_id>
assist_upgrade <npc_id> <building_id>
assist_heal <healer_npc_id> <target_npc_id>
eat <npc_id>
sleep <npc_id>
damage_building <building_id> <amount>
repair_building <building_id>
upgrade_building <building_id>
plaza_notice <text>
give_money <npc_id> <amount> [visibility]
attack_npc <npc_id> <damage> [visibility]
damage_npc <npc_id> <damage> [visibility]
recover_npc <npc_id> <game_seconds>
backend_health
llm_usage
dialogue_mock <npc_id> <text>
dialogue_recruit <npc_id> <text>
last_order_injection
memory <npc_id>
location <location_id>
```

`craft_target` 不带 `force` 时保留 CraftingSystem 的 `confirmation_required` 返回；只有显式追加 `force` 才放弃已完成 / 部分阶段。`craft_stage` 从当前项目快照取 revision 后调用权威接口，不自行扣材料或加库存。

`horse_damage / horse_advance / horse_birth` 分别调用 `HorseSystem.debug_damage / debug_advance / debug_force_birth`；`horse_assign / horse_unassign` 调用正式分配接口，不绕过入伍、主武器、成年、在厩和唯一分配校验。

常用示例：

```text
add_resource money 20
damage_building wall 15
repair_building wall
assist_repair engineer_01 wall
upgrade_building garden
assist_upgrade engineer_01 garden
damage_npc cook_01 150 local_public
assist_heal doctor_01 cook_01
set_time 2 9 30 0
time_snapshot
enter_location cook_01 dining_hall
work gardener_01 garden
work blacksmith_01 blacksmith
work engineer_01 workshop
work stableman_01 stable
work cook_01 tavern
assign_action doctor_01 work_clinic_doctor
assign_action cook_01 receive_clinic_treatment
train_instructor veteran_deputy_01
train_student stableman_01
eat cook_01
sleep priest_01
plaza_notice 今晚所有人都必须留在广场附近。
give_money cook_01 5 local_public
recover_npc cook_01 54000
backend_health
llm_usage
dialogue_recruit cook_01 守备官需要你一起保护大家。
publish_order veteran_deputy_01 守住城门，但先保证自己安全。
recruit_npc priest_01
order veteran_deputy_01
plan_request
plan_generate gardener_01
plan_generate_rule gardener_01
plan_execute gardener_01
plan gardener_01
plan_revise gardener_01 gm_manual
reflect_npc cook_01 force
long_memory cook_01
reflection_result
llm_state cook_01
start_proactive cook_01 守备官，我想知道我们还能不能守住这里。
proactive cook_01
npc_talk doctor_01 priest_01 诊所工位被占用了，我想和你协调一下。
add_resource item_bow 2
add_resource item_mail_chest 1
equip_weapon veteran_deputy_01 bow local_public
equip_armor veteran_deputy_01 chest local_public
craft_target blacksmith craft_iron_helmet
craft_snapshot blacksmith
craft_stage blacksmith blacksmith_01
craft_target workshop craft_wall_ballista force
horse_snapshot
horse_damage horse_chestnut_wind 10
horse_advance 3600
horse_birth
horse_assign veteran_deputy_01 horse_chestnut_wind local_public
horse_unassign veteran_deputy_01 local_public
unit_type veteran_deputy_01
assign_attribute cook_01 strength
spawn_wave 1
next_wave
alarm
enemies
escape_npc priest_01
step_enemies 60
clear_enemies
memory cook_01
location plaza
events
```

`unit_type` 只读取 `EquipmentSystem.get_unit_type_snapshot(...)`。只有 `horse_assign` 经 HorseSystem 完成具体马分配并同步 `equipment.mount.horse_id` 后，NPC 才可能被判定为骑乘兵种；任何聚合资源数量都不代表已分配马。

## 维护规则

每次完成任务验证时，Agent 必须判断本次功能是否能被用户直接在主界面看见和手动验证。

- 如果不能直接看见，但它是关键状态、数据、事件、AI、资源、建筑、NPC、时间、战斗、后端或 Prompt 调试能力，就必须给 GM 面板新增或替换入口。
- 如果新实现已经覆盖旧调试能力，应替换旧按钮或命令，不保留误导性的旧入口。
- GM 面板入口应该调用系统已有公开方法或 `debug_*` 方法；不要把数值结算、HP 扣除、记忆写入等权威逻辑写在 GMPanel 里。
- 每次更新 GM 面板时，同步更新本文件的“分组”“命令”和“常用示例”。
- 如果新增 GM 验证脚本或重要文件，同步更新 `docs/MODULE_INDEX.md`。

## 验证

T0061/T0059 使用下列专项验证开局种子、中文显示、六类 LLM 上下文和既有 GM 入口；T0061 额外核对 NPC 知识详情不显示可信度 / 更新时间，而 `long_memory` 的原始记录仍保留相关字段，不增加第二套长期记忆权威：

```powershell
godot --headless --path . --script res://tools/verify_npc_initial_long_memory.gd
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

T0022 覆盖下方长段中 T1003 的历史“Mock 计划和规则降级”口径：当前 `plan_generate` 是真实 provider 专用且失败不降级。正式 8 路并发、`llm_plan_day` 来源和 Mock provider 拦截分别由 `verify_game_startup_real_async.gd`、`verify_formal_plan_real_only.gd` 与 `verify_daily_plan_llm.gd` 覆盖。

GM 面板当前有专用验证脚本：

```powershell
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

T0043 的五建筑位置、资格、团队效率、损伤与升级封闭由下列专项脚本验证；它复用 GM 已有的行动、建筑伤害、升级、快照和时间推进接口，不新增第二套结算按钮：

```powershell
godot --headless --path . --script res://tools/verify_building_service_positions.gd
```

该脚本会加载 `Main.tscn`，检查 GM 按钮和窗口，执行命令验证资源、建筑、时间、时间倍率快照、NPC 地点、GM 入伍按钮、自然语言指令、每日计划生成 / 查看 / 执行、手动当前小时计划修订、首次睡眠总结入口、长期记忆查看、计划修订请求 / 结果、最近通用计划修改判别、最近 LLM 指令注入、训练场教官 / 受训者入口、敌人波次生成 / 跳到下一波按钮 / 警铃集结 / 快照 / AI 推进 / 清空、逃离命令、敌人在场 TimeSystem `x1` 上限注册 / 释放、记忆事件和广场公告。T0035-T0038 后还会验证资源选择器包含 11 个具体 `item_*` 且隐藏四个过期聚合键、制造目标 / 单阶段 / 成品入库，以及马匹快照 / 受伤 / 生态推进 / 强制繁育 / 具体分配 / 解除分配。T0904 的成长与技能点分配由 `tools/verify_skill_progression.gd` 覆盖；T1001 的计划执行细节由 `tools/verify_daily_plan_system.gd` 覆盖；T0023/T0050 的资源不足 / 工位占用触发、判别为空 / 非空、精确小时修订、Mock 隔离、真实计划修订和慢速释放由 `tools/verify_daily_plan_reevaluation.gd` 与 `tools/verify_action_failure_plan_revision_judgement.gd` 覆盖；NPC 当前计划入口、事件 / 见闻详情首次定位最新记录与刷新滚动保持由 `tools/verify_npc_panel_state.gd` 覆盖；T0029/T0030/T0049 的邀请接受 / 拒绝、无硬上限、软轮次参考、任一方结束标记，以及拒绝 / 正式结束后的双方独立判别由 `tools/verify_dialogue_invitation_contract.gd` 和对话判别专项覆盖；T1003 的显式开发 Mock 日计划由 `tools/verify_daily_plan_llm.gd` 覆盖；T1004/T1005 的首次睡眠总结、NPC 面板日记、短期记忆清空和对话 / LLM 打断边界由 `tools/verify_daily_reflection_system.gd` 与 `tools/verify_dialogue_sleep_summary_boundaries.gd` 覆盖；T1101 的敌人波次数据、正门外生成位置、GM 入口和清理流程由 `tools/verify_enemy_wave_generation.gd` 覆盖；T1301 的 HUD 倒计时、配置时间自动来袭、重复触发保护和 GM 跳波入口由 `tools/verify_enemy_wave_schedule.gd` 覆盖；T1102/T1104C 的目标优先级、跳过围墙、移动、敌方建筑攻击和主厅失败状态由 `tools/verify_enemy_target_priority.gd` 覆盖；T1103 的 HUD 警铃、GM 命令、阵型、骑乘表现和遭遇敌人切换由 `tools/verify_combat_alarm_rally.gd` 覆盖；T1104 的双方基础伤害、盔甲减伤、攻击间隔、敌人移除、清敌退出和避战不攻击由 `tools/verify_combat_damage.gd` 覆盖；T1104A 的战斗时间上限、LLM 慢速叠加和清敌恢复由 `tools/verify_combat_time_cap.gd` 覆盖；T1104B 的艾达持剑第一波节奏和战斗动作秒换算由 `tools/verify_combat_pacing.gd` 覆盖；T1105 的兵种策略选项、NPC 面板策略下拉框、策略事件、默认策略重置、战斗内避战和保持距离射击由 `tools/verify_combat_strategies.gd` 覆盖；T1106 的战斗开始 / 结束广播、受伤 / 昏迷 / 击退统计和清敌回工作状态由 `tools/verify_combat_flow.gd` 覆盖；T1203 的完整逃离移动、离站标记和事件由 `tools/verify_escape_station_behavior.gd` 覆盖；T1204A 的逃离警告、NPC 面板入口、对话打开暂停、关闭恢复、五轮置灰、给钱减速、逃离攻击无回复计轮、昏迷暂停和复苏继续由 `tools/verify_escape_intervention_dialogue.gd` 覆盖；T1303 的无可战斗人员失败、未集结误判边界和 HUD / 快照原因由 `tools/verify_no_available_combatants_failure.gd` 覆盖；T1304 的第 5 波胜利、结算快照、HUD 胜利占位和结算后拒绝刷波由 `tools/verify_five_wave_victory.gd` 覆盖。
