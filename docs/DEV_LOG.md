# DEV_LOG.md

## 2026-07-29 T0095/T0096 Pending 生命周期与熟睡总结水位

- ActionSystem 增加统一 `_is_action_commit_ready(...)`：暂停、尚在移动、地点不符或已有 active 时，fixed / target-aware pending 都不能申请工位或开始行动；逻辑 tick 也增加暂停保护。服务依赖和 NPC-NPC 对话的移动清理改为无信号收束，再提交唯一结构化失败。
- 新增 `verify_pending_action_pause_resume.gd`，穷尽 15 个固定地点行动与三类协助、拜访、NPC-NPC 对话，覆盖途中暂停、抵达临界帧、错误逻辑 tick、恢复同路线、恰好启动一次及目标失效一次失败。
- MemorySystem 新增短期正文 + 稳定 ID 原子快照和按快照 ID 选择性轮转。DailyReflectionSystem 记录上次成功请求终点，模型内容固定为该水位之后到本次请求快照；请求在飞期间新增的事件不会被旧回调清除，漏掉窗口也不推进水位。
- `DailyReflectionRequest` 新增必填 `summary_window / reflection_period`。日记按 21:00 窗口锚点写为“接到守备命令的第N天”，并保存实际触发日 / 时间与记录范围；Prompt 明确这是公告牌上“我们奉命守住此地”的公开命令，不是入伍、到站或个人指令。
- Pending、TimeSystem、弥撒、服务依赖、建筑入口、基础行动、计划目录、NPC 对话、协助治疗、熟睡总结、Schema、Mock endpoint 与 Prompt 回归通过。真实 DeepSeek `deepseek-v4-flash` 一次熟睡总结成功，4,751 tokens、估算 ¥0.004974、`fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 冻结启动正常，编辑器无错误；未新增 GM 权威。

## 2026-07-28 T0094 宿舍记录 UI、弥撒重估与跨夜熟睡总结

- 宿舍固定床位权威映射保持不变，BuildingPanel 改为通用 `床位X：空闲 / 某人占用中`。NPCPanel 在【对话】右侧新增小【记录】，只读筛选全局事件档案中的守备官—目标 NPC 完整会话，并按日期、时间与历史战斗事件还原波次分组。
- 固定地点行动开始前统一复验实际抵达；教堂祈祷增加最终到达守卫。弥撒开始会中断 active 与 pending 普通祈祷，释放位置并提交精确 `pray_failed_mass_started`；pending 路径先无信号收束移动 / 信息地点，再只发一次完整失败，修复暂停或移动边界下的异地祈祷与重估竞态。当前弥撒的明确对话承诺也会纳入当前小时修订，Prompt 保持“强倾向参加、非程序硬选”。
- 守备官第一条有效消息在真实中断前保存目标私有 `interrupted_activity_context`，明确打断前活动、当前计划及暂定恢复项；睡眠中 NPC 会知道刚被叫醒且计划不变时继续睡。该上下文不写入事件、见闻、日记或知识图谱。
- DailyReflectionSystem 从自然日首次睡眠去重改为 21:00 锚定窗口，同窗多段睡眠累计 1 游戏小时；对话叫醒不清零，失败不消耗窗口，只有成功应用才登记完成。复核发现的“请求在飞期间新增短期记忆可能被整批轮转”是既有异步边界，已登记 T0095，不阻塞本任务场景。
- 新增 / 扩展 UI、宿舍、弥撒运行时、睡眠对话与夜间窗口专项；相关 Godot、Python Schema、Mock / endpoint、Prompt、合同和项目解析回归通过。真实 DeepSeek 弥撒四次及睡眠打断对话一次均首次成功、无 fallback；Godot MCP 运行态确认文案、两段波次历史、只读记录边界和编辑器零错误。任务期间共记录 25 次真实调用、估算 ¥0.11752772，含专项 5 次、测试进程误用现有真实配置 4 次及两次主场景启动的 16 次日计划，已在 API_BUDGET 逐项披露。

## 2026-07-28 T0093 完成型行动连续计划段与建筑工期约束

- 复查确认另一个独立合同 bug：`DailyPlanSystem` 发送合法 `failure_type=action_completed`，但 `LLMBridge._normalize_plan_failure_type()` 未列入该枚举，正式 payload 会退化为 `unknown`；现已显式保留。
- 五类 `reevaluate_current_hour_on_completion` 行动配置不变。完成时从当前小时起按原计划 identity 收集连续相同 action + target，第一项不同即停止；完整小时数组一次进入正式修订，单小时、跨小时陈旧回调、当前小时即时派发、重复完成项拒绝和三次真实重试边界不变。
- 日计划、范围判别和正式修订 Prompt 各增加一条精简工期约束，要求结合 `game_time`、建筑总工期与剩余时间，只在预计完工前安排协助或作业影响，不把一小时升级铺满整个上午。
- Python Schema / Mock / endpoint / Prompt / 合同专项与 Godot 日计划、修订、完成策略、建筑升级和协助经验回归全部通过。连续三小时专项确认请求 `[8,9,10]`、第 11 小时不同任务不被夹带，并覆盖单小时与跨小时。
- 真实 DeepSeek `deepseek-v4-flash` 一次把 8–10 点三段 `assist_upgrade clinic` 改为 `work_clinic_doctor`，`fallback_used=false`，6,391 input / 142 output tokens，估算 ¥0.00378988。Godot MCP 4.0.1 / Godot 4.6.2 运行态确认枚举、helper 与五类配置，编辑器错误为空；既有 GM 入口足够，未新增调试权威。

## 2026-07-28 T0092 LLM 等价上下文与响应合同精简

- Model Adapter 在六类正式调用的 provider 边界删除 `meta`、`null`、重复人物 / 轮次 / 资源 / 日记 / 战局副本及分支外字段；人物、记忆、指令、实时现场和动态白名单保持不变。LLMBridge 不再重复发送默认日计划规则。
- 六类 provider 输出合同移除固定回声与可推导字段；后端补齐响应 envelope、NPC / 日期、分支结果、派生布尔值、即时行动和候选 `action_kind / priority / 唯一 location_id`，完整 Schema 与业务校验不变。
- 同形样例输入字符减少 3.62%–11.49%，输出字符减少 7.47%–61.30%。真实同 ID 对话 input/output tokens 下降 5.70% / 27.50%，行动失败范围判别下降 9.12% / 39.29%。
- Python 编译、17 个后端专项、7 个 Godot 专项、项目解析和隔离 Mock 桥接通过；Godot MCP 4.0.1 / Godot 4.6.2 连接正常且编辑器无错误。
- 六类 DeepSeek `deepseek-v4-flash` 真实路径均成功、`fallback_used=false`；保留 `emotion / morale_delta_intent / summary / reason / dialogue_goal / debug_reason` 等进入事件、UI、记忆或诊断的有效字段。既有 GM 日志与用量入口足够，未新增调试权威。

## 2026-07-28 T0091 `talk_to_npc` 目标驱动计划合同

- 复盘诊所工位冲突确认范围判别已触发，正式修订失败源于模型返回物理上正确的 `clinic`，而旧候选用 `location_id=null` 表示动态追踪；这是表示合同冲突，不是模型选错地点或重估未触发。
- `LLMBridge` 与后端 provider payload 不再向 `talk_to_npc` 候选提供地点；两个计划 Prompt 要求只选目标 NPC。DailyPlanSystem 不保存对话地点，ActionSystem 继续执行时查询并追踪目标实时位置。
- 后端按 action + target 校验对话候选，把供应商冗余地点规范化为 `null` 并记录 `dynamic_npc_target`；固定工作、拜访和协助行动继续精确校验 action / target / location，白名单外目标和自聊仍拒绝。
- Python 编译、Schema / Mock、plan_day / revise endpoint、Prompt 和目标合同专项通过；6 个 Godot 目录 / 执行 / 边界专项与 editor 解析通过。Godot MCP 4.0.1 连接 Godot 4.6.2，编辑器错误为空。
- 真实 DeepSeek 修订返回 `talk_to_npc -> priest_01 / location_id=null`、合并后 6 个工作阶段；NPC-NPC 邀请也成功。2 次调用合计 13,144 tokens、估算 ¥0.00932104，均 `fallback_used=false`。既有 GM 入口足够，未新增调试权威。

## 2026-07-28 T0090 开发期额度重置与请求预留校准

- 复盘开局卡在“制定计划”：当日已结算 ¥6.514753 时，7 路在途按 ¥1.77 共预留 ¥12.39，第 8 路会投影到 ¥20.674753 并被预算门禁阻止；Godot 在其他请求完成前立即耗尽欧文的 3 次重试，最终 7/8 成功且正式开局按既有规则保持暂停。
- 清理前统计上海自然日 347 次真实 provider 尝试：总计 ¥6.58959012、均值 ¥0.01899017、P95 ¥0.02998008、P99 ¥0.03258096、最大 ¥0.04262264。当前 Flash 请求预留改为 ¥0.05，约为均值 2.63 倍并高于实测最大值约 17%；8 路总预留由 ¥14.16 降为 ¥0.40。
- 停止本项目后端后备份完整账本，只删除 `day=2026-07-28` 的 347 条并保留其他日期 23 条；配置验收产生的两条真实对话费用 ¥0.00327664 也在二次备份后清除。两个备份均位于被忽略的 `backend/logs/archive/`。
- `.env`、示例配置、ModelAdapter Flash 默认值、后端 README、预算专项和 API 成本文档同步为 ¥0.05；每日 ¥20、实际 usage 结算、失败关闭、429 和禁止自动 Mock fallback 不变。该值不再覆盖供应商理论极端最大上下文，模型 / Prompt / 价格 / 上下文或费用分布变化时必须重估。
- Python 编译与 `verify_api_budget_debug.py` 通过。两次真实 DeepSeek 私有边界对话均成功且无 fallback；第一次只因脚本漏收“无从知晓”同义词失败，补充后通过。最终后端健康快照确认今日 0 次 / ¥0、在途 ¥0、剩余 ¥20、预留 ¥0.05。

## 2026-07-28 T0089 教堂失败后的弥撒 / 祈祷优先修订

- ActionSystem 为所有行动失败上下文补入精确 `failure_id`，让 LLM 两阶段计划链在保持通用 `failure_type=target_unavailable` 的同时能稳定识别教堂互斥和主持依赖失败。
- 范围判别在反向教堂候选当前可用时固定选择当前小时；正式修订对“普通祈祷失败→参加弥撒”和“参加弥撒失败→普通祈祷”增加保持原意的强倾向，同时保留人物、状态、记忆、指令、紧急事实和动态白名单的判断空间。
- Prompt、Schema、Mock、endpoint、教堂依赖、行动目录、日计划与项目 smoke 回归通过。真实 DeepSeek `deepseek-v4-flash` 对两个方向各 1 次判别 + 1 次修订，四次均首次成功、`fallback_used=false`。
- Godot MCP 4.0.1 / Godot 4.6.2 运行态确认两个失败方向均保留精确失败码且反向候选 `available_now=true`，编辑器错误为空；复用既有 GM 指定行动、当前计划、`plan_request` 和 LLM 日志，未新增调试权威。

## 2026-07-28 T0088 建筑工期信息、平缓时间显示与入伍颜色

- TimeSystem 新增统一时钟 / 时长格式：正常 `x1 / x2 / x4` 冻结显示秒为 `00`，倒计时向上取整到分钟；LLM 慢速请求期间恢复游戏秒，并由倍率信号即时刷新 HUD 时钟、波次倒计时与当前建筑面板。
- BuildingSystem 的修复 / 升级状态保留权威 `duration_seconds / remaining_seconds`，新增 `duration_text / remaining_text`。MemorySystem 在开始作业差量中传播 active job 与总工期，LLMBridge 投影可读总工期、剩余时间、进度和协助人数，不向模型提供裸秒数。
- `NPC.tscn` 把世界姓名与 HP / 当前行动拆为两个 Label3D；入伍后仅世界姓名和 NPC 面板姓名使用淡绿色，既有 `npc_state_changed` 即时刷新链保持不变。
- `verify_time_system.gd`、`verify_building_repair_upgrade.gd`、`verify_npc_panel_state.gd` 增加正常 / 慢速显示、总工期传播、LLM 上下文和颜色覆盖；地点信息、动态上下文、Schema / Prompt 回归均通过。
- 真实 DeepSeek 升级协助对话、携带进行中工期的计划修订及完成后修订均 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 实机确认 `09:12:00 / 0小时20分00秒` 与慢速 `09:12:37 / 0小时19分53秒`，姓名 / 状态颜色分离，编辑器无新增错误。所有功能可从 Main 直接验证，未新增 GM 入口。

## 2026-07-28 T0087 拆分对话输出合同并删除失效意图

- 删除通用 `DialogueIntent`；`/npc/dialogue` 按 `dialogue_kind` 选择 `PlayerNPCDialogueResponse / NPCNPCDialogueResponse / EscapeInterventionDialogueResponse`，三者禁止额外字段。旧 `request_* / share_witness / start_escape` 与通用 `continue_talk / end_talk` 不再属于对话输出。
- 应征只读取 `recruitment_result`，修复“拒绝应征但文本仍愿继续谈”被重复 intent 业务校验误杀的问题；NPC-NPC 只读取 `invitation_result / should_end_dialogue`，逃离挽留改读 `escape_intervention_result=stay|leave`。
- Prompt、动态 schema hint、Mock、Godot DialogSystem / CombatSystem、审计导出和全部相关测试同步；非权威元数据 `null` 只做带记录的默认化，业务枚举和跨分支字段仍严格失败。
- Python Schema / Mock / Prompt / endpoint / 业务合同通过；10 个 Godot 对话专项通过，Godot MCP 4.6.2 编辑器无错误。真实 DeepSeek 完成玩家、NPC-NPC、应征、战时、逃离、邀请接受 / 拒绝和正式收尾，最终均 `fallback_used=false`。
- 真实合同验收 19 次约 ¥0.03678208；一次未显式覆盖 `.env` 的 Godot UI 回归误走 4 次真实对话，约 ¥0.09114248，已在 API_BUDGET 记录。功能可直接从 Main 对话验证，现有 LLM 日志 / 事件 / 逃离入口足够，无新增 GM 权威。

## 2026-07-28 T0086 提前完成计划行动续接与倍速快捷键

- 审计 25 个配置行动后，将会提前解决目标 / 较早结束并造成明显空档的 `assist_repair / assist_upgrade / assist_heal / receive_clinic_treatment / drink_wine` 标为 `reevaluate_current_hour_on_completion=true`；循环生产、持续服务和吃饭 / 睡觉 / 祈祷 / 弥撒 / 拜访等常规或整小时行动保持原策略。
- DailyPlanSystem 兼容建筑协助、协助治疗、病床和饮酒的不同成功结果；完成后 deferred 确认权威 day / hour、原计划 identity 与 NPC 状态，同小时直接以 `action_completed` 只修订当前小时，跨小时则由正常整点派发接管。当前小时修订成功后立即执行；原样重复相同 action + target 会被 Godot 拒绝并在既有 3 次真实修订边界内重试。
- 后端 Schema 与计划修订 Prompt 增加 `action_completed` 语义和不同后续活动约束。专项覆盖五类配置 / 完成结果、单链请求、重复拒绝、即时执行与跨小时；Schema、Mock、Prompt、升级、完成策略、协助经验和时间回归通过。真实 DeepSeek `deepseek-v4-flash` 一次把完成饮酒后的当前小时改为 `work_clinic_doctor`，`fallback_used=false`。
- HUD 新增主键盘数字行 `1 / 2 / 3 -> x1 / x2 / x4`，排除小键盘、修饰键和文本输入焦点，并在速度按钮 tooltip 提示。Godot MCP 4.0.1 / Godot 4.6.2 通过真实物理键 `3` 确认切到 `x4`，直调小键盘保持倍率，编辑器错误为空。
- 既有 GM 行动、建筑、治疗、时间、计划 / `plan_request` 和 LLM 日志入口足够验证，未新增 GM 权威。`verify_assist_timed_experience.gd` 仍报告其既有 ObjectDB exit leak warning，但测试退出码为 0，本任务专项与编辑器均无新增错误。

## 2026-07-28 T0085 修复升级协助完成后的计划重估

- 后端持久化日志确认：升级完成后的范围判别正确选中当前小时，真实 DeepSeek 六次修订都返回 `work_clinic_doctor`，但 `assist_upgrade` 未被 Godot Schema 工作统计识别，导致 `current_work_phase_count=0`，后端再以 `merged plan must keep at least 6 work phases` 拒绝；3 轮 Godot 重试叠加后端纠错共耗时约 32.2 秒。
- `LLMBridge` 统一把 `assist_upgrade` 计作劳动，并在计划 Schema 导出时优先保留 `target.location_id=plaza`；`BuildingSystem` 在工程完成时清空协助者陈旧失败上下文，`DailyPlanSystem` 为已结束的升级 / 修复生成本轮 `no_active_*` 上下文。
- 移除 `/npc/plan_day`、`/npc/revise_plan` 以及 Godot 日计划应用 / 修订合并的最低 6 工作阶段硬拒绝。三份计划 Prompt 仍将通常至少 6 阶段作为强建议，并禁止仅为凑数扩大修订范围；小时覆盖、白名单、目标 / 地点和即时行动合同保持为硬校验。
- Python 契约 / Schema / endpoint / Prompt、Godot 升级完成专项、日计划、重估、行动失败、建筑升级与项目 smoke 回归通过。真实 DeepSeek `deepseek-v4-flash` 对升级结束返回 `work_clinic_doctor @ clinic`，`fallback_used=false`；Godot MCP 4.0.1 / Godot 4.6.2 连接正常且编辑器错误为空。
- 现有 GM 入口足以验证，不新增按钮或权威结算；真实验收 1 次对话 + 2 次修订账本估算约 ¥0.00989。

## 2026-07-28 T0084 按叙事到站顺序固定宿舍床位

- `building_defs.json` 将床位 1–8 按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜配置固定归属，9–10 号保留未分配。
- BuildingSystem 在通用位置申请中区分 `assigned_npc_id` 与 `occupied_by`：有专属床者只申请自己的床，无专属床者只能申请未分配床；完成、中断、失败和封闭释放不改变归属。
- BuildingPanel 逐床显示“NPC 专属（空闲）/ 占用中（专属）”及“空余床位”，ActionSystem 继续复用既有睡眠生命周期与结构化失败链，不维护第二份映射。
- 新增固定床位专项；建筑面板 / 位置、基础行动、结构化事件、日计划、首次睡眠总结和项目 smoke 回归通过。Godot MCP 4.6.2 确认布鲁诺重复申请始终为 3 号床、运行态占用文案正确、编辑器错误为空。
- 功能可从主场景宿舍面板直接验证，未新增 GM 入口；未修改 Prompt、后端或模型行为，未调用真实 provider。临时静止调试验收后已恢复 `startup_mode=1`。

## 2026-07-28 T0083 精简对话事件标题与应征结果反馈

- 完成守备官会话的确定性 summary 标题由“守备官与 XX 的完整对话”精简为“守备官与 XX 对话”，逐句正文和单事件边界不变。
- `DialogSystem` 把合法 `accept / reject` 附在产生结果的 NPC history turn；`DialogPanel` 在同一回复块下一行显示绿色对勾接受或红色叉号拒绝，真实 `reply_text` 不变。
- 对话 UI 专项新增接受 / 拒绝富文本断言，会话生命周期新增精确标题断言；结构化记忆、NPC 面板和静态主场景 smoke 回归通过。
- Godot MCP 4.6.2 运行态确认两种颜色 / 符号、逐回复元数据、精简标题、事件正文仅含真实发言和编辑器错误为空；临时 `startup_mode=0` 已恢复为 `1`，显式 Mock 服务已关闭。
- 本任务不修改 Prompt、后端接口或模型判断，不调用真实 provider；功能可直接在主场景验证，未新增 GM 入口。

## 2026-07-28 T0082 多轮会话事件摘要与应征会话锁

- Godot MCP 复现确认两轮会话的 `payload.dialogue_text` 完整保留四句，但事件 `summary` 只显示第二轮；根因是 MemorySystem 使用 `last_player_text / last_reply_text` 生成守备官完成会话摘要，NPCPanel 又只读 summary。
- `MemorySystem` 对 `session_completed=true` 的 `dialogue_turn` 改为按 `dialogue_text` 原顺序逐句生成确定性全文摘要；仍是一条事件和一次公开广播，NPC-NPC 逐轮摘要不变。
- `DialogSystem` 不再在发送后清除 `recruitment_request_pending`；第一次应征消息设置 `session_had_recruitment_request` 后，系统取消入口永久拒绝本场取消，挂起超时按完成。`DialogPanel` 同步 disabled 与专用 tooltip。
- 对话生命周期新增两轮四句单事件、NPC 事件库详情全文、sticky toggle、后续消息标记、主动关闭、取消锁和挂起超时完成覆盖；对话 UI 及记忆 / NPC / 主动交涉 / 战时 / 逃离 / 计划恢复回归通过。
- 本任务未修改 Prompt、Schema、后端接口或正常 LLM 调用频率，不需要真实 provider 效果验收；GM 复用既有事件查询与推进时间入口，未新增权威入口。
- 首次以正式 `startup_mode=1` 启动 Godot MCP 时，既有启动流程自动触发 8 路 DeepSeek 日计划，账本估算增加约 ¥0.125404；随即停止。最终运行态改用临时静止调试 + 显式 Mock，确认 UI / 事件后恢复 `startup_mode=1`，编辑器错误为空。

## 2026-07-28 T0081 统一持续行动生活消耗与协助成长

- 新增 `data/activity_needs.json` 与 `NPCNeedsSystem`，把 idle、对话、拜访、移动、工作、训练、进食、睡觉、病床、祈祷、饮酒、集结、避战、逃离、战斗和昏迷恢复统一为“点 / 游戏小时”的连续饱食 / 疲劳档位；每名 NPC 每个 tick 只命中一个档位，小数余数逐人累积，行动中途结束后剩余时间按 idle 结算。
- `data/action_defs.json` 的 25 条行动定义全部改用唯一 `needs_profile`，移除四类旧生活增量字段。修复、升级和协助治疗新增 `timed_experience`，分别按真正推动作业 / 治疗的有效时长每小时增加 1 点工程 / 医术；目标中途完成或复苏后不多算生活消耗与经验。
- 新增 `verify_activity_needs_framework.gd` 动态穷尽全部行动定义和全部行为模式，新增 `verify_assist_timed_experience.gd` 覆盖修复、升级、治疗的分段与中途完成结算；行动、训练、诊所、战斗、避战、逃离、移动、时间、饮酒、吃饭等相关回归与主场景 headless 启动通过。
- Godot MCP 4.6.2 冻结 Main 并步进运行，确认 `NPCNeedsSystem` 已加载、25 条行动定义及生活配置无错误。现有 NPC / GM 状态快照已经可直接观察饱食、疲劳和经验，因此未新增 GM 控件。

## 2026-07-28 T0080 建筑门口失败重估与升级协助认知修复

- 审计 `backend/logs/llm_calls.jsonl` 确认工程师的真实请求一直收到 `assist_upgrade` 候选，但模型把目标建筑误当执行地点；同时 Godot / 后端没有把该行动计入最低工作阶段，促使模型用铁匠铺工作维持工作量。另发现建筑状态投影读取了不存在的便利布尔字段，日志中的 `is_upgrading` 因而失真。
- 升级状态变化现在只立即中断室内 active 依赖行动。路上 pending 保留移动；NPC 到入口且被 BuildingSystem 拒绝后，NPCSystem 收束到广场并发入口失败信号，ActionSystem 才写 `arrival_check_failed / interrupted_phase=pending` 的唯一结构化失败并触发既有两段式重估。
- `assist_upgrade` 候选明确为广场 / 室外、无需进入、当前可用并计入工作阶段；DailyPlanSystem、后端日计划 / 修订校验和四份 Prompt 统一该语义。实时升级 / 修复布尔状态改由 BuildingSystem 接口生成。
- Python Schema / Mock / Prompt / endpoint、Godot 升级失败 / 动态上下文 / 日计划 / 建筑回归及项目 smoke 通过。真实 DeepSeek 对话明确可在广场协助，正式修订选择 `assist_upgrade(workshop, plaza)`，均 `fallback_used=false`。
- Godot MCP 4.6.2 冻结 Main 验证路上未失败、门口才失败、室内 active 立即失败、候选与升级状态正确；编辑器错误为空。现有 GM 入口足够，未新增控件。

## 2026-07-28 T0079 当前计划连续时段与重复说明收束

- `NPCPanel` 将连续、完整展示语义相同的小时项合并为可见时段；当前小时命中区间时由整段显示 `▶`。不同来源、目标、优先级、对话目的或可见说明不会误合并。
- `reason.strip_edges() == action_name` 时只在 UI 投影中隐藏第二行，权威 24 小时计划、原始说明、来源和执行合同不变；Prompt、Schema、后端均未修改。
- 首次打开定位改为按可见分组取当前时段前两项；刷新、不同说明拆段及 00:00 / 01:00 边界保持原体验。
- `verify_npc_panel_state.gd`、NPC 面板交互、日计划系统和项目 headless 加载通过。Godot MCP 4.6.2 冻结运行确认 `▶ 13:00–16:00  酿造酒｜真实 LLM 日计划`、行动名只出现一次、重复说明隐藏，编辑器错误为空；未新增 GM 入口。

## 2026-07-27 T0078 NPC 主动交涉收口、必改当前小时与取消锁

- NPC 发起的守备官会话完成后，若结束时当前计划仍为 `seek_guard_officer`，范围判别固定携带当前小时；正式修订沿用正常动态候选与 T0076 立即 / deferred 派发。
- `DialogPanel` 在主动交涉中禁用取消按钮并显示专用 tooltip；`DialogSystem` 同步拒绝直接取消。守备官主动普通会话仍可取消，主动交涉挂起两小时后按完成入库并进入判别。
- 真实 provider 验收发现仅靠 Prompt 会偶发遗漏 required 小时；后端现保留模型其他合法选时并权威归并程序 required 集合，以 `model_normalizations` 留痕，不替模型生成行动。
- 主动交涉、普通会话生命周期、当前小时派发、NPC-NPC、Schema / Prompt / Mock 与真实 DeepSeek 专项通过；Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认按钮 disabled、专用 tooltip、系统取消锁和会话保留，编辑器错误为空。

## 2026-07-27 T0077 LLM 完整用量、每日 20 元预算与 GM 顶栏

- 核验 T0069 审计已保存完整输入 payload、正式 provider body、聚合响应、原始正文、UTC 时间、重试与最终 usage，继续不保存请求头并递归脱敏凭据。
- 新增 `LLMCostLedger`：按每次正式 HTTP 尝试持久化 DeepSeek 缓存命中 / 未命中输入、输出 token 与人民币估算；上海自然日跨 ModelAdapter / 后端重启重放。V4 Flash 默认官方价 0.02 / 1 / 2 元每百万 token。
- 正式 provider 每个尝试先预留 ¥1.77，当日已用与在途预留会越过 ¥20 时在 HTTP 前返回 429 / `budget_exceeded`；账本 / 定价错误失败关闭，不进入 Mock。旧进程内调用 / token 上限继续兼容。
- `LLMBridge` 新增 usage 异步只读线程；GM 面板标题下方每 3 秒显示本次后端运行输入 / 输出 / 总 token、人民币估算和今日金额 / 上限，隐藏时不轮询。
- fake-provider、Schema、Mock endpoint、审计、持久化重启预算、GM 与项目 headless 回归通过。真实 DeepSeek 对话返回 200、0 fallback：5,827 输入（2,944 命中 / 2,883 未命中）、180 输出、¥0.00330188；Godot MCP 运行态读取到顶栏“1,290 tokens / ¥0.1234 / 今日 ¥3.2100 / ¥20.00”，编辑器错误为空。

## 2026-07-27 T0076 NPC 对话跨小时延续与重估后当前行动立即派发

- 日计划 `talk_to_npc` 的来源元数据从 ActionSystem 延续到 DialogSystem；普通同日整点不再过期 pending 或全局结束自主会话。DailyPlanSystem 为赶路 / 等待发起者、邀请发起者及正式会话双方重建当前小时屏障，对话结束 / 失败后才派发结束时当前计划；跨日与高优先级行为模式保留中断权。
- 自主 NPC-NPC 对话发起者的范围判别新增 `required_revision_hours=[结束时当前小时]`。LLMBridge、Pydantic Schema、endpoint 业务校验、Prompt、紧凑重试及 Mock 使用同一硬合同；受邀者仍独立判断，第二层继续使用正常动态行动候选。
- 当前小时正式修订统一先写可靠 dispatch marker。直接派发、对话组延迟和行为模式延迟共用同一恢复路径；派发失败或误命中已消费单次项不再静默清除 marker。
- GM 以只读 `dialogue_carryover` 替换旧 `expire_plan_dialogues`。更新 NPC-NPC 等待 / 会话、选时修订、GM、Schema / endpoint / Prompt / Mock 自动化；相关 Godot 专项、Python 专项、项目解析和 diff 检查通过。
- 真实 DeepSeek `deepseek-v4-flash` 在关闭 fallback 后完成普通变化 / 空判别、发起者强制当前小时判别 / 当前小时正式修订、行动失败判别 / 修订。发起者判别首次遗漏 required 小时，被真实业务校验拒绝并由同 provider 紧凑重试纠正；最终所有路径 `fallback_used=false`。

## 2026-07-27 T0075 计划行动完成策略与连续生产周期

- 根因是 T0025 只允许 `(day, hour, plan_version, action, target, dialogue_goal)` 普通派发一次；高熟练度把格伦的铁匠周期缩短到约 40 分钟后，完成回调清除行动所有权但不重开，因此只能等下一次 `hour_started`。
- `data/action_defs.json` 为全部 25 个配置行为加入必填完成策略；ActionSystem 校验六个合法值及计划可选性。当前分类为 6 个可循环生产、3 个持续服务、4 个目标解决、9 个每小时单次、1 个终局和 2 个非计划系统行为。
- DailyPlanSystem 在可循环生产成功完成后 deferred 重新读取当前计划并正常派发下一周期；完成事件先于新开始事件，工位、资源、仓库、建筑、制造目标与 revision 每周期重验。失败、中断和条件不满足不续开。
- 整点相同 action / 必要 target 继续采用当前运行态并保留进度，不同项沿既有中断路径切换；每小时单次记录不依赖 `plan_version`，同小时重算计划不会重复吃饭或饮酒，显式玩家对话恢复仍可继续未完成行动。
- 新增 `verify_plan_action_completion_policy.gd`，更新单时段、规则计划和玩家对话恢复测试；完成策略、行动目录、基础行动、目标替换、扩展行动、制造管线 / 提醒、工作产出和项目解析通过。两个旧 LLM 计划修订专项仍分别命中既有真实后端 slowdown 与 payload / 线程问题，未用 Mock 代替。
- Godot MCP 4.0.1 / Godot 4.6.2 冻结 Main 确认 25 项配置、0 策略错误、两个系统正常载入，编辑器错误为空。完整分类与未来新增合同已同步到 `game_design.md`、AI、经营建筑、技术 / Godot 架构、模块索引和 GM 文档。

## 2026-07-27 T0074 制造目标缺失主场景提醒

- 新增 `Main/UI/CraftingTargetAlerts` 与 `CraftingTargetAlertPresenter.gd`：铁匠铺 / 工械坊无制造目标时，在建筑名称上方显示红色 `!`，悬停提示“未选择制造物品”。
- 提醒随 3D 名称投影更新并在屏幕边缘夹取；只在按钮区域接收鼠标，小于 320×180 的不可用测试视口不显示，避免破坏原有世界拾取。
- `BuildingSystem` 新增正式 `select_building(...)`；提醒真实点击和原世界点击共用 `building_clicked -> BuildingPanel`，旧 `debug_select_building(...)` 委托该入口。
- 选择目标后只隐藏对应提醒，清空目标后恢复；UI 只读 CraftingSystem 项目快照，不设置目标、不推进阶段或结算资源。
- 新增 `verify_crafting_target_alerts.gd`，并通过制造管线、铁匠铺、工械坊、15 座建筑真实点击、建筑工位面板和项目加载回归。
- Godot MCP 4.6.2 冻结运行确认 1152×648 下两个提醒可见、tooltip 正确、工械坊提醒打开对应面板，选择弓后工械坊提醒隐藏而铁匠铺保持；编辑器错误为空。功能可直接手动验证，未新增 GM 入口。

## 2026-07-27 T0073 指令面板叙事文案与计划影响验收

- 移除指令输入框“自由撰写守备官希望该 NPC 持续参考的指令……”placeholder；标题精简为“给 {NPC} 的指令”，默认说明改为“驿站成员将尽量遵循守备官的指令行动。”。
- `verify_npc_order.gd` 增加新标题、说明和空 placeholder 断言，既有未入伍拦截、预填、修订号、私有事件、相同文本无副作用与关闭不保存合同保持通过。
- 新增 `verify_order_plan_effect.gd`，从真实面板发布指令，捕获当前小时 `order_changed` 修订，使用正式 builder 验证最新 `current_order` 注入，并确认合法结果合并到权威 24 小时计划。
- 新增 `verify_order_plan_effect_real.gd`，以 DeepSeek `deepseek-v4-flash`、关闭 Mock fallback 发起一次正式修订；老兵副官 08:00 计划由 `idle` 改为 `visit_location -> chapel`。`request_id=godot_revise_plan_1436_0002`，输入 22,884 / 输出 266 tokens，0 fallback。
- Godot MCP 4.6.2 冻结运行确认“给 艾达 的指令”、世界内说明、空 placeholder 和正常布局，编辑器错误为空。既有 GM 指令 / 注入 / 计划入口足够观察，不新增重复控件。

## 2026-07-27 T0072 应征接受即时刷新与软性指令入口确认

- 根因是应征接受结果被暂存在 `DialogSystem.deferred_recruitment_result`，只有结束会话才写入 NPCSystem；NPCPanel 的 `npc_state_changed` 监听原本正常，因此重新打开后才看到“是”。
- 合法 `accept` 回复现在进入对话历史后立即调用既有权威 `set_npc_recruited(...)`；打开中的 NPC 面板同步刷新“已入伍：是”与可用“指令”按钮。取消后续对话不回滚已明确说出口的接受，拒绝仍无状态变化。
- 确认 T0703 软性指令闭环早已完整存在：NPC 面板“指令”按钮打开 `OrderPanel` 自由文本，NPCSystem 保存 `current_order`，LLMBridge / 后端 Schema 与 Prompt 接收该上下文，变化时触发计划重评估但不强制行动。
- NPC 面板个人库存文案由“持有酒”精简为“酒”；同步更新对应 UI 专项断言。
- `verify_dialogue_ui.gd`、`verify_dialogue_session_lifecycle.gd`、`verify_wartime_dialogue.gd`、`verify_npc_panel_interactions.gd`、`verify_npc_order.gd`、`verify_npc_panel_state.gd` 和项目 headless smoke 通过；旧指令专项的硬编码面板路径改为稳定节点名查找。
- Godot MCP 冻结主场景直接模拟接受回复，确认对话仍打开时权威状态、面板字段、指令按钮和“酒：0”同时更新；编辑器错误为空。未改 Prompt / provider，不需要真实 API 复测，也未新增 GM 入口。

## 2026-07-27 T0071 NPC-NPC 对话私有上下文隔离

- 定位真实场景泄漏：格伦在铁匠铺合法接收“制造目标变为铁盔”见闻；伊沃自己的记忆没有该事实，但伊沃的对话请求包含格伦 `speaker_npc.short_term_memory`，导致模型把格伦所知误当成伊沃所知。
- `LLMBridge` 删除 NPC 说话者的完整 `speaker_npc`，并把 `speaker_context.state` 收为空；说话者只暴露姓名、外表、健康和实际说出口文本，回复者自己的长短期记忆保持不变。
- 后端 `NPCDialogueRequest` 只允许 `speaker_npc=null`，`SpeakerContext.state` 必须为空；ModelAdapter 不再从 `speaker_npc` 推断 NPC id。对话 Prompt 同步禁止使用对方未说出口的记忆 / 指令 / 私有状态，并注明行动候选元数据不自动成为见闻。
- 同类审计另发现 `talk_to_npc` 候选暴露其他 NPC 实时地点、行动和入伍状态；这些字段已从候选移除，ActionSystem 仍在执行时权威读取并追踪目标，计划与对话行动回归通过。
- 新增差异记忆 Godot 专项，把带铁盔标记的私有事件只写给格伦，确认伊沃记忆及六类伊沃 payload 均无该标记；同时确认伊沃自己的 `short_memory / long_memory` 未被误删。
- Schema、Mock、fake provider、对话 endpoint、六类 Prompt、动态 station context、NPC-NPC 邀请 / 边缘流程、项目 smoke 全部通过。真实 DeepSeek `deepseek-v4-flash` 1 次明确表示不知道未公开安排，输入 5,581 / 输出 207 tokens，`fallback_used=false`。
- Godot MCP 4.6.2 运行态确认唯一 `Main/Systems/LLMBridge` 节点存在，编辑器错误为空。现有 `npc_talk`、事件 / 见闻与后端审计入口足够验证，未新增重复 GM 功能。

## 2026-07-27 T0070 全员名册、职业知识与仓库容量

- `LLMBridge` 的六类 NPC 请求改为始终发送全部 8 名登记成员，每人携带权威 `recruited / in_station`；离站者保留在名册并标为不在站。后端 Schema 与六份 Prompt 同步收紧，缺标签请求会被拒绝。
- 初始知识图谱新增艾达教官独练、莉娜无病人研习、托马坐骑资格 / 随骑手离厩、布鲁诺成餐更耐饱四条职业规则；8 条仓库关系更新为按等级扩容及正门失守后受袭次序。当前共 226 条关系，受击丢货仍未写入。
- `resource_defs.json` 配置粮食 / 餐食 / 酒 / 木材 / 石料 / 铁 1 级容量 120 / 120 / 60 / 120 / 120 / 120，后续每级增加 60 / 60 / 30 / 60 / 60 / 60；ResourceSystem 提供单项、批量和原子入库接口。
- 工作产出与商人购买在扣输入前预检容量；满载时不发生部分结算，工作失败在计划修订中归为资源不足。修复了无容量配置资源被空字典误判为容量 0 的硬错误。
- 仓库建筑面板显示六项当前上限，HUD 左上受限资源悬停显示同一数值；无限资源无提示。该功能可从 Main 前端直接验证，未新增 GM 入口。
- 静态、Schema、六类动态 payload、知识、工作、交易、HUD、训练、诊所、马匹、食堂和仓库专项通过。真实 DeepSeek `deepseek-v4-flash` 1 次准确回答 8 人入伍 / 在站状态与艾达两类教官成长，0 fallback；Godot MCP 运行态确认面板、tooltip 和编辑器无错误。
- 食堂回归脚本显式关闭自动日计划执行，避免测试断言结束后仍有行动失败判别 HTTP 线程随 SceneTree 强制销毁；该调整只收束测试生命周期，不改变正式游戏启动或计划规则。

## 2026-07-27 T0069 后端 LLM 调用持久化审计日志

- 新增 `backend/services/llm_audit_logger.py`，默认将调用生命周期追加到 Git 忽略的 `backend/logs/llm_calls.jsonl`；每行带 schema version、UTC 时间、audit id 和事件类型，写盘失败不会中断游戏。
- ModelAdapter 记录调用输入、每次真实供应商完整无请求头 body、聚合响应、原始模型正文、解析 / 拒绝、HTTP / 异常、usage、fallback 和最终结果；Schema / 业务校验失败通过 usage timestamp 关联原 audit id 并追加证据。
- 新增环境变量 `LLM_AUDIT_LOG_ENABLED / PATH / INCLUDE_PAYLOADS`；`/health`、`/debug/llm_usage` 和 GM“成本统计”只显示日志状态、路径与最近写盘错误，不返回正文。
- 写盘前递归脱敏常见凭据 key、序列化 JSON 中的 credential 值、Bearer、`sk-...` 和当前真实 API Key；供应商 Authorization 请求头从不进入日志数据。
- 新增 `verify_llm_persistent_audit_log.py`，覆盖完整 fake provider 成功、两次非 JSON 重试、HTTP 503、业务无效关联、24 路并发 Mock、默认环境开关、敏感信息和写盘失败；既有 ModelAdapter / budget / Schema / 六类 endpoint 与 Prompt 回归全部通过。
- 真实 DeepSeek `deepseek-v4-flash`、`LLM_FALLBACK_TO_MOCK=false` 完成战时对话和战斗心理各 1 次：2 个 audit id 对应 10 条生命周期事件，完整 messages / 响应和 token 均存在，0 fallback；API Key 和请求头均未进入日志。

## 2026-07-27 T0068 导出 T0067 真实 LLM 94 次调用审计包

- 新增 `tools/export_t0067_llm_audit.py`，只读提取本机 T0067 Codex 会话中的 usage、删除前原始 `.out` 和场景标记事件；不读取 / 导出 Key，不包含 Authorization 请求头，也不重新调用 provider。
- 生成 `docs/audits/T0067_LLM_94_CALLS/`：94 行调用库存、三类完整 system Prompt、Agent 场景文本、16 份完整无请求头定向矩阵 provider body、16 路原始结果 / usage、Main 聚合与尾部 usage、39 条场景结果和四份测试脚本快照。
- 16 路输入 89,562 / 输出 2,614 tokens、Main 尾部 12 原始 / 11 唯一记录和 94 行类型分布均由导出器断言复核；敏感字段扫描通过。本任务新增真实 API 调用为 0。
- 明确审计缺口：T0067 当时只把 usage 保存在内存，Main 的完整动态 payload、解析前原始响应和 SSE 没有持久化；后端重启后只能恢复尾部 11 个真实 request id，其余 67 次保留聚合与部分场景输出，不伪造逐条 Prompt / 响应。T0068 因此标为 `Partial`。

## 2026-07-27 T0067 真实战斗心理、日常逃离与挽留全分支验收

- 使用 DeepSeek `deepseek-v4-flash`、关闭 thinking 与自动 Mock fallback，通过正式 Main 场景验证低血量心理、战时 / 避战对话、日计划逃离和逃离挽留。去重后正式 Main 后端 78 次与独立定向矩阵 16 次，共 94 次真实供应商请求；93 次通过业务校验、1 次普通开局日计划业务无效、0 fallback。
- 自然结果：参战继续战斗、避战继续躲避、避战低血逃离、战时士气高昂、避战无应征、格伦接受应征并在装备后参战、莉娜拒绝应征、实际撤回危险命令后托马被挽留、欧文连续五轮拒绝挽留均正确落地。
- 未稳定自然触发：参战低血逃离、斗志激昂、完整日计划主动选择 `escaping_station`、极端战时对话逃离。每个结构化分支在受限正式 payload 中均可达，故任务标为 `Partial` 并只提出 Prompt / 上下文建议，没有进行软性调参。
- 修复 Pydantic 静默丢字段、对话业务组合缺校验、避战 fallback 越界、低血量迟到响应、同波次重启误收旧响应、逃离模式 / 移动半提交、复苏续逃卡死和战时对话结束重入。逃离只在原子移动成功后记录事件。
- 修复业务校验失败 usage 双计：供应商生成成功但业务输出无效时，不再为同一 request id 同时保留成功、失败两条记录，而是原地标记 `SchemaValidationError`，保留真实 token / finish 元数据且预算只累计一次。修复前最终 Main 快照的 79 条记录包含 1 条重复；审计后的实际 Main 请求为 78 次。
- Python 最终回归 9/9、Godot 战斗 / 逃离最终回归 8/8 通过；新增三份真实 Main 工具与一份真实 provider 分支矩阵。现有 GM 入口已能观察权威状态，不新增面板入口。

## 2026-07-27 T0066 精简公告牌文案并优化当前计划初始位置

- 公告牌玩家页签改为“通告 / 日程表”；移除已发布字数、“通告草稿”、默认退出说明和日程表底部默认草稿说明。系统错误、时段校验、全天重叠和发布结果等按需反馈仍保留。
- `schedule_advisory_note` 更新为“这是建议日程，驿站成员不一定严格按照这个日程，如有特殊事务可自行安排”；黄色标签直接显示权威字段，不再附加“参考性质｜”，初始 / 后续日程事件继续引用同一备注。
- NPC“当前计划”详情首次打开时根据当前小时和每个行动实际占用文本行定位到当前项前两项，并允许末尾继续滚动，使当前项通常处于第三个行动位置；0 / 1 点夹取到当天开头。完整计划和刷新滚动保持不变。
- 自动化通过：`verify_notice_board_tabs.gd`、`verify_npc_panel_state.gd`、`verify_notice_board_input.gd`、`verify_location_info_nodes.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_npc_panel_interactions.gd` 与项目 headless smoke。
- Godot MCP 4.0.1 / Godot 4.6.2 运行态确认新 Tab、黄色文案、空默认提示、无旧标签，以及 08:00 打开时从 06:00 开始并标记 08:00；编辑器错误日志为空。功能可直接从 Main 前端验证，不新增 GM 入口，不涉及 LLM / API。

## 2026-07-27 T0065 公告牌改为全站单次广播并移除入场重复

- `MemorySystem._broadcast_public_event(...)` 只对 `plaza_notice_changed / plaza_schedule_changed` 改用全站 NPC 接收者；其他广场 / 地点 `local_public` 事件继续只转发给当前地点在场者。既有 `add_witness_event(...)` 资格规则继续过滤昏迷、睡觉、逃离和站外 NPC。
- 通告与参考日程保留独立发布接口和变更检测。只改通告只生成一条通告事件，只改日程只生成一条日程事件，两页分别变化时各生成一条，相同内容不重复广播；玩家发布 summary 分别明确为“守备官更新了通告”和“守备官更新了参考日程”，新内容保留在 payload。
- 广场权威快照仍保存 `current_notice / reference_schedule / schedule_advisory_note`，但 `_record_location_entry_snapshot_witness(...)` 在写入 NPC 入场见闻前剔除三项；入场摘要同步不再提公告牌，避免室内往返经由广场时反复堆叠相同内容。
- `NoticeBoardPanel` 成功与草稿提示更新为全站广播语义；没有新增 GM 入口，主场景公告牌、NPC 见闻详情和既有 GM 地点 / 见闻查询已能直接验证。
- 自动化通过：`verify_notice_board_tabs.gd`、`verify_notice_board_input.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_location_info_nodes.gd`、`verify_escape_station_behavior.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_action_local_public_broadcast.gd`、`verify_gm_panel.gd`、`verify_npc_unconscious_natural_recovery.gd` 与项目 headless smoke。
- Godot MCP 4.0.1 / Godot 4.6.2 冻结运行验证 8 名 NPC 对通告各新增 1 条见闻、对日程各新增 1 条见闻；室内莉娜随后进入广场时，入场见闻不含三个公告牌字段且摘要不提公告牌。编辑器错误日志为空。

## 2026-07-27 T0064 修复 Godot MCP 新会话 proxy 启动失败

- 6550 端口实际由当前 Godot 4.6.2 编辑器插件正常监听，8765 由唯一 broker 监听；此前再启动一个 `--editor` 产生的 `Address already in use` 是验证方式错误，不代表既有 MCP 掉线。
- fresh proxy 专项复现真实根因：`godot-mcp-proxy.mjs` 只查找已被清理的 `npm-cache\_npx`，因此新会话在加载 `@modelcontextprotocol/sdk` 时 `ENOENT` 退出；旧 proxy / broker 仍存活掩盖了问题。
- 修复用户级 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`：优先使用 broker lock 指向的安装和全局 `@satelliteoflove/godot-mcp` 包内 SDK，再回退全局独立 SDK / npx 缓存。
- `tools/verify_godot_mcp_topology.mjs` 增加子 proxy 退出码与 stderr 诊断；`tools/check_godot_mcp.ps1` 明确显示 6550 owner，并提醒不得重复启动第二个 editor 或误杀正常 listener。
- 验证通过：fresh proxy 多会话隔离、单 broker / 单 Godot 连接、自检和 `godot --headless --path . --quit-after 1`。broker 实际调用确认 addon/server `4.0.1` 对齐、Godot `4.6.2`、`Main.tscn` 打开、编辑器错误为空。修复前已经关闭的 Codex stdio transport 需要刷新或新开会话才能注册工具。

