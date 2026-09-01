# GODOT_ARCHITECTURE.md

## T0315 里程碑弹窗与幼马命名接线

- `EventBus` 新增 `building_job_completed(building_id, job_type, result)` 与 `horse_birth_naming_requested(request)`；前者只在 BuildingSystem 的真实 `_finish_repair / _finish_upgrade` 末尾发送，后者只在 HorseSystem 成功预留候选幼马后发送。
- `Main/UI/MilestoneAlertPresenter` 是常驻全屏 Control，内部持有一个 FIFO 队列和两个 AcceptDialog。建筑窗读取只读结果；小马窗预填模板名并把 request id 与文本提交给 `HorseSystem.confirm_pending_foal_name(...)`。Control 本身忽略世界鼠标，只有弹窗接收交互。
- HorseSystem 新增单个 `_pending_birth` 事务与递增 request id。自然繁育和 `debug_force_birth()` 都进入 `_request_foal_naming(...)`；待命名时 `_get_birth_block_reason()` 阻止并发出生。确认函数权威入库后复用既有状态信号，使 WorldHorsePresentation、HorsePanel、马厩列表与分配候选自然刷新。
- MemorySystem 注册 `horse_born` 结构并确定性格式化名称。Main 没有新增旁路命名字段或第二套马匹 UI 状态。

## T0314 制造暂存与收获接线

- `CraftingSystem` 新增逐建筑 `_pending_outputs`、`pending_outputs_changed` 和 `collect_pending_outputs(...)`。最终阶段与材料扣除处于同一 stage commit；成功后只累加暂存并重置阶段，正式 ResourceSystem 保持不变。收取先复制点击瞬间快照，通过 `can_store_resources / add_resources` 一次提交，成功后再按该快照扣减暂存。
- `Main/UI/CraftingTargetAlerts` 复用建筑 Label3D 屏幕投影，新增 `44×44px` 小手圆形 Button 与总件数徽标；`Main/UI/CraftingHarvestDialog` 是 `z=80` 的全屏居中覆盖层，逐件生成 `68×68px` 无边框 Button 图标，Tooltip 为正式名称。
- BuildingPanel 与世界按钮都只调用弹窗 `open_for_building(...)`；弹窗确认只调用 CraftingSystem 收取接口。HUD、NPCEquipmentWindow 和 DefenseDeviceSystem 无暂存读取路径，因此正式入库前自然不可见 / 不可用。
- ActionSystem 最终阶段发送带具体装备 / 器械图标的“待收取”世界反馈；MemorySystem 只消费结构化 `pending_output_resources`。功能在正式 Main 可直接验证，既有制造单阶段 GM 入口会产生真实暂存，无需新增 GM 按钮。

## T0313 马匹生态世界反馈接线

- `HorseSystem.gd` 新增仅运行时 `_world_feedback_accumulators`。自然回血函数返回实际 `hp / satiety` 差；照料提交后分别记录自然 HP 增长、`care_bonus_hp` 和 growth；繁育概率在实际钳制后记录，并在进入冷却时清理旧余量。
- `_advance_simulation(...)` 继续按原 60 游戏秒固定步长推进生态、照料和繁育，只在整个 while 结束后调用一次反馈 flush。HP / 饱食 / 额外 HP 的完整单位和成长 / 概率的 `0.1%` 单位进入同一 `horse_ecology` 逐马替换频道，剩余小数留在系统内。
- `_advance_feeding(horse_id, horse, ...)` 在原 ResourceSystem 扣粮成功后计算饱食上限钳制的实际恢复，并发送 `horse_feeding` 组；等待粮食路径不发送。两频道都使用既有 horse 锚点解析和 `2.75m` 高度，不新增场景节点或 Autoload。
- 功能在正式 Main 可直接观察，既有 `horse_advance / horse_damage` 调试能力足以准备状态，未新增 GM 入口。Godot MCP 本轮在正式 Main 首次步进时连接关闭，自动化由 `verify_t0313_horse_ecology_world_feedback.gd` 与 CLI Main headless 完成。

## T0312 战斗 / 恢复世界反馈接线

- `WorldFeedbackPresenter` 现可解析 `npc / enemy / horse / building / defense_device`。实时位置分别来自 NPCSystem、CombatSystem、HorseSystem 快照、BuildingSystem 入口和 DefenseDeviceSystem deployment；payload 的精确命中点可设为优先，目标移除后使用最后有效坐标。
- 默认高度为 NPC `4.25m`、敌军 `2.95m`、马匹 `2.75m`、建筑 `3.0m`、器械 `2.35m`；碰撞点只抬高约 `0.25–0.35m`。`damage` 同目标立即替换，`healing` 在 `0.45s` 内把单条同语义增量相加并重启动画。
- NPC 受伤、普通治疗、昏迷自然 / 协助恢复与跨阈值复苏，敌军受伤 / 移除，马匹受伤，建筑受伤 / 直接恢复 / 施工修复，器械受伤 / 摧毁均从各自提交点发送。骑乘分伤自然形成骑手和马匹两个锚点；当前器械无恢复 API，不建立 UI 旁路。
- CombatSystem 只新增世界位置查询与既有碰撞坐标的表现透传，不改变攻击接触、弹体 sweep、伤害公式或目标路由。该功能正式 Main 可直接观察，无需新增 GM 面板入口。

## T0311 世界数值反馈接线

- `Main/UI/WorldFeedbackPresenter` 是 `CanvasLayer` 下的全屏、忽略鼠标、`PROCESS_MODE_ALWAYS` 表现节点；它以 `Camera3D.unproject_position(...)` 跟随 NPCSystem 的实时世界坐标，相机后方或屏幕外隐藏，不钉屏幕边缘。
- NPC 默认反馈锚点为实体原点上方 `4.25m`，高于 T0301 的 `3.72m` 情绪层。普通反馈同锚点最多两组；`needs` 等替换频道收到新值时立即移除旧组。每组 `1.2s` 不透明稳定显示，随后 `0.8s` 上漂 `36px` 并淡出；计时不消费逻辑游戏秒，TimeSystem 暂停不冻结表现。
- `WorldFeedbackPayload.gd` 统一生成带符号实际增量、正式名称、颜色角色与可选 SVG 路径。普通工作在资源提交和成长返回后一次发送；`NPCSystem.increase_npc_skill` 默认发送成长组，ActionSystem 普通工作可抑制该次单独发送并与资源合组，避免重复。
- 进食资源在 `_start_eat` 成功扣除后发送；饱食从 `_apply_progress_state_deltas / _apply_final_state_deltas` 的钳制后真实差值发送。NPCNeedsSystem 只为 `sleep` profile 的真实负疲劳差发送，不把普通工作过程需求消耗刷成飘字。
- 该接线新增表现信号，不新增 Autoload、存档字段、GM 入口或数值结算器。T0312-T0314 现已分别复用该入口完成战斗 / 恢复、马匹生态与制造收获反馈。

## T0310 NPC 复苏提示接线

- `NPCSystem._revive_npc_from_unconscious(...)` 继续在权威状态、HP 和复苏事件提交后发出 `EventBus.npc_revived(npc_id)`；系统接口与信号签名不变。
- `HUD.gd` 是新增的只读消费者：将 NPC id 排入 `_npc_revived_alert_queue`，通过 NPCSystem 正式档案解析姓名，再驱动 `Main/UI/HUD/NpcRevivedAlertDialog`。
- `AcceptDialog` 使用 `popup_centered()`，确认与关闭都 deferred 推进下一条；该 UI 不反写 NPCSystem，也不新增 GM 入口。

## T0309 HUD 主资源图标接线

- `Main/UI/HUD/AlarmButton` 的玩家可见文案为“警报”；节点名和 `CombatSystem.trigger_combat_alarm("hud")` 接线不变，警铃集结仍是底层玩法语义。
- `HUD.gd` 的 `_build_resource_strip()` 仍按 `ResourceSystem.get_resource_ids()` 和 `show_in_main_hud` 动态建 7 个稳定命名资源项；每项由 `22px TextureRect/Icon + Amount Label` 组成，TextureRect 加载 `assets/ui/resource_icons/*.svg`，Label 只显示数量。系统 emoji 字符不进入运行时文本。
- `_refresh_resource_capacity_tooltip()` 统一把 ResourceSystem 的正式名称放在图标 Tooltip 首行；`get_resource_capacity(...) >= 0` 时追加动态仓库上限。图标 `MOUSE_FILTER_STOP`，数量 Label 与外层 Item 忽略鼠标，确保悬停边界只属于图标。
- 原 `ResourceStrip`、装备 / 器械按钮、详情面板、HUDFrame deferred 自适应和 ResourceSystem 接口均未改；功能可在正式 Main 直接验证，不新增 GM 入口。

## T0306 LLM 短期记忆聚合接线

- `LLMBridge.gd` 集中维护五类白名单、逐类签名、连续段边界、reduce 与确定性中文摘要；`_build_short_memory_context`、共享 `NPCContext` 和反思 `day_events` 均走 `build_memory_event_projection`。
- `DailyReflectionSystem.gd` 从原始请求快照构建 day_events 时调用同一投影；总结成功仍把原始 `event_ids / witness_ids` 交回 MemorySystem 清理。
- `GMPanel.gd` 复用“短期记忆 / LLM”入口，同时显示事件 / 见闻原始条数、投影条数和五类 `by_type` 统计；NPCPanel 仍直接读取原始短期记忆逐条显示。

## T0301 NPC 世界头顶层接线

`NPC.gd` 集中使用五个局部 Y 常量：友军血条 `2.62`、思考 / 主动交涉 `2.95`、自主 / 挂起对话与逃离警示 `3.12`、情绪 Emoji `3.72`；姓名 / 行动仍由 `_refresh_label` 固定为 `2.08`。`debug_get_overhead_ui_snapshot` 公开所有层的位置，测试不依赖截图猜测。

`CombatSystem.gd` 的 `_create_enemy_node` 与 `_create_formal_enemy_actor` 共用 `ENEMY_NAME_LABEL_HEIGHT=2.10`，`_ensure_enemy_world_health_bar` 使用 `ENEMY_HEALTH_BAR_OFFSET=0.34`，避免正式 Actor 再覆盖成另一套高度。

## T0300 DialogPanel 紧凑 Header 接线

`Header` 直接包含 `DialogHeaderLeft` 与 `DialogHeaderToggles`。左侧 VBox 内依次是 `DialogTitleRow(DialogNPCNameLabel + DialogHistoryButton)` 和 `DialogVisibilityOptions`；右侧 GridContainer 仅承载四类特殊交互。旧的 `DialogHeaderControls` 层已移除，避免右侧两行控件决定左侧标题的垂直位置。

`DialogPanel._refresh` 只在 `dialogue_kind=escape_intervention` 时显示 `DialogRoundLabel`，公开性始终由同组两个 CheckBox 投影并按 force / waiting / 已发首轮锁定。`_apply_plain_toggle_style` 清空 CheckButton 六种状态框；`_apply_stable_input_style` 从主题复制 normal StyleBox 同时覆盖 normal / focus，保留全局主题所有其他属性。

## T0299 模式快照与记忆节点接线

`NPCSystem → npc states / debug_get_behavior_mode_snapshot` 保存行为模式 previous / reason；`NPCSystem / CombatSystem / ActionSystem → MemorySystem` 只提交具体世界事实。MemorySystem 在 `add_event` 入口拒绝开发专用 `npc_mode_changed`，因此 EventBus、NPCPanel 记录、地点广播与 LLMBridge 短期记忆均不会收到模式日志。

## T0298 NPC / DialogPanel 节点接线

`Main.tscn` 的 NPCPanel 内容树以 `NPCCombatStrategyRow → NPCManagementButtonRow → NPCDialogueButton` 收尾；管理行只含等宽 `NPCGiveWeaponButton / NPCAssignButton`，对话按钮是 Content 的直接子节点并横向填满。旧 `NPCDialogueButtonRow / NPCDialogueHistoryButton` 已移除。

DialogPanel 的 Header 包含标题、`DialogHistoryButton`、公开性单选和独立特殊交互 Grid。公开性由同一 ButtonGroup 中的 `DialogPublicToggle / DialogPrivateRadio` 两个 CheckBox 表达，运行时把各状态 StyleBox 覆盖为空；四类特殊交互 CheckButton 不与公开性单选组混用。DialogPanel 根引用现有 `blacksmith_vertical_slice_theme.tres`，没有复制第二套主题资源。

历史按钮调用 `NPCPanel.open_dialogue_history(target_npc_id)`，继续复用 MemorySystem 的只读详情渲染；这是 UI 间导航，不新增事件写入或会话所有权。

## T0296 世界纯 Emoji 与人物框尾巴接线

`NPC.gd` 的运行时 `DialogueEmotionBubble` 不再创建 MeshInstance3D `BubbleBody` 或白色材质；节点树只有位于视觉层 20 的 `EmojiSprite`，纹理来自透明 `128×96 SubViewport`。渐隐只修改 Sprite3D alpha，人物副镜头排除逻辑不变。

`NPCPortraitViewport.gd` 继续在人物框 Overlay 内组合 PanelContainer 与两层 Polygon2D 尾巴。尾巴外轮廓从主体底边中心附近 `(34,57)–(46,57)` 收束到 `(55,70)`，Panel 后绘制会遮住基部内侧，使可见尾巴自然从底边中点露出；尖端不进入人物头部区域。

## T0295 暂停情绪动作接线

`TimeSystem.set_paused(true)` 继续只冻结游戏时间与权威模拟，不暂停 SceneTree。`NPC.gd` 仍通过 `EventBus.npc_dialogue_emotion_presented` 同步启动 Emoji 和角色临时表现；`ChibiCharacterPilot` 在自己的 `_process(real_delta)` 中仅识别临时 `happy / angry` 为暂停豁免，并用 real delta 推进其倒计时。

AnimationPlayer 的暂停速度由 `gameplay_paused && !pause_exempt_dialogue_emotion_action` 决定。暂停中情绪结束时先清理 transient，再将 `_animation_paused` 恢复为 TimeSystem 暂停值后解析权威状态，保证底层动画从第一帧开始就是冻结的。其他表现与权威系统无需改变 process mode。

## T0290 世界血条网格空间左对齐

`WorldHealthBar3D` 的 Track 与 Fill 是两个独立 `MeshInstance3D` billboard，必须共享完全相同的节点原点。Fill 宽度继续直接写入 `QuadMesh.size.x`；左对齐改为写入该网格的 `center_offset.x`，公式为 `-bar_width * (1.0 - ratio) * 0.5`。不得再用 Fill 节点的本地 X 位置表达左对齐，否则旋转父节点会让两个 billboard 获得不同世界原点。

组件调试快照额外公开 Track / Fill 位置和 Fill 网格中心偏移，供旋转父节点专项与 MCP 运行态验收使用；这些字段只读，不参与 HP 权威。

## T0289 对话情绪表现节点

`DialogSystem` 是回复情绪进入 Godot 的单一编排点：规范化后把 `emotion_id / emotion_label / emotion_emoji` 附加到 NPC 回合，并发出 `EventBus.npc_dialogue_emotion_presented(npc_id, presentation)`。`NPC.gd` 的运行时 `DialogueEmotionBubble` 只消费此信号并画世界气泡；`NPCPortraitViewport.gd` 在自己的 Control 树画第二人称气泡。二者不查询对话历史、不结算状态，也不互相控制生命周期。

世界气泡的 MeshInstance3D 与 Label3D 使用视觉层 20；`NPCPortraitViewport` 的相机已经排除该层，所以共享 World3D 仍不会把世界气泡重复拍进人物框。人物框气泡位于 SubViewportContainer 上方的独立 UI Overlay，主相机不可见。两个消费者都使用信号携带的 `hold_seconds=5.0 / fade_seconds=0.75`，后一条信号重置本 NPC 自己的显示计时。

## T0288 特殊请求状态与事件净化接线

- `DialogSystem.send_player_message(...)` 在请求前设置四类 `session_had_*_request`；`get_dialogue_state()` 统一投影 `session_had_special_interaction_request` 给 DialogPanel。
- `DialogPanel._refresh(...)` 只读取统一投影禁用取消，不自行判断哪类开关已经发送。
- `DialogSystem._publish_special_interaction_results(...)` 在回复落地时写独立结果；`end_dialogue(...)` 经过 `_sanitize_completed_dialogue_history(...)` 后再向 MemorySystem 写普通会话。
- `MemorySystem.REQUIRED_PAYLOAD_FIELDS.dialogue_turn` 不再要求特殊交互字段；`dialogue_special_interaction_result` 合同保持独立。

## T0287 GM 结果展台与 NPC 状态图标接线

- `GMPanel.gd` 创建命名结果按钮，统一调用 `DialogSystem.debug_preview_special_interaction_result(...)` 或 `debug_preview_escape_intervention_result(...)`；后者再进入 NPCSystem / CombatSystem。
- NPCPanel 的两个 TextureRect 是只读投影，随既有 `npc_state_changed` 刷新 `states.morale_boost / work_encouragement_boost`。SVG 只负责表现，不承载数值或状态。
- 正常逃离挽留响应把 `escape_intervention_result` 附在产生它的 NPC history turn 上，DialogPanel 据此生成结果行；模型原文保持不变。

## T0286 特殊反馈与逃离警报接线

- `DialogSystem.special_interaction_result` 广播已合法化的逐轮结果；`DialogPanel.gd` 只筛选 `success=true` 并驱动 `DialogSpecialSuccessDialog` 队列。
- `CombatSystem.start_npc_escape(...)` 在行为切换和 `escape_started` 入库成功后发出 `EventBus.npc_escape_started`；`HUD.gd` 驱动 `EscapeStartedAlertDialog` 队列。启动前校验失败、pending 与 already escaping 分支不会发信号。
- 两个 AcceptDialog 均属于正式 `Main.tscn` UI：成功窗按钮为“太好了”，逃离警报按钮为“好的”。业务状态仍由系统层拥有。

## T0285 工作鼓励接线

- `DialogPanel.gd` 只投影 DialogSystem 的四类 toggle 状态与 NPCSystem / CombatSystem 资格；`Main.tscn` 将特殊 toggle 放入 2×2 GridContainer，公开开关仍独立。
- `DialogSystem.gd` 保存工作请求持续状态、发送前复验并只在开启时交给 LLMBridge；回复结果绑定 history，完成对话后调用 NPCSystem。`none / escape` 保持 toggle，成功后关闭锁定。
- `NPCSystem.gd` 保存至当天 24:00 的工作 buff 并提供单一倍率查询；ActionSystem 与 BuildingSystem 只读取倍率，不复制状态。逃离继续复用 CombatSystem 正式出口流程。
- `GMPanel.gd` 只提供正式开窗和显式 Mock 请求；本地 HTTP 专项覆盖四选一、字段关闭、无关忽略、未入伍资格、1.2 倍率和失效。

## T0284 战斗策略对话接线

- `NPCPanel.gd` 仅通过 `NPCCombatStrategyValue` 投影 CombatSystem 当前策略，不再创建或连接 OptionButton。`DialogPanel.gd` 绑定 `DialogCombatStrategyToggle`，负责资格 / 互斥投影和每轮反馈。
- `DialogSystem.gd` 持有会话内策略请求状态，发送前复验资格，仅在开启时经 LLMBridge 携带上下文；收到结果后归一化并调用 CombatSystem。策略变更立即生效，因此本会话后续轮次读取新当前值。
- `GMPanel.gd` 只暴露正式开窗和同一 Mock 请求链；`tools/verify_wartime_dialogue.gd` 与本地 HTTP Mock 专项覆盖 toggle 持续、互斥、无关保持、合法切换及 NPC 面板只读边界。

## T0282 世界血条网格填充与敌军接线

- `WorldHealthBar3D.gd` 通过 Fill `QuadMesh.size.x` 表达归一化比例，节点 scale 恒为 `Vector3.ONE`；零比例隐藏 Fill，并在调试快照中公开实际填充宽度、网格宽度、可见性与 scale，避免 billboard 变换再次掩盖视觉误差。
- 组件新增实例级健康 / 危险颜色配置。CombatSystem 在普通 Area3D 敌军和正式 ActorMotionBody 敌军创建时统一挂载组件，使用同一橙色覆盖两档颜色，并在敌军 HP 刷新时同步。
- `tools/verify_t0282_world_health_fill_and_enemy_overhead.gd` 覆盖共享网格几何、NPC / 建筑权威比例、零血隐藏、敌军具体名称、名称上方位置与低血恒定橙色。功能可在正式 Main 直接观察，不新增 GM 入口。

## T0280 世界战时血条接线

- `scripts/world/WorldHealthBar3D.gd` 是共享 billboard 组件：暗色固定槽、左对齐填充、统一绿 / 红阈值，并提供只读调试快照。
- `NPC.gd` 与 `DefenseDeviceView.gd` 在自身实体下挂载组件，轮询活动敌人数处理和平 / 战时边界；状态快照刷新时同步比例。`StationLayoutController.gd` 仅在仓库、正门、主厅 NameLabel 创建时挂载组件，并从 BuildingSystem 刷新。
- `tools/verify_t0280_world_combat_health_bars.gd` 覆盖三座建筑白名单、NPC 文案布局、塔防名称、战时显隐和低血颜色；功能在正式 Main 可见，不新增 GM 入口。

## T0271 NPC / 马匹状态与 HUD 有效倍率接线

- `NPCPanel.gd` 在原 `NPCSatietyLabel / NPCFatigueLabel` 位置动态创建两个 VBox 行，顺序均为 Label → ProgressBar；进度范围通过 `NPCNeedsSystem.get_need_bounds(...)` 读取 `activity_needs.json`，危险色只属于 UI 投影。
- `HorsePanel.gd` 与 `BuildingPanel.gd` 只格式化既有 horse snapshot：模板、逐匹位置和内部 horse id 不进入玩家文本，稳定槽位后缀映射为中文“X号”；HorseSystem 数据与马厩顶部总量不变。
- `TimeSystem.format_time_scale_label(...)` 统一把可识别的小数倍率显示为分数（`1/60`）；`HUD.gd` 比较 snapshot 的 player / effective scale，只在外部约束确实降低倍率时禁用按钮并筛出最严格请求的显示原因。暂停按钮、TimeSystem 请求集合与数值推进权威不变。
- `verify_npc_panel_state.gd`、`verify_time_system.gd`、`verify_t0250_stable_horse_ui_and_click.gd` 覆盖结构、阈值、中文槽位、按钮锁定和释放恢复；正式前端可直接观察，不新增 GM 入口。

## T0270 HUDFrame 内容适配接线

- `Main/UI/HUD/HUDFrame` 的场景初始右下边界改为 `(629, 232)`；标题、资源条、倒计时、后端状态、底部按钮和能力按钮的位置均未移动。
- `HUD._get_hud_frame_content_end()` 只枚举常驻控件，并以 `max(size, combined_minimum_size)` 处理主题造成的按钮 / 文本扩张；`_fit_hud_frame_to_content()` 在右、下各增加 `12px` 后写回背景边界。
- `_build_resource_strip()`、资源刷新、后端状态刷新及动态倒计时 / 虔诚控件构建会合并请求 deferred 适配。`debug_get_hud_frame_layout_snapshot()` 只读暴露边界给专项和 MCP，不提供 UI 或玩法写入口。
- `tools/verify_t0270_hud_frame_content_bounds.gd` 在正式 Main `1280×720` 下断言器械 / 虔诚控件不越界、内容完整包含及稳定留白；功能可直接在正式前端观察，不新增 GM 入口。

## T0269 敌方远程建筑命中接线

- `CombatSystem._trace_combat_projectile_segment(...)` 把完整 projectile 交给建筑透明判断；判断从 `target_at_release.type/id` 读取释放时目标，不依赖当前锁或后续 AI 状态。
- 敌方弹体的目标为同一 `building/front_gate` 或 `building/main_hall` 时，对应 collider 不加入透明排除集，碰撞身份继续由 `_resolve_projectile_collision_identity(...)` 解析并提交既有建筑伤害入口。仓库沿用普通实体碰撞。
- `tools/verify_t0269_enemy_ranged_building_damage.gd` 在正式 Main 中分别保留一名正式弓手 / 弩手，以生产 selector → windup → release → projectile sweep 覆盖三座建筑；`verify_t0260...` 同时锁定后方单位 / 器械穿透语义。

## T0268 HUD / NPCPanel 精简接线

- `Main/UI/NPCPanel/.../Header` 在背景按钮后直接挂载 `NPCActionLabel` 与 `NPCBehaviorModeLabel`；`NPCPanel.gd` 分别格式化 `current_action` 和 `behavior_mode`，后者只在显示层降低颜色对比度。行动标签每次刷新都会重置颜色，仅 `current_action=escaping_station` 投影为警示红 `#dc6157`，其余恢复白色，避免切换状态或 NPC 后残色。
- `NPCInteractionVisibilitySelect` 已由同一 `ButtonGroup` 管理的 `NPCInteractionPublicRadio / NPCInteractionPrivateRadio` 替代；CheckBox 加入组后使用圆形单选外观，`allow_unpress=false` 保证始终有一项选中。
- `HUD.gd` 的 `_format_next_wave_arrival()` 负责把既有权威 `seconds_until` 包装为自然来袭句式；倒计时精度仍由 `_format_wave_countdown()` 和当前时间倍率决定。
- 相关专项覆盖节点位置、互斥状态、语义映射、精简文案、状态刷新和倒计时；功能均可在正式 Main 直接观察，不新增 GM 入口。

## T0266 移除无效弹药占位接线

- ResourceSystem 不再加载独立弹药商品，CraftingSystem 的正式配方集合也不再包含隐藏弹药配方；弓、弩、箭塔和弩床继续直接使用既有攻击节奏与物理弹体链。
- HUD 装备投影仅收集 `detail_group=weapon|armor` 的具体库存，再与 NPC 装备槽和存活马匹组合；不再创建空的弹药分类或图标资源依赖。
- 现有远程命中、塔防部署和战斗结算接口未新增替代库存，避免 UI 或调试层形成第二套弹药权威。

## T0265 HUD 库存图标窗接线

- `HUD.gd` 动态创建 `ResourceDetailPanel/ResourceDetailScroll/ResourceDetailGrid`：面板最小尺寸 `500×430`，内容为六列 `68×68` 图标按钮，横向滚动关闭、纵向滚动自动开启。原 `ResourceDetailText` 不再创建。
- 装备投影按 ResourceSystem 的 `detail_group=weapon|armor` 具体库存、NPCSystem 五个装备槽和 HorseSystem 全部存活马匹组合；器械投影按 DefenseDeviceSystem definition 的单项库存成本与活动 deployment 组合。每条投影带 icon / assigned / tooltip，但按钮不渲染文字。
- HUD 监听 `resource_changed / npc_state_changed / horse_state_changed / horse_assignment_changed / defense_device_state_changed`，只在对应详情窗打开时重建图标并保留滚动位置。`debug_get_resource_detail_snapshot()` 仅提供自动化 / MCP 只读 UI 投影，不修改库存或分配。
- `tools/verify_hud_resources.gd` 覆盖具体库存逐件数、剧情初装、马匹、穿盔 / 分马 / 部署实时刷新、灰暗态、精确 Tooltip、无 RichText 与滚动范围；功能直接在 Main 前端可见，不新增 GM 入口。

## T0264 NPCPanel 装备窗口接线

- `Main/UI/NPCPanel/NPCGiveWeaponButton` 保留稳定节点名但玩家文案改为“装备”；`NPCEquipmentLabel` 静态隐藏，旧运行时 weapon / armor / horse 行不再创建。`NPCCombatStrategyRow` 继续独立存在。
- `NPCPanel.gd` 在 `Main/UI` 下动态创建 `NPCEquipmentWindow`，使 `316×332` 窗口不参与右侧信息面板的 minimum-size 计算；窗口右缘对齐人物副镜头右缘、顶部接在副镜头下方，并随 NPCPanel 拖动 / 响应式布局更新。
- `NPCEquipmentWindow.gd` 复用 `EquipmentSilhouette.gd`，六槽顺序和坐标与 NPCDevLab 一致；选择窗位于装备窗左侧。确认 / 提示 Dialog 作为窗口子节点，只在用户操作时出现。
- `tools/verify_t0264_npc_equipment_window.gd` 通过 NPCPanel debug 投影覆盖 UI 与权威状态；`verify_equipment_system`、`verify_npc_panel_interactions` 和骑乘回归已迁移到单按钮合同。

## T0263 全槽位瞄准矩阵接线

- `tools/verify_t0263_enemy_ranged_all_defense_slots.gd` 读取 `T0263_SLOT_ID / T0263_DEVICE_ID`，每次实例化正式 Main，只部署一个活动器械并保留一名正式第三波弓手；测试夹具仅选择合法射程 / 无遮挡射线，索敌、windup、release、物理 sweep 与扣血均走生产链。
- `tools/verify_t0263_enemy_ranged_all_defense_slots.ps1` 枚举 8 个正式槽位和 `wall_arrow_tower / wall_ballista`，形成 16 个隔离进程用例，避免前一器械、残箭、敌军状态或废墟影响后续项。
- 主厅东北位的北侧射线会被诊所正式 collider 合法阻挡，因此该用例使用东侧无遮挡射线；没有关闭诊所碰撞、扩展透明建筑列表或绕过物理弹体。
- Godot MCP 正式 Main 同时部署 8 座箭塔，并通过 CombatSystem / Presenter 生产快照确认每个槽位 `aim position == InteractionArea/CollisionShape3D global position`。

## T0262 主厅塔防远程受击接线

- `DefenseDeviceView.get_combat_projectile_target_snapshot()` 从活动 `InteractionArea/CollisionShape3D` 返回真实世界中心、deployment 身份和节点路径；Area 仍使用 interaction + projectile layer 6，不新增会阻挡角色的 Body。
- `DefenseDevicePresenter.get_projectile_target_snapshot(...)` 只接受可见、活动且 HP 大于零的 deployment。CombatSystem 在敌方远程 release 时读取该快照，并将 `aim_target_source / aim_target_node_path` 写入活动与终态弹体诊断。
- 若正式器械受击视图暂不可用，保留旧宿主代理点作为兼容瞄准回退；近战 target position、敌军攻击位和主厅 / 正门的实体碰撞没有改动。
- `tools/verify_t0262_enemy_ranged_main_hall_device_hit.gd` 使用正式 Main 部署主厅箭塔和正式第三波弓手，覆盖直接 release 诊断以及生产 selector → windup → release → sweep → deployment HP 的自然链。

## T0261 已部署塔防点击与面板接线

- `DefenseDeviceView/InteractionArea` 在活动状态写入 `deployment_id / device_id` metadata；废墟状态移除 metadata、关闭 collision layer 和 `input_ray_pickable`。不新增 Body、碰撞层或权威数据。
- `Main/WorldRoot/Station/DefenseDevices` 的 DefenseDevicePresenter 提供 interaction layer 4 的 area-only 屏幕射线，跳过其他 Area 后只接受仍有效且可见的 deployment。`Main/Systems/BuildingSystem._unhandled_input(...)` 在正式建筑美术拾取前调用该接口并转发既有点击事件，解决围墙 / 主厅外壳抢占。
- `Main/UI/DefenseDevicePanel` 绑定 `scripts/ui/DefenseDevicePanel.gd`，运行时生成紧凑只读字段并监听选择 / 状态信号。`Main/WorldRoot/Station/Effects/AttackRangeIndicator` 接线不变，同一 `defense_device_clicked` 事件刷新权威有效射程。
- `tools/verify_t0261_defense_device_selection_panel.gd` 在正式 Main 用生产相机、物理 Area 和 `SceneTree.push_input(...)` 覆盖围墙 / 主厅器械选择、面板互斥、六项属性与范围圈；功能可直接前端验证，不新增 GM 入口。

## T0260 正门 / 主厅弹体透明接线

- `Main/Systems/CombatSystem` 的通用弹体 ray sweep 在命中继承 `building_id=front_gate / main_hall` 的 collider 后，先核对本发 `target_at_release`；只有宿主不是本发敌方建筑目标时才排除该 RID 并沿原子步线段继续查询。`transparent_building_skip_count / transparent_building_skipped_ids` 写入活动、终态与残箭快照。
- 正门与主厅原有 `StaticBody3D` 仍保持 world-static layer 1 / actor-body mask 2，并继续进入生产 NavigationMap；没有关闭 `CollisionShape3D`，NPC、敌军、马匹和商车不能因本次修改穿过实体。
- `DefenseDeviceView/InteractionArea` 使用 layer 6（interaction 4 + projectile 2），仍是没有阻挡 Body 的 `Area3D`。活动器械直接携带 deployment 身份；敌方弹体可命中，友方 / 塔防弹体跳过同阵营器械，废墟状态仍关闭该 Area。
- `tools/verify_t0260_projectile_transparent_gate_main_hall.gd` 在正式 Main 同时验证 raw physics ray 先撞实体、Combat sweep 穿透、后方敌人命中、主厅箭塔直接扣血及主厅 HP 隔离。

## T0259 取马路线与正式战斗世界交接

- CombatSystem 的空 `clear_spawned_enemies()` 不再执行战后行为模式退出；波次替换仍清理真实敌军 / battle / formal runtime，但“生成前场上为空”不会解散预战集结。
- HorseSystem 以 assigned horse 的 pickup waiting phase 为权威，公开 `ensure_wartime_mount_route(...)`。正式世界迁移、rally→combat 或其他状态写入停掉 NPC ActorMotion 后，只重建骑手到原 `target_position` 的 NavigationAgent 路线，不改人物 / 马匹世界坐标、分配或目标锁。
- CombatSystem 的 mounting watchdog、接敌交接和重复警铃复用该接口；同步完成上马时始终读取回调后的最新 rally，避免旧 `mounting` 快照覆盖 `moving / combat_ready`。
- `tools/verify_t0259_mount_pickup_enemy_handoff.gd` 使用正式 Main 与 GM 波次参数覆盖导航图迁移、接敌、目标锁、重复警铃恢复和最终上马。

## T0258 正式治疗 pending 空间交接

- ActionSystem 不再用任意 `current_action.begins_with("moving_to_")` 判断治疗路线已启动；必须同时匹配当前伤员的 `healing_target_<npc_id>` movement target 与 formal session 的 `healing_route_started`。战后日程、集结回收或旧地点移动因此不能冒充治疗路线。
- 同一治疗 pending 的重复派发通过 deferred preview/navigation 同步重新调用幂等接近逻辑。NPCSystem 仍是路线、实体运动、到位与 formal session 权威；GMPanel 只在 route started / active 后显示成功。
- `tools/verify_t0258_heal_pending_handoff.gd` 使用正式 Main 和真实战斗世界覆盖单次命令、旧移动竞态、重复命令及最终实体到位，不新增场景节点、Autoload 或结算接口。

## T0257 战后治疗路线与装备表现投影

- NPCSystem 的 formal healing session 保存 `healing_direct_world_route`，接近目标读取伤员 CharacterBody 当前世界坐标，不再以战前语义地点作为第一段路线。候选站位排除其他角色；导航卡死后有限换位并临时关闭治疗者对 actor 层碰撞 / RVO，世界层与生产 NavigationMap 始终保留，到达 / 失败 / 中断恢复默认设置。
- ActionSystem 只在实际到位后提交 helper、首付与治疗；GMPanel 和计划派发共用该接口。MemorySystem 在 generic `moving_to_*` 前识别 `moving_to_healing_target_*`，避免合成 target id 进入 BuildingSystem。
- ChibiCharacterPilot 的装备节点继续只读 EquipmentSystem。主武器显隐要求战斗权威或 `attack / training_instructor / training_practice / mounted_attack / mounted_training`，工作移动及循环隐藏主武器；既有 action-specific 汤勺、扫帚、锄、锤、医疗包和扳手继续按工作状态显示。

## T0256 行为模式空间连续性交接

- `Main/UI/HUD/DismissRallyButton` 与 AlarmButton 同层相邻；HUD 只调用 `CombatSystem.dismiss_combat_rally("hud")`，不自行筛 NPC、恢复计划或写位置。
- CombatSystem 只把权威模式仍为 `rally` 的 NPC 交给 NPCSystem 返回工作；战斗 / 避战不响应解散。rally timeout 和敌军清空的 rally / avoid 退出也请求 DailyPlanSystem 恢复已捕获的当前计划，combat 退出继续走既有战后重评估。
- NPCSystem 在工作→rally / combat / avoid 打断前让 DailyPlanSystem 捕获运行中的计划项，并在任何行为模式打断内部锁定 / 恢复同一世界坐标。正式战斗世界开始前同样快照默认正式居民坐标；结束时只为旧兼容 actor 恢复旧空间，默认正式居民保留结束位置和生产 NavigationMap。
- `tools/verify_t0256_mode_transition_continuity.gd` 使用正式 Main、实际 HUD signal、正式波次 / 索敌 / 清敌接口覆盖六类转换、计划续接、按钮范围与首帧移动上界。

## T0255 NPC 姿态化交互碰撞接线

- `scenes/npc/NPC.tscn/InteractionArea` 保留原 `InteractionCollision` 站立胶囊，并新增同层 `UnconsciousInteractionCollision`：沿角色局部 X 轴水平放置、贴近地面，仍只使用 interaction layer 4，不参与实体碰撞、导航或战斗射线。
- `NPC.gd._sync_unconscious_physical_entity()` 在投影权威昏迷状态时互斥启用两种点击形状；昏迷仍关闭 `BodyCollision` 与 RVO，交互 Area 保持可拾取。复苏恢复原站立形状。
- NPCSystem 的生产相机拾取、`EventBus.npc_clicked` 与 NPCPanel 接线不变。`tools/verify_t0255_unconscious_npc_body_click.gd` 覆盖形状轴向、倒地身体 / 旧站立热区射线、面板选择与复苏恢复。

## T0250 马厩卡片与马匹点击接线

- 不新增场景节点、Autoload、碰撞层或 GM 控件。`Main/UI/BuildingPanel` 从既有 HorseSystem 快照构建实际在厩卡片，并为动态 ProgressBar 应用局部样式；`Main/UI/HorsePanel` 仅删除冗余说明 Label。
- `Main/Systems/BuildingSystem._unhandled_input(...)` 先调用统一马匹路由：离厩命中直接转发到 HorseSystem 选择，在厩命中继续结合 `StableArt.is_interior_revealed_for_selection()`；随后才进入建筑 / 室内 NPC 拾取。
- `tools/verify_t0250_stable_horse_ui_and_click.gd` 在正式 Main 覆盖离厩过滤、五类颜色、冗余节点删除与离厩马点击互斥；T0170 继续覆盖透明 / 不透明马厩三路径。

## T0249 固定目标近战引导恢复接线

- 不新增场景节点、Autoload、NavigationMap 或 GM 控件。`Main/Systems/CombatSystem` 从既有引导 target 计算 request 级到点余量，并将其通过 `_get_combat_motion_options(...) / update_motion_target(...)` 同步到正式敌军 ActorMotionBody。
- `ActorMotionBody.request_motion(...)` 对 enemy combat supersede 保留独立静止采样；`set_runtime_actor_collision_enabled(...)` 在脱困窗口把 body mask 从 `world_static|actor_body` 暂时切为 `world_static`，完成 / 取消 / 清敌时恢复。调试快照公开覆盖原因。
- `tools/verify_t0180_gate_attack_positions.gd` 使用正式 Main 和 GM 第一波覆盖 8 人自然接近、全员真实伤门和恢复还原；T0243 覆盖自占区排除与跨 request 静止计时，T0186 的隔离门面夹具适配非独占引导语义。

## T0248 物理箭矢穿透与附着接线

- `Main/Systems/CombatSystem` 继续在 `_physics_process` 推进 `Main/WorldRoot/CombatProjectiles/*`。活动 ray query 仍使用 mask `3` 并查询 body / area；每次命中同阵营角色时把该 collider RID 加入当前 projectile exclusion 后继续扫完余下线段，不改场景碰撞层。
- `CombatProjectileView.stick_at(...)` 在终态保留箭节点。世界命中重挂到实际 collider Node3D；NPC 命中重挂到 `Main/WorldRoot/Station/NPCs/*`；敌军命中在伤害前重挂到其 `EnemyArtView`，所以既有 `_preserve_enemy_defeat_presentation(...)` 会把箭连同步行 / 骑乘尸体包装一起保留。
- 不新增场景节点、Autoload、资源或 GM 控件。`tools/verify_t0248_projectile_friendly_pass_through_and_stick.gd` 覆盖双向同阵营穿透与附着清理，`tools/verify_t0248_ranged_release_lock_and_interrupt.gd` 覆盖目标移出射程和受击 release 边界；T0143 夹具改用生产 NavigationMap 开放区以避开主厅真实碰撞。

## T0244 后门战时碰撞运行接线

- `Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/BackGateArt` 继续由 FormalGateArtView 生成两扇 AnimatableBody 门叶；不新增场景节点、Autoload、碰撞层或 NavigationRegion。
- 每个物理更新只为配置开启的后门读取 `Main/Systems/CombatSystem.get_active_enemy_count()`。大于 0 时对两个 `DoorLeafCollision` deferred disable，回到 0 时恢复；FrontGateArt 不启用该配置。
- `tools/verify_t0244_rear_gate_combat_passthrough.gd` 在正式 Main 覆盖 0 / 8 / 0 敌军边沿、两块真实 CollisionShape、敌我 CharacterBody 双向通行和正门不受影响。

## T0243 动态攻击引导运行接线

- 不新增场景节点、Autoload、NavigationMap、碰撞层或伤害 Area。`Main/Systems/CombatSystem` 复用 StationLayoutController 已提供的建筑包络、正门门板和塔防 `host_proxy_regions`，把原候选位置装饰为竖直圆柱引导区。
- 正式敌军继续由 `Main/WorldRoot/FormalStationLayout/FormalEnemies/*` 下的 ActorMotionBody 提供实际 Transform；占区读取 `data/physics_navigation.json` 的 `enemy_foot / enemy_mounted` 半径与高度，移动仍走同一生产 NavigationMap。
- `data/station_layout.json.c3_p7_dynamic_assault.attack_position_policy` schema 升为 `enemy_attack_guidance_zones_v2`。`tools/verify_t0243_guided_attack_zones.gd` 在正式 Main 覆盖正门、城墙塔防、真实体积计数、动态换区和未到圆心的射程交接。

## T0241 敌军重定向动量接线

- 不新增节点、Autoload、信号或导航资源。CombatSystem 只在既有 `_get_combat_motion_options(...)` 中为 `enemy_*` 请求声明替换时保留速度；ActorMotionBody 仍独占 CharacterBody velocity、NavigationAgent RVO、路径、碰撞、制动和到达。
- request 替换仍发送既有取消 / 开始信号并重建目标合同，但在新请求初始化完成后恢复受 profile 上限限制的水平速度。该速度在下一物理帧进入原有路径和避障流水线，不改变攻击位租约、候补优先级、精确到位恢复或攻击交接。
- 现有正式动态波次快照已经嵌入每个 Actor 的 `debug_get_motion_snapshot()`，因此新增速度字段自动出现在 GM / 测试读取路径，不需要新面板节点。

## T0240 战斗避战接线

- 不新增节点、Autoload、信号或导航资源。`Main/Systems/CombatSystem` 从现有活动敌军构建避战威胁场，以最近威胁触发、以全部威胁加权选点，并通过 `Main/Systems/NPCSystem.move_npc_to_world_position(...)` 提交给 NPC 原有 `ActorMotionBody / NavigationAgent3D`。
- CombatSystem 同时读取 `NPCSystem.is_npc_world_movement_active(...)`，使避战策略状态与底层物理请求保持一致；中断恢复仍走同一 NPCSystem / ActorMotionBody 权威，不在 UI 或 GM 中复制位移。
- `NPC.gd` 与 `MemorySystem.gd` 只把 `moving_to_combat_strategy_avoid_* / combat_strategy_avoid_holding` 投影为“正在避战 / 避战待命”。`tools/verify_t0240_combat_avoid_strategy_threat_trigger.gd` 直接实例化正式 Main 覆盖近敌触发、锁定保持、策略切换与中断恢复。

## T0242 敌方骑兵人马原地共同阵亡接线

- `CombatSystem._preserve_enemy_defeat_presentation(...)` 仍在权威敌军移除前把 `EnemyArtView` 重挂到敌军表现根，但骑兵分支改为调用 `begin_mounted_shared_defeat(2.4)`；已删除前门、出生区和地图边缘逃跑目标计算。
- `EnemyMountedArtView` 在阵亡边沿记录包装根、马匹本地根和马匹世界坐标，播放骑手 `Death_A` 与 `merchant_horse.glb/Death`。`_process` 只按 TimeSystem 战斗秒推进尸体保留计时并固定马根，不再提交任何 Transform 逃离位移；马匹 Death 强制非循环并在完成信号后 seek / pause 于末帧。
- `defeat_cleanup_completed` 在统一保留时间到期时携带最后零漂移快照并释放整个包装，人马不会分开清理。NPCDevLab 使用同一方法与信号，旧 `mounted_defeat_escape`、逃跑速度 / 方向 / 距离接口均已移除。

## T0236 敌军移动表现接线

- `Main/Systems/CombatSystem` 在 `_physics_process(delta)` 中读取正式敌军 `ActorMotionBody` 所在 CharacterBody 的全局位置，缓存水平位移 / 速度 / 方向，并把结果送入既有敌军表现刷新。
- 步兵继续调用 `ChibiCharacterPilot.apply_profile(... moving, movement_speed ...)`；骑兵继续调用 `EnemyMountedArtView.apply_state(...)`，同步骑手 `mounted_walk` 与马匹 Walk。场景树、AnimationPlayer 资源和骑乘绑定未改。
- `tools/verify_t0236_enemy_locomotion_presentation.gd` 实例化正式 Main 并覆盖步骑错位、`0.06 m/s` 拥挤爬行、真实 AnimationPlayer 片段 / playing / 播放倍率、停止和攻击优先级；现有第五波 GM 入口足以直接观察，因此未新增按钮或调试节点。

## T0235 远程战术移动恢复接线

- `Main/Systems/CombatSystem` 继续选择我方远程攻击点，经 `Main/Systems/NPCSystem.move_npc_to_world_position(...)` 提交给现有 NPC `ActorMotionBody`；NPCSystem 新增只读 `get_npc_world_movement_progress(...)` 转发最小运动进展，不取得物理控制权。
- `ActorMotionBody` 的独立静止采样跨 `update_motion_target(...)` 保留。CombatSystem 在 `2.25 s` 门槛后排除旧点、重走既有圆弧 / NavigationMap / 攻击线筛选；目标锁和伤害结算路径不变。
- `tools/verify_t0235_friendly_ranged_tactical_recovery.gd` 在正式 Main 覆盖步行 / 骑乘弓弩、动态目标更新不清静止证据、换点距离、到达容差和真实攻击 handoff；没有新增场景节点或信号。

## T0233 固定目标远程攻击位接线

- `CombatSystem._get_enemy_attack_position_row_specs(...)` 对远程 `building / defense_device` 读取统一六排配置；`_get_oriented_building_attack_position_candidates(...)` 和 `_get_defense_device_attack_position_candidates(...)` 沿既有受击表面展开，不改场景碰撞体或器械展示节点。
- 正门继续使用现有 `target_outlines.front_gate.position_count=5` 门板表面点；仓库 / 主厅继续读取 BuildingSystem 提供的旋转包络，主厅角落塔防继续读取 StationLayoutController / DefenseDeviceSystem 的双墙 `host_proxy_regions[]`。
- 没有新增节点、信号、Autoload 或 NavigationMap。现有 `debug_get_enemy_attack_position_snapshot()` 可直接观察六排 slot、租约、候补和区域身份。

## T0232 保持距离撤离接线

- `Main/Systems/CombatSystem` 在 `_advance_single_npc_combat_attack(...)` 的目标锁之前处理撤离优先级，并把段运行态写入 `Main/Systems/NPCSystem` 的 NPC states。NPCSystem 仍通过 `move_npc_to_world_position(...)` 连接 NPC CharacterBody 下的 ActorMotionBody / NavigationAgent3D。
- `Main/Presentation/StationLayoutController.resolve_station_avoidance_navigation_target(...)` 同时服务非战斗避战和保持距离撤离，负责 `interior_polygon`、实体包络与生产 NavigationMap 修正。没有新增场景节点或专用导航资源。
- 撤离途中动作名为 `keep_distance_retreating`，目标 ID 保存在 `movement_target / keep_distance_retreat_target_id`；不使用 `moving_to_<building>` 文案，避免信息地点格式器把战术点误认成建筑。

## T0231 运行节点与调试字段

- `Main/Systems/CombatSystem` 管理 `_enemy_precise_arrival_recoveries`，并把活动项与计数投影到既有攻击位调试快照。
- 正式敌军 `ActorMotionBody` 新增 `set_runtime_avoidance_enabled(...)`；它只切换子节点 `NavigationAgent3D.avoidance_enabled` 并清空陈旧 safe velocity，不换导航图、不瞬移、不改碰撞层。
- 生产场景树与 `.tscn` 无变化；新专项直接实例化 `Main.tscn`，用正式主厅 slot03、正式敌军 Actor 和生产攻击位租约验证交接。

## T0230 主厅角落双墙代理运行接线

- 不新增节点、碰撞体、NavigationMap、信号或 Autoload。`Main/Presentation/StationLayoutController` 复用 `MainHall/StaticCollision` 现有 `back_wall / front_left / front_right / left_wall / right_wall`，为四个角槽各生成两组只读墙面代理。
- `Main/Systems/DefenseDeviceSystem` 将区域列表投影到活动塔防目标；`Main/Systems/CombatSystem` 在原 8 位租约上限内按两面墙生成 `4 + 4` 候选，并让真实近战 / 弹体碰撞匹配任一区域。屋顶 DefenseDeviceView、发射点和主厅碰撞均未移动。
- `tools/verify_t0230_main_hall_corner_dual_wall_contact.gd` 覆盖四槽双墙、候选分布、两墙扣血、远端拒绝和主厅 HP 隔离；T0228 专项改为按候选所属区域验证墙面。

## T0229 远程攻击位运行接线

- 不新增节点、信号、Autoload、NavigationMap 或配置字段。`Main/Systems/CombatSystem` 在既有友军攻击预算中生成 `range × 0.95` 圆弧攻击位，并继续调用 `Main/Systems/NPCSystem.move_npc_to_world_position(...) → NPC / ActorMotionBody`。
- 圆弧候选使用 `Main/Presentation/StationLayoutController` 的生产 NavigationMap，通过 NavigationServer3D 吸附 / 验路；正式 world-static 射线只用于筛选攻击线，不承担伤害。现有弹体 / 近战接触仍是唯一命中结算入口。
- `tools/verify_t0225_station_breach_global_friendly_targeting.gd` 增加步行弓 / 弩攻击位和 stale request 恢复；`tools/verify_t0229_mounted_gate_wave_handoff.gd` 自然覆盖四骑手集结、正门切敌、第五波与重复警铃。

## T0228 主厅墙面代理与槽位等级接线

- 不新增场景节点、碰撞体、NavigationMap、信号或 Autoload。`Main/Presentation/StationLayoutController` 从现有 `MainHall/StaticCollision` 的 `back_wall / front_left / front_right` 生成四槽宿主代理，向 DefenseDeviceSystem 追加只读墙面外向方向。
- `Main/Systems/CombatSystem` 继续使用原攻击位租约、ActorMotionBody 和真实模型接触链；仅将主厅塔防的接敌法线从器械展示朝向切换为宿主墙面法线。屋顶 `DefenseDeviceView` 的位置、旋转、发射点和攻击表现均不移动。
- `data/defense_device_defs.json`、`data/station_layout.json` 与 `data/building_fixture_layouts.json` 同步改为前侧 `slot_03/04` 先出现、背侧 `slot_01/02` 后出现；`tools/verify_t0228_main_hall_defense_wall_contact.gd` 覆盖四墙段真实碰撞与扣血。

## T0227 刚上马集结运行接线

- 不新增节点、信号、Autoload 或数据字段。`Main/Systems/HorseSystem` 仍在上马完成时调用 `Main/Systems/CombatSystem.handle_npc_mount_ready(...)`；该回调现在统一进入现有 `_start_npc_rally(...)`。
- 集结依然通过 `NPCSystem.move_npc_to_world_position(...) -> NPC.move_to_location(...) -> ActorMotionBody` 使用 `combat_rally_<npc_id>` 请求，新增 `movement_purpose=friendly_rally` 只作运行诊断。正门自动开合、骑手 / 马匹实体、RVO 和 T0221 单调出门前缀均不变。
- `tools/verify_t0227_mount_auto_rally_and_recovery.gd` 在正式 Main 自然跑通站外接敌取马、正门内侧中断恢复、门外到位和遇敌切换。

## T0226 避战移动恢复接线

- 不新增节点、信号、Autoload 或配置。`Main/Systems/CombatSystem` 读取 `Main/Systems/NPCSystem.is_npc_world_movement_active(...)`，并仍经 NPCSystem 向原 NPC ActorMotionBody 补发 `avoid_shelter_<npc_id>` 请求。
- 新诊断字段位于现有 `debug_get_combat_snapshot().active_avoidances[]`，GMPanel 无新写入接口。`tools/verify_t0226_avoidance_motion_recovery.gd` 在正式 Main 中中断 Actor 请求并验证圈内 / 离圈恢复和自然位移。

## T0225 第五波破防友军索敌接线

- 场景树与信号不变：`Main/Presentation/StationLayoutController.is_world_position_inside_station(...)` 继续提供唯一站内事实，`Main/Systems/CombatSystem` 在接触扫描和友军攻击预算中把该事实投影为共享 `station_breach_global` scope。
- `debug_get_friendly_targeting_snapshot()` 的每名锁增加 `station_breached / station_enemy_only`，顶层增加 `station_breach_target_scope`；现有 GM“一键征召&配装”“所选波次动态群战”和敌人快照即可观察，不新增写目标的节点或按钮。

## T0224 警铃集结运行接线

- 不新增场景节点、信号、Autoload 或配置字段。`HUD/AlarmButton` 与 `GMPanel/CombatAlarmButton` 继续调用同一个 CombatSystem 接口；最后警铃快照新增 `target_locked_count` 并在 `ignored[]` 中给出 `target_locked / locked_enemy_id`。
- `CombatSystem._get_rally_eligibility(...)` 读取 NPCSystem / EquipmentSystem 快照并保留已上马事实；`_start_npc_rally(...)` 对响应者清理旧模式运行态，已骑乘者直接发 `combat_rally_*` 世界移动，未骑乘者等待 HorseSystem 完成会合后由原回调发起移动。
- `tools/verify_t0224_unified_alarm_rally.gd` 在正式 Main 同时覆盖睡眠日常、避战、旧集结、无目标战斗、已锁目标、未上马、已上马以及 5 米外正常索敌打断。

## T0223 主厅部署 UI 与昏迷动画接线

- `Main/Systems/DefenseDeviceSystem` 从主厅槽配置读取 `1.0x` 基础倍率；`Main/UI/DefenseSlotPresenter` 沿用通用“倍率为 1 时隐藏”规则，主厅弹窗不再创建可见高台加成说明。场景节点、器械 Presenter 和攻击圈节点不变。
- `ChibiCharacterPilot._play_state(...)` 对已经完成的 `unconscious / mounted_fall` 非循环状态直接保持当前末帧，不再因 `NPC.update_profile(...)` 重复调用 `AnimationPlayer.play(Death_A)`。复苏仍由 `apply_profile(...)` 检测权威昏迷边沿并启动原 `get_up / Lie_StandUp` transient。
- `tools/verify_t0223_main_hall_range_and_unconscious_pose.gd` 在正式 Main 校验六级主厅倍率 / 弹窗，再用正式 NPC 包装验证倒地末帧、重复刷新零回卷和真实复苏片段。

## T0222 EnemyPanel 与共享世界人物窗接线

- `Main/UI/EnemyPanel` 绑定 `scripts/ui/EnemyPanel.gd`，运行时创建左侧 `NPCPortraitViewport` 与右侧纯属性列；它与 NPCPanel 共用 UI 主题、右上对象面板层级和响应尺寸合同。
- `NPCPortraitViewport.gd` 不复制敌军模型，而是让 SubViewport 共享 Main World3D，并按 `target_kind` 从 NPCSystem 或 CombatSystem 读取人物快照。骑乘只改变局部相机焦点 / 高度，不更改世界 Camera3D 或 Actor Transform。
- 敌军选择由正式 Actor 的既有 InteractionArea 发出 `EventBus.enemy_clicked`；NPCPanel、HorsePanel、BuildingPanel、MerchantPanel、NoticeBoardPanel 与 AttackRangeIndicator 监听该事件完成互斥收口。没有新增 Autoload、碰撞层、存档字段或权威结算节点。

## T0221 通用出口前缀运行接线

- 不新增场景节点、NavigationMap、Link 或 Autoload。`StationLayoutController.get_indoor_exit_navigation_prefix(...)` 在原字典中增加 `exit_forward_direction / skipped_point_ids`；所有使用 ActorMotionBody 的 NPC、敌军和独立马匹自动继承。
- ActorMotionBody 保存归一化出口方向，`update_motion_target(...)` 对室外新目标保留活动点列，`_physics_process(...)` 在取 NavigationAgent 当前腿前推进已经越过的路线横截面。快照新增 `indoor_exit_prefix_target_update_preserved_count`，可区分正常保留与新请求重建。
- `tools/verify_t0221_monotonic_building_exit.gd` 覆盖全部建筑矩阵与真实 NPC 的刷新 / 外力位移；`tools/verify_t0221_mounted_stable_exit.gd` 驱动四名正式骑手自然上马、离厩和集结，并记录阶段回退与门外纵向回退。

## T0220 敌方远程建筑多排接线

> 历史基线：T0233 已把此接线扩为建筑 / 塔防统一六排，未改变下述节点边界。

- 不新增场景节点、NavigationMap、信号或 Autoload。`CombatSystem._get_enemy_attack_position_row_specs(...)` 读取 `ranged_building_row_range_ratios`，并由原正门前线 / 旋转建筑四面候选生成器展开多排。
- `Main/Systems/CombatSystem` 的既有敌军 ActorMotionBody 继续向选中的吸附槽位移动；租约 slot id 的 row 段保证各排独立预约。GM 动态第 3～5 波与现有敌人 / attack-position 快照可直接观察三排，无需新增 GM 按钮。
- `tools/verify_t0220_enemy_ranged_multirank_building_positions.gd` 验证三建筑数量、三类远程角色、排距 / 胶囊间隔、近处选择内排，以及近战与塔防单排不变。

## T0214 正门回站与战时开门接线

- `StationLayoutController.get_front_gate_inside_avoidance_target()` 读取 `friendly_station_response.outside_avoidance_reentry`，沿实际 FrontGate 根的局部 `-Z` 内侧方向取点、吸附生产 NavigationMap，并复验站内多边形与实体包络。未新增 NavigationMap、Link 或位移节点。
- `FormalGateArtView/FriendlyApproachSensor` 在战时仍只接受 `npc_id / MerchantWagon`，继续排除 `enemy_id`。`LeftDoorHinge / RightDoorHinge` 保持 AnimatableBody3D 实体门叶；新增 `FixedGateCombatContactArea` 使用独立第 4 碰撞层（bitmask `8`）、无 mask、非阻挡，只在敌军当前攻击 `front_gate` 时加入近战 / 弹体查询 mask，友军攻击不会碰到该层。
- 正门攻击候选仍从 StationLayoutController 的静态门体轴向和 CombatSystem 五槽配置生成，不引用活动门叶 Transform 或 Area 状态。

## T0212 骑兵败退速度接线（已由 T0242 废止）

- 历史实现曾把 `enemy_waves.move_speed` 传入包装推进逃马；T0242 后 `setup(...)` 不再接收速度，正式与 DevLab 均反向验证阵亡坐骑零位移。TimeSystem 战斗帧桥现只推进共同尸体保留计时与动画倍率。

## T0210 室内出口前缀运行结构

- 不新增节点、Autoload 或 NavigationMap。`Main/Presentation/StationLayoutController` 新增 `get_enterable_building_at_world_position(...)`、`is_world_position_inside_enterable_building(...)` 和 `get_indoor_exit_navigation_prefix(...)`，返回已有世界路线点。
- 所有友方 NPC CharacterBody 与正式敌军 ActorMotionBody 在 `request_motion(...)` 时检查前缀；NavigationAgent3D 的活动 target 在四个 authored 点之间切换，公开快照中的 `target_position` 始终是最终目标，`navigation_leg_target_position` 才是当前腿。
- 取消 / 失败 / 最终抵达清理前缀；外部位移在仍处室内时重建、已移出建筑时清除。现有敌人快照和 NPC motion 快照即可观察，无需场景节点或专用 GM 权威。

## T0209 站内避战运行结构

- 不新增节点、Autoload 或信号。`Main/Systems/CombatSystem` 负责圈内敌军采样、逆平方方向和避战运行态；`Main/Presentation/StationLayoutController.resolve_station_avoidance_navigation_target(...)` 负责多边形、实体包络、生产 NavigationMap 与路径可达修正。
- `Main/Systems/NPCSystem.move_npc_to_world_position(...)` 仍把最终点交给 NPC CharacterBody 下的 ActorMotionBody / NavigationAgent3D。`active_avoidances` 只保存运行态目标与诊断，不建立第二张导航图，也不进入逃离状态机。

## T0208 正门五槽接线

- 不新增节点、信号或场景资源。`StationLayoutController.get_building_combat_geometry("front_gate")` 继续输出门体轴向；CombatSystem 从 `attack_position_policy.target_outlines.front_gate` 读取五槽 / `4.8 m` 宽度并生成门板平面候选。
- `LeftPostCollision / RightPostCollision` 继续作为双塔实体和导航烘焙源，但候选生成不再读取塔面偏移或专用站距。现有 GM 动态第一波与敌人快照直接显示 5 个 `front_*_of_05` 租约和 3 个 waiter。

## T0204 正门塔体与攻击位接线

- `StationLayoutController._build_gate(...)` 读取 `front_gate.tower_collision`，在既有 `LeftPostCollision / RightPostCollision` 节点生成 `2.35 × 5.05 × 3.55 m` BoxShape，局部中心为 `x=±4.175, y=2.525`。节点保持 layer 1 / mask 2、`formal_navigation_source` 与 `building_id=front_gate`，并标记 `gate_structure_role=side_tower_body`。
- `get_building_combat_geometry(...)` 对前后门返回 `gate_combat_geometry_v1`，轴向直接读取旋转后门根 basis；无专用塔配置的后门回退既有 `gate_post_width`。CombatSystem 的建筑目标和正门候选因此正对正式门体，而不是正对路线阶段点。
- 正门门洞仍由两塔碰撞内沿 `±3.0 m` 保持 `6.0 m` 净宽；塔体加入现有 collider-baked NavigationMesh 后，角色路径绕过塔体，门 Link 与破门状态机无需新增节点或信号。

## T0202 友军攻击表现与战斗结束接线

- `ChibiCharacterPilot._play_state(...)` 对 `attack / mounted_attack` 增加单 sequence 末帧保持：AnimationPlayer 的 one-shot clip 已停止、但权威 phase 仍为 windup / recovery 时不再次 `play()`；下一 sequence 由 `apply_profile(...)` 检测序号变化并以 reset 重启。
- `CombatSystem._on_logical_time_tick(...)` 与 `_advance_friendly_combat_ai(...)` 在活动战斗尚未结算而 `_active_enemies` 已空时调用统一收口。`_handle_all_enemies_cleared(...)` 额外清空 `_active_melee_swings / _pending_melee_damage_commits`，NPCSystem 既有 mode transition 随后清空 attack target / phase / elapsed / cycle 和 current action。

## T0201 主厅透明实体接线

- `StationLayoutController._build_building_static_collision(...)` 读取主厅 `solid_interior_blocker`，在 `BuildingRoots/MainHall/StaticCollision/InteriorBlocker` 生成无 Mesh 的 `StaticBody3D + CollisionShape3D`。节点使用 layer 1 / mask 2，带 `building_id=main_hall`、`transparent_entity=true` 与 `blocks_navigation=true` 元数据，并加入 `formal_navigation_source`。
- `_build_building_navigation_links(...)` 不再生成 `MainHallDoorLink`；`_classify_building_navigation_point(...)` 同步把内部阻挡足迹判为 blocked。既有四面外墙 Body、`building_segment_id`、主厅攻击位、器械平台及表现树不变。

## T0200 统一战斗导航实现

- `data/station_layout.json.navigation.production_bounds` 将正式 collider-baked NavMesh 扩展到北侧敌军生成区；站内 AStar 合同网格仍保持原范围，避免把调试可达性合同与生产战场范围混为一体。`enemy_exterior_mode=shared_open_baked_space` 禁止创建旧 `EnemyApproachNavigation` 导航带。
- `ActorMotionBody.request_motion(...)` 接受战斗运动选项；`update_motion_target(...)` 在同一活动请求内更新移动目标。调试快照公开 `path_plan_mode=direct|detour`、路径长度、直线距离、目标更新次数和持续重规划状态。
- 敌我仍共用 `NavigationAgent3D` 与 RVO。`ActorMotionBody.configure_avoidance_identity(...)` 为每个角色设置稳定的微小 priority 差，防止多人同优先级时互相礼让不前；战斗请求在持续阻塞时重新设置相同权威目标，普通 NPC 行动继续按旧次数 / 时间失败。CombatSystem 在目标进入武器条件后停止请求，并由既有攻击时间线独占身体和伤害提交。
- `ActorMotionBody.request_motion(...)` 的 `motion_options.target_desired_distance` 可按请求覆盖 profile 最终到达半径，并统一用于 NavigationAgent、物理到达、直连捷径与平面可达复核。CombatSystem 仅为 `type=defense_device`、已取得租约且使用近战武器的请求传入 `station_layout.json` 的 `melee_attack_position_arrival_tolerance=0.06`；建筑租约仍用 `arrival_tolerance=0.32`。

## T0198 友方分域锁定接线

- `StationLayoutController.is_world_position_inside_station(...)` 与当前 `friendly_station_response_v4` 提供友军分域、加权避战和保持距离撤离配置；没有新增节点、Autoload 或信号。除 T0232 近身撤离会在锁定前清锁并独占一段移动外，CombatSystem 仍把同一 enemy ID 交给策略移动和攻击复验。
- 正式敌军近战 / 弹体最终仍汇入 `_apply_enemy_attack_to_npc(...)`。该入口在 NPC HP 实际下降后，用受击前锁与来源 enemy ID 生成一次性请求；NPCSystem 不再因同模式受击重复停止 ActorMotionBody。
- `debug_get_combat_snapshot().friendly_station_response` / `debug_get_friendly_targeting_snapshot()` 可观察分域、锁、pending 请求和 metrics。现有 GM 波次、一键配装、NPC / 敌人快照足够验收，无需新增场景或面板按钮。

## T0197 / T0199 受击重评估与统一调度接线

- NPC 模型接触、NPC 弹体、骑乘碰撞与塔防弹体仍汇入 `CombatSystem._apply_damage_to_enemy(...)`；该入口在 HP 实际下降且当前 / 来源满足高威胁异源条件时写入一次性请求。没有新增节点、Autoload 或信号。
- 下一次预算化敌军 AI 更新由 `_select_formal_dynamic_enemy_target(...)` 消费请求，并复用 T0196 已收集的圈内高威胁候选。读档重建、敌人移除和清场不会恢复旧请求。
- `debug_get_combat_snapshot().enemy_targeting` 增加 pending 请求、逐敌 pending 标志和三项 metrics，现有 GM“敌人快照”即可观察，因此无需新增按钮或调试场景。

## T0196 统一敌军索敌接线

- `StationLayoutController.get_formal_wave_navigation_config(...)` 继续把 `targeting_policy` 交给 `Main/Systems/CombatSystem`；当前 schema 为 `enemy_unified_presence_lock_v3`。场景树、Autoload 与信号接线不变。
- CombatSystem 每次预算化敌军 AI 更新只从 NPCSystem / EquipmentSystem、DefenseDeviceSystem 和 BuildingSystem 收集当前有效事实，在精确 `37.2 m` 水平范围执行同池最近首次选择与在场锁；全部活动敌人无条件调用该选择器，动态压力标记只影响运动 / 攻击位。实际伤害重评估见 T0197 / T0199。
- 选中 NPC 时直接把实时单位位置交给 `ActorMotionBody`，不生成 attack position。选中塔防 / 建筑时才进入现有 lease；塔防、仓库、主厅满位交回选择器，完整城门满位进入现有 waiter。
- `debug_get_combat_snapshot().enemy_targeting` 与 `enemy_attack_positions` 已足够观察政策、锁、metrics、NPC 零租约和城门 waiter，无需新增场景节点或 GM 控件。

## T0194 敌军塔防感知与受击抢占接线（历史，已由 T0196 取代）

- `DefenseDeviceSystem.get_active_defense_targets()` 现随宿主代理一并输出 deployment 的 `effective_attack_range`；墙体升级或主厅平台倍率变化后，下一次快照直接反映最终范围。
- `CombatSystem._collect_enemy_target_priority_groups(...)` 对每个塔防独立计算 `enemy_detection_range`，不扩大 NPC 基础索敌；`_select_enemy_recent_hit_preempt_target(...)` 只读取 CombatSystem 已提交的 `recent_hit` 关系并复用攻击位 / 阻挡预检。
- Main 场景节点与信号接线不变；现有 GM 波次、部署和敌人快照已能触发及观察全链，无需新增按钮。

## T0193 友军攻击起手锁接线

- `Main/Systems/CombatSystem._advance_combat_ai(...)` 每个权威战斗步只推进一次共享时钟，再依次驱动友军和敌军。`_advance_single_npc_combat_attack(...)` 用该步起点 / 终点消费 cadence wait 与 authored phase，不从 AnimationPlayer 或 NPC action label 推导时间。
- NPC `states` 新增可选的 `combat_attack_last_sequence_time / combat_attack_next_sequence_time / combat_attack_sequence_lock_remaining`。前两项是本进程运行态；正式空间检查点只写 sequence 与 remaining，加载后 next 先为 0，由 CombatSystem 下一步重建。
- SpatialSaveSystem 的既有顺序仍是 NPC restore → Combat restore。CombatSystem 在 `_spawn_formal_dynamic_wave(..., clear_existing=true)` 前捕获刚恢复的友军相对锁，波次重建后写回，避免中间 `clear_spawned_enemies()` 把读档等待误清。没有新增节点、Autoload、信号或 GM 控件。

## T0192 友军战术移动交接接线

- `NPC.gd.is_world_movement_active()` 同时核对 NPC 本地 `_is_moving` 与继承 ActorMotionBody 的 `is_motion_active()`；`NPCSystem.is_npc_world_movement_active(...)` 仅转发该实时事实。
- `NPCSystem.get_npc_navigation_closest_point(...)` 从目标 NPC 的 NavigationAgent 读取当前 map RID；`CombatSystem._constrain_combat_strategy_position(..., npc_id)` 将接近、保距和冲击拉开点统一吸附到这个真实 map。旧正式 / 兼容模式标志不再参与 map 选择。
- `Main/Systems/CombatSystem` 在友军策略移动分支核对存活性。失活但状态残留时调用 NPCSystem 原有的 `stop_npc_movement_with_state(...)`，清理 request / arrival context 后即时重新寻路；进入攻击距离时用同一入口完成运动→攻击交接。
- 近战 approach target 的站距为 `max(0.2, range * 0.85 - arrival_tolerance)`，CombatSystem 仅在活动追击进入 `range * 0.85` 后才停止请求；远程仍以完整 range 交接。NPC / ActorMotionBody 通用配置与工位终段容差不变。Main.tscn、Autoload、NavigationMap、存档 Schema 与 GM 控件均未变更；三敌自动化覆盖首杀后目标更换、再接敌和真实模型命中。

## T0189 敌军实体暂停接线

- `Main/Systems/CombatSystem` 监听 Autoload `EventBus.gameplay_pause_changed`，并同步 `FormalEnemyNavigationPilot`、`FormalActiveEnemySlice` 与 `FormalEnemies/*` 下的正式 `ActorMotionBody`。
- 运动体暂停沿用 `ActorMotionBody.set_motion_paused(...)`：`_physics_process` 在 paused 分支清零 CharacterBody / NavigationAgent / RVO 速度后返回，保留 request id、target position 和 NavigationAgent 路径。恢复会重置进展采样起点，再继续原请求。
- 正式波次 slice 新增非存档运行字段 `tactical_motion_paused`，防止 `gameplay_pause_changed(false)` 覆盖攻击到位停步。没有新增节点、Autoload、场景信号或 GM 控件；现有 HUD 暂停可以直接验收。

## T0188 站内敌军空间查询与响应接线

- `Main/Presentation/StationLayoutController.is_world_position_inside_station(...)` 把世界坐标转换到正式布局局部坐标，并只读 `station.interior_polygon`；CombatSystem 不复制城墙边界。
- `Main/Systems/CombatSystem` 每次接触更新先取得站内敌军集合，再分别驱动武装应征切战和非战斗避战。主动策略移动仍通过 NPCSystem 提交同一生产 NavigationAgent 目标，伤害 / 动画权威没有迁移。
- `Main/Systems/HorseSystem` 继续监听 NPC 状态变化并执行既有指定马匹会合；CombatSystem 在取马阶段跳过友军攻击，收到 `handle_npc_mount_ready(...)` 后恢复策略。Main 无新增节点、Autoload 或 GM 按钮，正式战斗可直接观察。

## T0185 战斗表现时间接线

- `Main/Systems/TimeSystem` 新增 `get_combat_frame_delta_seconds(...) / get_combat_frame_rate()`，并在 `get_time_scale_snapshot()` 暴露 `combat_frame_rate`。没有修改 Engine.time_scale、Autoload、Main.tscn 或存档 Schema。
- `ChibiCharacterPilot.gd / NPCArtView.gd` 用该倍率驱动攻击、受击、昏迷、起身、骑乘坠落与血液反馈；`NPC.gd / EnemyMountedArtView.gd` 同步正式马匹 AnimationPlayer，敌方阵亡包装仅推进共同尸体保留计时。主动暂停统一冻结，恢复不重建攻击 sequence。
- `CombatSystem._advance_combat_projectiles(...)` 以共享战斗帧 delta 推进敌我 / 塔防通用弹体，内部 `1/120 s` 子步、ray sweep、attack id 和伤害入口不变。`MeteorPresentation.gd` 同样以共享 delta 推进落地冲击波并同步粒子 speed scale。
- DefenseDeviceView 的生产机构仍只消费 DefenseDeviceSystem timeline snapshot；隔离开发预览中的 Tween / 假弹体不进入 Main 权威战斗。现有 Main 与 GM 入口已能直接观察本次行为，因此未新增调试节点或按钮。

## T0181 陨石建筑查询与友军排出接线

- `Main/Presentation/StationLayoutController.get_building_area_overlap(...)` 使用正式布局根、建筑根旋转、墙段和门体配置返回首个建筑冲突。
- `Main/Systems/PietySystem.get_target_position_validation(...)` 是 HUD 与施放请求共用入口；`request_meteor_cast(...)` 必须再次调用，保证 UI 绕过也无法向建筑施放。
- 落地帧先调用 `NPCSystem.displace_npcs_from_world_obstacle(...)`。安全点从生产 NavigationMap 取得，并按实体半径避免友军重叠；`ActorMotionBody.apply_external_displacement(...)` 保留活动 request id / target。之后 `MeteorPresentation.impact_at(...)` 才添加 `MeteorStaticBody`。
- Main 不新增节点或 GM 按钮；既有虔诚填满与正式选点入口可直接验收。

## T0238 陨石坑淡化接线

- `Main/Systems/PietySystem` 在落地时创建 `_crater_lifetimes[cast_id]`，由既有 `EventBus.logical_time_tick` 更新 `elapsed_game_seconds / fade_progress / opacity`；24 小时到期调用同一 MeteorPresentation 的 `remove_crater()`。
- `MeteorPresentation.gd` 收集凹坑、灰床、焦土、灰烬块和坑缘共享材质，通过 `set_crater_fade_progress(...)` 统一更新 Alpha。陨石本体仍位于独立 `_body_root`，弹坑删除不触碰 `MeteorStaticBody`。
- Main.tscn、Autoload、导航与 GM 节点均未改变；`PietySystem.get_piety_snapshot().craters[]` 提供只读验收数据。

## T0179 友军骑手与马匹共享鞍座坐标

- `MountedPresentationReference.orient_local_offset_to_visible_forward(...)` 将 DevLab 已验收的局部骑手偏移投影到当前可见前向；`get_friendly_rider_root_offset(...)` 是友军鞍座根偏移的唯一入口。
- NPCDevLab 继续旋转检视外层，但骑手位置改为显式调用上述共享入口；Main 的 `ChibiCharacterPilot` 在每帧平滑 yaw 后，用同一入口旋转根偏移和坐姿补偿。`NPC.gd` 随后以更高 process priority 把马匹转到人物同一可见前向。
- 骑乘待机、移动、攻击、受击和坠马起点读取同一表现坐标；坠马侧向与后向落点以触发时前向 / 右向建立。节点仍是 presentation-only，不写 HorseSystem、NPCSystem、NavigationAgent 或 CombatSystem。

## T0178 ActorMotion 路径推进接线

- `Main/*/ActorMotionBody/NavigationAgent3D` 继续使用正式 NavigationMap；`ActorMotionBody._resolve_intermediate_waypoint_progress(...)` 只读当前 PackedVector3Array 与索引，按配置决定正常推进、合法提前推进或错过点推进。
- `debug_get_motion_snapshot()` 新增当前路径点位置 / 距离、动态容差、捷径判定、中间点推进数和错过点推进数，供正式 Main 运行态与自动化定位，不写存档也不改变 NPC 状态。
- `data/physics_navigation.json.path_progression` 是 NPC、步行敌军与骑乘敌军共享参数源；最终到达距离仍来自 `navigation_agent.target_desired_distance`。
- Main 未新增节点、Autoload 或 GM 按钮。既有“全员征召配装”和警铃入口足以从前端复现并观察完整流程。

## T0176 Godot 导航运行合同

- `Main/*/NPC (ActorMotionBody)` 每帧仍可从 NPC.gd 同步 TimeSystem 暂停状态，但 ActorMotionBody 只在布尔值真实变化时停止或恢复运动采样。
- `NavigationAgent3D.get_current_navigation_path()` 与 `get_current_navigation_path_index()` 用于计算剩余折线路径；路径为空时退回到水平目标距离。相关值由 `debug_get_motion_snapshot()` 只读暴露。
- `Main/Systems/CombatSystem` 创建正式动态敌军时，将 NavigationAgent RVO padding 绑定到攻击位安全余量的一半，并将 target desired distance 绑定到正式攻击位到达容差。
- 完整正门 / 仓库的 StaticBody 仍负责物理阻挡；双向 NavigationLink 不改变建筑 HP、碰撞开关或攻击权威，只在阻挡物开放后提供导航连接。

## T0173 陨石现实下落与逻辑燃烧分流

- `Main/Systems/PietySystem` 的 `_process(real_delta_seconds)` 只推进 `_pending_meteors`，并在 `Main/Systems/TimeSystem.is_gameplay_paused()` 为真时返回；NPC / LLM 慢速请求不再影响陨石 Transform 插值和落地触发。
- `EventBus.logical_time_tick` 只自然推进 `_burn_zones`；冲击发生后仍由 PietySystem 调用 CombatSystem，MeteorPresentation 仍只负责显示、碰撞实体、弹坑和特效。
- 既有 GM `piety_step` 继续调用 `debug_advance_effects` 同时推进两类状态，便于冻结状态下确定性验收。

## T0171 HorsePanel 属性行接线

- `Main/UI/HorsePanel/HorseInfoContent` 的五组属性仍由 `HorsePanel.gd` 运行时创建；每组先添加 Label、再添加 ProgressBar，不新增 `.tscn` 节点、信号、Autoload 或存档字段。
- 每个 ProgressBar 的 `fill` 使用面板内缓存的正常 / 危险 `StyleBoxFlat`；`_set_progress()` 同步刷新数值、tooltip、危险元数据及对应 Label 字体覆盖。
- `debug_get_snapshot().progress_rows` 只提供布局与颜色自动验收，不进入正式玩法结算。

## T0170 马厩马匹点击接线

- `HorseWorldView/HorseInteractionArea` 保持 layer 4，并新增 `interaction_kind=horse` 与 `horse_id` 元数据；HorseSystem 使用与 NPCSystem 相同的主 Camera3D→Area3D 精确射线解析，不依赖模型网格或姓名 Label。
- BuildingSystem 在通用 BuildingArtView AABB 选择前调用 stable horse route：找到具体在厩马后，再读取 stable 专属 interaction hit 的 `interior_revealed`。透明时调用 `HorseSystem.select_horse_from_world_click()`，不透明时调用既有 `_select_building("stable")`。
- FormalStableArtView 的 selection reveal 由 `_roof_opacity <= interior_reveal_opacity_threshold` 决定；屋面视觉、阴影代理、静态碰撞、导航和马槽均未变化。

## T0169 HorsePanel 紧凑镜头接线

- `Main/UI/HorsePanel/HorsePanelRow/HorsePortraitView` 仍由运行时创建；HorsePortraitView 改用纵向 `SIZE_SHRINK_BEGIN`，由 HorsePanel 在视口变化和显示时更新最小宽高，因此保持左上对齐而不再被 HBox 拉伸至面板全高。
- 没有新增场景节点、Autoload、信号或存档字段。HorsePortraitViewport 的 SubViewport、Camera3D、视觉层与 HorseSystem 查询链路均未改变。

## T0168 Godot MCP 路径别名拓扑

- 当前 Godot MCP 可报告项目路径 `D:/MyGames/这不是我的战争/`；Windows 文件系统将其解析为 Junction 目标 `D:/这不是我的战争/`，因此编辑器、MCP 与当前工作区操作的是同一 `project.godot` 和 `.godot` 状态。
- Agent 应直接复用这一连接读取工程信息、编辑器状态、场景树与 `res://` 节点。不得为了让显示字符串一致而另启 Godot 编辑器、抢占 6550 端口或退回“禁用 MCP”流程。
- `tools/verify_project_path_alias.ps1` 是拓扑异常时的只读诊断入口；它不修改 Junction、不重启编辑器，也不管理 MCP 进程。

## T0167 马槽接近点接线

- StationLayoutController 将每个 `horse_anchor.pickup_center` 写入同一 HorseAnchor Marker，并验证它位于马槽开放侧。FormalStableArtView 通过当前 HorseWorldView 的 `stable_slot_id` 返回该 Marker 的接近点世界坐标。
- HorseSystem 仍只依赖 `horse_world_presentation` 组，不硬编码 Stable 节点路径；取得接近点后用生产 NavigationMap 完成起终点吸附和 `map_get_path` 验证，再调用 NPCSystem 原移动接口。
- 没有新增场景节点、Autoload 或信号；马模型中心、接近点和 NPC 路径分别保持表现、空间配置与运动职责。

## T0166 GM 面板运行时结构

- `Main/UI/GMPanel` 仍由 `GMPanel.gd` 运行时创建控件；固定 `GMQuickActions` 位于命令行与 `GMSectionTabs` 之间，五个页签各自拥有 ScrollContainer / VBoxContainer。
- 没有修改 Main.tscn、Autoload、系统节点或信号。移除的是重复按钮实例，命令解析和 NPCSystem / CombatSystem 等底层 debug 方法继续保留。

## T0165 陨石奇观接线

- `scripts/presentation/combat/MeteorPresentation.gd` 由 PietySystem 为每次施放实例化到 `WorldRoot/Station/Effects`。它复用运行时 Quaternius 卵石 GLB，并程序化创建低多边形主体、坑洼、GPUParticles3D 火焰 / 烟尘 / 碎屑、TorusMesh 冲击波、StaticBody3D 碰撞和永久 crater mesh。
- PietySystem 保存 pending / landed / permanent crater 三类只读诊断映射；落地调用表现的 `impact_at(...)` 后再走既有 CombatSystem 结算。EventBus 的 `event_recorded` 已存在，本任务不新增 Autoload 或战斗结束信号。
- `CameraRig.request_camera_shake(duration, amplitude, frequency)` 提供轻震与强震表现接口；常规 `_process` 在完成输入平移后更新 Camera3D 局部偏移，暂停和文本焦点不导致震动卡死。

## T0164 正式建筑 NameLabel 接线

- `Main/Presentation/StationLayoutController` 在 `_add_label(..., "NameLabel", ...)` 时标记并收集正式建筑 / 门名，设置 38px 字号；普通工位、马位和调试 Label3D 不进入集合。
- 控制器 `process_mode=ALWAYS`，因此暂停游戏时仍能依据 CameraRig 位移与 Camera3D 缩放更新真实时间渐隐。`debug_get_building_name_label_snapshot()` 只用于专项观察，无新增节点、Autoload、信号或存档字段。

## T0163 陨石无边界地面接线

- HUD 继续从当前 Camera3D 投射射线到 `target_ground_y` 水平面；取消对 StationLayout / 建筑 bounds 的依赖，命中后直接把有限世界坐标交给 PietySystem。
- PietySystem 的节点、信号、Effects 容器、CombatSystem 调用和 GM 调试接口均未变化；T0181 起 `get_targeting_snapshot()` 以 `scope=unbounded_ground_plane_except_buildings` 表示无限地面但排除正式建筑区域。

## T0162 马匹实体、点击与特写接线

- `Main/UI/HorsePanel` 绑定 `HorsePanel.gd`；面板运行时创建 `HorsePortraitViewport` 并读取 `Main/Systems/HorseSystem`。`EventBus.horse_clicked(horse_id)` 驱动选择，NPC / Building / Merchant / NoticeBoard / AttackRangeIndicator 同步清理互斥状态。
- `FormalStableArtView` 为每匹马创建 `HorseWorldView` 包装，模型由 `HorseAppearance` 着色，姓名 Label3D 使用人物框排除层，Area3D 只做点击。HorseSystem 通过 `horse_presenter` 组取得只读世界位置，避免反向依赖具体场景路径。
- HorsePortraitViewport 与 NPCPortraitViewport 一样使用共享 `World3D` 的 SubViewport 和独立 Camera3D；相机排除世界姓名与主相机淡出壳，稳定槽内使用走道构图，移动状态使用墙体射线修正。

## T0161 GM 一键征召配装接线

- `Main/UI/GMPanel` 在固定快捷区运行时创建 `RecruitAndEquipAllButton`；无需修改 `Main.tscn` 节点树。按钮调用 `Main/Systems/EquipmentSystem.debug_apply_combat_loadout_preset()`，成功或失败都只在 GM 日志展示。
- EquipmentSystem 通过既有绝对节点路径访问 NPCSystem / ResourceSystem / HorseSystem；HorseSystem 新增 `debug_ensure_horses(Array)`，创建出的测试马进入原 `_horses / _horse_order` 容器并沿原信号刷新马厩表现。
- 没有新增 Autoload、EventBus 信号、运行时服务、场景或存档节点。正式角色包装继续只读最终装备 / 坐骑状态。

## T0157 摧毁锁存与废墟表现接线

- BuildingSystem 在建筑首次降至 0 HP 时写 `destruction_latched=true`；可恢复目标只有达到 `ceil(max_hp * recovery_hp_ratio)` 才解除。正门、仓库和主厅的 ArtView 只读该字段，因此伤害、修复和视觉不会形成双权威。
- 正门 ArtView 将锁存映射为门板绕底部铰点倒塌及门板碰撞关闭；门楼、门楣和门柱不换模。恢复阈值到达后复用同一门叶动画和 CollisionShape。
- DefenseDeviceSystem 在 deployment 被移除前生成按 slot_id 键控的临时 ruin snapshot。Presenter 让 active 与 ruin 互斥；新部署清同槽废墟，现实时间到期清剩余废墟。ruin View 禁用点击和攻击时间轴。
- 仓库 / 主厅在各自 ArtView 下生成同材质废墟组并隐藏正常外壳、屋顶、升级和损伤层；主厅锁存不可解除，且 Presenter 隐藏其宿主器械，避免平台坍塌后的悬空单位。

## T0155 NPC locomotion 接线

- `NPC.gd` 从 ActorMotionBody 已加载的 `physics_navigation.json` 读取 `npc_locomotion_v1`，按 profile 状态选择 walk/run 基础速度，再叠加既有 `_get_move_speed_multiplier()`；legacy 直线兼容路径和正式 NavigationAgent 共用该结果。
- `update_profile(...)` 可在移动中调用 `configure_profile(...)` 热更新 NavigationAgent `base_speed`，保留当前目标、路径、RVO、到达和失败信号。TimeSystem 的玩家倍速不进入物理位移公式，暂停仍通过既有 `set_motion_paused(...)` 管理。
- 每个物理帧在移动前后量测水平位移，`NPC.gd -> ChibiCharacterPilot / NPCArtView` 传递 actual speed、显式 locomotion state、reference speed 和 clamp。步行、奔跑、骑乘步态据此缩放 AnimationPlayer；停止时仍由 profile 状态机回到 `idle / vehicle_seated`。
- 旧两参数 `set_movement_active(...)` 调用保持兼容：NPCDevLab 与敌军包装未传显式分类时，角色包装继续根据现有 combat mode / 预览速度推断 walk/run；正式我方 Main 始终传显式分类。

## T0152 NPC-NPC 邀请示意接线

- ActionSystem 的正式接近阶段只调用 `face_formal_dialogue_speaker(...)`，避免等待判定时强制受邀者停工或转向；DialogSystem 在创建 dialogue ID 后提前绑定正式空间会话，确保快速异步回复也能找到同一实体会话。
- NPCSystem 的 `play_formal_dialogue_presentation_event(...)` 校验 dialogue、角色、参与者状态和发起时距离，再调用 NPC 实体的表现桥；最近事件以稳定 ID 去重并提供 32 条只读快照，不进入存档。
- 接受前 `stage_formal_dialogue_acceptance(...)` 只捕获真实位置与原空间迁移合同；ActionSystem 完成停工后，NPCSystem 在同一同步调用中恢复该位置、接管导航、令双方相向并播放受邀者示意。之后 DialogSystem 才写 `current_action=talk_to_npc`。
- Chibi / legacy 角色包装把 `talk_gesture` 映射为 `talk` clip 的一个完整周期。临时 transient 优先于 profile 动作，周期结束后重新解析权威状态；包装不拥有对话或行动结算。

## T0151 攻击距离圈接线

- `Main/WorldRoot/Station/Effects/AttackRangeIndicator` 绑定 `scripts/presentation/combat/AttackRangeIndicator.gd`，监听 NPC / 器械选择、非战斗对象选择、状态变化和清除选择事件。
- `DefenseDeviceView.tscn` 新增 interaction-only Area3D；点击后通过 `EventBus.defense_device_clicked(deployment_id)` 切换表现选择，NPCPanel / BuildingPanel 同步收起。其碰撞层仅用于输入射线，不参与 CombatSystem 的世界 / actor 碰撞查询。
- indicator 每帧只更新选中对象位置与只读有效性；半径未变化时不重建 128 段 ImmediateMesh。NPC 状态与器械部署变化会主动刷新，失效时隐藏但不制造第二套单位状态。

## T0150 敌军索敌接线（历史，已由 T0196 取代）

- `StationLayoutController.get_formal_wave_navigation_config(...)` 将 `targeting_policy` 与 T0149 `attack_position_policy` 一并交给 CombatSystem；前者配置五级顺序、范围、锁 / 重评估、近期命中保留和白名单阻挡探测，后者继续独占站位参数。
- 该段描述旧五级实现；当前 CombatSystem 不再让活动弹体参与候选，也不为 NPC 预检 lease。`ActorMotionBody` 接收最终 NPC 实时位置或固定目标攻击位 / 城门候补位置。
- `debug_get_combat_snapshot().enemy_targeting` 暴露每敌锁定与优先级、活动反击源和 metrics；现有 GM“敌人快照”自动显示该数据，不增加用于强制改目标的 UI 接口。

## T0149 攻击位租约接线

- `StationLayoutController.get_formal_wave_navigation_config(...)` 将 `c3_p7_dynamic_assault.attack_position_policy` 原样交给 CombatSystem；其中只配置安全余量、吸附 / 到位容差、射程比例、容量上限及三类建筑正面宽度，不保存运行时占用者。
- CombatSystem 以 `_enemy_attack_position_leases / _enemy_attack_position_by_enemy / _enemy_attack_wait_queues` 维护唯一关系。候选经 `NavigationServer3D.map_get_closest_point / map_get_path` 过滤并排序，取得租约后才把 `attack_position` 交给现有 `ActorMotionBody.request_motion(...)`。
- `DefenseDeviceSystem.get_active_defense_targets()` 的只读 `facing_direction` 使宿主墙段攻击带生成在器械朝外一侧；原 `host_proxy` 身份、碰撞和 HP 路由不变。NPC 环位已由 T0196 删除；NPC 实时移动由目标位置变化触发现有 motion 重规划。
- `debug_get_combat_snapshot().enemy_attack_positions` 暴露可序列化 leases / waiters / metrics；位置向量序列化补齐 attack / queue / target position。清敌与 initialize 清空全部映射，checkpoint 不保存这些 NavMap 相关瞬时字段。

## T0148 宿主碰撞代理接线

- `StationLayoutController.get_defense_device_slot_pose(...)` 在正式器械位置之外，输出宿主代理 kind / ID、墙段或建筑墙段、平台 fixture、地面接近点、瞄准点和命中半径。正式建筑静态墙碰撞新增稳定 `building_segment_id` 元数据；围墙继续使用既有 `wall_segment_id`。
- `DefenseDeviceSystem.bind_formal_slot_positions(...)` 将这些字段绑定到运行态 slot，`get_active_defense_targets()` 把低位代理位置交给敌军寻路 / 朝向，并在 deployment snapshot 中暴露只读 `host_proxy`。恢复 legacy 坐标时会同步移除正式代理字段，避免旧映射残留。
- CombatSystem 的 melee collider 与 projectile collider 身份解析新增 `wall_segment_id / building_segment_id / fixture_id / fixture_kind / collision_category`。两种命中路径都调用同一严格代理匹配，再进入既有器械伤害入口。
- 代理复用既有正式 StaticBody3D，不生成重叠的第二套碰撞体，也不由 DefenseDevicePresenter 或器械模型决定伤害。器械销毁只影响 DefenseDeviceSystem 部署记录，StationLayoutController 的墙 / 平台碰撞生命周期保持独立。

## T0147 塔防时间轴、表现与弹体接线

- `DefenseDeviceSystem._advance_auto_attack(...)` 推进部署实例的权威相位，通过 `EventBus.defense_device_action_phase` 投影到 `DefenseDevicePresenter -> DefenseDeviceView -> Formal*ArtView`。表现只同步 yaw、装载可见性、释放次数和恢复，不主动决定攻击。
- release 帧由 DefenseDeviceSystem 调用 `CombatSystem.release_defense_device_projectile(...)`；CombatSystem 向 presenter 查询当前正式模型 muzzle snapshot，并把发射 Transform、目标瞬时位置、effect projectile 配置和 effect range 固化到通用 projectile。
- CombatSystem 继续统一推进 Node3D 表现、重力与物理 sweep。`source_side=defense_device` 的合法敌军碰撞复用 `apply_defense_device_attack(...)`，随后以唯一 attack ID 把终态回传 `resolve_defense_device_projectile(...)`；表现节点和事件总线均不直接修改 HP。
- 旧 `DefenseDeviceView.play_device_action(...)` 只保留隔离美术预览；生产事件改用相位同步，正式 `FormalBallistaArtView / FormalArrowTowerArtView` 不生成内部假弹体。清理路径会同时复位部署时间轴和在途 projectile。

## T0146 正式弓弩步骑接线

- `ChibiCharacterPilot.get_combat_projectile_release_snapshot(...)` 校验当前权威武器、弓 / 弩节点及 LoadedArrow / LoadedBolt，并返回 Transform、origin source、节点路径和 mounted 状态。`NPC.gd -> NPCSystem.gd` 与 `EnemyMountedArtView.gd` 分别转发友方和骑射敌方事实。
- `CombatSystem._get_projectile_release_descriptor(...)` 是正式 release 唯一入口；descriptor 不 ready 时写 `release_rejected` 并终止，ready 时把发射 Transform 与 provenance 固化到 projectile。旧 transform getter只保留只读兼容查询，正式 spawn 不消费其身体高度 fallback。
- 敌我步 / 骑仍使用同一个 `_spawn_combat_projectile(...)`、物理子步和碰撞伤害链；HorseSystem 只决定友方 `combat_mounted` 与马匹生命周期，不生成或移动弹体。

## T0145 攻击 ID 与终态事实接线

- `CombatSystem._spawn_combat_projectile(...)` 在创建 `CombatProjectileView` 前生成 `attack_id`，把它与 `attack_sequence` 写入 attack context、运行态 projectile 和 release result；敌我共用该入口。
- `_resolve_combat_projectile_collision(...)` 先查询 / 预留 `_resolved_projectile_attack_facts`，再调用既有碰撞伤害函数；完成后把 hit / blocked fact 固化并把 ID 盖到顶层攻击结果及嵌套 damage result。重复 ID 直接返回 `duplicate_ignored=true`。
- `_finish_combat_projectile(...)` 为落地、遮挡和超时建立同结构终态 fact；`_clear_combat_projectiles(...)` 同时释放视图节点、活动数组与去重表。combat snapshot 暴露活动 ID、最近 fact 和 `resolved_projectile_attack_count`，不提供 GM 强制结算入口。

## T0144 正式近战模型接线

- `ChibiCharacterPilot.get_combat_melee_contact_segment(...)` 从正式剑 / 长杆节点的已量测局部端点计算世界刃段，并用 `AnimationPlayer.assigned_animation` 确认当前确实是对应步 / 骑攻击片段。`NPC.gd / NPCSystem.gd` 与 `EnemyMountedArtView.gd` 只做只读转发。
- CombatSystem 在后置 `_process` 按配置密度采样活动 swing；先查询当前武器胶囊，未命中再扫相邻样本的刀尖 / 中段运动段，mask `3` 并排除射手 RID。接触进入待提交队列，由下一物理帧复用原伤害入口；collider 身份继续沿父链 meta 解析。
- `CombatAnimationTiming.get_timing(..., mounted)` 返回步 / 骑独立 authored 接触点；NPC combat stats / attack context 在骑乘近战时读取 `melee_contact.mounted_range`。敌军实例化后同样从武器定义归一化近战范围。
- `debug_get_combat_snapshot()` 暴露 `active_melee_swings / last_melee_contact_result` 的可序列化副本，不暴露 Shape、Node 或 RID，也不创建 GM 专用命中权威。

## T0143 正式弓弩弹体接线

- `CombatSystem._resolve_npc_attack_impact(...) / _apply_enemy_attack(...)` 对 `bow / crossbow` 分流到 release，不调用即时伤害；`CombatProjectileView.gd` 由 CombatSystem 直接实例化为 Node3D 子节点并按速度朝向，无 Area / Body。
- `NPCSystem.get_npc_combat_projectile_release_transform(...)` 经 `NPC.gd` 转发到 `ChibiCharacterPilot.get_combat_projectile_release_transform(...)`；敌军直接从 `EnemyArtView` 读取，同一接口由 `EnemyMountedArtView` 转发给骑手。包装缺失时回退到角色碰撞体上方，不回退到即时命中。
- `_physics_process(...)` 以 TimeSystem 的共享战斗帧 delta 推进活动弹体；暂停时冻结，战斗 `1/60` 逻辑倍率不会再次施加。每步使用 `PhysicsRayQueryParameters3D`、mask `3`（world_static + actor_body）并排除射手 RID，且同时查询 body / area 以兼容正式 ActorMotionBody 与旧敌军 Area 包装。
- collider 身份通过父链 meta 解析；弹体结果在 `debug_get_combat_snapshot().active_projectiles / last_projectile_result` 暴露。`debug_advance_combat_projectiles(...)` 仅用于确定性专项，不创建另一套结算规则。

## T0142 攻击周期与正式角色包装接线

- `CombatSystem._advance_single_npc_combat_attack(...)` 与 `_advance_enemy_attack(...)` 共用 `CombatAnimationTiming.get_timing(weapon_id, attack_interval)`，保存 sequence、phase、elapsed、cycle、impact、target、committed 和 playback；命中前不调用伤害接口。
- 正式友军通过 `NPCSystem.set_npc_facing_direction(...)`，正式敌军通过 `EnemyArtView.set_facing_direction(...)` 持续朝向当前目标。敌军刷新即使 profile 签名未变化也会更新朝向，移动目标不会被旧签名缓存挡住。
- `ChibiCharacterPilot.apply_profile(...)` 读取 `states.combat_attack_*`；新 sequence 会重播动作并按 elapsed 定位。剑盾 / 长杆使用单片段 seek，弓 / 弩会定位到 draw / aim / release 或 aim / shoot / reload 子阶段；AnimationPlayer 与程序弓弦 / 弩弦共用同一倍率。
- 正式敌军 spatial checkpoint 保存并恢复攻击周期；NPC 模式切换和昏迷、敌军路线切换与 stagger 清理相位。`debug_get_enemy_art_snapshots()` 与角色 art snapshot 暴露只读时间轴，方便 Main / GM / 自动化观察，不成为第二套权威。

## T0141 正式敌军四武器与骑兵包装接线

- `CombatSystem._attach_formal_enemy_art(...)` 对 `sword_shield / polearm / bow / crossbow` 统一实例化 `EnemySwordShieldChibiArtView.tscn`；`cavalry / mounted_ranged` 继续实例化 `EnemyMountedArtView`。只有未知武器类型才保留旧表现回退。
- 每个正式敌军仍以原 ActorMotionBody 为运动、碰撞和选择根；新包装只是其表现子节点，旧 `ActorMesh` 隐藏但不替代权威节点。
- `_apply_enemy_art_state(...)` 把敌军 `weapon_type` 放入 `equipment.main_weapon.id` 后调用生产 `apply_profile(...)`。`ChibiCharacterPilot` 会按需建立长杆、弓、弩附件，并依据权威战斗可见性显示唯一固定武器；正式路径不调用 `debug_set_equipment_preview(...)`。
- 骑兵包装把同一 profile 继续转交骑手，因此轻骑显示剑盾 + 马，骑射显示弓 + 马；骑乘朝向与 T0242 的人马共同阵亡由 `EnemyMountedArtView` 实现。
- `debug_get_enemy_art_snapshots()` 新增只读 `enemy_type_id / mount_type`，用于确认波次兵种与包装映射，不成为存档字段或第二套敌军状态。

## T0130-D1R14 四部位低模护甲接线

- `ChibiCharacterPilot` 在角色骨架解析后为 `Head`、`Chest / Body`、`LeftForearm / RightForearm` 和 `LeftShin / RightShin` 建立护甲 BoneAttachment；头盔与胸甲各一根，护腕和护腿各两根。几何按需创建，未装备时不生成额外 Mesh。
- 护甲位置以目标骨的模型空间 rest 变换为基准：保存 `bone_global_rest.affine_inverse() * desired_model_transform`，由 BoneAttachment 在动画中带动。禁止在 `_process` 逐帧重写护甲 global_transform，否则会重复出现武器曾经发生的“动作中脱手”问题。
- 头盔使用低面数冠体、眉梁 / 鼻梁 / 护颊与皮革衬带；胸甲使用前后收腰壳片、横向甲片、侧部链甲和皮带；护腕 / 护腿使用低边数锥台、边缘环与甲片。全部几何无碰撞，不参与命中或导航。
- `apply_profile(...)` 是正式只读投影入口，`debug_set_armor_preview(...)` 是 DevLab 临时入口；二者最终只更新同一组护甲根的可见性。护甲在 `combat / rally` 显示，在 `work` 隐藏，不写 EquipmentSystem、库存、减伤或战斗权威。
- 头盔可对原 SkinnedMesh 中能安全识别的独立头发 / 头饰拓扑岛生成过滤副本；原网格被缓存，卸下或隐藏头盔时必须原样恢复。无法可靠分离的外观保持开放式头盔组合，不允许为了遮发把头盔整体放大到明显悬浮。
- `tools/capture_t0130_d1r14_armor.gd` 直接拍摄同一 `NPCDevLab` 生产包装，覆盖八名友方正面和代表角色侧 / 背面；专项同时检查每槽实际 Mesh、左右根数量、工作 / 战斗显隐和跨角色共享。

## T0130-D1R12 两头身动作合成与附件接线

- `ChibiCharacterPilot` 继续使用 KayKit 源骨架、Synty 目标骨架和共享 AnimationLibrary。步战动画是已验收上半身动作源；骑乘片段先复制 `Mounted_Idle` 全身跨坐，再只替换 Spine、Chest、UpperChest、Neck、Head、双肩、双臂与双手的旋转轨，Hips 和腿骨保持骑乘基线。
- 不能简单把所有源 Hips 轨丢弃：弓 / 弩步战瞄准会把上半身 yaw 的一部分写在 Hips。`_transfer_foot_hips_rotation_to_mounted_spine(...)` 保持 `mounted_hips * adjusted_spine == foot_hips * foot_spine`，把这部分旋转转移到 Spine；这样上半身与步战同向，下半身仍跨坐。
- `_apply_mounted_spine_forward_lean(...)` 只叠加武器专属的小幅前倾；剑盾和长杆不得通过旋转 Hips 获得前倾。骑乘剑、长杆、弓、弩都继续消费步战已验收的手部与武器相对关系，不另复制一套漂移的“马上握点”。
- 武器 / 工具模型必须声明真实局部长轴、正面和显式握点。位置按 `target_hand - basis * source_grip` 反算；攻击中需要由手带动的附件保存 BoneAttachment 局部 Transform，禁止每帧重写 global_transform。只有弓弦、箭矢、双手长杆等确有程序约束的部件才在动作期更新。
- `NPCDevLab` 只实例化生产包装并投影调试 profile；正式 NPC / 敌人也通过同一包装或共享参数进入表现层。开发检视、Main、截图工具与自动化必须观察同一节点实现，禁止为截图复制专用姿势。

## T0138-R2 DevLab 骑乘表现基准接线

- `MountedPresentationReference.gd` 是骑乘模型相对 Transform 的共享生产常量；`NPCDevLab` 是这些值的视觉验收场所，但不是运行时权威依赖。正式 Main 与 DevLab 必须读取同一常量或实例化同一生产包装，禁止复制一组“看起来接近”的位置 / 缩放 / 朝向参数。
- 友方链路由 `NPC.gd + ChibiCharacterPilot.gd` 读取 DevLab 已确认的马根 `(0,0.13,0)`、马缩放 `(0.50,0.39,0.46)` 和骑手根偏移 `(0,1.30,0.35)`。`NPC.gd` 的后置 `_process` 在人物平滑转向完成后读取 `get_visible_forward()` 并同步马根，避免人物与马采用不同转向时间常数。
- 敌方 Main 与 DevLab 都实例化 `EnemyMountedArtView`；包装的马位置 / 缩放同样来自共享引用，并在骑乘阶段后置同步骑手实际可见前向。进入共同阵亡阶段后冻结人马包装朝向与根位置，不再产生独立逃逸朝向。
- 后续 DevLab 已存在的模型、动作和姿势应视为正式场景验收参照：新增正式用法时先复用生产脚本 / 资源 / 共享参数，再由 DevLab 做可视确认；不得让 DevLab 调用 HP、伤害、装备、马匹或战斗结算接口成为权威。

## T0242 / T0139 友方坠马与敌方骑兵共同阵亡接线

- `NPC.gd` 仍是正式角色节点与表现桥。其战斗坐骑子树实例化 `res://assets/3d/quaternius/animals/merchant_horse.glb`，只在 `combat_mounted=true` 时显示，并按角色移动切换马匹 `Idle / Walk`。
- `ChibiCharacterPilot.gd` 根据上一帧已骑乘、当前已昏迷的状态边沿启动 `mounted_fall`。人物根表现从正式骑姿偏移沿侧向抛物线移动到地面落点，同时播放 `Death_A`；状态机权威不等待动画。
- T0139-D2 的 `NPCDevLab` 动作仅向同一 `ChibiCharacterPilot` 先后投影已骑乘和已昏迷的本地 profile，因此与 Main 共用上述边沿检测、`Death_A` 和位移曲线。离开动作时重建角色预览以清理局部坠马姿态；不调用任何权威系统。
- 落地偏移保持到 NPC 复苏；复苏继续使用既有 `get_up / Lie_StandUp`，并在动作期间将表现偏移平滑收回人物权威根节点。步战昏迷继续走普通 `unconscious`。
- `CombatSystem._attach_formal_enemy_art(...)` 对 `cavalry / mounted_ranged` 创建 `EnemyMountedArtView`：内部持有同一 Synty 骑手和 `merchant_horse.glb`，只向骑手投影 `combat_mounted`。包装显式声明敌方马无独立 HP，CombatSystem 仍把全部伤害直接结算 `_active_enemies` 中的敌军单位。
- 敌军阵亡先从活动敌人与 ActorMotionBody 权威链移除；`_preserve_enemy_defeat_presentation(...)` 仅把表现包装重挂到敌军表现根，投影 `hp=0 / alive=false` 后调用 `begin_mounted_shared_defeat(2.4)`。骑手留在阵亡点执行 `Death_A`，马匹原地执行 `Death` 并保持末帧，保留时间到期后包装整体 `queue_free`；普通敌军继续走原延时释放分支。

## T0138 正式骑战运行时接线

- `HorseSystem._process()` 只推进 `returning_stable`（以及旧存档兼容的 `approaching_rider`）马匹世界坐标；T0138-R1 的取马等待使用 `location=stable / phase=waiting_for_rider_at_stable`，因此 `FormalStableArtView` 把马固定在真实 `HorseAnchors` 并播放 `Idle`。返厩阶段仍播放 `Walk`；`ridden / dead` 不留在马厩表现根中。
- NPC 取马复用 `NPCSystem.move_npc_to_world_position(...)` 与正式 NavigationMap；T0167 后目标是对应马槽朝中央走道开放的配置接近点，不再从马模型中心求可能隔栏的最近点。移动目标 id 使用真实 `stable`，避免地点 / 记忆层把合成马匹 id 当成建筑。进入容差时通过 `stop_npc_movement_with_state(...)` 清理尚未完成的 arrival 请求，避免下一物理帧把 `combat_ready` 覆盖成等待状态。
- `NPC.gd` 的既有 `CombatMountVisual` 仍只看 `combat_mounted`，因此会合途中保持步行，抵达后才显示骑乘；当前任务不创建坠马动画。`NPCPanel` / `BuildingPanel` 只读新阶段并在非工作模式禁用换装，不保存马匹事实。

## T0135-P8AR8 铁匠铺全敞开正面

- `FormalBlacksmithArtView._build_exterior()` 不再实例化 `FrontWall / FrontDoor / DoorJambLeft / DoorJambRight / AutoDoor`；正面只保留四个具名 `FrontPost01–04`、原顶部横梁与职业徽牌，侧后砌体和平顶树不变。`get_art_slice_snapshot()` 以 `front_enclosure_profile=fully_open_with_four_original_roof_posts` 暴露当前表现合同。
- Lv.2 两根侧向加固柱改为具名 `ReinforcedWallBraceWest / East`，包络为 `Y=0.18–3.38 m`；专项要求其保持落地且顶部至少低于 `FlatSlateDeck` 底面约 `0.02 m`，避免升级后穿出平顶。
- `StationLayoutController._build_building_static_collision()` 对 `blacksmith` 继续生成左右后墙碰撞，但跳过 `FrontLeft / FrontRight`，并在碰撞根记录 `fully_open_front=true`；其他建筑仍走原双前墙段生成分支。
- 中央 `BuildingDoorLink`、门内外路线点和地点提交仍作为铁匠铺工作动线使用，但正面不再具有门动画或门叶感应 Area。NPC 导航、fixture 碰撞、BuildingSystem、屋顶 / 外墙透明和点击接线均沿用现有权威。

## T0135-P8AR7R3 工械坊门楣徽牌檐下净空

- `Exterior/WorkshopSign / CompassBar / CompassStem` 是正门上方无碰撞表现徽牌，不属于山墙或门体。R3 将其最高点从瓦面以上收至约 `Y=3.36 m`，该处 `Roof/RoundTileRoof` 导入顶点内侧最低值约 `Y=3.428 m`。
- 专项在 art-local `(x≈0,z≈6.23)` 邻域读取瓦面真实顶点，要求徽牌三个 Mesh 的 AABB 顶部均低于檐口内侧至少 `0.04 m`；主牌底部同时不得低于 `Y=2.90 m`，防止通过继续下移侵占自动门净口。
- 本次不调整屋顶、山墙、矩形墙、AutoDoor、碰撞、导航、工位或制造权威。

## T0135-P8AR7R2 工械坊山墙横截面净空

- 工械坊矩形墙顶与整体屋顶 AABB 合法仍不足以证明山墙不穿瓦。`verify_t0135_p8ar7_building_roof_closure.gd` 现在直接读取 `Roof/RoundTileRoof` 下每个导入 Mesh surface 的顶点，将其变换回 art-local 空间，并在两端山墙 `x=±6.08 m` 附近按 `|z|=0–6 m` 七档求瓦面内侧最低 Y。
- 每档用 `PrismMesh.size / position` 解析三角山墙顶线，要求至少保留 `0.04 m` 瓦下净空；持久 shadow proxy 明确排除。两侧 `Front/RearRakingBeam` 另锁定 `16°`、厚度不超过 `0.161 m` 和内收高度，避免木构独立穿出。
- 最终山墙仍从矩形墙顶 `Y≈3.32 m` 起封闭，但峰值由 `5.82 m` 收至 `5.02 m`；屋顶 Transform、四边覆盖、自动门、透明 / 阴影链与所有正式空间 / 玩法权威不变。

## T0135-P8AR7R 工械坊 / 宿舍四边屋面贴合

- 工械坊 `Roof/RoundTileRoof` 的 Quaternius 源模型真实屋脊沿局部 Z；调用实例现在绕 Y 旋转 `90°`，与 authored `ColdRidgeCap` 和位于 `x=±6.08` 的山墙统一为局部 X 屋脊。实例 Y 从 `3.20` 抬至 `3.69`，南北顺坡檐条拆分为两片并随真实坡面旋转，监窗整体移到屋脊上方。
- 宿舍两片程序化 BoxMesh 坡面统一使用 `17° / 7.78 m / 13.84 m`，中心为 `x=±3.70,y=4.585`；山墙棱柱、檐梁、王柱、顺坡撑、十一组拼缝和 `13.9 m` 屋脊同步消费同一轮廓，不保留旧 `24°` 局部变换。
- `verify_t0135_p8ar7_building_roof_closure.gd` 在 art-local 空间合并 authored Mesh AABB，排除 persistent shadow proxy；分别检查屋面比正式墙体 X/Z 四边至少多覆盖 `0.08 m`、檐底不低于墙顶 `0.02 m` 且最大悬空不超过工械坊 `0.14 m` / 宿舍 `0.10 m`，并检查山墙从墙顶连接到屋脊。

## T0135-P8AR7 可进入建筑屋面封闭结构

- `BuildingArtView._add_gable_wall(...)` 统一创建闭合 `PrismMesh` 三角棱柱；调用方给出横向宽度、山墙高度、厚度、材质和可选 Y 轴朝向。节点置于各建筑 `Exterior/Sealed*GableEnds`，因此自动进入 scene-local 外墙透明材质与持久 shadows-only 代理链，但自身不创建 CollisionObject、NavigationRegion、Area 或权威接口。
- 食堂 / 酒窖 / 工械坊的屋脊沿局部 X，山墙位于 `x=±端点` 并旋转 `90°`；宿舍屋脊沿局部 Z，山墙位于 `z=±端点`。每端的横梁、王柱和两根顺坡撑由既有 `_add_box / _add_beam_between` 生成并与山墙同属 Exterior。
- `FormalBlacksmithArtView._build_roof()` 不再生成 `NorthSlateSlope / SouthSlateSlope / ColdRidgeCap`，改建 `FlatSlateDeck`、四边 `*ParapetCap` 和七道 `FlatSlateSeam`；烟囱、`RoofStructureAdditions`、升级屋面路径、透明 / 阴影代理及正式空间权威接线不变。

## T0135-P6R3 原点归位与连续 DirectionalLight 接线

- `environment_art_v1.celestial_cycle.directional_transform_update_interval_game_seconds` 当前为 `0.0`。`_consume_direction_update_due()` 在非正值时允许每个时间信号写入真实太阳 / 月亮 Basis；正值时仍可按绝对游戏秒分桶，供低频调试降级使用。
- `station_layout_v2.migration.preview_offset=[0,0]`，`FormalStationLayout` 和正式 CameraRig 不再携带旧 X=1000 偏移。`previous_formal_world_offset` 只供 NPCSystem 恢复无 `world_origin` 的旧 v1 空间检查点时迁移。
- 正式模式下，StationLayoutController 隐藏 `Station/Ground|Buildings|Props`，并缓存后把其 CollisionObject3D layer / mask 置零；GM legacy compatibility 恢复缓存值。正式 NPC / Enemies / Effects 根不在该列表中。
- `get_debug_snapshot().directional_shadow` 继续公开刷新间隔、桶、累计写入次数和已应用 ray direction；P6R3 专项同时读取真实 Light Basis，确认连续三次时间信号产生连续三次方向写入。
- GM 跳时、读档与昼夜切换仍沿 EventBus 原链生效；没有新增 GM 入口。现有 Main `set_time`、暂停和倍速即可观察，错误项目路径的 MCP 不参与当前工作区验收。

## T0135-P6R 方向光级联稳定化接线

- `environment_art_v1.celestial_cycle` 新增 `directional_shadow_blend_splits` 与三级 split 配置；`CelestialCycleController._configure_light()` 对 `SunDirectionalLight / MoonDirectionalLight` 统一应用四级联、`120 m`、`0.12 / 0.30 / 0.60` 和边界混合。
- `get_debug_snapshot().directional_shadow` 暴露实际模式、范围、淡出、混合、三级分割和 `sun_moon_match`，便于专项验证日月交接不会换到另一套阴影质量。旧 `Main/SunLight` 接线、WorldEnvironment、P7R shadows-only 壳体及功能灯子控制器均未改。

## T0135-P8AR6 宿舍卫生间附属物结构

- `data/station_layout.json.service_outbuildings` 登记 `dormitory_latrine / dormitory_latrine_02`；`StationLayoutController._build_public_props()` 将它们实例化为 `FormalStationLayout/PublicProps/DormitoryLatrine / DormitoryLatrine02`，不进入 `BuildingRoots` 或 BuildingSystem。P8AR6R 只增加第二条同规格配置，不复制控制器分支。
- `FormalDormitoryLatrineArtView.gd` 只生成外部 Mesh 树：`StoneFoundation / ClosedExteriorShell / OakTimberFrame / ClosedPlankDoor / PermanentOpaqueRoof / RoofVentilation / GroundingDetails`。根元数据显式锁定 `has_interior=false / enterable=false / interactive=false / functional=false / roof_fade_member=false`。
- 布局控制器在每个旋转根下各生成一个 `StaticCollision` BoxShape，并加入 `formal_navigation_source`；因此两间分别是实体导航障碍，但都没有入口 Area、NavigationLink、门动画、灯光或点击热点。生产 NavMesh 在 `_build_spatial_contract()` 前已能读取两个碰撞。

## T0135-P8AR4 食堂逐灶 VFX 结构

- `FormalDiningHallArtView/KitchenWorkFX` 挂载 `DiningKitchenWorkFX.gd`，下设 `Station01–03`。每组包含 `FireVisuals`、`FoodVisuals`、`PotSteam`、`ChimneySmoke` 和有影 `FireLight`，并携带 `workstation_id / chimney_name / required_level` 元数据。
- 控制器监听 `EventBus.building_state_changed / npc_state_changed`，deferred 合并后读取 BuildingSystem 与 NPCSystem 的稳定状态；它不轮询资源，也不写 ActionSystem。StationLayoutController 中三个夹具 `Ember` 同样携带 `dining_work_heat / workstation_id`，由该控制器按同一工位独立显隐。
- 三个 `ChimneySmoke` 相对各自灶根位于 `(0,6.55,-0.82)`，与建筑局部 `x=-3.8/0/3.8,z=-4.82` 的三根烟囱出口重合；烟雾在屋顶透明链之外，烟囱模型仍按既有屋顶 / 等级规则显示。
- P8AR4R2 后 Lv.2 不再创建 `RoofStructureAdditions/WestSparkGuard` 与 `CenterSparkGuard`，也不保留空的 Lv.2 屋顶透明路径；唯一升级屋顶分支是 Lv.3 第三烟囱。西 / 中烟囱继续属于一级 `Roof/LevelOneKitchenChimneys`。

## T0135-P8AR5 共享中世纪洗手池结构

- `MedievalWashBasinBuilder.build_wash_basin(...)` 返回纯 Node3D / MeshInstance3D 表现树，由宿舍 `Interior/Level1Details/CommonWashBasin` 和诊所 `Interior/Level1Details/ClinicWashBasin` 共用；调用方只传位置、朝向和建筑调色板。
- 模型稳定结构件包括 `StoneFooting / OakLeg / LowerStorageShelf / BasinSupportSlab / HammeredBasinBowl / RaisedBasinRim / CleanWaterSurface / OakBackBoard / CopperWaterCistern / CopperSpout / HangingLinen`。盆体由开放式椭圆双层 SurfaceTool 网格构成，水面位于内腔，不使用实心球遮住水面。
- 两个实例都设置 `authority_role=non_workstation_decoration`、`prop_type=medieval_wall_wash_basin`，不创建 CollisionObject3D、NavigationRegion3D、Area3D、Marker3D 或工位；现有正式 NavMesh、fixture 碰撞与屋顶透明链不变。
- P8AR5R 将宿舍 `CommonWashBasin` 固定在 `(-1.0,0,-5.78)`，并把 `WarmStoneHearth / HearthChimney` 同轴固定在 `(1.0,0,-5.78)`；专项同时锁定洗手池坐标、洗手池—床 / 壁炉零重叠和炉体—烟囱平面对齐。
- `_add_kitchen_chimney()` 通过 `_add_hollow_square_course()` 分别以四段 Box 生成筒身、砖冠和可选铁箍，中央 `0.38 m` 烟道无 Mesh；旧实心 `OpenFlue` 节点已删除。专项用中心点对所有子 Mesh 做局部 AABB 复核，防止后续装饰再次封堵孔洞。

## T0135-P8AR3 铁匠铺半开放结构与炉火接线

- `FormalBlacksmithArtView` 生成后炉砌体、前侧开放棚面、同轴烟囱和四个带结构支撑的命名灯具；灯具元数据分布为 Lv.1 两盏、Lv.2 一盏、Lv.3 一盏。`_apply_visual_level()` 同步灯模可见性并 deferred 刷新功能灯控制器。
- `building_fixture_layout_v1.blacksmith` 将三砧视觉根抬高并由 `StationLayoutController._decorate_blacksmith_anvil()` 补足石脚、木墩、铁箍和工作热铁；热铁带 `smithy_work_heat / workstation_id` 元数据。共享炉的 fixture 根继续提供等级 / 碰撞审计，详细炉体只由 ArtView 生成，避免双层重叠。
- `SmithyAmbientFX` 连接 `EventBus.building_state_changed / npc_state_changed`，deferred 读取 BuildingSystem 和 NPCSystem 的已稳定状态。快照暴露活动工位 / NPC、火光、粒子、烟和热铁数量；节点只读且 presentation-only。
- 铁匠铺静态壳碰撞对后侧墙保留 `4.6 m` 深度，前侧只保留可见门柱段；NavigationMesh 仍从正式静态碰撞烘焙。后炉基础填光由 `environment_art_v1` 使用局部后移的 `8 m / 72°` SpotLight，前棚工作灯仍由 `BuildingFunctionalLightController` 管理。
- P8AR3R2 后 `_add_smithy_lantern()` 的 `rear_masonry_wall / east_masonry_wall / west_masonry_wall` 三种方向都只生成贴墙背板、短挑臂和斜撑；东西壁托按墙面法线旋转，四盏灯不再生成落地柱、跨梁或局部门架。支撑继承灯具 `functional_lantern_required_level`，无碰撞 / 导航；功能灯控制器继续按同一灯模最终可见性启停光源。
- `HoistChain / HoistHook / CeilingHoistBeam` 同属 `UpgradeVisuals/Level3/RoofStructureAdditions`，由既有 additional roof fade 一起处理。`PedalGrindstone` 位于二级东侧服务区 `(3.2,0,3.1)` 并标记 `primary_entry_clear=true`，不再占用中央门轴。

## T0135-P8AR2 露天灯具等级与远景接线

- `FormalGardenArtView / FormalTrainingGroundArtView / FormalStableArtView` 为四盏 authored 灯写入 `functional_lantern_required_level`，分布固定为 Lv.1 两盏、Lv.2 一盏、Lv.3 一盏；`_apply_visual_level()` 同时更新灯柱 / 棚柱灯具模型可见性。
- `BuildingFunctionalLightController` 保存每个 emitter 的源灯具引用，以源节点最终树可见性作为解锁结果；新增监听 `EventBus.building_state_changed` 并 deferred 刷新。快照可直接读取逐建筑解锁灯数与 `1:2 / 2:1 / 3:1` 元数据分布。
- 所有 `OmniLight3D` 及被接管既有 Light3D 的 `distance_fade_enabled=false`。正式相机 `20–70 m` 缩放不再关闭灯芯 / 光池，屋顶、墙体阴影和体积雾隔离规则不变。

## T0135-P8AR 灯具姿态与露天照度接线

- `FormalGardenArtView / FormalTrainingGroundArtView` 各生成四个带实体支撑的命名灯笼；`FormalStableArtView` 在现有内侧棚柱上生成四个命名灯笼；`environment_art_v1.functional_lights` 同步按这些唯一名称解析，不使用父级前缀误匹配。
- `FormalTavernArtView` 的两灯改挂后墙内侧木背板，`FormalMainHallArtView` 的两灯改挂正门两侧门廊灯柱。所有受审计灯具带 `mounted_to_structure / mount_surface` 元数据，专项逐一验证，不向碰撞或 NavigationServer 注册。
- 控制器逐建筑快照新增 `designed_energy_total / maximum_range`，用于锁定露天场地的最低可工作照度；它们仍是表现审计值，不参与资源、NPC 行动或建筑效率结算。

## T0135-P8A 全建筑实体功能灯接线

- `CelestialCycleController` 从 `environment_art_v1.celestial_cycle.functional_lights` 创建唯一 `BuildingFunctionalLightController` 子节点，并在 `get_debug_snapshot().functional_lights` 暴露配置数、灯具 / 光源数、逐建筑占用、醒着人数、启灯状态和缺失宿主审计。
- 控制器优先解析 `/FormalStationLayout/` 的 `building_art_view`；围墙与前后门按正式 GateArt 元数据补充解析。十二座建筑复用已有唯一命名灯笼，围墙 / 正门 / 后门从同一 Quaternius 灯笼资源生成实体灯和铁托。P8AR3 后当前共 `39` 个灯具并接管教堂既有一盏暖光，合计 `40` 个受控光源。
- 新光源挂在各正式宿主局部坐标中，开启 shadow、关闭 volumetric fog；P8AR2 后关闭距离淡出。灯具实例会递归剥离碰撞与导航节点。现有 GM `set_time`、建筑升级和 NPC 行动 / 睡眠入口足以验收，不增加重复按钮。

## T0135-P7R4 铁匠铺绑定与实体墙体遮光接线

- `CelestialCycleController._ensure_interior_fill_lights()` 先按 `building_id` 收集所有 `building_art_view` 候选，再由 `_interior_view_priority()` 优先正式布局 / 可见节点并降权旧 `WorldRoot/Station` 兼容节点，避免共享 `blacksmith` ID 时把灯挂到隐藏铁匠铺。
- `environment_art_v1.celestial_cycle.interior_fill` 为七座可进入建筑各配置一盏有影填光：六座封闭建筑使用 `[0,2.3,0] / 13.5 m / 84°`，P8AR3 半开放铁匠铺使用后炉区 `[0,2.3,-4.0] / 8 m / 72°`；`InteriorFillLights/InteriorFill01` 向下照射且体积雾能量为零。
- P7R 已生成的 `PersistentShellShadowCaster` 无需另建室内专用挡光体：屋顶 / 外墙代理保持 opaque shadows-only，自动遮挡七盏局部灯。`RoofVisibilityController` 的 reveal 信号继续统一控制启停，封闭时活动灯数为零。

## T0135-P7R3 日光色温与柔和面状补光接线

- `interior_fill` 新增 `daylight_sun_mix / daylight_neutral_color / daylight_neutral_mix` 与 `soft_area_fill`。`_calculate_interior_daylight_color` 每次时间变化后混合太阳 / 环境色，`_update_interior_lights` 再用 P7R2 `daylight_weight` 从各建筑夜间暖色连续插值。
- P7R3 的 `color_by_building / daylight_color` 快照及色温算法继续保留；其两盏高位无影 SpotLight 参数已由 P7R4 的单盏屋檐下有影灯配置替换。
- 节点数量、屋顶信号、雾衰减、TimeSystem / EventBus / GM 接线和 P7R 持久阴影代理均未改变。

## T0135-P7R2 室内日照同步曲线接线

- `environment_art_v1.celestial_cycle.interior_fill` 新增 `daylight_start_time / daylight_peak_time / daylight_end_time`、`night_base_scale / day_peak_scale / daylight_curve_power`；当前锚点为 `06:00 / 12:00 / 18:00`，倍率为 `1.0 → 1.30 → 1.0`。
- `CelestialCycleController._calculate_interior_time_curve` 从 `_last_time` 逐秒计算上午正弦缓入与下午余弦缓出，并在 `get_debug_snapshot().interior_fill` 暴露 `time_scale / daylight_weight / lighting_phase`。结果继续乘以每座建筑既有 `max_energy` 与屋顶 reveal，不新增灯节点。
- 现有 GM `set_time`、暂停、倍速和读档沿 EventBus 原链即时重算；不增加第二套 GM 入口或时钟。

## T0135-P7R 建筑透明壳体持久阴影接线

- `BuildingArtView._cache_roof_mesh / _cache_exterior_materials` 在复制渐隐材质前保存原始 Mesh / 材质到 internal `PersistentShellShadowCaster`。代理设置 `SHADOW_CASTING_SETTING_SHADOWS_ONLY`、禁用 GI 和进程；源 Mesh 设置 `SHADOW_CASTING_SETTING_OFF`，透明度变化只更新 scene-local 材质 alpha。
- internal 代理挂在对应源 Mesh 下，所以不需要逐帧同步 Transform，也会跟随自动门、升级层级和建筑根显隐。`get_roof_visibility_snapshot` 新增 roof / exterior 代理数量、持久阴影状态和可见网格重复投影审计字段。
- `Formal*ArtView._mesh_count_at` 统一调用基类 authored mesh 计数，跳过代理；既有升级外观数量、边界、碰撞、点击和导航合同不变。

## T0135-P7 动态环境与透明室内接线

- `FormalEnvironmentArtView -> FormalGroundSurfaceArtView -> CelestialCycleController` 现在组合 `SunDirectionalLight / MoonDirectionalLight / DynamicWorldEnvironment`。`DynamicWorldEnvironment` 持有运行时唯一 `Environment + Sky + ProceduralSkyMaterial`，使用 ACES、传统指数雾及可配置调整参数；环境快照暴露相位、环境能量、曝光和雾密度供专项审计。
- `CelestialCycleController` 监听既有 `/root/Main/Presentation/RoofVisibilityController.roof_visibility_changed`。后者每次应用相机距离后附带所有 `BuildingArtView.get_roof_visibility_snapshot()`，因此补光与既有屋顶 / 外墙透明曲线严格同源，不轮询相机、不复制透明阈值。
- 控制器按 `environment_art_v1.celestial_cycle.interior_fill.buildings` 在七座正式 BuildingArtView 下各建一个 `InteriorFillLights` 根和一盏向下 SpotLight3D。透明度决定 reveal 权重，日照曲线决定昼夜强度；屋顶封闭即隐藏，节点均开启实体壳遮光、关闭体积雾贡献且只属表现层。
- P7 沿用 GM 既有 `set_time` 与 `roof_visibility` 验证入口，没有新增重复按钮。Main 旧 `SunLight` 仍保留稳定路径但完全退役；不存在第二个 WorldEnvironment、环境时钟或灯光存档字段。

## T0135-P6 真实日月循环接线

- `FormalGroundSurfaceArtView` 在 P1–P5 地表 / 地形 / 森林 / 散布之外实例化 `CelestialCycleController`，后者拥有且仅拥有 `SunDirectionalLight / MoonDirectionalLight` 两个表现节点；环境根快照通过 `celestial_cycle` 暴露当前时间、方向、高度、能量、色温与主阴影归属。
- 控制器只读 `/root/GameState` 的绝对日 / 时 / 分 / 秒并监听 `/root/EventBus.time_changed`。每次信号都从升起、南中、落下配置直接重算完整球面姿态，不累计上一帧角度、不调用 TimeSystem、不写存档；暂停无信号即冻结，x2 / x4 和 GM `set_time` 自动沿既有时间权威同步。
- Main 旧 `SunLight` 保留稳定节点路径但置为隐藏、零能量、无阴影；控制器还按 `legacy_light_paths` 运行态重复确认退役，避免旧固定光与日月形成双光。日月能量比较后任意时刻最多一盏开启 DirectionalLight 阴影。
- P6 不创建 `WorldEnvironment`、天空、雾、功能灯或室内补光。P7 将继续消费相同天体快照 / 太阳高度，不新建环境时钟。

## T0135-P5 全图自然散布接线

- `FormalGroundSurfaceArtView` 在 P2/P3 地形与 P4R 森林之后实例化 `FormalEnvironmentScatterView`，后者只读 `environment_art_v1.natural_scatter`、`station_layout_v2.roads / buildings / public_locations`、河流截面与山脉截面，不复制地点、路线或地形权威。
- 五类散布分别合并为少量 MultiMesh：河岸读取实时河槽外缘，山脚按三层山面高度落地，林下按距围墙与正式路线净空筛选，道路边缘由既有 42 段道路宽度派生，城内空地使用 15 点围墙多边形并排除最大等级地块、道路与公共地点。
- 湿痕 / 苔藓 / 泥肩过渡使用合并 ArrayMesh 和顶点透明度；草、蕨、灌木、岩石均为低多边形程序网格。表现根明确不创建 `StaticBody3D / CollisionShape3D / Area3D / NavigationRegion3D`，NPC、敌人、商车、逃离和器械继续使用原权威空间合同。

## T0135-P1R 地表返修接线

- `StationLayoutController._build_building_roots()` 仍创建稳定路径 `BuildingRoots/*/ReservedLot`，但节点改为纯 Node3D 元数据，只保存 `lot_size / planning_metadata_only`，不再生成可见 BoxMesh。碰撞、建筑外壳、最大等级包络和点击节点均未删除。
- `FormalGroundSurfaceArtView` 不再生成独立 Plaza Mesh 或 DoorWear Mesh；`GroundSurface` 只标记广场由 `FormalRoadNetworkArtView` 的 42 段道路交汇承担，入口磨损同样并入道路泥肩。广场逻辑地点与道路端点没有变化。
- Quaternius 卵石缩为两个非闭合簇；短草 / 三叶草按 20 个中心生成 54 个实例，导入材质保留原贴图并使用 alpha-scissor、双面、无影草片，避免远景黑块。全部细节仍剥离碰撞且不创建 Area / NavigationRegion。

## T0135-P1 正式城内地表与广场接线

- `StationLayoutController` 读取并校验 `environment_art_v1`，在完成 Terrain / Roads 后实例化 `FormalEnvironmentArtView`。旧 `Plaza/Patch00–02` 不再生成 MeshInstance，但 Plaza 根和 `station_layout_v2.public_locations.plaza=(0,10), radius=4 m` 继续保留给权威地点系统。
- `FormalGroundSurfaceArtView` 用驿站 15 点 interior polygon 生成 13 三角深草覆盖层；首版的三环广场与 12 个门口磨损已被 P1R 否决并移除，保留本段只作历史实现记录。
- 首版 12 块环形卵石和均匀植被散布也已由 P1R 的两簇碎石 / 成簇植被覆盖。导入细节始终剥离 CollisionObject，整个表现根无 StaticBody、CollisionShape、Area3D 或 NavigationRegion3D。
- 道路仍由 `FormalRoadNetworkArtView` 按既有 42 段生成且 `roads_affect_navigation=false`。P1 不修改物理碰撞、生产 NavigationMap、NPC / 敌军寻路、建筑点击、敌路、商路或逃离权威；功能在 Main 直接可见，因此不增加 GM 入口。

## T0135-P0R 自然场景与日月循环规划接线

- `data/presentation/environment_art.json` 作为环境表现配置源，规划保存地表色板、分区 seed / 密度 / 资源池、道路 / 门坪 / 工位 / 敌路排除参数、河谷 / 山脉可见包络、日月轨道和质量档；它不保存时间、导航、敌人生成或建筑状态权威。
- `scenes/environment/FormalEnvironmentArtView.tscn` 作为正式环境表现根，已由 `StationLayoutController` 在正式布局下实例化并组合 P1–P5 的地表、地形、森林与自然散布。旧自然碰撞和 NavigationMap 继续由 `StationLayoutController` 持有，表现根不得创建第二套全图导航。
- `scripts/presentation/environment/FormalGroundSurfaceArtView.gd` 已由 P1R 覆盖首版：当前只保留城内深草变化、浅排水和成簇地表细节，独立广场 / 门前贴片为零；只读 `station_layout_v2.roads / plaza / buildings` 与环境配置。`public location=plaza / center=(0,10) / radius=4 m` 保持不变。
- T0135-P1R3 曾试接世界坐标草地、方向化泥土及三类 Painted 贴花，但因平面绘制纹理与现有低多边形 3D 材质语言不统一而按用户反馈回滚。正式架构继续使用 P1R2 程序化草地与 T0132-P5 程序化道路，不加载候选地表资产，也不存在 `PaintedBuildingFootprints / PaintedGrassDirtTransitions / PaintedRoadDetails` 运行节点。
- `scripts/presentation/environment/FormalTerrainArtView.gd` 已完成 P2/P3 河谷 / 山脉。P4R 的 `FormalForestArtView` 从前 / 后 / 侧 bounds、围墙多边形距离、河槽边界、山体高度、敌 / 商路线和出生净空生成统一针叶 MultiMesh 林；密度按地形连续变化，不再加载阔叶树资产。StationLayoutController 继续持有 8 段 River Cliff、4 段 Rock Ridge 和 12 段 Dense Forest StaticBody；可见层不创建碰撞 / NavMesh。
- `scripts/presentation/environment/CelestialCycleController.gd` 已在 P6 负责太阳、月亮方向光与主阴影表现；P7 将在同一绝对时刻基础上组合 `WorldEnvironment`、天空与雾。它不维护第二套时钟，也不修改 TimeSystem、行动、波次、商人或存档 Schema。
- `resources/materials/environment/` 规划存放世界坐标地表、压实泥土、河水、湿痕和雾材质；`scenes/vfx/environment/` 规划存放烟、火、火星、尘土等通用表现。功能状态只由既有建筑 / 行动信号投影，粒子本身不提交生产、伤害或事件事实。
- P1–P8 分步迁移资源，只有当该步正式视图通过后才隐藏对应旧占位表现；不会一次删除旧物理边界或复制全部 68 个自然模型。现有 GM `set_time` 已足够直接观察日月循环，不新增重复调试入口。

## T0132-P6 正式公告牌接线

- `StationLayoutController._build_public_props()` 从 `station_layout_v2.public_locations.notice_board` 读取位置 / 朝向，在 `FormalStationLayout/PublicProps/NoticeBoard` 实例化共用 `NoticeBoard.tscn`；SpatialContract 内的隐藏 Marker 继续用于位置校验，但不再冒充正式可见模型。
- `NoticeBoard.tscn` 保留 `NoticeBoard.gd` 根与 `VisualRoot/NoticeBoardLabel`、`NoticeBoardClickArea` 稳定路径；`VisualRoot` 新挂 `FormalNoticeBoardArtView` 并在子节点生成完整低模结构。旧兼容地图与正式地图因此复用同一模型和交互脚本，不维护第二套公告逻辑。
- 公告牌只有 Area3D 点击热点，没有 StaticBody / NavigationRegion；点击仍发 `EventBus.notice_board_clicked`，NoticeBoardPanel 仍只提交草稿到 MemorySystem。表现快照只暴露模型数量、纸页 / 屋顶 / 支柱合同，不新增存档或建筑 Schema。

## T0132-P5 正式道路表现接线

- `StationLayoutController._build_roads_and_plaza()` 保留 `FormalStationLayout/Roads` 容器和既有广场，只把旧的逐段 BoxMesh 道路替换为一个 `FormalRoadNetworkArtView`。该视图只读消费 `station_layout_v2.roads`，不维护另一份端点、宽度或路线配置。
- `FormalRoadNetworkArtView` 用 ArrayMesh 生成泥肩 / 路芯与断续车辙，用低矮 MeshInstance3D 生成边石和共享端点交汇补片；全部节点保持 presentation-only，不创建 `StaticBody3D / CollisionShape3D / NavigationRegion3D`，也不接入选择射线。
- 调试快照暴露路段分类、端点 / 宽度、ribbon / rut / stone / junction 数量和三角面数供专项验证；`roads_affect_navigation=false` 是显式合同。NPC、敌军、商人、逃离者和战斗阶段仍使用原 NavigationMap、实体碰撞及各自权威完成条件。

## T0132-P4b 正式箭塔与主厅木台接线

- `building_fixture_layouts.json` 的四个 `main_hall_device_platform` 改为实例化 `FormalMainHallDefensePlatformArtView.tscn`；`StationLayoutController` 识别该完整正式场景后不再叠加旧石框 / 灰护墙。fixture 根位置、旋转、碰撞和 `device_anchor_y` 不变。
- `data/defense_device_defs.json` 为 `wall_arrow_tower` 指向 `FormalArrowTowerArtView.tscn`。模型复用 `DefenseDeviceView.configure_device / play_device_action` 可选接口，在场景内部驱动 `AimingYawPivot`、动态弦、后坐、回位轮、装填箭可见性和短命飞行箭；它不进入系统权威状态或存档 Schema。
- `DefenseDevicePresenter` 继续逐次转发 `defense_device_action_resolved`，没有新增信号。专项与既有器械部署测试同时验证正式场景实例化及真实自动攻击事件已进入箭塔动作视图。

## T0132-P4a 正式弩床表现接线

- `data/defense_device_defs.json` 只为 `wall_ballista` 指向 `FormalBallistaArtView.tscn`，箭塔仍走既有回退。`DefenseDeviceView` 保存最新部署快照，在模型实例化后调用可选 `configure_device`，收到动作时再调用可选 `play_device_action`；不认识新接口的占位 / 后续模型仍可继续显示。
- `FormalBallistaArtView.gd` 在独立场景内以 Quaternius WoodTrim / MetalOrnaments PBR 纹理生成静态结构，运行态只旋转 `AimingYawPivot`、更新两段弦的 CylinderMesh、驱动后坐 / 绞盘 Tween、切换床面箭并创建短命表现弹体。模型根不进入 DefenseDeviceSystem，不持有 HP、库存、射程、选敌或伤害权威。
- DefenseDeviceSystem 单次射击结果从正式 slot 和选中 enemy 复制 `origin_position / target_position`，同时携带最终 `attack_interval`；EventBus 继续只发一次 `defense_device_action_resolved`。表现弹体挂到当前场景避免跟随转台移动，抵达目标快照后 `queue_free`。
- `get_debug_snapshot()` 暴露场景路径、平台姿态、包络、装填状态、弦位置、射击 / 飞行 / 重装计数和材质来源供专项检查；这不是存档 Schema。当前 P4a 可直接从 Main 部署并开战观察，未新增 GM 接口。

## T0132-P2 仓库三级正式表现

- `StationLayoutController` 不再内联生成 A3b12R 的透明木格栅仓架和两块拉伸屋面，改为实例化 `FormalWarehouseArtView.gd`；旧 Envelope 继续隐藏，正式最大 `StaticCollision`、七组分类 fixture / 碰撞、敌军攻击点与导航不变。
- `SolidWarehouseMass` 使用 Quaternius 同源 RockTrim / Plaster / UnevenBrick / WoodTrim PBR 贴图构成连续地基、下仓、密封主体和承重顶盖；12 个导入 `warehouse_wall_woodgrid` 模块只补木构立面。P2R 删除五个重复完整屋顶，改用一个 `main_hall_roof` 模块覆盖主仓并标记 `roof_profile=single_continuous_ridge`；Lv.2 侧仓使用 `roof_round_tiles_4x4`，Lv.3 安全仓复用单屋脊瓦顶。`art_revision=t0132_p2r`，主体明确标记为封闭实体而非库存容器。
- `BuildingArtView` 的镜头接口被覆盖为屋顶 / 外墙始终不透明，`interior_revealed=false`；仓库保持不可进入，正式点击只通过 `14×6.6×14 m` 表现包络选择 BuildingPanel。
- 等级层只读投影 `5→6→7` 外部分类 fixture / 碰撞：Lv.2 增东侧仓与加固，Lv.3 增后部挑高安全仓。分类节点保留 `inventory_count_authority=false`，不查询 ResourceSystem 当前数量。HP 只读投影轻 / 重损伤，GM `warehouse_art_level` 只切换表现。

## T0132-P1 主厅六级正式表现

- `StationLayoutController` 不再内联构建 A3b11R 主厅大块几何，改为实例化 `FormalMainHallArtView.gd`；旧 Envelope 继续隐藏，正式 `StaticCollision / FixtureLayout` 和空间路由不变。
- P1R 删除了被默认俯视读成淡蓝白盒的单一 `CentralGatehouse`，改由 `CentralCommandCore / CommandNeck / FrontGatehouse` 三段体量和 `CentralCrossRoof / FrontGatehouseRoof` 两个完整程序坡屋顶组成中轴；`art_revision=t0132_p1r`。这些节点只改变 Mesh / Material 表现，不改变碰撞根或点击权威。
- P1R2 曾将上述主体全部换成 53 个墙片和四组超大导入屋面，但 Quaternius 本地包只有模块、没有完整主厅成品；该结构缺少封闭体量与屋面承重层，并遮住四角器械平台，现仅作为返修历史保留。
- P1R3 用 `SolidMainHallMass` 建立封闭的地基、灰泥主体、承重屋面和中央指挥屋；这些 BoxMesh 明确标记 `solid_visual_volume`，并使用从 Quaternius 源资产提取的 RockTrim / Plaster / UnevenBrick PBR 贴图与三平面 UV，不再是纯色白盒。`TexturedFacadeModules` 的 50 个导入墙 / 门模块补足窗、木构和立面细节，`LoadBearingDefenseTerrace` 提供连续屋面、女儿墙、垛口与四个平台通路；`CentralKeepRoof` 和门楼雨棚均为紧凑导入瓦面，不进入平台净空。当前 `art_revision=t0132_p1r3`、`visible_shell=closed_textured_quaternius_composite`。
- 表现根继承 `BuildingArtView`，但覆盖为六级累计层，并因主厅不可进入而始终返回 `interior_revealed=false`、强制屋顶 / 外墙不透明。`interaction_bounds=22×7.4×18 m` 用于正式远程布局上的建筑点击。
- BuildingSystem 等级驱动 `Level2..Level6` 可见性与外部 fixture 碰撞，累计数为 `1/2/3/4/5/7`；DefenseDeviceSystem 仍唯一拥有 `1/1/2/2/3/4` 槽位解锁与部署权威。StationLayoutController 新增只读 `get_defense_device_slot_pose(...)`：主厅从正式平台 fixture 的 `device_anchor_y` 生成世界锚点，围墙从正式正门墙段生成锚点；默认正式世界激活时调用 `DefenseDeviceSystem.bind_formal_slot_positions(...)`，显式 legacy compatibility 才恢复 JSON 旧坐标。部署快照、`DefenseDeviceView`、世界 `+` 标记和自动攻击原点由同一个运行态 slot position 派生。
- `_refresh_building_state()` 只读 `hp/max_hp`，在 `<76%` 和 `<41%` 切换两级损伤节点；没有表现节点写 HP、修复、伤害或失败状态。GM `main_hall_art_level` 同样只调用 debug 表现层。

## T0131-P9 正式马厩建筑切片

- `StationLayoutController` 在 Stable 的正式 `StaticCollision / FixtureLayout / HorseAnchors` 完成后实例化 `FormalStableArtView.gd` 并隐藏旧 Envelope。表现保持 `16 × 16 m` 地块中的 `14 × 14 m` 露天马院，不建立完整墙壳。
- 等级同步启用 fixture `7→8→9`、碰撞部件 `23→24→27`、照料位 `2→2→3` 与马匹锚点 `7→7→8`。Lv.2 不启用 `StableCare03Trough / StableCare03Rail`；Lv.3 才启用第三照料配套。
- `HorsePresentation` 读取 `HorseSystem.get_horses_snapshot()`：`stable` 马（包括 `waiting_for_rider_at_stable`）映射到既有 `HorseAnchors` 并保持 Idle，`returning_stable` 与旧兼容 `approaching_rider` 按权威世界位置移动，`ridden / dead` 隐藏；表现马无碰撞、AI、库存、伤害或骑乘权威。
- Stable 始终允许内部 NPC 点击优先；围栏、马栏和马匹不渐隐，两侧连续顶棚从外柱延伸至马栏内沿并完整覆盖八个马体锚点，只有两侧及升级小遮棚登记到 `70→58 m / 0.06` 透明链。入口复用 `BuildingAutoDoor`，净口 `2.58 × 2.35 m`、低门叶 `1.22 m`。
- GM `stable_art_level <1|2|3>` 只调用表现根预览，不修改 BuildingSystem 等级、HorseSystem 马匹位置或照料占用。

## T0131-P8 正式训练场建筑切片

- `StationLayoutController` 在 TrainingGround 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalTrainingGroundArtView.gd` 并隐藏旧 Envelope。表现保持 `16 × 18 m` 地块中的 `14 × 16 m` 露天训练院，不建立完整墙壳。
- 等级同步启用 fixture / 碰撞 `6→8→10`，教官 / 训练位为 `1+2→1+3→2+4`。六个现有 Marker 与动作净空不变；Lv.2 只启用 `TrainingStudent03Dummy`，Lv.3 才启用 `TrainingInstructor02CommandPost / TrainingStudent04Dummy`。
- TrainingGround 覆盖 `is_interior_revealed_for_selection()` 并始终返回 true。木栅、旗位和器械不渐隐；主教官棚、二级器材棚和三级二号教官棚登记到 `70→58 m / 0.06` 屋顶透明链。
- 入口复用 `BuildingAutoDoor` 的低门合同，门叶 `1.05 m`、净通行 `2.08 × 2.35 m`。GM `training_ground_art_level <1|2|3>` 只调用表现根预览，不修改 BuildingSystem 等级或训练占用。
- 历史 A3b7 是最高等级全配置审计；正式美术接入后测试显式预览 Lv.3 再检查十件碰撞，避免把 Lv.1 正确关闭的未来 fixture 误判为缺失。

## T0131-P7 正式菜园建筑切片

- `StationLayoutController` 在 Garden 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalGardenArtView.gd` 并隐藏旧 Envelope。表现是 `14 × 14 m` 露天生产区，不建立完整墙壳；最高级包络约 `13.82 × 13.87 m`。
- 等级同步启用可见 fixture `6→8→9`、碰撞部件 `10→12→15` 与耕作位 `2→2→3`。Lv.2 只启用灌溉 / 堆肥质量设施；Lv.3 才启用 `GardenPlot03Bed`，其表现支路显式携带 `workstation_id=garden_plot_03`。
- `BuildingAutoDoor` 新增向后兼容的 `leaf_visual_height`：默认仍等于 `clear_height`，菜园将可见门叶设为 `1.02 m`，但净通行审计仍为 `2.08 × 2.35 m`。传感器、无阻挡碰撞与 presentation-only 权限不变。
- Garden 覆盖 `is_interior_revealed_for_selection()` 并始终返回 true，确保露天 NPC 点击优先、空地仍可回退 BuildingPanel。围栏不渐隐；主农具棚顶和二 / 三级遮棚登记到屋顶透明链，使用 `70→58 m / 0.06`。
- GM `garden_art_level <1|2|3>` 只调用表现根预览。BuildingSystem、ActionSystem、NPCSystem、ResourceSystem 与正式 NavigationMesh 继续分别拥有等级 / 工位、周期行动、实体到达、粮食与路径权威。

## T0131-P6 正式酒窖建筑切片

- `StationLayoutController` 在 Tavern 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalTavernArtView.gd` 并隐藏旧 Envelope。正式房体约 `12 × 10 m`，最高级可见包络保持在 `14 × 12 m` 地块内。
- 等级同步启用 fixture / 碰撞 `4→5→6`，其中酿酒位为 `2→2→3`；Lv.2 只启用熟成架，Lv.3 才启用 `Cellar03FermentationCask`。新增冷却、铜管、批次记录、制桶和装卸节点均没有工位 Marker。
- 两级 `RoofStructureAdditions / ExteriorAdditions` 分别登记到附加屋顶 / 外墙透明路径；主屋顶、墙体、通风帽、外部桶架和装卸附件统一使用 `70→58 m / 0.06`。自动门沿局部 `+Z` 对齐，净口 `2.08 × 2.35 m`。
- GM `tavern_art_level <1|2|3>` 只调用表现根 `debug_force_visual_level`。专项验证预览不改变 BuildingSystem 的 Lv.1 权威，并回归正式酿酒与 MerchantSystem 酒交易。
- P6R 的后墙、遮阴熟成和装卸桶由 `_add_storage_barrel` 统一实例化 Quaternius `barrel.glb`，写入 `decorative_storage_barrel / required_level / authority_role` 元数据；运行快照按可见节点报告 `6→11→14`，不创建碰撞、Marker 或占用条目。

## T0131-P5 正式宿舍建筑切片

- `StationLayoutController` 在 Dormitory 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalDormitoryArtView.gd` 并隐藏旧 Envelope。宿舍长屋占约 `14 × 13 m`，最高级可见包络限制在 `16 × 14 m` 地块内。
- T0239 后 `FormalDormitoryArtView` 从已经生成的床 fixture 只读筛选非空 `assigned_npc_id`，按 `workstation_id` 排序并为床位 1–8 生成八座程序化双门个人衣柜；床位 9–10 不生成空归属柜。柜体只镜像 `assigned_npc_id / workstation_id / fixture_id` 元数据，标记为非工位、非库存陈设且不创建碰撞、导航或点击权威。
- 等级同步在 Lv.1 / Lv.2 都保持 10 件床 fixture 与 10 件碰撞；1–8 号床的 `assigned_npc_id`、9–10 号空归属、床边 Marker、床面锚点与睡眠路径不变。床边 Marker 新增同名只读元数据，只用于表现快照 / 测试，不参与分配。
- 二级 `RoofStructureAdditions` 和 `ExteriorAdditions` 分别进入附加屋顶 / 外墙透明路径；主屋顶、墙体、烟道、修补梁与窗板统一使用 `70→58 m / 0.06`。自动门沿局部 `+Z` 对齐，净口 `2.08 × 2.35 m`。
- GM `dormitory_art_level <1|2>` 只调用表现根 `debug_force_visual_level`；BuildingSystem、ActionSystem、NPCSystem 与 NPCNeedsSystem 继续拥有等级、床位、到达、睡眠和恢复权威。

## T0130-D1 NPC 开发检视场景节点

- T0130-D1R6 已撤销 D1R3 的临时入口，`project.godot:application/run/main_scene` 重新指向 `res://scenes/main/Main.tscn`；Godot 的运行项目按钮进入正式游戏。`NPCDevLab.tscn` 保持独立开发场景，工具内返回按钮与 F8 仍显式加载正式 Main。
- `NPCDevLab.tscn` 是独立 `Node3D`：固定地面、展示台、灯光、相机和 `CanvasLayer`；`NPCDevLab.gd` 在运行时建立角色选择、模式、动作与装备 UI，一次只在 `CharacterMount` 下实例化一个生产外观包装。敌种列表从 `enemy_waves.json` 去重，友方外观从 `npc_profiles.json + character_appearances.json` 解析。
- T0130-D1R8 后，`NPCDevLab.gd` 只持有一个场景级 `_shared_loadout` 和当前 `_mode`，不再按 unit id 保存临时装配；角色切换只替换可见包装并把动作重置为待机，六槽装卸与有效模式继续沿用。敌军选择把有效模式强制为 `combat`。`_equip_slot(...)` 对任意槽装配后切到战斗；`_trigger_action(...)` 根据配置 `modes` 在单模式动作上自动切换，双模式动作保持现状，`requires_mount` 等前置条件仍在切换前校验。
- `data/presentation/npc_dev_lab.json` 只保存动作目录、职业动作能力和敌军预览包装；装备选择读取正式 `weapon_defs.json / armor_defs.json / horse_defs.json`，选择结果只保存在场景级 `_shared_loadout`。`EquipmentSilhouette.gd` 只绘制 UI 轮廓，不持有槽位、库存或人体部位权威。
- `ChibiCharacterPilot.debug_set_equipment_preview(...)` 是显式 debug-only 的逐实例可见性覆盖：按临时主武器控制剑盾节点，必要时惰性建立同包装剑盾表现；不修改 `apply_profile`、正式装备映射或共享资源。友方临时马匹由场景实例化现有 GLB 并驱动正式骑乘动作，不创建 HorseSystem 所有权；敌方骑兵另复用正式包装。
- T0130-D1R 在 `Stage` 下增加无监测、仅供输入拾取的 `RotationDragArea/CollisionShape3D`。其胶囊覆盖步行与骑乘角色高度；按下后由场景根 `_input` 消费水平 MouseMotion，统一写入 `CharacterMount / HorseMount.rotation_degrees.y`，释放或 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 清理拖动态。全屏 Overlay 使用 `MOUSE_FILTER_IGNORE` 透传空白，实际子面板仍保持默认截获。
- T0130-D1R7 不在开发场景复制剑盾挂点数值；`ChibiCharacterPilot._ensure_sword_shield_nodes()` 同时服务临时预览与正式包装。剑使用 `RightHand + (-0.065632, -0.007022, 0.038889) / (0, 0, 90°)`，盾使用 `LeftHand + (0.047388, -0.015351, 0.096296) / (5.079137°, 52.49611°, 98.10695°)`，二者统一缩放 `0.72`；盾位置基于本地背面中心 `(0, -0.066718, -0.072478)` 与额外 `0.045 m` 正向净空校准。快照报告局部 Transform、握柄 / 剑尖到手距离、盾背到手距离、有符号净空、盾面—可见正面点积和朝上轴，供几何回归。
- T0130-D1R4 在 `Stage` 下新增默认隐藏的 `SeatPreview`，仅由五个无碰撞 BoxMesh 组成。非乘骑坐姿时，场景读取当前包装的 `seated_pose_offset_y` 并把其绝对值加到 `CharacterMount` 基础高度，抵消正式空间坐席锚点才需要的下沉量；凳子留在平台固定高度并单独同步预览 yaw。普通动作、战斗或坐骑显示时恢复基础 / 骑乘高度并隐藏凳子，不改 `ChibiCharacterPilot` 的正式偏移和状态映射。
- T0130-D1R9 移除 `PreviewHorse` 曾叠加的 `180°` 局部 yaw；导入马的可见正面使用本地 `+Z`，与稳定后人物包装的可见正面同向。`debug_get_snapshot()` 报告双方世界前向、点积和马模型局部 yaw，专项在初始骑乘与拖转后均校验点积大于 `0.99`；`HorseMount` 与 `CharacterMount` 的公共 yaw 同步路径不变。
- T0139-D1 对敌方 `cavalry / mounted_ranged` 绕过上述友方临时 `HorseMount`：`_spawn_character(...)` 直接创建与 Main 同一 `EnemyMountedArtView`，骑兵骑手使用剑盾、骑射兵保持 `equipment_mode=none`。其固有马不写 `_shared_loadout`，坐骑槽只显示不可卸下的说明。
- `mounted_shared_defeat` 动作先通过正式 `apply_profile(hp=0, unconscious=true)` 触发骑手 `mounted_fall / Death_A`，再调用包装的 `begin_mounted_shared_defeat(...)`；马匹同时播放 `Death`，人马原地保留并由同一清理信号释放。下一次动作按需重建同一包装，因此可重复验收而不创建第二套阵亡状态机。

## T0130-P8R2 欧文护目镜双姿态

- `ChibiCharacterPilot` 为 `engineering_kit` 保存 Head 骨空间下的 `forehead / worn` 两套 Transform。额头姿态沿用原位置；佩戴姿态以独立模型空间眼位、轻微放大铜框和半透明深青镜片覆盖双眼，并用 `0.16 s` Tween 切换。
- 状态选择仍只读现有表现投影：`state=work && current_action=work_workshop` 才进入 `worn`；维修 / 升级即使也使用 `Working_A` 和扳手，护目镜仍为 `forehead`。调试沙盒的强制 work 只用于制造视觉验收，不写入 NPC 权威状态。
- 快照新增 `engineer_goggles_mode / target_model_position`，正式制造、维修和升级专项分别锁定正确姿态。护目镜仍只有 MeshInstance3D，不增加碰撞或交互面。

## T0130-P8R 工械坊贴桌终段导航

- 工械坊三个 `npc_stand` 均在家具配置中声明 `target_desired_distance=0.08`。`StationLayoutController.get_building_spatial_route(...)` 只投影该可选字段；`NPCSystem` 只把它传给对应室内路线终段。
- `NPC.move_to_location(...)` 新增向后兼容的可选 `motion_options`，仅本次请求向 `ActorMotionBody.configure_profile(...)` 写入 NavigationAgent 到达精度。后续普通移动会以原默认配置重新调用，因此不会把贴桌精度泄漏到战斗、逃离或其他建筑路线。
- 工程台站位根距桌沿 `0.6 m`，NPC 胶囊半径 `0.35 m`，保留 `0.25 m` 净空；不使用关闭碰撞或到达后传送来伪造贴桌表现。

## T0130-P8 欧文工程师角色节点

- `OwenChibiArtView.tscn` 复用 `ChibiCharacterPilot.gd`，选择 `SK_Pirates_Firstmate_01` 的短壮工头轮廓、作者 `_01_A` Albedo / 顶点色脸、`engineering_kit` 与循环 `Working_A`。铜框护目镜挂 Head，双工具袋 / 折尺 / 木楔挂 Body，活动扳手挂 RightHand；所有附件均为无碰撞 PrimitiveMesh。
- `current_action=work_workshop / assist_repair_<building> / assist_upgrade_<building>` 只有在既有正式空间事务实际提交后才解析为 `work` 并显示扳手；在途由父级 CharacterBody / NavigationAgent 驱动 walk。`engineering_kit` 同时实例化默认隐藏的剑盾表现，只有 EquipmentSystem 权威 `main_weapon=sword_shield` 时显示，睡眠或卸装后隐藏。
- `ChibiCharacterSandbox.tscn` 现有九个基座：8 名初始 NPC 与剑盾敌人；欧文支持单人近景抓图。生产场景仍挂原 `NPC.tscn/ArtMount`，不新增 CharacterBody、NavigationAgent、SelectionArea、工位或结算节点。

## T0134-P1 NPC 实时人物镜头节点

- `NPCPanel.gd` 在运行时创建左上 `NPCPortraitView`，由 `NPCPortraitViewport.gd` 构建 `SubViewportContainer/PortraitSubViewport/PortraitCamera`；P1R 使用顶边锚定、信息列约 52% 高度与 190–210 px 响应宽度，P1R2 移除标题 / 地点 Label 与外部 VBox，让画面直接填充边框内侧。原 `PanelContainer` 信息列保持既有节点路径和交互合同。
- `PortraitSubViewport.own_world_3d=false` 并显式复用 Main viewport 的 `world_3d`。副镜头只拍摄已有 NPC 和真实场景，不实例化角色；关闭、切换建筑或目标无效时将更新模式切为 `UPDATE_DISABLED`。
- NPCSystem 仅提供 `get_npc_portrait_snapshot(npc_id)` 窄只读快照，包含实体坐标、表现层真实正面、姿态构图高度和中文地点。`NPC.gd` 只汇总现有状态；`ChibiCharacterPilot` 与 `NPCArtView` 只暴露实际可见 forward，不改变角色根旋转。
- 副镜头排除视觉层 20；NPC 的 Label3D 后代被放在该层，主镜头仍可见但不会挡住人物特写。P1R3 再让主镜头 / 人物框分别消费建筑渐隐壳层 19 / 不透明壳层 18；`BuildingArtView` 的 internal `PortraitOpaqueShell` 继承源 Mesh 的 Transform 与可见性，但不进入作者模型计数、不投影、不承担碰撞或玩法。P1R 的默认构图为 3.9 m / 40°，遮挡射线仍只检查 `world_static` 层并在必要时缩短距离，不参与导航、碰撞或点击。

## T0130-P7/P7R/P7R2/P7R3 莉娜角色与诊所巡床节点

- `LinaChibiArtView.tscn` 复用 `ChibiCharacterPilot.gd`，选择 `SK_Pirates_GovDaughter_01`、保留作者顶点色的 `Blue_A` Albedo、`medical_kit`、`Working_B` 诊所研读与 `Working_A` 治疗。场景挂在原 `NPC.tscn/ArtMount` 下，不含 CharacterBody、NavigationAgent、SelectionArea 或治疗权威。
- 共享包装在既有 Body / LeftHand / RightHand 骨挂点下创建 MedicalSatchel / MedicalBook / BandageRoll；药包按 Chest global rest 反算到模型空间腰侧，三者均只有 PrimitiveMesh。诊断快照暴露父节点、显隐与治疗循环模式。
- P7 新增 `medical_treatment`，P7R 再新增 `seated_study`，共享状态合同现为 18 个。`current_action=assist_heal_<target>` 仅在 ActionSystem 实际提交后投影为治疗；正式诊所值班按 `presentation_clinic_duty_mode` 区分坐桌研读、在途和床边治疗。`ChibiCharacterSandbox.tscn` 在 P8 后并排显示 8 名初始 NPC 和剑盾敌人，并支持莉娜与欧文单人抓图。
- `NPCSystem.move_formal_clinic_doctor_to_patient_bed(...) / move_formal_clinic_doctor_to_study_seat(...)` 复用同一生产 NavigationMap 与既有医生 CharacterBody。床边目标来自患者当前正式病床 session，回桌目标来自医生自己的诊疗位；跨室内移动保留现有 `location_context`，到椅后才重新挂接 `seated_study`。
- P7R2 保留 `interior_target_position` 作为启用 Body 碰撞的安全寻路终点，并由 `occupant_anchor_position` 朝该终点的方向派生床外 `0.4 m`、沿床切线 `0.65 m` 的贴床锚点；切线方向随床侧镜像以校准 `Working_A` 右手落点。到达回调才调用 NPC 的空间挂接接口；换床时解除挂接、恢复 Body 碰撞并回到旧床安全点后再导航，避免从家具碰撞体内部求路。InteractionArea 不关闭，因此贴床治疗中的医生仍可点击。
- P7R3 让 `get_building_spatial_route(...)` 额外返回目标家具 `collision_size` 及全局 right / forward 轴。NPCSystem 将床体沿站位方向的投影半宽、NPC `0.35 m` 半径和 `0.08 m` 净空相加生成床侧锚点，沿床偏移收至 `0.35 m`。`NPC.attach_to_spatial_anchor(...)` 新增默认向后兼容的 `disable_body_collision` 参数；床面 / 座椅仍按旧合同关闭 Body，只有 `standing_treatment` 传 `false` 保留实体碰撞。
- 可见验收复用既有 FormalClinicDoctor / Patient 与 FormalHealAssist GM 入口，没有增加第二套治疗按钮或结算路径。

## T0130-P6 马塞尔角色节点

- `MarcelChibiArtView.tscn` 复用 `ChibiCharacterPilot.gd`，选择 `SK_Fantasy_Wizard_01` 的年长长袍基础、`PolygonMinis_Texture_Purple_A.png`、作者导入材质、`Working_A` 与专属 `Ranged_Magic_Spellcasting_Long`。场景开启分离头饰过滤、Body 木质圣徽和 P6R 的 Head 灰白低模圆冠，但不含 CharacterBody、NavigationAgent、SelectionArea 或职业工具。
- 共享包装在目标骨架进入实时重定向后重建 ArrayMesh 索引，仅移除审计到的尖帽拓扑岛；Body socket 下的 WoodenCross 随 Chest 骨动作。P6R2 为其增加 `(-4.946784°, 0.614417°, -90.05296°)` 局部旋转，抵消 Body 待机骨姿约 `90°` 滚转，并在快照报告局部 Transform、长轴—世界 Up 与正面—角色可见正面点积。P6R 以 Head global rest 反算模型空间圆冠的局部 Transform，让单个无碰撞 SphereMesh 跟随 Head；这些诊断与附件均不产生玩法接口。
- `ChibiCharacterSandbox.tscn` 现以七个基座并排显示格伦、托马、布鲁诺、伊沃、马塞尔、艾达和剑盾敌人；工作组显示马塞尔酿酒，生活组显示其主持弥撒，P6R 新增马塞尔头型正面 / 侧面抓图参数。真实验收继续复用既有 `FormalTavernWorkButton / FormalChapelLeaderButton / FormalChapelPrayerButton`，没有新增 GM 权威入口。

## T0130-P5 艾达角色与卧姿节点

- `AdaChibiArtView.tscn` 复用共享包装，选择 `SK_Vikings_ShieldMaiden_01`、保留作者材质设置的 `Blue_A` Albedo 与 `synced_sword_shield`。剑 / 盾仍挂 RightHand / LeftHand，但显隐读取 profile 的正式主武器 ID；场景本身不含碰撞或装备权威。
- P5R2 在共享包装增加默认关闭的 `use_imported_character_material`：开启时逐 Mesh 复制导入 BaseMaterial3D，保留 `vertex_color_use_as_albedo`、透明度和作者表面设置，只替换 Albedo 并应用既有明度系数。艾达开启该模式以恢复原生眼眉；P5R 的程序化 Head 面部节点与相关导出字段已经删除。
- P5 时共享状态合同增至 16 个并新增 `sleeping -> Lie_Idle`；P7 加入医疗处置，P7R 再加入坐姿研读，现为 18 个。`NPC.gd` 会把所有空间姿态转发给支持 `set_spatial_attachment_pose` 的 Chibi 包装；仅 `lying_supine / sleeping_supine` 对旧包装执行 ArtMount 卧倒回退，避免坐姿被误旋转或卧姿双重旋转。
- 动作沙盒在 P7 后并排显示格伦、托马、布鲁诺、伊沃、马塞尔、艾达、莉娜和剑盾敌人。训练与睡眠继续复用已有 GM 正式行动入口，没有新增第二套玩法按钮。

## T0130-P4/P4R 伊沃角色节点

- `IvoChibiArtView.tscn` 复用 `ChibiCharacterPilot.gd`，选择独立 `SK_Pirates_Deckhand_01` 劳动者轮廓、保留作者顶点色的 `_01_A` 土色 Albedo、循环 `Digging` 与 `garden_hoe`。P4R2 开启既有 `use_imported_character_material` 以恢复原生眼睛；木柄铁锄仍由包装内低多边形 PrimitiveMesh 组成，P4R 按完整动作周期重校 RightHand 局部轴，快照暴露锄刃前向距离和左手到柄身距离供回归。
- 包装挂在原 `NPC.tscn/ArtMount` 下且不带碰撞。真实田畦到岗才显示园锄；真实长凳挂接选择 `seated_prayer`，使用伊沃专属 `-0.56 m` 可见坐姿偏移并隐藏园锄。
- `ChibiCharacterSandbox.tscn` 现并排显示格伦、托马、布鲁诺、伊沃、艾达和剑盾敌人；截图参数支持指定动作相位和伊沃正面面部近景，便于检查原生眼睛与长柄工具完整周期。`formal_garden_work / formal_chapel_work` 快照继续提供伊沃只读 `character_art`，没有新增玩法权威入口。

## T0130-P3 布鲁诺角色节点

- `BrunoChibiArtView.tscn` 复用 `ChibiCharacterPilot.gd`，选择独立 `SK_Adventure_ShopKeeper_01`、暖红调色板、`Working_C` 与 `cook_spoon`。木柄铜勺由包装内低多边形 PrimitiveMesh 组成，不是 Synty 源资产派生网格。
- 包装挂在原 `NPC.tscn/ArtMount` 下且不带碰撞。NPC.gd 继续传入真实移动方向与 profile；实际灶台到岗才显示勺子，真实座位挂接选择 `seated_eating` 并隐藏勺子。
- `ChibiCharacterSandbox.tscn` 在 P4 后已扩为五角色；P3 的 `formal_dining_work snapshot` 继续提供只读 `character_art`，没有增加玩法权威入口。

## T0130-P2 托马角色节点

- `TomaChibiArtView.tscn` 与格伦 / 剑盾包装共享 `ChibiCharacterPilot.gd`，但选择独立 `SK_Adventure_Peasant_01`、土色调色板、`Working_B` 和 `stable_broom`；场景不含碰撞，挂在原 `NPC.tscn/ArtMount` 下。
- 共享适配器新增可配置 `work_clip`，并把 `Working_A/B/C` 放入共享 AnimationLibrary 的循环白名单；这不复制每实例动画库。马厩扫帚由 RightHand BoneAttachment 承载，只在 `current_action=work_stable` 且非移动 / 昏迷的工作表现中可见。
- `ChibiCharacterSandbox.tscn` 现在并排显示格伦、托马和剑盾敌人；沙盒会显式让三人面向相机，只影响预览。正式托马仍由 NPC.gd 把实际路径 / 工位方向传入表现层。

## T0130-P1 正式两头身角色节点

- `GlenChibiArtView.tscn` 由 `NPC.gd` 挂到 `blacksmith_01/ArtMount`，不含自身碰撞；父级 `NPC.tscn` 的 BodyCollision、InteractionArea、NavigationAgent 和标签节点原样保留。
- `EnemySwordShieldChibiArtView.tscn` 由 CombatSystem 挂到符合剑盾步兵合同的 `ActorMotionBody/EnemyArtView`；父级 ActorMesh 隐藏，但 BodyCollision、InteractionCollision、NavigationAgent 和 EnemyLabel 保留。
- 两种包装复用 `ChibiCharacterPilot.gd`，内部为隐藏 KayKit SourceRig、RetargetModifier3D、Synty TargetSkeleton、六个标准人形挂点、AnimationPlayer、血粒子和禁用的 PhysicalBoneSimulator 占位。
- Synty TargetSkeleton 的网格正面是本地 `+Z`；`ChibiCharacterPilot` 在 `VisualRoot` 层固定增加 `PI` 源朝向修正，而 `_target_yaw` 继续由项目 `-Z` 世界方向计算。诊断快照以修正后的可见 `+Z` 轴报告 `visual_forward`，避免用错误轴让自动化掩盖倒走。
- NPCSystem 新增只读 `debug_get_npc_character_art_snapshot(...)`，CombatSystem 新增只读 `debug_get_enemy_art_snapshots()`；两者仅服务 GM / 自动验收，不参与权威结算。
- T0130-P1R2 后，格伦的 hammer 在非 `work_blacksmith` 状态挂到 `Mount/Hips`，以共享校准 Transform 在右侧腰间水平收纳并让模型正 Y 的锤头端朝人物正面；进入真实打铁状态仍重挂 `RightHand`。该切换只属于 `ChibiCharacterPilot` 表现层。
- T0130-P1R4 废止 P1R3 靠近锤头颈部的伪握点。导入网格的细柄约为局部 `Y=-0.478539..0.306658`、锤头从 `Y≈0.568391` 起；工作锤现以柄后段 `(0,-0.4,0)` 对齐 RightHand，局部位置 `(-0.152,0,0)`，并在快照中分别报告握点误差、手后柄尾距离与锤头最小分离。非工作 Mount/Hips Transform 与所有行动 / 生产权威保持不变。

## T0129C-A5-P8 空间检查点节点

- `Main/Systems/SpatialSaveSystem`（`scripts/systems/SpatialSaveSystem.gd`）挂在 CombatSystem 后，提供 `save_formal_spatial_checkpoint / load_formal_spatial_checkpoint` 与 GM 调试包装。
- 默认磁盘位置为 `user://formal_spatial_checkpoint.json`。读取新 Main 时只使用稳定 ID、JSON 坐标和配置索引；生产 NavigationMap、角色 Body、敌人实体与行商马车全部重新创建，不跨场景保存 RID 或 NodePath。

## T0129C-A5-P7 默认正式世界节点生命周期

- `StationLayoutController` 读取 `station_layout_v2.migration.formal_layout_active=true` 后默认启用 `FormalStationLayout`、三块 NavigationRegion、12 个门 Link、后路 Link 与正式相机范围；旧 `WorldRoot/Station` 仅保留开发兼容，不再是新局默认空间权威。
- `NPCSystem.begin_default_formal_world()` 将 8 个既有 `NPC.tscn` CharacterBody 分别放到正式初始锚点并绑定生产 NavigationMap，不复制节点。NavServer 首帧最近点若与锚点水平误差超过 `2 m`，使用已审计锚点，避免 stale map 返回世界原点。
- 默认居民开始工位 / 地点 / 对话 / 协助行动时从当前 Body 坐标出发；结束只释放事务、工位和挂接，保留最后正式位置与生产导航。CombatSystem 只临时标记战斗权属，进入和退出均不传送默认居民。
- MerchantSystem 在默认正式世界选择 `formal_rear_trade_default` 6 点路线；CombatSystem 对默认正式居民与战斗居民统一选择 6 点地图边缘逃离路。`station_layout legacy` 经 `debug_set_legacy_compatibility_enabled(true)` 暂停上述权属并同步恢复 2 点商路，`station_layout preview` 恢复正式世界。
- A5-P8 已保存该运行时空间状态；进行中事务采用安全回滚，NavMap 同步后恢复 NPC 最后坐标，未直接序列化 RID 或 NodePath。

## T0129C-A5-P6d-3 正式昏迷目标接近节点

- `NPCSystem.begin_formal_healing_approach(...)` 先复用正式地点会话，再围绕目标 CharacterBody 选择可达接近位；兼容世界目标会被可逆投影到目标建筑室内锚点，已有 formal Body 不重复迁移。
- 同目标最多两个会话，接近位水平间距至少 `0.85 m`；到位判定要求同一信息地点、`physical_location_phase=formal_healing_approach`、目标仍昏迷且水平距离约 `0.8–1.70 m`。
- `ActionSystem` 只有在正式会话、目标 ID、实体距离和目标状态全部匹配后才扣首枚第纳尔并加入 helper。GM 入口只调用派发 / 中断 / 快照；A5-P7 默认总世界复用该会话，不改变治疗事务。

## T0129C-A5-P6d-2 建筑外沿施工节点

- `StationLayoutController.get_building_exterior_service_slots(building_id, "upgrade")` 复用最大等级 envelope 外候选，但生成独立 `<building>_upgrade_<n>` ID，避免与维修会话抢占语义混淆。

## T0131-P1 正式工械坊建筑切片

- `StationLayoutController` 在生成 Workshop 的 `StaticCollision / FixtureLayout` 后实例化 `FormalWorkshopArtView.gd`，隐藏旧半透明 Envelope。新表现根继承 `BuildingArtView`，只监听 BuildingSystem `building_state_changed`，不拥有等级、HP、制造、工位或地点权威。
- `FormalWorkshopArtView` 在 `12 × 12 m` 包络内生成 Quaternius 墙 / 圆门 / 深木地板 / 圆瓦屋顶以及纯表现的工程杂物；`static_collision_path=../StaticCollision`、`workstation_markers_path=../FixtureLayout/NPCStands`，路线和导航继续由 StationLayoutController 生产 NavigationMap 统一提供。
- T0131-P1R 为 `BuildingArtView` 增加 `additional_roof_fade_paths`：额外节点与 `roof_path` 一起克隆 scene-local 屋顶材质、接受同一 alpha 和阴影开关。工械坊把 Lv.2 传动梁 / 导轨与 Lv.3 主装配桁架登记到该数组；升级室内道具和吊钩仍保持可见。三级外部装配湾继续走 `additional_exterior_fade_paths`，并由专项用导入模型实际 AABB 同时校验 `14 × 14 m` 地块边界与主 / 附属屋面垂直净空。
- T0131-P1D 新增纯表现 `BuildingAutoDoor.gd`。组件在建筑局部 `+Z` 入口生成双侧铰链、双扇门与 `Area3D` 接近传感器；传感器只监测碰撞层 2 的 `CharacterBody3D`，门叶只动画旋转且没有 PhysicsBody / 阻挡 CollisionShape。铁匠铺和工械坊把组件挂在 `Exterior/AutoDoor`，因此门材质随外墙透明；它不调用 NPCSystem / BuildingSystem / ActionSystem，也不提交地点、工位或导航结果。
- 等级投影同时控制 `UpgradeVisuals/Level2 / Level3`、FixtureLayout 的直接子视觉和对应 StaticBody：`required_level` 高于当前等级时视觉隐藏、CollisionShape 禁用且 collision layer 清零。NavMesh 仍按最高等级家具预留区烘焙，因而低等级不会穿越未来扩建位；这是一种保守导航预留，不是隐藏碰撞。
- 工械坊和铁匠铺同用 `70→58 m` 的近景外壳透明范围；`fade_exterior_with_roof=true` 使 Roof、Exterior 与两级外部扩建附件使用实例本地 alpha。BuildingSystem 的通用 BuildingArtView 拾取先尝试透明建筑内 NPC，再回退建筑空白点击。
- GM `workshop_art_level <1|2|3>` 只调用表现根 `debug_force_visual_level`，真实等级与容量仍由 `upgrade_building workshop` 和 BuildingSystem 结算。
- NPCSystem 的 formal exterior route 根据 `service_kind` 显示“施工点”或“维修点”，抵达后统一提交 `physical_location_phase=building_exterior_service`，并以 `formal_exterior_service_kind=upgrade` 区分事务。
- ActionSystem 只有在 formal session、建筑 ID、施工服务类型和实体到达全部匹配时才调用 `add_upgrade_helper`。升级期建筑内部继续不可进入；A5-P7 总切换不改变这一前置条件。

## T0131-P1B 铁匠铺屋面与升级附属结构返修

- `FormalBlacksmithArtView` 保持原 `14 × 12 m` 主体和 `16 × 16 m` 地块权威不变，只重组 `UpgradeVisuals` 表现节点。Lv.2 `FuelShelter` 与 Lv.3 `FinishingBay` 各自组合石台、斜棚、木柱 / 斜撑和职业储物；运行态 Mesh AABB 同时限制 `X/Z` 地块边界和相对主屋面的垂直净空。
- Lv.3 `CeilingHoistBeam` 从 `InteriorAdditions` 移到 `RoofStructureAdditions`，并作为唯一铁匠铺 `additional_roof_fade_paths`。`BuildingArtView` 对该分支复制 scene-local 材质并与主屋顶统一写 alpha / shadow；`HoistChain / HoistHook` 仍在室内分支，不随外壳消失。
- `ChimneyAssembly` 不加入附属棚净空约束：砖石烟囱、烟罩、垂直烟道和 `SmokeOutlet` 是从炉膛穿屋面到屋脊上方的连续功能结构。专项分别验证有意排烟穿越与其他升级件零穿模，不通过移动烟粒子或隐藏烟囱伪造结果。
- 返修只改 presentation-only 层；`FixtureLayout` 的 `2 -> 2 -> 3` 锻造位、BuildingSystem 等级 / HP、CraftingSystem 阶段、生产 NavigationMap、StaticCollision 与 NPC 点击权威未改。

## T0129C-A5-P6d-1 建筑外沿维修节点

- `StationLayoutController.get_building_exterior_service_slots(...)` 为 12 座建筑按最大等级 envelope 四边生成维修候选；围墙取长墙段内侧，前后门取门洞两侧。候选经生产 NavigationMap 吸附，并保留同帧 NavServer 尚未同步时的审计坐标。
- `NPCSystem.begin_formal_building_exterior_action(...)` 为同目标会话选择最近未占槽；室内 NPC 先走既有 exit route，再通过 `ActorMotionBody` / NavigationAgent3D 到槽位。抵达状态为 `physical_location_phase=building_exterior_service`，逻辑信息地点仍是 `plaza`。
- `ActionSystem` 只在抵达状态、建筑 ID、服务类型和 formal session 全部匹配后提交 helper。GM 入口与专项不传送角色、不写修复进度；A5-P7 后从居民当前正式位置出发。

## T0129C-A5-P6c 正式 NPC-NPC 接近节点

- `data/action_defs.json` 为 `talk_to_npc` 启用 `formal_spatial_route=true` 和 `approach_distance=1.35`。ActionSystem 先走正式地点路由，再调用 NPCSystem 围绕目标 CharacterBody 采样合法站位；路径为空但双方点属于同一 NavigationRegion 时使用同区域候选，最终可达性仍由 NavigationAgent3D 负责。
- 静止兼容目标会临时投影到建筑室内锚点或广场正式公共锚点；已有 formal workstation session 的目标直接使用当前 Body，不复制角色。邀请接受时 `prepare_formal_dialogue_activation(...)` 先转移目标空间权属，再允许普通工作中断释放工位。
- `dialogue_ended` 通过已绑定 `dialogue_id` 结束双方空间会话。A5-P7 后双方回到默认正式居民状态；这不改变 DialogPanel、Prompt 或后端协议。

## T0129C-A5-P6b 无工位正式地点拜访

- `data/action_defs.json` 以 `formal_spatial_route=true` 选择正式执行分支；ActionSystem 仍独占 pending / active / 时长 / 事件生命周期，NPCSystem 独占 CharacterBody、NavigationAgent3D、门路与地点提交。
- 建筑目标复用 `StationLayoutController.get_building_spatial_route(...)`；`plaza` 由 `get_public_location_world_position(...)` 提供正式公共锚点。室内到另一建筑必须先消费来源建筑 exit route，再消费目标 entry route。
- 地点拜访会话复用 formal session，但不预留 / 提交任何 workstation。结束时 Body 保留在最后已提交的正式地点，不生成补偿性地点事件。

## T0129C-A5-P6a 宿舍正式睡眠节点

- `sleep_in_dormitory.formal_spatial_route=true` 后复用通用正式工位会话：ActionSystem 发起并在到达后提交，BuildingSystem 独占固定床 reservation / occupancy，NPCSystem 独占 CharacterBody 门路、地点提交与床面挂接。
- occupancy 成功后调用 `attach_formal_workstation_occupant(...)`，StationLayoutController 返回 `sleeping_supine` 锚点；NPC.gd 关闭 Body 碰撞、保留 InteractionArea，并以既有躺卧 Transform 表现睡眠。解除挂接在物理帧恢复碰撞。
- NPCNeedsSystem 与 DailyReflectionSystem 只读取 active 权威状态；空间姿态、动画或 GM 快照不能开始睡眠。完成与异常退出通过 ActionSystem 的统一释放和正式会话清理回到旧世界。

## T0129C-A5-P5i 小教堂正式礼拜节点

- `lead_mass / pray_at_chapel` 复用通用正式工位会话。ActionSystem 先预留祭坛或祈祷席，NPCSystem 独占 CharacterBody 门路与地点提交，BuildingSystem 在实体到站后把对应 reservation 提交为 occupancy；只有提交成功才建立 active 行动。
- 祈祷席 occupancy 成功后，NPCSystem 把角色挂到 StationLayoutController 的 `occupant_anchor`；主持者保持站立实体。结束或失败统一解除挂接、释放工位和正式会话，不能由表现姿态反推礼拜事实。
- `mass_leader / seated_prayer` 是 NPCArtView 只读状态。UAL2 Standard 没有原生坐姿礼拜片段，当前以 `Idle_Rail_Call / Idle_Rail` 加局部坐姿偏移构成低配表现；PietySystem 与祈祷事件不读取动画。

## T0129C-A5-P5h 训练场正式双实体节点

- `work_training_instructor / receive_weapon_training` 复用通用正式工位会话；ActionSystem 在迁入前校验主武器 / 坐骑，BuildingSystem 独占教官位 / 训练位的预留与占用，NPCSystem 独占 CharacterBody 门路和到站提交。
- 学员可以在教官 pending 时先预留并到位等待；两者未 active 前 ActionSystem 不推进技能。active 后继续使用既有共享教官团队、装备项目和建筑效率公式；最后教官退出时统一失败 active / pending 学员、释放工位并保留正式位置。
- `AdaArtView.tscn` 与 NPCArtView 的 `training_instructor / training_practice` 循环状态只投影权威行动；循环挥剑不调用 CombatSystem，不生成命中、伤害或战斗事件。

## T0129C-A5-P5g 诊所正式服务节点

- ActionSystem 为两种诊所行动建立正式工位会话；医生到桌后提交占用并 active，患者到床边后先提交病床占用，再调用 NPCSystem 的 `attach_formal_workstation_occupant(...)` 挂到 StationLayoutController 提供的床面锚点。提交失败会释放自身 reservation / occupancy 和会话。
- `NPC.gd` 挂床期间保持 InteractionArea 可点、临时禁用实体 Body 碰撞并应用 `lying_supine`；结束、失败或最后医生离岗时解除挂接、恢复碰撞和旧世界坐标。医生站立保留 CharacterBody / NavigationAgent 合同。
- `LinaArtView.tscn` 继承 UAL2 通用角色装配并覆盖青灰配色、无锤设置；GM 两个实际按钮和 A5-P5g 专项覆盖双 pending、双占用、挂床、循环动画、治疗扣费及中断清理。

## T0129C-A5-P5f 酒窖正式工作节点

- `work_tavern` 通过通用 `formal_spatial_route` 接入 ActionSystem / NPCSystem 可逆会话；ActionSystem 在会话前预检粮食，StationLayoutController 只读提供酒窖门路与 `cellar_01–03` 桶外安全站位，BuildingSystem 独占 `brew` 预留 / 占用和等级容量，ResourceSystem 只在完整周期原子结算粮食与酒。
- `MarcelArtView.tscn` 继承 UAL2 通用角色装配并覆盖暗梅灰神职配色、无锤设置；NPCArtView 把 `work_tavern` 归一为既有循环 work 状态，不改变 CharacterBody3D、NavigationAgent3D、碰撞或玩法权威。
- GM `FormalTavernWorkButton` 发送真实 ActionSystem 派工。专项从实际 `pressed` 信号覆盖缺粮预检、pending 零扣料 / 零产出、到位占用、循环表现、缩放产酒且金钱不变、同 session 原位续作与中断清理。

## T0129C-A5-P5e 菜园正式工作节点

- `work_garden` 通过通用 `formal_spatial_route` 接入 ActionSystem / NPCSystem 可逆会话；StationLayoutController 只读提供菜园门路和田畦开放工作面，BuildingSystem 独占 `farm` 预留、占用与等级容量，ResourceSystem 只接收完整周期的缩放粮食产出。
- 当前 `IvoChibiArtView.tscn` 使用 Deckhand 园丁包装、`Digging` 与到岗后园锄；旧 `IvoArtView.tscn` 仅作历史回退。二者均不改变 CharacterBody3D、NavigationAgent3D、碰撞或玩法权威。
- GM `FormalGardenWorkButton` 发送真实 ActionSystem 派工。专项从实际 `pressed` 信号覆盖 pending 零产出、到位占用、循环表现、精确缩放产粮、同 session 原位续作与中断清理。

## T0129C-A5-P5d 食堂正式工作节点

- `work_dining_hall` 通过通用 `formal_spatial_route` 接入 ActionSystem / NPCSystem 可逆会话；ActionSystem 在会话前预检 `input_resources`，BuildingSystem 独占灶台预留 / 占用与等级容量，ResourceSystem 只在完整周期结算 `grain -1 / meal +2`。
- StationLayoutController 继续只读返回食堂门路和 `dining_kitchen_station_01–03` 家具安全站位；Lv.1 只开放前两口灶台，Lv.3 才新增第三权威工位。角色仍以 CharacterBody3D / NavigationAgent3D / move_and_slide 到达，不用瞬移或后台地点代替。
- 当前 `BrunoChibiArtView.tscn` 使用 ShopKeeper 厨师包装、`Working_C` 和到岗后厨具；旧 `BrunoArtView.tscn` 仅作历史回退。GM `FormalDiningWorkButton` 仍发送真实 ActionSystem 派工，专项继续覆盖缺粮预检、pending 零扣料、到位占用、循环表现、精确产出、原位续作与中断清理。

## T0129C-A5-P5c 工械坊正式工作节点

- `work_workshop` 通过已有 `formal_spatial_route` 数据开关进入 ActionSystem / NPCSystem 通用正式工位会话，不新增第二套制造控制器。StationLayoutController 继续只读提供工械坊门路和 `workbench_01–03` 世界 Marker，BuildingSystem / CraftingSystem 分别独占占用和阶段结算。
- `OwenArtView.tscn` 是 A5-P5c 的 Quaternius / UAL2 历史回退；T0130-P8 后 `character_appearances.json` 已把 `engineer_01` 切到 `OwenChibiArtView.tscn`。两者均不拥有 NPC 根、碰撞、导航或工程结算。
- GM `FormalWorkshopWorkButton` 发真实 ActionSystem 派工信号，成功后只隐藏 GM 窗口。专项从实际 `pressed` 信号验证新局自动目标、正式迁移、占用、循环表现、单阶段提交、原位续作和切目标清理。

## T0129C-A5-P5b 正式锻造会话与导航重启

- ActionSystem 对 `formal_spatial_route` 工作先做业务预检，再调用 NPCSystem 创建带唯一 `session_id` 的可逆正式会话。NPCSystem 管理实体 staging、门内地点提交、工位占用和恢复；ActionSystem 只在抵达信号后启动 CraftingSystem 周期。
- 连续周期先尝试在同一会话 / 工位上原位续开。最后一个正式会话结束后，NPCSystem 立即清理权威状态，但将表现根 / NavigationRegion 隐藏延后 `0.15 s`；若期间有新会话则保持启用。StationLayoutController 在重启后调用 `NavigationServer3D.map_force_update()`，ActorMotionBody 为初始可达查询保留 120 物理帧同步宽限，既有 8 秒卡死 / 重寻路合同不变。
- 建筑在导航同步窗口内进入升级 / 失效时，ActionSystem 会在发起路线前复核可用性并保留 `building_upgrading / building_unavailable` 业务失败，不误报泛化路线失败。中断后只在最新权威位置仍处于建筑内时下发疏散，避免用 `movement_started` 覆盖具体失败结果。

## T0129C-A5-P1 全员正式战时节点生命周期

- 默认波次把全部当前可行动的既有 `NPC.tscn` CharacterBody（初始正常状态为 8 个）迁到 `FormalStationLayout` 的 NPC 初始锚点并绑定生产 NavigationMap；不复制 NPC 节点。战斗人员与非战斗人员使用同一 Body / Agent / CollisionShape，差异只来自权威 `behavior_mode` 与装备状态。
- 战斗期非战斗 NPC 的避战请求继续下发到 NPC 根的 ActorMotionBody；目标先吸附正式 NavigationMap。实体胶囊保持 layer 2 / mask 3，点击 Area 保持独立；逃离完成时 NPC 根与点击表面同时关闭，不能留下不可见但可点击的碰撞对象。
- `StationLayoutController.get_escape_exit_world_position()` 现返回 6 点正式后路的地图边缘 completion `(-54,-305)`。`RearEscapeNavigation` 是 12 顶点 / 5 多边形折线 Region，`RearEscapeGateLink` 从主岛后门内侧单向接入后路；两者与核心、敌军 Region 共用生产 NavigationMap。

## T0129C-A4-P7 五波动态实体节点

- `FormalStationLayout/FormalEnemies` 通过同一工厂生成第 1–5 波的 `8 / 16 / 24 / 36 / 48` 个 ActorMotionBody。步兵胶囊半径 `0.42 m`，骑兵 / 骑射为 `0.65 m`；Body 均为 layer 2 / mask 3，彼此和 world_static 都会阻挡。
- 所有 Agent 共享当前玩法目标而不是共享速度或位置。NavigationAgent 参数保留紧密施压和实体碰撞：`neighbor_distance=1.8`、`time_horizon_agents=0.6`、`time_horizon_obstacles=0.8`、统一 `avoidance_priority=0.55`；旧固定队列的按行列优先级已经移除。远程单位仍由权威 `attack_range` 自然停在外层。
- `motion_target_position` 是当前单位自行追逐的目标点，不是攻击槽。运动卡住后节点保持原位，CombatSystem 把状态改为 `pressing_blocked` 并重新请求；节点不会被传送，也不会把当前位置登记为假到达。
- 节点命名保持 `FormalWaveEnemyFoot01–08`（第一波兼容）与 `FormalWave%02dEnemyFoot%02d`（第二至第五波）。命名中的 Foot 仅为历史兼容；真实碰撞 profile 按 `unit_type` 选择 foot / mounted。
- ActorMotionBody 应用 profile 时同步 `NavigationAgent3D.max_speed`；RVO 回调输出先限到同一速度，再经过加速度约束。运行快照暴露 `profile_base_speed / navigation_max_speed / maximum_observed_speed / maximum_raw_safe_velocity_speed / maximum_frame_displacement / rvo_speed_clamp_count`，供拥堵回归识别速度尖峰。
- `presentation_facing_direction` 是 CombatSystem 逐敌保存的表现状态。速度低于 `0.35 m/s` 不更新；正常方向改变限制为每物理帧最多 `TAU * delta`。它只传给 `EnemyArtView`，不会旋转 CharacterBody 的导航或碰撞方向。

## T0129C-A4-P7b 默认正式敌我节点生命周期

- 默认 `spawn_wave()` 在 `FormalStationLayout/FormalEnemies` 创建运行 ID 为 `wave_%02d_runtime_enemy_%03d` 的 ActorMotionBody；旧 `WorldRoot/Station/Enemies` 保持为空。显式 P7 回归节点名继续保留原兼容格式。
- A5-P1 最初在战斗开始时迁移现有 `NPC.tscn` CharacterBody；A5-P7 后这些节点已默认常驻生产 NavigationMap，战斗只原地接管并在清理时恢复正式居民模式。Body layer / mask、InteractionArea 和角色表现始终是同一节点。
- `StationLayoutController.set_runtime_formal_world_enabled()` 复用正式预览内部开关来统一启用 / 禁用核心、敌军接近与后路 NavigationRegion、门链接和镜头范围；玩法系统不直接操作这些场景节点。战斗结束但仍有正式逃离者时，CombatSystem 暂缓关闭该开关，仅由 NPCSystem 保留逃离者的正式世界绑定，完成或留下后再释放。

## T0129C-A4-P6 第二波 16 实体与双排（历史）

`FormalStationLayout/FormalEnemies` 下第二波节点命名为 `FormalWave02EnemyFoot01–16`，均实例化同一 ActorMotionBody 场景。前 12 个读取剑盾模板并使用 `melee_front` 槽，后 4 个读取长杆模板并使用 `polearm_rear` 槽；第一波历史节点名 `FormalWaveEnemyFoot01–08` 保持兼容。

正门与仓库的有限正面使用同侧多排，主厅目标使用 12 位前排单线与 4 位后排单线。主厅槽在同兵种内按当前 Body 位置就近且唯一分配，长杆请求等待剑盾前排全部到位后才下发。第二波拥堵恢复上限为 60 秒，后排的目标容差受自身武器射程约束；NavigationAgent、胶囊碰撞和 avoidance 仍决定实际位置，CombatSystem 只在运动到达信号后开放攻击。

## T0129C-A4-P5R2 第一波直攻多实体导航

`CombatSystem` 在 `FormalStationLayout/FormalEnemies` 下创建 `FormalWaveEnemyFoot01–08`。每个节点均实例化 `ActorMotionBody.tscn`，因此实体根、胶囊碰撞、交互区和 `NavigationAgent3D` 不共享；`_formal_first_wave_slices / _formal_first_wave_node_paths` 以敌人 ID 分别保存运行态，物理帧只从对应 Body 回写该敌人的位置和表现方向。

出生仍使用不重叠的 3 列 / 3 排槽；出生后不再下发道路阶段，而是直接下发当前建筑的独立攻击位。正门 / 仓库各 8 位，主厅为北侧正面 8 位单排攻击带，以 `NavigationServer3D.map_get_closest_point()` 吸附到正式图。`motion_arrived` 才把同一位置交给攻击目标，失败或卡住不会伪装成到达。

T0200 起不再创建 `EnemyApproachNavigation` 横断面廊道；核心生产 NavMesh 的静态碰撞烘焙范围直接覆盖城外敌军生成区，且不读取道路。AStar 合同网格继续只验证墙内开放地面；生产 NavigationMap 则同时处理城内外静态实体绕行。

## T0129C-A4-P4 主厅实体路线

- `FormalActiveEnemyFoot01` 在仓库摧毁后仍为同一 CharacterBody3D，沿核心 NavMesh 从仓库攻击点移动到 `(0,2)` 主厅攻击点；不重建节点、不传送。
- `motion_arrived(main_hall)` 后 CombatSystem 才切换表现 / 攻击状态。主厅摧毁触发已有 GameState 与 HUD 失败链；正式实体仍由清敌 / 停止接口统一释放。

## T0129C-A4-P3 正门链接与仓库路线

- `FormalStationLayout/SpatialContract/EnemyFrontGateLink` 是双向 NavigationLink3D，连接外围 `front_gate` 与核心 `gate_turn`，与两个 Region 共用生产 NavigationMap，并随正式世界 / 显式切片启停。敌军用入站方向执行破门后的目标推进，友军用出站方向执行 T0160 正门外警铃集结；链接本身不提交门 HP、攻击或模式切换。
- `FormalActiveEnemyFoot01` 破门后仍是同一 CharacterBody3D，不重建、不传送；到仓库依次消费四个正式阶段，到达信号才改变攻击权威。核心 NavMesh 仍为 788 / 754，12 个建筑门链接计数不变。

## T0129C-A4-P2 活动敌人节点生命周期

- `FormalStationLayout/FormalEnemies/FormalActiveEnemyFoot01` 是首个同时存在于 `_active_enemies` 与正式场景树的敌人，复用 ActorMotionBody、Quaternius 敌人外观和 P1 NavigationMap。
- `_enemy_nodes[wave_01_formal_enemy_001]` 指向该 CharacterBody，因此既有受击、刷新、清敌和死亡入口无需第二套注册表。正式敌人死亡表现保留在正式父节点，Body 本体与活动状态立即移除。
- P2 不改变普通 `spawn_wave()`：未显式运行该切片时，全部波次仍使用旧 `Station/Enemies` Area3D。GM 对外入口已用活动攻门切片替换 P1 无伤害按钮。

## T0129C-A4-P1 正式敌军运行切片

- `StationNavigation` 的生产烘焙已直接覆盖北侧城外；旧 `FormalStationLayout/SpatialContract/EnemyApproachNavigation` 不再创建。`RearEscapeNavigation` 仍以独立 12 顶点 / 5 多边形区域连接后门到地图边缘，并与 `StationNavigation` 共用生产 NavigationMap，默认按正式世界状态启停。
- `FormalStationLayout/FormalEnemies/FormalEnemyFoot01` 只在显式 GM 试点存在，节点类型为 `ActorMotionBody / CharacterBody3D`，复用 `enemy_foot` 碰撞和 NavigationAgent 配置；停止、清敌或重跑会释放。
- 正式核心 `StationNavigation` 继续为 788 顶点 / 754 多边形和 12 个门链接。P1 未替换旧 `Station/Enemies` 的 Area3D 波次节点；该替换从 A4-P2 开始逐名进行。

## T0129A 独立场景空间灰盒（Main 尚未迁移）

> T0129B-C2a 后，Main 已有正式空间契约与禁用态导航 staging 根，但运行时权威仍未迁移；本节标题中的“尚未迁移”特指 BuildingSystem / NPCSystem / CombatSystem 等玩法空间。

- `docs/SCENE_SPACE_AND_VISUAL_PLAN.md` 是场景空间规格源，统一记录米制画布、城墙 / 城门、12 个最大等级建筑地块、道路、自然边界、敌人阶段点、镜头和功能位置表现合同。
- `data/presentation/station_spatial_plan.json` 的 `station_spatial_plan_v7` 保存目标空间、最高容量、21:9、第五波队形 / 路线与逃离节奏数据；`StationSpatialSandbox.gd` 只在独立场景中生成调试几何和汇总只读状态。`StationEnemyStressSimulation.gd` 创建 48 个物理包络敌人并执行 presentation-only 行军；`StationEscapeStressSimulation.gd` 创建单个逃离压力体并核算多种速度。它们不注册 Autoload、不成为 Main 子场景，也不写 BuildingSystem / NPCSystem / CombatSystem。
- v0.9 使用一套深草材质生成 `700 × 720 m` 可见承底；为了形成真实低位河槽，东西两块同材质地岸在 `X≈-97` 处留出 `30 m` 河谷，水面 `Y=-1.2 m`。这仍计为一种地表表现，不恢复浅色城内层。
- 14 段墙体、42 段道路、12 个八方向最大等级地块都由配置驱动；第 42 段是 A1 为酒窖正门增加的避障折点。地块 / 道路交叉使用有向矩形 SAT 校验，并额外验证每个建筑局部 `+Z` 正面入口到服务道路端点不超过 `2.5 m`。Main 相对布局合同继续要求主厅为中央最大 / 最高灰盒体量，后排、两翼和前场建筑不得跨区漂移。
- 森林散布覆盖 `688 × 708 m`，通过确定性抖动和道路 / 河流 / 城内排除生成 1043 个树实例；树干与树冠使用 MultiMesh，岩石仍为稀疏调试节点。该批处理策略只属于灰盒表现，不构成正式植被系统。
- 灰盒复用 `CameraRig.gd` 的输入合同，但实例局部配置为 `20–70 m` 与新平移边界；这不改变正式 Main 仍在使用的 `18–42 m` 与旧边界。
- 阶段 B 当时没有修改 `Main.tscn`、正式导航、CameraRig 脚本、CombatSystem 或运行时权威坐标。其用户构图、最高容量、21:9、48 敌与长逃离压力结论继续作为阶段 C 对照源。
- 灰盒通过后，坐标应优先收束到可审计配置，再由表现和权威系统分别读取；必须同步迁移建筑 / 地点入口、NPC 初始点、正 / 后门、商人 / 逃离、敌军阶段点、集结位、器械平台和镜头约束，避免场景节点与脚本常量形成两套空间事实。

## T0129B-C2a / T0129C-A1–A3b12R 正式空间、静态碰撞与运动组件

- `data/station_layout.json / station_layout_v2` 是阶段 C 的正式空间迁移合同；`station_spatial_plan_v7` 退回设计 / 压力证明职责。运行控制器只读正式配置，专项才同时读取两者做漂移校验。
- `Main/Presentation/StationLayoutController` 在 `Main/WorldRoot/FormalStationLayout` 下生成 Terrain、Roads、Plaza、WallsAndGates、BuildingRoots 和 SpatialContract。后者含广场 / 公告牌、8 个 NPC 初始 Marker、每座建筑 5 个进出 Marker、61 个工位 Marker、4 个主厅器械槽 Marker与 StationNavigation。
- StationNavigation 从 `formal_navigation_source` 的 237 个 StaticBody 同步烘焙：`0.25 × 0.1 m`，T0201 后为 928 顶点 / 862 多边形，解析 mask 只含 `world_static=1`。全站实际生成 241 个 StaticBody / 255 个 CollisionShape；导航源包含建筑外墙与主厅内部阻挡、围墙 / 门柱、地面、133 个逐建筑 fixture 碰撞部件和 24 个自然边界阻挡。它使用专属 NavigationMap；11 个双向 NavigationLink3D 跨过可进入建筑的 `1.8 m` 实体门洞，主厅不创建 Link，Region / Link 在预览外一起禁用。另保留 `0.5 m / 11303` AStarGrid2D，只作为合同坐标的确定性对照。
- C1 当时曾把 staging 根暂放在 `(1000,0,0)`；P6R3 已在正式世界默认化后将其归位 `(0,0,0)`。当前 CameraRig 直接套用正式 `20–70 m`、FOV 62°、`X[-150,150] / Z[-215,240]` 合同；显式 GM 旧图兼容才隐藏正式根并恢复旧相机值。
- `get_building_spatial_route(building_id, position_id)` 返回正式门外、门内、室内 / 具体位置、出口和面向方向；已有家具合同的位置还返回 `target_fixture_id / logical_position_center_position / arrival_mode`，而 `interior_target_position` 始终是家具外安全站位。病床额外返回床面 `occupant_anchor_position / occupant_anchor_facing_direction / occupant_pose`，供抵达并提交占用后的表现挂接使用；它不是路径目标。`get_npc_initial_world_position` 与 `get_navigation_path_local` 提供后续 C2b 的窄查询面。这些 API 只返回坐标，不提交地点、不占工位、不移动 NPC。
- 默认相机和全部系统仍面向 `WorldRoot/Station`。C2b 必须把 BuildingSystem / NPCSystem 的站内路线与地点事务接到上述接口；C3 / C4 继续迁移 CombatSystem、器械、MerchantSystem、逃离和虔诚合法地表。所有活动消费者完成前，不得把 FormalStationLayout 移回原点，否则旧敌人出生 / 攻击点会落入新墙内。
- 未来建筑场景先按最高等级包络放下全部权威功能位置，再拆为逐级 `UpgradeVisuals`；可见设备、同 ID Marker、NPC 站位 / 朝向与 `reserved_by / occupied_by` 保持一一对应。

`data/physics_navigation.json / physics_navigation_v1` 是实体运动的统一尺度与参数合同。`project.godot` 的 3D 物理层 1–3 分别命名为 `world_static / actor_body / interaction`。A5-P2 增加正式波次生成 / 调度合同：生成间距按本波最大胶囊计算，RVO 半径比物理胶囊多 `0.10 m` 预判缓冲，默认逐敌 AI 每帧轮转 8 人；物理胶囊、NavMesh 烘焙半径和战斗数值不变。A5-P3 新增 `CombatSystem.get_wave_hud_snapshot()` 作为高频 HUD 窄投影，完整波次快照继续用于低频业务 / 调试；HUD 和 MerchantSystem 只去重表现刷新，不降低权威 `logical_time_tick` 频率。A3 读取全 12 建筑的 `data/building_fixture_layouts.json`，当前生成 107 件配置物、61 个 NPCStand、36 个 OccupantAnchor、8 个 HorseAnchor 和 133 个复合碰撞部件；再读取 `station_layout.natural_collision` 生成 24 个河岸 / 岩脊 / 密林阻挡。A3b9R–A3b12R 已组合教堂、工械坊、主厅和仓库 Quaternius 资产；仓库生成 `WarehouseArt` 并隐藏旧 Envelope，七件 fixture 的 `cargo_categories` 仅控制类别装饰。导入 GLB 只读，`asset_path / visual_scale` 只影响表现；碰撞仍由配置尺寸生成，库存、主厅槽位、HP、失败条件和射程仍在权威系统。T0201 后全站为 241 个 `StaticBody3D` / 255 个 `CollisionShape3D`；屋顶、Marker 和点击表现不控制碰撞。

仓库 `WarehouseArt` 使用同一 `BuildingArtView` 类注册到 `RoofVisibilityController`，但不配置 `InteriorTrigger / ClickArea / NavigationRegion3D`，因此不会把不可进入建筑伪装成室内地点。`preserve_roof_albedo_texture=true` 时，屋顶材质仍逐实例复制并乘冷灰色，但保留原始木纹贴图；默认 `false` 保持铁匠铺纯色覆盖合同。两种模式都只改 scene-local 材质 alpha，透明时关闭屋顶阴影。

A1 静态 Body 最初位于 X=1000 隔离根；P6R3 归位后由 StationLayoutController 在正式模式同步停用旧白盒分支碰撞，避免两套实体重叠。A2a 新增 `ActorMotionBody.tscn / ActorMotionBody.gd`：CharacterBody3D 根拥有 NPC 配置胶囊，`InteractionArea` 单独承担拾取层，NavigationAgent3D 负责路径与 RVO，脚本以 profile 最大速度、加速度和 `move_and_slide` 执行实际位移，并把到达、取消、不可达与卡死作为信号输出。组件没有任何 BuildingSystem / NPCSystem / MemorySystem 引用。

`ActorMotionSandbox.tscn / .gd` 手工生成一个带中央阻挡洞的 NavigationMesh、一个未进入 NavMesh 的物理卡死墙和 5 个运动组件实例。蓝色实体绕中央阻挡，黄 / 紫实体对向会车，红色实体触发两次有界重寻路后失败，绿色实体在导航岛边缘返回不可达；蓝色实体途中还会暂停 / 恢复。`verify_t0129c_a2_actor_motion.gd` 锁定 Body / InteractionArea 分层、NPC 胶囊、绕障侧移、会车净距、avoidance callback、暂停零漂移、失败原因与零玩法权威提交。

`NPC.tscn / NPC.gd` 的通用根是 `CharacterBody3D`，实体胶囊、点击 `InteractionArea` 与 `NavigationAgent3D` 分层。A5-P7 后 8 名 NPC 新局即常驻生产 NavigationMap；`formal_nav_pilot` 只保留纯空间回归。床 / 椅 / 长凳路线先以 CharacterBody 抵达家具边安全位，BuildingSystem 提交占用后才挂到空间锚点；挂接只关闭 Body 碰撞，InteractionArea 保持启用，停止 / 不可达 / 改派 / 建筑失效 / 昏迷均释放事务并保留正式位置。跨门步骤以 `interior_position` 为目标，确保角色真正越过 NavigationLink 后才提交地点；ActorMotionBody 以路径末端水平距离复核 Recast 高度偏移造成的假不可达。战斗、非战避战、长逃离与默认商人都复用同一正式世界，旧直线模式仅供 GM 临时兼容。

## T0129 正式地图铁匠铺垂直切片

- 当前验收节点为 `Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt`，脚本 `FormalBlacksmithArtView.gd` 继承通用 `BuildingArtView`，但不再创建私有 4×4 NavigationMesh；路线、门洞、墙体、家具和 Actor 导航统一消费 StationLayoutController 的正式碰撞与生产 NavigationMesh。
- 脚本在运行时按 `14 × 12 m` 包络生成 Quaternius 模块墙 / 门、深木骨架、T0135-P8AR7 冷灰蓝平板岩屋面、正式炉区陈设与 `UpgradeVisuals/Level2 / Level3`。`BuildingArtView` 现可按建筑选择启用 `fade_exterior_with_roof`，复制屋顶、Exterior 和额外升级外墙附件的 scene-local 材质；正式铁匠铺在 `70→58 m` 内把两者同步从 `1.0` 降到 `0.06`，可见壳关闭投影而持久 shadows-only 代理继续投影，碰撞、导航和室内节点不随透明度关闭。
- 正式铁匠铺提供 `interaction_bounds_center / size` 和 `get_building_interaction_ray_hit(...)`。BuildingSystem 先命中正式建筑包围体：外壳透明时只把同建筑、被 NPC Area 射线准确命中的实体交给 NPCSystem，否则选择建筑；NPCSystem 反向阻止不透明包围体中的 NPC 抢先处理点击。该规则只决定 `npc_clicked / building_clicked` 的表现入口，不修改地点、工位或行动权威。
- `ChimneyAssembly/StoneChimney` 从 Lv.1 常驻，`Interior/ForgeAmbient/AmbientFX/Smoke` 的生成点与屋脊上的 `SmokeOutlet` 对齐。Lv.2 只增加烟囱冠、加固带与其他非容量资产，不再把完整烟囱误放在未来等级组中。
- 正式 `FixtureLayout/Visuals` 按 BuildingSystem 等级投影可见性；`NPCStands`、`SpatialContract` 和每建筑 `SpatialAnchors` 保留节点、元数据和权威坐标，但默认不渲染调试框 / 标签。最高等级 fixture 碰撞继续常驻，作为升级空间与生产导航净空的冻结合同。
- GM `smithy_art_level` 与 `verify_t0129_blacksmith_art_slice.gd` 已指向正式节点；旧 `WorldRoot/Station/Buildings/BlacksmithArtView` 只保留兼容和历史技术回归，不再是 T0129 验收源。

## T0129 历史 4×4 技术样板

- `BuildingArtView.gd` 监听 `building_state_changed`，仅把 BuildingSystem 的真实 `level` 投影到 `UpgradeVisuals/Level2 / Level3`；`debug_force_visual_level` 只供美术验收，不修改权威建筑。场景内按两个四边形生成 4×4 m 室内加门口漏斗 NavigationMesh，并保留 T0127 确定性门路作为当前移动执行链。
- `BuildingArtView.tscn` 的 1 级炉膛、风箱、铁砧、工具 / 材料与 `forge_01 / forge_02` 对齐；2 级烟囱 / 武器架不扩容，3 级第二铁砧与 `forge_03` 同时出现。静态碰撞覆盖外墙、炉膛、铁砧和工作台，透明屋顶不影响这些节点。
- 用户反馈迭代后，`Roof/RoundTileRoof` 使用 `position.y=3.18 / scale=(0.88, 0.42, 0.88)` 的低坡轮廓；运行时实际屋面范围约为 `2.96–4.75 m`。`Level2/StoneChimney` 改为 `(-0.75, 1.55, -1.48)`，实际顶部约 `5.30 m`，既从炉膛上沿起立又越过屋脊。
- 屋顶材质继续由 `BuildingArtView.gd` 创建 scene-local override，但铁匠铺候选会移除暖橙 albedo 贴图并使用冷灰蓝 `roof_albedo_override`；Exterior 各 surface 同样克隆后乘灰紫 `exterior_albedo_tint`，不污染 Quaternius 导入资源。透明 alpha 只修改这些本地屋顶材质，表现快照公开 `roof_profile / roof_scale / chimney_*` 供自动验收。
- 上述 `4 × 4 m` 包装现只作为进门、工位提交、工作动画和屋顶透明技术原型保留；用户已否决其最终占地。T0129A 全站空间灰盒和 `16 × 16 m` 铁匠铺地块验证已经完成，正式候选见上一节。
- `SmithyAmbientFX.gd` 只驱动火焰网格、OmniLight、烟 / 火星 GPUParticles 和风箱把手，暂停时冻结；不产生资源、火灾或工作效率。
- `NPCArtView.gd` 新增权威 HP 边沿驱动的血粒子、受击位移弹簧和受控倒地冲量；`CombatSystem.gd` 只把每批第一名敌人装配为红褐色 Glen 包装 + 剑盾样片，其余继续用 capsule，避免提前承担 48 个完整骨骼角色成本。敌人权威状态、伤害、移除与清敌顺序不变。
- `blacksmith_vertical_slice_theme.tres` 只应用在 HUD / NPCPanel / BuildingPanel，继续使用真实 Control；GM 的 `smithy_art_level` 只调用表现调试接口。

## T0128 NPCArtView、格伦外观与动画投影

- T0128 当时以 `Area3D` 为根建立 `LegacyVisuals / ArtMount`；A2b-P1 后 `NPC.tscn` 根已迁为 `CharacterBody3D`，点击改由子级 `InteractionArea` 承担，两个表现容器结构不变。`NPC.gd` 按 `character_appearances.json` 实例化正式外观，未映射人物继续显示 legacy。
- `GlenArtView.tscn` 组合只读 Quaternius 基础体、农民服装、短发和 UAL2 rig。A5-P5a 的 `TomaArtView.tscn` 曾继承同一包装提供绿色马夫低配外观；P2 后它只作回退历史资产，生产映射已改为上一节的 `TomaChibiArtView.tscn`。
- 运行时构建真实 `AnimationNodeStateMachine`，状态名固定为 `idle / walk / run / talk / work / attack / hit_react / unconscious / get_up`；程序位移保持权威，AnimationTree 使用非 root-motion 片段并按世界速度调整播放。
- 六个 `BoneAttachment3D` 挂点使用共享骨骼名；锤子只在 Back / RightHand 之间重挂。外观映射、材质、动画、装备显示和 PhysicalBoneSimulator 占位均属于表现层，不写 profile、EquipmentSystem、HP、工位或事件。
- `NPC.gd` 在移动开始 / 停止、朝向和 profile 刷新时投影到 art view。受击依据权威 HP 下降播放短反应，`unconscious=true` 播放倒地，权威复苏边沿播放 get-up；自定义 TimeSystem 暂停同时冻结动画树和 transient 计时。

### T0128A 朝向归一化与持续动画循环

- `SourceFacingCorrection` 是第三方源空间到项目角色空间的固定转换，绕 Y 轴 180°；`CharacterPivot` 仍保存动态路径 yaw，二者不得合并，否则会再次产生正面 / 位移反向。
- AnimationPlayer 的导入 AnimationLibrary 视为共享只读源。每个 NPCArtView 初始化时创建实例本地 AnimationLibrary 和 Animation 副本，只对持续状态片段设置 `LOOP_LINEAR`；AnimationTree 继续负责状态切换和淡入淡出。
- 调试快照新增视觉 forward / target direction、source correction 和 work cycle position / length / loop mode，用于验证表现，不新增权威状态或 GM 修改入口。

## T0127 铁匠铺真实空间执行与权威提交

- `Main/WorldRoot/Station/Buildings/BlacksmithArtView` 是首个正式 `BuildingArtView` 实例；旧 `Blacksmith` Mesh 只隐藏显示，继续作为 `building_defs.json.scene_nodes` 的数据 / HP / 点击兼容绑定。
- `BuildingArtView.gd` 公开门外、出口、门内、室内默认站位和按 `workstations[].id` 查询的工位 Marker 世界坐标。`ClickArea` 只登记 `building_id` 元数据，最终选择仍由 BuildingSystem 的统一拾取入口处理。
- NPCSystem 只为 `blacksmith` 启用空间路线状态机：`approaching_door -> crossing_entry -> moving_to_workstation -> workstation_arrived`；离开使用 `moving_to_exit -> crossing_exit -> leaving_building`。每步复用现有移动执行器，Marker 路线从门洞绕开静态墙体。
- BuildingSystem 独占 `reserved_by / occupied_by`；ActionSystem 派工时预留，NPCSystem 穿门时提交地点，抵达工位后 ActionSystem 提交占用并创建 active 计时。MemorySystem 与 UI 只读这些权威快照。
- `NavigationRegion3D` 仍是禁用占位。本轮用确定性门口 / 门内 / 工位路线满足首个样本的稳定进出；T0131 批量迁移前不得把该节点描述为已烘焙全站导航。
- 中断、昏迷、失败、升级清退和室内改派统一取消路线并释放预留 / 占用；已经穿门者通过反向路线真实离开，门外中断不提交进入事实。

## T0126 BuildingArtView 与 RoofVisibilityController

- `scripts/presentation/buildings/RoofVisibilityController.gd` 挂在 `Main/Presentation` 和 ArtSandbox 根下，只读取 `Camera3D.position.length()`；Main 使用既有 CameraRig 距离，沙盒把 orbit target 放在 CameraRig、相机局部坐标只保存观察距离。
- `scripts/presentation/buildings/BuildingArtView.gd` 在 ready 时克隆屋顶 `BaseMaterial3D` 为 scene-local surface override，启用 alpha depth pre-pass 与 anisotropic 过滤。历史版本曾在 alpha 小于 `0.98` 时关闭阴影；T0135-P7R 已改为透明源 Mesh 与持久 shadows-only 代理分离，当前阴影不再随 alpha 消失。
- `scenes/buildings/BuildingArtView.tscn` 实现公共建筑节点合同，实例化圆门 / 直墙 / 圆瓦屋顶 / 木地板 / 铁砧，并提供桌子、碰撞、点击区、入口、室内触发体、升级和 VFX 挂点。NavigationRegion3D 是明确禁用的 T0127 占位。
- ArtSandbox 的 `SmithyView` 与 `ClinicView` 复用同一 PackedScene 和全局控制器，但分别配置 `20–30 m / 0.06` 与 `23–34 m / 0.12`，用于连续滚轮对照。
- T0126 完成时 Main 暂未实例化建筑包装；T0127 已接入正式铁匠铺，其他建筑仍保持原基础 Mesh 与入口地点流程。

## T0130-P0 Synty 可见骨架与 KayKit 动作试片

- `assets/3d/synty/t0130_pilot/` 在 P8 后只包含 9 个角色 FBX、4 个装备 / 职业道具 FBX 与 18 张调色板；`assets/3d/kaykit/animations/rig_medium/` 包含 8 个动作 GLB。完整源包继续隔离在带 `.gdignore` 且被 Git 忽略的 `art_source/`。
- `ChibiCharacterPilot.gd` 为每个试片实例保留一套隐藏 KayKit source Skeleton 与一套可见 Synty target Skeleton；KayKit mannequin Mesh 不进入运行时树。目标 Skin bind 与骨名在挂入前同步为 `SkeletonProfileHumanoid` 名称，`RetargetModifier3D(use_global_pose=false)` 只转移相对姿态并保留目标骨长。
- 动画收集器从 8 个 KayKit GLB 复制并重写一次轨道路径，生成含当前 131 个可用非空片段的进程内共享 AnimationLibrary；48 个敌人不复制 48 份动作。P1 仍保留双骨架实时重定向，后续需要评估离线烘焙或导入期标准化。
- `GlenChibiPilot.tscn` 与 `EnemySwordShieldChibiPilot.tscn` 提供相同 18 状态接口、Capsule 选择体与手部装备挂点；不读取或写入 NPC / Combat 权威状态。`ChibiCharacterSandbox.tscn` 在 P8 后以 8 组状态并排显示 8 名初始 NPC 和剑盾敌人。
- `Main/Presentation/ChibiCharacterPilotPreviewController` 只在 GM 请求后把一对试片挂到 `FormalStationLayout/T0130CharacterPilotPreview`，关闭时释放整根；不替换正式 NPC / 敌人，不注册伤害、地点、工位或事件。自动化验证启停前后权威 NPC 数量不变。

## T0125 ArtSandbox、导入资源与表现基线

- `scenes/art/ArtSandbox.tscn` 是独立运行入口，实例化六个 Quaternius 代表 GLB；不成为 Main 子场景，不注册 Autoload、EventBus 信号或权威系统。
- `scripts/presentation/ArtSandbox.gd` 只克隆导入的 `BaseMaterial3D` 做 anisotropic surface override、开启阴影、应用 rim / outline 并播放 `Farm_Harvest`。相机滚轮 / 中键只控制沙盒观察，不改变正式 CameraRig。
- `data/presentation/art_scale_baseline.json` 是单位、朝向、尺寸、色板、导入与性能软上限的表现配置；它不得保存建筑等级、地点、工位、资源、HP、伤害或行动事实。
- 导入 GLB 继续视为只读源；其外置 PNG 使用 2K Godot 导入上限。正式建筑 / 角色必须通过包装场景增加碰撞、导航、屋顶、升级件、挂点和状态投影，不把这些修改写回第三方导入物。
- 当前 Main 只有铁匠铺使用正式包装与穿门 / 工位权威链，其他建筑和原 NPC 表现仍使用基础版本。T0126 的屋顶合同继续有效，T0127 不改变 T0125 角色基线。

## T0123 美术重构目录与未来运行时边界

Quaternius 美术升级已建立 `art_source -> assets -> scenes/resources -> Main` 的单向管线。`art_source/` 含 `.gdignore`，只保存原始下载、许可证和 DCC 工作文件；Godot 正式运行时只引用经筛选的 `assets/`、包装后的 `scenes/` 与项目维护的 `resources/`。第三方导入场景视为只读源，碰撞、挂点、导航、屋顶、升级部件和表现脚本通过继承 / 包装场景添加。

后续表现脚本统一进入 `scripts/presentation/`，只消费 BuildingSystem、NPCSystem、ActionSystem、CombatSystem、EquipmentSystem、CameraRig 等权威快照或信号。表现层不得自行决定建筑等级、地点、工位、资源、HP、伤害、行动完成、事件或见闻。

T0126 已新增统一相机缩放快照到屋顶透明度的表现链；T0127 已把铁匠铺从“到入口即切换地点”迁移为门外 / 门内 / 工位提交链。建筑公共节点合同由 `BuildingArtView.tscn` 落地，但其他建筑仍保留旧地点逻辑；T0129 用户验收前不得批量复制到全站。

## T0116 新运行时接口

- `LLMBridge.build_dialogue_intent_revalidation_payload(...)`
- `LLMBridge.request_npc_dialogue_intent_revalidation[_async](...)`
- `dialogue_intent_revalidation_response_received / ..._async_response_received`
- `DailyPlanSystem.debug_get_dialogue_intent_revalidation_snapshot(npc_id)`

DailyPlanSystem 保存复核 request-id / NPC 去重表、一次性批准签名和最近结果；计划更新会清除旧批准。modify 写回当前小时 `dialogue_goal` 并更新意图制定元数据后重新计算签名，cancel 调用既有 `request_plan_reevaluation(..., revision_hours=[current_hour])`。Main.tscn 无节点改动。

## T0115 Godot 侧主动交涉与失败重估职责

- `DailyPlanSystem.gd` 把 stage-one 的 `action_failure` 来源带入正式修订上下文；当前小时若原样重复失败项，在 `set_npc_daily_plan(...)` 前返回 `failed_action_repeated`，继续使用既有 `FORMAL_REVISION_MAX_ATTEMPTS`，不写计划、不派发、不另开判别链。
- `NPCSystem.gd` 在主动交涉、建筑移动和世界目标移动开始时原子写入新 action、非失败 start result 与空失败上下文。`handle_npc_clicked(...)` 先请求 DialogSystem；失败时消费点击但保留 proactive，成功后才清理问号状态。
- `DialogSystem.gd` 为主动交涉保存新草稿 ID。激活失败或草稿在同步状态事件中消失时，按 cancelled 会话清理仍属于该 ID 的草稿并返回失败；只有同一 ID 真正成为 active dialogue 才写 NPC 开场轮次。
- `NPC.gd` 的 `...` 覆盖 `?` 规则不变：这只是当前规划活动的显示优先级。规划结束后 NPCSystem 刷新节点，未消费的 proactive 问号自动恢复。
- 没有新增节点、Autoload、信号、场景或 GM 控件。三个既有专项分别锁定交涉事务、失败修订重试与移动状态原子性。

## T0114 Godot 侧虔诚与陨石职责

- `Main.tscn` 在 CombatSystem 后注册 `PietySystem`，并在 Station 下提供无碰撞的 `Effects` 容器；没有新增 Autoload。
- `ActionSystem.gd` 在 active 祈祷推进后把本 tick 的有效秒提交给 PietySystem。暂停分支、pending 移动、行动中断和已到个人时长后的弥撒等待不会触发提交。
- `PietySystem.gd` 读取 `data/piety_ability.json`，保存共享虔诚、pending 陨石和燃烧区，监听 `logical_time_tick` 推进，并通过 EventBus 发布进度 / 施放 / 落地。T0159 起落地结算后提交全站公开影响事件，冲击实际击败敌人时再提交独立击杀事件；MemorySystem 只消费结构化事实，不反向决定效果。
- `PietyAbilityButton.gd` 负责中心十字架 `✝` 与圆环绘制，HUD 负责输入与地面预览；两者都不保存独立虔诚，也不触碰 HP。`CombatSystem.apply_enemy_area_damage(...)` 是两段伤害唯一入口且只枚举活动敌人，确保 NPC、建筑和器械无友伤。
- GMPanel 只暴露 PietySystem 的填满、设值、快照和时间推进调试接口；专项自动化与主界面都经过真实系统路径。

## T0109 Godot 侧异步请求退出职责

- `LLMBridge.gd` 继续独占每个原生 HTTP 工作线程；互斥保护的传输取消状态只用于通知 worker 停止 `HTTPClient.poll()`，不参与业务结果、usage 或权威状态判断。
- `cancel_llm_request(...)` / `cancel_npc_llm_requests(...)` 先保留原有慢速和 NPC 活动释放，再请求对应传输协作退出；正常 deferred 完成路径仍由主线程 `wait_to_finish()` 并发出既有取消结果。
- `_exit_tree()` 统一拒绝新异步请求、取消所有传输、释放所有慢速 / NPC 活动并 join 已启动线程。退出中的 worker 不再投递完成回调，避免 Callable 指向已释放节点。
- 没有新增节点、Autoload、endpoint、EventBus 信号或 GM 关闭按钮。`verify_llm_bridge_shutdown.gd` 使用本地悬挂 TCP 响应验证真实慢连接退出，不依赖供应商或 Mock 伪成功。

## T0108 Godot 侧稳定知识迁移职责

- `data/npc_initial_long_memory.json` 仍是 8 人开局前建筑知识的唯一数据源；围墙 / 主厅两条六级器械位置曲线写入该图谱，T0223 已删除主厅射程加成知识。
- `NPCSystem` 的加载、深拷贝和幂等初始化不变；`LLMBridge` 仍通过既有 `long_memory / long_term_memory` 原样投影，NPCPanel 仍只读中文知识标签。
- 没有新增事件、广播、短期记忆、Prompt 字段、Schema、节点或权威结算。Python / Godot 专项负责锁定旧“只能上墙 / 永不增槽”文本已消失。

## T0106 Godot 侧全量紧凑记忆职责

- `MemorySystem.gd` 的权威事件、见闻、稳定 ID、原始 payload、广播与熟睡总结快照轮转均不修改。
- `LLMBridge.gd` 移除每类 8 条上限，六类 payload 都按当前索引原顺序投影全部亲历 / 见闻；公共 `build_compact_memory_event(...)` 生成 `summary + details`，省略重复大结构并把计划 `items` 合并为连续 `plan_segments`。
- `DailyReflectionSystem.gd` 复用同一投影器生成反思快照；`memory_kind` 只标记亲历 / 见闻，不改事件归属。供应商侧的反思去重由后端 Model Adapter 完成。
- `GMPanel.gd` 将原“短期记忆”入口改为“短期记忆 / LLM”，只读显示原始事件 / 见闻计数和 LLM 实际全量紧凑投影；不写事件、不清水位，也不维护第二套压缩器。
- 没有新增节点、Autoload、EventBus 信号、endpoint、call_type 或权威结算。专项覆盖六类 payload、超过 8 条旧因果、紧凑率与现有私有记忆边界。

## T0105B Godot 侧跨小时弥撒职责

- `ActionSystem.gd` 通过只读 `is_npc_committed_to_active_mass(...)` 统一识别 active `lead_mass` 与 `pray_at_chapel + mass_attendance`。参礼者自身祈祷计时到期时停在时长上限，必须等主持自然结束后先恢复独祷，再正常完成。
- `DailyPlanSystem.gd` 只在 `hour_started` 的计划不同且 NPC 仍受弥撒约束时登记运行时 deferred marker，不打断、不释放位置。弥撒结束后，同一 deferred 批次按现有服务提供者、训练指导者、普通行动、服务接受者、训练学员、对话的依赖顺序执行当时最新的当前小时计划。
- 非小时边界的计划修订、对话恢复和主动执行会清理该 marker 并沿用既有即时切换；对话、建筑失效、昏迷等系统仍可按原权威路径中断弥撒。普通行动、完成策略和计划数据结构均未修改。
- 没有新增节点、Autoload、EventBus 信号、后端、Schema、Prompt、模型调用或 GM 权威入口。

## T0105A Godot 侧结束语义职责

- `ActionSystem.gd` 在 `lead_mass` 自身时长完成时，先让参礼者以 `mass_completed` 恢复独祷，再复用 `_complete_pray(...)` 释放祭坛、设置主持者完成状态并写 `prayer_completed`。
- T0105B 已取消“计划小时边界直接完成主持”的旧入口；整点现在只登记等待，不能冒充弥撒自然结束。
- `MemorySystem.gd` 现有摘要分支不变：`mass_leader_stopped` 显示“因主持中断而结束”，`mass_completed` 显示“弥撒结束”。事件仍经既有 `local_public` 路由入库 / 广播。
- 没有新增节点、Autoload、EventBus 信号、后端、Schema、Prompt、模型调用或 GM 权威入口。

## T0102 Godot 显示层本地化职责

- `data/building_defs.json` 为旧生产位置提供中文 `name / workstation_name_prefix`，但 BuildingSystem 继续保存并使用原有 `id / type / tags`；没有新增数据迁移或第二套位置状态。
- `BuildingPanel.gd` 不再读取标签用于渲染，并在配置名缺失或等于历史自动生成的英文 `type + 序号` 时使用中文类型名；未知类型、资源、成员和马匹位置只在显示层降级为中文。
- `NPCPanel.gd` 通过既有 ActionSystem 目录获取正常 action 的配置中文名，移动和未知运行态采用显示保底；HUD 只把实现类名改为玩家可读的“装备系统”。
- 没有修改后端、Schema、Prompt、Autoload、场景节点、EventBus 信号、权威结算或 GM 控件。主场景可直接验证；GM 日志仍可显示内部系统名。

## T0101 Godot 侧职责

- `data/npc_initial_long_memory.json` 是守备官四条开局前知识的唯一种子来源；Godot 不在 GDScript 写死“三年前”或关系文案。
- `NPCSystem` 沿既有 `key_value_replace_v1` 初始化并保存四条关系，`LLMBridge` 沿既有长期记忆构造原样投影到六类正式请求；没有新增传输镜像。
- `NPCPanel` 的【知识】弹窗继续只显示中文主体、关系和值，因此玩家可直接确认“到站时间 / 来站前经历 / 过往相处”；底层 `confidence / day / time` 仍保留。
- 没有新增场景节点、Autoload、EventBus 信号、GM 命令或权威结算。既有 `long_memory <npc_id>` 可辅助查看原始记录，但前端本身已经可验证。

## T0100 人设字段职责

- `data/npc_profiles.json` 是 8 人 `religion="天主教"` 的唯一配置源；现有背景无冲突，不在 GDScript 补写人物故事。
- `NPCPromptProfile.FIELD_DEFINITIONS / build_setting(...)` 新增“宗教信仰”一项，因此对话 `npc_setting` 与 NPCPanel【背景】自动读取相同字段；UI 不保存副本。
- `LLMBridge._build_npc_context(...)` 把同一字段放入共享 `NPCIdentity`，覆盖日计划、范围判别、正式修订、战时心理和熟睡总结；后端 Schema 显式保留。
- 没有新增节点、Autoload、EventBus 信号、endpoint、模型调用次数、状态或权威结算。玩家可从主场景背景弹窗直接验证，无需 GM 入口。

## T0099 Godot UI 职责

- `NPCPanel.gd` 继续只读 `MemorySystem.get_all_events()`，但筛选后只按 `day / time / _history_sequence` 排序并按日期输出，不再消费 `combat_started / combat_ended` 或生成 `_history_wave_label`。
- `DialogPanel.gd` 在自身可见、非旁听且“提出应征”可用时处理 `Tab`，通过设置 CheckButton 的 `button_pressed` 复用既有 `toggled -> DialogSystem.set_recruitment_request_pending(...)` 链；禁用 / 隐藏状态保持权威。
- `Main.tscn` 在 `DialogPanel` 下增加 `DialogAttackConfirmationDialog`。`DialogPanel.gd` 持有“本次打开已确认攻击”的纯 UI 标记，在新开、挂起隐藏、恢复、完成、取消、强制结束或切换旁听边界重置；只有确认成功调用既有攻击接口后才解除本次打开期间的重复提示。
- 没有新增 Autoload、EventBus 信号、后端 endpoint、Schema、权威结算或 GM 控件；日期、快捷键与确认均可在主场景直接验证。

## T0098 Godot 系统职责

- `ActionSystem.gd` 继续把权威 action 保持为 `pray_at_chapel`，active 字典新增 `prayer_mode=personal_prayer / mass_attendance` 与可选 `provider_npc_id`。`lead_mass` 开始、完成或停止时只转换 / 重绑定这些字段；祈祷席、`elapsed_seconds`、`duration_seconds` 和计划执行签名不变。
- `MemorySystem.gd` 注册 `prayer_joined_mass / prayer_resumed_alone`，生成确定性摘要并使用既有 `local_public` 路由；没有新增 EventBus 信号或独立事件系统。
- `DailyPlanSystem.gd` 与 `LLMBridge.gd` 移除独立参加弥撒的派发排序、依赖候选和教堂失败归一化；模型、GM 和计划下拉只看到 `pray_at_chapel / lead_mass`。
- `get_runtime_action_snapshot()` 暴露 `prayer_mode`，既有 GM 运行态、当前计划和事件列表即可观察转换。本任务不新增节点、Autoload、场景或 GM 权威按钮。

## T0095/T0096 Godot 系统职责

- `ActionSystem.gd` 持有统一 `_is_action_commit_ready(...)`，所有 fixed / target-aware pending 在暂停、尚在移动、地点不符或已有 active 时不得提交；`_on_logical_time_tick(...)` 在暂停时也不推进。
- `NPC.gd / NPCSystem.gd` 继续持有物理移动与到达事实。暂停不调用 stop，不清路线；到达后由 NPCSystem 清空 `movement_target` 并发出状态变化，ActionSystem 才有资格提交。
- `MemorySystem.gd` 新增原子短期快照与按 ID 选择性轮转；全局事件实体不删除。
- `DailyReflectionSystem.gd` 维护 21:00 窗口、上次成功内容终点、请求快照及日记元数据；`NPCSystem.gd` 负责把 `record_label / trigger / period` 追加进长期日记。
- `LLMBridge.gd` 将 `summary_window / reflection_period` 发送给既有 `/npc/daily_reflection`，并优先用 `record_label` 投影历史日记。没有新增系统节点、Autoload、endpoint、EventBus 信号或 GM 控件。

## T0094 Godot 节点与系统职责

- `Main.tscn` 在 NPC 面板原对话位置使用 `NPCDialogueButtonRow`，包含占满剩余宽度的 `NPCDialogueButton` 与右侧小型 `NPCDialogueHistoryButton`；既有挂起橙点仍是对话按钮子节点。没有新增独立历史弹窗，记录复用 `NPCMemoryDetailPopup`。
- `NPCPanel.gd` 只读 `MemorySystem.get_all_events()`，筛选当前 NPC 与守备官的完整会话并按日期 / 时间排序；T0099 起展示只按日期分组，不再计算历史波次组。它不写事件、不启动对话、不触发 LLM；`BuildingPanel.gd` 则把宿舍床位恢复为通用位置格式，只显示 `occupied_by`。
- `DialogSystem.gd` 在真正打断前构造 `interrupted_activity_context` 并保存在当前会话；`LLMBridge.gd` 仅在非空时把它放入目标 NPC 的对话请求。该结构不经过 MemorySystem，也不新增 EventBus 信号。
- `ActionSystem.gd` 负责固定地点行动与 `_start_pray(...)` 最终到达校验；T0098 后弥撒开始 / 结束改为同一祈祷行动的内部模式转换。`NPCSystem.gd` 负责移动中断时让逻辑地点、信息空间和世界位置一致收束。`DailyPlanSystem.gd` 继续负责其他真实失败 / 对话后的两阶段计划链和当前小时可靠派发。
- `DailyReflectionSystem.gd` 负责 21:00 窗口 identity、同窗睡眠累计、并发等待、成功去重与调试快照；T0095 起 MemorySystem 的短期索引轮转改为按请求快照 ID，NPCSystem 既有深度睡眠锁与 LLMBridge 既有 endpoint 不变。
- 本任务不新增系统节点、Autoload、endpoint、EventBus 信号或 GM 按钮。前端可直接验证床位与记录；教堂继续复用通用祈祷 / 主持弥撒指定行动与计划入口，夜间窗口通过扩展后的 `reflection_result` 快照观察。

## T0092 Godot 侧兼容边界

- `LLMBridge.gd` 的 endpoint、信号、慢速注册和成功响应消费不变；默认日计划规则不再作为 `planning_rules` 重复放入 payload，显式非空自定义规则仍可附加。
- Godot 仍接收完整 `ok / npc_id / plan_day / needs_revision / immediate_action / should_start_escape` 及完整计划项，不感知 provider 是否省略这些字段。
- 日计划 / 修订中唯一白名单候选的 `action_kind / priority / location_id` 已由后端补齐；DailyPlanSystem、DialogSystem、CombatSystem 和 NPCSystem 继续使用原结构。
- 没有新增节点、Autoload、信号、场景修改或 GM 权威入口。

## T0091 对话目标与地点职责

- `LLMBridge.gd` 的 `talk_to_npc` 候选只暴露目标 NPC 身份，不写 `location_id`；固定地点行动候选不变。
- `DailyPlanSystem.gd` 将后端完整计划 Schema 转成内部计划时，对 `talk_to_npc` 只保存 `target_id / target_npc_id`。T0097 的 provider 冗余字段已在后端编译边界丢弃；即使兼容旧完整响应含冗余地点，Godot 也不会把它写成计划目的地。
- `ActionSystem.gd` 继续拥有对话寻路权威：派发时读取目标当前地点，接近期间按既有有限重定向规则跟踪目标，目标不可用则产生结构化失败。
- 没有新增节点、Autoload、EventBus 信号或 GM 权威入口。

## T0085 升级结束后的计划职责

- `BuildingSystem.gd`：升级 / 修复正常完成并释放协助者时，同时清空其旧 `last_action_failure_context`；它仍只结算建筑作业，不决定后续计划。
- `DailyPlanSystem.gd`：旧 `assist_upgrade / assist_repair` 目标已结束时，按实时 BuildingSystem 状态构造 `no_active_upgrade / no_active_repair` 本轮上下文，再进入既有两层重估。日计划、正式修订和合并不再检查工作阶段是否达到 6。
- `LLMBridge.gd`：计划项导出时优先采用 `target.location_id`，因此升级协助保持 `target_id=building / location_id=plaza`；`assist_upgrade` 纳入 Schema 工作统计。工作数量仍提供给 Prompt，不参与权威结算。
- 24 小时完整性、小时唯一性、动态候选、当前小时即时行动及真实 provider 来源仍由现有边界校验。没有新增节点、Autoload、信号或 GM 控件。

## T0084 固定宿舍床位职责

- `data/building_defs.json` 在床位 1–8 上配置 `assigned_npc_id`，按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜的叙事到站顺序绑定；床位 9–10 不声明归属。
- `BuildingSystem.gd` 继续是位置权威。`claim_workstation(...)` 若发现调用者有同类型专属位置，只尝试该位置；没有专属位置时跳过别人的专属位置并使用未分配位置。`release_workstation(...)` 只清空 `occupied_by`。
- `ActionSystem.gd` 的睡眠开始、完成、中断、升级封闭和结构化事件路径不变；它仍只按 `dormitory_bed` 类型请求，并保存 BuildingSystem 返回的具体 `workstation_id`。失败上下文额外保留固定位置和被保留位置信息。
- `BuildingPanel.gd` 不提供玩家交换入口；T0094 起只渲染实时空闲 / 占用，不再把固定归属写在面板上。功能直接在主场景宿舍面板可见，不新增 Autoload、信号或 GM 控件。
- `tools/verify_fixed_dormitory_beds.gd` 覆盖配置顺序、乱序并发申请、重复申请、未来 NPC 只用空余床、真实睡眠两次复用同一床和面板文案。

## T0083 对话结果元数据与表现职责

- `DialogSystem.gd` 在合法应征请求响应产生 `accept / reject` 时，只给对应 NPC history turn 增加可选 `recruitment_result`；`text` 继续保存模型真实回复，后续回合不依赖会话级最后结果反推历史。
- `DialogPanel.gd` 按 turn 元数据生成绿色对勾或红色叉号结果行，并与回复组成同一个显示块。UI 不决定应征结果，也不修改 NPCSystem 权威入伍状态。
- `MemorySystem.gd` 仍只从 turn 的 `speaker_name / text` 生成事件全文，结果展示文案不会进入事件正文；完成会话标题统一为“守备官与 XX 对话”。
- 没有新增节点、Autoload、EventBus 信号、后端 endpoint 或 GM 权威入口。

## T0082 对话会话状态与摘要职责

- `DialogSystem.gd`：继续持有 `recruitment_request_pending` 会话开关与 `session_had_recruitment_request` 历史事实；发送时保持开关，不让 UI 自行记忆 sticky 状态，并在系统取消入口和挂起超时处统一执行应征锁。
- `DialogPanel.gd`：只投影 toggle、取消 disabled 与 tooltip；不自行决定消息是否携带应征标记，也不自行结束会话。
- `MemorySystem.gd`：守备官完成会话仍只写一条事件；`session_completed` 时从权威 `dialogue_text` 按顺序生成完整确定性 summary。
- `NPCPanel.gd`：无需新增专用渲染分支，既有事件库 / 详情读取更新后的同一 summary。

## T0081 统一 NPC 生活消耗节点职责

- `Main.tscn` 在 `TimeSystem` 后、其他逻辑消费者前挂载 `Main/Systems/NPCNeedsSystem`。它先读取本 tick 开始时的行为 / 行动快照，再按实际剩余行动时长拆分活动与空闲时间，避免大时间步在行动完成后继续按原行动扣除。
- `NPCNeedsSystem.gd` 独占饱食 / 疲劳的连续速率、小数余量和边界钳制；读取 `data/activity_needs.json`、NPC 权威状态、ActionSystem 运行快照及 BuildingSystem 作业剩余时间，只通过 `NPCSystem.update_npc_state(...)` 写回。
- `ActionSystem.gd` 不再结算工作、训练或睡眠的生活消耗；吃饭只保留食物带来的正向饱食恢复。它新增配置驱动的有效工时经验累计入口，仍通过 `NPCSystem.increase_npc_skill(...)` 与 MemorySystem 事件进入既有成长管线。
- 协助修复 / 升级的有效秒数由建筑作业剩余时间与当前速度上限裁切；协助治疗由 NPCSystem 根据当前 HP、30% 复苏阈值、治疗速率和该治疗者的小数恢复余量计算复苏前秒数。暂停与倍率仍只由 TimeSystem 形成 `logical_time_tick.game_delta_seconds`。
- 新节点不新增 Autoload 或 EventBus 信号。`verify_activity_needs_framework.gd` 穷尽行动 / 行为模式，`verify_assist_timed_experience.gd` 覆盖三类协助的有效时间与经验。

## T0080 建筑入口失败与升级协助职责

- `BuildingSystem.gd` 继续独占升级作业、封闭和入口可用性；它发出状态变化，但不判断 NPC 是否已经看见封闭，也不写计划失败。
- `NPCSystem.gd` 在移动真正抵达时重新读取建筑可进入性。若被拒，它停止移动、清理到达上下文、把 NPC 收束到广场，并发出 `EventBus.npc_building_entry_failed`；该信号携带入口检查事实，不直接触发 LLM。
- `ActionSystem.gd` 对升级状态变化只立即中断目标建筑内的 active 依赖行动；路上 pending 保留。收到入口失败信号后，仅当该 NPC 的 pending 行动仍真正指向该建筑时，才清理运行态并写唯一 `*_failed_building_upgrading`。
- `DailyPlanSystem.gd` 继续只消费最终行动失败并走 T0050；它与 `backend/app.py` 都将 `assist_upgrade` 计为工作阶段。`LLMBridge.gd` 负责投影 `plaza / requires_building_entry=false / counts_as_work_phase=true` 及 BuildingSystem 实时升级布尔状态。
- 没有新增场景节点或 Autoload；新增一个 EventBus 领域信号。`verify_building_upgrade_action_failure.gd`、`verify_dynamic_station_context.gd` 和真实 provider 专项覆盖门口时序与协助认知。既有 GM 入口足够，不新增控件。

## T0078 NPC 主动守备官交涉职责

- `DialogSystem.gd` 以会话状态中的 `dialogue_kind=player_npc / dialogue_initiator=npc / proactive_talk=true` 作为唯一取消锁判据；它在草稿、正式会话和系统取消入口保持同一规则，并让挂起超时调用完成而非取消。
- `DialogPanel.gd` 只表现该权威状态：取消键 disabled，tooltip 为“驿站成员主动交涉不可取消对话。”；守备官发起的普通会话仍走原取消路径。
- `DailyPlanSystem.gd` 在对话完成上下文中核对当前计划项。只有当前 `action_id=seek_guard_officer` 才设置 required 当前小时；第二层仍复用既有动态候选、计划合并与可靠派发 marker。
- 没有新增节点、Autoload、EventBus 信号或 GM 权威入口，也没有改变 `seek_guard_officer` 的问号等待、无人响应或跨日语义。

## T0077 GM 运行成本顶栏职责

`LLMBridge.request_llm_usage_async()` 使用既有原生 HTTP 工作线程读取 `/debug/llm_usage`，以 `call_type=llm_usage` 复用线程回收但不申请 TimeSystem 慢速、不写 NPC 活动状态。完成结果只通过 `llm_usage_response_received` 回到主线程。

`GMPanel` 打开时立即请求一次，之后仅在面板可见且没有在途查询时每 3 秒刷新。顶栏只格式化后端 `provider_usage.session / daily` 的输入、输出、总 token 和人民币值；不在 Godot 侧计算单价、累计费用、预留额度或决定是否放行模型。同步“成本统计”命令保留用于查看完整 debug 快照。

## T0076 对话跨小时与计划派发职责

- `ActionSystem.gd` 继续拥有接近、预约和 pending 对话；新增只读跨小时快照，并让同日旧小时日计划对话免于普通计划项过期。它不决定对话后做什么。
- `DialogSystem.gd` 让自主会话继承日计划来源元数据；结束上下文显式携带 `autonomous / speaker_npc_id / target_npc_id`，供 DailyPlanSystem 只对实际发起者设置必选当前小时。会话仍独占邀请 / 正式对话与高优先级中断。
- `DailyPlanSystem.gd` 在 `hour_started` 重建对话延续 marker，普通整点不再全局调用 `end_autonomous_dialogue_for_hour_change()`；它独占 `required_revision_hours` 的发起者判定、双人组屏障及当前小时直接 / deferred 派发。跨日仍不重建 marker。
- `LLMBridge.gd` 只把 required 小时和正常动态候选投影到后端；没有新增行动表、节点、Autoload 或 EventBus 信号。
- `GMPanel.gd` 以只读 `dialogue_carryover` 替换旧 `expire_plan_dialogues`，显示 DailyPlanSystem 汇总的 pending / active / deferred 状态，不结束对话、不修改计划。

## T0075 行动完成策略职责

- `data/action_defs.json` 为全部 25 个配置行为保存必填 `completion_policy`；行为定义继续是单一数据源，不在 DailyPlanSystem 维护第二份可重复 action id 表。
- `ActionSystem.gd` 校验策略枚举与 `plan_selectable` 一致性，并公开只读策略 / 配置错误查询；它仍独占移动、工位、资源、周期、制造阶段和事件结算。
- `DailyPlanSystem.gd` 独占计划小时语义：整点采用相同 action / 必要 target 的既有运行态，不同项调用现有中断；成功完成 `repeat_while_planned` 后 deferred 续开；`once_per_plan_hour` 使用不依赖 `plan_version` 的逻辑项消费记录。
- `TimeSystem.gd`、`CraftingSystem.gd`、`BuildingSystem.gd`、`MemorySystem.gd` 无新增职责。时间只发 tick / hour 信号，制造与建筑继续权威结算，事件继续由原行动路径写入。
- 新增 `verify_plan_action_completion_policy.gd` 并更新三个既有计划回归，覆盖 25 项分类、生产续开、事件顺序、同 / 异行动跨小时、单次行为重算及玩家对话恢复。没有新增节点、Autoload、信号或 GM 控件。

## T0074 制造目标提醒职责

- `Main.tscn` 在 `UI` 下新增轻量 `CraftingTargetAlerts` 表现节点；它先于对象面板绘制，因此 NPC / 建筑面板仍覆盖世界提醒。
- `CraftingTargetAlertPresenter.gd` 只读取 `CraftingSystem.get_project_snapshot(...)` 并监听 `project_changed`，把铁匠铺 / 工械坊名称的 3D 世界位置投影为屏幕坐标，维护红色按钮、边缘夹取、tooltip 与可见性。
- `BuildingSystem.select_building(...)` 是世界建筑与提醒按钮共用的正式选择入口，继续通过 `EventBus.building_clicked` 打开 `BuildingPanel`；原 `debug_select_building(...)` 委托它，不创建第二套面板入口。
- 提醒不写制造目标、阶段、资源或建筑状态；`CraftingSystem` 仍是项目权威，`BuildingPanel` 仍是目标选择入口。功能直接可见，不新增 Autoload、信号或 GM 控件。

## T0073 指令 UI 与验收职责

- `Main.tscn` 只移除 `OrderTextEdit` 的默认 placeholder，不新增或移动节点。
- `OrderPanel.gd` 负责动态标题“给 {NPC} 的指令”和默认世界内说明；发布、关闭、对话互斥及状态反馈继续复用既有流程。
- `NPCSystem.gd`、`DailyPlanSystem.gd` 与 `LLMBridge.gd` 的权威职责未改；新增工具分别验证 UI 合同、确定性计划合并和真实 provider 计划影响。
- 功能可直接在 `Main.tscn` 验证；后端状态继续使用既有 GM 当前指令、最近注入和计划查询，不新增节点、Autoload、信号或 GM 入口。

## T0071 对话私有上下文隔离职责

- `LLMBridge.gd` 只为回复者构造完整人物 / 记忆上下文；NPC 说话者不再生成 `speaker_npc`，`speaker_context` 只保留姓名、外表、健康和空 `state`。
- `DialogSystem.gd` 继续只负责会话轮次、说话文本、历史和权威生命周期；本任务不修改对话事件、计划判别、行动打断或广播规则。
- `MemorySystem.gd` 继续保存各 NPC 独立事件库 / 见闻库；修复不复制、移动或删除任何人的记忆，只改变 LLMBridge 的跨人物投影。
- `LLMBridge.gd` 的 `talk_to_npc` 候选不再附带目标实时地点、行动或入伍状态；`ActionSystem.gd` 继续在执行阶段权威读取目标当前位置并最多追踪一次，不依赖计划候选中的旧地点。
- 新增 `verify_dialogue_private_context_boundary.gd`，用只属于格伦的私有铁盔批次标记审计六类伊沃 payload。没有新增节点、Autoload、信号或 GM 权威接口。

## T0070 名册、知识与仓库 UI 职责

- `LLMBridge.gd` 从 NPCSystem 的全体运行态实体生成名册，并分别投影 `recruited / in_station`；不新增系统节点或静态人员表。
- `NPCSystem.gd` 继续装载数据驱动知识图谱。新增职业细节和仓库容量认知仅修改种子数据，不在脚本里写死人设。
- `ResourceSystem.gd` 是六项仓库容量及原子入库的唯一事实源；`ActionSystem.gd` 和 `MerchantSystem.gd` 只在结算边界调用容量接口。
- `BuildingPanel.gd` 动态创建仓库上限行，`HUD.gd` 为既有资源标签设置上限 tooltip；两者只读 ResourceSystem。没有新增 `.tscn` 节点、Autoload、信号或 GM 入口。
- `verify_dynamic_station_context.gd`、`verify_npc_initial_long_memory.gd` 与 `verify_warehouse_capacity_ui.gd` 分别覆盖运行态名册、知识注入和容量 / UI。

## T0067 战斗心理与逃离修复职责

- `LLMBridge.gd` 继续构建唯一正式 payload，不新增系统节点；本轮只验证五个战斗 / 逃离状态字段能完整到达后端。
- `CombatSystem.gd` 负责低血量请求关联、应用前复验、战时 / 低血量意向转为士气或逃离，以及复苏后的模式分流。它不再自行先写逃离模式再尝试移动。
- `NPCSystem.gd` 新增内部原子接口，把行为模式提交和世界移动放在同一成功边界；原有 `set_npc_behavior_mode(...)` 仍是一般模式入口。
- `DialogSystem.gd` 负责上下文防御、避战战时结果拒绝和会话结束重入保护；T0072 后合法应征接受在回复进入历史时立即交给 NPCSystem 应用，战时反应与挽留结果仍只在完成会话时应用。
- `DailyPlanSystem.gd` 未改变权威职责：`escaping_station` 不是普通 ActionSystem 行动，只能转交 CombatSystem。真实高压计划未选择该候选属于 Prompt / 上下文质量，不通过 GDScript 强制概率。
- 本轮没有新增 `.tscn` 节点、Autoload、信号或 GM 按钮。现有 GM 逃离、战斗快照、计划和 LLM usage 入口已足够观察，新增验证通过独立工具脚本完成。

## T0066 公告牌与计划详情 UI 职责

- `NoticeBoardPanel.gd` 仍只管理两页本地草稿、配置化建议备注和发布调用；T0066 只收敛玩家文案与默认状态标签，不改变 MemorySystem 权威状态、校验或 T0065 广播范围。
- `data/notice_board_defaults.json` 是 `schedule_advisory_note` 的唯一默认文本源。UI 与 MemorySystem 事件摘要读取同一字段，不在 UI 另写一份黄色备注。
- `NPCPanel.gd` 从 DailyPlanSystem 读取完整计划，从 GameState 读取当前小时，只在“当前计划”详情首次打开后计算首个可见行动。它不修改计划次序或执行状态；详情刷新、事件 / 见闻到底部和其他模式仍复用既有滚动生命周期。
- 本任务没有新增场景节点、系统节点、信号、GM 入口、LLM 请求或后端接口；`verify_notice_board_tabs.gd` 与 `verify_npc_panel_state.gd` 负责端到端 UI 和边界回归。

## T0063 赠酒与饮酒节点职责

- `NPCPanel.gd` / `Main.tscn` 只展示个人酒、采集赠酒数量并调用 NPCSystem；不会直接修改 ResourceSystem 或 NPC state。
- `NPCSystem.gd` 负责驿站酒到个人酒的原子转移、个人资源查询与扣减，并在成功后刷新 NPC / 发信号；`states.money / wine` 均在加载时规范为非负整数。
- `ActionSystem.gd` 从 `action_defs.json` 读取 `drink_wine`，开始时再次校验并消费个人酒，保存活动状态并写 `wine_consumed`；DailyPlanSystem 只观察标准失败状态并复用资源不足重估。
- `MemorySystem.gd` 保存 `wine_given / wine_consumed` 并执行既有 private / local_public 广播；“心情改善 / 伤痛暂时淡化”是事件语境，不是新的数值系统。
- `LLMBridge.gd` 继续作为六类 payload 的唯一行动目录 / NPC 状态投影点；没有新增场景系统节点。GM 通用行动下拉自动读取新 action，无需新增专用调试节点。

## T0061 人设构造与知识弹窗职责

- `data/npc_profiles.json`、`NPCPromptProfile.FIELD_DEFINITIONS / build_setting(...)` 和 `LLMBridge._build_npc_context(...)` 已移除 `signature_lines`。对话 `npc_setting`、共享 `NPCIdentity` 与 NPCPanel【背景】继续共用同一档案来源；T0100 后另含精简 `religion`，语言倾向仍只读取宽松 `speech_style`，没有第二套 UI 或 Prompt 档案。
- `NPCSystem.gd` 仍完整装载三篇 8 字段历史日记和 `key_value_replace_v1` 图谱。前两篇的新叙事层级、固定到站顺序、守备官唯一职责关系及建筑叙事化 `value_label` 都是数据内容合同，不在 GDScript 写死。
- `NPCPanel._format_knowledge_graph_block(...)` 只把 `subject_label / relation_label / value_label` 组装成玩家可读文本，不再追加 `confidence / day / time`。该过滤只作用于【知识】弹窗；NPCSystem 运行态、DailyReflectionSystem 替换更新、LLMBridge 请求和 GM 原始调试继续保留完整记录。
- 本任务没有新增场景节点、Autoload、endpoint、`call_type`、调用频率或权威结算。现有 Main 前端可通过 NPCPanel 的【日记】【知识】【背景】直接验收，无需新增 GM 入口。

## T0060 文案与投影层职责

- `NPCSystem.gd` 继续保存完整 8 字段日记并装载 8 人档案 / 初始图谱；本任务没有改变实体、状态或记忆应用逻辑。
- `LLMBridge._build_existing_diary_entries(...)` 仍是日记文本的唯一投影点：开局种子为“往昔·…：正文”，新熟睡总结优先使用 `record_label` 投影为“接到守备命令的第N天 HH:MM:SS：正文”，无标签的旧运行态记录仍兼容“第N天 HH:MM:SS”，旧纯字符串及缺元数据记录也继续可读。
- 六份 Prompt 负责解释前缀先后、“往昔·近日”处于敌情传达前，以及首次睡眠反思只输出正文；Prompt 不生成权威日期、时间或事件。
- 本任务没有新增场景节点、Autoload、后端 Schema、endpoint、`call_type` 或权威结算系统。T0061 已取代其中“开放的守备官认识”和固定台词样例口径：当前为唯一职责知识与宽松 `speech_style`。

## T0059 初始长期记忆运行时职责

- `NPCSystem.gd` 同时读取 `npc_profiles.json` 与 `npc_initial_long_memory.json`；在创建任何 NPC 实体前验证 id 集合和最小结构，再把日记 / 图谱深拷贝到 profile 运行态。它不在 GDScript 写死人设或建筑认识。
- `LLMBridge.gd` 只投影已加载的运行态记忆：对话使用顶层 `long_memory`，其余共享 NPCContext 使用 `long_term_memory`。`target_npc` 不重复长期记忆；T0071 后说话者不再生成 `speaker_npc`，短期与长期私有上下文均不进入回复者请求。
- `DailyReflectionSystem.gd` 沿用现有“追加日记 + 替换知识键”应用路径；初始记录只改变基线条数，不新增反思触发或模型调用。
- `NPCPanel.gd` 与 `GMPanel.gd` 不新增事实源：主场景“日记 / 知识”弹窗和既有 `long_memory <npc_id>` 命令从开局即可读取种子；T0061 后 NPCPanel 隐藏知识可信度 / 更新时间，GM 仍可观察完整原始记录，两者都不自行写记忆。
- 本任务不新增场景节点、Autoload 或权威结算系统。专项 `verify_npc_initial_long_memory.gd` 负责 8 人装载、15 建筑 / 7 人 / 守备官覆盖、中文 UI 和六类 payload；既有反思 / GM 测试改用“初始条数 + 新增条数”断言。

## T0058 公开资源投影与升级行动提示职责

- `LLMBridge.gd` 每次构造 `station_context` 时只从 ResourceSystem 投影 `grain / meal / wood / stone / iron`，同时让计划类兼容字段 `current_resource_states` 使用同一白名单；不得传递全量库存快照。
- `data/station_context.json` 保存第六条升级常识；它不保存当前资源数、升级目标或进度。当前资源来自 ResourceSystem，当前可协助目标来自 `_build_allowed_action_candidates(...)` 对 BuildingSystem 活动作业的查询。
- `assist_upgrade` 在技术合同中保持英文 `action_id / action_kind`，`data/action_defs.json` 和候选 `name` 提供中文玩家 / 模型可读名称。BuildingSystem / ActionSystem 继续拥有倒计时与加速权威。
- `GMPanel.gd` 的既有 `station_context` 入口增加公开基础资源一行，只读同一 LLMBridge 快照，不缓存或编辑资源。

## T0057 升级封闭的行动生命周期职责（pending 时序由 T0080 修正）

- `BuildingSystem.gd` 仍只负责升级作业、资源预付、封闭状态和 `building_state_changed`；它不直接写 NPC 行动失败或调用计划系统。
- `ActionSystem.gd` 在建筑变为不可访问时立即处理中目标建筑的 active 行动；对应 pending 行动继续移动，直到 NPCSystem 在入口拒绝进入后才写唯一最终 `*_failed_building_upgrading`。上下文记录行动、建筑、阶段、升级原因、到达检查和中文摘要；单纯停留 / 普通访问只做清退，不伪造行动失败。
- `DailyPlanSystem.gd` 把 `building_upgrading / building_unavailable` 规范为现有 Schema 支持的 `target_unavailable`，并沿用 T0050 的行动失败判别与按需精确修订；不新增第二套升级专用重估。
- `tools/verify_building_upgrade_action_failure.gd` 使用可控 fake provider 覆盖路上 pending 与进行中 active 两条链路，并证明非空判别继续进入第二层修订。

## T0054 驿站常识运行时职责

- `LLMBridge.gd` 是 `station_context` 的唯一运行时组装者：读取 `data/station_context.json` 的简介 / 规则，从 NPCSystem 构造全体登记人员及当前标签，从 BuildingSystem 构造全部建筑，从 ActionSystem 构造工作模式行为类型。
- 建筑目录描述配置中的建筑身份，不随 HP 删除；当前可用性由各业务 payload 的建筑状态和 BuildingSystem 校验决定。广场 / 公告牌没有 BuildingSystem 定义，因此不会进入目录。
- 行为目录只收录 `plan_selectable=true` 的 ActionSystem 定义并补入系统特殊 `escaping_station`；`talk_to_guard_officer`、`escape_intervention_dialogue` 等纯运行态入口不进入。动态目标、位置、资格和资源约束继续由 `_build_allowed_action_candidates(...)` 生成。
- `debug_build_station_context()` 只返回同一组装结果。GMPanel 的按钮 / 命令只格式化显示，不缓存、不编辑、不修改 NPC、建筑、行动或战斗状态。

## T0053 对话来源与失效职责（普通跨小时由 T0076 覆盖）

- `DailyPlanSystem._assign_plan_item(...)` 是日计划对话来源元数据的唯一写入者，将日 / 小时 / 版本 / 原计划项传给 `ActionSystem.assign_npc_dialogue(...)`；GM 和其他调用者保持无来源元数据。
- `ActionSystem` 在逻辑 tick、计划结束后的邀请重试和 `DailyPlanSystem._on_hour_started(...)` 新行动派发前校验 pending 对话。T0076 起，同一天从旧小时延续的日计划对话不再因为当前小时计划不同而失效；同小时计划项被替代、跨日或目标 / 行为模式权威失效时，仍负责停止接近、释放双方 reservation 并写完整结构化失败，不直接调用 LLM。
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

- `LLMBridge.gd` 从 NPCSystem 当前运行态构建唯一顶层 `station_context`；T0054 已由同一构造器补齐建筑、工作行为与规则，T0070 后 NPC 逃离 / 离站仍保留在名册中并标记 `in_station=false`。
- `DailyReflectionSystem.gd` / `NPCSystem.gd` 只应用第一人称日记与替换式知识图谱；`NPCPanel.gd` 负责把知识主体、关系和值的技术内容显示为中文，不改写底层技术值，并在 T0061 后不向玩家显示 `confidence / day / time`。
- `MemorySystem.gd` 负责公告牌默认数据、广场当前通告 / 参考日程、时段校验、初始 NPC 见闻和入场快照。T0065 起，公告牌两类发布事件按类型向全站当前可接收见闻的 NPC 各广播一次，普通公开事件仍按地点在场范围广播；广场入场见闻快照剔除公告牌三项，避免重复。`NoticeBoardPanel.gd` 只负责双 Tab 草稿、日程行交互与发布调用。

## T0045 BuildingPanel 测量与 CameraRig 输入生命周期

- BuildingPanel 不使用状态切换当帧可能过期的 `combined_minimum_size` 撑高面板。它按 building id 保留上一次稳定高度，在有上限的逐帧容器排版采样后再写入新高度；新目标测量期保持在布局树中但透明且递归禁用鼠标，避免隐藏 Control 无法排版及透明控件拦截世界点击的问题。
- CameraRig 在 `_input(...)` 内维护本窗口 WASD 状态，`_process(...)` 只消费这份状态，不调用 `Input.is_key_pressed(...)`。按键 release、文本输入焦点、`NOTIFICATION_APPLICATION_FOCUS_OUT` 和 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 会清空平移；失焦同时清除中键拖拽。

## T0044 当前计划恢复与对象面板布局边界

- `DialogSystem` 在玩家消息真正打断行动时保存该运行时行动 ID，只在有效玩家对话、未重估且无攻击的结束分支调用 `DailyPlanSystem.resume_current_plan_after_player_dialogue(...)`；NPC 原本空闲时不调用。
- `DailyPlanSystem` 的专用恢复入口先要求被打断行动 ID 与当前小时计划行动一致，再仅移除目标 NPC 当前计划阶段的执行签名 / 计划行动标记，并调用既有 `execute_current_plan_for_npc(...)`；正常小时派发仍使用原签名去重。
- `NPCPanel` 改变宽度后保留当前合理高度，待容器完成换行布局再收敛到自然高度。BuildingPanel 的同建筑刷新保留该建筑已测得高度，新目标则透明排版后显示；两者都不在等待帧内暴露最大高度空面板。BuildingPanel 的操作提示作为 `Main/UI` 下的覆盖控件，不参与建筑面板最小尺寸计算。

## T0043A ActionSystem 服务依赖路由

`ActionSystem` 现在把 `work_clinic_doctor → receive_clinic_treatment`、`work_training_instructor → receive_weapon_training` 作为配置驱动的服务依赖。服务者在移动时，依赖者保持 pending；服务者有效占位后重试依赖者。服务者停止时统一扫描活动中和等待中的依赖者，写失败、释放位置、记录事件并交给 DailyPlanSystem 重评估。

T0098 后 `lead_mass` 不再中断 `pray_at_chapel`，也不形成服务依赖。ActionSystem 在祈祷 active 数据中保存内部模式与当前主持者绑定；主持正常完成、异常离岗或替换主持者接管时原地转换 / 重绑定。`get_runtime_action_snapshot()` 暴露该模式，供 GM / 调试读取；BuildingSystem 仍只管理位置与建筑状态，不承接行为规则。

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

## Godot MCP 本机连接拓扑

当前本机链路为“每个 Codex 会话一个 stdio proxy → 唯一 `127.0.0.1:8765` broker → Godot 编辑器插件 `127.0.0.1:6550`”。多个 proxy 是正常状态；只有 broker 和 broker→Godot 连接必须保持单例。

`C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs` 优先使用 broker lock 指向的 Godot MCP 安装及全局 `@satelliteoflove/godot-mcp` 包内 `@modelcontextprotocol/sdk`，全局独立 SDK 与 npx 缓存仅作回退。不得重新把 `npm-cache\_npx` 作为唯一 SDK 来源，因为 npm 清理缓存后新会话 proxy 会在注册工具前直接退出。

编辑器已经监听 6550 时，这是插件正常工作的前提，不是应清理的冲突。项目 smoke 使用 `godot --headless --path . --quit-after 1`；不要在已打开编辑器时再启动第二个 `--editor` 实例。按顺序运行 `tools/check_godot_mcp.ps1` 与 `node tools/verify_godot_mcp_topology.mjs` 可区分插件监听、broker、fresh proxy 和多会话隔离问题。已经关闭的 Codex stdio transport 不能在原会话热恢复，修复脚本后需刷新或新开该会话。

T0102 已将 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 绑定到 Main 场景的 `Systems` 节点下；T0035/T0037 新增 `CraftingSystem.gd` 与 `HorseSystem.gd`，并按 `BuildingSystem -> CraftingSystem -> NPCSystem -> HorseSystem -> ActionSystem` 顺序绑定，使项目、NPC 和养马周期依赖初始化明确；T0604 新增 `LLMBridge.gd` 并绑定到 `Main/Systems/LLMBridge`，T0604A 已将其传输层替换为 Godot 原生 `HTTPClient`；T0901 新增 `EquipmentSystem.gd` 并绑定到 `Main/Systems/EquipmentSystem`；T1004 新增 `DailyReflectionSystem.gd` 并绑定到 `Main/Systems/DailyReflectionSystem`；T1507 新增 `MerchantSystem.gd` 并绑定到 `Main/Systems/MerchantSystem`；T1508 新增 `DefenseDeviceSystem.gd` 并绑定到 `Main/Systems/DefenseDeviceSystem`。T0401 已实现 `TimeSystem.gd` 的基础时间推进、秒级显示、暂停、加速、跨天、逻辑时间倍率、LLM 等待减速请求，以及 `time_changed` / `time_scale_changed` / `logical_time_tick` / `hour_started` / `day_started` 信号；T1104A 新增 TimeSystem 时间倍率上限请求，CombatSystem 可在敌人在场时注册 `combat_enemy_presence` 上限；T1406 后 `get_time_scale_snapshot()` 还会暴露 `last_time_scale_reason`。T0020 后，`LLMBridge` 会在对话、常规每日计划、计划修订、低血量心理判定和首次睡眠总结请求前按 payload 注册慢速，并在成功、失败、取消或超时后释放；正式开局的每日计划批次由 `GameStartupSystem` 直接暂停全局时间，8 份真实计划全部成功后才统一执行当前项并恢复时间；任一失败保持暂停且不生成 Mock / 规则计划，不为单个请求重复登记慢速。`debug_get_llm_runtime_snapshot()` 供 GM 查看当前等待中的 LLM 请求数、pending request id、NPC 活动请求、异步请求数量、有效逻辑倍率、最近倍率变化原因和逐请求慢速注册 / 释放审计。LLMBridge 只请求后端业务接口或开发期 mock 接口，不保存供应商 API Key；生产 / 演示路径真实 provider 失败或预算超限时应返回错误或规则 / 模板降级，不得让 Godot 收到 mock 内容伪装成功。T0202 已实现 `ResourceSystem.gd` 的基础资源读写和 HUD 同步；T0205 已实现 `BuildingSystem.gd` 的配置读取、低模建筑绑定、运行时点击区、`building_clicked` 选择事件、`building_state_changed` 状态刷新事件，以及倒计时修复/升级逻辑；T1506 后主厅公告牌可点击编辑当前广场公告并写入公开信息；T1507 后商队会在后门按日程出现，提供基础资源购买、酒类出售和结构化公开事件。T0304/T0409 已实现 `NPCSystem.gd` 从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体、发出 `npc_clicked`、读取/更新 NPC 基础状态、调试移动到建筑入口，并在到达后发出 `npc_state_changed`；室内信息地点切换到另一个室内信息地点时，事件和地点信息层会插入广场中转链。T0501/T0502/T0503 已实现 NPC HP 扣除、`npc_hp_changed`、`npc_unconscious`、昏迷阻断移动/行动、昏迷自然恢复、协助治疗、`npc_revived`、自动复苏和昏迷/治疗/复苏事件写入。T0808 已实现小诊所医生工位、病床治疗、研读医术和诊所等级治疗效率。T0901/T0036/T0038 已实现 `EquipmentSystem` 从装备定义读取主武器、盔甲和具体马匹投影，只消耗 / 返还同名具体成品库存；T0902 已独立验收只读兵种判定与 `get_unit_type_snapshot(...)`，坐骑判定只读取 `equipment.mount` 槽；T0903 已实现训练场教官工位、受训位、当前装备决定训练项、教官/受训者熟练度成长和训练状态消耗；T0904 已实现 `NPCSystem` 统一成长结构、经验达标获得未分配技能点，以及玩家分配技能点到力量 / 智力。T0402 已将 `MemorySystem.gd` 升级为事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场事件查询；T0403 已在 `MemorySystem.gd` 中实现可进入地点信息节点、`people_present` 维护、进入快照和 `local_public` 即时广播；T0404/T0408/T0409/T0035/T0037 已统一广场即时广播、公告变更广播、建筑可传播外部状态广播、建筑内部特殊状态白名单和对应室内进入快照 / 字段差量，且不会把制造小数进度或马匹个体详情泄露到广场；T0405 已提供 NPC 短期记忆容器查询和玩家非对话交互事件调试写入口，仍不提供按地点查询事件的长期接口，地点/建筑节点不作为事件历史存储。T1004/T1005 起，首次睡眠总结完成后只清空指定 NPC 的当天短期事件/见闻索引，保留全局事件档案。T0407 已提供记忆降噪规则：进入/离开事件只保留行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化只广播变化字段。`ActionSystem.gd` 的工作 / 训练 / 协助修复 / 协助升级 / 协助治疗 / 诊所治疗 / 吃饭 / 睡觉调试行动闭环已写入结构化事件；制造工作还会把完整周期提交为一个阶段，打断只清未完成周期。T1101 已让 `CombatSystem.gd` 读取 `data/enemy_waves.json`，并在 `Station/Enemies` 下生成正门外低模敌人占位；T1102 已让敌人按逻辑时间选择目标、移动并攻击 NPC / 建筑，主厅清零会写入 `GameState` 失败占位；T1103 已让 HUD / GM 警铃触发入伍持武器 NPC 前往城门外集结，按近战前排 / 远程后排排列，写入警铃与集结事件，并在接敌时切换 `combat_ready` 占位；T1103A 已统一 `behavior_mode`，接入集结超时、接敌入战、清敌退出和昏迷复苏分流；T1103B/T1103C 已实现非战斗人员（未入伍或已入伍但无主武器）避战触发、按敌方方位短步长四散移动、清敌退出、避战中应征 / 装备分流和 `avoidance_started` / `avoidance_ended` 事件；T1104 已实现 combat 模式入伍持武器 NPC 的基础自动攻击、属性 / 防御伤害、攻击间隔、敌人 HP 扣除和清零移除；T1104A 已取消战斗数值与玩家时间倍率绑定，并在活动敌人存在时把 TimeSystem 有效倍率上限设为 `x1`；T1104B 已把攻击冷却从游戏秒换算到战斗动作秒，并校准第一波基础节奏；T1104C 已从敌人目标偏好中移除围墙，敌人破城门后直接转向仓库 / 主厅；T1105 已接入不同兵种战斗策略、玩家手动策略选择、策略状态快照和策略移动目标；T1106 已接入战斗开始 / 结束广场公开事件、当前战斗运行态和受伤 / 昏迷 / 击退统计；T1201/T1202 已接入战时公开对话心理结果和低血量自身心理判定；T1203 已接入逃离驿站行为，逃离 NPC 会前往后门外出口，离图后标记 `escaped` 并写入广场公开事件；T1204A 已接入逃离挽留 NPC 面板入口、对话暂停逃离移动、未满 5 轮关闭恢复、满 5 轮按钮置灰、给钱减速、逃离攻击加速且无 NPC 回复、昏迷暂停和复苏继续逃离；T1302/T1303 已接入主厅摧毁和无可战斗人员失败结算，失败后广播 game-over 并暂停 TimeSystem；T1304 已接入第 5 波胜利结算，胜利后广播 game-over、暂停 TimeSystem、保存资源 / 建筑 / NPC 结算快照并阻止继续刷波；T1305 后 `GameState` 会为胜利和失败补齐 NPC 结局明细，HUD 结算页滚动显示每名 NPC 的最终状态、入伍状态、最后位置、Mock 最终看法和 Mock 后续命运。仍不实现命中率。

T0043 在上述系统绑定上补齐统一位置链路：`BuildingSystem` 保存逐位置状态、可用性、受损倍率与逐级升级效果；`NPCSystem` 在移动发起和到达时复验可进入性；`ActionSystem` 为吃饭、睡觉、祈祷 / 弥撒、诊疗和训练自动申请位置，并聚合全部在岗医生 / 教官贡献；`MemorySystem` 传播外部效率分档和室内位置增删 / 占用差量；`BuildingPanel` 逐位置只读显示。升级开始会封闭建筑、释放位置并将室内 NPC 送回广场。

T0022 覆盖上述 T0019 旧口径，也覆盖上一段保留的历史“明确规则降级后完成”表述：正式开局和新一天每日计划只有 8 份真实 `llm_plan_day` 全部成功才会执行并恢复时间。整批默认 8 路并发，单人最多 3 次真实请求；仍失败时保持暂停与 `planning_day`，不生成 Mock / 规则计划。

T0023 覆盖 T1002 的旧 Mock / 规则修订口径：正式计划修订只接受真实 provider，成功响应必须携带非 Mock provider 元数据并写为 `llm_plan_revision`；失败最多 3 次真实请求，保留原计划且不写 `plan_revised`。NPC 面板通过“当前计划”详情读取 DailyPlanSystem 权威计划；事件 / 见闻详情刷新保留当前滚动位置。行动失败是否进入该修订由后续 T0050 的第一层判别决定。

T0024 后，NPCPanel 在事件库上方使用“当前计划 / 日记 / 知识”三等分按钮，共用详情弹窗读取 DailyPlanSystem 计划与 NPCSystem 长期记忆，面板正文不再创建日记滚动框。DailyReflectionSystem 明确限制最多 8 路异步总结并暴露实际峰值；DailyPlanSystem 的正式开局 / `day_started` 批次同样记录实际并发峰值。后端五个正式 LLM 成功端点共用 provider 元数据封装，Godot 睡眠总结根据元数据选择 `llm_daily_reflection` 或显式开发 `mock_daily_reflection`，不再按调用位置硬编码来源。

T0049 覆盖上述“五类正式业务”和 T0048 剩余日重排口径：新增第六类计划修改判别，`LLMBridge` 为其提供 payload、异步请求、慢速注册 / 释放与结果信号。对话结束先返回精确 `revision_hours`，空数组不调用修订；非空数组才让 `DailyPlanSystem` 以 `revision_scope=selected_hours` 请求 `/npc/revise_plan`。事件 / 见闻详情首次打开滚到最底部，打开期间刷新保留当前位置。

T0050 将第六类统一命名为 `plan_revision_judgement`，请求通过 `trigger_kind=dialogue|action_failure` 区分本轮完整对话和程序权威行动失败事实，并统一发送到 `/npc/plan_revision_judgement`。日常行动失败不再默认直接修订当前小时：空判别保持原计划，非空才用原有完整第二层上下文精确修改选中小时；第一层等待和第二层修订都占用既有 NPC 计划屏障。旧 dialogue 命名的端点、Schema 和 LLMBridge 方法只保留兼容包装。

T1501 曾同时注入 `speech_style` 与 `signature_lines`；T0061 已取代该历史口径。`LLMBridge._build_npc_setting(...)` 和共享 `_build_npc_context(...)` 现在从 `data/npc_profiles.json` 读取精简 `religion` 与宽松 `speech_style`，分别注入对话顶层人设和 `NPCContext.identity`。两者只影响人物背景、模型语气与主观文本，不改变 NPC 状态、行动或任何权威结算。

T0042 后，`res://scripts/core/NPCPromptProfile.gd` 集中定义对话顶层 `npc_setting` 的字段集合和构造规则；`LLMBridge._build_npc_setting(...)` 委托该构造器，`NPCPanel` 的人物背景详情也读取同一结果。标题行新增的“背景”按钮只负责打开共用详情弹窗，UI 不保存第二份背景数据，不触发 LLM，也不写 NPC / 记忆权威状态。

T0107 覆盖 T1508 的围墙专属结构。`DefenseDeviceSystem.gd` 绑定到 `Main/Systems/DefenseDeviceSystem`，权威维护围墙 / 主厅通用槽、等级解锁、库存、器械 HP / 防御 / 穿透 / 攻速、宿主射程倍率与自动攻击；围墙 / 主厅均最高 6 级，容量分别为 `1 / 2 / 2 / 3 / 3 / 4` 与 `1 / 1 / 2 / 2 / 3 / 4`。T0112 后 `get_slot(...)` 会把槽位基础倍率与宿主逐级 `defense_device_range_bonus` 合成为实时有效倍率，部署快照、自动攻击和选敌都复用该槽位快照。`DefenseSlotPresenter.gd` 绑定到 `Main/UI/DefenseSlotPresenter`，只投影已解锁空槽的圆形 `+` 并提交部署请求；弹窗每次稳定布局后同时重算宽高，避免自动换行标签的初始高度缓存把面板拉满窗口。`DefenseDevicePresenter.gd` 继续绑定到 `Main/WorldRoot/Station/DefenseDevices`，消费已部署快照并创建 `DefenseDeviceView.tscn`；T0112 起还监听既有 `building_state_changed`，在围墙 / 主厅等级变化后立即用新快照刷新世界射程标签。每个 view 固定包含 `ModelMount`，可选 `presentation.model_scene` 在该挂点下实例化，为正式模型、动画和特效保留稳定替换契约。

## 逻辑时间倍率原则

TimeSystem 不修改 `Engine.time_scale`，也不直接改变 NPC 移动、动画或物理速度。玩家设置的 `x1` / `x2` / `x4` 是逻辑时间倍率；当 LLMBridge、DialogSystem、计划系统或战斗判定等待模型返回时，可以调用 `TimeSystem.request_time_slowdown(request_id, scale, reason)` 注册慢速请求，完成、失败或超时后调用 `release_time_slowdown(request_id)`。

当前默认 LLM 等待倍率为 `1/60`，即在默认 `x1` 速度下从“现实 1 秒 = 游戏 1 分钟”减缓为“现实 1 秒 = 游戏 1 秒”。多个慢速请求同时存在时，TimeSystem 使用最慢的有效倍率。T0183 起，CombatSystem 在活动敌人存在时也注册 `combat_enemy_presence = 1/60` 慢速；NPC 移动 / LLM 等待使用相同倍率，不会继续叠慢，最后一名敌人消失后恢复玩家已选倍率。工作 / 日常状态、资源、计划打点、治疗和建筑倒计时系统读取 `get_numeric_delta_multiplier()`、`get_game_delta_seconds(real_delta)` 或 `logical_time_tick`，而不是 Godot 全局时间缩放。CombatSystem、DefenseDeviceSystem 和 PietySystem 直接把战时游戏秒作为攻击、移动、塔防和持续效果秒；攻击动画按现实帧播放并用权威 elapsed/cycle 校准，因此不再使用 `game_delta_seconds / 60` 的第二套动作秒换算。

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
│  ├─ DefenseSlotPresenter
│  ├─ NoticeBoardPanel
│  ├─ MerchantPanel
│  ├─ GMPanel
│  └─ DialogPanel
├─ CameraRig
│  └─ Camera3D
└─ SunLight
```

T0103 已在 `Main.tscn` 直接放置低模驿站 Blockout：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊，以及主厅前公告牌均使用简单几何体和 `Label3D` 调试标签表示。2026-05-19 已扩大地面、围墙和相机视野，并拉开建筑间距，避免建筑过小过密；围墙四角已闭合，公告牌已缩小并移动到主厅正面。2026-06-12 为 T1101 扩大正门外地面与 `Props/FrontRoad`，使敌人可生成在正门外森林方向。T1506 后公告牌拥有独立点击区和当前公告预览，但仍不绑定 `data/building_defs.json`，不拥有 HP、等级、工作位、修复或升级；公告文本归广场状态保存。T1507 后后门商人入口标签只在配置到访时段显示并可点击交易。T0107 后 `Station/DefenseDevices` 由独立 presenter 生成围墙 / 主厅已部署低模器械，`UI/DefenseSlotPresenter` 负责已解锁空槽圆形 `+` 与部署卡；T0112 起锁定槽不创建可见等级标记，卡片尺寸在窗口变化时按稳定内容重新收束。两个表现层都不拥有库存、HP、射程或伤害权威。

T0104 已在 `Main/UI/HUD` 下补齐基础 HUD：标题、天数、`HH:MM:SS` 时间/阶段、资源栏、速度按钮、暂停按钮、警铃按钮和后端状态。`Main/UI` 绑定 `res://scripts/ui/UIInputFocusManager.gd`，统一处理文本输入框点击外部失焦；`Main/UI/HUD` 绑定 `res://scripts/ui/HUD.gd`，负责显示和从 `GameState` 读取当前时间；T0401 后会监听 `EventBus.time_changed` / `hour_started` / `day_started`，并通过 `SpeedButton` 调用 `TimeSystem.cycle_speed()` 在 `x1`、`x2`、`x4` 间循环，通过 `PauseButton` 或空格调用 `TimeSystem.toggle_paused()`。T0012 后，HUD 会监听 `EventBus.resource_changed`，按 `ResourceSystem.get_resource_ids()` / `data/resource_defs.json.ui_order` 动态显示非聚合资源，并提供装备/器械详情按钮；详情面板贴近各自按钮左下并保持在屏幕内，只读取 `ResourceSystem`、`EquipmentSystem` 和 `NPCSystem`。T1301 后 HUD 显示波次倒计时；T1302-T1305 后 HUD 复用 `GameOverPanel` 显示失败或胜利结算，胜利读取 `GameState.settlement_snapshot` 展示剩余资源、建筑和 NPC 状态摘要，胜利和失败都会在滚动详情区展示 NPC 结局总结。T0604 后，HUD 读取 `Main/Systems/LLMBridge` 的后端状态，并监听 `backend_status_changed` 刷新 health check 结果。T1103 后，警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")`，不在 HUD 内自行决定 NPC 集结或战斗事实。T0205 已将 `Main/UI/BuildingPanel` 绑定 `res://scripts/ui/BuildingPanel.gd`：监听 `EventBus.building_clicked` 打开被点击建筑，监听 `EventBus.building_state_changed` 刷新当前可见建筑，从 `BuildingSystem` 读取名称、等级、HP、建筑状态、精确运作效率及按配置顺序排列的逐位置名称 / 空闲 / 占用者，并通过按钮触发 `BuildingSystem` 的修复/升级接口；不显示“主动工位 / 被动工位”或按类型聚合摘要。修复/升级消耗和条件只在按钮悬停提示框中显示，进行中会显示倒计时进度、剩余时间、速度倍率和协助人数。T0110 后升级提示通过 BuildingSystem 读取下一目标等级已解析的逐级成本、工期与奖励，并显示该级是否扩展工程器械槽；T0112 后同一路径显示围墙非扩槽等级的器械射程增量。T0107 后围墙 / 主厅面板显示当前建筑的弩床 / 箭塔库存、已解锁空槽和部署清单；世界槽位 `+` 是直接入口，所有入口都只调用 DefenseDeviceSystem。

T0604 已新增 `res://scripts/systems/LLMBridge.gd`，并以 Godot 原生 `HTTPClient` 状态机支持后端地址、健康检查和 NPC AI 业务请求。T0049/T0050 后六类正式业务均有异步路径、request id、取消、NPC LLM 活动和 TimeSystem 慢速审计；`request_timeout_seconds=2` 只保护建立本地后端连接及 health / usage 等短请求，业务生成由后端流式连接 / 空闲超时控制。对话 payload 继续收集目标 NPC 设定、权威状态、记忆、地点、说话者、轮次和战时上下文；T0053 起 `build_plan_revision_judgement_payload(...)` / `request_plan_revision_judgement_async(...)` 按 `trigger_kind` 把对话或行动失败事实、判别基线原计划以及共享 NPC 人设 / 状态 / 长短期记忆 / 指令 / 驿站 / 现实条件送往 `/npc/plan_revision_judgement`。计划修订和战时心理 payload 使用同一 NPCContext，修订仍采用 `revision_scope=selected_hours` 与精确 `revision_hours`。该桥只返回后端 JSON 或错误字典，不写入权威事件或状态，也不直连真实 LLM 供应商。

T0701/T0702/T0049 后，`res://scripts/systems/DialogSystem.gd` 是 Godot 侧对话、征召结果和对话后计划判别编排入口，`res://scripts/ui/DialogPanel.gd` 只负责交互呈现。DialogSystem 维护参与者、历史、公开性、轮次和一次性应征标记，将实际对话写入 MemorySystem；玩家-NPC 有效会话结束后自动为目标 NPC 判别，NPC-NPC 邀请拒绝或正式会话结束后为双方分别判别。`revision_hours=[]` 时不请求修订，并仅在原动作确被本次对话打断、仍匹配计划且行为模式允许时恢复；非空时把精确小时交给 DailyPlanSystem。DialogPanel 已移除“结束后重估计划”开关；空窗口或未完成普通回复不触发判别。对话内攻击一旦提交就是有效事实，即使攻击回复取消或逃离攻击不产生 NPC 回复，也保留攻击轮并进入同一判别。NPC-NPC 仍先邀请、接受后才打断双方普通行动并释放工位，正式会话无硬轮次上限；旁听关闭不结束会话。行为模式强制结束、战时公开对话和逃离挽留继续沿用既有权威边界。

T0703 已把 NPCPanel 的已入伍占位按钮替换为独立 `OrderPanel` 自然语言指令面板；NPCSystem 权威保存 `current_order`，MemorySystem 写入 `private` `order_assigned`，并通过 `EventBus.npc_plan_reevaluation_requested` 发出统一重估请求。UI 不直接启动具体行动，也不决定 NPC 是否服从。T0049 后，指令变化属于非对话触发，直接以 `revision_hours=[current_hour]` 请求真实修订；所有修订使用 `selected_hours`，不再完整覆盖剩余日。正式每日计划与修订只应用经 provider 证明的真实结果，失败最多重试 3 次并保留原计划，不生成 Mock / 规则修订。主动找守备官交涉被玩家实际响应后走对话判别；未被点击而超时则作为非对话状态变化只修订当前小时。

T1001/T0022/T0025/T0049/T0050 后，`res://scripts/systems/DailyPlanSystem.gd` 同时承担显式规则调试计划、正式真实 LLM 每日计划、对话 / 日常行动失败判别后的精确阶段修订与其他直接受限修订。正式每日计划批次默认 8 路并发，8 人全部成功才恢复时间并执行当前项；单人最多 3 次真实请求，失败不调用 Mock 或规则降级。当前项按教官、其他非对话、受训者、对话顺序派发，普通派发以同一计划版本 / 时段签名幂等；T0075 后生产成功完成可按配置受控续开，每小时单次行为另以不依赖计划版本的逻辑项记录防止重放。判别空集合时不启动第二层；非空修订链路校验响应小时集合与 `revision_hours` 完全一致，仅合并所选小时，未选小时保持原值。请求日 / 小时 / 计划版本 / 对话 epoch、单后继队列和连续迟到落地失败上限共同拒绝过期覆盖与无限重修；`avoid_combat` 等非工作模式可先应用计划而延迟执行当前项。

T0019/T0022 后，`res://scripts/systems/GameStartupSystem.gd` 挂载到 `Main/Systems/GameStartupSystem`并导出三状态 `startup_mode`。静止调试模式暂停 `TimeSystem` 并关闭计划自动执行；两个正式模式会先暂停时间，让 8 名 NPC 写入 `wake_up`、清空旧计划并进入 `planning_day`，再以 8 路并发请求真实每日计划。系统只在 8 份 `llm_plan_day` 全部成功时打开自动执行、统一执行第 1 天 06:00 项并恢复时间；任一失败时保持暂停，不接受 Mock 或规则计划。新手引导模式当前只记录 `placeholder_not_implemented`；Headless 环境不自动应用启动模式。

T1004/T1005/T1405 已新增 `res://scripts/systems/DailyReflectionSystem.gd` 并挂载到 `Main/Systems/DailyReflectionSystem`。它监听 `EventBus.event_recorded` 中的 `sleep_started` / `sleep_ended` 和 `logical_time_tick`；T0094 后按 21:00 锚定窗口累计同窗多段睡眠，满 1 游戏小时后调用 `LLMBridge.request_npc_daily_reflection_async(...)` 请求 `/npc/daily_reflection`，成功应用才把窗口去重完成。T0095 将触发窗口、内容水位与日记归属拆开：请求携带 `summary_window / reflection_period` 和原子短期记忆快照，成功结果通过 `NPCSystem.apply_daily_reflection(...)` 追加带“接到守备命令的第N天”标签的日记，并按 `subject + relation` 替换知识图谱当前值；随后 `MemorySystem.clear_npc_short_term_memory_snapshot(...)` 只轮转本次快照 ID，请求在飞期间新增的记忆继续保留。后端失败或输出无效时使用本地模板并保留模型失败日志；该请求会申请 TimeSystem 慢速，且从发起到应用完成期间通过 NPCSystem 的熟睡总结锁阻止对话、发消息、行动中断和行动改派。生产 / 演示路径不得用 mock 日记伪装真实模型成功。

T0105 已将 `res://scripts/camera/CameraRig.gd` 绑定到 `Main/CameraRig`：玩家可用 WASD 平移、鼠标中键拖拽平移、滚轮缩放；脚本只移动 `CameraRig` 的 X/Z 位置和 `Camera3D` 的本地距离，保留高机位俯视角，并通过导出参数限制移动边界和缩放距离。T0045 后 WASD 改为事件式按键状态，按键释放、文本输入聚焦和窗口失焦都会停止平移，失焦也会取消中键拖拽；T0045A/T0045B 后基础速度为 `28 m/s`，Shift+WASD 以 `56 m/s` 平移。T1101 后 Z 轴正向边界扩到可观察正门外敌人生成区。该阶段不实现角色控制或自由第一人称视角。

T0202 已在 `res://scripts/systems/ResourceSystem.gd` 中实现基础资源系统：启动时读取 `data/resource_defs.json` 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁，提供 `get_resource`、`get_resource_definition`、`get_resource_ids`、`add_resource`、`can_afford`、`spend_resources` 与临时调试接口。所有资源变化通过 `EventBus.resource_changed` 通知 UI；资源不足时 `spend_resources` 返回 `false`，不扣除也不产生负数。T0012 后 HUD 主栏直接显示非聚合资源，武器、盔甲、马匹整备和工程器械在装备/器械详情面板中查看；派生资源仍由行动、装备或后续交易/器械部署系统权威结算。

T0205 已在 `res://scripts/systems/BuildingSystem.gd` 中实现基础建筑系统：启动时读取 `data/building_defs.json`，按 `scene_nodes` 绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，为绑定节点创建运行时 `Area3D/CollisionShape3D` 点击区，并在左键点击时发出 `EventBus.building_clicked(building_id)`；建筑受损、修复/升级进度、协助者变化、修复完成和升级完成会发出 `EventBus.building_state_changed(building_id)`。建筑调试标签会显示名称、等级和 HP，并在修复/升级后刷新。2026-05-24 起，`NoticeBoard` 从建筑定义中移除；T1506 后由独立 `NoticeBoard.gd` 创建点击区、相机射线拾取和公告预览，并通过 `NoticeBoardPanel.gd` 调用 MemorySystem，BuildingSystem 不参与公告状态。2026-05-20 修正后，建筑点击同时通过 `_unhandled_input` 的相机射线拾取点击区，避免全屏 UI 背板或项目拾取设置导致真实鼠标点击失效。T0304 起，建筑系统提供 `get_building_entry_position(...)` 和 `get_building_location_context(...)`，分别用于 NPC 移动目标点与地点当前状态读取；该上下文不包含建筑过去事件，精确 HP 与剩余修复/升级时长仍留在系统 / UI，外部只传播 `condition / is_enterable / operational_efficiency` 分档，室内逐位置传播 `id / type / name / occupied_by / status` 及增删变化。T0801 起，建筑系统提供 `claim_workstation(...)` / `release_workstation(...)` 作为位置占用权威接口，ActionSystem 通过这些接口自动取得 / 释放同类型空位。T0043 后新增统一建筑可用性、受损与活动效率接口，升级按 `level_effects` 应用成本、时长、Max HP、位置和效率奖励；固定位置类型拒绝扩容，升级期间建筑封闭并清退使用者。修复/升级由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 结算；资源不足时不会改变建筑状态。升级只有在建筑完好且未处于修复/升级作业时可开始。T1102 起，战斗系统通过 `apply_damage_to_building(...)` 扣除建筑 HP，并写入 `building_damaged` 结构化事件；该入口仍由 BuildingSystem 作为权威状态修改点。

T0304 已新增 `res://scenes/npc/NPC.tscn` 和 `res://scripts/npc/NPC.gd`，并在 `res://scripts/systems/NPCSystem.gd` 中实现基础 NPC 生成、状态接口和直线移动占位：启动时读取 `data/npc_profiles.json`，实例化 8 个 NPC 到 `Main/WorldRoot/Station/NPCs`，每个 NPC 保存唯一 `npc_id`，主场景 `Label3D` 调试标签只显示短姓名、HP 和当前行动。NPC 点击会打印 ID 并通过 `EventBus.npc_clicked(npc_id)` 广播；`NPCSystem` 同时提供 `get_npc(...)`、`get_npc_state(...)`、`get_npc_ids()`、`get_npc_count()`、`update_npc_state(...)`、`set_npc_state_value(...)`、固定熟练度枚举、`normalize_skills(...)`、`get_npc_specialties(...)`、`increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)`、`debug_assign_attribute_point(...)`、`debug_select_npc(...)`、`move_npc_to_building(...)`、`debug_move_npc_to_building(...)`、`debug_move_selected_npc_to_building(...)` 和 `debug_enter_location_immediately(...)`。T1103 后还提供 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 以世界坐标发起城门外集结、接敌时停止移动并切换状态。T1103A 起，NPC 运行时状态统一保存 `behavior_mode = work|rally|combat|avoid_combat|unconscious|escaped`、进入原因和进入时间，T1103 的 `combat_mode` 仅作为旧集结 / 坐骑视觉兼容字段保留。每名 NPC 的技能会归一化为 8 个职业熟练度加 5 个武器熟练度，专长由高熟练度推导，不使用硬职业枚举；运行时 `progression` 记录各熟练度经验、总经验、未分配技能点和已分配技能点。技能点由玩家分配到力量或智力，AI 不自动消耗。移动开始时 NPC 状态进入 `moving_to_<building_id>` 或系统指定的移动状态；到达后通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present`，写入 `current_location`、`current_location_name` 和 `location_context`，并发出 `EventBus.npc_state_changed(npc_id)`。T0409 起，室内信息地点到室内信息地点的切换会在事件与地点信息层插入广场中转；物理移动仍是低模直线占位。T1103A 后 `NPC.gd` 运行时优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结 / 接敌朝向标记，并兼容旧 `combat_mode`；只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动会显示“战术移动”行动摘要。进入地点只读取当前地点状态快照，不继承该地点过去事件。该阶段不实现复杂避障、自然状态变化、真实日程计划、正式战斗结算或 LLM。

T0402 后，`res://scripts/systems/ActionSystem.gd` 的简单行动系统会在行动开始、完成或失败时写入结构化事件：工作路径写入 `work_started`、`work_completed`、`work_failed`，协助修复写入 `repair_assist_started`，协助升级写入 `upgrade_assist_started`，协助治疗和诊所治疗写入 `healing_started` / `healing_completed`，吃饭路径写入 `eat_started`、`eat_completed`，睡觉路径写入 `sleep_started`、`sleep_ended`，工作 / 研读医术 / 训练成长写入 `skill_improved`。行动仍会先检查 NPC 是否可行动，必要时调用 `NPCSystem.move_npc_to_building(...)` 前往目标地点；到达后进入持续行动状态，并通过 `EventBus.logical_time_tick` 按逻辑秒推进，不再瞬时结算完整结果。吃饭当前 1200 秒恢复约 50 点饱食度；睡觉当前 23400 秒降低 100 点疲劳，且睡觉期间 `MemorySystem.add_witness_event(...)` 不会给该 NPC 写入地点/建筑 public 见闻；T0801 后工作以配置 `duration_seconds` 为单位周期基准，开始时占用目标建筑工位，实际周期时长按 NPC 对应熟练度、力量/智力属性和建筑等级缩短，单位结束时结算资源输入/输出、饱食消耗和疲劳增长，完成、失败或中断时释放工位。T0803 后，工作可选 `output_scaling` 产出缩放；当前菜园粮食产出会按耕种熟练度、力量和菜园等级提高实际产量，完成事件记录缩放后的产出。T0804 后铁匠铺消耗铁产出武器/盔甲派生库存；T0805 后工械坊消耗木材产出武器/工程器械派生库存，工程和智力影响制作效率；T0806 后马厩消耗粮食产出马匹整备派生库存，养马、力量和马厩等级影响制作效率与实际产出；T0807 后酒窖消耗粮食产出酒库存，酿酒、智力和酒窖等级影响制作效率与实际产出；T1507 后由 MerchantSystem 在商人到访时单独出售，酿酒完成仍不自动换钱。T0808 后小诊所包含医生工位和病床：医生在岗且病人占床时治疗才推进，治疗按逻辑时间消耗第纳尔并恢复 HP，速度由医术、智力和诊所等级提高；医生无病人时缓慢研读医术。T0903 后训练场包含教官工位和受训位：无装备不能训练或执教，受训者需要已有教官，教官独处时提升自己当前装备对应武器 / 骑术，有受训者时受训者按自己的装备提升对应熟练度且教官提升“教练”，训练按逻辑时间消耗疲劳和饱食。T0904 后，工作完成、诊所研读 / 治疗、训练场成长都会调用 `NPCSystem.increase_npc_skill(...)`，同步写入经验和未分配技能点。协助修复/协助升级是带 `building_id` 参数的运行时广场行为，事件 `location_id == "plaza"` 且 `visibility == "local_public"`；建筑 HP、资源预付和倒计时由 `BuildingSystem` 结算。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者前往目标所在信息地点，每个目标最多 2 名治疗者，按逻辑时间消耗第纳尔，并调用 `NPCSystem.assist_unconscious_recovery(...)` 按医术熟练度加速 HP 恢复；`ActionSystem.get_healing_helpers_for_target(...)` 仅供信息节点读取当前治疗者，不参与结算。若游戏处于暂停，未到达目标的行动保留在 pending 队列中，已开始的行动保留在 active 队列中，不推进资源消耗/产出或状态变化；恢复后继续。当前已按 `game_design.md` 覆盖菜园、食堂、酒窖、铁匠铺、工械坊、马厩、小诊所、训练场、协助修复、协助升级、协助治疗、吃饭和睡觉的最小效果；工程器械部署已由 T1508 独立 DefenseDeviceSystem 处理；其他职业特殊生产平衡仍由后续任务处理。

T0025 覆盖上一段旧行动 / 治疗事件清单：ActionSystem 还执行祈祷、主持弥撒、地点拜访和带目标 NPC 对话，并以 `get_runtime_action_snapshot(...)` 向计划系统暴露 pending / active 的 action、target、location、已占位置与参数。协助治疗只有目标正常完成时写 `healing_completed`；中途第纳尔不足或离开治疗地点写 `healing_failed`。T0043 后普通祈祷使用祈祷席且不依赖神父在场；`lead_mass` 对所有 NPC 可见，但只有 `abilities` 包含“主持弥撒”的 NPC 能占用祭坛。对话接近、预定、打断与位置释放仍由 ActionSystem 权威处理。

T0043 覆盖上一段 T0808/T0903 的单服务者旧效率口径：小诊所使用 `clinic_doctor_station` / `clinic_patient_bed`，训练场使用 `training_instructor_station` / `training_practice_slot`；所有在岗医生共同提高全部病床恢复，所有在岗教官共同提高全部训练位成长。食堂吃饭申请 `dining_seat`，宿舍睡觉申请 `dormitory_bed`，普通祈祷申请 `chapel_prayer_seat`，主持弥撒申请 `chapel_altar`。活动周期同时消费建筑升级加成和受损倍率，建筑封闭时现有行动被强制中断。

T1507/T0129C-A5-P4b 使用 `MerchantSystem.gd`、`MerchantWagon.gd / .tscn` 与 `MerchantPanel.gd`。MerchantSystem 读取 `data/merchant_defs.json`，监听 `time_changed`：到点实例化带多段 Body 碰撞和 NavigationAgent 的实体马车，并绑定专属路线 NavigationMap。只有 `motion_arrived` 后才提交在场事实、启用交易点击牌并写 `merchant_arrived`。P7R2 后 `station_layout_v2.rear_spatial` 登记正式六点局部路线 `(-55,-315) -> (-52,-235) -> (-46,-185) -> (-42,-135) -> (-40,-120) -> (-28.2,-52.4)`；StationLayoutController 同时校验 dock 到后门 `7.0 m` 净距并转换为正式世界坐标，MerchantSystem 以 12 顶点 / 5 多边形折线 NavigationMesh 执行往返。A5-P7 后默认每日时段使用该正式路线，2 点路线仅供临时旧图兼容。

T0132-P7 将复杂表现从 MerchantWagon 权威根拆到 `FormalMerchantWagonArtView.gd`：该子视图运行时生成两匹 Quaternius 马、唯一一套正交四轮两轴木板车、车辕 / 横轭 / 肩圈、19 件分层货物和两头身 `MerchantChibiArtView`。`MerchantWagon.gd` 只把真实平面速度转成马匹 Walk / Idle 与车轮滚动，并将表现快照合入调试结果。ChibiCharacterPilot 只新增只读的 Hand socket 世界坐标访问器，使四段缰绳逐帧以左右手为端点；该访问器不改变角色动画或行动。双马 / 车身 BoxShape 与 `NavigationAgent.radius=1.45 m` 是通行物理包络，交易 Area 仍只在 MerchantSystem 停靠提交后启用。车夫、货物、车轮和缰绳均为表现；买卖报价、余额 / 库存校验及 ResourceSystem 原子结算只归 MerchantSystem。

P7R 在同一表现视图内以两个 ArrayMesh 曲面生成货斗主篷和车夫前檐；五组篷弓、八根货斗侧柱、三根纵梁、四道绑带及两根驾驶区悬挑斜撑均为 MeshInstance3D，不含碰撞与 Area。车篷快照暴露宽度、高度、前后端、前檐长度和构件数供专项审计；MerchantWagon 权威根只把 TradeBubble 抬到篷顶净空之外，不感知或结算车篷。

T0901 已新增 `res://scripts/systems/EquipmentSystem.gd`：系统读取武器、盔甲和坐骑定义，消耗具体库存，把装备写入已入伍 NPC 的 `equipment` 槽位，并通过 `MemorySystem.record_player_interaction(...)` 记录玩家给予或更换事件。T0031 起，NPC 档案的 `initial_equipment` 会在定义加载后装载到空槽；该故事初始化不扣库存、不写玩家交互事件，当前用于让艾达开局持有正式剑盾。T0902 起，兵种判定只根据 `equipment.main_weapon` 与 `equipment.mount` 返回分类标签和只读快照；旧 `horse_readiness` 库存本身不会让 NPC 被判定为骑兵。T0107 后 CombatSystem 读取 NPC `combat_base`、主武器、四甲与坐骑定义，生成统一基础 / 成长 / 装备 / 状态 / 最终属性，并负责远程距离带、敌人抬手 / 僵直和骑兵冲锋状态机；EquipmentSystem 本身仍不执行伤害结算、耐久或完整外观换装。

T0303 已将 `Main/UI/NPCPanel` 绑定 `res://scripts/ui/NPCPanel.gd`：监听 NPC 点击与状态变化，显示目标的权威状态、成长、装备、行动和记忆入口；T0107 后额外只读 CombatSystem 最终快照，显示战斗等级、攻击、防御、穿透和攻速。切换建筑时隐藏自身。T0042 后标题行“背景”按钮复用详情弹窗展示 `NPCPromptProfile` 人设。T0268 后标题行背景按钮右侧直接显示行动值与灰暗行为模式值；记忆入口显示“当前计划 / 日记 / 认识”和“事件 / 见闻”，不显示库名与条数。事件和见闻详情首次打开自动滚到最底部的最新记录，已打开时刷新保留玩家当前位置，日记与底层知识图谱继续在独立详情弹窗查看。T1204A 后逃离 NPC 仍可从该面板进入挽留对话。`BuildingPanel` 在 `npc_clicked` 时隐藏，确保对象面板互斥。

T0079 后，`NPCPanel` 的当前计划详情会在只读展示层合并连续且完整展示语义相同的小时项，并隐藏与行动名完全相同的重复 `reason`；当前时段标记和首次滚动按合并后的可见分组计算。DailyPlanSystem / NPCSystem 的 24 小时权威计划、来源、Prompt、Schema 与执行均不受影响。

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
## T0131-P2R3 正式小教堂建筑切片

- `StationLayoutController` 在 Chapel 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalChapelArtView.gd` 并隐藏旧 Envelope。表现根继承 `BuildingArtView`，只读 BuildingSystem 的 Lv.1 / Lv.2，不拥有虔诚、礼拜、地点、工位、HP 或升级结算。
- `FormalChapelArtView` 在约 `12 × 12 m` 包络内程序组合暖灰石基 / 转角石、阶梯山墙、尖拱门套、圆窗、侧墙尖拱狭窗、圣坛端和 `31°` 冷灰蓝板岩屋顶；主屋面与钟塔屋面统一使用主厅现有基色 `#65717a`。这些节点是表现语义，不取代正式静态墙体 / 导航。权威家具继续来自 `building_fixture_layouts.json`。等级投影把 fixture 可见 / 碰撞从 `11→16`，但 `workstation_markers_path=../FixtureLayout/NPCStands` 始终只有祭坛 1 + 祈祷席 10。
- Lv.2 把 `chapel_level_two_bell_rack` 调整到局部 `(-5.58, 3.0, -3.9)` 的西后侧高位钟塔，碰撞中心同步为 `Y=4.25 m`；该 fixture 没有 NPC 工位或行动事务。`ChapelLevelTwoRoofTruss`、钟塔屋面和恢复后的五根短金色 `RoofCrest / RidgeFinial` 登记为额外屋顶透明根；钟体、彩窗、扶壁及其他塔 / 墙附件登记为额外外墙透明根，同 `70→58 m / 0.06` 曲线切换 alpha 与阴影。主屋面十四根 `West/EastSlateJoint` 使用与各自 `West/EastNaveSlate` 相同的 global basis X 方向，尺寸厚度为 `0.018 m`；专项锁定左右各七根、方向点积至少 `0.999`。`BuildingArtView` 的材质缓存仍处理 surface material 和程序网格 `material_override`。
- 小教堂自动门沿局部 `+Z` 入口对齐，净口 `2.08 × 2.35 m`，无阻挡 CollisionShape；正式门洞、NavigationMap、地点提交和工位占用仍由 StationLayoutController / NPCSystem / BuildingSystem 提供。GM `chapel_art_level <1|2>` 只调用表现预览，不修改 BuildingSystem。

## T0131-P3 正式小诊所建筑切片

- `StationLayoutController` 在 Clinic 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalClinicArtView.gd` 并隐藏旧 Envelope。表现根继承 `BuildingArtView`，只读 BuildingSystem 的 Lv.1–3；真实医生桌 / 病床仍来自 `building_fixture_layouts.json`，治疗结算仍由 ActionSystem / BuildingSystem 提交。
- T0131-P3R 后，`FormalClinicArtView` 不再导入与工械坊接近的通用圆瓦双坡顶；四个 `SurfaceTool` 坡面、短屋脊与中央玻璃采光气楼组成宽缓四坡轮廓。程序面保持向上法线并按 Godot 顺时针正面顺序提交，运行时网格完整性审计没有诊所新增项。象牙灰泥、鼠尾草绿木构 / 百叶、奶油布雨棚、药草花箱及叶片药臼圆徽记只提供治愈医舍语义，不新增现代红十字或第二套交互权威。
- 诊疗位 marker 总数固定 2，病床可用 marker 为 `2→3→4`；等级同步把 fixture 可见与碰撞切为 `6→7→8`，但不修改权威数组。四坡屋面 / 采光气楼属于基础 Roof 根；Lv.2 / Lv.3 通风结构登记为额外屋顶透明根，全部外墙、雨棚、窗饰、花箱、晾棚 / 发药窗登记到基础或额外外墙透明根，共用 `70→58 m / 0.06` 曲线。
- 自动门沿局部 `+Z` 入口对齐、净口 `2.08 × 2.35 m`，只感应角色碰撞层。GM `clinic_art_level <1|2|3>` 只调用表现预览；最高等级美术与 fixture 包络由专项限制在 `14 × 14 m` 地块内。

## T0131-P4 正式食堂建筑切片

- `StationLayoutController` 在 DiningHall 的正式 `StaticCollision / FixtureLayout` 完成后实例化 `FormalDiningHallArtView.gd` 并隐藏旧 Envelope。表现根只读 BuildingSystem 等级；真实灶台、座椅、路径、占用、生产和进食仍由既有数据与系统维护。
- 两个 `kind=dining_table` 的共享桌由控制器生成厚木桌体、支架和少量餐具，不再加载诊所检查桌。桌体仍沿用配置 ID、Transform 与 BoxShape，且不创建 `NPCStand` 或 occupant anchor；十把椅子继续分别承载十个用餐事务。
- 等级同步把 fixture 可见 / 碰撞切为 `14→14→15`，可用灶台为 `2→2→3`，用餐席固定 `10`。`FormalDiningHallArtView` 的 Lv.2 只投影储藏 / 备餐 / 燃料设施，不再给前两根烟囱添加悬浮防火帽；Lv.3 第三排烟罩与屋顶烟囱和 `kitchen_03` 同级出现，不预告虚假容量。
- 屋顶、四周墙体、烟囱、燃料棚与升级外墙附件统一走 `70→58 m / 0.06` 透明链；自动门沿局部 `+Z` 对齐，净口 `2.08 × 2.35 m`。GM `dining_hall_art_level <1|2|3>` 只切表现预览，最高等级可见包络由专项限制在 `16 × 14 m` 地块内。
- T0131-P4R 只重排表现节点：Lv.2 备餐柜与 Lv.3 发餐柜分别挂在正面墙内侧左右，统一以根节点旋转柜体和台面附件。专项用运行态 Mesh AABB 审计它们与基础 `East/WestServingCrockery` 零相交，并单独检查门前带；不调整 StaticCollision、NavigationMesh、fixture 配置或等级同步。
## T0132-P3 围墙与动态城门表现（2026-08-23）

- `StationLayoutController._build_walls_and_gates()` 继续生成 14 段 `StaticBody3D` 墙碰撞、4 个门柱碰撞及既有导航源；旧 `Wall_* / LeftPost / RightPost / Lintel` Mesh 仅隐藏，结构权威不迁移。
- 同一控制器在 `WallsAndGates/FortificationArt` 实例化 `FormalFortificationArtView`。P3R 的视图只读 `station_layout` 和 BuildingSystem，生成 WoodTrim 贴图木板幕墙、立柱 / 束梁 / 斜撑、巡逻道、木垛口、六级升级组及四个木制正式器械台；RockTrim 只用于低防潮基脚。平台坐标继续由 `get_defense_device_slot_pose("wall", slot_id)` 绑定 DefenseDeviceSystem。
- `FormalGateArtView` 的 P3R 塔身、门楣、垛口和外露框架均为木制，仅塔脚使用低石垫；正后门仍各生成两个 `AnimatableBody3D` 门叶，每叶持有 world-static 层碰撞。碰撞只负责真实阻挡 / 开合，不决定敌军到达、建筑受击或突破；敌军 `enemy_id` 被传感器过滤，友军在战时仍能触发开门，BuildingSystem HP 清零后禁用门叶碰撞并打开。
- 门传感器只读取 actor-body 层：`npc_id` 为我方，`MerchantWagon` 仅可作为商队触发者，`enemy_id` 永远排除。门状态不写地点、工位、事件、HP 或导航事实。
- P3R2 将 `wall_slot_01–04` 的正式横向偏移统一改为 `-7.6 / +7.6 / -13 / +13 m`。`StationLayoutController._get_front_wall_defense_device_slot_pose()` 和 `FormalFortificationArtView.PLATFORM_LATERAL_OFFSETS` 使用相同合同；DefenseDeviceSystem 默认正式绑定后把部署位置与攻击原点覆盖到这些世界坐标。所有平台元数据均为 `building_id=wall / host_structure=front_wall`，不读取 `front_gate` 等级，也不成为门楼子槽。
- P3R3 从 `FormalFortificationArtView._build_upgrade_visuals()` 删除 `FrontWallTimberButtress / WallIronTie / FinalIronCoping`。Level2 / 4 / 6 根仍参与等级切换但不再生成独立墙外盒体；对应等级的平台显隐继续由 `_apply_visual_level()` 和 `PLATFORM_REQUIRED_LEVELS` 驱动，因此清理不影响槽位或碰撞权威。
- P3R4 由 `FormalFortificationArtView._get_front_wall_attachment_pose()` 和 `StationLayoutController._get_front_wall_defense_device_slot_pose()` 分别读取 `north_west_a / north_east` 两个真实墙段。算法选择距正门中心最近端点，从门洞边缘扣除后的既定距离沿墙切线采样；平台 / 横杆 / 旗面旋转取正 X 墙切线，DefenseDeviceSystem facing 取 Z 为正的墙外法线。专项锁定左 `-4.61°`、右 `+5.75°`、墙段 ID、附件数量以及平台—运行态位置 / 朝向一致。
## T0137 NPC 移动期间统一时间慢速

`res://scripts/npc/NPC.gd` 在 `move_to_location(...)` 或 `ActorMotionBody.motion_started` 确认真正进入运动生命周期后，向 `Main/Systems/TimeSystem` 注册 `npc_movement:<npc_id>`；`stop_movement`、`motion_arrived`、`motion_failed`、`motion_cancelled` 与节点退出统一释放。请求使用 TimeSystem 的默认慢速值 `1/60`，多名 NPC 各有独立 id，因此任一移动者仍存在时不会提前恢复玩家倍率。运动动画与实体位移仍按原真实帧速度运行；TimeSystem 发出的有效游戏秒同步约束 Resource / Action / Building / Needs / Combat 等既有逻辑时间消费者。Main 的 HUD 已能直接显示 `x0.02` 与精确秒，GM 既有指定移动和时间倍率快照足够辅助验证，不新增面板入口。
## T0213 马匹返厩 ActorMotionBody 生命周期

- `Main/Systems/HorseSystem` 在已骑乘马脱离战时状态时，读取 `NPCSystem.get_npc_world_position(rider)` 作为真实下马点，在自身下创建隐藏 `ActorMotionBody`，配置与 `enemy_mounted` 同胶囊但属于友方 RVO 层的 `horse` profile，并用 `horse_defs.return_to_stable_speed=3.2` 覆盖速度。该节点绑定 StationLayoutController 的 production NavigationMap，抵达马厩开放侧后释放并将只读表现归位到原 `stable_slot_id`。
- FormalStableArtView 仍是马匹可见模型唯一来源：`returning_stable` 读取 HorseSystem 同步的 Body 世界位置 / velocity，播放 Walk 并按实际速度转向；`waiting_for_rider_at_return_position` 保持原位置并播放 Idle。隐藏 Body 不创建第二匹可见马，也不接管点击、HP 或分配。
- 返厩中 NPC 再进 `rally` / `combat` 时，HorseSystem 取消 Body request、在马旁环形采样生产 NavMap 可达会合点，并调用既有 `NPCSystem.move_npc_to_world_position(...)`。NPC 抵达后释放隐藏 Body，设置 `ridden`，再调用 `CombatSystem.handle_npc_mount_ready(...)` 恢复集结。
