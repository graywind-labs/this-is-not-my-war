# GODOT_ARCHITECTURE.md

## T0061 人设构造与知识弹窗职责

- `data/npc_profiles.json`、`NPCPromptProfile.FIELD_DEFINITIONS / build_setting(...)` 和 `LLMBridge._build_npc_context(...)` 已移除 `signature_lines`。对话 `npc_setting`、共享 `NPCIdentity` 与 NPCPanel【背景】继续共用同一构造器，只读取宽松 `speech_style`，没有第二套 UI 或 Prompt 档案。
- `NPCSystem.gd` 仍完整装载三篇 8 字段历史日记和 `key_value_replace_v1` 图谱。前两篇的新叙事层级、固定到站顺序、守备官唯一职责关系及建筑叙事化 `value_label` 都是数据内容合同，不在 GDScript 写死。
- `NPCPanel._format_knowledge_graph_block(...)` 只把 `subject_label / relation_label / value_label` 组装成玩家可读文本，不再追加 `confidence / day / time`。该过滤只作用于【知识】弹窗；NPCSystem 运行态、DailyReflectionSystem 替换更新、LLMBridge 请求和 GM 原始调试继续保留完整记录。
- 本任务没有新增场景节点、Autoload、endpoint、`call_type`、调用频率或权威结算。现有 Main 前端可通过 NPCPanel 的【日记】【知识】【背景】直接验收，无需新增 GM 入口。

## T0060 文案与投影层职责

- `NPCSystem.gd` 继续保存完整 8 字段日记并装载 8 人档案 / 初始图谱；本任务没有改变实体、状态或记忆应用逻辑。
- `LLMBridge._build_existing_diary_entries(...)` 仍是日记文本的唯一投影点：开局种子为“往昔·…：正文”，运行后记录为“第N天 HH:MM:SS：正文”，并兼容旧纯字符串及缺元数据记录。
- 六份 Prompt 负责解释前缀先后、“往昔·近日”处于敌情传达前，以及首次睡眠反思只输出正文；Prompt 不生成权威日期、时间或事件。
- 本任务没有新增场景节点、Autoload、后端 Schema、endpoint、`call_type` 或权威结算系统。T0061 已取代其中“开放的守备官认识”和固定台词样例口径：当前为唯一职责知识与宽松 `speech_style`。

## T0059 初始长期记忆运行时职责

- `NPCSystem.gd` 同时读取 `npc_profiles.json` 与 `npc_initial_long_memory.json`；在创建任何 NPC 实体前验证 id 集合和最小结构，再把日记 / 图谱深拷贝到 profile 运行态。它不在 GDScript 写死人设或建筑认识。
- `LLMBridge.gd` 只投影已加载的运行态记忆：对话使用顶层 `long_memory`，其余共享 NPCContext 使用 `long_term_memory`。对话 participant 可省略私人长期记忆，避免 target 重复和 speaker 泄露。
- `DailyReflectionSystem.gd` 沿用现有“追加日记 + 替换知识键”应用路径；初始记录只改变基线条数，不新增反思触发或模型调用。
- `NPCPanel.gd` 与 `GMPanel.gd` 不新增事实源：主场景“日记 / 知识”弹窗和既有 `long_memory <npc_id>` 命令从开局即可读取种子；T0061 后 NPCPanel 隐藏知识可信度 / 更新时间，GM 仍可观察完整原始记录，两者都不自行写记忆。
- 本任务不新增场景节点、Autoload 或权威结算系统。专项 `verify_npc_initial_long_memory.gd` 负责 8 人装载、15 建筑 / 7 人 / 守备官覆盖、中文 UI 和六类 payload；既有反思 / GM 测试改用“初始条数 + 新增条数”断言。

## T0058 公开资源投影与升级行动提示职责

- `LLMBridge.gd` 每次构造 `station_context` 时只从 ResourceSystem 投影 `grain / meal / wood / stone / iron`，同时让计划类兼容字段 `current_resource_states` 使用同一白名单；不得传递全量库存快照。
- `data/station_context.json` 保存第六条升级常识；它不保存当前资源数、升级目标或进度。当前资源来自 ResourceSystem，当前可协助目标来自 `_build_allowed_action_candidates(...)` 对 BuildingSystem 活动作业的查询。
- `assist_upgrade` 在技术合同中保持英文 `action_id / action_kind`，`data/action_defs.json` 和候选 `name` 提供中文玩家 / 模型可读名称。BuildingSystem / ActionSystem 继续拥有倒计时与加速权威。
- `GMPanel.gd` 的既有 `station_context` 入口增加公开基础资源一行，只读同一 LLMBridge 快照，不缓存或编辑资源。

## T0057 升级封闭的行动生命周期职责

- `BuildingSystem.gd` 仍只负责升级作业、资源预付、封闭状态和 `building_state_changed`；它不直接写 NPC 行动失败或调用计划系统。
- `ActionSystem.gd` 在建筑变为不可访问时识别目标建筑对应的 pending / active 行动，先停止移动 / 活动并释放位置，再写唯一最终 `*_failed_building_upgrading`。上下文记录行动、建筑、阶段、升级原因和中文摘要；单纯停留 / 普通移动只做清退或停止，不伪造行动失败。
- `DailyPlanSystem.gd` 把 `building_upgrading / building_unavailable` 规范为现有 Schema 支持的 `target_unavailable`，并沿用 T0050 的行动失败判别与按需精确修订；不新增第二套升级专用重估。
- `tools/verify_building_upgrade_action_failure.gd` 使用可控 fake provider 覆盖路上 pending 与进行中 active 两条链路，并证明非空判别继续进入第二层修订。

## T0054 驿站常识运行时职责

- `LLMBridge.gd` 是 `station_context` 的唯一运行时组装者：读取 `data/station_context.json` 的简介 / 规则，从 NPCSystem 构造当前在站人员，从 BuildingSystem 构造全部建筑，从 ActionSystem 构造工作模式行为类型。
- 建筑目录描述配置中的建筑身份，不随 HP 删除；当前可用性由各业务 payload 的建筑状态和 BuildingSystem 校验决定。广场 / 公告牌没有 BuildingSystem 定义，因此不会进入目录。
- 行为目录只收录 `plan_selectable=true` 的 ActionSystem 定义并补入系统特殊 `escaping_station`；`talk_to_guard_officer`、`escape_intervention_dialogue` 等纯运行态入口不进入。动态目标、位置、资格和资源约束继续由 `_build_allowed_action_candidates(...)` 生成。
- `debug_build_station_context()` 只返回同一组装结果。GMPanel 的按钮 / 命令只格式化显示，不缓存、不编辑、不修改 NPC、建筑、行动或战斗状态。

## T0053 跨小时等待失效职责

- `DailyPlanSystem._assign_plan_item(...)` 是日计划对话来源元数据的唯一写入者，将日 / 小时 / 版本 / 原计划项传给 `ActionSystem.assign_npc_dialogue(...)`；GM 和其他调用者保持无来源元数据。
- `ActionSystem` 在逻辑 tick、计划结束后的邀请重试和 `DailyPlanSystem._on_hour_started(...)` 新行动派发前，校验 pending 对话是否仍匹配说话者当前 `talk_to_npc + target`。失配时负责停止接近、释放双方 reservation 并写完整 `talk_to_npc_failed_plan_superseded`；不直接调用 LLM。
- `DailyPlanSystem._on_npc_state_changed(...)` 从 `last_action_failure_context.failed_plan_item` 恢复真正失败的旧对话计划项，启动通用判别；没有该字段的旧失败继续使用当前项。`LLMBridge` 负责在判别、日计划、正式修订和战时心理 payload 中复用同一 NPCContext / station_context 构造器。

## T0052 计划中对话职责

- `NPCSystem.gd`：持有并规范化 `llm_activity`，公开计划活动只读查询；不把计划活动误并入深睡 / 战时的立即失败标记。
- `NPCPanel.gd`：只负责禁用样式和提示，不自行取消请求或创建等待动作。
- `DialogSystem.gd`：守备官对话权威入口拒绝计划中目标；自主邀请在目标计划竞态下返回 `npc_planning`，不取消参与者计划。
- `ActionSystem.gd`：拥有 NPC-NPC 接近、pending options 和双方预约；目标计划结束后从状态信号延迟重试，启动成功前不释放所有权。
- `LLMBridge.gd`：继续用同一 `kind=plan` 覆盖日计划、修改判别和修订；本任务不修改请求 Schema、Prompt 或模型响应应用权威。

## T0051 弹窗拖动与会话节点职责