## 2026-07-27 T0063 守备官赠酒与 NPC 自主饮酒闭环

- NPC 面板在给钱右侧新增给酒数量和按钮，并显示 NPC 个人持酒；NPCSystem 从驿站 `wine` 原子转入个人 `states.wine`，8 人档案和旧数据运行态默认均补为非负整数。
- `data/action_defs.json` 新增可计划 `drink_wine`。只有本人持酒时进入动态计划 / 对话候选，执行开始通过个人资源接口实际扣 1；成功写 `wine_consumed`，不足写 `drink_wine_failed_no_wine` 并复用资源失败重估。心情改善和伤痛暂时淡化只作为事件上下文，不建立情绪数值、不删除记忆。
- `station_context.work_mode_actions` 增加 `description`，保证新计划行动同步进入 NPC 背景行为目录；六类 NPC 状态携带个人 `money / wine`，共享驿站五项公开资源不变。后端新增 `PlanActionKind=drink` 并限制日计划 / 剩余日饮酒次数不超过当前个人酒。
- 六份正式 Prompt 分别补充候选前提、程序扣减、无酒失败和上下文影响边界。Schema、fake-provider Prompt、Mock endpoint、Godot 面板 / 行动 / 六类目录专项和 headless 均通过。
- 真实 DeepSeek `deepseek-v4-flash` 在 `LLM_FALLBACK_TO_MOCK=false` 下通过日计划、对话、计划判别 / 修订、战时心理和首次睡眠反思验收，成功结果全部 `fallback_used=false`。本轮没有新增 call_type 或运行时 LLM 调用。
- 功能可从主界面直接验证，并可复用 GM 资源增减、通用指定行动和事件查询；未新增 GM 入口。当前会话没有可调用 Godot MCP，Godot 4.6.2 命令行专项正常，编辑器插件另报告 6550 端口已被占用。

## 2026-07-24 T0061 收束 NPC 背景叙事与知识面板展示

- 从 8 份正式 NPC 档案、共享 `NPCIdentity` / `npc_setting`、`NPCPromptProfile`、背景弹窗和六类正式 Prompt / payload 中删除 `signature_lines`；人物差异继续由职业视角、人格、欲望、恐惧、底线和宽松 `speech_style` 提供，不再用几句代表性表达限定后续生成。
- 重新分配初始日记的信息层级：“往昔·来站前”用宏观切片交代身世、职业形成、离开原因和到站时间；“往昔·初到驿站”交代接手工作与所遇成员。八个视角按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜拼成一致的驿站到站史；T0060 的 8 篇“往昔·近日”微观日常保持不变。
- 每名 NPC 对守备官的种子知识收为一条基本职位职责，技术关系键统一为 `role`，不再附加“尚待观察”或关系判断。15 座建筑的中文认识改为人物在世界内会自然表达的常识，本职建筑继续更具体。为删除当前未实现的仓库容量、受击丢货和损失比例暗示，8 条仓库技术 `value` 受控迁移为 `central_storage_and_post_breach_attack_target`；其余技术 `value` 不变，222 条 `confidence / day / time` 完整保留。
- NPC“知识”详情只显示中文主体、关系和值，不再向玩家显示可信度和更新时间；原始 / 运行态记录、存档与 GM `long_memory` 仍保留 `confidence / day / time`，后端知识补丁继续保留 `confidence`，Godot 继续写入日期与时间。功能可直接从 `Main.tscn` 的“背景 / 日记 / 知识”验证，未新增 GM 入口。
- 静态文案、六份 Prompt、后端 Schema、Model Adapter Mock 与相关 endpoint 全部通过；`verify_npc_character_profiles.gd`、`verify_npc_initial_long_memory.gd`、`verify_npc_panel_state.gd`、`verify_daily_reflection_system.gd`、`verify_gm_panel.gd` 5 个 Godot 专项全部通过。最终最大 payload 字符数为 `battle_judgement=32057 / daily_reflection=29242 / dialogue=48330 / plan_day=47118 / plan_revision_judgement=50053 / revise_plan=49952`。
- 真实 DeepSeek `deepseek-v4-flash` 在关闭自动 Mock fallback 后完成 3 次调用，0 失败，全部 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 运行态确认 8 人各 3 篇日记、守备官 `role`、222 条原始元数据、8 条仓库技术值和玩家知识 UI 隐藏边界全部正确；莉娜实际知识弹窗显示 27 条关系，编辑器错误日志为空。
- 项目 headless smoke 通过，仅保留既有退出期 `ObjectDB instances leaked at exit` 警告。T0061 标记为 `Done`；另登记 T0062 负责未来实现仓库容量与受击资源损失闭环，本轮不扩展该系统。

## 2026-07-24 T0060 重写 8 名 NPC 初始长期记忆文案

- 全量重写托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文的 7 类根本人设、24 篇开局前日记和 227 条知识图谱中文 `value_label`。每人仍为 25 个知识主体：15 座正式建筑、其余 7 人、守备官和 2 个个人故事主体；职业相关建筑更细，其余认识简明并服从当前权威规则。
- 人物表达改为自然、直接、具体的中文，并分别以朴实谨慎、口语抱怨、安静务实、短促严厉、条理复盘、温和完整、临床精确、因果分析形成区别。移除旧版晦涩比喻、突兀拟人和为机巧而机巧的共同腔调，轻微黑色幽默只保留在事实清楚的个别句子中。
- “往昔·近日”统一落在守备官收到并向众人传达敌情之前，只记录普通驿站生活；守备官认识保持中立开放。六类 payload 把结构化日记投影为带“往昔”或“第 N 天 HH:MM:SS”时间标签的 `list[str]`，六份 Prompt 同步中文表达和时间边界。
- 静态文案、人物档案、初始记忆、六份 Prompt、后端 Schema、Model Adapter Mock、首次睡眠反思、GM、Godot 专项与项目 headless 全部通过。真实 DeepSeek `deepseek-v4-flash` 准确回答莉娜、欧文、布鲁诺 3 条新记忆路径，3 次调用、0 失败且全部 `fallback_used=false`。
- 最终真实专项前有 4 次成功的验收谓词 / 时间标签校准调用；一次 LLMBridge 集成测试误用真实本地配置并如实记录 `ProviderIdleTimeout`，没有回退 Mock，之后改用显式 Mock 后端完成集成回归。本轮合计 8 次真实 provider 尝试。
- Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认 8 人均为 `diary=3 / subjects=25 / prefix=true / recent_clean=true`，编辑器无错误且场景已停止。本任务不新增 GM 入口，继续复用 NPC 面板“日记 / 知识”和 `long_memory <npc_id>`。

## 2026-07-24 T0059 补全 8 名 NPC 初始长期记忆与根本人设

- 排查断线残留后确认 NPCSystem 已有未闭合的种子加载入口，但正式数据文件缺失；现新增独立 `npc_initial_long_memory.json` 并收束加载 / 验证路径，不覆盖或回退用户已有其他修改。
- 为托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文各写 3 篇第一人称生命切片和完整初始图谱。每人覆盖其余 7 人、守备官、15 座建筑与至少 2 个个人故事主体；建筑规则经程序 / 文档审校，守备官关系保持开放。
- 8 人 `background_story` 收敛为稳定职业视角和根本矛盾；六类 Prompt 补充“开局前记忆不是今日事实、实时权威优先、关系由真实互动发展”。LLMBridge 移除目标图谱重复镜像，并避免对话 participant 重复 / 泄露私人长期记忆。
- 初始记忆、人物档案、反思追加、GM、后端 Schema、六份 Prompt、Mock 和六类 Godot payload 自动化通过；重复 initialize 保持每人恰好 3 篇种子日记。Godot MCP 4.0.1 / Godot 4.6.2 运行态确认 8 个 NPC 实体、每人 3 篇日记 / 25 个知识主体 / 守备官条目、对话顶层唯一长期记忆和空错误日志。
- 真实 provider 最初两次在较短流空闲窗口内触发 `ProviderIdleTimeout`，且均未回退 Mock；随后以连接 30 秒 / 空闲 180 秒的受控配置重试，DeepSeek `deepseek-v4-flash` 准确回答莉娜与欧文的独特记忆锚点。最终 usage 为 2 次调用、0 失败、`fallback_used=false`。

## 2026-07-23 T0058 向所有 NPC 公开基础资源与升级协助常识

- `station_context` 新增严格五项 `basic_resource_reserves`，由 LLMBridge 每次从 ResourceSystem 当前运行态读取粮食、餐食、木材、石料和铁；计划类 `current_resource_states` 同步收窄，隐藏第纳尔、酒、装备、器械和马匹库存。
- `station_rules` 增加第六条“建筑升级缓慢、协助可加快”规则；六份 Prompt 按职责解释资源白名单，并要求日计划 / 修订在动态候选存在时认真考虑 `assist_upgrade`，没有候选时不得自造目标。
- 既有 GM `station_context` 只读输出增加公开资源。Schema、Mock、endpoint、Prompt、Godot 六类 payload、计划目录、GM 和项目 headless 通过；真实 DeepSeek 对话准确复述 23/4/17/9/6 五项资源，真实 24 小时计划实际选择 `assist_upgrade`，均无 fallback。
- Godot MCP 4.0.1 冻结运行确认粮食变化后下一次共享上下文即时刷新、技术值为英文且中文名称正确；清理旧日志后重新运行无新增编辑器错误。

## 2026-07-23 T0057 建筑升级中断行动并触发失败重估

- 根因确认：ActionSystem 已在 `building_state_changed` 时清理指向封闭建筑的 pending / active 行动，但最终写入 `building_unavailable`；DailyPlanSystem 只把包含 `failed` 的日常结果接入 T0050，因此清理后没有行动失败判别，NPC 停在 idle。
- 升级封闭现只把真正依赖该建筑的 pending / active 行动写为 `<action_id>_failed_building_upgrading`；先停止移动 / 周期并释放位置，再一次性保存行动、建筑、pending / active 阶段、升级原因和中文摘要。单纯停留 / 普通移动只清退或停止，不伪造失败；广场上的协助升级不受误伤。
- DailyPlanSystem 将 `building_upgrading / building_unavailable` 规范为现有 `target_unavailable`，复用 T0050 `action_failure` 判别与非空后的精确阶段修订，没有增加 Schema、Prompt、call type 或第二套结算。
- 新增 `verify_building_upgrade_action_failure.gd`，覆盖食堂路上 pending 与菜园内 active 两条链路；建筑位置、修复升级、服务依赖、日计划重估、T0050 两阶段、基础行动、GM、项目 headless 与 diff 检查通过。真实 DeepSeek `deepseek-v4-flash` 的失败判别 / 精确修订均一次成功且无 fallback；Godot MCP 4.0.1 运行态复验 active 链并确认无新增编辑器错误。现有 GM “指定行动 / 升级 / plan_request”足以观察，不新增入口。

## 2026-07-23 T0056 马匹成长、额外 HP 与繁育反馈

- 栗风 / 灰鬃初始成长由 100% 调整为 60% 刚成年，自然 HP / 饱食上限从成长曲线得到 76 / 80；有效马厩照料可继续推进到 100%。
- HorseSystem 为每匹马增加独立累积繁育概率和配置化 1440 游戏分钟产后冷却；至少两匹成年在厩、非冷却候选且有效养马人在岗时，概率按照料分钟、养马能力和马厩等级增长，成功后本次候选归零并进入冷却。
- 公开马匹快照新增基础 HP 与照料额外 HP 派生字段；BuildingPanel 将两者拆成独立进度，并新增两位小数繁育概率和冷却剩余时间。UI 只读 HorseSystem，不写权威状态。
- 新增 `verify_horse_care_feedback.gd`，并调整既有马匹专项的 60% 成长饱食上限夹具；马匹反馈、马厩照料、马匹生态 / 分配、建筑面板、NPC 面板、GM、HUD、装备、兵种、战斗集结共 10 项相关回归及主场景 headless 启动通过。
- Godot MCP 冻结运行确认有效照料会同步推进成长、额外 HP 与逐马概率；必成繁育后马匹数 2→3、亲本概率归零并进入 86400 游戏秒冷却，马厩 UI 显示“繁育概率 0.00%（冷却 1天0小时）”，编辑器无新增错误。

## 2026-07-22 T0055 持续活动与周期产出常识

- `data/station_context.json` 新增第五条世界内规则：工作、照料、训练、治疗和制造只在成员持续有效参与时推进，完成相应周期后才由驿站实际记录结算；离岗、改做他事或被打断后不会无人自动产出，未完成进度是否保留以程序记录为准。
- 六份正式 Prompt 按各自职责禁止把未完成周期或离岗后的预期收益写成已完成事实；没有新增 Schema 字段、Godot 结算代码、call type 或游戏内调用次数。
- Schema、Mock / endpoint、Prompt、Godot 六类 payload、GM 和项目 headless 回归通过。真实 DeepSeek `deepseek-v4-flash` 菜园专项回答“活计得有人一直干，周期到了才算数；一离岗进度就停，没人接着干就没产出”，`fallback_used=false`。
- Godot MCP 4.0.1 server/addon 版本一致；冻结运行主场景后真实上下文为 8 人 / 15 建筑 / 22 种工作行为 / 5 条规则并命中新周期规则，编辑器无新增错误。

## 2026-07-22 T0054 NPC LLM 驿站常识上下文

- 新增 `data/station_context.json`，以世界内口吻保存小型边境驿站简介和四条精简规则；人员、建筑、行为目录不写死在该文件或 GDScript。
- LLMBridge 从 NPCSystem 当前在站人员、BuildingSystem 全部配置建筑与 ActionSystem 可计划行动定义组装五字段 `station_context`，并统一注入对话、日计划、计划修改判别、正式修订、战时心理和首次睡眠反思。广场 / 公告牌、仅运行态对话入口不会误入目录。
- 后端 Schema 新增建筑 / 工作行为模型并收紧四个非空数组；六份 Prompt 明确完整世界目录与单次 `allowed_actions / allowed_decisions` 的区别，禁止背景规则覆盖程序权威事实。
- 新增 Python 配置夹具与扩充 Schema / Prompt / endpoint / Godot payload 专项；GM 增加只读“驿站上下文”按钮和 `station_context` 命令。项目 headless、动态 8→7 人员、15 建筑、工作行为来源与四条规则验证通过。
- 环境存在真实 Key，DeepSeek `deepseek-v4-flash` 已完成对话、每日计划、计划修改判别、正式修订、战时心理与首次睡眠反思路径，全部 `fallback_used=false`；场景语义问答未补造离站成员。
- Godot MCP 4.0.1 server/addon 版本一致；冻结运行主场景后读取真实上下文为 8 人 / 15 建筑 / 22 种工作行为 / 4 条规则，目录排除广场和仅运行态守备官对话入口，编辑器没有新增错误。

## 2026-07-22 T0053 跨小时对话等待失效与人物上下文一致性

- 日计划 `talk_to_npc` pending 新增来源日 / 小时 / 版本 / 原计划项。ActionSystem 在逻辑推进、目标计划完成重试和整点新计划派发前复验当前计划；不再找同一目标时释放预约、停止接近并写 `talk_to_npc_failed_plan_superseded`，包含旧 / 新计划项与跨小时事实。DailyPlanSystem 优先用旧 `failed_plan_item` 进入行动失败判别，避免把下一小时行动误报为失败项。
- 修复移动清理同步状态信号竞态：先以非失败 reason 停止移动，再写一次完整结构化失败，防止无上下文的同名失败先被去重。GM 新增 `expire_plan_dialogues`，仅扫描既有日计划等待，不创建计划、对话或失败。
- `NPCContext` 新增 `long_term_memory={knowledge_graph, diary}`；PlanRevisionJudgementRequest 改为 StationAware 并必填统一 NPCContext、行动候选与实时建筑 / 资源状态。日计划、对话 / 失败范围判别、正式修订和战时低血量心理现共享人物、状态、当前指令、长短期记忆与地点；两阶段原样传递失败项 / 类型 / 摘要 / 上下文。四份 Prompt 与 `plan_item_superseded` Schema 同步。
- Python Schema / Mock / Prompt / endpoint 和 Godot 跨小时、两阶段、场景上下文、日计划、对话、低血量心理回归通过。真实 DeepSeek `deepseek-v4-flash` 完成对话判别、行动失败判别、正式修订、战时对话和低血量心理，均一次成功且无 fallback。Godot MCP 4.0.1 运行态确认三类 payload 的 station / identity / state / order / short / long / location 字段齐全，编辑器无新增错误。

## 2026-07-22 T0052 计划期间对话互斥与自主对话等待

- `NPCSystem` 统一公开 `kind=plan` 活动查询；`DialogSystem` 在守备官草稿、实际交互和自主邀请边界返回 `npc_planning`，玩家对话不再取消每日计划、修改判别或计划修订请求，也不推进 dialogue epoch 或打断原行动。
- `NPCPanel` 在目标计划中禁用对话按钮并提示“NPC正在思考”；计划活动清除后随状态刷新恢复。Godot MCP 运行态确认 disabled、tooltip、错误码和计划仍活动四项同时成立。
- `ActionSystem` 允许既有 `talk_to_npc` 行动接近计划中目标；到达后保留 pending action、双方预约与开场白，目标计划结束后延迟重试原邀请。即时失败修订候选继续过滤计划 / LLM 活动目标，日计划候选仍允许稍后目标。
- 更新睡眠 / 对话边界、NPC-NPC 竞态和计划行动目录自动化；专项与 NPC 面板、对话 UI、计划恢复、会话生命周期、NPC-NPC 计划行动回归通过。本任务没有修改 Prompt、Schema 或 provider 输出合同；已配置后端的真实 DeepSeek `deepseek-v4-flash` 邀请接受 / 拒绝和正式 NPC-NPC 对话复验通过，`fallback_used=false`。

## 2026-07-22 T0051 可拖动弹窗与守备官会话生命周期