- `scripts/ui/DraggablePanel.gd`：无权威状态的通用拖动控制器；绑定窗口和顶部 handle，负责解除布局锚点、保留用户位置和视口夹取。
- `DialogPanel.gd`：展示完成 / 取消 / 挂起按钮、即时守备官消息、等待状态；监听同一个 `npc_dialogue_bubble_clicked`，优先恢复挂起玩家会话，再进入 NPC-NPC 旁听。
- `DialogSystem.gd`：唯一会话生命周期权威；保存 `ui_visible/suspended/suspended_remaining_seconds`，监听 `logical_time_tick`，完成时提交整场事件，取消时丢弃暂存结果。
- `NPC.gd`：复用既有会话气泡 Area3D 的点击路由；挂起玩家会话显示橙色 `↩`，自主 NPC-NPC 显示浅色 `...`。
- `NPCPanel.gd`：只查询 DialogSystem 显示橙点和恢复入口，不自行结束会话或结算超时。

## T0047 BuildingPanel 有界测量与输入隔离

- `BuildingPanel.gd` 不再直接 `await content.sort_children`。容器没有新增排序时该信号可能不再发出，旧协程会把面板永久留在 `visible=true / alpha=0 / height=1`；现在 `_await_stable_content_layout(...)` 每个测量阶段最多跨 4 帧采样，并在每帧复验 `_panel_fit_generation`，过期协程不会揭示旧内容。
- 新建筑进入透明测量前设置 `mouse_behavior_recursive=MOUSE_BEHAVIOR_DISABLED`，使面板及全部动态子控件都按 `MOUSE_FILTER_IGNORE` 处理；`_finish_panel_fit()` 完成高度、透明度和 fit 标记收尾后才恢复继承交互。关闭、切换 NPC、空或非法建筑同样关闭交互。
- 修复 / 升级按钮处理函数增加可交互状态守卫，透明、隐藏或尚未完成 fit 的面板不能进入 BuildingSystem 权威接口。`verify_building_panel_real_click.gd` 通过真实 Viewport 输入覆盖全部 15 个建筑 ID，并校验选择前后建筑与资源状态不变。

## T0046 运行时职责

- `LLMBridge.gd` 从 NPCSystem 当前运行态构建唯一顶层 `station_context`，并在 NPC 逃离 / 离站后即时将其移出名单；T0054 已由同一构造器补齐建筑、工作行为与规则。
- `DailyReflectionSystem.gd` / `NPCSystem.gd` 只应用第一人称日记与替换式知识图谱；`NPCPanel.gd` 负责把知识主体、关系和值的技术内容显示为中文，不改写底层技术值，并在 T0061 后不向玩家显示 `confidence / day / time`。
- `MemorySystem.gd` 负责公告牌默认数据、广场当前通告 / 参考日程、时段校验、初始 NPC 见闻、在场广播和入场快照；`NoticeBoardPanel.gd` 只负责双 Tab 草稿、日程行交互与发布调用。

## T0045 BuildingPanel 测量与 CameraRig 输入生命周期

- BuildingPanel 不使用状态切换当帧可能过期的 `combined_minimum_size` 撑高面板。它按 building id 保留上一次稳定高度，在有上限的逐帧容器排版采样后再写入新高度；新目标测量期保持在布局树中但透明且递归禁用鼠标，避免隐藏 Control 无法排版及透明控件拦截世界点击的问题。
- CameraRig 在 `_input(...)` 内维护本窗口 WASD 状态，`_process(...)` 只消费这份状态，不调用 `Input.is_key_pressed(...)`。按键 release、文本输入焦点、`NOTIFICATION_APPLICATION_FOCUS_OUT` 和 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 会清空平移；失焦同时清除中键拖拽。

## T0044 当前计划恢复与对象面板布局边界

- `DialogSystem` 在玩家消息真正打断行动时保存该运行时行动 ID，只在有效玩家对话、未重估且无攻击的结束分支调用 `DailyPlanSystem.resume_current_plan_after_player_dialogue(...)`；NPC 原本空闲时不调用。
- `DailyPlanSystem` 的专用恢复入口先要求被打断行动 ID 与当前小时计划行动一致，再仅移除目标 NPC 当前计划阶段的执行签名 / 计划行动标记，并调用既有 `execute_current_plan_for_npc(...)`；正常小时派发仍使用原签名去重。
- `NPCPanel` 改变宽度后保留当前合理高度，待容器完成换行布局再收敛到自然高度。BuildingPanel 的同建筑刷新保留该建筑已测得高度，新目标则透明排版后显示；两者都不在等待帧内暴露最大高度空面板。BuildingPanel 的操作提示作为 `Main/UI` 下的覆盖控件，不参与建筑面板最小尺寸计算。

## T0043A ActionSystem 服务依赖路由

`ActionSystem` 现在把 `work_clinic_doctor → receive_clinic_treatment`、`work_training_instructor → receive_weapon_training`、`lead_mass → attend_mass` 作为配置驱动的服务依赖。服务者在移动时，依赖者保持 pending；服务者有效占位后重试依赖者。服务者停止时统一扫描活动中和等待中的依赖者，写失败、释放位置、记录事件并交给 DailyPlanSystem 重评估。

`lead_mass` 开始后还会中断同教堂内 `pray_at_chapel`；`attend_mass` 使用祈祷席并保存 `provider_npc_id`，由对应主持正常完成或异常离岗统一收束。`get_runtime_action_snapshot()` 暴露依赖、互斥及主持者绑定，供 GM / 调试读取；BuildingSystem 仍只管理位置与建筑状态，不承接行为规则。

## T0041 对话行动参考职责

- `LLMBridge.gd`：`build_npc_dialogue_payload(...)` 与 `build_npc_daily_plan_payload(...)` 复用 `_build_allowed_action_candidates(npc_id, true)`，因此 `data/action_defs.json`、动态 NPC 目标、可进入地点和协助目标只有一条候选构造链路。
- `DialogSystem.gd`：玩家-NPC、NPC-NPC 邀请 / 正式回复、战时和逃离挽留继续只调用统一的 `request_npc_dialogue(_async)`；无需按场景手工拼行为列表。
- `tools/verify_dialogue_action_reference.gd`：对 7 个现有对话上下文逐项比较对话与日计划候选签名，防止后续新增行为只进入计划而漏进对话。

## T0035-T0038 制造与马匹节点（当前实现）

- `Main/Systems/CraftingSystem`（`res://scripts/systems/CraftingSystem.gd`）读取 `data/crafting_recipes.json`，维护铁匠铺 / 工械坊建筑级项目；`ActionSystem` 在开工、周期推进、打断和周期完成时调用其权威接口。
- `Main/Systems/HorseSystem`（`res://scripts/systems/HorseSystem.gd`）读取 `data/horse_defs.json`，监听逻辑时间和 NPC 状态；马厩工作只提供有效养马能力，个体进食 / 恢复 / 成长、照料额外 HP、累积繁育概率 / 产后冷却和分配均由该节点结算。
- `BuildingSystem` 已提供按 section 写入 / 读取 `special_state` 的接口；`MemorySystem` 只允许 `production` 与 `horses` 的固定 NPC 可见字段，并只在对应室内形成快照 / 差量。
- `BuildingPanel` 已提供制造目标、材料 / 阶段 / 总进度、换目标确认和限高马匹滚动列表；`NPCPanel` 已提供具体装备与具体马匹分配区；HUD / 围墙 / EquipmentSystem 已改读具体库存。UI 不持有项目或马匹权威状态。
- `EquipmentSystem.equipment.mount` 只保留带 `horse_id` 的战斗兼容快照；HorseSystem 才是马匹实体、分配、在厩 / 骑乘位置的唯一事实源。
- 制造小数进度与马匹个体变化使用独立 UI 刷新信号，不用 `building_state_changed` 高频制造 NPC 见闻；只有目标 / 整数阶段或在厩数量发生语义变化时写建筑内部特殊状态。

`CraftingSystem` 必须位于 `ActionSystem` 前；`HorseSystem` 位于 `NPCSystem` 后、`ActionSystem` 前，使同一个逻辑时间片已经完成的 `work_stable` 周期可以作为当前有效养马照料输入。专项验证见 `verify_crafting_pipeline.gd`、`verify_horse_ecology_assignment.gd`、`verify_horse_care_feedback.gd`、`verify_equipment_system.gd`、`verify_defense_device_deployment.gd` 与 `verify_hud_resources.gd`。

## T0032 气泡真实鼠标拾取路由