- 新增 `DraggablePanel.gd`，把对话、NPC、建筑、指令、公告牌、商人、NPC 详情和 HUD 库存详情的顶部栏统一为拖动把手，解除原布局锚点后保留用户位置并限制在当前视口；GM 按钮原有拖动和原生确认窗保持不变。
- 守备官对话新增完成 / 取消 / 挂起。发送先写守备官历史再请求 LLM；完成可在等待中取消回复并以最后一句守备官文本结尾，整场只提交一个 `dialogue_turn` 后进入统一计划判别；取消丢弃会话、事件、见闻和暂存的应征 / 战时 / 逃离结果；攻击即时结算并禁用取消。
- 挂起会话保持 NPC `talk_to_guard_officer` / `active_dialogue_id` 占用和等待请求，NPC 头顶显示橙色 `↩` 可点击气泡，NPC 面板对话按钮显示橙点。7200 逻辑秒后普通会话自动取消，含攻击会话自动完成并保留不可撤销事实。
- 新增 `verify_dialogue_session_lifecycle.gd`，并迁移 `verify_dialogue_ui.gd`、逃离挽留、战时对话、睡眠边界、主动交涉和 NPC 面板测试到新提交语义。专项、UI / 计划 / 记忆 / 建筑 / HUD / 商人回归及主场景解析通过；真实 DeepSeek `deepseek-v4-flash` 对话调用记录为成功、`fallback_used=false`。

## 2026-07-22 T0050 行动失败统一为先判别、再精确阶段修订

- 日常计划行动失败不再默认以 `[current_hour]` 直接请求 `/npc/revise_plan`。`DailyPlanSystem` 会先调用通用真实 `/npc/plan_revision_judgement`，以 `trigger_kind=action_failure` 传入权威失败计划项、失败类型 / 摘要 / 必要上下文、原 24 小时计划和工作阶段下限；空集合保持原计划，非空才进入第二层。
- 对话和行动失败现在共享 `PlanRevisionJudgementRequest/Response`、`plan_revision_judgement_system_prompt.txt`、`call_type=plan_revision_judgement` 和通用 LLMBridge 异步信号。旧 `/npc/dialogue_plan_revision_judgement`、旧 Schema / 方法名保留兼容，不再是正式运行时主路径。
- 第二层继续携带既有人设、状态、短期 / 长期记忆、地点、资源、建筑、行动白名单、当前指令、完整原计划和失败上下文，但 `revision_hours` 精确等于第一层选择。失败工作改为非工作且全天计划处在最低工作阶段数时，第一层需同时选择最少的未来补偿阶段。
- 行动失败第一层复用既有 NPC 修订互斥、单后继队列、请求版本 / 小时过期校验、TimeSystem 慢速与计划派发屏障；判别为空、失败或取消都会释放状态，非空后的落地失败仍受连续 3 次上限。异步第二层成功启动会明确返回 `ok=true`，不会被第一层误记为启动失败。同一阶段重复状态通知继续去重，但新小时会清空失败缓存，避免同名冲突在后续阶段发生时 NPC 留在失败地点且不再产生判别。
- GM `plan_request` 改为显示最近通用判别及 `trigger_kind`，未新增强制判别按钮。Python Mock / Schema / Prompt / endpoint、Godot 行动失败专项与既有计划 / 对话 / 工位 / 诊疗 / GM 回归通过；真实 DeepSeek `deepseek-v4-flash` 的行动失败判别返回 `[8, 14]`，第二层严格只修订 `[8, 14]`，无 fallback；Godot 真实资源不足路径也完成“判别 → 修订 → 事件落地 → 慢速释放”。

## 2026-07-22 T0049 对话后先判别、再精确阶段修订

- T0048 的剩余日全量重排实测过于笨重，现改为两阶段链路：所有实际守备官-NPC / NPC-NPC 对话结束后，先用独立真实 LLM 根据完整本轮对话与原计划返回精确 `revision_hours`；空数组表示不修改，非空才进入第二次完整上下文计划修订。
- NPC-NPC 邀请拒绝与正式会话结束均由双方分别判别。守备官对话窗删除“结束后重估计划”开关，由 NPC 自行决定；空判别在满足 T0044 动作恢复边界时继续原行动。对话内已提交攻击即使回复取消或不产生 NPC 回复，也作为有效事实进入同一判别。
- 所有双目标 NPC-NPC 会话在发起任一方判别前预注册组派发屏障，等双方第一层 / 必要第二层全部终态后按计划依赖顺序放行；跨小时玩家对话也在目标 NPC 判别链终态前延迟新小时派发。第一层输入保持为本轮对话、原 24 小时计划、时间 / NPC 标识和轻量会话元数据，完整上下文只进入第二层。
- `/npc/revise_plan` 改为 `revision_scope=selected_hours`，响应只能覆盖请求小时；行动失败、指令变化、战斗结束 / 复苏、主动交涉超时和 GM 手动触发等非对话来源不调用判别层，统一默认 `[current_hour]`。非对话伤害按其自身入口处理。原有真实 provider、三次尝试、过期 / epoch 丢弃、单后继队列和失败保留原计划边界继续生效。
- 事件库 / 见闻库详情从关闭状态首次打开时默认滚到最底部，直接显示最新记录；详情已经打开时，新记录刷新继续保留玩家阅读位置。
- 异步收口补齐两个竞态：旧 generation 的 D1 HTTP 不再阻塞已完成 D2 的当前计划放行；普通失败 followup 从排队、启动到终态始终阻塞旧行动重派，计划应用清除的 ready marker 会按新版本安全恢复或在新行动已启动时直接消费。
- 设计、AI、Prompt、Schema、架构、UI、记忆、预算、GM、模块索引与后端说明已同步新合同。Python / Godot / UI 回归和 headless 解析通过；真实 DeepSeek `deepseek-v4-flash` 的 `[14]` 精确修改、第二层同范围返回和 `[]` 不修改均一次成功、无 fallback；Godot MCP 4.0.1 冻结运行最新主场景且错误日志为空。T0048 条目保留为历史记录并明确由已完成的 T0049 取代。

## 2026-07-22 T0048 统一计划重估为剩余日全量重排（历史方案，已被 T0049 取代）

- 根因确认：运行时同时保留 `local_changes` 与 `remaining_day` 两套合同，导致行动失败、NPC-NPC 对话、指令变化等只修订 1-3 个小时，而玩家对话开关开启后会完整重排剩余日。
- `DailyPlanSystem`、`LLMBridge`、Python Schema、endpoint、Mock、紧凑重试和计划修订 Prompt 现只允许 `remaining_day`；所有触发源保留过去小时，完整覆盖当前小时至 23 点，起始项必须与 `immediate_action` 一致。
- 自动化捕获行动失败、NPC-NPC `dialogue_completed` 与 GM 手动触发的实际异步请求，并回归完整小时集合、旧范围拒绝、白名单、工作阶段、单后继队列、迟到失败上限和对话 / 服务依赖边界。
- Mock / Schema / fake-provider、Godot headless 和项目加载通过。真实 DeepSeek `deepseek-v4-flash` 返回 16 个剩余小时项；工位冲突结果选择 `talk_to_npc -> priest_01 @ clinic`，保留 15 个工作阶段，两条真实路径均 `fallback_used=false`。
- Godot MCP 4.0.1 冻结运行主场景，向实际 LLMBridge 故意传入旧局部值后读到 `revision_scope=remaining_day`、起始小时 8、当前计划 24 项，编辑器错误日志为空。既有 GM `plan_revise` 直接承接新语义，没有新增重复入口。

## 2026-07-22 T0047 修复建筑点不开与透明按钮误升级

- 现象与根因：BuildingPanel 偶发点不开，并可能误触升级。首次打开 / 切换时，透明面板直接等待不保证再次触发的 `sort_children`，协程卡住后仍覆盖世界并接收鼠标。
- 处理：改为带 generation 的有界逐帧测量，统一收尾恢复高度和透明度；透明 / 隐藏阶段递归禁用鼠标，修复 / 升级回调再次校验面板可交互状态。
- 防复发规则：UI 异步布局等待必须“有上限、可取消、必收尾”；任何 `visible=true` 但视觉不可见的 Control 必须同步禁用整棵子树输入；关键点击回归必须向 Viewport 发送真实鼠标事件，不能只直调 debug 方法。
- 验证：真实点击与快速切换全部 15 个建筑 ID 均正常，且 HP、等级、资源、修复 / 升级作业不变；相关建筑、NPC 面板、制造、马匹及项目加载回归通过。

## 2026-07-21 T0046 长期记忆收敛、动态驿站场景与公告牌双页

- 首次睡眠反思不再输出 / 保存 / 显示 `memory_summary`；长期记忆只保留第一人称日记和替换式知识图谱。知识 patch 增加 `subject_label / relation_label / value_label`，NPCPanel 对技术主体、关系和值使用中文映射 / 保底；收紧合同后真实 DeepSeek 反思再次通过且无 fallback。
- 携带 NPC 人设的请求统一注入顶层必填、名单非空的动态 `station_context`：只介绍人员很少的小型边境驿站和当前在站姓名 / 身份，不写战争任务；运行态已验证一人离站后名单 8→7。
- 公告牌改为“通告 / 参考日程”双 Tab，退出丢弃草稿、发布才保存。日程支持时段与内容增删改，始终标明仅供参考；全天已排满时新增草稿会提示先解决重叠。初始通告 / 日程预写所有初始 NPC 见闻，后续发布沿广场在场广播 / 入场快照路由传播；逃离完成者会从地点节点移除且不再接收后续内容。
- Mock / Schema / fake-provider / Godot headless 专项通过。真实 `deepseek-v4-flash` 在中文值合同收紧后反思 1 次、共享场景 4 类业务通过；8 人计划采样 8/8 成功、0 fallback、0 重试，input 126323 / output 13974 tokens。Godot MCP 本轮不可调用，已报告并使用 headless 验收；功能可在主场景直接验证，未新增 GM 入口。

## 2026-07-21 T0045 建筑进度面板、镜头粘键与成长文案

- 修复 BuildingPanel 在修复 / 升级状态切换当帧读到过期满滚动内容高度的问题：同建筑刷新先使用上次稳定高度，完成容器排版后再贴合新内容；首次打开 / 切换时透明测量，不显示大面积空白。
- CameraRig 从 `Input.is_key_pressed(...)` 全局轮询改为事件式 WASD 状态；按键释放停止平移，窗口失焦清空键盘与中键拖拽，LineEdit / TextEdit 聚焦时不接受镜头移动。
- `attribute_improved` 保持 NPCSystem 技能点权威扣除，事件 actor 与 summary 改为 NPC 自身通过锻炼体力 / 脑力提升力量 / 智力，payload 使用 `training_kind` 替代 `assigned_by`。
- 新增 `verify_camera_rig_input.gd`，扩展建筑修复 / 升级与熟练度成长专项。三项专项与项目 headless 通过；Godot MCP 运行态确认围墙升级面板从 502px 精确增至 554px、空白差为 0，S 释放后位置不再继续变化，编辑器无错误。

## 2026-07-21 T0044 对话后计划恢复与对象面板收敛

- 修复玩家有效对话打断 NPC 后无法继续当前小时工作的根因：DialogSystem 记录确实被打断的运行时行动，DailyPlanSystem 专用恢复入口仅在该行动仍匹配当前小时计划，且签名与当前日 / 小时 / 计划版本 / 行动目标完全一致时清除签名，再走正常行动校验；NPC 原本空闲时不会重放已完成短行动，普通重复派发仍保持同阶段去重。
- 马厩去掉“马厩马匹”重复标题，摘要改为“在厩 / 离厩”，逐匹只显示分配对象；未入伍 NPC 的武器、盔甲、马匹和战斗策略禁用控件统一增加征召前置悬停提示。
- NPC 事件库 / 见闻库大号详情收敛为与小框一致的时间和摘要，不再把事件 ID、内部类型、地点 ID、参与者、目标、可见性、重要度或 payload 暴露给玩家；MemorySystem 底层数据不变。
- 修复对象面板底部黑框闪烁：NPCPanel / BuildingPanel 不再在等待容器布局的一帧内临时撑到屏幕最大高度；建筑修复 / 升级浮动提示迁到 `Main/UI` 覆盖层，悬停前后 BuildingPanel 高度保持不变。
- 新增 `verify_player_dialogue_plan_resume.gd`，扩展 NPC 面板、交互、建筑位置和修复升级专项；相关 13 项 Godot 专项与项目 headless 通过。Godot MCP 4.0.1 冻结运行态确认马厩文案、7 个未入伍控件提示、事件详情白名单和悬停前后 614px 高度不变，编辑器错误日志为空。

## 2026-07-21 T0043A 服务依赖中断与弥撒参与

- 将病床治疗、训练位受训与参加弥撒配置为持续依赖行动；无有效医生 / 教官 / 主持者时开始失败，活动中全部服务者离岗时承载者立即失败、释放位置并进入计划重评估。同批服务者仍在移动时允许依赖者等待，到岗后自动重试。
- 教堂拆为普通祈祷、主持弥撒、参加弥撒三项：普通祈祷无需神父，但与主持弥撒互斥；弥撒开始中断已有祈祷。参加者绑定实际主持者，主持正常完成时一并完成，异常中断时一并失败。
- LLM 候选与运行态快照暴露依赖 / 互斥字段，DailyPlanSystem 按服务者优先派发，三份 Prompt 和 MemorySystem 摘要同步区分三种教堂行动；GM 通用行动下拉自动加入 `attend_mass`。
- 新增 `verify_service_dependency_interruptions.gd`，并扩展候选、GM 和 Prompt 合同测试，覆盖诊疗、训练、教堂的开始失败、中途退出、位置释放、正常 / 异常弥撒收束与结构化事件。
- Schema、Mock endpoint、三份 Prompt 与 Godot 相关回归通过；真实 DeepSeek `deepseek-v4-flash` 完成 plan_day、revise_plan 和 7 次 dialogue 验收，全部无 fallback；教堂专项回答确认无人主持时仍可普通祈祷但不能参加弥撒。Godot MCP 冻结运行态确认参加者绑定主持者、互斥失败与主持离岗释放位置，server/addon 4.0.1 版本一致且编辑器无错误。

## 2026-07-21 T0043 建筑位置、团队效率与升级封闭

- 先将五建筑合同同步到玩法、经济建筑、Schema、AI、记忆信息空间、UI、Prompt、API 预算和架构文档；本条覆盖历史上的“12 床 / 12 席”“按类型聚合”“神父离站后祈祷失败”和“位置数量不传播”旧口径。
- `building_defs.json` 落地小教堂固定祭坛 1 + 祈祷席 10、小诊所初始诊疗位 1 + 病床 2、训练场初始教官位 1 + 训练位 2、食堂初始灶台 1 + 固定用餐席 10、宿舍固定床位 10，并以逐级 `level_effects` 配置可扩位置、活动效率和 Max HP。
- BuildingSystem 新增统一可用性 / 可进入性、精确损伤与活动效率、固定位置扩容保护和升级封闭；NPCSystem 在移动前 / 到达时复验，升级开始会中断室内行动、释放位置并清退到广场。
- ActionSystem 把吃饭、睡觉、祈祷、主持弥撒、诊疗和训练映射到具体位置；程序自动选同类空位，满位返回结构化失败。普通祈祷不依赖神父，`lead_mass` 仅“主持弥撒”能力者可执行。全部在岗医生 / 教官共同作用于全部病床 / 训练位，升级与受损倍率实时改变周期效率。
- BuildingPanel 改为逐位置显示名称与占用，并展示精确运作效率；MemorySystem 传播外部 0/25/50/75/100% 效率分档和室内位置增删 / 改名 / 改类型 / 占用差量，精确 HP、精确效率和剩余时长继续降噪。
- LLMBridge 候选补齐资格 / 即时可用性 / 原因 / 所需能力，三份 Prompt 禁止无资格行动和位置编号。Mock / Schema / Prompt 验证通过；真实 DeepSeek `deepseek-v4-flash` 的 plan_day、revise_plan、dialogue 均无 fallback，新增非神职园丁不选择 `eligible=false lead_mass` 的真实检查。
- 新增 `verify_building_service_positions.gd` 并完成建筑、行动、移动、地点信息、面板、每日计划与 Prompt 回归。同步修复制造测试夹具，并将 `insufficient_stage_resources` 规范为 `resource_insufficient` 以恢复真实计划重估语义。
- Godot MCP 4.0.1 / Godot 4.6.2 冻结运行 `Main.tscn`，运行态读取五建筑位置数、弥撒资格与诊所逐位置 UI 文本均正确，编辑器无新增错误。

## 2026-07-21 T0042 NPC 面板人物背景弹窗

- NPC 面板标题行在姓名旁新增“背景”按钮；T0042 当时弹窗展示外貌、背景故事、职业背景、性格、欲望、恐惧、底线、说话风格、代表性表达和能力，T0061 已删除代表性表达并保留其余 9 项。
- 新增 `scripts/core/NPCPromptProfile.gd`，统一构造 LLM 对话顶层 `npc_setting` 与玩家背景详情；没有复制任何 NPC 背景文案，也没有增加 API 调用。
- `verify_npc_panel_state.gd` 覆盖按钮位置、10 项档案字段、弹窗关闭和艾达 / 布鲁诺切换无旧内容残留；NPC 档案、对话行动参考和项目加载回归通过。
- Godot MCP 4.0.1 冻结运行 `Main.tscn` 并实际打开艾达背景弹窗完成画面检查，server/addon 版本一致，编辑器错误日志为空。

## 2026-07-21 T0041 非计划 NPC 对话行动能力参考

- `LLMBridge.build_npc_dialogue_payload(...)` 新增非空 `allowed_actions`，直接复用日计划 `_build_allowed_action_candidates(npc_id, true)`，没有建立 Prompt 专用行为清单。
- `NPCDialogueRequest` 把行动参考收紧为至少一条；对话 Prompt 明确列表内仅表示可尝试、列表外当前做不到，且对话不能生成计划或声称行动已执行。
- 新增 `verify_dialogue_action_reference.gd`，7 个现有对话子上下文全部与日计划候选逐项一致，测试状态下候选数为 31。
- fake-provider、Schema、Mock endpoint 和业务合同通过；真实 DeepSeek `deepseek-v4-flash` 完成玩家-NPC 与 NPC-NPC 能力问答，均确认布鲁诺能加工餐食、不能骑飞龙；整套 6 次真实调用 `failed=0`、`fallback_used=false`。
- Godot MCP 冻结运行 `Main.tscn` 并推进 3 帧后可定位运行态 `LLMBridge`，server/addon 均为 4.0.1 且编辑器错误日志为空。

## 2026-07-21 T0040 右上角对象面板内容自适应重做

- 撤销 T0039 的 NPC 800px 双栏和两块面板固定占满窗口高度方案；NPCPanel 恢复 380-440px 响应式单栏，BuildingPanel 改为 360-420px 响应式宽度，两者均保持右上 16px 安全边距。
- 两块面板改为“内容自然高度决定实际高度、窗口安全高度只设上限”：先按最终宽度完成换行，再计算正文高度；窗口缩放、状态 / 记忆 / 装备和建筑专属区变化后重新适配。空的 NPC 交互结果行不再占位。
- 马匹列表按卡片自然高度和当前窗口剩余空间伸缩，消除默认窗口只溢出约 11px 所造成的内外双滚动；大窗口可展开完整两匹卡片。此前移除的马匹 / 制造冗余说明保持隐藏，非零制造进度确认仍保留。
- `verify_npc_panel_state.gd` 新增 1152×648 / 2048×1109、单栏、高宽比、自然高度、边距和主厅 / 马厩内容量断言；NPC、制造、马匹专项与项目加载通过。Godot MCP 实测默认主厅 360×218、马厩 360×614，大窗口模拟 NPC 440×1017、马厩 409.6×601，所需场景均无多余外层滚动，编辑器错误日志为空。

## 2026-07-21 T0039 扩大右上角对象面板并精简提示

> 本条记录的是 T0039 当时实现；其固定满高与 NPC 双栏布局已由 T0040 替换，文案精简仍保留。

- NPCPanel 从 360px 单列改为 800px 双栏，左侧集中状态、技能、计划入口和并排的事件 / 见闻摘要，右侧集中交互、武器、策略、盔甲与坐骑；面板随窗口高度延伸到上下 16px 安全边距，默认 1152×648 窗口不再需要滚动外层正文。
- BuildingPanel 扩至 460px 并使用同一高度边界；常用建筑正文不再出现外层滚动，马匹子列表增高到可直接容纳三匹卡片，后续更多马匹仍保留子滚动保护。
- NPC 未入伍或合法但尚未分配马匹时隐藏冗余说明；无主武器、无成年在厩马、逃离与已分配状态仍保留有效反馈。制造目标为空及已有目标时移除常驻说明，非零制造进度切换确认弹窗仍完整提示清零与材料不返还风险。
- 更新 NPC 面板、制造和马匹自动化断言；专项与项目加载通过，并通过 Godot MCP 检查默认窗口下两块面板的实际尺寸和外层滚动状态。

## 2026-07-20 T0035-T0038 分阶段制造、具体库存与真实马匹闭环

- 新增 CraftingSystem 和 11 个配置化配方：铁匠铺 / 工械坊先选目标再开工，一个完整周期原子完成一个阶段；中断只清当前周期，换目标经确认后中断旧 revision 并放弃整数阶段，成品按具体 `item_*` 入库。升级后的多工位可并行贡献周期，由 CraftingSystem 串行复验材料和提交阶段。
- 装备与防御器械迁移为具体库存：武器 / 四个盔甲部位精确消耗和返还来源物品，弩床 / 箭塔只能逐件部署对应库存；旧 `weapons` / `armor` / `defense_devices` / `horse_readiness` 只保留兼容且正式路径禁止消费。艾达故事初始剑盾仍不扣库存，箭束本轮只入库。
- 新增 HorseSystem 和两匹初始成年马“栗风 / 灰鬃”，实现个体 HP、自然与照料额外 HP、厩内外饱食、持续进食、自愈、养马驱动成长和稀有繁育。马厩面板逐匹展示；建筑特殊状态严格只传播物理在厩总数 / 成年数 / 小马数。
- NPC 面板新增真实马匹分配：只允许已入伍且持主武器者分配成年在厩马；日常不离厩，集结 / 战斗自动骑乘，退出战斗 / 工作 / 昏迷返厩，失去资格、主武器或逃离自动解除。装备、盔甲和马匹下拉均会即时刷新操作按钮；面板会明确显示未入伍、无主武器、已逃离或暂无成年在厩马等不可分配原因。
- 建筑制造面板提供目标下拉、材料 / 阶段文本、含当期小数周期的进度条和非零进度切换确认，确认文案明确当前阶段名与整件进度。最终复核将制造进度改为直接响应周期信号，并合并同帧马匹刷新，避免逻辑时钟反复重建下拉框和马卡干扰交互。
- 新增 / 迁移制造、马匹、具体装备、器械、HUD、NPC 面板、兵种、训练与 GM 自动化；制造 / 马匹专项同时覆盖进入快照、仅室内字段差量和个体信息防泄露，通用工作框架夹具补齐“先有制造目标、再判断阶段材料”的前置顺序，9 项既有战斗夹具也迁移为具体剑盾 / 弓 / 锁子甲与真实成年马。GM 综合回归固定使用离线失败 + 规则 / 模板路径并显式生成规则计划，避免普通自动化误调用真实 provider；最终 27 项整合回归、主场景 headless 加载及 Godot MCP 实际面板检查通过。

## 2026-07-20 T0034 制造、具体库存与马匹系统设计冻结

- 核查 `game_design.md`、现有武器 / 盔甲 / 器械定义和历史删除记录，冻结铁匠铺 6 种、工械坊 5 种制造目标；补充箭束具体库存，不把泛称“简易塔防装置”重新解释为已删除的拒马。
- 冻结一个工作周期一个阶段、中断仅回退当前周期、整数阶段保留、换目标确认清零、多工位串行落账、逐阶段原子扣料和完成后具体成品入库规则。
- 冻结具体武器 / 盔甲 / 器械库存，不再允许聚合库存跨品类转换；箭束暂不扩展战斗弹药消耗。
- 冻结两匹初始成年马、厩内外饱食、持续进食、自愈、低概率繁育、养马驱动成长和额外 HP 规则，以及已入伍持主武器 NPC 的马匹分配与战时上下马边界。
- 严格核查地点信息传播：制造状态与马厩数量属于可进入建筑内部 `special_state`，进入者得快照、在场可接收者得字段差量；小数进度与逐匹马详情不进入 NPC 见闻，也不公开到广场。实现拆分为 T0035-T0038。

## 2026-07-20 T0033 玩家对话可选剩余日重评估与马塞尔酿酒人设

- 马塞尔档案在神父背景中简短补充“他擅长酿酒”，没有把酿酒改写为职业、本职工作或硬编码行动。
- 玩家-NPC 对话面板新增“结束后重估计划”开关：守备官从 NPC 面板主动发起默认关闭，NPC 主动交涉默认开启；旁听和逃离挽留隐藏。只有完成至少一轮有效 NPC LLM 回复且开关开启，结束后才触发一次对话型重评估；关闭时恢复原计划当前小时行动（T0044 后收紧为只恢复本次确实打断且仍匹配当前计划的行动）。攻击事实保持独立强制重评估。
- 计划修订新增 `local_changes` 与 `remaining_day` 范围。剩余日范围要求真实模型逐小时返回当前小时至 23 点，过去计划保持不变；Godot 与后端双层校验完整小时集合、即时行动、工作阶段下限及精确行动白名单。后端首个真实响应若仅业务合同失败，会携带具体错误向同一真实 provider 请求一次纠正；失败仍返回真实错误，不使用 Mock / 规则降级。
- Python Schema、Prompt、endpoint、Godot UI / 对话边界 / 主动交涉 / 剩余日合并与项目加载回归通过。真实 DeepSeek `deepseek-v4-flash` 同时通过局部 2 项与剩余日 16 项修订，`fallback_used=false`。

## 2026-07-20 T0032 修复自主对话气泡真实鼠标点击

- 用户实机反馈气泡可见但无法点击。定位到 `NPCSystem._unhandled_input(...)` 的全局 Camera3D 射线会先命中气泡子 Area3D，再沿父节点找到 NPC id，将其误判为 NPC 本体点击并消费事件；原测试直接调用气泡 debug 方法，未覆盖这条真实输入顺序。
- 气泡新增交互类型、NPC id 和 `dialogue_id` 元数据；NPCSystem 射线拾取改为结构化结果，优先把气泡命中路由到 `npc_dialogue_bubble_clicked`，普通 NPC 胶囊命中才打开 NPC 面板。
- 旁听专项改用 Camera3D 世界到屏幕投影和 Viewport 鼠标移动 / 按下 / 释放事件，确认医生、厨子双方气泡都能打开，关闭后可重开同一会话且不误开 NPC 面板；自然结束后真实点击 NPC 本体仍能打开面板。NPC 生成、NPC 面板、NPC-NPC 对话竞态和项目加载回归通过。

## 2026-07-20 T0031 NPC-NPC 旁听生命周期复验与艾达初始剑盾

- 复验自主 NPC-NPC 旁听运行链路：接受后双方气泡可点击，弹窗消费同一 `dialogue_id` 的实时更新；LLM pending 时关闭只隐藏 UI、不取消请求，再点任一参与者气泡会恢复最新待回复内容。自然结束后双方气泡清理，已打开窗口保留最后一句与结束状态，直到玩家手动关闭。
- `data/npc_profiles.json` 为艾达新增 `initial_equipment.main_weapon=sword_shield`；`EquipmentSystem` 从正式武器定义装载完整开局槽位，只填空槽，不调用库存扣除与玩家交互事件入口。艾达因此开局即为近战步兵，后续玩家换装仍按正常规则返还旧剑盾库存并写 `equipment_changed`。
- 更新旁听、装备、兵种和战斗节奏专项断言。`verify_npc_npc_dialogue_observer_ui.gd`、`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_combat_pacing.gd`、`verify_combat_alarm_rally.gd`、`verify_combat_strategies.gd`、`verify_no_available_combatants_failure.gd`、NPC 档案 / 生成 / HUD 资源回归与项目 headless 加载均通过；`verify_no_available_combatants_failure.gd` 结束时仍会输出既有异步 LLM 线程随测试树释放的清理警告，但专项断言与退出码通过，本任务未修改该链路。GM 综合脚本在未启动后端时会停在既有异步总结等待并报超时，不作为本次通过项。

## 2026-07-20 T0030 NPC-NPC 无硬上限、软性收尾与拒绝单方重评估

- 自主 NPC-NPC 正式会话移除第 3 / 5 轮程序硬截断；会话与请求以 `max_rounds=0` 表示无硬上限，并新增 `soft_round_threshold=5` / `soft_round_guidance`。`current_round` 继续逐轮进入上下文；Prompt 要求事情谈完即可自然告别，第 6 轮起若无紧急 / 必要事项应告别结束，有必要时允许继续。
- `DialogSystem` 改为完全由正式回复的 `should_end_dialogue` 驱动自然结束：结束标记所在 `reply_text` 先追加到历史和 `dialogue_turn`，记录结束者 / 最后一句 / 轮次，再立即结束，不把告别语发给另一方等待回复。旁听 UI 显示当前轮次、无硬上限和软性收尾提示。
- 邀请拒绝后的重评估名单只保留发起者；拒绝者从未被打断，保持当前行动 / 工位和计划且不重评估。邀请接受后的正式会话结束仍让可行动且处于 work 模式的双方各重评估一次。逃离挽留的独立 5 轮硬规则保持不变。
- Python Schema、Prompt、Mock endpoint、业务合同和 Model Adapter 回归通过；Godot 邀请合同新增越过第 5 轮至第 7 轮的无硬截断验证，并覆盖最后一句后无下一次调用、拒绝单方重评估、正式结束双方重评估。计划行动、竞态、旁听 UI、LLMBridge 与逐轮降速回归均通过。
- 真实 DeepSeek `deepseek-v4-flash` 已验证邀请接受、邀请拒绝和第 6 轮非紧急软性结束，`response_kind=reply_to_npc`、`should_end_dialogue=true`、`fallback_used=false`；真实 Godot 邀请 + 正式回复旁听链路确认逐请求慢速注册 / 释放和倍率恢复。

## 2026-07-20 T0029 NPC-NPC 邀请、三轮上限与对话后计划重评估

- 历史口径说明：本节的“最多 3 轮”和“邀请拒绝后双方重评估”已由同日 T0030 替代；邀请阶段、接受后才打断、逐轮结束字段和玩家有效对话重评估仍有效。
- 审计确认旧实现会在发起者到达后直接打断双方行动，没有让目标 NPC 先接受 / 拒绝，且代码、配置与文档仍使用 5 轮；现已改为独立邀请阶段，邀请不计正式轮次、不提前打断目标，接受后才释放双方普通行动 / 工位并进入最多 3 轮正式会话。
- 对话 Prompt、Schema、后端业务校验、真实 provider 与显式 Mock 合同统一增加 `dialogue_phase` / `invitation_result`；邀请只能接受或拒绝，正式会话每轮可主动结束，第 3 轮由程序与后端共同强制结束。
- 邀请和每轮正式对话分别申请 / 释放 TimeSystem 慢速；目标拒绝、正式对话自然结束或被打断后，双方都进入计划重评估。
- 修复玩家有效对话重评估时机：只有一轮“玩家消息 + NPC 有效 LLM 回复”完成后才登记结束重评估；仅打开窗口或取消未完成回复不会误触发，攻击事实仍按原边界触发。
- Python Schema / 业务 / Prompt / Mock 回归、Godot 邀请合同 / 计划行动 / 竞态 / UI / 睡眠边界回归全部通过；真实 DeepSeek 验证邀请接受、拒绝和正式回复均为 `fallback_used=false`，真实 Godot 旁听链路确认邀请及正式轮分别降速。

## 2026-07-20 T0028 NPC-NPC 自主对话气泡、旁听 UI 与逐轮降速

- 确认旧实现只有后台自主对话和通用 LLM 三点状态标记：自主会话固定 `ui_visible=false`，没有双方可点击气泡，也没有只读对话进程入口。
- `NPC.gd` 新增运行时 `AutonomousDialogueBubble`：浅色小气泡、三点文本和独立 3D 点击区只在匹配的自主会话中对双方显示；结束、失败、取消或高优先级中断后随 `active_dialogue_id` 清理。自主对话气泡显示时隐藏重复通用 LLM 三点标记。
- `EventBus` 新增带 `npc_id + dialogue_id` 的气泡点击信号；`DialogSystem` 提供参与者与会话双校验的只读观察快照，并保存稳定的双方显示名。
- `DialogPanel` 新增旁听模式：显示双方姓名、当前 / 最大轮次、公开性、LLM 等待状态、待回复开场和历史；隐藏输入、发送、攻击、应征与公开性操作。关闭只清理本地 UI，不结束会话、不取消请求、不触发重评估；自然结束后保留最终记录。
- NPC-NPC 每轮请求显式设置 `requires_time_slowdown=true`，并在 pending 状态建立后再广播一次展示快照。连续三轮失败端专项确认每轮 `llm_dialogue_wait` 单独注册 / 释放；真实 DeepSeek Godot 专项确认气泡点击、真实回复、慢速生效、释放和玩家 `x4` 倍率恢复。
- 验证通过：新 fake provider UI 专项、真实 provider 旁听专项、真实 NPC-NPC 后端 smoke、LLM 慢速审计、玩家对话 UI、自主计划对话、对话竞态、NPC 面板、项目解析和 diff whitespace 检查。真实 provider=`deepseek`、model=`deepseek-v4-flash`、`response_kind=reply_to_npc`、`fallback_used=false`。
- 功能可直接在 `Main.tscn` 验证；既有 GM `npc_talk` 可构造双方气泡，不新增重复调试入口。当前用户编辑器已占用 Godot MCP 6550；没有抢占 / 重启 broker，运行验收使用不加载编辑器插件的 Godot 4.6.2 headless 场景脚本完成。