- `NPC.gd`：`AutonomousDialogueBubble` 在可见期间保存 `interaction_kind=autonomous_dialogue_bubble`、参与 NPC id 与当前 `dialogue_id`，继续保留自身 Area3D 点击回调作为直接拾取路径。
- `NPCSystem.gd`：全局 `_unhandled_input` 射线改为返回结构化世界交互。命中气泡时直接广播 `npc_dialogue_bubble_clicked` 并消费输入；命中普通 NPC 本体时才调用原 `_select_npc(...)`，避免子气泡沿父节点被误判为 NPC 面板点击。
- `tools/verify_npc_npc_dialogue_observer_ui.gd`：通过 Camera3D 投影气泡 / NPC 本体的世界坐标，并向 Viewport 推送真实鼠标事件，覆盖双方气泡、关闭后重开、面板互斥与 NPC 本体点击回归。

## T0031 初始故事装备与旁听重开边界

- `data/npc_profiles.json`：用 `initial_equipment` 保存 NPC 开局故事装备的正式定义引用；当前艾达的 `main_weapon` 引用 `sword_shield`。
- `EquipmentSystem.gd`：完成武器 / 盔甲 / 坐骑定义加载后，把尚未占用的初始装备槽装载为完整运行时装备；该路径不调用资源扣除或玩家交互事件入口，后续换装仍走正式库存结算。
- `DialogPanel.gd`：旁听窗口关闭只清理本地显示；会话仍在运行时，气泡点击会按同一 `dialogue_id` 重新读取最新观察快照。结束信号更新并冻结最终文本，不自动隐藏窗口。
- `tools/verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_combat_pacing.gd` 与 `verify_npc_npc_dialogue_observer_ui.gd`：覆盖初始剑盾不扣库存 / 不写赠送事件、近战兵种 / 战斗节奏，以及旁听关闭后重开与结束后手动关闭。

## T0029/T0030 NPC-NPC 邀请与软轮次会话边界

- `ActionSystem.gd`：发起者抵达目标后先保留邀请中的会话预定，不立即打断目标当前行动或释放其工位。
- `DialogSystem.gd`：先用独立 `dialogue_phase=invitation` 请求目标接受 / 拒绝；拒绝即结束但双方仍分别进入计划修改判别，接受后才打断双方普通行动、显示气泡并进入无硬轮次上限的正式对话。任一方结束标记回复先写入历史 / 事件，再立即终止而不调下一轮，随后双方分别判别。
- `LLMBridge.gd`：把 `dialogue_phase`、`current_round`、`max_rounds=0`、软阈值和软性指导传给后端；邀请和每一轮正式回复都分别注册 / 释放 TimeSystem 慢速。
- 玩家-NPC 普通对话在 NPC 的有效 LLM 回复完成后自动登记计划修改判别，UI 不再提供强制重估开关。判别 `revision_hours=[]` 时不请求修订并按边界恢复原行动，非空时只修订所选小时。仅打开窗口或取消尚未完成的回复不判别。
- 所有双目标 NPC-NPC 会话在双方判别请求发出前预注册同一会话组派发屏障；等双方第一层 / 必要第二层全部终态后，`DailyPlanSystem` 才按计划依赖顺序放行。跨小时玩家对话也在目标 NPC 判别链终态前延迟新小时计划，避免对话 epoch 和新计划互相使响应过期。
- `tools/verify_dialogue_invitation_contract.gd`、`verify_npc_npc_dialogue_real.py`、对话计划判别专项与真实旁听专项覆盖邀请接受 / 拒绝、越过第 5 轮、软性收尾、单方结束不追加调用，以及双方独立判别与精确小时修订。

## T0028 自主对话气泡与旁听职责

- `DialogSystem.gd`：继续拥有唯一权威 NPC-NPC 会话，并提供按参与者 + `dialogue_id` 校验的只读观察快照；每轮 NPC 消息显式要求 TimeSystem 慢速。
- `NPC.gd`：根据匹配的自主会话状态为双方运行时创建 / 显示独立 `AutonomousDialogueBubble` 与点击区，只发出观察请求，不直接操作会话。
- `EventBus.gd`：用 `npc_dialogue_bubble_clicked(npc_id, dialogue_id)` 把 3D 气泡点击传到 UI。
- `DialogPanel.gd`：复用中央窗口呈现只读旁听模式；隐藏玩家操作，关闭时只清理 UI，进行中可再次点击气泡重开同一会话，自然结束后保留最终记录。
- `tools/verify_npc_npc_dialogue_observer_ui.gd`、`verify_npc_npc_dialogue_observer_real.gd`、`verify_llm_time_slowdown_audit.gd`：覆盖 fake provider 交互、真实 provider Godot 链路和连续逐轮慢速注册 / 释放。

## T0025 运行时职责

- `BuildingSystem.gd`：工位申请失败返回占用者 ID 与工位快照。
- `ActionSystem.gd`：执行 `talk_to_npc`、`visit_location`、`pray_at_chapel`，管理接近预定、移动、打断、工位释放、训练协作、治疗失败事件和目标运行态快照。
- `DailyPlanSystem.gd`：解析带目标计划项，按教官 / 普通 / 受训者 / 对话顺序派发当前项，以同一时段签名、计划版本、单后继队列和失败上限保护真实异步修订。
- `DialogSystem.gd`：维护唯一权威对话和可并存的只读玩家草稿，双重校验 NPC 回复身份 / 类型，驱动无硬轮次上限的真实 NPC-NPC 对话，并在实际会话结束后为参与者编排 T0049 计划修改判别。
- `LLMBridge.gd`：根据实时 NPC / 建筑 / 资源状态构造动态行动候选，并为即时修订过滤忙碌目标。
- `tools/verify_plan_action_catalog.gd`、`verify_plan_extended_actions.gd`、`verify_npc_npc_plan_action.gd`、`verify_npc_npc_dialogue_edges.gd`：覆盖目录、祈祷 / 拜访运行闭环、工位交涉和对话竞态。

## Godot 版本

目标版本：Godot 4.6

## 场景原则

- 场景负责表现和节点关系。
- 系统脚本负责逻辑。
- 数据来自 JSON 配置，不写死在场景中。
- 所有跨系统通信优先通过 EventBus 信号，不要互相硬引用。

## 推荐场景树

```text
Main
├─ WorldRoot
│  ├─ Station
│  │  ├─ Ground
│  │  ├─ Buildings
│  │  ├─ NPCs
│  │  ├─ Enemies
│  │  ├─ DefenseDevices
│  │  └─ Props
├─ Systems
│  ├─ TimeSystem
│  ├─ ResourceSystem
│  ├─ BuildingSystem
│  ├─ CraftingSystem
│  ├─ NPCSystem
│  ├─ HorseSystem
│  ├─ ActionSystem
│  ├─ MemorySystem
│  ├─ MerchantSystem
│  ├─ DefenseDeviceSystem
│  ├─ CombatSystem
│  ├─ EquipmentSystem
│  ├─ LLMBridge
│  ├─ DailyPlanSystem
│  ├─ GameStartupSystem
│  ├─ DailyReflectionSystem
│  ├─ UnconsciousSystem
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  ├─ NoticeBoardPanel
│  ├─ MerchantPanel
│  ├─ GMPanel
│  └─ DialogPanel
└─ CameraRig
```

## Autoload 建议

| 名称 | 路径 | 作用 |
|---|---|---|
| EventBus | `res://scripts/core/EventBus.gd` | 全局信号 |
| GameState | `res://scripts/core/GameState.gd` | 全局运行状态 |
| ConfigLoader | `res://scripts/core/ConfigLoader.gd` | 加载配置 |

## 当前 Autoload 实现

T0101 已在 `project.godot` 注册以下 Autoload：

| 名称 | 路径 | 当前状态 |
|---|---|---|
| MCPGameBridge | `res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd` | Godot MCP 运行桥接；2026-06-17 升级到 Godot MCP `4.0.1` 后继续直接预加载 `mcp_runtime_state_sampler.gd`，并显式预加载 `key_names.gd`、`joy_names.gd`、`mcp_exec_guard.gd`，避免 `.godot` 全局类缓存缺少 helper class 时启动失败 |
| EventBus | `res://scripts/core/EventBus.gd` | 已声明基础事件信号 |
| GameState | `res://scripts/core/GameState.gd` | 已保存天数、小时、战斗状态和胜负结算快照；T1305 后会补齐 NPC 结局总结字段 |
| ConfigLoader | `res://scripts/core/ConfigLoader.gd` | 已支持 JSON 读取和错误提示 |