## 2026-07-17 T0025 NPC-NPC 自主对话计划行动与设计目录补齐

- 将 `talk_to_npc` 接入正式每日计划与失败修订：候选携带具体 NPC、地点、action kind 和交涉目标，发起者会追踪目标并预定双方。此处当时实现为到达后直接打断普通行动、释放工位并最多对话 5 轮；该历史口径已由 T0029 的“先邀请、接受后最多 3 轮”替代。
- 修复对话生命周期竞态：批量计划按教官、其他非对话、受训者、对话顺序落地；跨小时只结束上一时段自主会话；战斗 / 避战 / 昏迷等权威模式不会被日程或清理覆盖；玩家只查看对话草稿不打断后台 NPC 对话，实际发送 / 攻击才提升优先级；退出测试不再遗留 SceneTreeTimer。
- 工位失败上下文补齐占用者、工位和实时建筑状态；修订 Prompt 明确优先考虑找占用者协调，并在替换第 6 个工作时段时补回工作。当前计划运行态按 action + target + location 识别，同一行动改换 NPC / 地点目标也会真正替换；计划版本、请求日 / 小时、逐 NPC 重评估记录和最新失败排队防止旧响应覆盖新计划或后续失败丢失。
- 对照 `game_design.md` 10.3 补齐并验证祈祷、地点拜访、主动找守备官和特殊逃离意向；动态修复 / 升级 / 昏迷治疗协助保持目标驱动。`visit_location_*` 状态现可正确格式化，不再产生未知行动警告。逃离意向仍交给 CombatSystem，逃离挽留对话不进入日程。
- 后端 Schema / 业务校验要求精确匹配 `action_id + action_kind + target_id + location_id`，拒绝自聊、空对话目的和非法目标；仅对 Schema 已通过且唯一命中候选的冗余 kind（或固定 idle 合同）做确定性规范化，并以 `model_normalizations` 留痕。NPC-NPC 回复在后端与 Godot 双层校验回复者和 `reply_to_npc`。
- 修复真实计划数组乱序风险：Godot 按每项声明的 `hour` 建表再排成 0-23，重复 / 越界 / 缺失小时拒绝；同一计划版本同一时段单次派发，修订单后继队列和连续 3 次迟到落地失败上限避免重复 / 无限循环。
- Godot 目录、运行闭环、对话主链路 / 竞态、基础行动、记忆、计划重估、行为模式、睡眠边界和 LLM 降速回归全部通过；隔离 Mock 后端的 UI 自动化通过。真实 DeepSeek 工位修订返回 `talk_to_npc -> priest_01 @ clinic`、6 个工作阶段，真实 NPC-NPC 回复为 `reply_to_npc`，均 `fallback_used=false`；真实正式开局 8/8 成功、峰值并发 8、0 fallback、全部 `llm_plan_day`。
- Godot MCP 已连接用户当前编辑器，server/addon 均为 4.0.1 且版本一致；运行 `Main.tscn`、查询 8 名 NPC 计划来源和编辑器错误日志均正常。Godot 4.6.2 headless 解析与专项回归同步通过。

## 2026-07-17 T0024 NPC 长期信息入口、8 路总结 / 跨天并发与来源统一

- NPC 面板把旧全宽“当前计划”改为“当前计划 / 日记 / 知识”三等分按钮；移除面板内嵌日记框，日记和知识图谱使用既有详情弹窗，并继续保留事件 / 见闻刷新时的阅读滚动位置。
- `DailyReflectionSystem` 明确最多 8 路同时请求，新增当前活动数、实际峰值、启动 / 完成数、请求 ID 与逐 NPC 结果快照；GM `reflection_result` 同时输出该快照。
- `DailyPlanSystem` 正式批次新增 `max_observed_concurrent`。真实开局与 `day_started` 跨天分别实测 8 个请求同时在飞，整批成功后才恢复时间。
- 后端五个正式 LLM 成功路由统一经 `model_success_payload(...)` 返回 provider / model / fallback 元数据。Godot 睡眠总结依据元数据写 `llm_daily_reflection` 或显式 `mock_daily_reflection`；缺少元数据或模型 fallback 不再被猜成真实成功。静态审计确认 Godot 源码不存在 `mock_revision`。
- 真实 DeepSeek 本轮 24 次并发业务验收全部成功：8 次首次睡眠总结、8 次开局计划、8 次跨天计划；failed=0、fallback=0、全部 `finish_reason=stop`、`attempt_count=1`。独立 Mock 后端验证正式计划链路仍在 health 阶段拒绝。
- Python Schema / Prompt / endpoint / 来源审计与 Godot UI、总结、计划、低血量、指令、降速、GM、项目加载回归通过。Godot MCP 仍因重复 Codex 会话连接被替换，本轮按规则未强行使用。

## 2026-07-17 T0023 行动失败真实计划重估与 NPC 当前计划 UI

- 根因确认：真实 `/npc/revise_plan` 响应缺少 provider 元数据，而 Godot 把所有成功结果硬编码为 `mock_revision`；失败分支则立即写入并执行 `rule_revision_fallback`。同一种 `last_action_result` 还可能长期留在去重缓存中，阻止后续同类失败再次重估。
- `/npc/revise_plan` 成功响应补齐 provider、model 和 fallback 元数据。正式重估检查真实 provider，异步请求最多尝试 3 次；成功统一写为 `llm_plan_revision`，最终失败保留原计划、不写 `plan_revised`、不执行 Mock 或规则修订。
- 资源不足、工位占用和其他日常 `failed` 结果继续由 ActionSystem 权威失败状态触发；每次实际修订请求注册 TimeSystem 慢速并在完成、失败或取消后释放。正常行动 / 成功修订会清理旧失败去重值。
- NPC 面板在事件库正上方新增“当前计划”按钮，详情显示 24 小时计划、当前小时标记、行动、理由和来源；计划替换或修订随 `npc_daily_plan_changed` 覆盖刷新。
- 事件库 / 见闻库详情刷新不再打断阅读：重写 TextEdit 前保存横纵滚动值，并以刷新代次合并同帧连续事件，布局完成后恢复玩家原位置。
- 独立 Mock 后端验证正式链路在 health 阶段拒绝且 usage 调用数为 0；真实 DeepSeek `deepseek-v4-flash` Godot 链路验证 `revise_plan` 成功、`fallback_used=false`、`finish_reason=stop`、来源 `llm_plan_revision` 且慢速已释放。Python、Godot UI / 计划 / GM / 降速与项目加载回归通过。
- Godot MCP 因重复 Codex 会话连接被替换，本轮按规则未强行继续，改用 Godot 4.6.2 headless 和当前真实后端验收。

## 2026-07-17 T0022 正式每日计划真实 LLM 专用与 8 路并发

- 排查运行日志后确认两个问题：真实 DeepSeek 成功计划被 Godot 错误标记为 `mock_plan_day`；单人真实请求失败时会被 `rule_plan_fallback` 掩盖并继续游戏。
- `/npc/plan_day` 成功响应附加 provider、model 和 fallback 运行元数据。Godot 正式路径在请求前检查 `/health`，拒绝 Mock / 未配置 / 启用 Mock fallback 的 provider，并对每份业务响应再次验证。
- 真实成功计划的 result、plan item 和 `plan_created` 统一标记为 `llm_plan_day`；删除每日计划规则降级函数。显式开发 Mock 测试和 GM 纯规则入口仍隔离保留，正式开局 / 新一天不会调用它们。
- 开局和 `day_started` 批次改为 8 路并发，每名 NPC 最多 3 次真实请求。全部成功后才统一执行并恢复时间；任一仍失败时保持暂停、禁用自动执行，所有 NPC 保持 `planning_day`。
- 新增正式路径拒绝 Mock provider 专项，更新三状态启动、每日计划、端点元数据和降速回归。显式 Mock 测试还修正了守备官指令触发的独立异步修订慢速等待，避免误判为每日计划遗留。
- 真实 DeepSeek `deepseek-v4-flash` 8 NPC 并发验收通过：8 成功、0 失败、0 fallback，全部 `finish_reason=stop`、`attempt_count=1`，Godot 验证全部来源为 `llm_plan_day`。正式 Mock 拦截、Python endpoint / Prompt / Schema、Godot 启动 / 计划 / 降速与项目加载回归通过。
- Godot MCP 因重复 Codex 会话连接被替换，本轮按规则未强行继续，改用 Godot 4.6.2 headless 与真实后端验收。

## 2026-07-16 T0021 移除 LLM 正常生成的固定总时长误杀

- 确认 T0020 的 75 / 90 秒业务总时长会把仍在正常生成的模型请求误判为失败；同时旧后端 `LLM_TIMEOUT_SECONDS` 混合了连接和读取语义，难以区分连接故障与正常长生成。
- `LLMBridge` 删除五类业务的独立总时长配置；正式业务请求发出后不再设置客户端响应 deadline，2 秒配置只用于连接本地 / 游戏后端和 health / usage 等只读短请求。
- Model Adapter 改为供应商流式 SSE 请求，逐块聚合 `delta.content`、`finish_reason` 与最终 usage；keep-alive 和 token 都代表请求仍有进展，不会因墙钟经过固定时长失败。
- 后端配置拆为 `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS=10` 和 `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS=120`。前者只保护建连，后者只处理流完全无数据的死连接，不是模型生成时长上限。
- 更新 LLM 审计与 Godot 降速审计，覆盖 SSE 分片 / keep-alive 聚合、业务请求无总 deadline、只读请求保留短 deadline、旧字段移除和慢速释放。
- 五类 fake / mock / Schema / Prompt、Godot 开局 / 计划重评估 / 首次睡眠总结 / 低血量判定 / 项目加载回归通过。
- 真实 DeepSeek 流式验收通过：对话、每日计划、计划修订、战时低血量心理判定和首次睡眠总结全部成功；真实 8 NPC 开局异步计划批次通过且无 mock fallback。

## 2026-07-16 T0020 LLM 输出限制与时间降速全链路审计

- 移除 `ModelAdapterConfig`、`.env.example`、本地 `.env` 和供应商请求中的客户端单次输出 token 上限；五类正式业务调用不再发送 `max_tokens`，`/health` 快照显示 `client_output_token_limit_applied=false`。累计调用、累计 token 和累计费用预算仍由默认关闭的 `LLM_BUDGET_MAX_*` 独立控制。
- 把空内容、非法 JSON 和 `finish_reason=length` 的紧凑重试从计划类扩展到 `dialogue`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection` 全部正式 call_type，保留 Schema 与业务白名单校验和真实失败 usage。
- `LLMBridge` 增加低血量心理判定与首次睡眠总结异步请求，并修正异步对话误用 2 秒通用超时；当时暂设的 75 / 90 秒业务总时长已由 T0021 移除，health / usage 继续使用 2 秒只读短超时。
- `CombatSystem` 的低血量判定、`DailyReflectionSystem` 的首次睡眠总结和 UI 的 NPC-NPC 消息改为异步应用；同步接口只保留兼容 / 调试用途，并同样遵守慢速注册规则。
- 五类正式请求按 payload 的 `requires_time_slowdown` 注册带 call_type 的 TimeSystem 慢速原因，所有完成、失败、取消、超时和降级路径释放；正式开局批量计划继续由 `GameStartupSystem` 全局暂停时间。运行态快照新增逐请求慢速注册 / 释放审计。
- 新增 `verify_llm_call_audit.py` 和 `verify_llm_time_slowdown_audit.gd`，并更新计划、对话、低血量判定、首次睡眠总结、GM 和战场公开信息脚本以等待异步结果。
- mock / Schema / endpoint、Godot headless 全链路和真实 DeepSeek 五类业务路径均通过；真实 8 人开局计划批次通过且无 mock fallback。Godot MCP 因重复 Codex 会话连接被替换，本轮按规则未强行使用。

## 2026-07-16 T0019 开局计划门与异步重评估修复

- 根据实机日志确认两个独立根因：开局代码主动先执行规则计划、再后台替换真实计划，导致“未制定就执行”；`/npc/revise_plan` 当时仍受固定单次输出额度限制，失败记录均为 `finish_reason=length` 与截断 JSON。
- 正式开局改为计划门：暂停 TimeSystem 和计划自动执行，8 名 NPC 写入 `wake_up`、清空旧计划并显示“制定计划”；每日计划最多 2 路并发，单人失败明确规则降级，整批完成后才统一执行当前小时项并恢复时间。
- `LLMBridge` 新增异步每日计划 / 计划修订和专用完成信号；计划修订不再同步阻塞主线程，并继续支持取消与慢速释放。后续 T0021 已移除正式业务的固定总时长。
- 新增 `plan_revision_system_prompt.txt`，要求只返回 1-3 个变化小时项；后端校验 NPC id、修订项数量、行动白名单和当前小时。当时的固定输出额度修复已由 T0020 取代，当前所有正式 call_type 均不发送客户端单次输出 token 上限。
- 真实 DeepSeek 验收：计划修订返回 `finish_reason=stop` 且无 fallback；真实开局 8 人批次专项通过。T0020 后又在无客户端输出上限配置下完成全 call_type 回归。
- 验证通过：`verify_plan_revision_prompt.py`、`verify_plan_revision_endpoint.py`、`verify_plan_revision_prompt_real.py`、`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`verify_plan_day_prompt.py`、`verify_game_startup_modes.gd`、`verify_game_startup_real_async.gd`、`verify_daily_plan_reevaluation.gd`、`verify_daily_plan_system.gd`、`verify_llm_bridge.gd`、`verify_npc_panel_state.gd` 和 Godot headless 项目加载。
- Godot MCP 本轮因重复 Codex 会话导致连接被替换，未用于场景内验收；没有强行继续 MCP 操作，改用 Godot 4.6.2 headless 与真实后端路径验证。

## 2026-07-16 T0019 三状态启动模式与正式游戏循环

- 新增 `GameStartupSystem`，在 Inspector 暴露“静止调试 / 正式循环（无新手引导）/ 正式循环（新手引导占位）”三个状态；主场景默认选择正式循环且不启用新手引导。
- 静止调试模式暂停 TimeSystem、关闭每日计划自动执行，不生成起床、计划或行动；两个正式模式恢复循环，并为 8 名 NPC 逐人启动新一天。
- `DailyPlanSystem` 新增 `start_new_day_for_npc(...)` / `start_new_day_for_all(...)`，先记录私有 `wake_up`，再复用现有 LLM / 显式 Mock 优先、真实失败规则降级路径生成 24 小时计划并立即执行当前小时项。
- 新手引导模式当前只暴露 `tutorial_requested` 和 `placeholder_not_implemented` 快照，不伪造教学步骤；Headless 环境默认跳过自动启动以保护既有测试隔离。
- 新增 `verify_game_startup_modes.gd`，覆盖主场景默认值、三个模式、8 人起床、24 小时计划、当前行动、暂停和计划自动执行状态；相关每日计划、记忆、NPC、行动、GM、项目加载回归通过，Godot MCP 连接自检通过。
- 功能可从 `Main.tscn` 直接运行，并可在 `Main/Systems/GameStartupSystem` Inspector 切换，因此未新增 GM 面板入口。

## 2026-07-16 T1508 工程器械部署

- 新增数据驱动的 `defense_device_defs.json`，集中定义弩床、箭塔、围墙槽位、库存成本、战斗效果和表现元数据；拒马类型与槽位已按需求删除。
- 新增权威 `DefenseDeviceSystem`，校验围墙 / 工械坊状态、器械与槽位兼容性和库存，以原子方式完成扣除、部署、占槽和事件写入；`deploy_device(device_id, slot_id)` 不选择或校验 NPC。
- 弩床与箭塔按战斗动作秒自动攻击，通过 CombatSystem 复用敌人防御、HP 与清敌流程；箭塔使用较低单次伤害和更短间隔。CombatSystem 已移除器械移动减速接缝。
- `defense_device_deployed` / `defense_device_triggered` 已加入 MemorySystem 保留类型、必需 payload 和确定性中文 summary；事件主体为守备官，不进入 NPC 亲历事件库，广场在场 NPC 仍按既有规则获得见闻。
- 围墙 BuildingPanel 新增器械库存、类型、槽位和部署结果，不显示部署者；UI 只调用权威系统。无需新增 GM 入口，既有资源 / 刷敌 / 推进战斗入口可辅助验证。
- 新增 `DefenseDevicePresenter`、`DefenseDeviceView.tscn` 和低模几何占位。表现实例固定提供 `ModelMount`，配置保留 `presentation.model_scene`，给 T15 正式模型、动画和特效留出无逻辑迁移的替换点。
- 更新 `verify_defense_device_deployment.gd`，覆盖 T0805 制造效率继承、库存原子性、无部署者 API / UI / 事件边界、拒马类型与槽位清除、弩床 / 箭塔自动攻击和模型挂点；战斗、记忆、建筑面板、HUD、GM、公告和商人回归通过。

## 2026-07-16 T1506 公告输入与 T1507 商人交易

- 主厅前 `NoticeBoard` 新增独立点击区、相机射线拾取和当前公告世界预览；`NoticeBoardPanel` 提供自由文本发布与留空清空。公告牌继续不属于 BuildingSystem。
- `MemorySystem.set_plaza_notice(...)` 返回实际广播事件并忽略相同文本；公告权威状态只保存在广场 `current_notice`，变更即时生成 `plaza_notice_changed` 并广播给当前在场、可接收见闻的 NPC。
- 新增 `data/merchant_defs.json`：后门商队每日 10:00-16:00 到访，粮食/木材/石料/铁买价为 2/3/4/5 第纳尔，酒卖价为 7 第纳尔。
- 新增 `MerchantSystem`：监听逻辑时间、控制后门商人标记和交易时段、校验报价/数量/余额/库存，并调用 ResourceSystem 权威结算；失败交易不修改资源。
- 新增 `MerchantPanel`：显示时段、配置报价、交易数量和驿站库存；UI 只提交买卖请求，不直接修改资源。酿酒完成仍只增加 `wine`，出售酒必须在商人到访时扣酒并增加第纳尔。
- MemorySystem 新增 `merchant_arrived`、`merchant_departed`、`merchant_trade_completed` 确定性 summary 与必需 payload；三类事件均按广场 `local_public` 广播。
- 未新增 GM 入口：公告牌和商人交易都能在 `Main.tscn` 直接点击验证；现有 GM 改时间、加第纳尔/酒和查看事件入口足以辅助验收，`docs/GM_PANEL.md` 无需改动。
- 新增 `tools/verify_notice_board_input.gd` 和 `tools/verify_merchant_trade_system.gd`；验证公告状态/广播/非建筑边界、商人时段、买入、卖酒、失败原子性、离场和事件结构。回归通过 `verify_tavern_wine_trade.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_structured_memory_events.gd`、`verify_location_info_nodes.gd`、`verify_gm_panel.gd`、`verify_hud_resources.gd`、`verify_action_system_basic.gd` 与项目 headless 加载。

## 2026-07-16 T1501 8 名 NPC 姓名与职业语气

- 正式确认 8 名 NPC 姓名：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文；老兵副官的 `background_job` 统一为“老兵副官”。
- `data/npc_profiles.json` 为每人新增简短 `speech_style` 和 3 条 `signature_lines`，并按 `game_design.md` 第 9 章收敛职业语气、欲望、恐惧与底线；背景保持短文本，世界内人设只使用“守备官”。
- `LLMBridge._build_npc_setting(...)` 与共享 `_build_npc_context(...)` 注入职业语气和台词样例；后端 `NPCIdentity` 同步新增字段，避免对话与其他 NPC 中心 Prompt 使用两套人设来源。
- `dialogue_system_prompt.txt` 要求模型从职业经验出发回应、吸收口吻但不逐字复读样例，并避免通用士兵台词；首次睡眠总结 Prompt 同步参考 `speech_style`。
- 未新增 GM 入口：姓名和职业对话都能从 `Main.tscn` 既有 NPC 标签 / 面板 / 对话路径直接验证，现有 GM 对话与 LLM usage 已足够辅助调试。
- 新增 `tools/verify_npc_character_profiles.gd` 和 `tools/verify_npc_character_dialogue_real.py`，覆盖正式档案、Godot payload 和真实 provider 职业身份回复。
- 真实 DeepSeek `deepseek-v4-flash` 已对 8 名 NPC 各完成一次 `/npc/dialogue`，回复分别体现马厩、食堂、菜园、打铁、防线、弥撒 / 安抚、治伤配药、工械 / 承重身份；usage 显示 calls=8、failed=0、`fallback_used=false`。
- Godot MCP 4.0.1 运行 `Main.tscn` 后确认运行态生成 8 人、姓名 / 职业正确、每人 1 条 `speech_style` 和 3 条 `signature_lines`；对话顶层与共享身份上下文注入一致，编辑器错误日志为空。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_battle_judgement_prompt.py`、`python tools/verify_daily_reflection_prompt.py`、`python tools/verify_npc_character_dialogue_real.py`、`godot --headless --path . --script res://tools/verify_npc_character_profiles.gd`、`godot --headless --path . --script res://tools/verify_npc_skill_schema.gd`、`godot --headless --path . --script res://tools/verify_npc_generation_click.gd`、`godot --headless --path . --quit-after 1`。

## 2026-07-07 T1406 API 额度面板 / 调试信息

- `ModelAdapter` 新增预算守门配置：`LLM_BUDGET_MAX_CALLS`、`LLM_BUDGET_MAX_INPUT_TOKENS`、`LLM_BUDGET_MAX_OUTPUT_TOKENS`、`LLM_BUDGET_MAX_TOTAL_TOKENS` 和 `LLM_BUDGET_MAX_COST`，默认 `0` 关闭。超预算时业务接口返回 HTTP 429 / `budget_exceeded`，usage 记录 `BudgetExceeded`、`budget_blocked`、request id、call_type、provider/model、NPC id 和失败原因，不自动 mock fallback。
- `/debug/llm_usage` 与 `/health` 的 adapter 快照新增预算上限、已用量、剩余额度、是否启用和最近预算错误；既有 usage 继续记录调用次数、类型、token、费用估算、失败原因、http 状态、异常类型、fallback / 降级来源。
- `TimeSystem.get_time_scale_snapshot()` 新增 `last_time_scale_reason`；`LLMBridge.debug_get_llm_runtime_snapshot()` 新增当前等待中的 LLM 请求数、pending slowdown request id、NPC 活动请求、异步请求数量、后端状态、有效逻辑倍率和最近倍率变化原因。
- GM 面板“成本统计”按钮和 `llm_usage` 命令现在同时显示后端 usage / budget 与 Godot runtime 快照；该入口只读，不申请慢速、不写权威状态。
- `backend/.env.example`、`backend/README.md`、`API_BUDGET.md`、`UI_UX.md`、`GM_PANEL.md`、`TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md` 和 `TASKS.md` 已同步回写。
- 新增 `tools/verify_api_budget_debug.py`，覆盖 fake real-provider usage / budget 记录、预算超限 usage 和 Flask 业务接口 HTTP 429。
- 真实 provider usage 验收：`python tools/verify_plan_day_prompt_real.py` 本轮因 DeepSeek `/npc/plan_day` 超时返回 `provider_unavailable`，usage 记录 `provider=deepseek`、`model=deepseek-v4-flash`、`exception_type=ConnectionError`、`fallback_used=false`；随后使用真实 DeepSeek 对单次 `/npc/dialogue` 发起短请求，返回 200，`/debug/llm_usage` 显示 calls=1、failed=0、`fallback_used=false`。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_api_budget_debug.py tools/verify_mock_model_adapter.py`、`python tools/verify_api_budget_debug.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、临时以 `LLM_PROVIDER=mock` 启动后端后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

## 2026-07-07 T1405 首次睡眠总结 Prompt

- 新增 `data/prompts/daily_reflection_system_prompt.txt`，作为 `/npc/daily_reflection` 真实 provider 的首次睡眠总结系统 Prompt；`ModelAdapter` 在 `call_type=daily_reflection` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- Prompt 明确区分长期记忆的两种更新语义：`knowledge_graph_updates` 是以 `subject + relation` 为键的替换式当前状态更新，`diary_entry` 是符合 NPC 语气的第一人称日记并按天增量追加。
- `/npc/daily_reflection` 当时新增 NPC id、日期、日记 / 摘要非空等业务校验；T0046 已移除独立摘要字段，当前只校验日记非空、知识图谱更新字段和“守备官”世界内称呼，不合法时返回 `model_output_invalid` 并写入失败 usage。
- `NPCSystem.apply_daily_reflection(...)` 不再写入 append-only `knowledge_graph.patches`，改为规范化 `knowledge_graph.by_subject[subject][relation] = 当前值`；同键后续更新覆盖旧值，日记继续追加。
- 新增 `tools/verify_daily_reflection_prompt.py` fake real-provider 验证和 `tools/verify_daily_reflection_prompt_real.py` 真实 provider smoke 验证。真实 DeepSeek `deepseek-v4-flash` 已完成 1 次 `/npc/daily_reflection` 调用，`fallback_used=false` 且无失败。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py backend/schemas/npc_ai.py tools/verify_daily_reflection_prompt.py tools/verify_daily_reflection_prompt_real.py tools/verify_daily_reflection_endpoint.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py`、`python tools/verify_daily_reflection_prompt.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_daily_reflection_prompt_real.py`、`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、临时以 `LLM_PROVIDER=mock` 启动后端后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --quit-after 1`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_battle_judgement_prompt.py`。

## 2026-07-07 T1404 战时对话与低血量心理 Prompt

- 新增 `data/prompts/battle_judgement_system_prompt.txt`，作为 `/npc/battle_judgement` 真实 provider 的独立低血量自身心理判定系统 Prompt；`ModelAdapter` 在 `call_type=battle_judgement` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 战时公开对话继续复用 `data/prompts/dialogue_system_prompt.txt`；T1404 验收覆盖 `interaction_context=combat` 的结构化 `wartime_reaction`，并与低血量判定同轮真实 provider smoke 验证。
- `/npc/battle_judgement` 在 `BattleJudgementResponse` Schema 校验后新增业务校验：`decision` 必须来自请求 `allowed_decisions`，`should_start_escape` 只能在 `decision == "escape_station"` 时为 true；不合法时返回 `model_output_invalid` 并写入失败 usage，Godot 继续按允许结果规则降级。
- 新增 `tools/verify_battle_judgement_prompt.py` fake real-provider 验证与 `tools/verify_battle_judgement_prompt_real.py` 真实 provider smoke 验证。真实 DeepSeek `deepseek-v4-flash` 已完成 1 次战时 `/npc/dialogue` 和 1 次 `/npc/battle_judgement` 调用，`fallback_used=false` 且无失败。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_battle_judgement_prompt.py tools/verify_battle_judgement_prompt_real.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py tools/verify_dialogue_prompt.py`、`python tools/verify_battle_judgement_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_battle_judgement_prompt_real.py`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`；Godot MCP `addon_status` / `get_state` 复验连接正常。

## 2026-07-07 T1403 每日计划 Prompt

- 新增 `data/prompts/daily_plan_system_prompt.txt`，作为 `/npc/plan_day` 真实 provider 的独立系统 Prompt 模板；`ModelAdapter` 在 `call_type=plan_day` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 每日计划 Prompt 明确输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` / `idle`，并限制 `current_order` 只能作为守备官当前指令参考，不能越过行动白名单、资源、HP、地点、建筑、工位或程序强制层。
- `/npc/plan_day` 在 `DailyPlanResponse` Schema 校验后新增业务校验：hour 必须覆盖 0-23，行动必须来自白名单，工作阶段必须不少于 6；不合法时返回 `model_output_invalid` 并写入失败 usage，Godot 继续走既有规则计划降级。
- 新增 `tools/verify_plan_day_prompt.py` fake real-provider 验证，以及 `tools/verify_plan_day_prompt_real.py` 真实 provider smoke 验证。真实 DeepSeek `deepseek-v4-flash` 已完成 1 次 `/npc/plan_day` 调用，返回 24 阶段白名单计划，`fallback_used=false` 且无失败。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_plan_day_prompt.py tools/verify_plan_day_prompt_real.py tools/verify_plan_day_endpoint.py tools/verify_mock_model_adapter.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_plan_day_prompt_real.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

## 2026-07-07 T1402 NPC 对话 Prompt

- 新增 `data/prompts/dialogue_system_prompt.txt`，作为 `/npc/dialogue` 真实 provider 的独立系统 Prompt 模板；`ModelAdapter` 在 `call_type=dialogue` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 对话 Prompt 已覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留：日常 / 征召限制 `recruitment_result=none|accept|reject`，集结 / 战斗限制 `wartime_reaction=none|escape|morale_boost`，避战保持 `wartime_reaction=none`。当时逃离仍用通用 intent；T0087 已替换为 `escape_intervention_result=stay|leave`。
- 新增 `tools/verify_dialogue_prompt.py` fake real-provider 验证，以及 `tools/verify_dialogue_prompt_real.py` 真实 provider smoke 验证。真实 DeepSeek `deepseek-v4-flash` 已完成 4 次 `/npc/dialogue` 调用，覆盖日常对话、应征、战时意向和逃离挽留，`fallback_used=false` 且无失败。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_dialogue_prompt.py tools/verify_dialogue_prompt_real.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt_real.py`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`、`godot --headless --path . --quit-after 1`。

## 2026-07-07 T1401A 封存成品 Mock fallback

- `ModelAdapterConfig.fallback_to_mock` 和 `LLM_FALLBACK_TO_MOCK` 环境默认值改为 `false`；真实 provider 失败、无 Key、HTTP 错误、超时、非 JSON 或业务 Schema 校验失败时不再自动返回 mock 内容。显式 `LLM_PROVIDER=mock`、`/mock/model` 和显式 `LLM_FALLBACK_TO_MOCK=true` 仍作为开发 / 自动化测试入口保留。
- usage 记录新增 `http_status`、`exception_type`、`degradation_source`、最近失败摘要，并在模型输出不符合业务 Schema 时追加失败记录；日志 / usage 不记录 API Key 或请求头。
- 通用 Model Adapter schema guard 补充枚举约束；当时的通用 `intent` 已在 T0087 删除并改为按对话类型封闭字段。正式 Prompt 打磨仍留给 T1402-T1405。
- 真实 API 验收通过：使用本地真实 `LLM_PROVIDER=deepseek` / `LLM_API_KEY` / `LLM_FALLBACK_TO_MOCK=false` 调用 `/npc/dialogue`，返回 200；`GET /debug/llm_usage` 显示 provider=`deepseek`、model=`deepseek-v4-flash`、input_tokens=873、output_tokens=303、`fallback_used=false`。无 Key 场景返回 503 `provider_unavailable`，usage 记录 `exception_type=ConfigurationError` 且 `fallback_used=false`。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py tools/verify_plan_day_endpoint.py tools/verify_plan_revision_endpoint.py tools/verify_daily_reflection_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_backend_schemas.py`、临时以 `LLM_PROVIDER=mock` 启动 Flask 后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-07-07 LLM Mock 封存与真实 API 验收规则

- 将项目级规则调整为：Mock 只用于开发期 Schema / 通信 / 自动化验证；基础 mock 测试通过后，涉及 LLM / Prompt 的任务必须使用真实 API Key 做真实 provider 验收。
- 明确生产 / 演示路径不得用自动 mock fallback 掩盖真实 provider 失败；模型失败、超时、无 Key、非 JSON 或 Schema 校验失败必须返回可处理错误并记录 request id、call_type、provider、model、NPC id 和真实失败原因。
- 允许规则 / 模板降级维持游戏流程，但必须标明 source 并保留原始模型失败日志；不得把 mock 回复、mock 计划或 mock 日记当成模型成功。
- 更新 `AGENTS.md`、`docs/TASKS.md`、`game_design.md`、LLM / Prompt / API / 架构 / GM / UI / 数据 Schema 相关文档和 `backend/README.md`；新增 T1401A，专门承接“封存成品 mock fallback 与真实失败日志”的后续实现。
- 本轮只改文档和任务登记，未改运行代码；随后 T1401A 已实现生产 / 演示默认关闭自动 mock fallback。

## 2026-07-07 T1401 真实 Model Adapter