T0102 已将 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 绑定到 Main 场景的 `Systems` 节点下；T0035/T0037 新增 `CraftingSystem.gd` 与 `HorseSystem.gd`，并按 `BuildingSystem -> CraftingSystem -> NPCSystem -> HorseSystem -> ActionSystem` 顺序绑定，使项目、NPC 和养马周期依赖初始化明确；T0604 新增 `LLMBridge.gd` 并绑定到 `Main/Systems/LLMBridge`，T0604A 已将其传输层替换为 Godot 原生 `HTTPClient`；T0901 新增 `EquipmentSystem.gd` 并绑定到 `Main/Systems/EquipmentSystem`；T1004 新增 `DailyReflectionSystem.gd` 并绑定到 `Main/Systems/DailyReflectionSystem`；T1507 新增 `MerchantSystem.gd` 并绑定到 `Main/Systems/MerchantSystem`；T1508 新增 `DefenseDeviceSystem.gd` 并绑定到 `Main/Systems/DefenseDeviceSystem`。T0401 已实现 `TimeSystem.gd` 的基础时间推进、秒级显示、暂停、加速、跨天、逻辑时间倍率、LLM 等待减速请求，以及 `time_changed` / `time_scale_changed` / `logical_time_tick` / `hour_started` / `day_started` 信号；T1104A 新增 TimeSystem 时间倍率上限请求，CombatSystem 可在敌人在场时注册 `combat_enemy_presence` 上限；T1406 后 `get_time_scale_snapshot()` 还会暴露 `last_time_scale_reason`。T0020 后，`LLMBridge` 会在对话、常规每日计划、计划修订、低血量心理判定和首次睡眠总结请求前按 payload 注册慢速，并在成功、失败、取消或超时后释放；正式开局的每日计划批次由 `GameStartupSystem` 直接暂停全局时间，8 份真实计划全部成功后才统一执行当前项并恢复时间；任一失败保持暂停且不生成 Mock / 规则计划，不为单个请求重复登记慢速。`debug_get_llm_runtime_snapshot()` 供 GM 查看当前等待中的 LLM 请求数、pending request id、NPC 活动请求、异步请求数量、有效逻辑倍率、最近倍率变化原因和逐请求慢速注册 / 释放审计。LLMBridge 只请求后端业务接口或开发期 mock 接口，不保存供应商 API Key；生产 / 演示路径真实 provider 失败或预算超限时应返回错误或规则 / 模板降级，不得让 Godot 收到 mock 内容伪装成功。T0202 已实现 `ResourceSystem.gd` 的基础资源读写和 HUD 同步；T0205 已实现 `BuildingSystem.gd` 的配置读取、低模建筑绑定、运行时点击区、`building_clicked` 选择事件、`building_state_changed` 状态刷新事件，以及倒计时修复/升级逻辑；T1506 后主厅公告牌可点击编辑当前广场公告并写入公开信息；T1507 后商队会在后门按日程出现，提供基础资源购买、酒类出售和结构化公开事件。T0304/T0409 已实现 `NPCSystem.gd` 从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体、发出 `npc_clicked`、读取/更新 NPC 基础状态、调试移动到建筑入口，并在到达后发出 `npc_state_changed`；室内信息地点切换到另一个室内信息地点时，事件和地点信息层会插入广场中转链。T0501/T0502/T0503 已实现 NPC HP 扣除、`npc_hp_changed`、`npc_unconscious`、昏迷阻断移动/行动、昏迷自然恢复、协助治疗、`npc_revived`、自动复苏和昏迷/治疗/复苏事件写入。T0808 已实现小诊所医生工位、病床治疗、研读医术和诊所等级治疗效率。T0901/T0036/T0038 已实现 `EquipmentSystem` 从装备定义读取主武器、盔甲和具体马匹投影，只消耗 / 返还同名具体成品库存；T0902 已独立验收只读兵种判定与 `get_unit_type_snapshot(...)`，坐骑判定只读取 `equipment.mount` 槽；T0903 已实现训练场教官工位、受训位、当前装备决定训练项、教官/受训者熟练度成长和训练状态消耗；T0904 已实现 `NPCSystem` 统一成长结构、经验达标获得未分配技能点，以及玩家分配技能点到力量 / 智力。T0402 已将 `MemorySystem.gd` 升级为事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场事件查询；T0403 已在 `MemorySystem.gd` 中实现可进入地点信息节点、`people_present` 维护、进入快照和 `local_public` 即时广播；T0404/T0408/T0409/T0035/T0037 已统一广场即时广播、公告变更广播、建筑可传播外部状态广播、建筑内部特殊状态白名单和对应室内进入快照 / 字段差量，且不会把制造小数进度或马匹个体详情泄露到广场；T0405 已提供 NPC 短期记忆容器查询和玩家非对话交互事件调试写入口，仍不提供按地点查询事件的长期接口，地点/建筑节点不作为事件历史存储。T1004/T1005 起，首次睡眠总结完成后只清空指定 NPC 的当天短期事件/见闻索引，保留全局事件档案。T0407 已提供记忆降噪规则：进入/离开事件只保留行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化只广播变化字段。`ActionSystem.gd` 的工作 / 训练 / 协助修复 / 协助升级 / 协助治疗 / 诊所治疗 / 吃饭 / 睡觉调试行动闭环已写入结构化事件；制造工作还会把完整周期提交为一个阶段，打断只清未完成周期。T1101 已让 `CombatSystem.gd` 读取 `data/enemy_waves.json`，并在 `Station/Enemies` 下生成正门外低模敌人占位；T1102 已让敌人按逻辑时间选择目标、移动并攻击 NPC / 建筑，主厅清零会写入 `GameState` 失败占位；T1103 已让 HUD / GM 警铃触发入伍持武器 NPC 前往城门外集结，按近战前排 / 远程后排排列，写入警铃与集结事件，并在接敌时切换 `combat_ready` 占位；T1103A 已统一 `behavior_mode`，接入集结超时、接敌入战、清敌退出和昏迷复苏分流；T1103B/T1103C 已实现非战斗人员（未入伍或已入伍但无主武器）避战触发、按敌方方位短步长四散移动、清敌退出、避战中应征 / 装备分流和 `avoidance_started` / `avoidance_ended` 事件；T1104 已实现 combat 模式入伍持武器 NPC 的基础自动攻击、属性 / 防御伤害、攻击间隔、敌人 HP 扣除和清零移除；T1104A 已取消战斗数值与玩家时间倍率绑定，并在活动敌人存在时把 TimeSystem 有效倍率上限设为 `x1`；T1104B 已把攻击冷却从游戏秒换算到战斗动作秒，并校准第一波基础节奏；T1104C 已从敌人目标偏好中移除围墙，敌人破城门后直接转向仓库 / 主厅；T1105 已接入不同兵种战斗策略、玩家手动策略选择、策略状态快照和策略移动目标；T1106 已接入战斗开始 / 结束广场公开事件、当前战斗运行态和受伤 / 昏迷 / 击退统计；T1201/T1202 已接入战时公开对话心理结果和低血量自身心理判定；T1203 已接入逃离驿站行为，逃离 NPC 会前往后门外出口，离图后标记 `escaped` 并写入广场公开事件；T1204A 已接入逃离挽留 NPC 面板入口、对话暂停逃离移动、未满 5 轮关闭恢复、满 5 轮按钮置灰、给钱减速、逃离攻击加速且无 NPC 回复、昏迷暂停和复苏继续逃离；T1302/T1303 已接入主厅摧毁和无可战斗人员失败结算，失败后广播 game-over 并暂停 TimeSystem；T1304 已接入第 5 波胜利结算，胜利后广播 game-over、暂停 TimeSystem、保存资源 / 建筑 / NPC 结算快照并阻止继续刷波；T1305 后 `GameState` 会为胜利和失败补齐 NPC 结局明细，HUD 结算页滚动显示每名 NPC 的最终状态、入伍状态、最后位置、Mock 最终看法和 Mock 后续命运。仍不实现命中率。

T0043 在上述系统绑定上补齐统一位置链路：`BuildingSystem` 保存逐位置状态、可用性、受损倍率与逐级升级效果；`NPCSystem` 在移动发起和到达时复验可进入性；`ActionSystem` 为吃饭、睡觉、祈祷 / 弥撒、诊疗和训练自动申请位置，并聚合全部在岗医生 / 教官贡献；`MemorySystem` 传播外部效率分档和室内位置增删 / 占用差量；`BuildingPanel` 逐位置只读显示。升级开始会封闭建筑、释放位置并将室内 NPC 送回广场。

T0022 覆盖上述 T0019 旧口径，也覆盖上一段保留的历史“明确规则降级后完成”表述：正式开局和新一天每日计划只有 8 份真实 `llm_plan_day` 全部成功才会执行并恢复时间。整批默认 8 路并发，单人最多 3 次真实请求；仍失败时保持暂停与 `planning_day`，不生成 Mock / 规则计划。

T0023 覆盖 T1002 的旧 Mock / 规则修订口径：正式计划修订只接受真实 provider，成功响应必须携带非 Mock provider 元数据并写为 `llm_plan_revision`；失败最多 3 次真实请求，保留原计划且不写 `plan_revised`。NPC 面板通过“当前计划”详情读取 DailyPlanSystem 权威计划；事件 / 见闻详情刷新保留当前滚动位置。行动失败是否进入该修订由后续 T0050 的第一层判别决定。

T0024 后，NPCPanel 在事件库上方使用“当前计划 / 日记 / 知识”三等分按钮，共用详情弹窗读取 DailyPlanSystem 计划与 NPCSystem 长期记忆，面板正文不再创建日记滚动框。DailyReflectionSystem 明确限制最多 8 路异步总结并暴露实际峰值；DailyPlanSystem 的正式开局 / `day_started` 批次同样记录实际并发峰值。后端五个正式 LLM 成功端点共用 provider 元数据封装，Godot 睡眠总结根据元数据选择 `llm_daily_reflection` 或显式开发 `mock_daily_reflection`，不再按调用位置硬编码来源。

T0049 覆盖上述“五类正式业务”和 T0048 剩余日重排口径：新增第六类计划修改判别，`LLMBridge` 为其提供 payload、异步请求、慢速注册 / 释放与结果信号。对话结束先返回精确 `revision_hours`，空数组不调用修订；非空数组才让 `DailyPlanSystem` 以 `revision_scope=selected_hours` 请求 `/npc/revise_plan`。事件 / 见闻详情首次打开滚到最底部，打开期间刷新保留当前位置。

T0050 将第六类统一命名为 `plan_revision_judgement`，请求通过 `trigger_kind=dialogue|action_failure` 区分本轮完整对话和程序权威行动失败事实，并统一发送到 `/npc/plan_revision_judgement`。日常行动失败不再默认直接修订当前小时：空判别保持原计划，非空才用原有完整第二层上下文精确修改选中小时；第一层等待和第二层修订都占用既有 NPC 计划屏障。旧 dialogue 命名的端点、Schema 和 LLMBridge 方法只保留兼容包装。

T1501 曾同时注入 `speech_style` 与 `signature_lines`；T0061 已取代该历史口径。`LLMBridge._build_npc_setting(...)` 和共享 `_build_npc_context(...)` 现在只从 `data/npc_profiles.json` 读取宽松 `speech_style`，分别注入对话顶层人设和 `NPCContext.identity`。该字段只影响模型语气与主观文本，不改变 NPC 状态、行动或任何权威结算。

T0042 后，`res://scripts/core/NPCPromptProfile.gd` 集中定义对话顶层 `npc_setting` 的字段集合和构造规则；`LLMBridge._build_npc_setting(...)` 委托该构造器，`NPCPanel` 的人物背景详情也读取同一结果。标题行新增的“背景”按钮只负责打开共用详情弹窗，UI 不保存第二份背景数据，不触发 LLM，也不写 NPC / 记忆权威状态。

T1508 修订后，`DefenseDeviceSystem.gd` 绑定到 `Main/Systems/DefenseDeviceSystem`，`DefenseDevicePresenter.gd` 绑定到 `Main/WorldRoot/Station/DefenseDevices`。前者权威维护器械配置、围墙槽位、库存扣除、弩床 / 箭塔自动攻击和事件，不依赖 NPCSystem；后者只消费部署快照并创建 `DefenseDeviceView.tscn`。每个 view 固定包含 `ModelMount`，可选 `presentation.model_scene` 在该挂点下实例化，为 T15 正式模型、动画和特效保留稳定替换契约。

## 逻辑时间倍率原则

TimeSystem 不修改 `Engine.time_scale`，也不直接改变 NPC 移动、动画或物理速度。玩家设置的 `x1` / `x2` / `x4` 是逻辑时间倍率；当 LLMBridge、DialogSystem、计划系统或战斗判定等待模型返回时，可以调用 `TimeSystem.request_time_slowdown(request_id, scale, reason)` 注册慢速请求，完成、失败或超时后调用 `release_time_slowdown(request_id)`。

当前默认 LLM 等待倍率为 `1/60`，即在默认 `x1` 速度下从“现实 1 秒 = 游戏 1 分钟”减缓为“现实 1 秒 = 游戏 1 秒”。多个慢速请求同时存在时，TimeSystem 使用最慢的有效倍率。T1104A 起，TimeSystem 还支持时间倍率上限请求：CombatSystem 在活动敌人存在时注册 `combat_enemy_presence`，把有效倍率上限压到 `x1`；若 LLM 慢速更低，则继续使用更慢者。工作 / 日常状态、资源、计划打点、治疗和建筑倒计时系统应读取 `get_numeric_delta_multiplier()`、`get_game_delta_seconds(real_delta)` 或监听 `logical_time_tick(game_delta_seconds, numeric_multiplier)`，而不是读取真实帧率或 Godot 全局时间缩放。战斗伤害、攻击间隔、攻击速度和战斗移动速度不再读取玩家 `x2` / `x4` 作为额外倍率，只接受暂停、敌人在场上限和 LLM 慢速对全局推进节奏的影响。T1104B 起，CombatSystem 内部再把 `game_delta_seconds / 60` 转为战斗动作秒推进攻击冷却和战斗位移，防止默认 `x1` 的 60 游戏秒 / 现实秒被误用为 60 次战斗动作秒。

暂停与加速彼此独立。`SpeedButton` 只调用 `TimeSystem.cycle_speed()`，空格和 `PauseButton` 只调用 `TimeSystem.toggle_paused()`。暂停时 `get_numeric_delta_multiplier()` 返回 `0`，TimeSystem 不发出逻辑推进；NPC 移动通过 `is_gameplay_paused()` 停止，ActionSystem 的行动资源/状态结算会保持 pending，直到 `gameplay_pause_changed(false)` 后再继续。暂停不应冻结 UI、HTTP/后端请求或未来 LLM 对话/判定请求；这些请求返回后仍必须通过程序规则应用权威状态变化。

`UnconsciousSystem` 仍保留为后续治疗扩展模块规划，T0102 未创建该节点或脚本；当前 T0501/T0502/T0503 的扣血、昏迷、自然恢复、协助治疗和自动复苏最小闭环由 `NPCSystem.gd` 与 `ActionSystem.gd` 负责。

## 当前 Main 场景结构

```text
Main
├─ WorldRoot
│  └─ Station
│     ├─ Ground
│     ├─ Buildings
│     │  ├─ MainHall
│     │  ├─ Dormitory
│     │  ├─ DiningHall
│     │  ├─ Warehouse
│     │  ├─ Tavern
│     │  ├─ Garden
│     │  ├─ Blacksmith
│     │  ├─ TrainingGround
│     │  ├─ Stable
│     │  ├─ Chapel
│     │  ├─ Clinic
│     │  ├─ Workshop
│     │  ├─ NoticeBoard （主厅前公告输入/预览，非建筑数据）
│     │  ├─ FrontWall / BackWall / LeftWall / RightWall
│     │  ├─ FrontGate
│     │  └─ BackGate
│     ├─ NPCs
│     │  ├─ Stableman01
│     │  ├─ Cook01
│     │  ├─ Gardener01
│     │  ├─ Blacksmith01
│     │  ├─ VeteranDeputy01
│     │  ├─ Priest01
│     │  ├─ Doctor01
│     │  └─ Engineer01
│     ├─ Enemies
│     ├─ DefenseDevices
│     └─ Props
│        ├─ Plaza
│        ├─ FrontRoad
│        ├─ BackRoad
│        └─ MerchantEntranceMarker
├─ Systems
│  ├─ TimeSystem
│  ├─ ResourceSystem
│  ├─ BuildingSystem
│  ├─ NPCSystem
│  ├─ ActionSystem
│  ├─ MemorySystem
│  ├─ MerchantSystem
│  ├─ DefenseDeviceSystem
│  ├─ CombatSystem
│  ├─ EquipmentSystem
│  ├─ LLMBridge
│  ├─ DailyPlanSystem
│  ├─ GameStartupSystem
│  ├─ DailyReflectionSystem
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  ├─ NoticeBoardPanel
│  ├─ MerchantPanel
│  ├─ GMPanel
│  └─ DialogPanel
├─ CameraRig
│  └─ Camera3D
└─ SunLight
```

T0103 已在 `Main.tscn` 直接放置低模驿站 Blockout：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊，以及主厅前公告牌均使用简单几何体和 `Label3D` 调试标签表示。2026-05-19 已扩大地面、围墙和相机视野，并拉开建筑间距，避免建筑过小过密；围墙四角已闭合，公告牌已缩小并移动到主厅正面。2026-06-12 为 T1101 扩大正门外地面与 `Props/FrontRoad`，使敌人可生成在正门外森林方向。T1506 后公告牌拥有独立点击区和当前公告预览，但仍不绑定 `data/building_defs.json`，不拥有 HP、等级、工作位、修复或升级；公告文本归广场状态保存。T1507 后后门商人入口标签只在配置到访时段显示并可点击交易。T1508 后 `Station/DefenseDevices` 由独立 presenter 生成低模器械占位，模型资源与权威结算解耦。