- `ModelAdapter` 新增 `deepseek` / `openai_compatible` 真实 provider 路径，使用 OpenAI 兼容 `/chat/completions`；DeepSeek 默认 `https://api.deepseek.com` + `deepseek-v4-flash`，Key 只从后端环境变量读取。
- 默认 `LLM_PROVIDER=mock`，非 mock provider 无 Key、请求失败、超时或返回非 JSON 时按 `LLM_FALLBACK_TO_MOCK=true` 自动降级到 mock；关闭降级时返回可处理错误。
- 后端复用单个 ModelAdapter 实例记录 usage，`GET /health` 返回 adapter 配置快照，`GET /debug/llm_usage` 返回调用记录、token、费用估算和 fallback 汇总。
- `LLMBridge` 新增 usage 查询接口，GM 面板新增“成本统计”按钮和 `llm_usage` 命令；查询只读，不申请 TimeSystem 慢速、不写权威状态。
- `backend/.env.example` 改为默认 mock，并补充 DeepSeek / OpenAI-compatible 配置项。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、临时以 `LLM_PROVIDER=mock` 启动 Flask 后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-07-03 T1305 NPC 结局总结页面

- `GameState.set_game_over(...)` 现在会规范化胜负 `settlement_snapshot`，并为每名 NPC 补齐最终状态（可行动 / 昏迷 / 逃离）、是否入伍、最后位置、Mock 最终看法、Mock 后续命运和记忆依据。
- HUD `GameOverPanel` 详情区改为滚动区；胜利和失败都显示 NPC 结局总结，胜利仍保留剩余资源、建筑状态和 NPC 状态摘要。
- 结局文案保持“守备官”世界内称呼，不使用“阵亡”或“死亡”描述 NPC。
- 扩展 `tools/verify_five_wave_victory.gd` 和 `tools/verify_main_hall_failure.gd`，覆盖 NPC 结局字段、HUD 明细和禁用死亡表述。
- 验证通过：`godot --headless --path . --script res://tools/verify_five_wave_victory.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

## 2026-07-03 T1304 第 5 波胜利条件

- `CombatSystem` 新增最终波次胜利评估：包含第 5 波的战斗在敌人清空后写入 `victory/five_waves_survived`，保存 `last_victory_result`，并在结算后拒绝继续 `spawn_wave(...)`。
- `GameState.set_game_over(...)` 支持通用 `game_over_reason` 与 `settlement_snapshot`；失败仍保留旧 `failure_reason`，胜利快照记录剩余资源、建筑 HP / 损毁 / 摧毁状态、驿站是否仍可运转、NPC 可行动 / 昏迷 / 逃离状态。
- HUD `GameOverPanel` 复用为胜负占位界面；胜利时显示“防守成功”、守住 5 波、剩余资源、建筑状态和 NPC 状态摘要。
- 新增 `tools/verify_five_wave_victory.gd`，覆盖手动触发 5 波、清敌胜利、停止时间、胜利快照、HUD 胜利占位和结算后拒绝刷波。
- 验证通过：`godot --headless --path . --script res://tools/verify_five_wave_victory.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-30 T1303 无可战斗人员失败条件

- `CombatSystem` 新增可战斗人员可用性快照：已入伍且持主武器、未昏迷、未逃离且未正在逃离的 NPC 计为可抵抗人员；工作中、尚未摇铃、尚未集结或尚未接敌不会误判为不可抵抗。
- 活动敌人在场时，波次生成、逻辑推进、NPC 昏迷、逃离开始和逃离完成会检查可用性；若所有可战斗人员都昏迷、逃离或正在逃离，则写入 `failure/no_available_combatants`，记录不可用原因和当前战斗快照，并复用 GameState / TimeSystem / HUD 失败占位链路。
- HUD 新增失败原因“无可战斗人员”；GM 敌人快照新增 `combatant_availability`，无需新增权威结算按钮。
- 新增 `tools/verify_no_available_combatants_failure.gd`，覆盖未集结不失败、部分逃离不失败、最后战斗人员昏迷后失败、失败时间、HUD 文案和战斗快照。
- 验证通过：`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

## 2026-06-30 T1302 主厅失败条件

- `GameState` 的 game-over 状态补充失败发生时间，并新增 `EventBus.game_over_changed` 广播；重复设置同一失败结果不会重复广播。
- `TimeSystem` 监听 game-over 信号，失败后自动暂停，且 `_process` 在 game-over 状态下不再推进逻辑时间。
- HUD 新增 `GameOverPanel` 失败占位界面，显示“防守失败”、原因“主厅被摧毁”、失败时间和“游戏已停止正常推进”提示。
- `CombatSystem` 继续作为主厅摧毁失败的触发入口：敌人攻击主厅至 HP 清零后写入 `failure/main_hall_destroyed`，并在敌人快照保留 `last_failure_result`。
- 新增 `tools/verify_main_hall_failure.gd`，覆盖主厅被摧毁、失败原因、时间停止、HUD 失败占位和战斗快照。
- 验证通过：`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-30 T1301 波次倒计时与自动来袭

- `CombatSystem` 新增波次日程状态：读取每波 `trigger_day` / `trigger_hour` / `trigger_minute` / `trigger_second`，在 TimeSystem `logical_time_tick` 中按逻辑时间触发下一未触发波次，并记录 `triggered_wave_numbers` 防止重复自动生成。
- HUD 新增 `WaveCountdownLabel`，显示下一波倒计时；敌人在场时显示当前波次 / 敌人数量和下一波。
- GM 面板新增“跳到下一波”按钮，并补充 `next_wave` / `jump_wave` 命令；敌人快照包含 `wave_schedule`。
- 新增 `tools/verify_enemy_wave_schedule.gd`，覆盖 HUD 倒计时、第 3 天 18:00 自动触发第一波、重复触发保护、GM 按钮与命令跳波。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

## 2026-06-29 T1205 战场公开信息综合验收

- 对照现有 T1106、T1201-T1204B 实现确认，战场公开信息已覆盖敌我人数、集结 / 必要模式切换、避战开始 / 结束、低血量、战时心理结果、NPC 击退敌人、昏迷、治疗、复苏、逃离、建筑受损和战斗结束。
- 新增 `tools/verify_battlefield_public_info.gd`，综合验证广场当前在场 NPC 见闻、NPC 面板见闻显示、LLMBridge 对话 payload 的 `witnessed_events` 和 `work <-> combat` / `work <-> avoid_combat` 模式事件降噪。
- 更新 `tools/verify_wartime_dialogue.gd`，固定使用关闭端口和短超时验证战时对话规则降级，避免本机已有后端服务造成误判。
- 未新增 GM 面板入口；现有 GM 敌人、记忆 / 见闻、伤害、治疗、逃离和建筑调试入口已能触发和观察相关状态。
- 验证通过：`godot --headless --path . --script res://tools/verify_battlefield_public_info.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-29 T1204B 逃离攻击事件去重与 NPC 面板提示修正

- 逃离挽留对话中点击攻击不再写 `escape_intervention_result`，因此不会再出现“听完守备官的话后，仍继续逃离驿站”；现在只保留伤害事件和“被守备官攻击后，逃离脚步更急了”的 `escape_speed_changed`。
- 逃离攻击仍会计 1 轮、关闭对话面板并恢复逃离移动，但不调用 NPC LLM、不产生 NPC 回复。
- NPC 面板切换到另一个 NPC 或隐藏时会清空临时交互结果，避免“已赠予 x 枚第纳尔”残留到其他 NPC。
- 验证补充：`verify_escape_intervention_dialogue.gd` 检查逃离攻击不写 `escape_intervention_result`；`verify_npc_panel_interactions.gd` 检查切换 NPC 后给钱提示清空。

## 2026-06-29 T1204A 逃离挽留入口、暂停与攻击规则调整

- 逃离 NPC 点击不再直接打开挽留对话；现在先打开 NPC 面板，再通过【对话】进入 `escape_intervention`。
- 逃离挽留打开时暂停 NPC 逃离移动；未满 5 轮关闭后恢复逃离且可再次打开，满 5 轮仍未挽留成功会自动关闭并让 NPC 面板【对话】置灰。
- 玩家消息需等 NPC 回复后才计 1 轮；逃离挽留中的攻击计 1 轮、立即关闭面板并继续逃离，不调用 NPC LLM、不写攻击回复 `dialogue_turn`。
- `CombatSystem` 新增逃离对话暂停 / 恢复接口；`DialogSystem` 和 `NPCPanel` 接入剩余轮次、按钮禁用、自动关闭和无回复攻击分支。
- `data/action_defs.json` 补充 `escaping_station` 与 `escape_intervention_dialogue` 系统行动，避免逃离与挽留暂停状态缺少行动定义。
- 验证通过：`godot --headless --path . --script res://tools/verify_escape_intervention_dialogue.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --quit-after 1`、临时 Mock 后端下的 `godot --headless --path . --script res://tools/verify_dialogue_ui.gd`；Godot MCP 连接、自检、运行 `Main.tscn` 和错误日志检查通过。

## 2026-06-29 T1204 逃离挽留五轮对话

- 逃离 NPC 现在会显示头顶 `!` 和 HUD 警告；初版 T1204 直接打开强制公开的逃离挽留对话，后续已由 T1204A 调整为先打开 NPC 面板，再点击【对话】进入挽留。
- `/npc/dialogue` 与 Mock adapter 新增 `escape_intervention` 语义，payload 带 `dialogue_kind`、`interaction_context` 和 `escape_intervention_round`；模型只表达留下或继续逃离意向。
- `CombatSystem` 负责权威结算：留下会停止逃离并回到工作模式，继续逃离会保留逃离；守备官给钱降低逃离速度，攻击提高逃离速度。
- 逃离 NPC 被打昏后进入 `paused_unconscious`，不会取消逃离；复苏后继续前往后门出口。
- 新增 `escape_intervention_result` 与 `escape_speed_changed` 事件，更新逃离状态、记忆、Prompt、schema、GM 面板和模块索引文档。
- 新增 `tools/verify_escape_intervention_dialogue.gd`，覆盖警告 UI、点击挽留、五轮限制、留下 / 继续结果、给钱减速、攻击加速、昏迷暂停和复苏继续。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`godot --headless --path . --script res://tools/verify_escape_intervention_dialogue.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 连接自检通过。

## 2026-06-29 T1203 逃离驿站行为

- `CombatSystem.start_npc_escape(...)` 接入正式逃离流程；战时对话 `escape` 和低血量判定 `escape_station` 不再只停留在 pending 意向，而是写入 `escape_started` 并让 NPC 前往后门外出口。
- 逃离移动期间 `escape_intent.status == "escaping"`，NPC 切出工作 / 战斗 / 避战行为，普通行动和战斗 AI 不再把其当作可用单位。
- NPC 抵达后由 `NPCSystem` 标记 `escaped=true`、`behavior_mode="escaped"`、`current_location="outside_station"`，隐藏并取消拾取实体，写入广场公开 `escaped` 事件。
- GM 面板新增“触发逃离”按钮和 `escape_npc <npc_id>` 命令；敌人快照新增 `active_escapes` 与 `last_escape_result`。
- 新增 `tools/verify_escape_station_behavior.gd`，并更新战时对话和 GM 面板验证覆盖 T1203 行为。
- 验证通过：`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`。

## 2026-06-25 T0018 NPC 面板事件库 / 见闻库详情弹窗

- `NPCPanel` 为事件库和见闻库标题 / 正文区域接入点击输入，点击后打开居中的 `NPCMemoryDetailPopup`。
- 详情弹窗显示当前 NPC 名称、记录类型、记录条数，以及每条记录的日期、时间、summary、类型、地点、可见性、重要度、事件 ID、参与者、目标和 payload JSON。
- 弹窗右上角 `×` 按钮可关闭；关闭 NPC 面板、切到建筑面板或 NPC 无效时会同步关闭详情弹窗。
- 弹窗只读取 NPC 面板缓存的事件 / 见闻数组，不修改 `MemorySystem`、事件库、见闻库或任何权威状态。
- 更新 `tools/verify_npc_panel_state.gd`，覆盖详情弹窗打开、内容显示、关闭按钮和点击连接存在。
- 验证通过：`godot --headless --path . --script tools/verify_npc_panel_state.gd`、`godot --headless --path . --script tools/verify_npc_short_term_memory_container.gd`、`godot --headless --path . --script tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-25 T1202 战时低血量自身心理判定

- 按设计更新低血量判定范围：当前战斗 / 敌人在场期间，任一未昏迷、未逃离 NPC 的 HP 首次从不低于 30% 跌破 30% 且仍大于 0 时触发；避战 / 非战斗人员也会判定，但只允许逃离或继续避战，不触发斗志激昂或继续参战。
- 后端新增 `/npc/battle_judgement` 业务接口，`BattleJudgementRequest` 接收 `battlefield_context`，Mock adapter 按 Godot 提供的 `allowed_decisions` 返回稳定结果。
- `LLMBridge` 新增 `request_npc_battle_judgement(...)` / `build_npc_battle_judgement_payload(...)`，请求携带最新 `current_order`、短期记忆、地点上下文、低血量事实、战局上下文和允许结果，并申请 / 释放 TimeSystem 慢速。
- `NPCSystem.apply_damage_to_npc(...)` 在权威扣血后延迟通知 `CombatSystem.handle_npc_damage_applied(...)`；CombatSystem 写入 `low_hp_triggered`、`battle_psychology_result`，每场每名 NPC 只触发一次，并在快照暴露 `last_low_hp_judgement_result` 与 `active_battle.low_hp_judgements`。
- 参战 NPC 可继续参战、逃离或斗志激昂；避战 / 非战斗人员只可逃离或继续避战。后端失败或模型输出越界时，Godot 规则降级到允许结果。低血判定期间目标 NPC 不可对话，触发时若正在对话则强制结束并取消未完成回复。
- 新增 `tools/verify_low_hp_battle_judgement.gd`，覆盖参战继续、避战继续避战、不重复触发、对话强制结束、事件入库、最新指令注入和慢速释放。
- 文档同步覆盖 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`COMBAT_SYSTEM.md`、`AI_NPC_SYSTEM.md`、`MEMORY_AND_INFO_SPACE.md`、`DATA_SCHEMA.md`、`TECH_ARCHITECTURE.md`、`PROMPTS.md`、`GM_PANEL.md`、`API_BUDGET.md`、`PROJECT_BRIEF.md` 和 `game_design.md`。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`godot --headless --path . --script tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --script tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script tools/verify_combat_damage.gd`、`godot --headless --path . --script tools/verify_combat_flow.gd`、`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_dialogue_sleep_summary_boundaries.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- Godot MCP 复验：`addon_status` 显示 connected=true、server/addon 4.0.1 匹配，项目路径为 `D:/MyGames/这不是我的战争/`。

## 2026-06-25 T1201 战时公开对话心理结果

- `DialogSystem` 在 `rally` / `combat` / `avoid_combat` 玩家对话中强制 `local_public`，锁定公开 toggle；战时后端失败时生成规则 fallback 回复、应征结果和 `wartime_reaction`。
- `LLMBridge` 的 `/npc/dialogue` payload 新增 `interaction_context` 与 `battlefield_context`，并在 NPC 状态上下文中暴露 `behavior_mode`、`combat_strategy`、`morale_boost` 和 `escape_intent`。
- 后端对话请求 / 响应增加战时字段；T0087 后响应类型为 `PlayerNPCDialogueResponse`。Mock 对话可按关键词返回 `none` / `escape` / `morale_boost`。
- `CombatSystem` 新增战场上下文构造、战时对话心理结算、`battle_psychology_result`、2 游戏小时 `morale_boost` 攻击 / 移动加成、过期事件和 `escape_intent` pending 状态；完整逃离移动仍留给 T1203。
- 新增 `tools/verify_wartime_dialogue.gd`，覆盖强制公开、payload 注入、后端失败 fallback、士气 buff、逃离意图和避战应征保留。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_dialogue_ui.gd`、`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-17 T1105A 战斗内避战策略距离边界

- 修正战斗模式中“避战”策略的距离边界：只在最近敌人低于非战斗避战安全阈值时按敌人来袭方向短步长远离。
- 敌人已经远离到安全阈值外时，NPC 保持 `behavior_mode == "combat"` 和 `combat_ready` 等待，不攻击、不继续向驿站边界或角落移动；若正在执行旧避战移动，会停止移动并清空策略移动目标。
- 扩展 `tools/verify_combat_strategies.gd`，覆盖近距离短步长避战、移动中敌人远离后的停止等待、远距离直接等待、不攻击和战斗模式保持。
- 文档同步覆盖 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`COMBAT_SYSTEM.md` 和 `game_design.md`。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_strategies.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 编辑器错误日志为空。

## 2026-06-17 T1106 战斗开始/结束流程

- `CombatSystem` 新增当前战斗运行态：敌人波次生成后写入广场 `combat_started`，记录波次、敌军构成、我方已入伍持主武器 NPC roster 和非战斗人员数量。
- 敌人被我方击退、NPC 受伤 / 昏迷时会计入本场统计；敌军全灭或 GM 清敌后写入广场 `combat_ended`，记录受伤 / 昏迷 NPC 和各 NPC 击退敌人的数量。
- 清敌回收补齐未接敌 `rally`：`combat` 回 `work` 并请求计划重评估，`avoid_combat` 与未接敌 `rally` 回 `work` 且不因单纯退出强制重评估；修正战前警铃但尚无敌人时不应被普通逻辑 tick 当作清敌回收。
- `MemorySystem` 新增 `combat_started` / `combat_ended` 必填 payload 校验和确定性 summary；`debug_get_combat_snapshot()` 暴露 `active_battle`、`last_battle_start_result` 和 `last_battle_end_result`。
- 新增 `tools/verify_combat_flow.gd` 覆盖战斗开始广播、接敌入战 / 避战、结束广播、受伤 / 昏迷 / 击退统计和清敌回工作状态；同步更新结构化事件与广场广播验证脚本的 `combat_started` payload。
- 文档同步覆盖 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`COMBAT_SYSTEM.md`、`MEMORY_AND_INFO_SPACE.md`、`DATA_SCHEMA.md`、`GODOT_ARCHITECTURE.md` 和 `GM_PANEL.md`。
- 验证通过：`verify_combat_flow.gd`、`verify_combat_damage.gd`、`verify_combat_alarm_rally.gd`、`verify_avoid_combat_mode.gd`、`verify_combat_strategies.gd`、`verify_combat_time_cap.gd`、`verify_combat_pacing.gd`、`verify_enemy_wave_generation.gd`、`verify_gm_panel.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。
- Godot MCP 复验：`addon_status` 显示 connected=true、server/addon 4.0.1 匹配；当前场景为 `res://scenes/main/Main.tscn`；编辑器错误日志为空。

## 2026-06-17 T1105 不同兵种战斗策略

- `CombatSystem` 新增按兵种提供的战斗策略选项和当前策略状态：近战 / 长杆可选“主动进攻 / 避战”，弓弩 / 骑射可选“最大化输出 / 保持距离射击 / 避战”，近战骑兵可选“主动进攻 / 拉开距离冲击 / 避战”。
- 战斗策略由玩家在已入伍且有主武器 NPC 的面板中手动选择，默认使用该兵种第一项进攻 / 输出策略；更换主武器或坐骑会重置到新兵种默认策略，`current_order` 不自动决定策略。
- 实现策略行为：远程最大化输出站桩射击，保持距离射击在射程内小幅后撤后继续攻击，近战主动进攻接近敌人，拉开距离冲击先拉开再接近，战斗内避战复用短步长避战移动但保持 `behavior_mode == "combat"`。
- `NPCPanel` 在“装备武器”旁新增战斗策略下拉框；`NPCSystem` 保存 `states.combat_strategy` 和策略移动目标；`MemorySystem` 新增 `combat_strategy_selected` 事件并支持“战术移动”行动摘要。
- 文档同步覆盖 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`COMBAT_SYSTEM.md`、`UI_UX.md`、`AI_NPC_SYSTEM.md`、`PROMPTS.md`、`DATA_SCHEMA.md` 和 `GM_PANEL.md`。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_strategies.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-17 T1104C 移除围墙作为敌人攻击目标

- 按新设计调整敌人规则 AI：敌人不再攻击围墙；无附近可行动 NPC 时按城门、仓库、主厅推进，城门被攻破后直接转向仓库。
- `CombatSystem` 默认目标偏好移除 `wall`，并新增目标偏好规范化过滤；旧配置中的 `wall` / `front_wall` 不会进入运行时目标偏好。
- `data/enemy_waves.json` 的 5 波敌人 `target_preference` 全部移除 `wall`。
- `tools/verify_enemy_target_priority.gd` 扩展验证：生成敌人偏好不含围墙，城门破坏后目标为仓库，围墙 HP 不变，仓库破坏后目标才转向主厅。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-17 T1103D 模式切换事件降噪

- 按当前设计去掉冗余模式事件：`work -> combat`、`combat -> work`、`work -> avoid_combat`、`avoid_combat -> work` 不再写入 `npc_mode_changed`，也不再通过该事件广播。
- `NPCSystem.set_npc_behavior_mode(...)` 增加模式事件过滤，同时保留 `force_mode_event` / `suppress_mode_event` 供特殊入口覆盖。
- 保留具体事实事件：避战开始 / 结束、攻击、受伤、警铃、集结、集结接敌、昏迷和复苏仍按原事件类型写入。
- 更新 `tools/verify_avoid_combat_mode.gd` 与 `tools/verify_behavior_mode_state_machine.gd`，分别验证工作 / 避战、工作 / 战斗互转不写 `npc_mode_changed`，且集结与避战事实事件不受影响。
- 验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_damage.gd`、`godot --headless --path . --script tools/verify_combat_pacing.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`。

## 2026-06-17 T1104B 战斗动作秒与第一波节奏校准

- 定位第一波战斗过快的根因：`x1` 下 TimeSystem 仍是现实 1 秒推进 60 游戏秒，旧攻击冷却直接消费这 60 游戏秒，导致现实 1 秒内发生大量连续攻击。
- `CombatSystem` 新增战斗动作秒换算：`60` 游戏秒折算为 `1` 战斗动作秒后再推进我方和敌方攻击冷却；敌人移动继续按 `move_speed * game_delta_seconds / 60` 推进，保持移动与攻速基准一致。
- 最近 AI 推进、我方攻击和敌方攻击结果补充 `combat_seconds`，便于 GM / 自动化检查实际攻速基准。
- 第一波劫掠剑盾手调为低强度探路敌人：HP `60`、攻击 `6`、防御 `1`、攻击间隔 `2.4`；艾达持剑对第一波时应能观察到十几秒量级的互相攻击过程。
- 新增 `tools/verify_combat_pacing.gd`，覆盖艾达持剑对第一波、单个 `x1` 基准秒攻击次数上限、敌方不爆发连击、第一波不瞬间清空和完整交战不应过快结束；同步延长 `tools/verify_enemy_target_priority.gd` 的主厅破坏推进时长。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。

## 2026-06-17 T1104A 战斗时间倍率脱钩与敌人在场限速

- 更新设计源与模块文档：战斗伤害、攻击间隔、攻击速度和战斗移动速度不再随玩家 `x2` / `x4` 时间倍率加速；玩家时间倍率主要服务工作 / 日常资源与状态结算。
- `TimeSystem` 新增时间倍率上限请求：`request_time_scale_cap(...)` / `release_time_scale_cap(...)` / `clear_time_scale_caps()` / `get_time_scale_snapshot()`；有效倍率由玩家选择、LLM 慢速和上限请求共同取最慢 / 最低上限。
- `CombatSystem` 在活动敌人存在时注册 `combat_enemy_presence` `x1` 上限，生成敌人时压低有效倍率，最后一个敌人移除或 GM 清敌后释放；LLM 慢速期间仍可降到 `1/60`，释放后回到敌人在场的 `x1`。
- GM 面板新增时间倍率快照按钮与 `time_snapshot` 命令，`snapshot` 和敌人快照可观察 TimeSystem 慢速请求与上限请求。
- 新增 `tools/verify_combat_time_cap.gd`，并扩展 `tools/verify_time_system.gd`、`tools/verify_gm_panel.gd` 覆盖上限请求、LLM 慢速叠加和清敌恢复。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。

## 2026-06-17 T1104 基础攻击与伤害

- `CombatSystem` 新增最小自动战斗推进：已入伍且有主武器 NPC 只在 `behavior_mode == "combat"` 中按逻辑时间攻击范围内敌人，`avoid_combat` NPC 不攻击。
- 我方攻击力读取主武器 `damage` 并按力量修正；攻击间隔读取主武器 `attack_interval`，再按武器熟练度、疲劳、饱食和骑术/坐骑修正。
- 新增统一防御减伤函数：敌人防御读取波次配置 `defense`，NPC 防御读取盔甲槽 `armor_value` 总和；敌方攻击 NPC 会先减伤再复用 `NPCSystem.apply_damage_to_npc(...)`。
- 敌人 HP 清零后从活动敌人和场景节点移除；场上敌人清空后沿用 T1103A/T1103B 的战斗 / 避战退出规则。
- `MemorySystem` 新增 `attack_made` 必填 payload 与 summary；敌方 `damage_taken` payload 补充原始攻击、防御和防御后伤害。
- 新增 `tools/verify_combat_damage.gd`，覆盖我方伤害、敌方伤害、盔甲减伤、攻击间隔、敌人移除、清敌退出和避战不攻击。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-17 T0017 Godot MCP 4.0.1 版本对齐

- 定位当前问题为 Godot MCP 可连接但版本不一致：Codex MCP `addon_status` 初始返回 `server_version=2.17.0`、`addon_version=3.7.0`、`versions_match=false`。
- 按“优先升级而非回退”处理：全局安装 `@satelliteoflove/godot-mcp@4.0.1`，并将项目 `addons/godot_mcp` 升级到 `4.0.1`。
- 处理 4.0.1 安装器在当前中文项目路径下只删除旧 addon、未正确落回新 addon 的问题：从全局 npm 包的 `addon` 目录机械恢复到项目 `addons/godot_mcp`。
- `MCPGameBridge` 补回本项目类缓存兼容策略：显式预加载 `mcp_runtime_state_sampler.gd`、`key_names.gd`、`joy_names.gd`、`mcp_exec_guard.gd`，避免 `.godot/global_script_class_cache.cfg` 未登记 helper class 时 headless 启动解析失败。
- 更新 `%USERPROFILE%\.codex\scripts\godot-mcp-broker.mjs`，兼容 4.0.1 移除旧 resources 入口、新版 `godot_*` 工具名和新版 tool result 内容格式；旧 Codex 工具壳仍可转发到新版 registry。
- 验证通过：`godot_project.addon_status` 返回 `connected=true`、server/addon 均为 `4.0.1`、`versions_match=true`；`godot_editor.get_state` 正常返回 `res://scenes/main/Main.tscn`；`tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`；`godot --headless --path . --quit-after 1` 无报错。

## 2026-06-17 T1103C 非战斗人员避战判定与四散移动

- `CombatSystem` 将可战斗判定统一为“已入伍且有主武器”：无主武器的已入伍 NPC 不集结、不接战，接敌时与未入伍 NPC 一样进入 `avoid_combat`；昏迷复苏和 GM 避战入口也使用同一判定。
- `NPCSystem` 的敌人攻击分流同步改为主武器判定；睡觉中的无武器入伍 NPC 只有被敌人攻击才进入避战，单纯接近不触发。
- 避战目标由固定安全点改为按最近敌人方位生成短步长远离目标，并按 NPC / 敌人组合加入稳定散射角，形成逐步四散逃跑效果；目标保持在驿站范围内。
- 避战中应征入伍但仍无主武器时继续避战；装备主武器且场上仍有敌人时才从避战切入 `combat`。
- `MemorySystem` 避战行动摘要与 `avoidance_started` summary 改为“远离敌人 / 避战方向”语义，不再暗示固定避战点。
- 更新 `tools/verify_avoid_combat_mode.gd`，覆盖无武器入伍 NPC 接敌避战、睡觉受击例外、短步长四散、应征后继续避战和装备主武器后入战。
- 验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`、`git diff --check`（仅提示 `docs/CURRENT_STATE.md` 未来会从 CRLF 转 LF）。

## 2026-06-12 T1103B 未入伍 NPC 避战模式

- `CombatSystem` 接入未入伍 NPC 避战移动：工作模式中敌人进入范围会切到 `avoid_combat`，睡觉中的未入伍 NPC 只在被敌人攻击时进入避战。
- 避战 NPC 会选择驿站内安全点并通过 `NPCSystem.move_npc_to_world_position(...)` 移动；避战不设置战斗 `combat_mode`，不攻击敌人，也不使用逃离驿站出口。
- 敌军清空后，避战 NPC 回到 `work` 且不请求计划重评估；避战中应征成功时，若仍有敌军则进入 `combat`，无敌军则回到 `work`。
- `MemorySystem` 新增 `avoidance_started` / `avoidance_ended` 事件类型、必填 payload 和 summary；NPC 行动状态摘要支持前往避战点。
- GM 面板新增“模拟避战”按钮和 `avoid_npc <npc_id>` 命令，敌人快照包含 `active_avoidances` 与最近避战结果。
- 新增 `tools/verify_avoid_combat_mode.gd`，覆盖未入伍接敌避战、睡觉例外、避战安全点、清敌退出不重评估、避战中应征分流、事件写入和 GM 入口。
- 验证通过：`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务仍不实现我方反击、敌人受击 / 倒下、逃离驿站、战时公开对话心理结果或低血量自身心理判定。

## 2026-06-12 T1103A 统一 NPC 行为模式状态机

- `NPCSystem` 新增 `states.behavior_mode` 权威运行时字段，支持工作 / 集结 / 战斗 / 避战 / 昏迷 / 逃离模式，并保留 `combat_mode` 作为旧集结与坐骑视觉兼容字段。
- `CombatSystem` 接入行为模式切换规则：警铃集结进入 `rally`，接敌进入 `combat`，集合点等待 1 游戏小时未接敌回到 `work` 且不重评估计划，敌军清空后战斗 NPC 回到 `work` 并请求重评估计划，复苏 NPC 按场上敌军和入伍状态分流。
- 睡觉 NPC 不因范围接敌自动进入战斗或避战；被敌人直接攻击时，已入伍者进入战斗，未入伍者进入避战。
- 模式切换会中断普通行动、移动、可取消 LLM 和当前对话；`DialogSystem.force_end_dialogue_for_npc(...)` 用于强制关闭对话并取消未完成回复。
- `MemorySystem` 新增 `npc_mode_changed` 结构化事件摘要；NPC 面板显示当前行为模式，GM 面板新增“行为模式快照”“推进集结等待”按钮和 `behavior_modes` / `advance_rally_wait [game_seconds]` 命令。
- 新增 `tools/verify_behavior_mode_state_machine.gd`，覆盖警铃集结、集结超时、接敌入战、清敌退出、睡觉接敌例外、被攻击入战、复苏分流和 GM 入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务只实现行为模式状态机和切换边界；未入伍 NPC 避战移动策略、战时公开对话心理结果、低血量自身心理判定、我方反击和完整战斗结算仍在后续任务。

## 2026-06-12 行为模式与战斗心理设计同步

- 设计源 `game_design.md` 新增工作 / 集结 / 战斗 / 避战四种行为模式定义，明确模式触发、退出和互斥边界。
- 取消旧式“战斗触发时全员心理判定”，改为集结 / 战斗 / 避战模式下的战时公开对话结构化意向，以及战斗中 HP 低于 30% 的自身心理判定。
- 明确集结模式到达集合点后等待 1 游戏小时仍未接敌则回到工作模式且不重评估计划；战斗模式在敌军清空后回到工作模式并重评估计划；未入伍避战模式只在敌军清空后回到工作模式。
- 明确战时公开对话强制同地点公开，Prompt 继承 T0603 上下文并额外注入 `battlefield_context`；已入伍 NPC 输出 `wartime_reaction`，未入伍避战 NPC 仍沿用应征结果逻辑。
- `TASKS.md` 新增 T1103A / T1103B，并重写 T1201 / T1202 等后续任务，避免后续实现重新走旧的全员战斗前判定方案。
- 本次只更新设计和任务文档，未修改运行时代码。

## 2026-06-12 T1103 警铃与集结

- HUD 警铃按钮接入 `CombatSystem.trigger_combat_alarm("hud")`；GM 面板新增“警铃集结”按钮和 `alarm` / `rally` 命令。
- `CombatSystem` 新增警铃集结权威流程：所有 NPC 写入 `combat_alarm_rang` 私有事件，入伍且有主武器、当前可行动的 NPC 会被排入城门外防线；近战 / 骑兵在前排，弓弩 / 骑射在后排。
- 集结会通过 `ActionSystem.interrupt_npc_action(..., "combat_alarm")` 打断普通日常行动并释放工位，再调用 `NPCSystem.move_npc_to_world_position(...)` 前往阵位；`debug_get_combat_snapshot()` 现在包含 `active_rallies` 和 `last_alarm_result`。
- `NPC.gd` 新增运行时低模骑乘和面向敌人方向标记；只有 `combat_mode == "rally"` 或 `"combat"` 且 `combat_mounted == true` 时显示坐骑，日常工作模式不骑马。
- 若集结途中遭遇一定范围内敌人，NPC 会停止移动并进入 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy`；这仍不实现我方攻击、敌人受击或完整战斗开始 / 结束流程。
- `MemorySystem` 新增 `combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy` 事件摘要和行动状态翻译。
- 新增 `tools/verify_combat_alarm_rally.gd`，覆盖 HUD 警铃、GM 命令、未入伍过滤、近战前排 / 远程后排、骑乘表现和集结途中遭遇敌人切换。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`。

## 2026-06-12 T1102 敌人目标优先级

- `CombatSystem` 接入敌人目标选择、逻辑时间推进、移动和敌方单向攻击；附近可行动 NPC 会优先成为目标，否则按城门、仓库、主厅选择仍有 HP 的建筑。2026-06-17 的 T1104C 已移除围墙作为敌人攻击目标。
- 敌人攻击 NPC 时复用 `NPCSystem.apply_damage_to_npc(...)`，NPC HP 清零仍进入昏迷；敌人攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)`，扣除建筑 HP、刷新建筑标签并写入 `building_damaged` 结构化事件。
- `GameState` 新增 `game_over`、`game_result`、`failure_reason` 和 `set_game_over(...)`，主厅 HP 清零时写入 `failure/main_hall_destroyed` 失败占位状态。
- `NPCSystem` 新增只读 `get_npc_world_position(...)`，供 CombatSystem 判断附近可行动 NPC；`CombatSystem.debug_get_combat_snapshot()` 现在包含敌人目标、当前行动和最近 AI 推进结果。
- GM 面板“战斗 / 敌人”分组新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令。
- 新增 `tools/verify_enemy_target_priority.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖新 GM 入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务只实现敌方单向攻击和失败状态占位；我方自动攻击、敌人受击 / 倒下、完整战斗开始 / 结束流程和正式胜负界面仍留给 T1104、T1106 和 M13。

## 2026-06-12 T1101 敌人配置与敌人生成

- `data/enemy_waves.json` 扩展为 5 波 Demo 敌人配置，后续波次在人数、HP、攻击、防御和兵种组合上逐步增强。
- `CombatSystem` 接入波次配置读取、查询、生成、清空和快照调试接口，可在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人实体；敌人保留 HP、武器类型、单位类型、攻击、防御、移动速度和目标偏好。
- `Main.tscn` 扩大正门外地面与正门道路，`CameraRig` 扩展 Z 轴视野，保证敌人生成在正门外森林方向且可被观察。
- GM 面板新增“战斗 / 敌人”分组，支持生成第一波、生成指定波次、查看敌人快照、清空敌人，并补充 `spawn_wave` / `enemy_wave` / `enemies` / `clear_enemies` 命令。
- 新增 `tools/verify_enemy_wave_generation.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖 T1101 数据、生成位置、GM 按钮、命令和清理流程。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务不实现敌人移动、目标 AI、攻击、伤害、战斗开始/结束或事件写入，这些留给 T1102 / T1104 / T1106。

## 2026-06-12 T1006 发送后才打断对话与对话窗攻击闭环

- NPC 面板“对话”改为只打开 DialogPanel 和查看历史，不再立刻打断行动、取消 LLM 或请求结束后的计划重评估。
- 玩家在对话窗实际发送消息或点击攻击后，才取消目标 NPC 的可取消 LLM 请求并打断工作 / 吃饭 / 睡觉等普通行动；普通消息未等 NPC 回复就结束会取消本轮异步 LLM，不写 `dialogue_turn`，不触发对话重评估。
- 对话窗等待 NPC 回复期间输入框仍可编辑，但发送和攻击按钮禁用，避免同一轮回复前重复提交。
- 攻击入口从 NPC 面板移到对话窗：点击后先扣 HP 并写入“守备官攻击了你以示惩戒”的 `damage_taken`，再请求 NPC 作出攻击语境回复；关闭等待中的攻击回复不会撤销攻击，结束时仍触发一次计划重评估。
- `DialogPanel` 将“提出应征”改为右上角 toggle，攻击按钮放到发送旁；`NPCPanel` 保留给钱和装备入口，不再直接扣血。
- 验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`、`godot --headless --path . --script res://tools/verify_dialogue_ui.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_npc_proactive_talk.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_reevaluation.gd`、`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`；并通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，日志无报错。

## 2026-06-11 T1005 对话打断、LLM 状态提示与首次睡眠总结优先级

- 玩家对话现在会打断工作 / 吃饭 / 睡觉等普通日常行动，并取消目标 NPC 的可取消 LLM 活动状态；取消后的计划 / 对话结果不会继续应用。
- 首次睡眠总结改为每天第一次睡觉且持续睡眠满 1 个游戏小时后触发；总结发起到应用完成期间通过 NPCSystem 深度睡眠锁阻止对话、消息、行动中断和行动改派。
- 总结期间发布给已入伍 NPC 的指令仍保存并写入事件，但计划重评估延后到醒来后执行。
- 对话、每日计划、计划修订和首次睡眠总结都会申请并释放 TimeSystem 慢速；`/npc/daily_reflection` 保持接口名不变，玩法语义改为首次睡眠总结。
- NPC 头顶新增 LLM 状态标记：普通 LLM 等待显示 `...`，首次睡眠总结显示禁止标记；NPC 面板名字旁显示“正在思考 / 正在计划下一步行动 / 正在熟睡”。
- GM 面板新增 `llm_state <npc_id>` 只读入口，查看 NPC LLM 活动、首次睡眠总结锁和延后重评估状态。
- 新增 `tools/verify_dialogue_sleep_summary_boundaries.gd`，更新 `tools/verify_daily_reflection_system.gd`。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`godot --headless --path . --script res://tools/verify_npc_order.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1004 睡前总结与短期记忆清空

- 新增 `DailyReflectionSystem` 并挂载到 `Main/Systems/DailyReflectionSystem`，监听 `sleep_started`；每名 NPC 每天首次睡觉生成睡前总结，重复睡眠不自动重复写入，GM 可 force 调试。
- `LLMBridge` 新增 `/npc/daily_reflection` 请求和 payload 构造，注入共享 NPC 上下文、当前指令、当天事件 / 见闻摘要和已有日记；当时睡前总结默认不申请 TimeSystem 慢速，已在 T1005 修正为首次睡眠总结必须慢速。
- Flask 后端新增 `POST /npc/daily_reflection`，使用 `DailyReflectionRequest` / `DailyReflectionResponse` 校验输入输出；Mock provider 覆盖 `daily_reflection`。
- `NPCSystem` 新增长期记忆读取和睡前总结应用接口，写入 `diary`，并把知识图谱更新合并到当时的占位结构；T1405 后已收敛为 `knowledge_graph.by_subject[subject][relation]` 替换式当前值，不再写 append-only `patches`。
- `MemorySystem` 新增 `clear_npc_short_term_memory(...)`，只清空指定 NPC 当天事件库 / 见闻库索引，不删除全局事件档案。
- `NPCPanel` 新增日记滚动区；`GMPanel` 新增睡前总结、长期记忆和最近总结按钮，以及 `reflect_npc`、`long_memory`、`reflection_result` 命令。
- 新增 `tools/verify_daily_reflection_system.gd` 与 `tools/verify_daily_reflection_endpoint.py`，并扩展 `tools/verify_gm_panel.gd`、`tools/verify_mock_model_adapter.py`。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1003 LLM / Mock 版制定计划接口

- Flask 后端新增 `POST /npc/plan_day`，用 `DailyPlanRequest` / `DailyPlanResponse` 校验每日计划 Mock 输入输出。
- Mock `plan_day` 会按 NPC 熟练度和行动白名单选择真实可执行工作行动，并返回睡觉、吃饭、工作、等待组成的 24 小时计划。
- `LLMBridge` 新增每日计划 payload 与 `/npc/plan_day` 请求，注入最新 `current_order`、短期记忆、长期记忆、地点 / 广场上下文、资源快照、建筑状态、行动白名单和计划规则；请求期间申请 TimeSystem 慢速并在成功 / 失败 / 超时后释放。
- `DailyPlanSystem` 新增 `generate_daily_plan_for_npc(...)`：成功时应用 `mock_plan_day` 并写入 `plan_created`，失败、输出不合法、非 24 阶段或工作阶段不足时应用 `rule_plan_fallback`。
- GM 面板 `plan_generate` 改为 LLM / Mock 优先并自动规则降级，新增 `plan_generate_rule` 纯规则入口，`plan_request` 可查看最近每日计划生成结果。
- 新增 `tools/verify_daily_plan_llm.gd` 与 `tools/verify_plan_day_endpoint.py`。
- 验证通过：`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`verify_plan_day_endpoint.py`、`verify_plan_revision_endpoint.py`、`verify_daily_plan_llm.gd`、临时以 `LLM_PROVIDER=mock` 和 `T1003_BACKEND_URL=http://127.0.0.1:5056` 启动 Flask 后再次运行 `verify_daily_plan_llm.gd`、`verify_daily_plan_reevaluation.gd`、`verify_daily_plan_system.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1002 行动异常与计划重评估

- `DailyPlanSystem` 接入统一计划重评估：行动失败、目标建筑不可用、资源不足、工位占用、对话打断、守备官攻击、主动交涉结束 / 超时、战斗警报占位和新指令会触发重评估。
- `LLMBridge` 新增计划修订 payload 与 `/npc/revise_plan` 请求，注入最新 `current_order`、当前计划、失败计划项、失败类型和行动白名单；请求期间申请 TimeSystem 慢速并在成功 / 失败 / 超时后释放。
- Flask 后端新增 `/npc/revise_plan`，用 `PlanRevisionRequest` / `PlanRevisionResponse` 校验 Mock 修订输出。
- 重评估成功写入 `plan_revised` 并执行当前小时修订项；后端不可用或输出失败时写入 `rule_revision_fallback` 并执行规则降级项。
- GM 面板新增“立即重评估”和 `plan_revise <npc_id> [reason]`，最近请求面板同时显示 NPCSystem 请求和 DailyPlanSystem 结果。
- 新增 `tools/verify_daily_plan_reevaluation.gd` 与 `tools/verify_plan_revision_endpoint.py`。
- 验证通过：`verify_daily_plan_reevaluation.gd`、临时以 `LLM_PROVIDER=mock` 和 `T1002_BACKEND_URL=http://127.0.0.1:5055` 启动 Flask 后再次运行 `verify_daily_plan_reevaluation.gd`、`verify_plan_revision_endpoint.py`、`verify_daily_plan_system.gd`、`verify_npc_order.gd`、`verify_gm_panel.gd`、`verify_npc_proactive_talk.gd`、`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`godot --headless --path . --quit-after 1`。

## 2026-06-10 T1001 规则版每日计划

- 新增 `DailyPlanSystem` 并挂载到 `Main/Systems/DailyPlanSystem`，可生成规则版 24 小时计划，默认按 NPC 熟练度选择工作行动，计划中工作阶段不少于 6 个。
- `NPCSystem` 新增计划存取与系统中断移动接口；`ActionSystem` 新增当前行动查询与 `interrupt_npc_action(...)`，计划切换时可安全释放工位、训练、治疗或移动状态。
- `MemorySystem` 接入 `plan_created` payload 校验和确定性 summary；计划生成会写入 NPC 私有事件库。
- GM 面板新增生成计划、执行当前计划、查看计划按钮，以及 `plan_generate` / `plan_execute` / `plan` 命令。
- 新增 `tools/verify_daily_plan_system.gd`，覆盖 24 小时计划、至少 6 个工作阶段、计划事件入库、小时打点执行、同小时重复执行和计划切换打断。
- 验证通过：`verify_daily_plan_system.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `Main.tscn` 后游戏日志为空。
- 备注：`tools/verify_time_system.gd` 当前仍有旧断言期望“暂停后挂起工作在几帧内产出资源”，与现行 T0801 之后的 1 小时持续工作语义不一致，本次未改该旧验证脚本。

## 2026-06-10 T0016 建筑面板工位显示优化

- `BuildingPanel` 移除独立“当前工作位 x/x”汇总行，场景默认占位改为 `工位：--`。
- 工位、床位和训练位改为按类型分组显示 `空闲数/总数：占用者`；空闲数和总数来自真实工位数组，占用者通过 `NPCSystem` 显示 NPC 名字。
- 诊所、训练场等多类型建筑会分别显示医生 / 病床、教官 / 受训者等位置；无占用者显示“空闲”，多个占用者用顿号分隔。
- 新增 `tools/verify_building_panel_workstations.gd`，覆盖新显示格式、占用者名字、多类型分组和无工位建筑。
- 验证通过：`verify_building_panel_workstations.gd`、`verify_building_repair_upgrade.gd`、`verify_work_output_framework.gd`。

## 2026-06-10 T0015 NPC 成长 UI 与 GM 入伍入口修正

- NPC 面板移除独立“成长”说明文本，改为在 HP 行右侧显示 `经验：当前 / 阈值`。
- 属性行改为内联显示力量和智力；只有存在未分配技能点且对应属性未达上限时，才在属性数值旁显示 `+1` 按钮，最后一个点用完后按钮自动消失。
- GM 面板 NPC 分组新增“设为入伍”按钮和 `recruit_npc <npc_id>` 命令，调用 `NPCSystem.set_npc_recruited(...)`，让选中 NPC 进入可发布指令 / 可分配装备的入伍状态。
- 更新 `tools/verify_skill_progression.gd`、`tools/verify_npc_panel_state.gd` 和 `tools/verify_gm_panel.gd`，覆盖新 UI 和 GM 入伍入口。
- 验证通过：`verify_npc_panel_state.gd`、`verify_skill_progression.gd`、`verify_gm_panel.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`verify_dialogue_ui.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `Main.tscn` 后游戏日志为空。

## 2026-06-10 T0904 职业熟练度与经验升级

- `NPCSystem` 新增运行时 `progression` 成长结构，`increase_npc_skill(...)` 成为统一熟练度增长入口；工作、诊所和训练的熟练度提升会同步增加技能经验与总经验，每 5 点总经验产生 1 个未分配技能点。
- 按当前设计改为玩家分配技能点：新增 `assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，只能把未分配技能点投入力量或智力，AI 只可在后续对话/计划中建议倾向，不能自行消耗技能点或改写属性。
- `NPCPanel` 接入成长展示与玩家分配技能点入口；该入口后续已按 T0015 调整为 HP 行右侧经验与属性数值旁条件显示 `+1`。`GMPanel` 新增技能点分配入口和 `assign_attribute <npc_id> <strength|intelligence>` 命令。
- `MemorySystem` 新增 `attribute_improved` 事件，并让 `skill_improved` payload 记录经验与技能点变化；新增 `tools/verify_skill_progression.gd` 覆盖工作、训练、诊所成长、技能点生成、玩家属性分配、NPC 面板和 GM 命令。
- 同步更新 `game_design.md`、`AI_NPC_SYSTEM.md`、`DATA_SCHEMA.md`、`UI_UX.md`、`GM_PANEL.md`、`MEMORY_AND_INFO_SPACE.md`、`ECONOMY_AND_BUILDINGS.md`、`GODOT_ARCHITECTURE.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md` 和 `TASKS.md`。
- 验证通过：`godot --headless --path . --script res://tools/verify_skill_progression.gd`。

## 2026-06-10 T0014 GM 行动入口、NPC 记忆滚动区与弹窗互斥

- GM 面板行动区去掉并列的工作、吃饭、睡觉、当教官和当受训者按钮；普通行动统一通过行动下拉和“指定行动”触发，协助修复、协助升级、协助治疗等带目标参数入口保留。
- NPC 面板事件库和见闻库改为固定高度滚动区，完整显示当前 NPC 的事件 / 见闻内容，刷新后自动滚到底部，用户仍可手动上滑查看旧记录。
- NPC 面板点击“对话”或“指令”不再自动关闭 NPC 面板；`DialogPanel` 与 `OrderPanel` 互斥，打开其中一个会关闭另一个，避免中央弹窗重叠。
- 更新 `tools/verify_gm_panel.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_dialogue_ui.gd` 和 `tools/verify_npc_order.gd` 的断言，覆盖新 UI 行为。
- 验证通过：`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_panel_interactions.gd`、`verify_npc_order.gd`、临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后运行 `verify_dialogue_ui.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-10 T0903 训练场与武器熟练度提升

- `data/building_defs.json` 将训练场拆分为 `training_instructor` 教官工位和 `training_student` 受训位，训练场升级当前增加受训位。
- `data/action_defs.json` 新增 `work_training_instructor` 和 `receive_weapon_training`；无武器且无坐骑的 NPC 不能训练或执教，受训者需要训练场内已有有效教官。
- `ActionSystem.gd` 实现教官独自练习、带受训者训练、受训者按当前主武器 / 坐骑提升武器熟练度或骑术、教官教学时提升“教练”、训练按单位时间消耗疲劳和饱食，以及教官/受训者项目熟练度差影响训练速度。
- `MemorySystem.gd` 补充训练相关 `skill_improved` summary；GM 面板可通过行动下拉指派训练行动，并保留 `train_instructor` / `train_student` 命令。
- 新增 `tools/verify_training_system.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖训练场 GM 入口和普通行动下拉；`tools/verify_action_system_basic.gd` 同步当前酒窖产出缩放断言。
- 验证通过：`verify_training_system.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_clinic_treatment.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0902 兵种判定

- `EquipmentSystem` 新增 `get_unit_type_snapshot(npc_id)`，返回兵种 id、中文标签、主武器类型、武器 class、是否有坐骑、坐骑 id 和完整装备槽快照，供 GM 面板和后续战斗系统只读使用。
- GM `unit_type <npc_id>` 改为输出完整兵种快照，方便验证“马匹整备库存”与“NPC 已装备坐骑槽”不是同一件事。
- 新增 `tools/verify_unit_type_classification.gd`，覆盖无武器、剑盾、长杆、弓、弩、近战武器 + 坐骑、远程武器 + 坐骑，以及“只有坐骑/只有库存不算骑兵”的边界。
- 验证通过：`godot --headless --path . --script res://tools/verify_unit_type_classification.gd`。

## 2026-06-09 T0013 移除短剑旧占位装备

- 删除 `data/weapon_defs.json` 中的旧占位主武器定义；正式主武器只保留剑盾、长杆、弓和弩。
- 移除 `NPCSystem.gd` 中旧占位武器兼容入口，正式装备统一通过 `EquipmentSystem` 选择具体主武器。
- `tools/verify_equipment_system.gd`、`tools/verify_hud_resources.gd` 和 `tools/verify_unit_type_classification.gd` 增加回归断言，确认旧占位武器不会再进入装备系统、HUD 详情或兵种判定。
- 验证通过：`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0012 HUD 详情面板与 GM 面板定位修正

- HUD 主资源栏去掉装备/器械详情中已有的聚合库存：武器、盔甲、马匹整备和工程器械，保留第纳尔、粮食、餐食、酒、木材、石料和铁。
- “装备”和“器械”详情面板改为贴近各自按钮左下方打开，并根据可用屏幕范围夹住位置。
- GM 面板改为跟随 `GM` 按钮附近打开；拖动按钮时已打开面板同步重定位并保持在可用屏幕范围内，面板高度收紧以减少遮挡 HUD。
- 更新 `tools/verify_hud_resources.gd` 和 `tools/verify_gm_panel.gd`，覆盖 HUD 主栏去重、详情面板定位、GM 面板跟随按钮和边界钳制。
- 验证通过：`verify_hud_resources.gd`、`verify_gm_panel.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0011 HUD 完整资源库存与装备器械详情

- `scripts/ui/HUD.gd` 改为按 `ResourceSystem.get_resource_ids()` 动态生成资源栏，直接显示第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料和铁。
- HUD 资源栏新增“装备”“器械”按钮；装备详情显示武器 / 盔甲 / 马匹整备库存、可分配装备定义和已分配数量，器械详情显示工程器械库存与当前未部署边界。
- `ResourceSystem` 新增 `get_resource_definition(...)`，`EquipmentSystem.get_armor_ids(...)` 修正为稳定返回 `Array[String]`，避免详情读取盔甲槽位时触发类型错误。
- 新增 `tools/verify_hud_resources.gd` 覆盖全量资源显示、派生库存刷新、装备详情和器械详情入口。
- 验证通过：`verify_hud_resources.gd`、`verify_equipment_system.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0901 库存与装备系统

- 新增 `res://scripts/systems/EquipmentSystem.gd` 并挂载到 `Main/Systems/EquipmentSystem`，作为装备库存、装备槽和兵种判定的权威入口。
- `data/weapon_defs.json` 补齐剑盾、长杆、弓、弩等主武器类型；新增 `data/armor_defs.json` 和 `data/mount_defs.json`，覆盖头盔、胸甲、腕甲、腿甲和坐骑槽。
- 装备主武器消耗 `weapons`，装备盔甲消耗 `armor`，装备坐骑消耗 `horse_readiness`；换装会返还旧装备对应库存。只有已入伍 NPC 可被守备官直接分配装备。
- NPC 面板新增主武器选择，装备后显示当前装备和战斗定位；GM 面板新增装备武器、装备盔甲、装备坐骑和兵种查看入口及命令。
- 装备事件复用 `MemorySystem.record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`，并按 `private` / `local_public` 传播给同地点见闻。
- 新增 `tools/verify_equipment_system.gd`，并更新 `verify_npc_panel_interactions.gd`、`verify_gm_panel.gd`。
- 验证通过：`verify_equipment_system.gd`、`verify_npc_panel_interactions.gd`、`verify_gm_panel.gd`、`verify_blacksmith_metal_gear.gd`、`verify_workshop_ranged_devices.gd`、`verify_stable_horse_care.gd`、`verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0010 忽略本机 VSCode Godot 路径配置

- `.gitignore` 新增 `.vscode/settings.json`，避免两台电脑不同 Godot 路径在 Git 同步时反复产生冲突或脏改动。
- 执行 `git rm --cached .vscode/settings.json`，让 Git 停止跟踪该文件，但保留本机文件；已确认 `.vscode/settings.json` 仍存在。
- 验证通过：`godot --headless --path . --quit-after 1`、`tools/check_godot_mcp.ps1`。

## 2026-06-09 T0009 Godot MCP 运行桥接类缓存启动失败修复

- 排查 Git 同步后项目跑不起来的问题，确认 `main` 已与 `origin/main` 对齐，仅 `.vscode/settings.json` 有本机 Godot 路径改动；A 电脑改动未显示为丢失或冲突。
- 直接启动 `godot --headless --path . --quit-after 1` 时，`MCPGameBridge` Autoload 因找不到 `MCPRuntimeStateSampler` 类型解析失败；文件实际存在，问题来自 Godot 全局类缓存未登记该 `class_name`。
- `addons/godot_mcp/game_bridge/mcp_game_bridge.gd` 改为 `preload("mcp_runtime_state_sampler.gd")` 并通过预加载脚本创建 sampler，不再依赖 `.godot/global_script_class_cache.cfg`。
- `_handle_watch_start(...)` 的 `start_result` 显式标注为 `Dictionary`，避免动态 sampler 实例导致类型推断失败。
- 验证通过：`godot --headless --path . --quit-after 1`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`tools/check_godot_mcp.ps1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0008 NPC 面板内容增多时向上溢出修复

- 修复 NPC 面板内容变多时向上下两个方向扩展，导致顶部越出屏幕的问题。
- `Main.tscn` 中 `Main/UI/NPCPanel` 和内部 `PanelContainer` 的垂直增长方向改为向下，保留右上角顶边作为固定基准。
- `tools/verify_npc_panel_state.gd` 增加长事件库/见闻库文本回归，确认内容膨胀时 `PanelContainer` 不会向上越过 NPC 面板顶边。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`。
- Godot MCP 自检通过：`addon_status` connected，当前打开场景为 `res://scenes/main/Main.tscn`。

## 2026-06-09 T0808 小诊所治疗行动完善

- `data/building_defs.json` 中小诊所拆分为 `clinic_doctor` 医生工位和 `patient_bed` 病床，诊所升级当前增加病床。
- `data/action_defs.json` 新增 `work_clinic_doctor` 和 `receive_clinic_treatment`，让医生坐诊/研读医术和病人占床成为两个独立行动选项。
- `ActionSystem` 新增诊所治疗逻辑：医生在岗且受伤未昏迷 NPC 占床时才推进治疗；治疗按逻辑时间消耗第纳尔并恢复 HP，医术、智力和诊所等级提高恢复速度；病人回满 HP 后释放病床。
- 医生无病人时会以慢速研读医学著作并通过 `skill_improved` 事件提升医术，治疗中也会少量提升医术；T0808 阶段只处理医术最小增长，现已在 T0904 接入统一经验、技能点和玩家属性分配规则。
- `NPCSystem` 新增 `restore_npc_hp(...)` 和 `increase_npc_skill(...)`，供诊所治疗与医术最小成长调用。
- 新增 `tools/verify_clinic_treatment.gd`，验证诊所工位/病床、研读医术、病床治疗、金钱消耗、医术/智力/诊所等级效率、治疗完成事件和病床释放。
- 验证通过：`verify_clinic_treatment.gd`、`verify_npc_unconscious_healing.gd`、`verify_work_output_framework.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0807 酒窖酿酒与出售边界

- `data/action_defs.json` 的 `work_tavern` 明确使用 `stat="intelligence"`，消耗 1 份粮食，产出 `wine` 酒派生库存。
- 酒窖工作沿用 T0801 统一效率公式：酿酒熟练度、智力和酒窖建筑等级会缩短单位酿造周期；`output_scaling` 会按酿酒、智力和酒窖等级提高实际酒库存产出。
- 将厨子布鲁诺的酿酒熟练度从 38 调整为 58，以符合 `game_design.md` 中厨子具备酿酒优势的定位。
- 新增 `tools/verify_tavern_wine_trade.gd`，验证酒窖配置、酿酒/智力/建筑等级效率、粮食消耗、酒库存产出、完成事件 payload、缺粮失败，以及酿酒完成不会在商人交易系统实现前自动增加第纳尔。
- 当前不实现饮酒，也不实现商队出售酒换钱；出售部分已补到 T1507 商人交易系统，要求接住 T0807 的 `wine` 库存。
- 验证通过：`verify_tavern_wine_trade.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`、`verify_garden_grain_output.gd`、`verify_workshop_ranged_devices.gd`、`verify_stable_horse_care.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0806 马厩马匹喂养与恢复

- `data/action_defs.json` 的 `work_stable` 明确使用 `stat="strength"`，消耗 1 份粮食，产出 `horse_readiness` 马匹整备派生库存。
- 马厩工作沿用 T0801 统一效率公式：养马熟练度、力量和马厩建筑等级会缩短单位照料周期；`output_scaling` 会按养马、力量和马厩等级提高实际马匹整备产出。
- 新增 `tools/verify_stable_horse_care.gd`，验证马厩配置、养马/力量/建筑等级效率、粮食消耗、马匹整备库存产出、完成事件 payload 和缺粮失败。
- 当前任务当时不实现坐骑装备槽、NPC 胯下骑乘表现、战斗移动速度加成、骑乘战术或卸下回马厩；坐骑槽、骑乘表现和战斗策略已分别由 T0901/T0902、T1103、T1105 接入，完整移动速度加成和卸下回马厩仍是后续任务。
- 验证通过：`verify_stable_horse_care.gd`。

## 2026-06-09 T0805 工械坊弓弩与防御器械

- `data/action_defs.json` 的 `work_workshop` 明确使用 `stat="intelligence"`，消耗 2 份木材，产出 1 份 `weapons` 和 1 份 `defense_devices` 派生库存。
- 工械坊工作沿用 T0801 统一效率公式：工程熟练度、智力和工械坊建筑等级会缩短单位制作周期；本次不实现具体弓/弩装备条目、装备外观或防御器械部署结算。
- 新增 `tools/verify_workshop_ranged_devices.gd`，验证工械坊配置、工程/智力/建筑等级效率、木材消耗、武器/工程器械库存产出、完成事件 payload 和缺木失败。
- 更新 T0901 后续安排：正式库存与装备系统需要接住 T0805 进入 `weapons` 的木质远程武器占位，并把主武器区分为剑盾、长杆、弓、弩等类型；T1508 继续负责消耗 `defense_devices` 并部署工程器械。
- 验证通过：`verify_workshop_ranged_devices.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_blacksmith_metal_gear.gd`、`verify_garden_grain_output.gd`、`verify_dining_hall_meals.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0804 铁匠铺金属武器和盔甲

- `data/action_defs.json` 的 `work_blacksmith` 明确使用 `stat="strength"`，消耗 2 份铁，产出 1 份 `weapons` 和 1 份 `armor` 派生库存。
- 铁匠铺工作沿用 T0801 统一效率公式：打铁熟练度、力量和铁匠铺建筑等级会缩短单位制作周期；本次不实现装备部位、品质、耐久或外观。
- 新增 `tools/verify_blacksmith_metal_gear.gd`，验证铁匠铺配置、打铁/力量/建筑等级效率、铁消耗、武器/盔甲库存产出、完成事件 payload 和缺铁失败。
- 在 T0901 任务中补充后续安排：正式库存与装备系统需要接住 T0804 的 `weapons` / `armor` 派生库存，再映射到主武器、头盔、胸甲、腕甲、腿甲等可装备数据。
- 验证通过：`verify_blacksmith_metal_gear.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`、`verify_garden_grain_output.gd`。

## 2026-06-09 T0803 菜园粮食产出

- `data/action_defs.json` 的 `work_garden` 增加 `stat="strength"` 与 `output_scaling`，菜园基础产出 2 份粮食，并由耕种熟练度、力量和菜园等级提高实际产出。
- `ActionSystem` 新增配置化工作产出缩放计算；工作完成时按缩放后的 `output_resources` 增加资源，并把实际产出写入 `work_completed` 事件 payload。未配置缩放的工作保持固定产出。
- 新增 `tools/verify_garden_grain_output.gd`，验证菜园产粮、耕种影响产出、力量影响产出、菜园等级影响产出，以及完成事件记录缩放后的粮食产出。
- 更新 T0801 工作框架验证，避免继续假设菜园永远固定产出 2 粮食。
- 验证通过：`verify_garden_grain_output.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`。

## 2026-06-09 T0802 食堂粮食加工餐食

- 新增 `tools/verify_dining_hall_meals.gd`，把 T0802 从 T0801 框架中拆出为独立验收：验证 `work_dining_hall` 消耗粮食、产出餐食、使用厨艺，并验证厨艺和食堂等级会缩短加工周期。
- 验证吃饭行动优先消耗餐食；餐食恢复 50 点饱食度，粮食恢复 25 点饱食度。
- 验证食堂工作和吃饭完成事件写入 NPC 事件库，payload 保留资源输入、资源输出、食物资源和饱食恢复量。
- 验证通过：`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`。

## 2026-06-09 T0007 工作中 NPC 状态刷新抢回面板修复

- 修复工作中 NPC 的 `npc_state_changed` 持续刷新会在玩家切到建筑面板后重新打开 NPC 面板的问题。
- `NPCPanel` 现在只在自身可见且刷新目标仍是当前 NPC 时响应状态刷新；点击建筑隐藏 NPC 面板后，工作、饱食、疲劳等后续状态变化不会再把它弹出。
- `tools/verify_npc_panel_state.gd` 增加回归用例：NPC 面板切到建筑面板后模拟同一 NPC 工作状态刷新，确认右上角保持建筑面板。
- 验证通过：`verify_npc_panel_state.gd`、`verify_work_output_framework.gd`、`verify_gm_panel.gd`。

## 2026-06-09 T0801 职业工作产出框架

- `BuildingSystem` 新增 `claim_workstation(...)` / `release_workstation(...)`，工作位占用和释放由建筑系统权威维护，工位变化继续通过 `building_state_changed` 触发地点内部状态广播。
- `ActionSystem` 的工作行动接入统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；低熟练不会慢于配置基准，高熟练 NPC 会更快完成同一单位产出。
- 工作开始写入实际 `workstation_id`、`building_id`、基础时长、有效时长和效率倍率；完成、资源失败或中断会释放工位并写入结构化事件。
- 新增 `tools/verify_work_output_framework.gd`，覆盖高熟练更快、工位占用/释放、占满拒绝第二名工人、资源不足失败不占工位、地点内部状态广播和事件写入。
- 验证通过：`verify_work_output_framework.gd`、`verify_action_system_basic.gd`、`verify_location_info_nodes.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0705 NPC 主动找守备官交涉

- `NPCSystem` 新增主动交涉状态与调试入口：可让 NPC 进入 `proactive_talk`，默认持续 1 游戏小时，触发时写入 `private` `proactive_talk_started`，超时或对话结束后请求计划重评估。
- `NPC.gd` 运行时创建 `ProactiveTalkBubble` 问号气泡；点击有主动交涉状态的 NPC 会优先打开对话，不先弹出 NPC 面板。
- `DialogSystem` 新增 `start_proactive_player_dialogue(...)`，复用既有玩家-NPC 对话面板，把 NPC 预先确定的开场问题作为第一条历史显示，并写入 `proactive_talk_message`。
- `MemorySystem` 新增 `proactive_talk_started` / `proactive_talk_message` 事件类型、必需 payload 和确定性 summary；玩家后续回复继续走既有 `dialogue_turn`。
- GM 面板新增主动交涉按钮、`start_proactive` 命令和 `proactive` 状态查询；新增 `tools/verify_npc_proactive_talk.gd`。
- 验证通过：`verify_npc_proactive_talk.gd`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0704 反馈修正：移除 NPC 面板要求休息按钮