T0104 已在 `Main/UI/HUD` 下补齐基础 HUD：标题、天数、`HH:MM:SS` 时间/阶段、资源栏、速度按钮、暂停按钮、警铃按钮和后端状态。`Main/UI` 绑定 `res://scripts/ui/UIInputFocusManager.gd`，统一处理文本输入框点击外部失焦；`Main/UI/HUD` 绑定 `res://scripts/ui/HUD.gd`，负责显示和从 `GameState` 读取当前时间；T0401 后会监听 `EventBus.time_changed` / `hour_started` / `day_started`，并通过 `SpeedButton` 调用 `TimeSystem.cycle_speed()` 在 `x1`、`x2`、`x4` 间循环，通过 `PauseButton` 或空格调用 `TimeSystem.toggle_paused()`。T0012 后，HUD 会监听 `EventBus.resource_changed`，按 `ResourceSystem.get_resource_ids()` / `data/resource_defs.json.ui_order` 动态显示非聚合资源，并提供装备/器械详情按钮；详情面板贴近各自按钮左下并保持在屏幕内，只读取 `ResourceSystem`、`EquipmentSystem` 和 `NPCSystem`。T1301 后 HUD 显示波次倒计时；T1302-T1305 后 HUD 复用 `GameOverPanel` 显示失败或胜利结算，胜利读取 `GameState.settlement_snapshot` 展示剩余资源、建筑和 NPC 状态摘要，胜利和失败都会在滚动详情区展示 NPC 结局总结。T0604 后，HUD 读取 `Main/Systems/LLMBridge` 的后端状态，并监听 `backend_status_changed` 刷新 health check 结果。T1103 后，警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")`，不在 HUD 内自行决定 NPC 集结或战斗事实。T0205 已将 `Main/UI/BuildingPanel` 绑定 `res://scripts/ui/BuildingPanel.gd`：监听 `EventBus.building_clicked` 打开被点击建筑，监听 `EventBus.building_state_changed` 刷新当前可见建筑，从 `BuildingSystem` 读取名称、等级、HP、建筑状态、精确运作效率及按配置顺序排列的逐位置名称 / 空闲 / 占用者，并通过按钮触发 `BuildingSystem` 的修复/升级接口；不显示“主动工位 / 被动工位”或按类型聚合摘要。修复/升级消耗和条件只在按钮悬停提示框中显示，进行中会显示倒计时进度、剩余时间、速度倍率和协助人数。T1508 修订后围墙面板额外显示弩床 / 箭塔库存、类型、兼容空槽和已部署清单，不显示部署者，所有按钮只调用 DefenseDeviceSystem。

T0604 已新增 `res://scripts/systems/LLMBridge.gd`，并以 Godot 原生 `HTTPClient` 状态机支持后端地址、健康检查和 NPC AI 业务请求。T0049/T0050 后六类正式业务均有异步路径、request id、取消、NPC LLM 活动和 TimeSystem 慢速审计；`request_timeout_seconds=2` 只保护建立本地后端连接及 health / usage 等短请求，业务生成由后端流式连接 / 空闲超时控制。对话 payload 继续收集目标 NPC 设定、权威状态、记忆、地点、说话者、轮次和战时上下文；T0053 起 `build_plan_revision_judgement_payload(...)` / `request_plan_revision_judgement_async(...)` 按 `trigger_kind` 把对话或行动失败事实、判别基线原计划以及共享 NPC 人设 / 状态 / 长短期记忆 / 指令 / 驿站 / 现实条件送往 `/npc/plan_revision_judgement`。计划修订和战时心理 payload 使用同一 NPCContext，修订仍采用 `revision_scope=selected_hours` 与精确 `revision_hours`。该桥只返回后端 JSON 或错误字典，不写入权威事件或状态，也不直连真实 LLM 供应商。

T0701/T0702/T0049 后，`res://scripts/systems/DialogSystem.gd` 是 Godot 侧对话、征召结果和对话后计划判别编排入口，`res://scripts/ui/DialogPanel.gd` 只负责交互呈现。DialogSystem 维护参与者、历史、公开性、轮次和一次性应征标记，将实际对话写入 MemorySystem；玩家-NPC 有效会话结束后自动为目标 NPC 判别，NPC-NPC 邀请拒绝或正式会话结束后为双方分别判别。`revision_hours=[]` 时不请求修订，并仅在原动作确被本次对话打断、仍匹配计划且行为模式允许时恢复；非空时把精确小时交给 DailyPlanSystem。DialogPanel 已移除“结束后重估计划”开关；空窗口或未完成普通回复不触发判别。对话内攻击一旦提交就是有效事实，即使攻击回复取消或逃离攻击不产生 NPC 回复，也保留攻击轮并进入同一判别。NPC-NPC 仍先邀请、接受后才打断双方普通行动并释放工位，正式会话无硬轮次上限；旁听关闭不结束会话。行为模式强制结束、战时公开对话和逃离挽留继续沿用既有权威边界。

T0703 已把 NPCPanel 的已入伍占位按钮替换为独立 `OrderPanel` 自然语言指令面板；NPCSystem 权威保存 `current_order`，MemorySystem 写入 `private` `order_assigned`，并通过 `EventBus.npc_plan_reevaluation_requested` 发出统一重估请求。UI 不直接启动具体行动，也不决定 NPC 是否服从。T0049 后，指令变化属于非对话触发，直接以 `revision_hours=[current_hour]` 请求真实修订；所有修订使用 `selected_hours`，不再完整覆盖剩余日。正式每日计划与修订只应用经 provider 证明的真实结果，失败最多重试 3 次并保留原计划，不生成 Mock / 规则修订。主动找守备官交涉被玩家实际响应后走对话判别；未被点击而超时则作为非对话状态变化只修订当前小时。

T1001/T0022/T0025/T0049/T0050 后，`res://scripts/systems/DailyPlanSystem.gd` 同时承担显式规则调试计划、正式真实 LLM 每日计划、对话 / 日常行动失败判别后的精确阶段修订与其他直接受限修订。正式每日计划批次默认 8 路并发，8 人全部成功才恢复时间并执行当前项；单人最多 3 次真实请求，失败不调用 Mock 或规则降级。当前项按教官、其他非对话、受训者、对话顺序派发，同一计划版本同一时段只派发一次。判别空集合时不启动第二层；非空修订链路校验响应小时集合与 `revision_hours` 完全一致，仅合并所选小时，未选小时保持原值。请求日 / 小时 / 计划版本 / 对话 epoch、单后继队列和连续迟到落地失败上限共同拒绝过期覆盖与无限重修；`avoid_combat` 等非工作模式可先应用计划而延迟执行当前项。

T0019/T0022 后，`res://scripts/systems/GameStartupSystem.gd` 挂载到 `Main/Systems/GameStartupSystem`并导出三状态 `startup_mode`。静止调试模式暂停 `TimeSystem` 并关闭计划自动执行；两个正式模式会先暂停时间，让 8 名 NPC 写入 `wake_up`、清空旧计划并进入 `planning_day`，再以 8 路并发请求真实每日计划。系统只在 8 份 `llm_plan_day` 全部成功时打开自动执行、统一执行第 1 天 06:00 项并恢复时间；任一失败时保持暂停，不接受 Mock 或规则计划。新手引导模式当前只记录 `placeholder_not_implemented`；Headless 环境不自动应用启动模式。

T1004/T1005/T1405 已新增 `res://scripts/systems/DailyReflectionSystem.gd` 并挂载到 `Main/Systems/DailyReflectionSystem`。它监听 `EventBus.event_recorded` 中的 `sleep_started` / `sleep_ended` 和 `logical_time_tick`，每名 NPC 每天首次睡觉并持续睡眠满 1 游戏小时后调用 `LLMBridge.request_npc_daily_reflection_async(...)` 请求 `/npc/daily_reflection`；后端失败或输出无效时使用本地模板，并保留模型失败日志。成功结果通过 `NPCSystem.apply_daily_reflection(...)` 增量追加长期日记，并按 `subject + relation` 替换式更新知识图谱当前键值，再通过 `MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天短期事件/见闻索引。该请求会申请 TimeSystem 慢速，且从发起到应用完成期间通过 NPCSystem 的首次睡眠总结锁阻止对话、发消息、行动中断和行动改派。生产 / 演示路径不得用 mock 日记伪装真实模型成功。

T0105 已将 `res://scripts/camera/CameraRig.gd` 绑定到 `Main/CameraRig`：玩家可用 WASD 平移、鼠标中键拖拽平移、滚轮缩放；脚本只移动 `CameraRig` 的 X/Z 位置和 `Camera3D` 的本地距离，保留高机位俯视角，并通过导出参数限制移动边界和缩放距离。T0045 后 WASD 改为事件式按键状态，按键释放、文本输入聚焦和窗口失焦都会停止平移，失焦也会取消中键拖拽。T1101 后 Z 轴正向边界扩到可观察正门外敌人生成区。该阶段不实现角色控制或自由第一人称视角。