- 移除 `NPCPanel` 的“要求休息/请求治疗”按钮及自动选择治疗者逻辑；休息、治疗这类意图由已入伍 NPC 的自然语言指令承担，既有 GM / ActionSystem 调试入口保留。
- 将给钱数量 `SpinBox` 从交互可见性行移动到“给钱”按钮旁边，让金额输入与给钱动作直接关联。
- 给钱数量输入框新增数字过滤，字母键不会写入金额文本；按 WASD 时会释放金额框焦点，让相机移动继续响应。
- 新增 `UIInputFocusManager` 并挂载到 `Main/UI`，让任意 `LineEdit` / `TextEdit` 在点击输入框外时释放焦点；NPC 给钱金额框、对话输入框和指令 TextEdit 已加入回归验证。
- 更新 `tools/verify_npc_panel_interactions.gd`，改为验证休息/治疗按钮不存在，并继续覆盖给钱、占位装备、攻击、公开见闻、LLM 短期记忆上下文和输入框点击外部失焦。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0704 NPC 面板非对话交互记忆

- `NPCPanel` 新增非对话交互区：可选择私下 / 同地点公开，赠予第纳尔、给予旧占位武器、攻击；给钱数量输入框紧邻“给钱”按钮。
- `NPCSystem` 新增 `give_money_to_npc(...)` 和旧占位武器入口：前者扣除全局第纳尔并增加目标 NPC 随身金钱，后者消耗 1 个全局 `weapons` 并写入装备事件；二者都复用 `MemorySystem.record_player_interaction(...)`，不重做事件系统。旧占位武器入口已在 T0013 后移除。
- 攻击按钮复用 `NPCSystem.apply_damage_to_npc(...)`，保持 HP、昏迷和恢复结算权威边界不变；NPC 面板不提供休息 / 治疗按钮。
- 新增 `tools/verify_npc_panel_interactions.gd`，覆盖给钱事件、同地点见闻、占位装备、攻击扣血、广场公开事件、后续 LLMBridge 短期记忆上下文，并检查休息/治疗按钮不存在。
- 验证通过：`verify_npc_panel_interactions.gd`、`verify_npc_panel_state.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。`verify_dialogue_ui.gd` 本次未通过的原因是本机 5000 端口由 deepseek provider 后端响应，非本次 Godot 改动导致。

## 2026-06-04 T0703A 当前指令接入 NPC LLM 上下文与计划重评估

- 后端新增 `CurrentOrderContext`，接入共享 `NPCContext` 和对话顶层 `NPCDialogueRequest`；计划、修订、战斗判定、主动交涉、反思和知识图谱更新等复用共享上下文时自动携带最新指令。
- Godot `LLMBridge` 统一注入最新 `current_order`，保存最近注入快照；GM 新增“最近指令注入”按钮和 `last_order_injection` 命令。
- 新指令重评估请求保存最新指令和 `rule_fallback_deferred` 结果；完整计划应用仍归尚未实现的 T1002，当前不直接修改行动或权威数值。
- 验证通过：后端 Schema / Mock / 对话接口、Python 编译、LLMBridge HTTP、对话 UI、NPC 指令、GM 面板、结构化记忆与项目加载检查；Godot MCP 主场景运行无日志错误。

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

## 2026-06-04

### T0703 入伍 NPC 自然语言指令入口与存储
完成：
- 已入伍 NPC 的旧“指派（占位）”替换为可用“指令”按钮；新增 `Main/UI/OrderPanel` 多行自由文本编辑、预填、发布和关闭流程。
- `NPCSystem` 权威保存结构化 `current_order`，仅在文本变化时递增修订号、写入 `private` `order_assigned` 并发出统一计划重评估请求；相同文本或关闭无副作用。
- 8 名初始 NPC 配置补齐 `current_order`；MemorySystem 固定生成“守备官制定了新的指令。”摘要。
- GM 新增发布/查看指令和查看最近计划重评估请求入口；新增 `tools/verify_npc_order.gd`。

验证：
- `verify_npc_order.gd`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd`、`verify_structured_memory_events.gd`、`verify_npc_short_term_memory_container.gd` 与项目加载通过。
- Godot MCP 连接正常，运行 `Main.tscn` 无游戏日志报错。

### T0702 提出应征与征召结果
完成：
- `DialogPanel` 新增“提出应征”按钮，点击后把下一次玩家消息标记为应征请求，发送后自动清除。
- `DialogSystem` 校验后端 `accept` / `reject`，接受时调用 `NPCSystem.set_npc_recruited(...)` 更新权威状态，拒绝时保持原状态。
- 应征请求与结果写入该轮 `dialogue_turn.payload`；`MemorySystem` 将 `recruitment_result` 纳入对话事件必需字段。
- NPC 面板会立即显示已入伍，并仅对已入伍 NPC 显示禁用的“指派（占位）”按钮；未提前实现 T0703。

验证：
- `tools/verify_dialogue_ui.gd` 覆盖应征按钮、一次性请求、接受、拒绝、NPC 状态、指派占位与事件 payload。
- `verify_npc_panel_state.gd`、`verify_structured_memory_events.gd`、`verify_llm_bridge.gd`、`verify_gm_panel.gd`、后端 Schema/接口验证和项目加载通过。
- Godot MCP 连接正常。

### T0701 对话 UI
完成：
- NPC 面板新增“对话”按钮；`Main/UI/DialogPanel` 接入 NPC 名字、公开性、轮次、历史、自由文本输入、发送和结束按钮。
- `DialogSystem` 接通 `LLMBridge`，当时维护玩家-NPC 不限轮次会话与 NPC-NPC 默认 5 轮会话；NPC-NPC 轮次口径已由 T0029 替换为邀请后最多 3 轮。
- `MemorySystem` 为对话事件增加 payload 校验与确定性摘要；对话事件进入所有参与 NPC 事件库，`local_public` 只广播给同地点第三者。
- 新增 `tools/verify_dialogue_ui.gd`；未实现 T0702 征召状态切换。
- 修复“同地点公开”开关被永久禁用：首轮发送前可切换并同步会话公开性，首轮发送后锁定。
- 对话事件降噪：移除 `dialogue_started` / `dialogue_ended` 入库与广播，只保留实际发生的 `dialogue_turn`。

验证：
- `tools/verify_dialogue_ui.gd`、`tools/verify_llm_bridge.gd` 在隔离 `mock` 后端下通过。
- `verify_structured_memory_events.gd`、`verify_npc_panel_state.gd`、`verify_gm_panel.gd`、后端 Schema/接口验证和项目加载通过。
- Godot MCP 连接正常，运行主场景无游戏日志报错。

### T0005 修正 Godot MCP 多会话单例边界
完成：
- 确认 Codex 每个会话都需要自己的 stdio proxy；此前 proxy 按同父进程清理 sibling 的逻辑会主动关闭旧会话，正是旧会话收到 `Transport closed` 的根因。
- 移除 `godot-mcp-proxy.mjs` 的 proxy lock 与 sibling kill，proxy 现在只随所属会话 stdin 关闭而退出。
- 调整 `godot-mcp-broker.mjs` 启动顺序：先监听单例端口 `8765`，再建立唯一的 Godot `6550` WebSocket 连接，消除并发首次启动 race。
- 将旧 `start-godot-mcp.ps1` 改为只启动 broker，不再终止其他 MCP 进程，也不再绕过 broker 直连 Godot。
- 更新 `tools/check_godot_mcp.ps1`，多个 session-local proxy 视为正常；新增 `tools/verify_godot_mcp_topology.mjs` 做可重复拓扑验证。

验证：
- `node tools/verify_godot_mcp_topology.mjs` 验证多个 proxy 可共存、只保留一个 broker / Godot 连接，并验证关闭一个 proxy 不影响另一个。
- 冷启动并发验证通过；`start-godot-mcp.ps1` 重复运行后仍只保留一个 broker 和一条 Godot 连接。
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。

## 2026-06-03

### T0604A LLMBridge 原生 HTTP 传输层
完成：
- 将 `scripts/systems/LLMBridge.gd` 的传输层从 T0604 临时 `curl.exe` / 临时 JSON 请求体文件替换为 Godot 原生 `HTTPClient` 状态机。
- 保持 LLMBridge 对上层接口稳定：`check_health()`、`request_npc_dialogue(...)`、T0603 payload 构造、错误字典、`backend_status_changed` 和 TimeSystem 慢速注册/释放语义不变。
- 新实现覆盖连接、请求、响应体读取、HTTP 响应解析、非法 JSON、后端 `ok=false` 与超时错误；会影响当前事态的请求在成功、失败或超时后都会释放慢速请求。
- `tools/verify_llm_bridge.gd` 新增静态防回退检查，确认 `LLMBridge.gd` 不含 `curl.exe`、`OS.execute`、临时请求体文件名或旧写文件函数。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`AI_NPC_SYSTEM.md` 和 `API_BUDGET.md`，继续明确正式架构为 Godot 客户端请求游戏服务器后端，再由后端调用 LLM Provider；Godot 客户端不保存供应商 API Key。

验证：
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T1407 后端服务器部署任务登记
完成：
- 在 `docs/TASKS.md` 的 M14 新增 P0 任务 T1407：部署游戏后端到服务器。
- 明确服务器运行入口仍是 `backend/app.py`；本地开发可继续 `python backend/app.py`，正式部署不得使用 Flask debug server。
- 任务要求后续补齐生产 WSGI 启动方式、生产依赖、`backend/README.md` 部署说明、环境变量、日志、健康检查、限流、预算、重启策略和 Godot 后端地址配置。
- 同步更新 `TECH_ARCHITECTURE.md` 和 `CURRENT_STATE.md`，让后端部署方向从总览文档也能看到。

### T0604A 任务登记与 T0604 踩坑复盘
完成：
- 在 `docs/TASKS.md` 新增 P0 任务 T0604A，要求把 `LLMBridge` 的临时 `curl.exe` 传输层替换为 Godot 原生 HTTP。
- 将 T0701 对话 UI 的前置任务改为 T0604A，避免在临时传输层上继续叠加玩家对话与征召流程。
- 在 `TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`MODULE_INDEX.md`、`API_BUDGET.md`、`AI_NPC_SYSTEM.md` 和 `CURRENT_STATE.md` 中明确正式方向：玩家电脑运行 Godot 客户端，请求游戏服务器后端；服务器后端调用 LLM Provider、持有 API Key、负责并发、限流、降级、成本统计和调用日志。玩家自行配置 API Key 仅作为未来可选 BYOK / 开发模式，不是 Demo 必需路径。

T0604 踩坑归因：
- 主要问题是 Godot HTTP 传输层和 headless 验证方式，没有暴露 NPC、记忆、Prompt 或前后端职责边界的整体架构问题。
- Godot 原生 HTTP 首次尝试卡在信号等待、节点生命周期和异步请求验证方式上；后续 T0604A 需要显式请求状态机、完成回调和超时兜底。
- 同步等待异步 HTTP 结果会让验证脚本挂起；所有成功、失败、超时和降级路径都必须释放 TimeSystem 慢速请求。
- Windows 命令行传中文 JSON、引号和换行容易破坏请求体；T0604 使用 `curl.exe` + 临时 JSON 文件只是为了先保住最小闭环，不是分发方案。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端会按设计返回 provider unavailable；后续验证应显式使用 mock 或隔离环境。

后续避免：
- 先完成 T0604A，再推进 T0701/T0702。
- 任何真实 LLM 接入都必须走后端 Model Adapter，Godot 客户端不得保存真实供应商 API Key 或直连模型供应商。
- 对会影响即时事态的 LLM 请求，验证必须覆盖成功、失败、超时、后端关闭和慢速释放。

### T0604 Godot LLMBridge
完成：
- 新增 `scripts/systems/LLMBridge.gd` 并挂载到 `Main/Systems/LLMBridge`。
- `LLMBridge` 支持后端地址配置、`GET /health`、`POST /npc/dialogue`、T0603 对话 payload 构造、后端失败/超时错误结果、TimeSystem 慢速请求注册与释放。
- HUD 后端状态改为读取 `LLMBridge`，GM 面板新增后端健康检查、对话 Mock 和应征 Mock 调试入口。
- 新增 `tools/verify_llm_bridge.gd`，覆盖 payload 字段对齐、后端关闭不崩、health、dialogue Mock、慢速注册与成功/失败后释放。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`AI_NPC_SYSTEM.md`、`API_BUDGET.md` 和 `GM_PANEL.md`。

验证：
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0603 `/npc/dialogue` Mock 接口
完成：
- `backend/app.py` 新增 `POST /npc/dialogue`，请求体校验为 T0603 版 `NPCDialogueRequest`；T0087 后 Mock 输出按三类封闭响应 Schema 校验。
- `backend/schemas/npc_ai.py` 重整对话 Schema：输入覆盖目标 NPC 设定、说话者名称/文本/上下文、是否提出应征、当前轮次/最大轮次、NPC 状态、对话公开性、短期记忆、长期记忆和地点快照；输出使用 `replyer_id`、`reply_text`、`response_kind`、`recruitment_result` 和 `should_end_dialogue`。
- `backend/services/model_adapter.py` 的 `dialogue` Mock 分支支持玩家-NPC 应征 `accept` / `reject`，并在 NPC-NPC 对话轮次接近上限时倾向结束对话。
- 新增 `tools/verify_dialogue_mock_endpoint.py`，覆盖 `/npc/dialogue` HTTP 调用、应征 accept/reject、NPC-NPC 结束倾向和非法请求 400。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`DATA_SCHEMA.md`、`AI_NPC_SYSTEM.md`、`MEMORY_AND_INFO_SPACE.md`、`PROMPTS.md`、`API_BUDGET.md`、`backend/README.md`、`backend/schemas/README.md` 和 `game_design.md`。

验证：
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_mock_model_adapter.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- Python 编译检查通过。

### T0602 Mock Model Adapter
完成：
- `backend/services/model_adapter.py` 默认 provider 改为 `mock`，`.env` 不存在或未设置 `LLM_PROVIDER` 时可直接返回 Mock JSON。
- 新增 `ModelAdapter.generate(...)`、`ModelAdapterResult` 和 `ModelUsageRecord`，按调用类型返回稳定内容，并记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态。
- Mock 当前覆盖对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉、玩家话术分类和通用兜底响应；每日计划固定返回 24 条计划项。
- `backend/app.py` 新增 `POST /mock/model` 调试接口；非法 JSON / 非对象 payload 返回 400，非 mock provider 未配置 `LLM_API_KEY` 时返回明确错误。
- 新增 `tools/verify_mock_model_adapter.py`，并回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`API_BUDGET.md` 和后端 README。

验证：
- `python tools/verify_mock_model_adapter.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py` 通过。

### T0601 后端 Schema
完成：
- 新增 `backend/schemas/common.py`，定义后端 AI 请求共享上下文：游戏时间、请求元信息、NPC 身份/状态、短期记忆摘要、行动候选和通用错误响应。
- 新增 `backend/schemas/npc_ai.py`，覆盖 NPC 对话、每日计划、计划异常重评估、战斗判定、睡前总结、知识图谱更新、主动找守备官交涉和玩家话术分类的请求/响应模型。
- 新增 `backend/schemas/__init__.py`、`backend/schemas/README.md` 和 `tools/verify_backend_schemas.py`。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`DATA_SCHEMA.md`、`PROMPTS.md` 和后端 README。

验证：
- `python tools/verify_backend_schemas.py` 通过。
- `python -m py_compile backend/schemas/common.py backend/schemas/npc_ai.py backend/schemas/__init__.py tools/verify_backend_schemas.py` 通过。
- Flask `create_app().test_client().get("/health")` 返回 200。

### T0502A 睡觉期间停止接收见闻
完成：
- `MemorySystem.add_witness_event(...)` 的见闻接收判定扩展为拒绝 `current_action == "sleep_in_dormitory"` 的 NPC。
- 睡觉 NPC 不再接收同地点/同建筑 `local_public` 事件、地点/建筑状态广播、公告或进入快照；自己的 `sleep_started` / `sleep_ended` 仍写入事件库。
- `tools/verify_action_local_public_broadcast.gd` 增加睡觉期间拒收 public 见闻、睡醒后恢复接收的回归断言。

验证：
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。

### T0409 广场 NPC 状态快照补齐
完成：
- `MemorySystem.get_location_snapshot(...)` 现在会为广场和可进入建筑统一生成 `people_statuses`；NPC 进入广场时，`location_context` 和一次性 `location_entry_snapshot` 见闻都能看到广场上 NPC 的生命状态与行动状态。
- 广场进入快照 summary 新增“在场人员状态”段落，沿用健康/受伤/昏迷、治疗者和精简中文行动状态的同一套格式。
- `tools/verify_location_info_nodes.gd` 增加广场 `people_statuses` 与 summary 断言。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-06-02

### T0005 Godot MCP transport 断开复盘
完成：
- 复盘本次连接异常：Godot MCP 工具返回 `Transport closed`，但 `tools/check_godot_mcp.ps1` 一度仍返回 `Godot MCP connected`，说明 Godot 插件和 `broker -> Godot` 链路未先断，当前 Codex 会话的 stdio MCP transport 已关闭。
- 清理残留 headless Godot 验证进程后，重启 `godot-mcp-broker.mjs`，broker health 与 listTools 均可手动返回。
- 重启/刷新 Codex 后，`project.addon_status` 和 `editor.get_state` 恢复正常。
- 将本次教训回写到 `CURRENT_STATE.md` 的 Godot MCP 段落和 `TASKS.md` 的 T0005 复盘：后续排查要区分 Godot 插件监听、broker 健康、Codex MCP transport 三层；`Transport closed` 不一定表示 Godot 插件掉线。

验证：
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- Godot MCP `project.addon_status` 返回 `connected: true`、`versions_match: true`。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

### T0407/T0503 建筑内 NPC 状态快照
完成：
- `MemorySystem` 的可进入建筑快照新增 `people_statuses`，进入者的 `location_entry_snapshot` 见闻会写出建筑内 NPC 的生命状态与行动状态。
- 生命状态分为健康、受伤、昏迷；昏迷者如有治疗者，会在状态文本中写明治疗者。行动状态由 `current_action` 翻译成精简中文。
- `ActionSystem` 新增只读 `get_healing_helpers_for_target(...)`，供信息节点查询当前治疗者，不参与权威结算。
- `tools/verify_location_info_nodes.gd` 和 `tools/verify_npc_unconscious_healing.gd` 增加建筑内 NPC 状态断言。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 事件摘要降噪
完成：
- `revived` summary 改为只表达 NPC 苏醒，不再展示 HP 恢复到多少。
- `healing_completed` payload 和 summary 不再包含原因字段。
- `tools/verify_npc_unconscious_healing.gd` 增加复苏 HP 文本和治疗完成原因字段的隐藏验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 治疗事件归属修正
完成：
- 修正协助治疗事件归属：治疗开始/完成进入治疗者和被治疗者事件库；同地点其他在场 NPC 获得见闻；治疗者不再把自己的治疗事件收到见闻库。
- 治疗事件 payload 和 summary 不再暴露医术熟练度。
- `tools/verify_npc_unconscious_healing.gd` 增加治疗事件归属与医术字段隐藏验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 治疗昏迷 NPC
完成：
- `NPCSystem` 新增 `assist_unconscious_recovery(...)`，按医术熟练度计算协助治疗恢复速度；低医术几乎没有额外加成，高医术会明显快于自然恢复。
- `ActionSystem` 新增 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`，治疗者会前往昏迷目标所在信息地点；目标必须昏迷，每个目标最多 2 名治疗者。
- 治疗开始立即消耗 1 枚第纳尔，持续治疗期间每 1800 游戏秒继续消耗 1 枚第纳尔；资源不足时治疗指派失败或治疗中止。
- `MemorySystem` 增加 `healing_started` / `healing_completed` payload 校验和确定性 summary；治疗事件写入治疗者和目标 NPC 事件库，并写入同地点其他在场 NPC 的见闻库。
- `data/action_defs.json` 新增 `assist_heal` / `targeted_heal` 行动定义，普通 `assign_action` 不直接执行，必须通过带目标的协助治疗接口。
- GM 面板新增治疗目标下拉、协助治疗按钮和 `assist_heal <healer_npc_id> <target_npc_id>` 命令。
- 新增 `tools/verify_npc_unconscious_healing.gd` 覆盖 T0503 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-05-26

### T0502 昏迷自然恢复
完成：
- `NPCSystem` 监听 `TimeSystem.logical_time_tick`，让昏迷 NPC 按每游戏小时 2 HP 自然恢复；暂停时无逻辑 tick，因此恢复也暂停。
- HP 达到 Max HP 30% 后自动复苏，设置 `unconscious=false`、`current_action=idle`，并发出 `npc_revived`。
- `MemorySystem` 增加 `revived` payload 校验和确定性 summary；复苏事件按 NPC 当前信息地点 `local_public` 广播给同地点 NPC。
- 追加 T0502A：`MemorySystem.add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，昏迷期间不接收地点/广场广播、状态广播、公告或进入快照；复苏后自动恢复接收。
- GM 面板新增 `recover_npc <npc_id> <game_seconds>` 命令，调用 `NPCSystem.debug_advance_unconscious_recovery(...)`，便于快速验证自然恢复。
- 新增 `tools/verify_npc_unconscious_natural_recovery.gd` 覆盖 T0502/T0502A 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0409 广场进入快照与室内经由广场移动链
完成：
- `MemorySystem` 的广场 `location_entry_snapshot` summary 现在会写出广场当前在场 NPC、公告牌文本和所有建筑可传播外部状态；payload 继续保留 `people_present`、`current_notice`、`building_external_states` / `key_entities`。
- `NPCSystem` 将地点切换和进出事件记录收敛为统一逻辑；室内信息地点切换到另一个室内信息地点时，会记录“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的事件链。
- 正常移动到达和 `debug_enter_location_immediately(...)` 共用同一套地点切换路径；当前物理移动仍是低模直线占位。
- `tools/verify_location_info_nodes.gd` 覆盖广场进入快照和室内经由广场事件链；`tools/verify_npc_movement_location.gd` 同步不可进入仓库归入广场信息节点的当前架构。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0501 NPC HP 扣除与昏迷状态
完成：
- `NPCSystem` 新增 `apply_damage_to_npc(...)` / `debug_damage_npc(...)`，负责权威扣除 NPC HP；HP 降到 0 后设置 `unconscious=true`、`current_action=unconscious` 并停止移动。
- `ActionSystem` 在 NPC 昏迷后清除 pending / active 行动，并拒绝继续指派工作、吃饭、睡觉、协助修复/升级；`NPCSystem.move_npc_to_building(...)` 同样拒绝移动昏迷 NPC。
- `MemorySystem` 增加 `damage_taken` / `unconscious_started` payload 校验和确定性 summary；昏迷事件以 `local_public` 广播到 NPC 当前信息地点，让同地点 NPC 收到见闻。
- `GMPanel` 的 `attack_npc` / 新增 `damage_npc` 命令改为调用 NPC 扣血接口；`verify_gm_panel.gd` 增加扣血昏迷检查。
- 新增 `tools/verify_npc_damage_unconscious.gd` 覆盖 T0501 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0408 收敛广场公开事件可见性
完成：
- 事件可见性只保留 `private` 与 `local_public`；广场广播改为 `location_id == "plaza"` 的本地公开事件。
- `MemorySystem` 将广场公告、广场状态、手动广场广播和协助修复/升级事件统一走地点广播路径，并将广场事件查询接口改为 `get_plaza_events()` / `debug_get_plaza_events()`。
- `ActionSystem` 协助修复/协助升级开始事件改为广场本地公开事件。
- `GMPanel` 可见性下拉移除旧广场专用公开项，攻击事件默认使用 `local_public`。
- `tools/verify_plaza_local_public_broadcast.gd` 替换旧广场专用广播验证脚本，并同步更新结构化事件、短期记忆和行动验证。

验证：
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0407 精简地点事件与建筑状态见闻
完成：
- `location_entered` / `location_exited` 现在只记录进入/离开的行动事实，不再在事件 payload 或 summary 中携带完整地点状态。
- NPC 进入新信息地点时，进入者会在见闻库获得一次 `location_entry_snapshot` 当前状态快照；已经在该地点的 NPC 只收到本地公开的进入/离开事件。
- NPC 离开地点时生成 `location_exited`，事件 `location_id` 使用被离开的地点，并广播给仍在该地点的 NPC。
- 建筑状态变化见闻改为字段级差量：外部状态使用 `changed_fields`，工位占用变化使用 `changed_workstations`，不再复制完整广场或建筑快照。
- 更新 `tools/verify_location_info_nodes.gd` 与 `tools/verify_plaza_local_public_broadcast.gd` 覆盖 T0407 规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-05-25

### 建筑修复覆盖、进入快照与协助事件位置修正
完成：
- `data/building_defs.json` 为城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊补齐 `repair` 配置，验证所有建筑都可修复。
- NPC 进入可进入建筑时，`location_entered` 摘要和进入者收到的当前状态见闻会立即包含建筑外部状态、建筑内 NPC 和工位占用状态。
- 协助修复/协助升级改为广场行为：NPC 在室内时先移动到广场；协助开始事件写入 `location_id == "plaza"` 的 `local_public`，目标建筑保留在 `payload.building_id`。
- `BuildingSystem` 的协助者有效性改为要求 NPC 仍在广场且当前行动仍是协助对应建筑。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0205/T0305/T0403/T0404/T0405 建筑升级倒计时与见闻降噪
完成：
- `BuildingSystem.upgrade_building(...)` 改为点击时一次性扣除资源并创建升级作业，随 `logical_time_tick` 推进；倒计时完成后才提升等级、Max HP 和可配置工作位奖励。
- 建筑受损、正在修复或正在升级时不可开始升级；升级期间不可开始修复。所有建筑定义都补齐了 `upgrade` 最小配置。
- `ActionSystem` 新增 `debug_assign_upgrade_assist(npc_id, building_id)`；NPC 可协助正在升级的建筑并按工程熟练度提供加速，升级完成后自动回到 idle。
- `MemorySystem` 的建筑可传播外部状态收窄为等级和完好/受损/正在修复/正在升级；HP、Max HP、剩余修复/升级时长不再触发见闻传播。可传播内部状态收窄为在场 NPC 和每个工位的占用/空闲状态，工位数量不再触发传播。
- 建筑状态见闻 summary 改为直接表达实际信息，不再使用“建筑状态更新”这类空泛前缀。
- `BuildingPanel` 显示升级倒计时进度、剩余时间、速度倍率和协助人数；`GMPanel` 新增协助升级按钮与 `assist_upgrade <npc_id> <building_id>` 命令。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0403/T0404/T0405 建筑状态与见闻广播修正
完成：
- `MemorySystem` 监听 `building_state_changed`，任一建筑外部状态变化都会同步到广场 `building_external_states` / `key_entities`，并生成带具体建筑名的 `plaza_status_changed` 见闻。
- 可进入建筑状态变化会生成 `location_status_changed` 本地见闻；NPC 进入广场获得所有建筑外部状态，进入可进入建筑获得该建筑外部 + 内部状态。
- 建筑状态快照拆分外部状态（HP、等级、完好/受损/正在修复、剩余修复时长）和内部状态（在场 NPC、工位数量、占用/空闲状态）；不可进入建筑不暴露内部 NPC 或工位。
- `data/building_defs.json` 移除主厅、仓库、围墙、城门的旧内部工位占位；围墙升级不再增加内部工位。
- 更新 `tools/verify_location_info_nodes.gd`、`tools/verify_plaza_local_public_broadcast.gd`、`tools/verify_building_repair_upgrade.gd` 覆盖全建筑外部状态、内部字段隔离、状态见闻命名和不可进入建筑无工位规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0006 修复建筑修复进度抢占右上角面板
完成：
- `EventBus` 新增 `building_state_changed(building_id)`，区分建筑状态刷新与玩家/调试选择建筑。
- `BuildingSystem` 在建筑受损、开始修复、修复进度推进、协助者变化、修复完成和升级时发出 `building_state_changed`，不再复用 `building_clicked`。
- `BuildingPanel` 仍通过 `building_clicked` 打开建筑，但只在自身可见且当前显示同一建筑时响应 `building_state_changed` 刷新。
- `tools/verify_npc_panel_state.gd` 增加回归用例：开始修复受损建筑后点击 NPC，再推进修复时间，确认右上角保持 NPC 面板。

验证：
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0305 行动系统持续时间修订
完成：
- `ActionSystem` 的工作、吃饭、睡觉改为到达地点后进入 active 行动，随 `TimeSystem.logical_time_tick` 推进，不再瞬时完成。
- `data/action_defs.json` 改用 `duration_seconds`：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。
- 吃饭按 20 分钟恢复约 50 点饱食度结算；睡觉按 6.5 小时降低 100 点疲劳结算；工作保留 1 小时最小批次，完成后结算当前占位投入/产出。
- 更新行动验证脚本，使测试显式推进逻辑时间后再检查完成事件和数值变化。

验证：
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。

### T0005 加固 Godot MCP proxy 自恢复
完成：
- 排查到这次 MCP “又连不上”的直接原因不是 Godot 插件掉了，而是同一个 `codex` 父进程下残留了两个 `godot-mcp-proxy.mjs`；其中旧的那个没有 broker 子进程，属于孤立 proxy。
- 更新 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`，加入 `%USERPROFILE%\.codex\godot-mcp-proxy.lock`。新 proxy 启动时会检查同父进程的旧 proxy，命中后先清理再接管，退出时再移除自己的 lock。
- 更新 `tools/check_godot_mcp.ps1`，除了原来的连接判断外，额外提示“多 proxy”与“proxy 在但 broker 不在”两类故障。
- 将这次经验精简回写到 `CURRENT_STATE.md` 和 `TASKS.md` 的 Godot MCP 相关位置，后续排查优先先看自检脚本和 proxy/broker 进程关系。
- 追加修正：再次复发时确认旧逻辑只会清理 lock 指向的单个 proxy，连续多次拉起后更早的残留 proxy 仍会留下。已改为按同一个 `codex` 父进程枚举所有 `godot-mcp-proxy.mjs`，在启动时一次性清理其余旧实例。

验证：
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- Godot MCP `project.addon_status` 返回 `connected: true`、`versions_match: true`。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。
- 清理孤立 proxy 后，只剩 1 条有效的 `proxy -> broker` 链路。

## 2026-05-24

### T0205/T0305 建筑修复 UI 与协助行为清理
完成：
- `BuildingPanel` 不再把修复/升级消耗常驻显示在面板正文；悬停修复/升级按钮时，在按钮旁显示资源消耗和条件提示框。
- `BuildingSystem` 会在 NPC 状态变化和修复推进前清理无效协助者；NPC 离开对应建筑或被改派后，协助人数和速度加成立即移除。
- `ActionSystem` 的协助修复保留为 `debug_assign_repair_assist(npc_id, building_id)` 这一套带建筑参数的统一行为；移除 `data/action_defs.json` 中固定“修补围墙”行动，避免 GM 行动下拉与协助修复按钮表达重复。
- `GMPanel` 行动分组新增“修复目标”建筑下拉，让“协助修复”按钮可直接选择目标建筑。
- 建筑操作提示框增加屏幕边界夹取；靠近右侧等边缘时会翻到按钮内侧或保持在可视区域内。
- `tools/verify_action_system_basic.gd` 增加“协助者离开后移除加成”的回归检查。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动挑选修复目标；仍保留在 T1001 TODO。

### T0205/T0305 建筑修复倒计时与 NPC 协助修复
完成：
- `BuildingSystem.repair_building(...)` 改为点击时一次性扣除资源并创建修复作业；HP 随 `logical_time_tick` 按进度逐步恢复，不再瞬间修复。
- 修复时长由缺失 HP、建筑等级和 `data/building_defs.json` 中的 `repair.seconds_per_missing_hp` / `repair.level_time_factor` 计算。
- 新增修复状态查询与 NPC 协助接口：`get_repair_status(...)`、`is_repair_in_progress(...)`、`add_repair_helper(...)`、`remove_repair_helper(...)`。
- `ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`；NPC 到达正在修复的建筑后按工程熟练度加速倒计时，多个 NPC 可叠加，修复完成后回到 idle。
- `GMPanel` 新增 `assist_repair <npc_id> <building_id>` 命令，并在建筑快照中可观察修复状态。
- `MemorySystem` 预留并格式化 `repair_assist_started` 事件。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动选择协助修复；已把“规则计划可把协助修复作为候选行为并选择目标”加入 T1001 TODO。

### T0403 修复行动事件 local_public 广播
完成：
- 修复 `ActionSystem` 行动事件可见性：工作、吃饭、睡觉开始/完成/失败事件不再以 `private` 写入，而是以 `local_public` 写入 `MemorySystem`。
- 同地点当前在场 NPC 会收到这些活动/工作事件并写入见闻库；行动者本人仍只保留亲历事件，不重复写入自己的见闻库。
- 新增 `tools/verify_action_local_public_broadcast.gd`，覆盖工作、吃饭、睡觉三类行动事件的本地公开广播。

验证：
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未新增 GM 面板入口；现有行动指派和记忆查询入口已经可以手动验证该修复。

### T0406 统一玩家交互事件世界内称呼
完成：
- `MemorySystem.record_player_interaction(...)` 将玩家相关 actor id 写为 `guard_officer`，并在 payload 中补充 `actor_display_name = "守备官"`。
- 玩家非对话交互 summary 模板改为“守备官给了/守备官攻击了/守备官指派了”等世界内称呼，不再把“玩家”写入 NPC 记忆文本。
- `tools/verify_npc_short_term_memory_container.gd` 增加给钱与攻击事件 summary 检查，确保包含“守备官”、不包含“玩家”，且 actor id 为 `guard_officer`。
- 更新设计源、NPC、记忆、Prompt、数据结构、GM、模块索引、当前状态和任务文档中的称呼规则。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

未做：
- 未重命名现有 `record_player_interaction(...)` / `npc_attacked_by_player` 等开发接口和事件类型，避免破坏当前任务、验证脚本和后续模块引用；世界内文本已统一为“守备官”。

### T0206 将公告牌移出建筑数据结构
完成：
- 从 `data/building_defs.json` 删除 `notice_board` 建筑定义，建筑定义数量由 16 调整为 15。
- 保留 `Main.tscn` 中主厅前 `NoticeBoard` 视觉占位；它不再绑定 `BuildingSystem`，不拥有 HP、等级、工作位、修复或升级。
- 明确公告文本的权威状态仍由广场信息节点保存，公告变更继续生成 `plaza_notice_changed` 并广播给当前在广场的 NPC。
- 更新建筑、数据结构、记忆信息、Godot 架构、模块索引、当前状态、任务列表和设计源中的相关说明。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/building_defs.json` 合法，且不包含 `notice_board`。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。

未做：
- 未新增公告编辑 UI；现有 GM 广场公告入口继续作为验证入口。

### T0004 建立 GM 调试面板与验证工作流
完成：
- 新增 `scripts/ui/GMPanel.gd`，在 `Main/UI/GMPanel` 下提供可拖动半透明 `GM` 按钮、GM 面板窗口、命令输入框、执行结果区和分组调试按钮。
- GM 面板顶部 `GM_ENABLED` 常量可用 `true` / `false` 切换开发/上线显示。
- GM 面板当前覆盖资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等 M1-M4 已完成但前端不易直接验证的关键能力。
- 新增 `docs/GM_PANEL.md`，记录开关、分组、命令、维护规则和验证方式。
- 更新 `AGENTS.md`：每次任务完成时若新增功能无法直接在前端验证，必须给 GM 面板新增或替换调试入口，并同步更新 GM 文档。
- 新增 `tools/verify_gm_panel.gd`，覆盖 GM 面板加载、打开、资源命令、建筑受损、时间设置、NPC 地点进入、给钱事件、广场公告和结果输出。

验证：
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，清空旧日志后游戏日志无报错，截图可见 GM 按钮与面板。

未做：
- 未新增新的权威结算系统；GM 面板只调用已有系统接口或 `debug_*` 接口。
- 未实现真实对话、征召、战斗、昏迷/治疗/复苏或后端 LLM 调用。

### T0405 实现 NPC 短期记忆容器
完成：
- `MemorySystem` 新增 `get_npc_short_term_memory(...)` / `get_npc_short_term_memory_ids(...)`，将当天 `event_log` 与 `witness_log` 作为独立容器暴露给后续 LLM 输入。
- 新增 `record_player_interaction(...)`，玩家非对话交互会先进入目标 NPC 事件库，再按 `private` / `local_public` 可见性广播给事件地点当时在场 NPC；广场交互使用 `location_id == "plaza"`。
- 新增 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)`，用于验证给钱和攻击事件写入；本次不实现真实按钮、HP 扣除或昏迷。
- `NPCPanel` 新增事件库和见闻库最近摘要，监听 `npc_memory_changed` 自动刷新。
- 新增 `tools/verify_npc_short_term_memory_container.gd`，覆盖短期记忆容器、给钱/攻击交互、见闻广播和面板区分显示。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。

未做：
- 未做睡前总结、知识图谱更新、LLM 接入、真实交互 UI、真实攻击扣血或昏迷。

### T0404 实现广场公开信息即时广播
完成：
- `MemorySystem` 将广场事件统一为 `location_id == "plaza"` 的 `local_public`，当前在广场的 NPC 会把事件写入见闻库。
- 室外或不可进入实体来源的公开事件会规范化为 `location_id == "plaza"`，并在 payload 中保留 `source_location_id`。
- 广场快照明确没有自身建筑 HP，并提供主厅、围墙、城门、仓库 `key_entities`、当前在场 NPC 数和敌人数。
- 广场公告文本变更会生成 `plaza_notice_changed` 广场公开事件；关键目标受损、修复或升级会生成 `plaza_status_changed` 广场公开状态事件。
- `BuildingSystem` 在关键目标受损、修复或升级时通知 `MemorySystem` 进行广场状态广播。
- 新增 `tools/verify_plaza_local_public_broadcast.gd`，覆盖广场本地公开事件、公告、关键实体状态、广场快照字段和见闻库写入。
验证：
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
未做：
- 未实现战斗本体、昏迷/复苏系统、逃离行为、公告输入 UI 或 LLM 解读。

### T0403 实现地点信息节点与进入快照

完成：
- 在 `scripts/systems/MemorySystem.gd` 中建立可进入地点信息节点，覆盖广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊。
- 地点节点维护 `people_present`、当前公告/命令和进入快照；主厅、围墙、城门、仓库状态归入广场 `key_entities`。
- `NPCSystem` 到达地点时会更新旧地点/新地点在场人员，并把 `location_entered.payload.location_snapshot` 写入事件库。
- `local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库；地点节点不保存事件历史。
- `BuildingSystem.get_building_location_context(...)` 优先读取 `MemorySystem.get_location_snapshot(...)`，让 UI / NPC 状态使用同一套当前状态快照。
- 新增 `tools/verify_location_info_nodes.gd`，覆盖地点人数进出、进入快照、广场关键实体状态和本地公开事件见闻转发。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现完整广场公开信息规则、战斗公开事件、公告输入 UI、睡前总结或 LLM 记忆摘要。

## 2026-05-23

### T0402 架构适配检查

完成：
- 检查 T0403 前已完成代码是否仍隐含旧的“地点/建筑保存事件历史并供后来 NPC 继承”模型。
- `BuildingSystem.get_building_location_context(...)` 删除 `recent_events` 占位，改为 `current_public_note_ids` / `public_notes` 当前状态占位。
- 删除 `MemorySystem` 的按地点查询事件 API 与内部索引，避免继续暗示地点/建筑保存事件历史。
- `BuildingPanel` 和验证脚本中的旧措辞同步为“地点状态 / 结构化事件日志”。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0402 实现结构化事件底座

完成：
- `MemorySystem` 从最小 EventLog 占位升级为结构化事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询；地点/广场节点不作为事件历史存储。
- 结构化事件统一包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload`。
- 已预留 T0402 要求的事件类型，并为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 等实现确定性 summary 模板和必需 payload 字段声明。
- `ActionSystem` 工作/吃饭/睡觉/失败路径已迁移到结构化事件；`NPCSystem` 到达地点时写入 `location_entered`。
- `EventBus` 增加 `event_recorded`、`npc_memory_changed`、`location_info_changed` 信号。
- 新增 `tools/verify_structured_memory_events.gd`，覆盖结构化字段、NPC 事件库、全局索引、广场公开查询和 payload schema。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现地点/广场即时广播、知识图谱、日记、LLM 记忆摘要、对话或战斗。

## 2026-05-22

### T0401 暂停输入与暂停结算语义修正

完成：
- 确认 `SpeedButton` 只调用 `TimeSystem.cycle_speed()`，空格和 `PauseButton` 只调用 `TimeSystem.toggle_paused()`，空格不会改变 `x1` / `x2` / `x4` 速度倍率。
- `ActionSystem` 监听 `gameplay_pause_changed`；暂停期间已到位行动只保留 pending，不执行资源消耗/产出、饱食/疲劳变化或 EventLog 结算，恢复后再结算。
- `game_design.md` 补充暂停设计：暂停停止逻辑时间、NPC 移动、战斗和资源/状态结算，但不冻结 UI、后端请求或 LLM 对话/判定等待。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖空格不改速度、NPC 暂停移动、暂停期间行动不结算且恢复后结算。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志无报错。

未做：
- 当前仍未实现真实 LLM 对话、NPC-NPC 对话、战斗系统或真实时间驱动生产；本次只补齐暂停底层语义和已接入行动结算的暂停保护。

## 2026-05-21

### T0401 逻辑时间倍率与 LLM 等待减速架构

完成：
- `TimeSystem` 增加 LLM 等待减速请求接口：`request_time_slowdown(...)`、`release_time_slowdown(...)`、`clear_time_slowdowns()`。
- 新增有效逻辑倍率读取接口：`get_effective_time_scale()`、`get_numeric_delta_multiplier()`、`get_game_delta_seconds(...)`。
- `EventBus` 新增 `time_scale_changed(...)` 与 `logical_time_tick(...)`，当时用于后续资源、计划和战斗数值按逻辑时间倍率结算；2026-06-17 的 T1104A 已修正该设计，战斗数值不再读取玩家 `x2` / `x4` 作为额外倍率，只受暂停、敌人在场 `x1` 上限和 LLM 慢速影响全局推进节奏。
- 默认 LLM 等待倍率为 `1/60`，即默认速度下现实 1 秒 = 游戏 1 秒；该机制不修改 `Engine.time_scale`，不改变 NPC 移动或动画速度。
- 更新 `game_design.md`、架构、AI、经济、战斗、Prompt、API 预算和任务路线图中的相关说明。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖 LLM 等待减速、释放后恢复玩家倍率和数值倍率接口。
- `godot --headless --path . --quit-after 1` 通过。
- `verify_action_system_basic.gd`、`verify_npc_panel_state.gd` 回归通过。

未做：
- 未将真实 LLMBridge、资源产出、计划调度或战斗数值实际接入逻辑倍率；已在后续任务中补充要求。

### T0401 秒级时间显示与控制修正

完成：
- `GameState` 增加 `current_minute` / `current_second`，`TimeSystem` 改为按游戏秒推进并写回 `HH:MM:SS`。
- `EventBus` 增加 `time_changed(day, hour, minute, second)`，HUD 使用该信号连续刷新时间显示。
- `HUD` 的 `SpeedButton` 改为只循环 `x1` / `x2` / `x4` 流速。
- `Main/UI/HUD` 新增 `PauseButton`，用于暂停/继续；空格键绑定到同一暂停/继续逻辑。
- `tools/verify_time_system.gd` 补充秒级流逝、速度按钮、暂停按钮和空格暂停验证。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现每日计划、战斗倒计时或 LLM 时间减速。

### T0401 实现 TimeSystem

完成：
- 在 `scripts/systems/TimeSystem.gd` 中实现基础时间推进：一天 24 小时，默认现实 1 秒 = 游戏内 1 分钟，每 60 游戏分钟推进 1 小时。
- 增加暂停与 `x1` / `x2` / `x4` 加速切换接口，并将 `HUD` 的时间按钮接到 `TimeSystem.cycle_speed()`。
- 在 `EventBus.gd` 中补充 `day_started(day)`；`GameState.set_time(...)` 会在跨天时发出 `day_started`，并继续发出 `hour_started(day, hour)`。
- `HUD.gd` 监听 `hour_started` / `day_started` 刷新天数、小时和阶段文本。
- 新增 `tools/verify_time_system.gd`，覆盖时间推进、暂停、加速、跨天信号和 HUD 刷新。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_action_system_basic.gd` 回归通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 时间减速、每日计划或战斗倒计时。

### NPC 面板属性显示修正

完成：
- `NPCPanel` 新增属性行，显示 `stats.strength` / 力量和 `stats.intelligence` / 智力。
- 面板显示顺序调整为：姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度、武器熟练度。
- `tools/verify_npc_panel_state.gd` 增加属性文本与 HP/属性/专长顺序验证。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- Godot MCP 本次连接失败：`ECONNREFUSED 127.0.0.1:8765`，未作为本次验证项。

### T0305 资源消耗与生产对齐修正

完成：
- 修正 `ActionSystem._execute_work(...)`：无 `output_resources` 的工作现在也会正确结算饱食/疲劳、写入 EventLog 并返回成功。
- `BuildingSystem` 新增 `restore_building_hp(...)`，支持工作行动恢复建筑 HP。
- `data/action_defs.json` 按 `game_design.md` 补齐酒窖酿酒、铁匠铺制造武器/盔甲、工械坊制造工程器械、马厩产出马匹整备占位，以及围墙修补恢复 HP。
- `data/resource_defs.json` 新增酒、武器、盔甲、工程器械、马匹整备派生资源。
- 扩展 `tools/verify_action_system_basic.gd`，覆盖派生资源生产、无普通产出工作和围墙修补 HP 变化。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/resource_defs.json` 和 `data/action_defs.json` 合法。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 派生资源仍是库存占位，不实现装备分配、器械部署、马匹实体、出售酒或复杂熟练度效率。

### T0305 实现简单行动系统

完成：
- `ActionSystem` 接入 `data/action_defs.json`，提供调试指派工作、吃饭、睡觉和指定行动的接口。
- 行动指派会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑；2026-05-25 起，到达后进入持续行动并随逻辑时间结算。
- 菜园工作产出粮食，食堂工作消耗粮食产出餐食；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。2026-05-25 起，吃饭和睡觉恢复/消耗按持续时间逐步发生。
- `MemorySystem` 新增最小 EventLog 占位，行动成功或失败会记录事件。
- `data/resource_defs.json` 新增餐食资源，`data/action_defs.json` 扩展工作 / 吃饭 / 睡觉行动配置。
- 新增 `tools/verify_action_system_basic.gd` 验证最小行动闭环。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 日程、训练、战斗、工作位占用或复杂职业产出。

### 熟练度架构修正

完成：
- 按 `game_design.md` 8.4 固定 NPC 熟练度全集：职业熟练度 `养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`；武器熟练度 `剑盾`、`长杆`、`弓`、`弩`、`骑术`。
- `data/npc_profiles.json` 中每名 NPC 均补齐 13 个熟练度维度，并移除 `搬运`、`草药`、`护甲制作`、`指挥`、`祈祷`、`劝解`、`木工` 等非设计源技能。
- `NPCSystem` 新增固定熟练度枚举、`normalize_skills(...)` 和 `get_npc_specialties(...)`，职业倾向由高熟练度推导，不再依赖硬职业字段。
- `NPCPanel` 改为显示“专长”，并分组显示职业熟练度与武器熟练度。
- 新增 `tools/verify_npc_skill_schema.gd` 验证每名 NPC 的技能全集。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 合法，且每名 NPC 刚好 13 个固定熟练度。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_skill_schema.gd` 通过。

### NPC 主界面标签与短名修正

完成：
- 将 `data/npc_profiles.json` 中 8 名 NPC 的显示名改为短名：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文。
- 简化 `NPC.gd` 头顶标签，主场景只显示姓名、HP 和当前行动。
- 职业、是否入伍等详细信息仍保留在 `NPCPanel` 中显示。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_npc_movement_location.gd` 均通过。

### T0304 实现基础移动与地点进入

完成：
- `BuildingSystem` 新增 `get_building_entry_position(...)`，为 NPC 移动提供建筑入口目标点。
- `BuildingSystem` 新增 `get_building_location_context(...)`，返回地点信息读取占位。
- `NPC.gd` 新增 `move_to_location(...)` 和 `movement_arrived`，支持简单直线移动。
- `NPCSystem` 新增 `move_npc_to_building(...)`、`debug_move_npc_to_building(...)` 和 `debug_move_selected_npc_to_building(...)`。
- NPC 到达建筑后写回 `current_location`、`current_location_name`、`location_context`，并发出 `npc_state_changed`。
- 新增 `tools/verify_npc_movement_location.gd`，覆盖调试移动到食堂、宿舍、仓库和地点状态更新。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- 通过 Godot MCP 打开并运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂避障、真实日程计划、工作/吃饭/睡觉行动结算、对话、征召、战斗或 LLM。

## 2026-05-20

### T0303 实现 NPC 基础状态与 NPC 面板

完成：
- 新增 `scripts/ui/NPCPanel.gd` 并接入 `Main/UI/NPCPanel`。
- NPC 面板当时显示姓名、职业、HP、饱食度、疲劳度、金钱、昏迷、入伍、当前行动和技能熟练度；2026-05-21 已改为显示由固定熟练度推导的专长。
- `EventBus` 新增 `npc_state_changed(npc_id)`。
- `NPCSystem` 新增 `get_npc_state(...)`、`update_npc_state(...)`、`set_npc_state_value(...)`，状态变化后会刷新 NPC 标签并通知 UI。
- `NPC.gd` 头顶调试标签在当时补充了入伍状态、昏迷和 HP 摘要；2026-05-21 已按主界面降噪要求改为短姓名、HP 和当前行动。
- `BuildingPanel` 与 `NPCPanel` 支持点击对象互斥切换。
- 新增 `tools/verify_npc_panel_state.gd` 覆盖面板打开、状态刷新、面板切换和关闭。

验证：
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

未做：
- 未实现 NPC 状态自然变化、治疗、对话、移动、征召或战斗。

## 2026-05-18

### 初始化文档结构

完成：

- 创建项目管理文档种子。
- 创建 `AGENTS.md` 协作规则。
- 创建核心模块文档。
- 明确文档回写流程。

影响文件：

- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- 其他模块文档

待办：

- 初始化 Godot 项目。
- 初始化后端目录。
- 将现有完整策划案放入 `game_design.md`。

## 2026-05-19

### T0002 初始化后端目录

完成：
- 创建 Flask 后端入口 `backend/app.py`。
- 实现 `GET /health`，返回 `{"ok": true, "service": "war-not-mine-backend"}`。
- 确认 `backend/requirements.txt` 包含 `flask`、`python-dotenv`、`pydantic`、`requests`。
- 新增 `backend/.env.example` 作为本地配置模板；真实 API Key 不写入仓库。
- 创建 `backend/schemas/`、`backend/services/`、`backend/data/`，并使用 `.gitkeep` 保留空目录。
- 新增最小 `backend/services/model_adapter.py`，作为后续 LLM 供应商隔离边界。
- 更新 `.gitignore`，忽略 `backend/.env`。

验证：
- `python -m compileall backend` 通过。
- 安装 `backend/requirements.txt` 后，通过 Flask test client 验证 `GET /health` 返回 HTTP 200 和 `{"ok": true, "service": "war-not-mine-backend"}`。
- 启动 `python backend/app.py` 后，通过 `http://127.0.0.1:5000/health` 验证返回 `{"ok":true,"service":"war-not-mine-backend"}`。

未做：
- 未修改 Godot 场景。
- 未实现 NPC、战斗、资源或 AI 对话。

### T0001 初始化 Godot 项目结构

完成：
- 创建 `res://scenes/main/Main.tscn` 作为最小可运行主场景。
- 主场景包含 `WorldRoot/Station/Ground`、`Systems`、`UI/HUD`、`CameraRig/Camera3D` 和 `SunLight`。
- 补齐 Godot 目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 设置 `project.godot` 的 `run/main_scene` 为 `res://scenes/main/Main.tscn`。
- 通过 Godot MCP 运行主场景，游戏日志无报错，截图可见标题与基础地面。

影响文件：
- `project.godot`
- `scenes/main/Main.tscn`
- `scenes/**/.gitkeep`
- `scripts/**/.gitkeep`
- `ui/.gitkeep`
- `assets/.gitkeep`
- `data/.gitkeep`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- `docs/DEV_LOG.md`
- `docs/CHANGELOG.md`

未做：
- 未实现 NPC、战斗、建筑交互、资源系统、时间系统或后端。

### 稳定 Godot MCP 启动与自检
完成：
- 定位 Godot MCP 频繁断开的根因：同一个 `codex.exe` 下重复拉起 `godot-mcp` 实例，Godot 插件会用 “Replaced by new client” 替换旧连接。
- 修复 `tools/check_godot_mcp.ps1` 解析错误和乱码提示，改为可用的连接自检脚本。
- 将 Codex 全局 `godot-mcp` 启动命令改为 `node C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`。
- 新增 `godot-mcp-broker.mjs`，由单例 broker 负责唯一的 Godot WebSocket 连接；多个 Codex 会话只连接本机 proxy。
- 本机验证 broker 可正常健康检查，并能成功调用 `editor.get_state` 读取 Godot 编辑器状态。

换机补充：
- 新环境若仍配置为 `npx.cmd -y @satelliteoflove/godot-mcp`，切换 Codex 会话仍会重复直连 Godot `6550`，需要改为 `node %USERPROFILE%\.codex\scripts\godot-mcp-proxy.mjs`。
- Windows 下 broker 直接 `spawn("npx.cmd")` 可能报 `spawn EINVAL`；更稳妥的方式是直接启动 npm cache 中的 `@satelliteoflove/godot-mcp/dist/cli.js`。
- `tools/check_godot_mcp.ps1` 自检不要用 TCP 主动探测 Godot `6550`，裸 TCP 连接会被 Godot MCP 插件当作新客户端并顶掉 broker；只检查监听状态，真实验证走 proxy 调用 `editor.get_state`。
- 修复后应只看到 broker 与其唯一 `godot-mcp` 子进程，Godot `6550` 只有 1 条有效客户端连接；本机 broker 默认监听 `127.0.0.1:6551`。

影响文件：
- `tools/check_godot_mcp.ps1`
- `C:\Users\JT\.codex\config.toml`
- `C:\Users\JT\.codex\scripts\godot-mcp-broker.mjs`
- `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`

### T0101 建立核心 Autoload 与系统骨架

完成：
- 新增 `scripts/core/EventBus.gd`，声明资源、时间、建筑点击、NPC 点击和公开事件基础信号。
- 新增 `scripts/core/GameState.gd`，保存当前天数、小时和战斗状态。
- 新增 `scripts/core/ConfigLoader.gd`，提供 JSON 配置读取入口，并在文件缺失或解析失败时给出明确错误。
- 在 `project.godot` 中注册 `EventBus`、`GameState`、`ConfigLoader` Autoload，保留既有 `MCPGameBridge`。
- 新增 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`MemorySystem.gd` 空系统脚本占位。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 清空旧日志后再次运行，游戏日志无报错。

未做：
- 未实现 NPC、建筑点击、资源变化、时间推进、后端连接或战斗逻辑。

### T0102 扩展 Main 场景节点结构

完成：
- 将 `res://scenes/main/Main.tscn` 整理为 `WorldRoot/Station`、`Systems`、`UI`、`CameraRig` 的标准结构。
- 在 `WorldRoot/Station` 下保留 `Ground`，并补齐 `Buildings`、`NPCs`、`Enemies`、`Props` 容器。
- 在 `Systems` 下补齐 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem`、`CombatSystem`、`DialogSystem`。
- 新增 `ActionSystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 空系统脚本占位，并绑定到 Main 场景。
- 在 `UI` 下保留 `HUD/TitleLabel`，并新增隐藏占位 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认当前 HUD 标题与基础地面仍可见。

未做：
- 未实现点击逻辑、NPC、资源数值、战斗或对话 UI。

### T0103 创建低模驿站 Blockout

完成：
- 在 `res://scenes/main/Main.tscn` 中扩展低模驿站空间占位。
- 在 `WorldRoot/Station/Buildings` 下新增主厅、宿舍、食堂、仓库、围墙、城门、后门等几何体占位。
- 在 `WorldRoot/Station/Props` 下新增广场、正门道路、后门道路和商人入口占位。
- 补齐酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌视觉占位等 T0103 要求的剩余占位区域。
- 为 P0 占位区域添加 `Label3D` 调试标签，便于后续建筑系统和导航接入。
- 扩大地面尺寸并调整俯视相机，让启动后可看到完整驿站布局。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 标题、完整低模驿站和调试标签可见。

追加调整：
- 根据反馈扩大地面和围墙范围，并重新拉开建筑间距。
- 将建筑更明显地分散到中央广场、生活区、生产区、防务区和后门入口周边。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认拥挤感降低。

反馈修正：
- 补齐围墙四角闭合，让驿站院墙更像完整防御边界。
- 将公告牌缩小并移动到主厅正面，符合公共信息挂在主厅前的设想。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现建筑数据、建筑点击、生产、NPC、导航或战斗逻辑。

### T0104 建立 HUD 基础界面

完成：
- 在 `res://scenes/main/Main.tscn` 的 `Main/UI/HUD` 下补齐标题、天数、小时/阶段、资源占位、加速按钮、警铃按钮和后端状态占位。
- 新增 `res://scripts/ui/HUD.gd`，从 `GameState` 读取当前天数和小时，并根据小时显示清晨/白昼/黄昏/夜间阶段。
- 资源显示保持占位值 `--`，后端状态固定为未连接占位；加速和警铃按钮不触发真实逻辑。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 可见，并且没有遮挡主要驿站视角。

未做：
- 未实现真实资源变化、时间推进、警铃逻辑、后端连接或对话 UI。

### T0201 创建基础数据文件

完成：
- 新增 `data/resource_defs.json`，包含第纳尔、粮食、木材、石料、铁五类基础资源的最小配置。
- 新增 `data/building_defs.json`，包含主厅建筑的最小配置。
- 新增 `data/action_defs.json`，包含修补围墙行动的最小配置。
- 新增 `data/weapon_defs.json`，包含早期武器最小配置；该旧占位武器已在 T0013 后移除，正式主武器只保留剑盾、长杆、弓和弩。
- 新增 `data/enemy_waves.json`，包含第一波敌人占位配置。
- 新增 `data/npc_profiles.json`，包含老兵副官占位档案。
- 更新 `DATA_SCHEMA.md`，补齐资源、武器、敌人波次 schema，并让已有示例与实际 JSON 字段一致。
- 更新 `MODULE_INDEX.md`，记录新增数据文件的用途、依赖和当前状态。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 6 个 JSON 文件格式合法，且均为非空数组。
- 通过临时 Godot 脚本调用 `ConfigLoader.load_data_file(...)` 读取 6 个文件，确认每个文件均返回数组数据。
- 通过 Godot MCP 自检确认连接正常。

未做：
- 未实现资源系统、建筑系统、NPC 生成、战斗波次生成或 LLM 接入。

### T0105 实现基础摄像机控制

完成：
- 新增 `res://scripts/camera/CameraRig.gd`，绑定到 `Main/CameraRig`。
- 支持 WASD 键盘平移、鼠标中键拖拽平移、鼠标滚轮缩放。
- 通过 X/Z 边界和缩放距离限制，避免摄像机离开驿站太远。
- 保留当前高机位俯视角，只移动 `CameraRig` 和调整 `Camera3D` 本地距离。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- Godot MCP 确认 `/root/Main/CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd`，并暴露平移、缩放和边界参数。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。

未做：
- 未实现角色控制、镜头旋转或自由第一人称视角。

### T0202 实现 ResourceSystem

完成：
- 在 `scripts/systems/ResourceSystem.gd` 中实现基础资源初始化和读写接口。
- 启动时通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取第纳尔、粮食、木材、石料、铁的初始值和下限。
- 提供 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`。
- 提供 `debug_add_resource(...)` 和 `debug_spend_resources(...)` 作为临时测试入口。
- 资源变化通过 `EventBus.resource_changed` 发出，`scripts/ui/HUD.gd` 监听信号并显示真实资源数值。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过临时测试场景验证：初始金钱 30；调试增加 5 后扣除 10 成功；粮食扣除 2 成功；超额扣除 9999 金钱失败且没有产生负数。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`。

未做：
- 未实现商人交易、建筑生产或工作产出。

### T0203 实现 BuildingSystem 与建筑实体

完成：
- 扩展 `data/building_defs.json`，当时覆盖 16 个建筑/门墙实体；2026-05-24 T0206 已将公告牌移出建筑定义，当前为 15 个建筑/门墙实体。
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑配置读取、基础状态保存、`get_building(...)` / `get_building_ids()` / `get_building_snapshot()` 查询接口。
- 通过 `scene_nodes` 将配置绑定到 `Main/WorldRoot/Station/Buildings` 下的低模节点。
- 为绑定建筑运行时创建 `Area3D/CollisionShape3D` 点击区，左键点击后发出 `EventBus.building_clicked(building_id)`。
- 将建筑调试标签更新为名称、等级和 HP，便于确认基础状态。

验证：
- `data/building_defs.json` 可被 PowerShell `ConvertFrom-Json` 解析；当时包含 16 条建筑定义，2026-05-24 T0206 后当前为 15 条。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认当时 `BuildingSystem` 加载 16 个建筑定义、主厅数据可查询、仓库可选中、主厅 ClickArea 已创建；2026-05-24 T0206 后公告牌不再加载为建筑。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- Godot MCP 查找确认运行时创建了 19 个 `ClickArea` 节点，覆盖多段围墙、城门和主要建筑。

未做：
- 未实现建筑面板、升级、修复、生产、敌人攻击或建筑 HP 扣除。

### T0204 实现建筑面板

完成：
- 新增 `scripts/ui/BuildingPanel.gd`，监听 `EventBus.building_clicked` 并从 `BuildingSystem` 读取建筑基础状态。
- 扩展 `Main/UI/BuildingPanel`，显示建筑名称、等级、HP / Max HP、工位状态和地点信息占位；工位展示后续已在 T0016 调整为按类型显示空闲数 / 总数与占用者。
- 修复、升级按钮保持禁用，仅作为后续 T0205 的 UI 占位。
- 面板右上角关闭按钮可隐藏面板；未知建筑或无建筑时面板保持隐藏。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认选择主厅会打开面板、切换仓库会刷新数据、关闭按钮会隐藏面板。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。

未做：
- 未实现建筑修复、升级、生产、储存/消耗展示或敌人攻击。

### T0204 建筑面板真实点击修正

完成：
- 修正点击建筑时不能显示面板的问题。
- 在 `scripts/ui/HUD.gd` 中让 HUD 根节点忽略鼠标，避免全屏 Control 背板拦截 3D 建筑点击。
- 在 `scripts/systems/BuildingSystem.gd` 中增加 `_unhandled_input` 射线拾取，从当前相机向鼠标位置投射并识别带有 `building_id` 的点击区。

验证：
- 使用临时 Godot 验证脚本模拟真实鼠标点击主厅，确认 `BuildingPanel` 打开且显示“主厅”。
- 使用 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

### T0205 建立建筑修复与升级占位逻辑

完成：
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑修复、升级、可用性检查和临时受损调试入口。
- 修复/升级统一通过 `ResourceSystem.spend_resources` 扣除石料；资源不足时不扣资源、不改变建筑状态。
- 在 `scripts/ui/BuildingPanel.gd` 中接通修复/升级按钮，并根据建筑 HP、等级、配置和资源状态自动启用或禁用。
- 在 `data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入 `repair` / `upgrade` 配置；围墙升级会提升等级、Max HP，并增加 1 个修复工作位。
- 新增 `tools/verify_building_repair_upgrade.gd`，覆盖 T0205 的最小验收路径。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过，项目加载无错误。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂升级树、美术变化、生产结算、敌人攻击或战斗系统联动。

## 2026-05-20

### T0301 完成 8 个初始 NPC 数据草案

完成：
- 将 `data/npc_profiles.json` 从老兵副官占位档案扩展为 8 名初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师。
- 每名 NPC 均补齐 `id`、`name`、`gender`、`appearance`、`background_story`、`personality`、`desires`、`fears`、`abilities`、`states`、`skills`、`recruited`、`equipment`、`plan`、`short_term_memory`、`knowledge_graph`、`diary` 等字段。
- 老兵副官 `veteran_deputy_01` 设为女性且 `recruited=true`；医生 `doctor_01` 设为女性；其他 NPC 初始 `recruited=false`。
- 更新 `AI_NPC_SYSTEM.md`、`DATA_SCHEMA.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md`、`TASKS.md` 和 `CHANGELOG.md`，让文档中的 NPC 列表与数据一致。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 格式合法。
- 确认 NPC 数量为 8，且只有老兵副官 `recruited=true`。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 NPC 场景、NPCSystem 生成、点击、移动、对话、征召或 LLM 接入。

### T0302 创建 NPC 场景与 NPCSystem

完成：
- 新增 `scenes/npc/NPC.tscn`，作为通用 NPC 低模占位场景。
- 新增 `scripts/npc/NPC.gd`，保存唯一 `npc_id`，显示 NPC 调试标签，并在点击时发出 `EventBus.npc_clicked`。
- 扩展 `scripts/systems/NPCSystem.gd`，启动时读取 `data/npc_profiles.json` 并在 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC。
- 提供 `get_npc(...)`、`get_npc_ids()`、`get_npc_count()` 和 `debug_select_npc(...)`，便于后续面板和验证脚本接入。
- 新增 `tools/verify_npc_generation_click.gd`，验证 NPC 生成数量和点击事件。

验证：
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。
- Godot MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC `Area3D` 节点。

未做：
- 未实现 NPC 移动、状态面板、行动计划、对话、征召、战斗或 LLM 接入。

备注：
- 本次排查到一次 MCP 断连原因：Godot 插件仍在 `127.0.0.1:6550` 监听，但 `godot-mcp-broker.mjs` 未在 `127.0.0.1:8765` 监听，只剩 proxy 进程。手动启动 broker 后恢复，`tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