T0202 已在 `res://scripts/systems/ResourceSystem.gd` 中实现基础资源系统：启动时读取 `data/resource_defs.json` 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁，提供 `get_resource`、`get_resource_definition`、`get_resource_ids`、`add_resource`、`can_afford`、`spend_resources` 与临时调试接口。所有资源变化通过 `EventBus.resource_changed` 通知 UI；资源不足时 `spend_resources` 返回 `false`，不扣除也不产生负数。T0012 后 HUD 主栏直接显示非聚合资源，武器、盔甲、马匹整备和工程器械在装备/器械详情面板中查看；派生资源仍由行动、装备或后续交易/器械部署系统权威结算。

T0205 已在 `res://scripts/systems/BuildingSystem.gd` 中实现基础建筑系统：启动时读取 `data/building_defs.json`，按 `scene_nodes` 绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，为绑定节点创建运行时 `Area3D/CollisionShape3D` 点击区，并在左键点击时发出 `EventBus.building_clicked(building_id)`；建筑受损、修复/升级进度、协助者变化、修复完成和升级完成会发出 `EventBus.building_state_changed(building_id)`。建筑调试标签会显示名称、等级和 HP，并在修复/升级后刷新。2026-05-24 起，`NoticeBoard` 从建筑定义中移除；T1506 后由独立 `NoticeBoard.gd` 创建点击区、相机射线拾取和公告预览，并通过 `NoticeBoardPanel.gd` 调用 MemorySystem，BuildingSystem 不参与公告状态。2026-05-20 修正后，建筑点击同时通过 `_unhandled_input` 的相机射线拾取点击区，避免全屏 UI 背板或项目拾取设置导致真实鼠标点击失效。T0304 起，建筑系统提供 `get_building_entry_position(...)` 和 `get_building_location_context(...)`，分别用于 NPC 移动目标点与地点当前状态读取；该上下文不包含建筑过去事件，精确 HP 与剩余修复/升级时长仍留在系统 / UI，外部只传播 `condition / is_enterable / operational_efficiency` 分档，室内逐位置传播 `id / type / name / occupied_by / status` 及增删变化。T0801 起，建筑系统提供 `claim_workstation(...)` / `release_workstation(...)` 作为位置占用权威接口，ActionSystem 通过这些接口自动取得 / 释放同类型空位。T0043 后新增统一建筑可用性、受损与活动效率接口，升级按 `level_effects` 应用成本、时长、Max HP、位置和效率奖励；固定位置类型拒绝扩容，升级期间建筑封闭并清退使用者。修复/升级由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 结算；资源不足时不会改变建筑状态。升级只有在建筑完好且未处于修复/升级作业时可开始。T1102 起，战斗系统通过 `apply_damage_to_building(...)` 扣除建筑 HP，并写入 `building_damaged` 结构化事件；该入口仍由 BuildingSystem 作为权威状态修改点。

T0304 已新增 `res://scenes/npc/NPC.tscn` 和 `res://scripts/npc/NPC.gd`，并在 `res://scripts/systems/NPCSystem.gd` 中实现基础 NPC 生成、状态接口和直线移动占位：启动时读取 `data/npc_profiles.json`，实例化 8 个 NPC 到 `Main/WorldRoot/Station/NPCs`，每个 NPC 保存唯一 `npc_id`，主场景 `Label3D` 调试标签只显示短姓名、HP 和当前行动。NPC 点击会打印 ID 并通过 `EventBus.npc_clicked(npc_id)` 广播；`NPCSystem` 同时提供 `get_npc(...)`、`get_npc_state(...)`、`get_npc_ids()`、`get_npc_count()`、`update_npc_state(...)`、`set_npc_state_value(...)`、固定熟练度枚举、`normalize_skills(...)`、`get_npc_specialties(...)`、`increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)`、`debug_assign_attribute_point(...)`、`debug_select_npc(...)`、`move_npc_to_building(...)`、`debug_move_npc_to_building(...)`、`debug_move_selected_npc_to_building(...)` 和 `debug_enter_location_immediately(...)`。T1103 后还提供 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 以世界坐标发起城门外集结、接敌时停止移动并切换状态。T1103A 起，NPC 运行时状态统一保存 `behavior_mode = work|rally|combat|avoid_combat|unconscious|escaped`、进入原因和进入时间，T1103 的 `combat_mode` 仅作为旧集结 / 坐骑视觉兼容字段保留。每名 NPC 的技能会归一化为 8 个职业熟练度加 5 个武器熟练度，专长由高熟练度推导，不使用硬职业枚举；运行时 `progression` 记录各熟练度经验、总经验、未分配技能点和已分配技能点。技能点由玩家分配到力量或智力，AI 不自动消耗。移动开始时 NPC 状态进入 `moving_to_<building_id>` 或系统指定的移动状态；到达后通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present`，写入 `current_location`、`current_location_name` 和 `location_context`，并发出 `EventBus.npc_state_changed(npc_id)`。T0409 起，室内信息地点到室内信息地点的切换会在事件与地点信息层插入广场中转；物理移动仍是低模直线占位。T1103A 后 `NPC.gd` 运行时优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结 / 接敌朝向标记，并兼容旧 `combat_mode`；只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动会显示“战术移动”行动摘要。进入地点只读取当前地点状态快照，不继承该地点过去事件。该阶段不实现复杂避障、自然状态变化、真实日程计划、正式战斗结算或 LLM。

T0402 后，`res://scripts/systems/ActionSystem.gd` 的简单行动系统会在行动开始、完成或失败时写入结构化事件：工作路径写入 `work_started`、`work_completed`、`work_failed`，协助修复写入 `repair_assist_started`，协助升级写入 `upgrade_assist_started`，协助治疗和诊所治疗写入 `healing_started` / `healing_completed`，吃饭路径写入 `eat_started`、`eat_completed`，睡觉路径写入 `sleep_started`、`sleep_ended`，工作 / 研读医术 / 训练成长写入 `skill_improved`。行动仍会先检查 NPC 是否可行动，必要时调用 `NPCSystem.move_npc_to_building(...)` 前往目标地点；到达后进入持续行动状态，并通过 `EventBus.logical_time_tick` 按逻辑秒推进，不再瞬时结算完整结果。吃饭当前 1200 秒恢复约 50 点饱食度；睡觉当前 23400 秒降低 100 点疲劳，且睡觉期间 `MemorySystem.add_witness_event(...)` 不会给该 NPC 写入地点/建筑 public 见闻；T0801 后工作以配置 `duration_seconds` 为单位周期基准，开始时占用目标建筑工位，实际周期时长按 NPC 对应熟练度、力量/智力属性和建筑等级缩短，单位结束时结算资源输入/输出、饱食消耗和疲劳增长，完成、失败或中断时释放工位。T0803 后，工作可选 `output_scaling` 产出缩放；当前菜园粮食产出会按耕种熟练度、力量和菜园等级提高实际产量，完成事件记录缩放后的产出。T0804 后铁匠铺消耗铁产出武器/盔甲派生库存；T0805 后工械坊消耗木材产出武器/工程器械派生库存，工程和智力影响制作效率；T0806 后马厩消耗粮食产出马匹整备派生库存，养马、力量和马厩等级影响制作效率与实际产出；T0807 后酒窖消耗粮食产出酒库存，酿酒、智力和酒窖等级影响制作效率与实际产出；T1507 后由 MerchantSystem 在商人到访时单独出售，酿酒完成仍不自动换钱。T0808 后小诊所包含医生工位和病床：医生在岗且病人占床时治疗才推进，治疗按逻辑时间消耗第纳尔并恢复 HP，速度由医术、智力和诊所等级提高；医生无病人时缓慢研读医术。T0903 后训练场包含教官工位和受训位：无装备不能训练或执教，受训者需要已有教官，教官独处时提升自己当前装备对应武器 / 骑术，有受训者时受训者按自己的装备提升对应熟练度且教官提升“教练”，训练按逻辑时间消耗疲劳和饱食。T0904 后，工作完成、诊所研读 / 治疗、训练场成长都会调用 `NPCSystem.increase_npc_skill(...)`，同步写入经验和未分配技能点。协助修复/协助升级是带 `building_id` 参数的运行时广场行为，事件 `location_id == "plaza"` 且 `visibility == "local_public"`；建筑 HP、资源预付和倒计时由 `BuildingSystem` 结算。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者前往目标所在信息地点，每个目标最多 2 名治疗者，按逻辑时间消耗第纳尔，并调用 `NPCSystem.assist_unconscious_recovery(...)` 按医术熟练度加速 HP 恢复；`ActionSystem.get_healing_helpers_for_target(...)` 仅供信息节点读取当前治疗者，不参与结算。若游戏处于暂停，未到达目标的行动保留在 pending 队列中，已开始的行动保留在 active 队列中，不推进资源消耗/产出或状态变化；恢复后继续。当前已按 `game_design.md` 覆盖菜园、食堂、酒窖、铁匠铺、工械坊、马厩、小诊所、训练场、协助修复、协助升级、协助治疗、吃饭和睡觉的最小效果；工程器械部署已由 T1508 独立 DefenseDeviceSystem 处理；其他职业特殊生产平衡仍由后续任务处理。

T0025 覆盖上一段旧行动 / 治疗事件清单：ActionSystem 还执行祈祷、主持弥撒、地点拜访和带目标 NPC 对话，并以 `get_runtime_action_snapshot(...)` 向计划系统暴露 pending / active 的 action、target、location、已占位置与参数。协助治疗只有目标正常完成时写 `healing_completed`；中途第纳尔不足或离开治疗地点写 `healing_failed`。T0043 后普通祈祷使用祈祷席且不依赖神父在场；`lead_mass` 对所有 NPC 可见，但只有 `abilities` 包含“主持弥撒”的 NPC 能占用祭坛。对话接近、预定、打断与位置释放仍由 ActionSystem 权威处理。

T0043 覆盖上一段 T0808/T0903 的单服务者旧效率口径：小诊所使用 `clinic_doctor_station` / `clinic_patient_bed`，训练场使用 `training_instructor_station` / `training_practice_slot`；所有在岗医生共同提高全部病床恢复，所有在岗教官共同提高全部训练位成长。食堂吃饭申请 `dining_seat`，宿舍睡觉申请 `dormitory_bed`，普通祈祷申请 `chapel_prayer_seat`，主持弥撒申请 `chapel_altar`。活动周期同时消费建筑升级加成和受损倍率，建筑封闭时现有行动被强制中断。

T1507 已新增 `res://scripts/systems/MerchantSystem.gd` 与 `res://scripts/ui/MerchantPanel.gd`。MerchantSystem 读取 `data/merchant_defs.json`，监听 `time_changed` 判断每日到访窗口，控制 `Props/MerchantEntranceMarker` 的可见标签和运行时点击区；玩家交易时由 MerchantSystem 校验时段、报价、数量和余额/库存，再调用 ResourceSystem 结算。买入粮食/木材/石料/铁会扣第纳尔，卖酒会扣 `wine` 并增加第纳尔；失败交易不修改状态。MemorySystem 记录 `merchant_arrived`、`merchant_departed`、`merchant_trade_completed` 广场公开事件。MerchantPanel 只展示配置报价和提交请求，不直接写资源。

T0901 已新增 `res://scripts/systems/EquipmentSystem.gd`：系统读取武器、盔甲和坐骑定义，消耗 `weapons` / `armor` / `horse_readiness` 派生库存，把装备写入已入伍 NPC 的 `equipment` 槽位，并通过 `MemorySystem.record_player_interaction(...)` 记录玩家给予或更换事件。T0031 起，NPC 档案的 `initial_equipment` 会在定义加载后装载到空槽；该故事初始化不扣库存、不写玩家交互事件，当前用于让艾达开局持有正式剑盾。T0902 起，兵种判定只根据 `equipment.main_weapon` 与 `equipment.mount` 返回分类标签和只读快照；`horse_readiness` 库存本身不会让 NPC 被判定为骑兵。T1103 起，CombatSystem 只读兵种快照决定集结前后排和是否显示战斗坐骑，NPC 日常工作不会因坐骑库存或装备而自动骑乘。UI 和 GM 面板只调用装备系统接口，不自行决定装备事实或兵种结果。T1104 后，CombatSystem 会读取主武器数值、盔甲防御和坐骑槽参与基础攻击与攻速修正；EquipmentSystem 本身仍不执行伤害结算、耐久或完整外观换装。

T0303 已将 `Main/UI/NPCPanel` 绑定 `res://scripts/ui/NPCPanel.gd`：监听 NPC 点击与状态变化，显示目标的权威状态、成长、装备、行动和记忆入口；切换建筑时隐藏自身。T0042 后标题行“背景”按钮复用详情弹窗展示 `NPCPromptProfile` 人设。T0024/T0049 后，事件库上方并排显示“当前计划 / 日记 / 知识”；事件库和见闻库详情首次打开自动滚到最底部的最新记录，已打开时刷新保留玩家当前位置，日记与知识图谱继续在独立详情弹窗查看。T1103A 后当前行动同时显示行为模式；T1204A 后逃离 NPC 仍可从该面板进入挽留对话。`BuildingPanel` 在 `npc_clicked` 时隐藏，确保对象面板互斥。

T0004 已将 `Main/UI/GMPanel` 绑定 `res://scripts/ui/GMPanel.gd`：开发模式下显示半透明可拖动 `GM` 按钮，点击后打开 GM 调试面板。面板只调用已有系统接口或 `debug_*` 接口，覆盖资源、时间、建筑、NPC、行动、地点信息、广场公告和短期记忆等关键调试入口；T0503 后行动区包含治疗目标下拉与协助治疗按钮；T0014 后普通行动入口收敛为行动下拉 + “指定行动”，带目标参数的协助入口继续保留；T0904 后 NPC 分组包含技能点分配入口，并支持 `assign_attribute <npc_id> <strength|intelligence>` 命令；T0015 后 NPC 分组新增“设为入伍”按钮，并支持 `recruit_npc <npc_id>` 命令；T1004/T1005 后 NPC 分组新增首次睡眠总结、长期记忆和最近总结入口，并支持 `reflect_npc`、`long_memory`、`reflection_result`、`llm_state` 命令；T1101 后新增“战斗 / 敌人”分组和 `spawn_wave` / `enemy_wave` / `enemies` / `clear_enemies` 命令；T1102 后新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令；T1103 后新增“警铃集结”按钮和 `alarm` / `rally` 命令，调用 CombatSystem 的警铃入口并显示集结结果摘要；T1103A 后新增“行为模式快照”“推进集结等待”按钮和 `behavior_modes` / `advance_rally_wait [game_seconds]` 命令，用于查看模式状态和验证 1 游戏小时集结等待超时；T1104 后，`step_enemies` 同时推进我方基础自动攻击并在快照中暴露最近我方攻击结果；顶部 `GM_ENABLED` 常量可在开发/上线模式间切换显示。

## 重要信号建议

```gdscript
signal day_started(day: int)
signal time_changed(day: int, hour: int, minute: int, second: int)
signal time_scale_changed(player_scale: float, effective_scale: float, numeric_multiplier: float, reason: String)
signal logical_time_tick(game_delta_seconds: float, numeric_multiplier: float)
signal hour_started(day: int, hour: int)
signal resource_changed(resource_id: String, amount: int)
signal npc_state_changed(npc_id: String)
signal npc_daily_plan_changed(npc_id: String, plan: Array)
signal npc_proactive_talk_changed(npc_id: String, active: bool)
signal npc_hp_changed(npc_id: String, hp: int, max_hp: int)
signal npc_unconscious(npc_id: String)
signal npc_clicked(npc_id: String)
signal building_clicked(building_id: String)
signal building_state_changed(building_id: String)
signal dialogue_requested(npc_id: String)
signal recruitment_changed(npc_id: String, recruited: bool)
signal battle_started(wave_id: int)
signal battle_ended(wave_id: int)
signal npc_revived(npc_id: String)
signal event_recorded(event: Dictionary)
signal npc_memory_changed(npc_id: String)
signal location_info_changed(location_id: String)
signal public_event_added(event: Dictionary)
signal notice_board_clicked
signal merchant_clicked
signal merchant_state_changed(active: bool, snapshot: Dictionary)
```

## 命名规范

- 场景：`PascalCase.tscn`
- 脚本：`PascalCase.gd`
- JSON 配置：`snake_case.json`
- 节点名：明确表达用途，如 `NPCContainer`, `BuildingContainer`
- 信号名：动词过去式或事件式，如 `npc_unconscious`, `resource_changed`

## 不要做

- 不要把游戏所有逻辑塞进 `Main.gd`。
- 不要在 NPC 节点里直接调用所有系统。
- 不要在 UI 脚本里修改底层数据，UI 应调用系统接口。
- 不要在场景里手填大量 NPC 数值。
- 不要手改大型 `.tscn` 导致场景损坏。
