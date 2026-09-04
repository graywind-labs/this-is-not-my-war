# COMBAT_SYSTEM.md

## T0350 实战成长与骑术收益

- NPC 武器命中敌人后，以统一伤害入口提交的 `hp_before - hp_after` 为唯一成长伤害；每累计 50 点提升 1 点当前武器熟练度。攻击发起时 `combat_mounted=true` 的同一武器伤害还按每 100 点提升 1 点骑术。过量伤害不计，余量按 NPC / 熟练度独立保存，换武器、跨波次和正式空间检查点不会丢失。
- 远程弹体沿用发射时 `attack_context` 中的 `required_skill / mounted` 快照；飞行途中上下马不改变本发成长归属。技能达到 100 时停止对应成长并清空隐藏余量。
- 只有 `source_type=npc_weapon` 且显式携带 NPC 成长资格的攻击进入成长链。NPC 武器直接击杀额外增加 1 点总经验；器械、陨石、环境及兼容马匹冲撞不会增加熟练度或击杀经验。同一敌人的 HP 只能从正数降到 0 一次，因此不会重复发放击杀经验。
- 骑术只在真实战时骑乘状态生效：0–100 线性提供最多 `1.12x` 额外移速和 `1.08x` 额外攻速，并分别乘在坐骑固定 `1.35x / 1.05x` 之外。未会合、下马或坐骑失效时，固定倍率与骑术倍率均不生效。
- 首轮保持五波敌军数量、HP、攻击、防御和攻速不变。该成长主要形成跨波次回报，首轮以专项与既有五波数值合同观察通关率，再决定是否调整敌军。

## T0332 正式全歼与守波提示边界

- `CombatSystem` 在每个敌人 HP 经统一伤害入口真实降到 0 时累计 `resolved_defeated_enemy_count`；该计数与 NPC 击退归属分离，所以近战、实体弹体、塔防和范围伤害均计入。
- 战斗结束时只有“剩余敌人 = 0、实际击败数覆盖起始波与全部追加波的敌军总数、GameState 未失败”同时成立，才按去重、升序波次发送 `combat_wave_cleared`。GM 清除 / 替换敌人不增加实际击败数，因此仍可执行既有清理与结算，但不会冒充成功守波。
- 最终第五波的 `victory` 不是失败，仍发送守波提示；主厅摧毁后的 `failure` 明确抑制提示。EventBus 信号只投影已提交战斗事实，不参与 HP、清敌、胜负或波次调度。

## T0135-P10H 陨石音频时间线

- PietySystem 继续独占虔诚消费、pending 陨石、实际视觉轨迹、冲击伤害、友军排出、燃烧区、镜头震动和事件。AbilityAudioController 只消费已有 `meteor_cast_started / meteor_impacted` 信号。
- 下坠完整单次声挂在正式 MeteorPresentation，因此自动跟随其真实世界 Transform；冲击声只在 `_resolve_meteor_impact` 已提交伤害 / 燃烧 / 事件后从结果落点播放。声音不存在或播放失败不得阻止技能。
- 游戏逻辑暂停时两条陨石 player 使用 `stream_paused` 保持位置；恢复后继续剩余素材，不改变 `fall_duration_seconds`。冲击不会截断已开始的完整下坠素材。

## T0327 塔防伤害反馈位于血条上方

- DefenseDeviceView 以当前器械实例的 WorldHealthBar 全局位置为基准，向上 `0.38m` 提供完整反馈锚点。弩床和箭塔名称高度不同，血条与伤害红字会随各自实例共同变化，不再共享 `2.35m` 的低位固定偏移。
- DefenseDeviceSystem 在提交 HP 变化前捕获该锚点，因此器械本次伤害被摧毁并移除视图时，红字仍能在最后的血条上方完成生命周期。不同命中点不改变文字位置，同部署的新伤害继续替换旧红字。
- 实际命中点仍传给战斗音效和碰撞事实；锚点修正不改变塔防命中资格、HP、摧毁、宿主隔离或敌军攻击逻辑。

## T0325 塔防近战引导点与真实模型接触闭环

- `enemy_attack_guidance_zones_v2` 为 `defense_device + melee` 生成墙面 / 平台候选时，横向中心只使用宿主代理 `hit_radius × defense_device_melee_proxy_safe_half_width_ratio` 的安全半宽，当前倍率为 `0.5`。远程六排、普通建筑 / 正门引导、目标锁和攻击射程不受该参数影响。
- 该安全核心为真实剑刃横向扫掠保留边界，避免引导中心贴近门柱或局部代理边缘后，敌人持续播放合法攻击动作却只命中邻接阻挡 / 扫出当前部署代理。城墙单区域弩床的步行剑盾近战候选因此由旧 5 点收束为 3 点；动态稀疏选择仍无独占容量或 waiter。
- 命中权威没有放宽：模型扫掠仍须通过 deployment 或 `building_id + wall/building segment/fixture + hit_radius` 身份校验，随后才调用 DefenseDeviceSystem；围墙 / 主厅 HP 不连带下降。T0325 逐点回归三点均首周期扣除器械 4 HP，T0195 自然整波仍连续 3 次扣血。

## T0317 正门、仓库与主厅唯一反馈锚点

- 正门、仓库、主厅的 HP 伤害、恢复与修复跳字统一使用正式建筑实体顶部的唯一反馈锚点。具体箭矢 / 近战墙面命中点不再改变这三座建筑的文字位置，因此正门和仓库不会错落到广场，主厅也不会随不同墙面出现两处。
- 这项例外只改变 WorldFeedbackPayload 的表现坐标。弹体碰撞、合法目标、实际伤害、`building_damaged` 事件和位置音效仍沿既有权威链路结算；普通建筑继续保留精确碰撞点优先策略，塔防器械按 T0327 固定使用自身血条上方锚点。
- 同一建筑 `damage` 频道的新红字仍即时替换旧红字；绿色恢复 / 修复使用同一正式锚点但独立 `healing` 频道。

## T0316 返厩途中直接接敌的取马连续性

- `combat_mount_phase` 属于骑乘会合事务。CombatSystem 在 `going_to_returning_horse / beside_returning_horse` 阶段与既有马厩取马阶段一样，暂停普通索敌攻击和战术移动，避免同一 NPC 的移动请求被逐帧改写。
- HorseSystem 路线看门狗以 NPCSystem 返回的 ActorMotion `active + request_id=stable` 为准，不再把可能在 `work → combat` 投影中清空的 `movement_target` 当作权威。只有真实路线消失才按原冷却机制恢复请求。
- 途中坐骑继续原地等待，骑手保持 combat `run` profile 和奔跑动画；会合后由既有 `_complete_mount_rendezvous(...)` 原子完成骑乘，再恢复普通战斗 AI。攻击、伤害、装备、马匹身份和战斗策略均未改变。

## T0135-P10E 战斗音频权威提交点

- CombatSystem 只在已有战斗事实边界发送 `combat_audio_event`：近战 swing 开始播剑 / 长杆挥动，实体弹体生成播释放与破风，物理碰撞且实际造成伤害后播弹体命中，敌军 HP 实际下降后播身体接触 / 概率语气；首次活动敌军进入播入场，非最终胜利的正常活动波结束播清波。
- NPCSystem 在 HP 实际下降后发送我方受击，并携带 `became_unconscious`；HorseSystem 只在马匹正式死亡后发送阵亡，普通受伤无声。BuildingSystem / DefenseDeviceSystem 只在 HP 实际下降后发送结构受损，并携带 destroyed 和提交坐标。最终胜利 / 失败沿既有 `game_over_changed` 在主厅位置播放。
- 音频事件是提交后的只读 DTO，不替代攻击 ID、实体弹体、碰撞身份、伤害公式、HP、昏迷、摧毁、波次或 GameState。一次远程命中允许“释放 / 破风 → 弹体接触 → 身体接触 / 概率语气”按时间分层，但每个事实只在对应提交点出现一次。
- CombatSystem 新增只读敌军音频运动快照，返回实际表现位置、移动状态、水平速度与骑乘标记。MovementAudioController 只混音距镜头最近的 6 个真实移动敌人，不改变寻路、速度或目标选择。

## T0135-P10B 敌人在场音频表现信号

- CombatSystem 每次执行既有 `_sync_enemy_presence_time_slowdown(...)` 时，以 `_active_enemies.size()` 为唯一来源；数量实际变化后广播 `EventBus.combat_enemy_presence_changed(active, enemy_count, reason)`。
- 该信号只供表现层选择战斗 / 日常 BGM，也保留数量和原因用于诊断。它不生成 / 清除敌人，不改变 `combat_enemy_presence` 的 `1/60` 慢速请求，不替代波次、胜败、警铃或 NPC 行为模式。
- 敌人首次真实进入场景后才切 `music_battle`；最后一名敌人自然死亡、GM 清场或恢复为空状态后回到 `music_day_night`。来袭预告和单纯触发警铃不会提前切歌。

## T0312 战斗 HP 世界反馈

- NPCSystem、CombatSystem、HorseSystem、BuildingSystem 与 DefenseDeviceSystem 继续独占各自 HP 结算；提交后将 `hp_before / hp_after` 交给 `WorldFeedbackPayload.emit_hp_change(...)`，Presenter 只显示真实带符号差值，不读取攻击力推算伤害。
- 同一 `anchor_type:id` 的 `damage` 频道收到新命中即替换旧红字。敌军与器械被本次伤害移除前先保存实体 / 部署世界坐标；反馈节点即使随后消失仍在最后位置完成 2 秒生命周期。范围伤害逐目标经过同一入口，骑乘分伤分别由 HorseSystem 和 NPCSystem 发出，不能在骑手处重复总伤害。
- 近战碰撞身份与弹体 `collision_position` 在存在时透传为敌军、器械或普通大型建筑的优先反馈点；无碰撞点才回退到对象锚点。正门、仓库、主厅按 T0317 固定使用正式实体顶部的唯一反馈锚点。该差异不改变命中资格、碰撞身份、伤害公式、宿主 / 器械 HP 隔离或事件事实。
- 昏迷自然恢复、协助 / 诊所治疗和建筑修复只显示正的实际 HP 差，短窗治疗合并不合并伤害。当前器械系统没有恢复权威接口，因此只接伤害，不新增器械修复数值规则。

## T0306 高频战斗事件投影边界

CombatSystem、NPCSystem、BuildingSystem、DefenseDeviceSystem 与 HorseSystem 继续逐次结算并逐次写入 `attack_made / damage_taken / building_damaged / defense_device_triggered / horse_damaged`；伤害、HP、目标、武器、部署和马匹事实不在生产侧合批。只有后续 LLM 投影按严格语义键聚合，同一目标但武器 / 攻防参数、伤害来源、建筑、部署、马匹、地点、可见性或日期不同都保持独立。非白名单战斗事件会切断聚合段，保留昏迷、复苏和战斗结束等因果边界。

## T0299 战斗模式与事件事实分层

- `work / rally / combat / avoid_combat / unconscious / escaped` 的互转及内部 reason 只写 NPC 运行态和 GM 快照，不进入事件库。
- 战斗信息继续由具体事件表达：警铃、集结、遭敌、避战、攻击、伤害、昏迷、复苏、逃离和挽留结果均保留，权威状态机与数值结算不变。

## T0291 战时行动不受对话抢占

- 守备官对话不是战斗暂停或行动状态。NPC处于 `rally / combat / avoid_combat` 时，CombatSystem继续独占集结目标、索敌、攻击阶段 / 冷却、战斗策略移动、避战目标和物理移动；DialogSystem不得调用普通行动中断、停止战时移动或写入对话行动标签。
- 战斗模式在会话期间发生 `rally ↔ combat`、`work → rally/combat/avoid_combat` 或回到 `work` 的合法转换时，已激活的玩家对话及其在途请求保留，会话上下文跟随最新模式。自主 NPC-NPC 闲聊仍限和平工作模式，不因本规则进入战时。
- 战斗事件、HP、敌我数量、目标与行为状态继续进入后续对话轮次的实时上下文。普通对话文本和情绪没有战斗效果；策略切换、士气增益、应征后的装备分流与逃离，只能通过原有权威接口落地。
- 逃离挽留不属于普通战时并行对话：`pause_escape_for_dialogue / resume_escape_after_dialogue` 仍明确暂停和恢复离站移动。

## T0287 战斗结果调试包装

- `debug_start_morale_boost / debug_clear_morale_boost` 只为 GM 结果展台提供重复验收，内部仍调用既有 `_start_morale_boost`、结束事件和 NPC 状态更新；正常对话资格、不可叠加与跨日清除不变。
- 逃离开始、挽留留下 / 继续逃离按钮分别调用既有 `debug_start_npc_escape / apply_escape_intervention_result`。警报、路径、轮次、事件和状态均由 CombatSystem 继续独占。

## T0286 实际逃离开始通知

- `start_npc_escape(...)` 只有在入口校验、行为模式与移动目标切换成功，并写入 `escape_started` 后，才广播 `EventBus.npc_escape_started`。
- 逃离意向、计划、启动失败及已经处于逃离状态的重复请求不会广播；HUD 仅据此显示一次居中警报，不参与路径、速度、挽留或离站结算。

## T0284 对话策略资格、候选与默认值

- 全部兵种默认策略统一为 `attack / 主动进攻`。近战步兵、长杆步兵和近战骑兵仅允许 `attack / avoid`；弓箭兵、弩手和骑射额外允许 `keep_distance / 拉开距离射击`。
- 未实现的 `charge_cycle / 拉开距离冲击` 已退出合法候选；旧运行状态或存档引用会被归一化为当前兵种默认 `attack`，底层兼容分支暂保留但没有 UI / 新请求入口。
- `get_combat_strategy_dialogue_eligibility(...)` 是策略 toggle 的权威资格：NPC 必须已入伍、持主武器并处于 `rally / combat`。`get_npc_combat_strategy_dialogue_context(...)` 提供当前策略与合法候选。
- NPC 面板不再写策略。只有显式对话请求经结构化结果合法化后，才调用 `set_npc_combat_strategy(..., reason="guard_dialogue_request")`；保持结果不产生变更。

## T0283 鼓舞资格与跨日 buff

- `get_wartime_dialogue_reaction_eligibility(...)` 是对话开关的战斗资格来源：目标必须处于 `rally / combat`、已入伍、持主武器且当前没有活动鼓舞 buff。
- `morale_boost` 仍令攻击力和 NPC 移动速度各提高 15%，但期限从固定 2 游戏小时改为“生效当天剩余时间”：开始时计算到次日 `00:00:00` 的逻辑秒数，并记录 `expires_day / expires_time`，跨日 tick 清除并写 `morale_boost_ended`。
- 鼓舞判定只在显式 toggle 请求后暂存；完成对话前不写 buff / 逃离事实，取消仍不应用。活动 buff 会反向禁用对话 toggle，避免重复叠加或刷新期限。

## T0282 敌军头顶信息与世界血条

- CombatSystem 为正式敌军与兼容敌军实体统一挂载 `WorldHealthBar3D`；敌军存在期间血条始终显示，直接读取当前 `hp / max_hp`，受到伤害后沿既有 `_refresh_enemy_node(...)` 路径同步。
- 敌军 Label3D 严格只显示敌人定义中的具体 `name`，不再拼接文字 HP、`unit_type_label`、当前行动或攻击目标。敌军详情面板仍可保留完整战斗数据，头顶信息不拥有结算权威。
- 敌军血条健康色和危险色都配置为橙色 `#c97832`，因此填充会随 HP 缩短但不会转红；NPC、建筑和塔防仍沿用绿 / 濒危红规则。

## T0280 战时世界血条与塔防标签降噪

- `CombatSystem.get_active_enemy_count() > 0` 是 NPC、战略建筑与活动塔防世界血条的统一战时显示条件；清敌后自动隐藏，不依赖波次倒计时或警铃状态。
- NPC、建筑、器械血条分别只读 NPCSystem、BuildingSystem、DefenseDeviceSystem 的 `hp / max_hp`，严格低于 30% 转红；伤害、目标选择、独立器械 HP 与宿主建筑 HP 路由均未改变。
- 塔防世界标签只保留名称，射程仍存在 deployment `effect.range` 和属性面板中，命中结果仍由实体弹体与战斗表现表达，不再占用头顶文字。

## T0279 塔防部署入口收敛

- 围墙 / 主厅空槽选择窗改为逐件库存纯图标，但部署仍由 DefenseDeviceSystem 原子校验和结算；UI 不复制器械属性、射程加成、HP、攻击时间线或槽位资格。
- BuildingPanel 删除重复部署表单只影响入口，不改变活动 deployment、敌方索敌、物理命中、器械独立 HP、满血返库或受损卸下销毁。保留的“已部署”汇总继续只读活动实例。

## T0277 战斗单位血量可视化

- NPCPanel 与 DefenseDevicePanel 分别读取 NPCSystem、DefenseDeviceSystem 的 `hp / max_hp`，在 HP 字段下显示独立血条；正常为橄榄绿，严格低于 30% 时条与标签转暗红。
- DefenseDevicePanel 的血条随既有 deployment 状态信号刷新，只做活动器械状态投影；独立器械 HP、宿主建筑 HP、敌方伤害路由、满血卸下返库与受损卸下销毁规则均不变。

## T0269 敌方远程对正门 / 仓库 / 主厅的建筑伤害

- 生产基线确认三类建筑都能被正式远程 selector 自然选中并完成 windup / release；仓库原本可正常受伤，正门和主厅失败在弹体 sweep：T0260 的透明过滤没有区分“宿主挡住后方目标”和“宿主就是目标”。
- 正门 / 主厅现在只在不是本发敌方弹体明确建筑目标时透明。敌军远程明确攻击 `front_gate / main_hall` 时，箭矢实际撞击其 collider，再按 collision identity 调用既有建筑伤害入口；射向门后角色或主厅器械时仍继续原线段 sweep。
- 正式弓 / 弩矩阵结果：正门 `160 → 154 → 147`，仓库 `150 → 144 → 137`，主厅 `180 → 174 → 167`。六项均自然选中、释放、命中对应 building id；透明跳过为空。仓库仍是普通阻挡建筑，不新增白名单或特殊瞄准。

## T0266 远程战斗不依赖额外弹药库存

- 弓、弩、箭塔与弩床继续按武器 / 器械定义执行攻击冷却、装填表现、物理弹体和命中结算，不读取或扣除独立弹药商品。
- 本次只删除无效资源占位，不修改射程、伤害、攻速、弹道、遮挡或塔防 HP 路由。

## T0263 全槽位敌方远程命中矩阵

- 现有 4 个围墙槽位和 4 个主厅槽位均对箭塔、弩床完成正式敌方自然攻击验证，共 16 项；每项 release aim 与实时 projectile Area 中心偏差均为 `0.0 m`，实际碰撞身份均为目标 deployment。
- 每发敌箭造成 4 点有效伤害：箭塔 `110 → 106`、弩床 `55 → 51`。围墙 `240`、主厅 `180` 在所有对应用例中保持不变，证明器械 / 宿主 HP 路由隔离。
- 合法遮挡仍生效：从主厅东北器械位北侧隔着诊所射击会命中诊所外墙；矩阵改用东侧无遮挡射线验证目标，不把诊所加入弹体透明列表，也不将 blocked 结果伪装成命中。

## T0262 敌方远程瞄准主厅塔防

- 敌方远程锁定 defense device 后，攻击位与近战距离判断仍使用宿主墙面代理；真正生成箭矢 / 弩箭时，瞄准点改为当前活动器械 `InteractionArea/CollisionShape3D` 的世界中心，不再射向主厅墙面旧代理。
- 瞄准点只在 release 时采样一次，弹体仍不追踪移动目标。之后必须通过 T0260 的主厅透明 sweep 实际碰撞器械 Area，才能按 deployment 身份减少器械 HP；主厅 HP 不联动，也没有逻辑补伤。
- 弹体快照新增 `aim_target_source=defense_device_hit_area_center` 与 `aim_target_node_path`，可区分真实器械受击点和兼容回退。专项自然链确认弓手自行选中器械并完成 windup / release，器械 HP `106 → 102`、主厅 HP 不变。

## T0261 塔防选择与射程投影

- 已部署塔防的 interaction Area 携带 deployment 身份，世界点击只选择 `status=active、hp>0` 且宿主可见的器械；点击不改变器械 HP、目标、攻击时间线或宿主建筑状态。
- DefenseDevicePanel 与 AttackRangeIndicator 共用 `EventBus.defense_device_clicked`。面板读取 deployment 的有效 effect，圆圈继续读取 `get_attack_range_indicator_snapshot(...)`，两者均不复制或修改战斗数值。
- 废墟关闭 Area 并清除交互身份；deployment 失效后面板和圆圈按既有状态信号隐藏，不产生攻击或结算旁路。

## T0260 正门 / 主厅只对弹体透明

- 正门与主厅仍是 world-static 实体与 NavigationMap 阻挡；本规则只作用于 CombatSystem 管理的敌军、友军和塔防物理箭矢 / 弩箭，不改变角色、马匹、商车或近战武器的实体接触。
- 弹体子步命中 `front_gate / main_hall` 建筑身份时，若该建筑不是本发敌方弹体的明确建筑目标，则排除该 collider 并继续原线段 sweep；建筑自身是目标时正常碰撞受伤。围墙、仓库、其他建筑、地形、敌对角色和昏迷角色仍正常挡箭；最多 32 次透明跳过的有界保护继续覆盖重叠 collider。
- 塔防器械拥有独立、非阻挡的 projectile Area。敌箭穿过主厅可命中其上器械，并经既有 deployment 身份只扣器械 HP；友方 / 塔防箭跳过同阵营器械。直接器械身份优先于继承的主厅建筑身份，避免目标被透明规则吞掉。
- 调试快照新增 `transparent_building_skip_count / transparent_building_skipped_ids`，与既有同阵营跳过、碰撞位置和残箭字段并列；没有 release-time 逻辑补伤或第二套建筑结算。

## T0259 集结取马遇敌接管

- `spawn_wave(clear_existing=true)` 在没有敌军、active battle 或 formal enemy runtime 时不再把空清理解释为战斗结束，因此预战 `rally` 和正在进行的指定马匹会合不会在新波次生成前被切回工作。
- 正式战斗世界迁移会停止旧导航请求，但 HorseSystem 随后按 pickup waiting phase 验证真实移动；路线 inactive 或指向错误目标时，从 NPC 当前坐标重建到同一马旁接近点。接敌切为 `combat` 后 `combat_mount_phase` 保持 `going_to_*_horse`，友方攻击 AI 继续等上马完成。
- 重复警铃对合法 target lock 保持无副作用边界，只额外调用幂等取马路线恢复；结果中的 `mount_route_recovered_count` 可观察本轮修复数。没有传送、马匹重分配、重复生成或目标锁重置。

## T0257 战后伤员治疗与工作武器表现

- 正式战斗结束后昏迷者继续留在实际倒地点；治疗系统以该身体坐标为权威空间目标，战前 `current_location` 只保留信息语义，不再把治疗者送回旧工作建筑。
- 战后人群不会永久阻断合法治疗：常规导航失败后有限更换伤员身边站位，并仅在恢复请求中忽略 actor 胶囊；地形、建筑和 NavigationMap 不放宽，治疗会话收口时恢复常规碰撞。
- NPC 的主武器槽在返回工作后仍保留，但人物表现收起武器并显示当前职业工具；重新集结、接敌或执行武器训练时再显示主武器。此规则不改变兵种、索敌或伤害结算。

## T0256 警铃解散与模式切换位置连续性

- `dismiss_combat_rally(source)` 枚举 NPCSystem 权威模式，只将 `rally` 切回 `work`；活动 rally 记录随成功转换清除。`combat`、`avoid_combat`、昏迷、逃离和普通工作 NPC 只进入 ignored，不被解散。
- 工作→集结 / 直接战斗 / 避战的转换帧保持实体世界坐标；从 rally / combat / avoid 返回工作同样不回写出生点、地点锚点或开战前缓存位置。新目标只通过 NPC 正式移动接口从当前坐标平滑寻路。
- 正式战斗世界的默认居民始终使用生产 NavigationMap。开战时工位 / 坐席权威释放不改变切换前坐标；战斗结束时保留战场结束坐标。旧非正式兼容 actor 仍可恢复其原空间，避免破坏隔离测试 / 旧入口。
- rally 解散 / 超时与 avoid 清场续接当前计划且不重评估；combat 清场保持既有战后重评估。骑手回马厩仍走 HorseSystem 物理返程，原地解除骑乘的切换帧不移动马匹。

## T0249 固定目标近战到位与持续静止脱困

- `enemy_attack_guidance_zones_v2` 的近战移动到点半径按 `有效交接距离 - attack_range_arrival_margin - 所选圆心到其对应接触点距离` 逐敌计算，并钳制在 `0.01～arrival_tolerance`；第一波正门为 `0.062～0.069 m`，不再使用通用 `0.32 m`。
- 为敌人选择引导圆时，占区圆柱统计排除该敌人自身，只统计其他存活敌军真实胶囊；调试快照中的 occupant ids 因而不会把选择者自己当作拥堵来源。
- enemy combat motion 的独立静止计时跨同请求目标更新与活动 request 替换保留。固定目标仍在攻击范围外且连续静止 `guidance_stall_recovery_seconds=0.75` 后，系统排除当前圆并重选；恢复窗口临时关闭该 Actor 对 actor-body 的物理碰撞，仅保留 world-static 碰撞，移动恢复或入射程立即还原。真实模型 / 弹体接触、HP、速度、NavMap 与攻击范围不变。

## T0248 箭矢同阵营穿透、释放锁与落点附着

- 敌我角色与正式塔防继续共用 CombatSystem 物理弹体。每个 `1/120 s` 子步在原线段上重复 ray sweep：我方 / `defense_device` 排除带 `npc_id` 的角色，敌方排除带 `enemy_id` 的角色；排除只限同阵营角色，墙体、建筑、地形、敌对角色和昏迷 NPC 仍在原 mask 上阻挡。每子步最多跳过 32 个同阵营 collider，避免异常重叠无限循环。
- `max_range` 只记录 `authored_range_crossed`，不再把箭停在空中；弹体保持释放瞬间的 origin、velocity、gravity 与 aim snapshot，直到第一处合法碰撞或 lifetime 终态。没有目标追踪、release-time 伤害或移动目标兼容补伤，attack id 仍保证只提交一次实际碰撞伤害。
- 远程 windup 一旦起手便持有 cycle target 到 authored release；目标移出射程不取消动作。正伤害在 release 前中断则不生成弹体，在 release 后中断只结束 recovery，活动弹体不被回收。目标死亡 / 昏迷 / 离场在 release 前仍按无效目标取消。
- 终态调用 `CombatProjectileView.stick_at(...)` 保留真实入射方向并把箭头略插入表面。世界 / 建筑以 collider Node3D 为 anchor，NPC 以角色根为 anchor，敌军在伤害前以美术根为 anchor，使致死箭随尸体表现重挂。活动敌军清空时清世界 / NPC 箭，敌军尸体箭随尸体清理；初始化与 GM 强制清场清全部。

## T0247 活体目标全速追击与敌我 RVO 分层

- 敌军追 NPC、我方近战 / 冲锋追敌军属于持续刷新终点的活体追击，不再使用固定落点的 `final_target_braking`。CombatSystem 继续按锁定目标位置更新接敌点，并在真实武器交接距离内停止 ActorMotion、进入原 windup / impact / recovery；基础速度、攻击范围和到点容差没有扩大。
- RVO 只处理同阵营局部人群：NPC、友方马匹与商车位于层 1，步行 / 骑乘敌军位于层 2，各自 mask 只包含本层。敌我相向时不再在攻击范围外互相预测让路；最终仍共享 `actor_body` CharacterBody 碰撞，无法穿过对方、同阵营前排或墙体。
- 普通工作、集结、避战、远程攻击点、建筑 / 塔防引导区和其他固定终点继续使用最终制动。ActorMotion 快照新增 `avoidance_layers / avoidance_mask / final_target_braking_enabled`，用于区分阵营避让与活体追击合同。

## T0246 友方战时奔跑饱食规则

- CombatSystem 只提供 `get_active_enemy_count()>0` 的存活敌军事实，不扣饱食、不判断真实位移。NPC 实体累计未骑乘且实际超过行走档的跑动秒数，NPCNeedsSystem 在逻辑 tick 中消费并以 `-0.1 / 游戏秒`结算。
- 每 tick 可计费秒数不超过该 tick 的游戏秒，且真实跑动样本消费后清空。因此路径重算不重复计费，堵路 / 站定不计费，GM 瞬间推进数小时也不会放大上一帧运动。
- `satiety=0` 的速度钳制位于 NPC 统一 locomotion / ActorMotion profile 边界，所以集结、战斗追击、远程攻击位、保持距离、战斗避战和逃离无需各自实现限速分支。敌军速度、攻击节奏与伤害规则不受影响。

## T0245 移动角色近战锁定伤害点与受击打断

- 普通剑盾 / 长杆对移动角色仍只在目标进入有效范围、攻击线合法且移动权威已释放后起手。`windup` 开始即把本次角色目标写入既有 cycle target；从此到 recovery 结束，目标位置、射程、接敌点或普通索敌刷新不再取消动作。目标死亡 / 昏迷 / 离场仍会使本次目标失效。
- 到 authored impact 秒时，CombatSystem 以 `locked_actor_timeline` 对仍有效的原 cycle target 直接提交一次既有防御 / 穿透伤害，不在 impact 再检查距离，也不依赖该帧模型扫掠。模型端点仍可采样到 `sampled_model_contact` 供表现与量测诊断，但不能提前扣血、换伤害目标或重复提交。
- 攻击者受到正伤害时同步中断当前 `windup / recovery`，并清理 active swing 与 pending commit。`windup` 且 impact 尚未提交时中断为零伤害；recovery 或已提交后中断只终止余下动作，已扣 HP 不回滚。下一次起手仍受原单调 cadence 锁约束。
- 固定建筑 / 城门 / 塔防目标继续走 T0243 引导区与 T0144 模型接触；骑兵冲锋继续走独立碰撞 / 僵直；弓弩继续走物理弹体。这三类不会被移动角色锁定命中旁路。

## T0243 建筑 / 塔防动态稀疏攻击引导区

- `front_gate / warehouse / main_hall / defense_device` 的旧独占 lease、满位回退、waiter 与精确到点攻击门槛已由引导区替代。现有表面采样继续以近战单排、远程六排作为 authored 候选源，但每个候选是 `melee / ranged` 分类的竖直圆柱引导区；圆面半径取执行敌军物理半径，高度当前为 `2.6 m`，同类圆按 `2 × radius + safety_margin` 去重。骑乘敌军因此会比步兵自动保留更少但物理上不重叠的圆。
- 每个敌军权威 AI 更新都用活动 Actor 的实际位置、`enemy_foot / enemy_mounted` 胶囊半径与高度计算圆柱重叠名单。选择顺序固定为“实际重叠人数最少 → 水平距离自身最近 → slot id 稳定排序”，再由生产 NavigationMap 吸附 / 验路；人数变化可在同一目标锁内改写活动移动终点，不排队、不占满，也不按预约计数。
- 引导圆不是攻击许可。系统同时从同类候选的真实 `contact_position` 选择离攻击者最近的合法受击接触点；该点进入有效攻击带后立即暂停 ActorMotion 并进入既有 windup / release / recovery，即使尚未到圆心。远程有效带为当前攻击范围，近战有效带为 `attack_range × melee_reach_ratio`，用于与实际模型扫掠触达保持一致。近战扫掠、远程弹体、宿主墙段身份和 BuildingSystem / DefenseDeviceSystem HP 仍是唯一命中与伤害权威。
- `debug_get_enemy_attack_position_snapshot()` schema 为 `enemy_attack_guidance_zones_v2`，保留 `leases[]` 兼容镜像并新增 `guidance_count / guidance_assignments[]`；记录所选圆、分类、半径、高度、实时重叠人数 / id、换区与射程交接指标。正常运行不再产生固定目标 waiter 或精确到位恢复。

## T0241 敌军战斗重定向速度连续性

- 敌军从一个目标身份切换到另一个 NPC / 建筑 / 塔防目标时，CombatSystem 仍替换 request id、目标坐标、移动用途和到达容差，但 `enemy_*` 运动选项现在声明 `preserve_velocity_on_supersede=true`。ActorMotionBody 仅继承替换瞬间的水平速度，并再次限制到当前物理 profile 上限。
- 继承速度不是最低速度保证。下一帧仍执行路径方向、加速度、RVO、CharacterBody 碰撞与最终落点制动；换到身后目标时反向分量会被剔除，前方拥堵时仍可合法降速。普通 NPC、日常行动与非战斗 request 不启用该选项，继续从静止起步。
- `motion` 快照新增 `requested_speed / desired_speed / candidate_speed / rvo_safe_speed / applied_speed / actual_speed / speed_limit_reason`，以及 `last_motion_preserved_velocity / last_preserved_velocity_speed / preserved_velocity_handoff_count`。原因可为 `profile_cruise / accelerating / intermediate_waypoint_braking / final_target_braking / rvo_avoidance / backward_path_velocity_rejected / physical_collision_slide / paused / arrived / cancelled / failed`，用于区分真正的速度控制与拥堵位移损失。

## T0240 战斗避战的近敌触发与移动权威

- 武装应征 NPC 的“避战”是 `behavior_mode=combat` 内的战术，不进入非战斗 `avoid_combat` 模式。每个战斗步以避战威胁场的 `nearest_encounter` 判断安全阈值；持久 `combat_target_enemy_id` 即使仍锁着远处敌人，也不能压住另一名近敌的避战触发。
- 触发与选点分工明确：最近实际威胁决定“是否需要避战”，圈内全部威胁继续按 T0209 的逆距离平方合成方向，再经站内边界、实体包络和正式 NavigationMap 解析落点。避战路段不攻击、不清除或改写既有攻击目标锁，最近威胁只记录在 `combat_strategy_move_enemy_id` 和 `combat_strategy_avoid_*` 诊断字段。
- `combat_strategy_move_strategy_id=avoid` 标识避战移动权威。切换策略时先结算其他战术的旧请求；活动路段按底层 `is_npc_world_movement_active(...)` 判定，状态文本残留但物理请求丢失时恢复同一已提交终点。到点后重新采样威胁；最近威胁达到安全距离时停止并进入 `combat_strategy_avoid_holding`。
- 世界头顶与地点行动摘要把活动 / 待命分别显示为“正在避战”与“避战待命”。这两个文本是只读投影，不参与触发、移动或目标锁结算。

## T0236 敌军实际移动驱动表现

- 正式敌军步行 / 骑乘移动动画不再只读取 `current_action`。CombatSystem 在物理帧比较 Actor 的实际水平 Transform，记录位移、平面速度、移动方向和停止累计时间；逻辑动作文本只作为尚未获得两帧位置样本时的兼容回退。
- 移动表现采用低速迟滞：活动 ActorMotion 请求的实测速度达到 `0.01 m/s` 即开始移动，已移动者只有在低于 `0.003 m/s` 持续 `0.18 s` 后才停。这样约 `0.06 m/s` 的拥挤 / RVO 爬行仍播放走动；初次激活必须有活动运动请求，无请求的碰撞去穿透不会独自启动走动片段。
- 步行包装以实测速度驱动 run；骑乘包装同步使用 `mounted_walk` 和马匹 Walk。攻击时间线、受击、昏迷、死亡与败退会覆盖普通移动投影；该层不提交移动请求、不选目标、不决定命中或伤害。

## T0235 我方远程战术接近停滞恢复

- `max_output / attack / keep_distance` 的普通远程接近继续使用 T0229 的目标锁与 32 点攻击圆。ActorMotionBody 新增独立 `stationary_elapsed_seconds`：按实体净位移采样，移动目标调用 `update_motion_target(...)` 或 persistent repath 都不会清零，只有新请求 / 新导航腿或真实移动恢复才重置。
- 活动攻击位请求连续 `friendly_strategy_stalled_reselect_seconds=2.25` 无有效位移时，CombatSystem 保留锁定目标，排除当前终点 `friendly_strategy_reselect_min_separation=0.8`，优先选择另一个可导航、可达且攻击线清晰的圆弧点。运行态记录 `combat_strategy_move_recovery_count / combat_strategy_last_stall`，不需要警铃重置。
- 交接安全带仍为实际武器射程 `95%`。攻击点向内预留 `friendly_ranged_attack_position_arrival_tolerance=0.08`，ActorMotion 同一请求使用 `target_desired_distance=0.08`；吸附后必须满足 `endpoint_distance + tolerance <= range × 0.95`。到达容差外沿即可先停止移动再进入真实攻击时间线，射程和静态攻击线均未放宽。
- 保持距离的活动 `1/3` 近身撤离段不进入该状态机；脚步 / 骑乘、弓 / 弩只在恢复普通远程接近后共用本合同。

## T0233 固定目标远程攻击位扩容

> T0243 保留本节六排容量与受击表面几何，但把租约 / 实际到位门槛改为动态稀疏引导与受击体射程交接。

- 敌方弓 / 弩 / 骑射攻击 `front_gate / warehouse / main_hall / defense_device` 时统一使用实际武器射程 `0.90 / 0.76 / 0.62 / 0.48 / 0.34 / 0.20` 的六排。排距同时满足最短远程射程下最大骑乘敌人 `2 × radius + safety_margin`，避免新增纵深位自身发生租约冲突。
- 表面采样与纵深排数分离。正门仍沿门板净宽每排 5 位、总计 30；仓库 / 主厅按四面包络每排最多 32、总计最多 192。城墙塔防单墙代理当前约 5 位 / 排、总计 30；主厅角落塔防在两面相邻墙上各约 5 位 / 排、总计 60。
- `ranged_building_max_positions / ranged_defense_device_max_positions` 只作用于远程每排表面预算。近战仍读取 `building_max_positions=20 / defense_device_max_positions=8`，正门近战五位及塔防 `0.06 m` 精确到位不变。
- 候选不是命中许可。每个位置仍须通过生产 NavigationMap 吸附 / 路径、实体半径租约冲突和实际到位；远程攻击仍复核接触点距离并由物理弹体真实碰撞，建筑 / 器械 HP 权威没有旁路。

## T0232 我方远程保持距离撤离循环

- `keep_distance` 只改变主动远程链的最高优先级前置判断：普通目标域、最近目标锁、射程外 `95%` 攻击圆选点、射线复核与攻击时间线继续复用 T0198 / T0229。步行弓 / 弩与骑射共用同一实现。
- 每次没有活动撤离段、或上一段实际到达后，以最终攻击范围 `1/3` 构建 T0209 同款威胁场：`normalize(Σ ((R/max(d_i,1.0))² × away_i))`。圈内有任意敌军就清空战略锁、攻击目标、重扫请求和未完成攻击相位；原始目标为 `npc_position + direction × attack_range × 2/3`。
- 目标由 `resolve_station_avoidance_navigation_target(...)` 修正到站内、实体外且生产 NavigationMap 可达的位置。活动段保存 target / direction / threats / sequence；物理 request 有效时不重扫，失活且未到点时恢复同一目标。到点后才复扫并续段；安全时清理撤离状态，同一战斗步回到普通目标选择。
- 撤离使用独立 `keep_distance_retreating` 动作状态，移动期间始终保持空目标且攻击数为 0。`friendly_station_response_runtime_v4.keep_distance_retreats[]` 只提供诊断，不成为第二套位移或伤害权威。

## T0231 塔防近战最后到位恢复

> 历史合同：T0243 已取消塔防固定目标的精确到点攻击门槛与 waiter；本节恢复机制只保留为旧 schema 兼容路径。

- 塔防目标的近战攻击位仍以 `melee_attack_position_arrival_tolerance=0.06` 作为攻击许可。普通 `arrival_tolerance=0.32` 只是最后接近恢复带，不能把租约改为 occupied，也不能绕过真实武器扫掠碰撞。
- reserved 租约持有者进入 `melee_precise_arrival_recovery_radius=0.32` 且 ActorMotionBody 连续 `melee_precise_arrival_recovery_stuck_seconds=0.75` 无路径进展后，CombatSystem 暂时关闭该 Actor 的 RVO 避让，让 CharacterBody 沿原 NavigationMap 路径与实体碰撞完成最后接近。路径、速度、墙碰撞和伤害权威均不变。
- 精确到位后立即恢复 RVO 并标记 `arrival_mode=precise_after_avoidance_recovery`；离开恢复带、进入 waiting、释放 / 换目标、受控清理时也恢复。`waiting_for_attack_position` 候补没有租约和攻击权限，不会触发恢复。
- `debug_get_enemy_attack_position_snapshot()` 公开活动恢复与 started / completed / cancelled 指标；ActorMotion 快照公开 `avoidance_enabled / runtime_avoidance_override_reason`。

## T0230 主厅角落塔防双墙受击与分散站位

- 每个主厅角落器械目标同时公开前 / 后墙与同侧侧墙两个局部宿主区域。四槽依次为 `back+left / back+right / front_left+left / front_right+right`；单值 `host_proxy` 继续保留原前 / 后墙主区域以兼容旧调用方。
- 敌军攻击位按两个区域独立取墙面位置、外向法线和局部 `hit_radius`。单器械既有 8 位上限均分为每面 4 位，槽 id 包含区域与采样点；候选继续通过 NavigationMap 可达校验、租约冲突和实体占用，等待者沿已分配区域施压。
- 近战扫掠与弹体碰撞逐区域匹配 `building_id + building_segment_id/fixture_id + hit_radius`。任一相邻墙面局部命中只扣同一器械 HP；同墙远端、无关墙面和主厅其他碰撞不算器械命中，主厅 HP 不连带下降。

## T0229 远程攻击位与战斗移动自恢复

- 弓、弩和骑射持有合法目标锁时，以最终武器射程的 `95%` 作为移动 / 攻击交接安全带。目标在该距离外时，无论当前策略为 `max_output / keep_distance / attack`，都必须生成远程攻击位，不能保持 `combat_ready` 原地等待。
- 攻击位以目标为圆心采样 32 个圆弧候选。每个候选必须能吸附到执行 NPC 的生产 NavigationMap、存在从 NPC 到候选的路径，且优先要求候选到目标的正式 world-static 射线畅通；从合法候选中选择水平距离 NPC 最近者。若暂时没有无遮挡候选，仍向最近可达圆弧点推进并在后续战斗步复核。
- 活动策略移动会随锁定目标移动更新攻击位；目标更换时收束旧请求并为新目标重建。到位后仍超过 `95%` 射程、攻击线被墙 / 门阻断，或 `moving_to_combat_strategy_*` 文本仍在但 ActorMotionBody request 已失活时，下一权威战斗步重新选择 / 补发，不释放穿墙弹体。
- rally 路线跨正门边界时按 NPC 当下地点使用正式目标域：站外为普通 `37.2 m` 半径，站内为“整站 + `37.2m`”并集；站外响应者破防时使用 `station_breach_global / station_enemy_only`。合法目标锁继续阻止警铃重派，战斗移动恢复不依赖铃声。

## T0228 主厅塔防墙面接敌与受击

- 主厅器械继续从屋顶平台射击，但作为敌军目标时使用该槽对应的 `back_wall / front_left / front_right` 低位宿主代理。代理提供独立 `outward_direction`，攻击位、接触点和敌军朝向均落在对应外墙外侧，不读取屋顶器械的展示朝向。
- 近战扫掠或敌方弹体必须真实碰到相同主厅墙段且处于该槽局部 `hit_radius` 内，才解析为 `defense_device` 命中；伤害只提交给 DefenseDeviceSystem，主厅 HP 不变。屋顶平台自身仍可作为同一器械的合法远程碰撞代理。
- 四槽当前解锁为前侧 `slot_03/04=Lv.1/3`、背侧 `slot_01/02=Lv.5/6`，六级容量继续为 `1/1/2/2/3/4`。

## T0227 上马回调与集结导航恢复

- `handle_npc_mount_ready(...)` 不再对 `combat` 分支只写 `combat_ready`。`rally / combat` 来源都生成一次刚上马集结命令；`_start_npc_rally(...)` 先用 `_find_rally_combat_encounter(...)` 检查当前目标，无目标才切 `rally` 和发起世界移动。
- 无旧 reservation 的直接接敌骑手使用 `_build_mount_completion_rally_entry(...)`；该入口只忽略其他 NPC 的目标锁来构建稳定阵形，仍保留入伍、主武器和可行动资格。
- `_advance_rally_units()` 对 `status=moving` 的未到位者校验 `current_action + is_npc_world_movement_active(...)`。导航失活时 `_request_rally_movement(...)` 补发同一 target id / position，并记录 `movement_recovery_count / last_movement_recovery_reason`。

## T0226 避战导航活性与恢复

- `_advance_avoidance_units()` 将状态文本与物理移动分开：只有 `moving_to_avoid_shelter_*` 且 `NPCSystem.is_npc_world_movement_active(...) == true` 时才继续等待到达。
- 若 NPC 未到避战点而物理请求已失活，圈内有敌时重新计算加权目标并发起移动；圈内暂无敌时使用运行态保存的原目标恢复路段。
- `active_avoidances[]` 保留 `movement_recovery_count / last_movement_recovery_reason`，仅作 GM / 测试诊断。HP、行为模式、威胁半径、加权方向、导航和逃离权威均不变。

## T0225 驿站破防全体武装应征者全局索敌

- `interior_polygon` 内只要存在一名存活活动敌人，仍在站外集结位、取马路线或其他地点的已入伍持武器 NPC 使用 `station_breach_global`，不再被本人 `37.2 m` 圈挡住。
- 站外破防域只收集站内敌人并按水平距离首次锁定最近者；站内 NPC 则使用 T0321 的“整站 + 本人 `37.2m` 圈”并集，更近的圈内站外敌人可以按正常最近逻辑取得锁。当前锁有效时继续保持，失效或异源受击重扫仍使用当下 scope。
- 最后一名站内敌人离开 / 消失后，站外友军恢复普通 `37.2m` 域，站内友军保持并集域。坐骑会合、最大化输出、保持距离、主动进攻、战斗避战、射程、寻路与攻击结算仍由原系统处理；T0229 起远程最大化输出在射程外也必须先取得攻击位。“已锁目标”不等于已经满足攻击起手条件。

## T0224 统一警铃集结与目标锁边界

- HUD / GM 警铃共用 `CombatSystem.trigger_combat_alarm(...)`。响应集合为“已入伍 + 有主武器 + 可行动 + 当前无合法攻击目标锁”，不再排除睡眠者，也不按工作、避战、旧集结或无目标战斗模式过滤。
- 只有 `combat` 模式中指向仍存活活动敌人的 `combat_target_enemy_id / combat_attack_target_enemy_id / combat_strategy_move_enemy_id` 会阻止警铃重派。该 NPC 的模式、目标、移动、攻击 sequence 和旧 rally 记录保持原样；其他响应者原子清理旧避战、战术移动、目标锁与未提交近战运行态，再建立本轮阵位。
- 已上马响应者保持骑乘并直接向正门阵位移动；有坐骑分配但未上马者保留 HorseSystem 会合链。集结即时检查与逐步检查均复用 `_get_friendly_target_scope(...) + _find_nearest_friendly_combat_enemy(...)`，不再使用独立 5 米接触圈；发现合法敌人后写入目标锁并转正常战斗。

## T0223 主厅器械射程与昏迷表现边界

- 主厅四个通用器械槽的基础 `range_multiplier` 统一为 `1.0`；弩床 / 箭塔部署在主厅时保持定义中的基础有效射程，不再获得高台加成。围墙 Lv.3 / Lv.5 的累计 `+5%` 宿主加固收益保持原样。
- DefenseDeviceSystem 仍独占最终有效射程、自动选敌和攻击结算；UI、世界圆环与敌军威胁感知只读更新后的 deployment 快照。取消主厅倍率不改变伤害、穿透、攻速、器械 HP、槽位曲线或目标优先级。
- NPC 昏迷权威仍只来自 NPCSystem 的 HP 与 `30%` 复苏门槛。ChibiCharacterPilot 仅让非循环 `Death_A` 在首次倒地后保持末帧；昏迷期间的 profile 刷新不得重播倒地，只有 `unconscious=true → false` 的权威边沿才播放 `Lie_StandUp`。

## T0222 敌军选择与只读观察边界

- 正式敌军 Actor 继续使用既有 interaction-only `InteractionArea`，仅新增左键选择并发送 `enemy_clicked(enemy_id)`；该 Area 不参与武器、弹体、冲撞或世界碰撞查询。
- CombatSystem 公开敌军详情与人物构图只读快照，详情来自 `_active_enemies`，人物位置与朝向来自正式 Actor；EnemyPanel 不取得写接口，不改变 HP、索敌、攻击相位、攻速、租约、移动或骑乘状态。
- 骑兵人物快照使用较高焦点 / 相机高度，让共享世界小窗对准骑手；下马后回到普通构图。选择切换仅控制 UI 可见性和 SubViewport 更新，不打断敌军当前行动。

## T0221 骑乘集结离厩不折返

- HorseSystem 完成真实马旁会合后仍由 CombatSystem 恢复原 `combat_rally_*` 阵位；移动层现在保留已开始的马厩出口阶段，集结目标刷新不会把骑手重新拉向 `interior / door_inside`。
- 四名骑手同时离厩继续保留 `0.65 m` 实体胶囊、RVO、正式门洞和真实碰撞。已经越过门外横截面的骑手不会与后续骑手对顶；专项记录四人门外向内回退均为 `0.0 m` 且全部集结完成。
- 本次不改变上马资格、骑乘速度、阵位、门体开合、攻速、伤害或敌方索敌；相同单调出口规则也覆盖敌军从任何可进入建筑重新追击室外目标。

## T0220 敌方远程建筑多排攻击位

> 历史基线：本节的三排 / 60 位上限已由 T0233 六排固定目标规则取代；其余租约与近排优先合同继续有效。

- 敌方弓、弩和骑射攻击正门 / 仓库 / 主厅时，固定候选由单排扩为射程 `72% / 50% / 30%` 的外、中、内三排。每排共享同一建筑表面接触点，只有站位纵深不同；攻击射程、弹体、起手间隔和真实碰撞伤害不变。
- 正门每排沿门板净宽生成 5 位，共 15 个远程位；仓库 / 主厅先按原四面包络挑选最多 20 个表面样本，再逐排展开为最多 60 位。`building_max_positions=20` 现在表示每排表面样本上限。近战仍为单排，正门仍是五个门板位。
- 每排候选独立验路和租约，分配继续按车道稳定性 / NavigationMap 路径距离选择。已在内排附近的敌人会取得内排；每个候选仍须实际抵达后才从 `reserved` 变为 `occupied`，因此扩排不改变 T0207 的实际占满规则或 T0211 waiter 政策。
- NPC 目标仍无固定槽位；塔防代理仍为单排。运行态租约 / 目标增加 `range_row_index / range_row_count / range_row_ratio`（目标装饰前缀为 `attack_position_`）用于诊断，不授予额外攻击权限。

## T0218 正门友军传感的昏迷边界

- 带 `npc_id` 的友方只有当前未昏迷时才触发正门；在传感范围内被击昏会立即退出友军判定，门按既有保持时间关闭，不等待物理碰撞更新。
- 原地复苏后恢复正常开门。该过滤不影响友方马匹 / 商队车、敌军拒绝、五个攻门位、固定门板战斗 Area 或伤害结算。

## T0217 友方马匹开门与活动门叶无碰撞

- 正门友军传感现接受 `npc_id`、无敌军身份的 `horse_id` 和 MerchantWagon；`enemy_id` 仍先行排除，因此敌方骑兵 / 马匹不能触发开门。
- 正门活动门叶从开始开启到完全关闭期间关闭物理碰撞，只在完全闭合且未摧毁时恢复。回站 NPC / 马匹不会再被旋转门叶横向推挤、加速或卡死。
- 敌军攻门不读取活动门叶碰撞，仍由 T0214 固定门板战斗 Area、五个门板攻击位、租约和真实武器接触结算；活动门叶对敌我双方均无物理碰撞，但不会改变敌军攻门目标或授予额外伤害。

## T0215 击昏目标后的实体交接

- 敌军击昏 NPC 后仍由统一索敌器在下一战斗步释放旧目标、清除旧攻击相位并选择建筑或其他单位；`pressing_to_warehouse` 等移动请求继续由 ActorMotionBody 执行，未新增传送或战斗特例。
- 昏迷 NPC 的倒地模型和 InteractionArea 保留，但 BodyCollision 与 NavigationAgent 避障实体关闭。紧贴原目标的敌军不再被一枚不可见的直立胶囊挡住，可以沿新目标路径离开；复苏后两者恢复。
- 该规则不改变伤害、昏迷、30% 复苏、治疗人数、攻击位租约、攻速或建筑优先级。专项同时断言目标切到仓库、战术暂停清除、真实位移、速度上限、昏迷可交互和复苏实体恢复。

## T0214 战时正门通行与攻击权威分离

- 活动敌军不再锁闭正门自动门。友军进入传感范围照常开门，敌军 `enemy_id` 仍被过滤；门叶离开 / 回到门洞只改变物理通行，不写索敌、突破、租约或 HP 状态。
- CombatSystem 的 `front_gate` 优先级、5 个门板位、5 租约 + 3 waiter 规则不读取 `open_fraction`。打开状态与关闭状态生成同一组实际旋转门体候选。
- 正门门板平面新增固定非阻挡战斗接触 Area。它使用独立的敌军攻门查询层并携带 `building_id=front_gate`，但不阻挡 CharacterBody，也不会截断友军穿过开门射击；敌人仍须先有正门目标、合法攻击位和真实武器 / 弹体接触，开门不会提供逻辑补伤。

## T0213 集结超时下马返厩与重新鸣警

- `rally` 到点等待 1 游戏小时未接敌后，CombatSystem 仍将 NPC 切回 `work`、删除 active rally 且不请求计划重评估。若该 NPC 已骑马，HorseSystem 以骑手此刻物理位置作为下马点，保留分配并启动正式导航返厩；不再使用上马时缓存位置或直线插值。
- 返厩速度由 `horse_defs.return_to_stable_speed=3.2 m/s` 单独定义为步行，不复用敌方逃马、骑兵冲锋或集结奔跑速度。移动权威是与 NPC 共用的 ActorMotionBody，表现层只播放 `Walk` 并按实际速度转向。
- 返厩途中再次触发警铃时，HorseSystem 先冻结马匹当前位置，并让骑手寻路到马旁可达点。完成上马后调用 `handle_npc_mount_ready(...)`，CombatSystem 才将本轮 rally 从 `mounting` 改回 `moving` 并恢复既定阵位；马匹等待期间不自行靠近骑手。

## T0212 骑兵败退坐骑正常奔跑速度

- 骑马敌军 HP 清零后，敌军单位仍立即退出活动战斗；保留的纯表现包装继续播放骑手 `Death_A` 坠马并让马向地图外逃离。
- T0212 的逃马速度合同已由 T0242 废止：CombatSystem 不再把 `move_speed` 传给阵亡包装，敌方马匹阵亡后保持零位移并与骑手一起延时清理。
- 快照公开 `escape_speed_mps / escape_speed_source=enemy_move_speed / maximum_escape_frame_displacement`。路线、边界释放、暂停冻结、骑手可见时间和所有 HP / 伤害 / 胜负权威不变。

## T0211 等待攻击位持续施压

- `waiting_for_attack_position` 仍保留当前索敌目标，并从该目标的兼容攻击位中稳定选一个 `desired_attack_position_id`；快照以 `attack_position_wait_movement_policy=pressure_assigned_attack_position` 标识。移动终点是该真实候选的 NavMap 吸附位置，而非入队位置或后排队形点。
- 期望位置不创建租约、不写 `occupied`、不开放攻击时间线。候补只能由现有实体碰撞停在前排后方；槽位释放仍按距离 / 入队 sequence 调用原晋升流程，更高优先级目标仍可由 T0196 索敌器抢占并清理旧队列。
- `attack_position_policy` 将候补 / 正常攻击者 RVO 基准优先级分别设为 `0.20 / 0.55`，并保留 `0.08` 身份微差。候补因此对在途租约持有者和已占位攻击者让行；前排静止攻击者不会被挤走，同阵营候补也不会阻挡既有近战扫掠的真实建筑接触。
- `verify_t0211_attack_wait_pressure.gd` 锁定 4.00→0.88 m 施压、前排零位移、胶囊净阻挡、候补零租约 / 零攻击及释放后晋升；T0195 同时记录自然弩床候补的期望槽位与移动政策。

## T0210 敌我共用室内出口前缀

- CombatSystem 继续独占索敌、目标锁和接敌点；若敌军或友军 ActorMotionBody 当前在可进入建筑室内、战斗最终目标在建筑外，移动层先执行该建筑正式反向门路，再追同一目标。诊所内原目标昏迷 / 失效后，重新锁定室外目标会因此先出门，不再尝试从室内直接连接远端接敌点。
- 前缀点与最终目标在同一个 motion request 中推进。对同一目标的实时位置更新不改变当前前缀腿或 request id；最后 `entry_outside` 完成后才恢复动态接敌终点。攻击周期、目标优先级、武器距离和伤害提交均未改变。

## T0209 站内多敌加权避战

- 避战圈 `R=39.2 m`，来自敌军统一索敌 `37.2 m` 加 `2.0 m` 余量。圈内每名敌军 `i` 贡献水平反向单位向量 `u_i=(npc-enemy_i)/d_i` 与权重 `w_i=(R/max(d_i,1.0))²`，最终方向为 `normalize(Σw_i u_i)`；抵消时回退最近敌人反向。
- 原始目标固定为 `npc + direction × R`。StationLayoutController 沿该射线限制到 `interior_polygon` 内，再从目标向原点有界采样生产 NavigationMap，拒绝建筑 / 附属物 / 墙 / 门包络。修正只影响实际目标，不改变原始方向和半径诊断。
- 自动非战斗避战与显式 `avoid_combat` 共用该算法；`active_avoidances` 记录 `threat_count / threats[].distance / weight / away_direction / avoidance_direction / desired_target_position / boundary_limited / navigation_adjusted`。移动仍由 NPCSystem / ActorMotionBody 执行，避战不离站。

## T0208 正门五个门板攻击位

- 正门固定近战带当前为五槽，`target_outlines.front_gate` 使用 `width=4.8 / position_count=5`，沿实际门体局部横轴生成 `2.4/1.2/0/-1.2/-2.4 m`。五个接触点都在门板平面和门洞范围内。
- 左右门塔继续拥有物理碰撞与导航阻挡，但不再是正门攻击面。候选生成器已删除“最外槽攻击塔面”的前移、专用站距和接触偏移；碰到相邻墙段也不再通过旧七槽 ID 代算正门命中。
- 第一波 8 人当前为 5 个独占门板租约 + 3 个正门 waiter。五个租约全部实际占用后，正门仍按强制破口例外保持三个候补，不越门选择仓库。

## T0207 固定攻击位的预留与实际占用

- 固定目标攻击位保留两阶段状态：分配成功后为 `reserved`，敌人实体进入该租约的到达容差后才由 `_has_enemy_reached_attack_position(...)` 提交为 `occupied`。目标快照同步投影真实租约状态。
- 租约分配继续让 `reserved` 与 `occupied` 都参与空间冲突，保证同一槽位不会发给两名敌人；索敌预览使用同一冲突几何的 `occupied_only` 视图，只有实际占用才消耗目标容量。全槽仅在途预留时返回 `available / reserved_in_transit`，全槽实际占用时才返回 `full`。
- 塔防、仓库和主厅仅在实际满位后对后来敌人视为消失；完整正门仍是强制破口例外。T0211 起 `reserved_in_transit` 候补压向真实槽位并以较低 RVO 优先级让行；槽位释放后仍复用原候补晋升。
- `verify_t0207_attack_position_actual_occupancy.gd` 覆盖全预留、部分占用、全占用、索敌降级和候补期望槽位；T0195 自然整波继续验证精确到位与连续真实塔防伤害。

## T0204 正门对称几何与双塔实体（攻击槽数量已由 T0208 覆盖）

- 正门攻击几何以 `StationLayoutController.get_building_combat_geometry("front_gate")` 返回的实际门体中心、右轴与外法线为准，不再用偏斜的路线 staging 向量决定攻击朝向。当前五槽沿门体局部横轴严格对称；中槽位于门洞中心，左右成对槽位互为镜像。
- T0204 曾让最外两槽落在塔面；T0208 已删除这两个槽和全部塔面接触特例。双塔碰撞与导航绕行仍保留。
- 正门槽位仍按可达性和租约分配。分配排序先把敌人的入场车道投影到门平面，再在五个合法门板候选中取最近横向槽；这只决定“选哪个空槽”，不改变目标、攻击位容量或路径权威。
- `verify_t0204_front_gate_alignment_and_tower_collision.gd` 当前锁定五个门板槽镜像、门法线、双塔射线命中、生产导航绕塔、`6.0 m` 门洞净宽及 5 租约 + 3 waiter；T0203 / T0180 / T0186 继续锁定五人全部真实伤害。

## T0203 正门攻击位导航落点权威

- 固定目标攻击位候选在租用前先吸附 NavigationMap 并完成路径可达性验证；该已吸附 `position` 是本次租约从移动到攻击交接的唯一权威终点，不能在后续 AI 刷新中被未吸附的 authored candidate 覆盖。
- 原始候选位置仅保存在 `authored_position` 供诊断；静态建筑 / 塔防租约继续刷新 `contact_position` 与目标事实。敌人失去目标、角色改变、目标失效或路径失败时仍按既有合同释放并重新申请租约。
- 这项修复不增加 `arrival_tolerance`，也不改变武器射程、攻击周期、门柱碰撞和 T0144 真实模型接触。`verify_t0203_front_gate_attack_handoff.gd` 从自然第一波生成到真实攻击，要求当前 5 个正门门板租约持有者全部实际扣门血。

## T0202 友军单序列表现与清敌收口

- 艾达的权威伤害起手仍由 T0193 `combat_attack_next_sequence_time` 限制；本次没有调整剑盾 `attack_interval`、技能倍率、impact 比例或伤害。60 Hz 实测约 `1.048 s` 完整周期，连续起手落在 `1.033–1.050 s` 的一帧采样误差内。
- 攻速异常来自表现层：非循环攻击 clip 已播放完，但 CombatSystem 仍处于同一 sequence 的 recovery 尾部；NPC profile 再刷新时，旧 `_play_state` 因 AnimationPlayer 已停止而重新播放该 clip。现在同一 sequence 的 windup / recovery 在末帧保持，只有 sequence 变化才 reset 并开始下一剑。
- 活动战斗仍存在但 `_active_enemies` 已空时，逻辑 tick 和友军攻击步都必须进入 `_handle_all_enemies_cleared(...)`，不得提前返回。收口清空友军近战 sweep / pending damage、战略锁、攻击锁、phase / elapsed / cycle 与可见行动，再按既有规则让 combat / rally / avoid_combat NPC 返回工作。
- `verify_t0202_friendly_attack_cleanup.gd` 锁定“艾达 windup 中由外部入口移除最后敌人”的边界；`verify_t0193_friendly_attack_cadence.gd` 继续锁定真实 sequence 间隔、跨中断时间锁、T0245 角色 impact 伤害与单 sequence 零回卷。

## T0200 敌我统一战斗寻路

- CombatSystem 继续先按 T0196 / T0198 锁定“打谁”，再按单位当前武器解析距离、近战接触或远程弹道条件。未满足攻击条件时，只向该目标周围距离自身最近且可达的合法接敌点移动；路径长短、道路、门和暂时拥堵不得反写目标优先级。
- 敌我战斗请求统一携带 `shared_combat_navigation_v1`：无遮挡时 NavigationMap 给出近似直线最短路，静态建筑 / 围墙 / 家具 / 自然阻挡由 collider-baked NavMesh 绕行，活动实体先由 NavigationAgent3D RVO 局部避让。目标显著移动时更新同一个 request 的终点；路径失效或持续无进展时按既有限频率重规划，直到进入攻击条件或目标失效。
- 普通生活 / 工作移动仍保留最大重规划次数与卡死超时；战斗追击不会因为达到该普通上限而永久停住。进入武器有效条件后先释放移动权威，再进入既有起手锁与模型接触 / 弹体时间线，不允许边移动边攻击。
- 城外生产 NavMesh 现覆盖正式敌军生成区到驿站外墙，旧 `EnemyApproachNavigation` 狭长廊道不再创建。敌军路线数据只用于生成 / 阶段表现，道路只用于美术；墙体、密林和其他正式静态碰撞仍是实际阻挡。
- 正门五个独占攻击位按门板净宽布置；首波 5 人均须到位并通过模型接触造成伤害，其余 3 人继续遵守完整城门 waiter 规则。敌我每个角色使用稳定身份哈希产生的微小 RVO 优先级差以打破对称礼让，它不改变目标、路径或攻击位。同阵营活动角色交由 RVO / 接敌移动处理，不作为近战武器扫掠的世界阻挡；静态场景与敌对实体仍按首个真实接触裁决。
- 塔防宿主代理的近战租约使用数据化 `0.06 m` 最终到达半径，由 ActorMotionBody 的 per-request `target_desired_distance` 执行；它防止普通 `0.32 m` 到达容差让敌人在真实剑模型扫掠之外提前停步。三座建筑保留各自已校准的普通到达合同，武器射程、攻击周期、伤害和代理碰撞身份不变。
- T0195 自然整波回归现在必须观察至少三个独立器械 HP 下降帧，并断言塔防近战实际到位不超过 `0.08 m`；首次扣血不再足以通过。

## T0198 友方分域在场锁与异源受击重扫

- 全部持武器友方 NPC 只使用 `friendly_enemy_presence_lock_v1`。站外 NPC 使用精确 `37.2 m` 水平圈；站内 NPC 使用“完整驿站内敌人 ∪ 本人 `37.2m` 圈内敌人”，因此既保留整站感知，也能在敌人尚未跨过多边形、但已进入本人索敌圈时主动接敌。
- T0225 起，只要驿站内仍有敌人，站外武装应征者改用 `station_breach_global` 跨距离锁站内敌人；站内武装应征者继续使用并集域。并集内所有目标使用同一水平距离排序，不设置“站内优先”。
- 没有有效锁时按水平距离选择最近敌人；当前敌人仍有效且仍在当前分域时持续保持，不因另一敌人后来出现或变近而跳锁。`combat_target_enemy_id` 同时约束策略移动、武器射程复核、windup / impact 和状态显示，不能在移动层与攻击层各选一个目标。
- 当前锁定期间，另一个敌人经 `_apply_enemy_attack_to_npc(...)` 正式链实际扣除 NPC HP 后，记录一次 `friendly_enemy_damage_reacquire_request_v1`。下一次选择只绕过在场锁一次：站外普通域重扫本人 `37.2 m` 圈，站内域重扫“整站 + 本人圈”并集，站外破防域重扫整座驿站，并按当前距离取最近者；不强制精确反击伤害来源，目标域外来源可触发重扫但不能越域成为目标。
- NPCSystem 受击路由只负责进入战斗模式，不再在每次受击时重进 combat、打断导航或把目标强写成攻击者。异源换锁可取消当前动作阶段与重建追击，但不能清除 T0193 `combat_attack_next_sequence_time`；瞬时请求不进入正式空间存档。

## T0197 / T0199 实际伤害的一次性最近重锁

- 当前目标为持武器 NPC / 塔防时，另一高威胁来源实际扣除敌人 HP 会记录一次请求；当前目标为无武器 NPC 或三座合法建筑时，任一持武器 NPC / 塔防实际扣除 HP 也会记录。请求为 `enemy_high_threat_damage_reacquire_request_v2`。当前高威胁目标自身伤害、零伤害、陨石等非 NPC / 塔防来源不触发。
- 下一次 `_select_formal_dynamic_enemy_target(...)` 在普通在场保持分支之前消费该请求，从精确 `37.2 m` 高威胁候选池按水平距离选最近者；它不是“反击伤害来源”，所以圈外攻击者不会被强拉入池，旧目标若仍最近也可重新选回。请求消费后立刻恢复 T0196 在场锁。
- 目标切换继续只取消当前 windup / recovery 或接敌移动，不能清除 T0191 的 `attack_next_sequence_time`；伤害、模型接触、弹体和攻击周期均未改变。请求是可观察但不进存档的一次性运行态。

## T0196 敌军统一半径与在场锁

- 全部活动敌军只使用 `enemy_unified_presence_lock_v3`：主 AI 调度不再按 `dynamic_combat_pressure` 标记回退旧 `target_preference` 选择器。所有兵种共用精确 `37.2 m` 水平索敌半径；圈内持武器 NPC / 塔防可用时立即优先于无武器 NPC、城门、仓库、主厅。动态标记只决定攻击位和运动实现，不决定目标优先级。
- 实际伤害的一次性圈内最近重评估同时覆盖高威胁在场锁和低优先级当前目标：当前锁定另一持武器 NPC / 塔防，或正在追无武器 NPC、攻击城门 / 仓库 / 主厅时，被持武器 NPC / 塔防实际扣 HP 都会在下一选择重扫全部圈内可用高威胁。当前高威胁目标自身命中、零伤害和非战斗来源排除；塔防满位仍按目标消失规则处理，完整城门满位例外不变。
- 持武器 NPC 与活动塔防是同一个高优先级池。没有有效单位锁时按水平直线距离选最近者；锁定后只要目标仍有效且在圈内便保持，不因同级单位后来出现或变近而换锁。塔防无兼容固定位置时对该敌人视为消失。
- 无武器 NPC 只在高优先级池为空时参与，首次按最近距离锁定并在有效 / 圈内时保持；任何持武器 NPC 或塔防进入圈内都会立即抢占。NPC 不申请攻击位、不排队且无容量上限，多名敌人可直接锁定并围攻同一 NPC。
- 圈内没有 NPC / 塔防时，只能按 `front_gate → warehouse → main_hall` 选择。塔防、仓库和主厅无兼容空位时对该敌人视为消失；完整城门是强制破口，满位仍保持城门目标并进入 waiter，不能越门锁定仓库。训练场等其他建筑永不进入候选。不可达性属于后续寻路问题，不改变本层目标类别；本任务没有修改导航算法。
- 目标变化只取消当前不再合法的接敌动作，T0191 单调起手时间锁、T0144 模型接触和各 HP 结算权威不变。`verify_t0196_unified_enemy_targeting.gd` 是当前目标合同；T0150 / T0194 的旧入口转发该专项。

## T0195 塔防严格优先与自然接敌闭环（历史，索敌政策已由 T0196 取代）

- T0194 解决了塔防不进入候选，但完整第一波仍暴露攻击位满员降级：墙弩剑盾位为 5 个，第 6–8 名敌人会选城门。现在 `defense_device_full_policy=queue_before_buildings` 将塔防设为建筑层严格屏障；有可达塔防时，满位敌人进入该塔防的 T0149 候补，不能申请建筑位。
- 自然路径专项从 GM 正门外测试区生成 8 名第一波敌人，不删除、不传送；全部目标帧保持塔防或塔防候补，城门目标帧 `0`，剑盾敌人最终抵达墙外攻击位并以正式模型接触让弩床 `55 → 51`，城门 HP 不变。
- 该政策只阻止“塔防满位→建筑”降级；NPC 层、塔防不可达时的合法阻挡物、塔防摧毁后的建筑回退、攻击节奏和物理命中规则均不变。

## T0194 敌军受击反击与塔防射程覆盖感知（历史，索敌政策已由 T0196 取代）

- 正常顺序仍是 `NPC → 塔防 → 城门 → 仓库 → 主厅`。塔防候选不再和 NPC 共用固定 `6 m` 半径：DefenseDeviceSystem 输出每个实例合并宿主倍率后的 `effective_attack_range`，CombatSystem 以“该射程 + `1.5 m`”建立逐目标感知圈，因此能攻击敌军的墙上器械不会因索敌圈更小而被城门抢走。
- 敌军当前目标为三座合法建筑时，`_apply_damage_to_enemy` 提交的最后一次 NPC / 塔防实际命中成为精确反击目标；该目标越过普通同类距离排序和短目标锁。旧建筑攻击尚在 windup 时立即换目标，impact 已提交的 recovery 只允许收尾一次。
- 当前目标为仍有效且攻击位仍可用的 NPC 时，近期受击只记录事实，不把敌人从该 NPC 拉向另一 NPC / 塔防。伤害来源不可达时继续遵守宿主代理、白名单阻挡和攻击位回退，反击不授予穿墙或必中能力。

## T0193 我方单位跨中断攻击起手锁

- 全部我方武装 NPC 与敌军共用 CombatSystem 单调战斗时钟。每次友军合法起手写入 `combat_attack_last_sequence_time`，并按该 NPC 当前装备 / 技能 / 骑乘状态解析出的完整 `cycle_seconds` 计算 `combat_attack_next_sequence_time`。
- 接触丢失、目标变化、策略移动、windup / recovery 取消或短暂行为模式切换只清当前 phase、elapsed、锁定目标与模型接触采样；只要本场敌人仍在，next sequence time 不得清零。旧 `combat_attack_cooldown` 仅投影剩余等待并兼容旧状态，不再决定新 sequence。
- 普通角色近战仍只在合法范围内起手，并于 authored impact 对原 cycle target 提交一次伤害；固定目标仍须模型接触。弓 / 弩仍只在 impact 释放带 attack id / sequence 的正式弹体。时间锁不会开放超距起手、改变播放倍率或让一次动作重复伤害。
- 战斗真正结束时清除全部 NPC 的 last / next / remaining，下一波独立开始。正式空间存档保存 `combat_attack_sequence` 与相对 `combat_attack_sequence_lock_remaining`；联合读档跨中间清场事务恢复相对量，下一友军步再对当前单调时钟重建绝对时间。
- `verify_t0193_friendly_attack_cadence.gd` 锁定每 0.2 秒取消压力、一次真实 behavior mode 往返、正式角色同 sequence 不回卷、压力后真实伤害以及联合存读档不赠送起手。

## T0192 友军战术移动存活与攻击交接

- 策略接近点、保持距离点和骑兵冲击拉开点必须投影到“执行该动作的 NPC 当前实际绑定 NavigationMap”。不得用 `_default_formal_wave_active` 等运行模式布尔值判断坐标空间：GM 正式动态波次同样位于生产地图，但该标志为 false，旧逻辑曾把仓库 `(24.69, 21.06)` 附近接敌点夹到旧边界 `(14, 18.5)`。
- NPCSystem 的 `get_npc_navigation_closest_point(...)` 只读当前角色的 NavigationMap RID 并返回最近可达点。只有 NPC 不存在或没有有效 map 时，CombatSystem 才退回旧兼容矩形；正式运行和正式 GM 波次必须得到同一空间结果。
- `current_action=moving_to_combat_strategy_*` 只是领域状态，不再被当作导航存活权威。`NPC.is_world_movement_active()` 通过 NPCSystem 向 CombatSystem 只读暴露当前 ActorMotionBody request 是否真正 active。
- 战术移动状态仍在、但物理请求已停止时，CombatSystem 统一清理旧 movement target / strategy target，记录 `combat_strategy_stale_movement_recovered`，并在同一战斗步按敌人当前位置重新提交追击；不依赖丢失的到达回调。
- `attack / keep_distance` 追击交接保持严格武器射程，但近战活动追击不在射程最外沿立即停步：接近点先在 `range * 0.85` 站距内向再预留数据化 `arrival_tolerance`，进入 `range * 0.85` 内侧安全起手带后才取消实际移动并允许攻击时间线起手。远程仍按完整射程交接；同一物理帧不允许导航与攻击同时控制身体。
- 交接判定没有修改武器 `range / attack_interval`，攻击仍须经 windup 后由真实模型接触提交伤害。`verify_t0192_friendly_warehouse_intercept.gd` 使用正式第一波实体和仓库拦截几何，显式取消中途 request，锁定自动恢复、无长时间静止移动、正式攻击和真实掉血。
- `verify_t0192b_friendly_occupied_approach.gd` 使用 GM 正式动态波次和三个相邻仓库攻击者，不再在首次掉血时结束；必须击杀模型接触实际命中的任意首名敌人，再切换并伤害存活敌人。专项不依赖相邻三者中任意一个不稳定的出生 ID。任何“导航已到达但武器尚不可靠接触”的边界空档都必须失败。

## T0191 敌军跨中断攻击起手时间锁

- 敌军完整攻击周期只读取自身规范 `attack_speed / attack_interval` 与武器 `CombatAnimationTiming`；NPC、塔防或建筑目标不得改变 cycle、impact、playback multiplier 或每周期一次的伤害提交上限。目标类型只决定碰撞身份与对应 HP / 防御结算入口。
- 第一波剑盾兵生产值为 `0.38 次/秒`，即 `2.6316 s` 完整周期、`0.5263 s` 模型命中点、`0.5067` authored 播放倍率。对艾达与对城门的时间轴探针完全一致；自然物理帧允许的采样误差下，连续起手实测为 `2.60–2.65 s`。
- CombatSystem 维护只随权威战斗步进增长的 `_combat_timeline_seconds`，每次敌军起手写入 `attack_last_sequence_time / attack_next_sequence_time`。距离、攻击位、寻路、目标变化或僵直造成的 `_cancel_enemy_attack_timeline()` 只清当前相位和模型接触，不得清除下一次合法起手时刻。
- 重新进入攻击范围时，若时间锁尚未到期，敌人保持 `combat_ready`，不增加 sequence、不重播 attack clip、不提交伤害；到期后才建立一个新的完整 windup / impact / recovery。粗步进仍可沿同一时间光标消费等待与动作相位。
- 多名敌人可在不同攻击位同时完成各自周期，因此同一目标承受的总伤害频率可能高于单兵频率；这不反向缩短任一敌人的周期。`verify_t0191_enemy_npc_attack_cadence.gd` 同时锁定目标不变量、每 `0.2 s` 中断压力、正式动画无单序列回卷、逐敌间隔、艾达还击与双方真实掉血。

## T0189 暂停时敌军实体运动权威

- `CombatSystem` 连接 `EventBus.gameplay_pause_changed`，并在物理帧入口同步路线试点、活动切片与正式波次的全部 `ActorMotionBody`。暂停调用幂等 `set_motion_paused(true)`，由运动体统一清零 CharacterBody velocity、NavigationAgent velocity / forced velocity 与 RVO safe velocity，且不取消活动 request。
- 正式动态敌军在 slice 中保存 `tactical_motion_paused`。有效暂停为 `TimeSystem.is_gameplay_paused() || tactical_motion_paused`；因此解除全局暂停不会让已经到攻击位、正在攻击或等待空间的敌人继续挤动，战术逻辑恢复追击时才释放该层。
- 暂停期间不采样模型近战接触，也不提交已经排队的近战伤害；队列保留到恢复后处理。投射物继续消费 TimeSystem 的 0 战斗帧秒，攻击权威继续只由 logical tick 推进。
- 前端无需新增 GM 入口：既有空格 / HUD 暂停与正式刷敌入口可以直接观察。`verify_t0189_enemy_pause_motion.gd` 固定单兵与含骑兵正式群体在 75 个物理帧内零位移、零速度、请求 / 阶段 / HP / attack sequence 不变，并验证恢复续路及战术停步不被误解冻。

## T0188 站内敌军全域响应与避战射程

- StationLayoutController 的正式 `interior_polygon` 是“敌人已进入驿站”的唯一空间事实。只要至少一名活动敌人在多边形内，全部可响应的武装应征 NPC 立即从工作 / 集结进入战斗，不要求敌人先进入该 NPC 的 5 米接触圈。
- T0225 起，只要站内仍有敌人，站外武装应征 NPC 的新目标可跨距离限定到整座驿站内；站内武装 NPC 则按 T0321 将整站敌人与本人 `37.2m` 圈内敌人合并，并从全集合锁最近者。旧 `normal_contact_range=5 m` 不再决定武装 NPC 索敌，只保留为非战斗接触 / 避战兼容下限。
- 分配坐骑不会绕过取马流程：进入战斗只设置 `going_to_stable_horse`，HorseSystem 完成指定马匹会合前友军 AI 跳过攻击；上马回调把状态改为 `mounted / combat_ready` 后再执行策略。
- T0209 后非战斗避战检测半径固定为敌军统一索敌 `37.2 m + 2.0 m = 39.2 m`，不再随活动敌军最大远程射程变化；原始目标距离同为 `39.2 m`。站内目标修正、清敌返回工作合同不变，`avoid_combat` 的实际位移档位由 T0155 固定为 run。

## T0187 五级索敌白名单与塔防真实受击（历史分类，现行规则见 T0196）

- 正式动态敌军唯一顺序为 `我方 NPC → 塔防单位 → 城门 → 仓库 → 主厅`。攻击意图、在途弹体扩展同类候选；近期实际命中在敌军攻击建筑时精确抢占来源，在敌军攻击有效 NPC 时不拉走当前目标。
- 建筑目标严格限制为 `front_gate / warehouse / main_hall`。训练场等普通建筑即使被阻挡射线命中，也只作为导航 / 世界碰撞，不会被转换成可攻击目标。
- 城墙塔防的宿主代理直接使用城外 lease 可达性，不再按代理中心的门线侧别回退到城门。`host_proxy_hit_radius` 只限定共享墙段上的命中区域；攻击接触点使用物理 `contact_radius`，让真实武器扫掠能够命中代理并只扣器械 HP。
- 目标选择、站位和真实伤害仍依次由 CombatSystem、T0149 lease、T0144 模型接触与 DefenseDeviceSystem 权威处理；没有增加动画补伤旁路。

## T0186 近战接触稳定性与交战滞回

- 模型近战扫掠会忽略带 `collision_category=navigation_floor` 的导航承载地表；该地表只负责站立 / 导航，不是一次挥击的终止目标。其他世界静态碰撞仍可阻挡，NPC、敌人、建筑和塔防宿主仍必须由碰撞身份匹配后才提交伤害。
- 敌军攻击位使用“进入严格、退出宽松”的滞回：首次到位仍要求 `arrival_tolerance=0.32 m`；租约进入 `occupied` 后允许数据化 `engagement_position_exit_margin=0.18 m`，避免 RVO 微移逐帧切换 pressing / attacking。
- 敌我 windup / recovery 锁定原攻击目标。活动攻击周期只在目标失效或距离超过 `attack_range + engagement_range_exit_margin` 时取消；友军 impact 复验使用相同锁定退出窗口，敌军索敌在完整活动周期结束前不切换到新目标。新周期启动仍使用原武器射程，不允许在退出余量内凭空发起攻击。
- 伤害合同不变：忽略导航地板只让武器继续采样到后续真实接触，不增加逻辑扣血旁路；墙、门、单位等有效碰撞仍会命中或阻挡。`verify_t0186_melee_engagement_stability.gd` 以生产 Main、小步现实战斗秒和真实 HP 事件覆盖长期围城与艾达正面对战。

## T0185 全战斗表现统一时间合同

- `TimeSystem.get_combat_frame_delta_seconds(real_delta)` 是现实帧转换为战斗表现秒的唯一入口；`get_combat_frame_rate()` 供 AnimationPlayer / 粒子倍率使用。敌人在场时两者为现实 1:1，暂停为 0，非战斗 x2 / x4 不会把战斗表现加速。
- ChibiCharacterPilot 的四武器步战 / 骑战攻击、受击、昏迷、起身和坠马，旧 NPCArtView 的战斗状态、友敌坐骑 / 敌方坐骑共同阵亡及相关粒子共同消费该合同。逻辑 attack elapsed、真实武器扫掠和伤害提交边界没有迁入表现层。
- CombatSystem 的友军、敌军与 DefenseDeviceSystem 弹体统一以战斗表现秒积分速度 / 重力；不得再将 `numeric_multiplier=1/60` 直接乘到物理 delta。暂停保持弹体原位置，恢复后继续同一 attack id 与轨迹。
- 正式塔防机构仍由 DefenseDeviceSystem 权威 attack timeline 驱动，MeteorPresentation 的冲击波 / 粒子走统一表现秒；PietySystem 的陨石下落维持 T0173 已定义的稳定现实秒 + 主动暂停合同。开发场景独立动作预览不参与生产伤害。

## T0184 攻击动画与 1:1 战斗秒同步

- ChibiCharacterPilot 不再把 TimeSystem 的原始玩家倍率直接当作攻击动画速度。`combat_enemy_presence = 1/60` 是把基础 `60 游戏秒 / 现实秒` 降为 1:1 的比例，不代表动画应以 `1/60` 速度播放。
- 角色攻击表现现经 T0185 的专用战斗帧接口，与 CombatSystem 的 attack elapsed / cycle 使用同一秒制；敌人在场时为 authored x1，暂停为 0，更严格的表现慢速可低于 x1。无敌人的合成 / 调试战斗 profile 最快限制为 authored x1。
- 近战伤害合同未变：到达逻辑 impact 仍不直接扣血，必须由实际剑刃 / 长杆模型扫掠命中目标碰撞体后提交。该修复让动画在正确时间抵达接触窗口，不扩大范围、不伪造命中。

## T0182 旋转建筑真实外墙攻击位

- `warehouse / main_hall` 的路线阶段点只作为接近与阻挡预检参考，不再覆盖战斗目标位置。CombatSystem 从 StationLayoutController 读取建筑真实中心、旋转基向量、最大级包络和正门宽度。
- 结构候选按敌人物理直径沿四面外墙采样，并从当前路线接近侧选取紧密连续的一段；候选接触点严格位于旋转矩形边界，站立点沿该墙面法线外移，正面门洞范围不生成墙体命中点。
- 每个租约继续保存独立 `contact_position`。到位、朝向、近战模型扫掠和远程瞄准均使用对应墙面点；武器必须实际碰到带相同 `building_id` 的墙体碰撞后才调用 BuildingSystem 伤害权威。
- 阻挡物射线继续指向 `route_approach_position`，避免通往大型建筑中心的直线穿过可由 NavigationServer 绕行的邻近建筑；正门 / 仓库的确定性硬阻挡顺序不变。

## T0181 陨石建筑禁投与落地排出

- 陨石伤害圆与任何正式建筑、城墙或城门区域相交时，PietySystem 在消费虔诚和创建 pending 状态前拒绝施放；建筑 HP 仍不会进入陨石伤害结算。
- 合法空地落地时，MeteorPresentation 提供与 StaticBody3D 完全一致的碰撞半径。PietySystem 先请求 NPCSystem 排出体积内友军，再创建静态碰撞，避免无伤友军被实体包住。
- 排出不属于伤害、击退或行为切换：HP、昏迷、骑乘、当前模式和移动目标不变。冲击与燃烧仍只调用 `CombatSystem.apply_enemy_area_damage(...)`。

## T0238 陨石坑 24 游戏小时生命周期

- 弹坑、焦土与灰烬只属于表现，不拥有 HP、伤害、导航或占位权威；它们从落地起随逻辑游戏秒线性淡化，并在 `86400` 游戏秒边界移除。
- 战中陨石 `StaticBody3D` 仍由 `combat_ended` 独立清理。弹坑先到期不能移除仍在战斗中的岩体，战斗先结束也不能提前抹除未到期弹坑。
- 冲击、燃烧、最近 12 目标、无友伤、NPC 安全排出与事件链均未改变。

## T0180 结构局部接触点与固定目标容量

- 建筑、城门和塔防宿主墙段的每个近战攻击位都携带独立 `contact_position`。敌人到位后的表面射程、攻击前朝向、T0144 武器扫掠和远程释放目标统一读取该点，不再以共享建筑中心误判两侧攻击者超出射程。
- 近战站立距离以模型武器触达距离为上限，并扣除 NavigationAgent 到达容差的一部分和小额结算余量；这只让合法站位落入真实扫掠窗口，不扩大武器命中长度。
- 局部接触点与独占租约继续用于塔防和三座建筑；T0196 起塔防、仓库和主厅满位时对尚未取得位置的敌人视为消失。城门是唯一例外：当前第一波为城门 7 个租约，第 8 人仍锁定完整城门并保留唯一 waiter，不能提前选择仓库。
- `formal_wave_pressure_unit/building` 到达只结束移动，不授予 attack-ready；最终攻击资格仍要求有效目标、租约、局部表面射程和实际武器接触，伤害继续只由 CombatSystem 结算。

## T0179 友军骑乘转向表现对齐

- 正式友军骑手与马匹继续读取同一 `combat_mounted` 权威状态，但人物根位置现在把完整骑姿局部偏移旋转到当帧可见前向，避免横向集结时人物滑到马侧。
- 攻击时间轴、武器接触段、投射物释放 Transform 和伤害权威未改变；骑乘攻击 / 受击及坠马只复用校正后的表现根坐标。

## T0178 骑手与步行单位共享寻路修复

- 骑手在指定马匹旁完成上马后，CombatSystem 继续把警铃时预留的骑兵翼阵位直接交给 NPCSystem；不插入马厩专属出口路线、门洞租约或串行候补。
- 步行与骑乘单位都由 ActorMotionBody 处理错过路径点、RVO 偏转和最终制动，因此广场、马厩外、城门内外的相同症状走同一修复。
- 阵位、骑乘身份、接敌切换、攻击权威和战斗时间规则不变；拥挤时单位可向出口提前靠近，但安全速度不能反向追逐身后旧路径点。

## T0176 攻击位可达性与城门阻挡

- 动态敌军的脚步 / 骑乘物理半径仍来自正式 actor profile；攻击位使用 `2 × physical_radius + safety_margin`，每个 NavigationAgent 使用 `physical_radius + safety_margin / 2`，避免槽位数据允许、RVO 却拒绝进入的矛盾。
- NavigationAgent 的目标到达距离与攻击位 `arrival_tolerance` 共用配置。攻击解锁仍需 CombatSystem 的攻击位距离与 T0144 / T0145 真实命中，不因扩大逻辑伤害范围而提前扣血。
- T0196 起索敌不再消费逐目标 NavigationMap 可达预检或门后阻挡抢占：NPC / 塔防只按统一半径、单位类别、锁定状态与固定位置容量决定目标；三建筑只按白名单存活顺序与容量回退。怎样抵达已锁目标由后续导航任务单独处理。
- 攻击位释放、武器角色兼容候补、阻挡物摧毁后的重新索敌和实际伤害权威保持 T0144–T0150 既有合同。

## T0167 马槽开放侧取马

- 已分配骑手仍严格寻找自己的 `horse_id`。目标不再由马模型中心直接取 NavMesh 最近点，而是读取该马 `stable_slot_id` 对应、朝中央走道开放的 `pickup_center`，避免最近点落在隔栏另一面。
- HorseSystem 发起移动前强制同步生产 NavigationMap，校验接近点吸附误差不超过 1 米且从 NPC 吸附起点存在完整路径；失败时返回明确原因，不以直线或隔栏点降级。
- 马保持在原槽等待。NPC 到达接近点后才进入 mounted，随后 CombatSystem 继续使用警铃时原有骑兵翼 reservation；接敌打断、伤害、返厩与马槽占用规则不变。

## T0165 陨石落地实体与战斗结束生命周期

- 伤害合同不变：5.5 米冲击仍只调用 `apply_enemy_area_damage(...)`，48 攻击力 / 5 穿透 / 最近 12 目标；10 动作秒燃烧仍每秒 1 攻击力且无友伤。变化仅是下落表现时长从 1.15 调为 2.8 动作秒。
- 落地后的 4.2 米陨石带 world_static `StaticBody3D`，在本场战斗内形成真实碰撞；CombatSystem 写出既有 `combat_ended` 事件后，PietySystem 移除所有落地陨石实体。弹坑与灰烬没有 HP、伤害或占位权威，不随清敌立即消失；T0238 起它们改由独立的 24 游戏小时淡化生命周期清理。

## T0163 陨石落点范围解锁

- 陨石目标不再受驿站矩形边界限制；有限 X/Z 在 T0181 建筑排除规则之外可进入原有冲击与燃烧结算。PietySystem 仍归一化地面 Y，拒绝非有限坐标，并只在合法施放后消费虔诚。
- 该变化不扩大伤害对象类型：CombatSystem 仍只枚举落点半径内的活动敌人，NPC、建筑与我方器械保持无友伤。

## T0162 指定马匹取马与骑乘外观

- 骑手的 `mount_rendezvous` 目标来自其已分配 `horse_id` 对应的真实 HorseWorldView，而不是某个通用马厩锚点；到达旁边后才进入 mounted 状态。上马后的马匹模型读取同一权威快照中的模板与毛色。
- 坐骑分配、取马和外观不改变 T0160 规则：未接敌则继续完成翼侧阵位，接敌则直接参战。马离厩 / 骑乘时仍占原马槽，战时结束返厩后回到同一槽位。

## T0161 八人战斗测试预设

- GM 预设提供四名步兵与四名骑手：中央近战 2、中央远程 2、骑兵翼 4；其中剑盾 / 长杆 / 弓 / 弩各 2 人，四人全甲。CombatSystem 不读取预设文件，只消费 EquipmentSystem / HorseSystem 形成的正式 unit type 快照。
- 点击后摇铃继续沿 T0160 动态编队，专项确认 `melee_front=2 / ranged_rear=2 / cavalry_left=2 / cavalry_right=2`。取马、接敌打断、伤害和胜负结算没有 GM 旁路。

## T0160 正门外友军集结阵型

- 警铃阵位读取 `station_layout.combat_spatial.friendly_rally`：正式中心 `(5,70)`，以 `enemy_direction` 为阵前方向。近战 / 长杆步兵组成 `melee_front`，弓 / 弩组成 `ranged_rear`，近战骑兵与骑射单位交替进入 `cavalry_left / cavalry_right`；数量增加时按各组配置间距扩排，不按 NPC 职业硬编码。
- 每名响应者在警铃时取得稳定 `formation_row / formation_index / position` reservation。步行者立即沿生产 NavigationMap 前往；骑手先到马厩取马，`handle_npc_mount_ready(...)` 再恢复同一翼侧 reservation。位置吸附只解决合法落点，只有实际距离不超过 `0.3 m` 才提交 `rallied`。
- `_advance_rally_units(...)` 继续先做 5 m 接敌检查，再检查到位；因此移动中或列阵等待时接敌会立即进入 `combat`，清除移动目标并直接索敌，不再回头补阵。没有接敌才列阵并开始一游戏小时等待。
- 正门 NavigationLink 允许双向实体通行：友军可由站内走到外侧集结区；敌军仍由 `front_gate -> warehouse -> main_hall` 目标阶段控制入站时机，导航连接本身不授予破门、攻击或伤害权威。

## T0157 摧毁后的战斗空间边界

- 弩床 / 箭塔 HP 清零后，DefenseDeviceSystem 在同一伤害提交中停止攻击、释放 target / deployment 与槽位；留下的 ruin View 没有碰撞、点击、索敌或发射能力。现实 `15 s` 后或同槽重新部署时只清表现废墟。
- 正门 0 HP 时门楼继续存在，但两扇门板倒地并关闭实际阻挡 CollisionShape。敌军既有破门→仓库→主厅阶段不变，可从真实门洞进入；达到 1% 修复阈值后碰撞恢复，后续敌军必须重新破门。
- 仓库在 30% 前仍是可被修复的坍塌目标；主厅摧毁仍立即触发既有失败。废墟 Mesh 不注册为战斗目标，不能二次吃伤害或替系统决定路线。

## T0135-P6R3 正式战斗坐标原点归位

- 正式地图从旧 X=1000 staging 偏移归位后，CombatSystem 不再用 `position.x > 900` 判断正式战术位置；动态波次只要持有正式世界权威，就把战术点吸附到 StationLayoutController 的生产 NavigationMap。
- 当前统一索敌只对固定目标检查 `target_key + weapon role` 的空位置；塔防、仓库和主厅满位即对该敌人视为消失，完整城门满位仍等待。NPC 不消费该租约系统。

## T0156 全量回归结论

- T0141–T0155 的生产链已作为一个整体通过自动矩阵；其中旧七层与后续五级分类均已由 T0196 统一在场锁合同取代，其余模型接触、弹体、代理、固定目标攻击位与 locomotion 权威边界不变。
- 没有 authored 武器几何样本的逻辑步必须返回 `melee_geometry_unavailable`，伤害为 0；测试不得再用 `_apply_npc_attack_to_enemy` 把未采样动画伪装成命中。战斗生命周期测试先完成一次正式角色剑模型接触，余额清理才使用显式测试 fixture 的权威 damage sink。
- 正式第五波 48 敌压力通过，CPU p95 `7.436 ms`、导航 p95 `0.333 ms`、零 orphan；五波胜利、主厅失败、无可用战斗员失败、暂停 / 存档、骑乘坠落 / 敌方坐骑共同阵亡和战后清理均通过。

## T0151 权威有效射程的只读表现

- `CombatSystem.get_npc_attack_range_indicator_snapshot(...)` 只对可行动、处于 `rally / combat` 且持弓 / 弩的友方返回 `ready=true`，半径直接来自同一攻击上下文使用的 `get_npc_combat_stats(...).final.range`。
- `DefenseDeviceSystem.get_attack_range_indicator_snapshot(...)` 只对宿主有效且 HP 大于 0 的活动 deployment 返回 `ready=true`，半径直接来自包含槽位与宿主倍率的有效 `effect.range`；这也是 T0147 选敌和弹体最大水平航程的数据源。
- 两类快照统一标记 `range_semantics=maximum_attack_initiation_ballistic_distance`。范围内仍可能因目标移动、抛物线、遮挡或真实碰撞而射空，圆环不产生攻击资格或伤害事实。

## T0150 / T0187 五级敌军索敌、反击证据与阻挡回退（历史，已由 T0196 整体覆盖）

- 正式动态敌军严格按 `NPC → 塔防 → 城门 → 仓库 → 主厅` 筛选。NPC 范围内目标、逐塔防实际射程威胁圈，以及有攻击意图 / 在途弹体的范围外目标在所属单位层合并去重；低层目标距离再近也不能越过仍可用的高层目标。
- 同层候选先生成 T0149 攻击位并通过 NavigationMap 预检，按实际路径距离选择最近可达空位。普通目标满位 / 不可达只记为回退原因，继续检查下一层；但有效且可达的塔防满位时立即进入该塔防候补并停止检查建筑层。塔防失效或确实不可达后才允许回退城门、仓库与主厅。
- 反击源由三个权威事实合并：NPC / 塔防当前攻击目标、`_active_projectiles.target_at_release` 中的在途攻击、`_apply_damage_to_enemy` 已提交命中。近期命中保存短生命周期及顺序；攻击建筑时最后实际来源精确抢占，来源失效或过期即清除，不进入存档。
- 当前目标带 `target_priority / target_lock_until_frame / target_last_evaluated_frame`。短锁仅抑制同级或更低级抖动；更高优目标立即抢占。若旧攻击已提交 impact 并处于 recovery，则旧周期完成后再切换，避免有效帧被重复或吞掉。
- 正式 `front_gate → warehouse → main_hall` 路线提供唯一可攻击建筑链。world-static 射线只允许返回这三个白名单 ID，其他 BuildingSystem 建筑由 NavigationMap 绕行。阻挡位满时复用 T0149 候补 / 补位，不建立第二套队列。

## T0149 敌军固定目标攻击位租约

- 正式五波仍由每个敌人独立索敌。NPC 是移动单位目标，不需要固定攻击位，多个敌人可以挤到身边直接接战；只有塔防宿主墙段 / 平台代理和 `front_gate / warehouse / main_hall` 在接近前取得 CombatSystem 的短生命周期攻击位租约。
- 槽间距由 `enemy_foot / enemy_mounted` 实体半径加配置安全余量生成。剑盾 / 长杆位的纵深按 T0144 模型接触距离生成，弓 / 弩射击位按当前有效射程生成；不同武器层即使槽 ID 不同，实际实体包络重叠时仍不可同时租用。
- 新租约先吸附到正式 NavigationMap，再查询从敌人当前位置到候选的路径；偏离原候选过大、无路径或路径终点不能到达的位置直接排除。可用候选按路径长度、稳定槽 ID 排序，最近可达者胜出。
- T0196 起塔防、仓库和主厅没有兼容空位时直接从该敌人的本轮候选中消失，不创建 waiter；完整城门满位时仍创建 / 保持 waiter，确保敌军不能越过未破城门。NPC 从不因拥挤消失，也不创建 lease / waiter。
- 目标 / 武器变化、无目标、路线切换、导航失败、stagger、死亡 / 移除和清敌都会释放租约。失败槽对该敌人短暂冷却，防止反复抢回；租约 / 队列 / 冷却不写入空间存档，恢复实体后重新分配。最终命中与伤害仍由 T0144 / T0145–T0148 权威链决定，占到位置本身不授予命中。

## T0148 塔防宿主墙段 / 平台受击代理

- DefenseDeviceSystem 的活动塔防目标不再把高处器械根节点直接当作敌军接触点，而是输出 `host_proxy`：宿主建筑、槽位、墙段 / 建筑墙段 / 平台 fixture、低位移动目标、瞄准点、接触半径和局部命中半径。
- 围墙槽 01/03 共用 `north_west_a` 物理墙体、02/04 共用 `north_east`，但每槽用自身平台中心和 `2.05 m` 命中半径进一步分区；碰到同一长墙的另一个槽位区域不算当前器械命中。
- 主厅槽的兼容主代理按位置映射到 `back_wall / front_left / front_right`，并同时接受对应唯一 `main_hall_slot_*_platform` fixture；T0230 起实际接敌 / 命中再展开同角 `left_wall / right_wall` 第二区域。地面近战可以攻击两条相邻支撑墙，远程弹体也可实际碰中支撑墙或平台，均解析为锁定器械。
- 敌军近战 sweep 和远程 projectile 共用 `_is_defense_device_proxy_contact(...)`。只有 deployment 或严格的 building + segment/fixture + 局部位置匹配后，才调用 `_apply_enemy_attack_to_defense_device(...)`；旧的“命中宿主建筑任意 collider 都算器械命中”路径已删除。
- 代理命中只调用 DefenseDeviceSystem，宿主建筑 HP 不变；`target_type=building` 仍只调用 BuildingSystem。器械摧毁后活动目标立即消失，但现有墙体 / 平台碰撞与建筑 HP 不随之删除。

## T0147 塔防动作时间轴与物理命中

- `DefenseDeviceSystem` 是部署器械攻击周期权威：每个实例维护 idle / windup / recovery、elapsed、cycle、release、target、committed 与 sequence。攻击速度用同一倍率缩放完整周期、释放时刻与恢复时间；每周期最多提交一次 release。
- 箭塔 / 弩炮只在 authored release 帧请求 `CombatSystem.release_defense_device_projectile(...)`。CombatSystem 从正式模型发射口生成弓箭 / 弩矢，锁定目标释放瞬间的世界位置，之后只按初速度、重力和连续扫掠推进，不追踪目标。
- 塔防弹体的 `source_side=defense_device`。只有实际第一碰撞体解析为活动敌军时，才经既有 `apply_defense_device_attack(...)` 结算；地面、建筑、同阵营阻挡、超时、水平航程耗尽或目标闪避均形成零伤害终态。
- `effect.range` 同时控制允许起手的最大水平距离和弹体 `max_range`，不维护 UI / 表现副本。终态结果按唯一 `attack_id` 回填 DefenseDeviceSystem 的最近动作、事件和累计伤害；释放本身不改 HP，重复命中事实不重复结算。
- 战斗暂停冻结时间轴与弹体；x2 / x4 不直接放大实体战斗秒。清敌、移除器械、读档或战斗清理会取消未完成周期并把在途塔防弹体明确终结，防止残留补伤害。

## T0146 敌我弓弩步骑正式矩阵

- 我方步战弓 / 弩与 HorseSystem 真实骑战弓 / 弩、敌方步战弓 / 弩和骑马弓手全部共用 T0142 时间轴、T0145 attack ID 与 T0143 物理弹体。当前波次没有骑乘弩兵，但共享 mounted-ranged 包装的弩 profile 已作为兼容分支验收，不新增敌种。
- 正式释放点必须来自当前生产角色包装中的 loaded arrow / bolt。包装只读返回 Transform、步 / 骑状态和节点路径；CombatSystem 不再从角色中心 / 身体高度生成兼容弹体。模型或装备节点不可用时只记录 `release_rejected`，不得补伤害。
- 攻速改变时继续以同一个完整攻击周期计算 authored release 秒和动画 playback multiplier；前摇期间持续面向目标，释放后速度不再随目标变化。每周期只创建一个带 T0145 ID 的弹体，实际碰撞后才进入唯一伤害入口。
- 弹体快照暴露 `source_mounted / release_position / release_basis / release_origin_source / release_origin_node_path`，用于 GM 与自动化确认实际模型来源；这些表现路径和 Basis 不进入存档权威。

## T0145 弹体攻击 ID 与唯一命中事实

- 每次正式弓 / 弩 release 生成唯一 `attack_id`，组成来源为 `source_side + source_id + attack_sequence + projectile_sequence`。时间轴 sequence 负责关联同一攻击周期，projectile sequence 保证测试、恢复或异常重复 release 时仍不复用 ID。
- `attack_id / attack_sequence` 贯穿 release result、活动弹体、最终 `hit / blocked / miss` fact、顶层攻击结果和嵌套 damage result。最终 fact 还记录实际 collider 身份、碰撞点、实际目标、是否伤害和原因，释放时锁定目标不覆盖实际碰撞事实。
- CombatSystem 在调用 NPC、敌军、塔防或建筑伤害入口前先把 ID 置为 resolving；同一 ID 的重复碰撞或重入只返回首个终态 fact 并标记 `duplicate_ignored`，不能再次结算。投射物表现节点仍只消费位置 / 速度，不创建或上报 HP 变化。
- 清空活动弹体时同步清空终态 fact 表；在途弹体、RID 和去重表不进入空间存档。T0146 将继续审计敌我 × 弓弩 × 步骑矩阵，本节不将矩阵覆盖提前视为完成。

## T0144 近战模型接触权威（T0245 后用于固定目标与角色模型诊断）

- 剑盾 / 长杆攻击起手只建立 CombatSystem swing；正式包装逐帧提供当前可见刃段 / 杆头端点。CombatSystem 按武器配置的样本数优先查询当前武器胶囊，未命中时再扫相邻样本的刀尖 / 中段运动轨迹；首个终止碰撞决定 `hit / blocked`，没有碰撞为 `miss`。
- 对建筑、城门和塔防宿主，锁定目标只负责朝向与起手，命中继续读取实际 collider；实际先碰到合法宿主受击体时按其身份结算。T0245 起普通角色对角色近战改为 cycle target 的 authored impact 承诺，不再由扫掠改伤害目标。
- 步战 / 骑战按各自动画量测接触点和范围：剑盾 `1.45 / 0.96 m`、长杆 `2.98 / 2.66 m`。距离表示面朝目标时目标碰撞体中心可被当前模型触及的前向范围，不使用横挥侧向半径冒充射程。
- 伤害仍只由 CombatSystem 提交。固定目标的表现帧登记首个接触并由物理帧消费唯一 damage commit；移动角色 swing 的模型接触仅作诊断，权威时间线到 impact 才提交锁定目标伤害。模型包装、BoneAttachment、武器 Mesh 与 AnimationPlayer 都不拥有 HP；攻击中断、模式退出或清敌会清理未结算 swing 与待提交队列。

## T0143 弓弩正式物理弹体

- 敌我 `bow / crossbow` 在 T0142 authored release 相位只创建弹体，不再立即调用伤害入口。释放点读取正式角色包装的 loaded arrow / bolt Transform，瞄准点读取目标当时的角色胶囊中心或结构目标高度；离弦后固定初速度，不追踪移动目标。
- `weapon_defs.json.projectile` 配置 speed / gravity / max_lifetime。CombatSystem 在物理帧中以不大于 `1/120 s` 子步积分重力，并用连续 ray sweep 查询 `world_static | actor_body`；场景、同阵营单位和无效实体会阻挡 / 终止弹体，不能穿过后继续命中原目标。
- 碰撞解析沿 collider 父链读取 `enemy_id / npc_id / deployment_id / building_id`。友军弹体可命中实际第一名敌军；敌军弹体可命中实际第一名 NPC。命中合法目标后才复用既有防御 / 穿透、马匹分伤、昏迷、击败、器械 / 建筑受击与事件链，单个弹体只提交一次。
- 防御器械自身没有独立物理体时，敌军射中其 `building_id` 对应宿主墙段也视为命中该器械；这只补齐物理弹体碰撞，不改变后续要实现的塔防目标优先级与建筑攻击占位。
- 正式 profile 写入 `combat_projectile_authority=combat_system`，使 `ChibiCharacterPilot` 只播放装填 / 拉弦 / 释放而不生成第二支预览飞箭；NPCDevLab 未带该字段，继续保留原动作预览。活动弹体和最近 hit / blocked / miss 可从 combat snapshot 观察；空间存档不保存飞行中 Node / RID，重建时直接丢弃在途弹体，避免恢复后幽灵伤害。

## T0142 敌我 NPC 攻击动画时间轴

- 剑盾、长杆、弓、弩使用 `CombatAnimationTiming` 登记的 NPCDevLab authored 总时长与命中 / 释放点。`attack_interval` 是从起手到恢复结束的完整周期；最终攻速只改变周期长度，命中比例不变，表现播放倍率为 `authored_cycle / authoritative_cycle`。
- 每次攻击都有单调 sequence，并经过 `windup -> impact -> recovery`。目标 HP 在 impact 前保持不变，跨点时最多提交一次；恢复结束前不能启动下一次普通攻击。粗粒度敌军步进按时间顺序补足完整周期，仍受单步最大攻击数保护。
- 友军和敌军在起手、命中与恢复中朝向当前目标。目标改变、离开射程、策略移动、模式退出、昏迷、正式路线重派或敌军 stagger 会取消旧周期；冲锋的碰撞与增强武器伤害也移动到剑盾命中相位，不能在动作开始瞬间结算。
- 弓 / 弩的释放点已由 T0143 接到正式物理弹体；近战的模型武器实际接触、表现长度射程校准、射程圈和新索敌 / 建筑占位仍未实现。
- `verify_t0142_combat_animation_timeline.gd` 与伤害 / 节奏 / 策略 / T0107 / 波次 / 正式包装回归共同锁定该合同；Main MCP 复核敌我命中前零伤害、朝向与跨点唯一结算。

## T0141 正式敌军复用 NPCDevLab 表现基准

- Main 的剑盾、长杆、弓、弩步兵现统一使用 NPCDevLab 已验收的 `ChibiCharacterPilot` 生产包装；轻骑和骑射继续使用 Main / DevLab 共用的 `EnemyMountedArtView`，固定装备分别为剑盾 + 马和弓 + 马。
- 武器与坐骑来源仍是 `enemy_waves.json`。CombatSystem 将其投影到正式 profile，表现层只按 profile 显示唯一武器和动作，不读取 DevLab 临时装配，也不改变敌军伤害、攻速、攻击距离、目标或占位逻辑。
- ActorMotionBody、碰撞、NavigationAgent、HP、受击、击退统计、坠亡共同尸体和胜负流程全部保留；旧 ActorMesh 仅在正式包装存在时隐藏。
- 当前弓 / 弩可见弹体仍是包装内部的动作预览，不是正式物理箭矢。攻击动作周期与攻速对齐、近战武器实际接触、实时瞄准、抛物线飞行、碰撞命中后伤害及射程提示圈均尚未由 T0141 实现。
- `verify_t0141_formal_enemy_dev_lab_reuse.gd` 生成代表波次并验证 7 个敌种、四类固定武器、步兵 / 骑兵包装、debug 隔离以及原碰撞 / 选择根保留。

## T0130-D1R12 四类武器步战 / 骑战表现边界

- 剑盾、长杆、弓、弩已具备开发检视所需的步战与骑乘握持 / 攻击表现。剑盾攻击保留手—剑刚性局部关系，长杆保持双手一前一后握持，弓由左手持弓、右手拉弦，弩保持在 NPC 自身右手一侧并向角色中线校准。
- 骑乘攻击以 `Mounted_Idle` 跨坐下半身为底，只替换上半身骨轨。剑盾、长杆复用步战协调上半身并叠加轻微前倾；弓 / 弩若在步战 Hips 上存有瞄准 yaw，则把 Hips 与 Spine 的合成旋转转移到骑乘 Spine，防止上半身斜转同时破坏跨坐腿姿。
- 骑乘受击、武器训练和骑马行走同样保持骑乘下半身；倒地 / 复苏的正式权威仍按 T0139 的人物昏迷与坠马链处理，不能由普通动作按钮伪造结算。
- 开发检视中的箭、弩矢和发射轨迹目前是 presentation-only。正式射程、弹道、碰撞、命中时刻、护甲、防御与伤害仍由 CombatSystem 独占；后续接入抛物线时必须让命中事实驱动表现结果，不能让动画帧或可见投射物直接扣血。
- `verify_t0130_d1_npc_dev_lab.gd` 验证表现骨轨、握点、前向、投射物阶段和跨角色一致性；它不替代正式五波战斗、伤害、昏迷和胜负回归。

## T0138-R2 取马后正式队形集结

- 警铃建立队形时，默认正式世界直接读取 `StationLayoutController.get_enemy_route_world()` 的 `front_gate` 世界坐标，不再依赖敌军正式波次已经生成。旧原型坐标只在显式旧场景兼容模式使用。
- 已分配马 NPC 仍先到马厩取马；`HorseSystem` 提交上马后，`CombatSystem.handle_npc_mount_ready(...)` 用警铃时已预留的 `formation_row / formation_index / position` 重新发起集结移动。T0160 后所有骑乘单位分列左右翼，步行近战居中前排、步行远程居中后排。
- 集结到达判定使用 `0.3 m`，覆盖 ActorMotionBody / NavigationAgent 的停止容差；人物停止时必能被提交为 `rallied`。本修正不改变接敌距离、骑兵伤害、我方马匹分伤、昏迷或敌方共同阵亡权威。

## T0242 / T0139 友方骑手坠马与敌方骑兵共同阵亡表现边界

- 骑乘 NPC 的 HP 归零、昏迷事实、双方马匹分配清理和存活马返厩仍由 CombatSystem / NPCSystem / HorseSystem 在同一受击结算中立即完成。
- 角色表现仅从 `combat_mounted=true` 到 `unconscious=true` 的边沿触发一次坠马：约 `0.92 s` 侧向翻落并播放 `Death_A`，落地后停留；它不提交伤害、不延迟解绑、不控制马匹返厩。
- 复苏继续遵守 30% HP 权威门槛并播放 `Lie_StandUp`；无马昏迷保持原表现。
- 敌方骑兵 / 骑射兵的马匹是纯表现节点，没有独立 HP、分伤、HorseSystem 记录或装备所有权；我方伤害完整进入敌军单位 HP，避免额外血池改变波次数值。
- 敌军 HP 清零时权威敌军立即移除并照常推进击退统计、清敌与胜负判断。随后保留的表现包装只负责骑手 `Death_A` 坠亡与马匹 `Death`：人马根位置固定、动画结束后保持尸体姿态；T0133-R1 后普通、骑乘和骑射尸体统一保留 `8.0 s` 再整体释放，不再存在逃跑目标、速度、距离或地图外释放。
- `NPCDevLab` 的敌方骑兵验收直接调用 `EnemyMountedArtView.apply_profile / set_movement_active / begin_mounted_shared_defeat`，仅改变独立开发场景表现，不向 CombatSystem 提交模拟伤害。
- T0139-D2 的我方 DevLab 入口以两次本地 `apply_profile` 复制正式骑乘到昏迷边沿，不扣 HP、不解除马匹分配、不发送事件；马匹 `Gallop` 仅是检视台上的返厩语义参照。

## T0132-P5 道路表现与战斗寻路边界

- 正式 42 段泥路只由 `FormalRoadNetworkArtView` 显示，显式保持 `roads_affect_navigation=false`，且没有 CollisionObject 或 NavigationRegion。车辙、泥肩、碎石和交汇补片不能改变敌我单位的路径成本、目标选择、挤压、攻击距离或到达判定。
- 当前正式波次继续按 NavigationMesh、CharacterBody 实体碰撞和 avoidance 寻找目标的最短可行路线；道路不是必须途经点。P5 后第一波动态直攻回归通过。

## T0132-P4b 箭塔攻击表现与结算边界

- DefenseDeviceSystem 继续按 `attack_interval=1.39 s`、伤害 16、穿透 4、基础射程 28 和宿主槽倍率即时选敌 / 结算；正式箭塔只消费既有 `origin_position / target_position / attack_interval` 表现快照。
- 每次已结算攻击驱动一次转台瞄准、弓弦释放、已装填箭隐藏、可见飞行箭和约 `58%` 间隔的机械回位；飞行体与动作都不提交命中、伤害、穿透或击败。目标在箭飞行期间移动或失效，不改写已发生的结算。
- 主厅木制平台替换只影响 Mesh / 材质。四槽坐标与 `3.93 m` 锚点保持不变；T0228 后前侧 `slot_03/04` 为 Lv.1/3、背侧 `slot_01/02` 为 Lv.5/6，T0223 的主厅 `1.0x` 射程与围墙槽加固收益不变。

## T0132-P4a 弩床攻击表现与结算边界

- DefenseDeviceSystem 仍按 `attack_interval=4.25 s`、伤害 44、穿透 8、基础射程 34 和宿主槽倍率即时选择目标并调用 CombatSystem 结算；动画完成、弩箭飞行时间和任何视觉碰撞都不提交伤害。
- 单次 `defense_device_action_resolved` 追加 `origin_position / target_position / attack_interval`，三者是本次权威射击发生时的只读快照。目标之后移动、昏迷或被移除不会改写已经结算的事实；飞行弩箭只追到快照坐标并自动清理。
- `DefenseDeviceView` 把同一事件交给正式弩床，按事件频率播放转台瞄准、弓弦释放、后坐、弹体飞行和重装；待机箭只在重装完成后出现。主厅 `1.0x` 基础射程与围墙 Lv.3 / 5 射程加成都不改变攻速或表现层职责。

## T0132-P2 仓库受击表现边界

- 仓库实体美术没有修改敌人 `front_gate→warehouse→main_hall` 目标序列、正式攻击点或动态接触逻辑；正门到仓库的导航回归仍为17点，第一次有效攻击继续由 CombatSystem 扣减 BuildingSystem 仓库 HP。
- 裂纹、松脱门板、碎石和烟尘只读 `hp/max_hp` 分级显示，修复后随权威 HP 清除。分类货物、侧仓与挑高安全仓不拥有库存损失、被掠夺比例、伤害或攻击完成权威；尚未实现的仓库受击资源流失规则仍不得由表现层推导为生效。

## T0132-P1 主厅城防与损伤表现边界

- 主厅器械槽位仍由 DefenseDeviceSystem 权威解锁，Lv.1–6 容量保持 `1/1/2/2/3/4`；T0228 后平台映射为前侧 `slot_03/04=1/3`、背侧 `slot_01/02=5/6`。表现层不拥有部署、射程、器械 HP、攻击或命中。
- P1R3 修复旧空间坐标分裂：主厅四槽的运行态攻击原点、世界部署模型和 UI 标记现在统一绑定正式平台世界锚点；围墙四槽也统一绑定正式正门墙段。主厅平台局部中心保持 `(-7,-5)/(7,-5)/(-7,5)/(7,5)`，安装高度为 `3.93 m`；T0223 后使用 `1.0x` 基础射程，伤害、攻速、穿透或目标选择公式不变。显式 GM legacy compatibility 才恢复配置中的旧地图位置。
- 主厅裂纹、破损布幔、碎石与烟尘只读 BuildingSystem `hp/max_hp`；主厅 HP 归零的游戏失败仍由原有权威流程决定，表现节点不提交伤害、修复或失败事件。

## T0130-P1 正式剑盾步兵表现接线

- CombatSystem 对 `unit_type=melee_infantry + weapon_type=sword_shield` 装配 `EnemySwordShieldChibiArtView.tscn`；第一波 8 人及后续同类个体使用 Synty Dark Knight、KayKit 动画和内建剑盾。T0139 后 `cavalry / mounted_ranged` 使用 `EnemyMountedArtView`，骑兵保留剑盾、骑射兵不冒充剑盾；长杆、弓和弩步兵仍使用旧回退。
- 正式敌人仍是既有 `ActorMotionBody`：父级 CharacterBody / NavigationAgent / BodyCollision / InteractionArea 负责实体移动、拥挤、索敌和点击。生产美术包装不带 P0 沙盒 SelectionArea，不改变胶囊半径、RVO、攻击距离或路径。
- CombatSystem 的 `current_action` 只读映射 walk / run / attack，HP / alive 只读映射受击 / 倒地；动画完成不提交命中、伤害、死亡或建筑破坏。`debug_get_enemy_art_snapshots()` 只供 GM 与专项观察。
- Synty 剑盾兵的可见正面为本地 `+Z`；包装层用独立 `180°` 修正对齐项目 `-Z` 移动合同，并以 `0.10 s` 有界响应跟随 RVO 持续更新的行进方向。该表现插值不改变 ActorMotionBody 的路线、避障速度、挤压、索敌或攻击范围。
- P1 专项确认第一波 8 个正式剑盾实体全部使用两头身家族并保留父级碰撞；敌人波次生成和 48 实例共享动画库回归通过。48 实例 headless 观测约 `6.86 ms/帧`、初始化 `210.50 ms`、静态内存 `+50.27 MB`，不替代渲染 / 导航 / VFX 联合预算。

## T0130-P0 剑盾敌人两头身表现试片

- `EnemySwordShieldChibiPilot.tscn` 使用 Synty Dark Knight 可见网格、KayKit Medium Rig 近战动作和 Synty 剑盾挂点，只验证外观、动作、选择体与并发成本；它没有加入 CombatSystem 活动敌人集合，也不计算索敌、射程、命中、伤害、阻挡或死亡。
- 48 敌夹具只实例化 presentation-only 包装并轮换 idle / walk / run / attack / hit_react，验证共享 AnimationLibrary 和骨骼更新开销；本机 headless 180 帧平均约 `6.86 ms`。这不能替代完整 Main 的导航、RVO、战斗系统、渲染和 VFX 联合预算。
- 用户视觉验收前，五波正式敌人继续使用既有生产表现；不得把 Main 的临时试片根视作刷波、战斗开始或目标可攻击实体。后续批量接线仍必须由 CombatSystem 权威状态驱动共享表现状态合同；P7 后 Chibi 包装为 17 状态。

## T0129C-A5-P8 波次与逃离空间恢复

- 活动正式波次保存波次号和存活敌人的 `spawn_index` 空间状态。加载从权威波次配置重建实体，删除存档中不存在的出生序号，再恢复坐标、HP、攻击冷却、抬手与硬直；目标选择和 NavigationAgent 路径随后继续实时计算。
- 活动逃离保存于 NPC 的 `escape_intent`。加载 NPC 坐标后，清醒者重新请求正式地图边缘终点，昏迷者保持暂停，已完成逃离者保持隐藏且不会复活。

## T0129C-A5-P7 默认正式居民与逃离

- 战斗开始时 NPC 已常驻生产 NavigationMap；CombatSystem 原地接管可行动 Body，不再从旧坐标传送到初始锚点。战斗结束只撤销战斗权属，保留各 NPC 当时正式坐标并回到 `formal_world_resident`。
- 默认正式居民在非战斗状态发起逃离时也使用后门至地图边缘的 6 点 / `261.302 m` 路线；只有实体抵达才提交 `escaped`。战斗中途结束不会把逃离者或其余 NPC 拉回旧图。
- GM 临时旧图兼容是开发入口，不改变伤害、波次、逃离事件、昏迷 / 复苏或胜负权威。

## T0129C-A5-P6d-3 昏迷实体与治疗接近边界

- T0215 后，昏迷 NPC 仍是不可行动、可见且可交互的世界角色，但不再保留 BodyCollision / RVO 阻挡实体；`assist_heal` 仍必须通过生产导航抵达其世界位置周围合法距离，不能用后台 `current_location` 代替接近。
- 每个目标最多两名治疗者，各自有独立路线与站位。战斗接管、治疗者昏迷、目标复苏或导航失败都会撤销会话与 helper；CombatSystem 不接管治疗费用、HP 恢复、经验或事件结算。
- 复苏阈值和“NPC 不死亡”核心规则不变；本步只把既有治疗链的空间前置条件落到实体世界。

## T0129C-A5-P3 完整 Main 时间链预算

- 默认第五波下分项采样 `logical_time_tick` 全订阅链，并用同一计时方式比较隔离 CombatSystem 与 `TimeSystem._advance_simulation_time()` 完整入口；600 次样本 P95 分别为 `3.764 / 4.383 ms`，综合约为隔离值的 `1.16×`，均低于 60 FPS 的 `16.67 ms` CPU 预算。
- `CombatSystem.get_wave_hud_snapshot()` 只投影 HUD 需要的当前波次、敌人数、下一波与倒计时，不复制完整活动战斗、生成结果和历史结果；原 `get_wave_schedule_snapshot()` 保持完整调试 / 业务合同。
- 普通时间倍率下 HUD 与商人忽略同一游戏分钟内的重复表现刷新；LLM 慢速需要精确秒时 HUD 仍按秒刷新。该优化不改变伤害、冷却、波次调度、商人到离时段或任何权威结算。

## T0129C-A5-P2 默认第五波实体压力与生产预算

- 正式生成阵列读取 `physics_navigation_v1.formal_wave_spawn` 与本波实际兵种半径；三列间距取配置下限和最大胶囊直径加净距的较大值。第五波骑射胶囊半径 `0.65 m`，因此使用 `1.40 m`，不再沿用会导致初始穿模的固定 `0.95 m`。
- 默认正式波次的逐敌索敌 / 攻击逻辑按每帧最多 `8` 人轮转。每个敌人分别累计未更新帧的 `game_seconds / combat_seconds`，轮到时再结算，故攻击间隔、伤害、移动 profile 与每人独立索敌不变；48 人在 6 帧内全部更新。实体运动、RVO、碰撞与动画仍逐物理帧运行。
- 正式战斗期接触扫描每 6 帧、避战目标复核每 3 帧；状态不变的正式敌人不重复刷新整套模型档案 / 标签，攻击动画由正常 profile 状态转换，不再反复调用返回完整快照的 debug 强制接口。
- A5-P2 专项覆盖 48 敌 + 8 NPC、非战斗持续避战、零导航失败、速度 / 单帧位移、胶囊净距、前排死亡后补位、轮转覆盖与清理零残留。隔离 CombatSystem 生产入口 P95 主线程约为 headless `4.70–5.19 ms`、D3D12 窗口 `10.52 ms`；完整 TimeSystem 的跨模块 P95 长帧另由 A5-P3 审计，不能把本结果表述为 Main 全系统性能验收。

## T0129C-A5-P1 全员正式战时空间与非战斗避战

- 默认波次启动时，CombatSystem 向 NPCSystem 请求全部 NPC；NPCSystem 只迁移当前可行动者，并保存每个 Body 的原坐标、导航开关和 NavigationMap。初始正常状态下 8 人均进入生产 NavigationMap；暂时昏迷等不可行动者可合法跳过，不会阻断波次，锚点缺失或导航绑定失败仍属于真实失败。
- `combatant_npc_ids` 继续只列入伍持主武器者；其余已迁移者列入 `noncombatant_npc_ids`，敌人可以按真实同图 Body 发现他们。未入伍或无主武器者仍由既有接敌规则进入 `avoid_combat`，没有被强制征召或赋予攻击能力。
- 避战候选按圈内全部敌军的距离逆平方合成反方向，并在一个完整避战半径外生成原始目标；A5-P1/T0209 对正式 NPC 把目标限制到驿站内实体旁可达 NavMesh，NPCSystem 再通过 ActorMotionBody 请求真实运动。道路没有权重，静态碰撞、实体碰撞和 avoidance 决定路线；不以字典位置或后台地点代替到达。
- 战中逃离出口动态解析到正式地图边缘 `(-54,-305)`；NPC 经后门单向链接进入 6 点 / `261.302 m` 后路 NavigationRegion。对话恢复和复苏恢复刷新并保存同一最终坐标，实体到达后才提交 `escaped`。

## T0129C-A4-P7 / T0129B-C3-P7 五波动态接敌压力

- `debug_run_formal_dynamic_wave_slice(wave_number)` 复用唯一正式实体工厂并覆盖 1–5 波。每个敌人独占 ActorMotionBody、实体胶囊、NavigationAgent、目标、射程与攻击状态；骑兵 / 骑射使用 `enemy_mounted` 体积，其余使用 `enemy_foot`。
- P5/P6 按出生编队预绑的固定攻击位与剑盾 / 长杆硬排不再参与当前运行逻辑。每个敌人仍独立查找目标；T0149 在选定目标后按当前目标轮廓、实体半径和武器射程动态申请可达租约，追击者向自己的租约点请求最短可行路径，道路仍没有权重。
- 取得租约且抵达有效射程者暂停移动并进入既有时间轴 / 物理命中链；未抵达者继续向自己的位置移动，目标满员者去候补等待点。`stuck_timeout` 会释放并短暂屏蔽失败位置，再重分配或候补，不能伪造到达或永久退出战斗；目标移动超过 `0.35 m` 或前排位置释放后会重新请求路径 / 同步补位。
- P7b 已把默认 `spawn_wave()` 接入正式坐标世界；A5-P1 又接入全部当前可行动 NPC与战斗期非战斗避战，A5-P4c / C4-P2 已接入正式战时长逃离。A5-P5a 已接入托马的单建筑正式 `work_stable`，其余非战日常建筑行动与默认商人仍待正式世界总切换。

### A4-P7b / C3-P7b 默认敌我正式战斗世界

- `spawn_wave()` 直接复用 `_spawn_formal_dynamic_wave()`；默认波次在 `FormalEnemies` 创建实体，显式 GM P7 切片仍走同一工厂但保持调试生命周期。默认日程允许在已有正式战斗中追加后续波次，ID 由运行序列保证唯一。
- NPCSystem 的 `begin_formal_combat_world()` 在 A5-P1 起迁移全部当前可行动 NPC，保存原坐标与导航模式，绑定生产 NavigationMap；`end_formal_combat_world()` 统一停止运动、恢复原坐标和兼容模式。CombatSystem 不直接写 NPC 最终坐标。
- 默认正式敌人只查询已迁入同图的 NPC，读取其 CharacterBody 实时位置；位移超过 `0.35 m` 时各敌人独立重规划。警铃阵位以正式正门内侧为基准，战术点吸附生产导航图。
- 清敌、自然战斗结束或系统重置都会退出正式运行世界并恢复镜头。战斗期可行动非战斗人员与敌人同图；未迁移的不可行动者会被目标查询过滤，避免跨坐标世界追逐。

### A4-P7R / C3-P7R 拥堵运动稳定性

- 每个正式敌人的 NavigationAgent `max_speed` 等于 ActorMotion profile `base_speed`。RVO safe velocity 即使给出更快或反向的局部修正，也要先限速，再经过同一加速度约束后才能交给 `move_and_slide`；不能产生独立于兵种移动速度的横向弹射。
- P6 固定队列遗留的行列 avoidance priority 已删除。正式敌人统一使用 `0.55`，`time_horizon_agents=0.6`、`time_horizon_obstacles=0.8`，保留实体碰撞和向目标持续施压。
- 表现朝向只在水平速度不低于 `0.35 m/s` 时更新，并限制为 `360°/s`；低速碰撞恢复保持上一有效方向。`pressing_to_* / pressing_for_attack_space` 视为移动，攻击与抬手始终朝向权威目标。
- P7 专项同时锁定 profile / Agent 速度一致、实际速度不越界、单帧位移不发生整个人体半径级弹出、单帧可见转角不超过约 `6°`、最小实体距离和前排空位补入。该稳定性修正没有降低碰撞、取消独立索敌或恢复固定攻击槽。

## T0129C-A4-P6 / T0129B-C3-P6 第二波混编正式实体（历史，运行策略由 P7 取代）

- `debug_run_formal_second_wave_slice()` 复用可指定波次的正式实体工厂，从 `enemy_waves.json / wave_02` 展开 12 名剑盾和 4 名长杆；每人仍独占 ActorMotionBody、NavigationAgent、碰撞胶囊、运行 slice 与死亡清理。
- 三个建筑目标仍只走最短可行路径且道路无权重。正门和仓库因正面有限使用同侧紧凑多排；主厅把 12 名剑盾展开在来袭侧前排，把 4 名长杆放在同侧后排，配置排间距 `2.1 m`。两类单位按角色各自领取槽位，不会用同一索引互相覆盖。
- 阶段建筑由先到者摧毁后，所有在途请求用 `superseded` 原子改向下一目标；不要求整波先在旧建筑前集合。第二波允许最长 60 秒有界拥堵恢复，宽松到达半径不超过对应武器射程，仍不得用超时伪造到达。
- 仓库转向主厅时，剑盾按当前物理位置领取最近未占前排槽，避免为追逐出生编号槽横穿已经成形的队列；12 名剑盾全部实际到位后，4 名长杆才进入后排，不会从后方堵住前排进路。专项连续两次实测两排各自纵深差 `0 m`、排间距约 `2.1 m`、零导航失败、2311–2336 次 avoidance，停止后零活动敌人与零正式节点。第一波 P5R2 回归保持通过。

## T0129C-A4-P5R2 / T0129B-C3-P5R2 第一波直攻与紧凑正面攻击位

- 第一波正式实体只以 `front_gate -> warehouse -> main_hall` 作为玩法目标序列。每次只向当前目标下发一个 NavigationAgent 目标，NavigationServer 在可通行地面上选择最短路径；道路、广场泥地和历史阶段 Marker 都不参与成本或强制途经。
- 城外与城内现使用同一静态碰撞烘焙的生产 NavMesh，密林、城墙与门洞仍形成真实阻挡；历史 6 横断面进军廊道已由 T0200 移除。目标销毁时，尚在途中者允许用 `superseded` 原子替换为下一建筑目标，不把旧请求取消误记为导航失败。
- 正门 / 仓库各有 8 个近战攻击位；主厅第一波使用北侧正面的 8 位单排攻击带，中心间距 `2.4 m`，不向四角、两侧或背面分配。第一波按稳定 formation index 领取独立位置并吸附到 NavigationMap；只有 ActorMotionBody 实际到达该位置后，CombatSystem 才设置 `attack_unlocked`。旧 P5 的碰撞边界超时假到达已经删除。
- 道路只属于表现层。本地 AStar 可达性合同也把墙内开放地面视为等价可走区域；敌我正式运动仍以 CharacterBody 碰撞、NavigationMesh、NavigationLink 和 avoidance 为约束，不允许穿建筑、围墙、家具或其他实体。

## T0129C-A4-P5 / T0129B-C3-P5 第一波正式实体

`debug_run_formal_first_wave_slice()` 从第一波权威配置展开 8 名敌人，每名都进入 `_active_enemies` 并拥有独立 `ActorMotionBody`、NavigationAgent、十阶段状态与攻击提交标记。3 列方向编队随当前路段旋转，目标先吸附到正式 NavigationMap；建筑外围因实体碰撞形成队列时，只在配置限定的建筑边界半径且持续移动 6 秒或卡住 3 秒后，把实际当前位置登记为该敌人的可达攻击位，仍不允许后台字典提前进入或攻击。

正门 / 仓库摧毁后，各敌人按自己的当前阶段继续推进；没有到达的后排不会继承前排的攻击权威。单体 HP 清零只删除自己的 Body、路径和 slice，最后一人或 `debug_stop_formal_first_wave_slice()` 继续复用既有时间倍率与战斗结束清理。本段是 P5 历史边界；P7 / P7b 已将五波、普通 `spawn_wave()` 与可战斗 NPC 接入动态正式链，器械和非战斗移动类别仍待后续迁移。

## T0129C-A4-P4 / T0129B-C3-P4 单活动敌人推进主厅

- `debug_run_formal_active_enemy_main_hall_slice()` 让一名正式活动敌人消费完整十阶段。仓库摧毁后清空旧攻击节奏并下发 `main_hall` 运动目标，实际到达前禁止选择 / 攻击主厅。
- `motion_arrived(main_hall)` 才设置主厅攻击目标和解锁标记；首次攻击继续为原配置 4 点，`main_hall_combat_authority_committed` 单独记录提交证据。
- 主厅最终伤害仍经过 `_apply_enemy_attack_to_building()` 和 `_trigger_main_hall_failure()`，由 GameState 提交 `failure / main_hall_destroyed`。P4 没有第二套失败条件；P3 / P2 API 只作兼容包装。

## T0129C-A4-P3 / T0129B-C3-P3 单活动敌人破门攻仓

- `debug_run_formal_active_enemy_warehouse_slice()` 创建一名真实活动剑盾敌人；P2 接口仅作兼容包装。其目标顺序为正门、仓库，但 CombatSystem 只在对应物理到达阶段允许选择目标。
- 正门摧毁后清空抬手 / 冷却并下发 `gate_turn`，ActorMotionBody 依次实际抵达 `gate_turn / north_junction / plaza_junction / warehouse`。途中 `_advance_enemy_ai()` 只报告物理移动，仓库 HP 不变；`motion_arrived(warehouse)` 才设置 `attack_unlocked=true` 并允许既有攻击链扣血。
- P3 当时的仓库后 hold 已由 P4 主厅实体路线取代；正门 / 仓库两项提交标记继续保留。

## T0129C-A4-P2 / T0129B-C3-P2 单活动敌人正门攻击

- `debug_run_formal_active_enemy_front_gate_slice()` 只创建第一波的一名真实活动剑盾敌人：进入 `_active_enemies`、启动时间倍率上限与 `combat_started`，实体位于正式根并沿 P1 路线运动。
- `ActorMotionBody` 抵达 `front_gate` 前，`_advance_enemy_ai()` 只能报告物理路线阶段，不能选择目标、直接改坐标或攻击。抵达后才把正式正门攻击点投影给既有目标选择，继续使用原攻击抬手、冷却、BuildingSystem 扣血和 `building_damaged`。
- P2 当时的正门后 hold 已由 P3 正式仓库路线取代；P2 专项仍锁定抵门前零伤害、首次正门伤害及清敌 / 死亡兼容。

## T0129C-A4-P1 / T0129B-C3-P1 正式敌军导航样片

- `CombatSystem.debug_run_formal_enemy_navigation_pilot()` 从第一波配置只读取得一名步兵样板，在远端正式根创建 `ActorMotionBody / enemy_foot`；它使用 `0.42 m / 1.8 m` 实体胶囊、layer 2 / mask 3、独立 interaction layer 4 和 NavigationAgent avoidance。
- 样片逐段消费 `station_layout.combat_spatial.enemy_route`，本步只走 `spawn -> reveal -> approach_mid -> contact -> front_gate`。物理到达后才推进阶段；正门到达状态是 `ready_to_attack_front_gate` 的空间预备态，不是攻击提交。
- P1 样片刻意不进入 `_active_enemies`，继续保留为无伤害空间基线；对外 GM 入口已由 P2 活动敌人攻门切片替换。

## T0129A 战场空间灰盒（尚未迁移）

- 当前 Main 敌人约在 `Z=29–31` 出生，距旧正门只有约 `17–19 m`；T0129A v0.9 灰盒把不规则前门放在 `(5,54)`、敌军林下出生区放在 `(2,335)`、远方林缘显现点放在 `(8,225)`，出生区距正门约 `281 m` 且嵌在地图边缘森林。仓库 / 主厅目标阶段点为 `(29,15)` / `(0,2)`，但尚未迁移正式 CombatSystem 坐标。
- 规划路线为林下出生 -> 林缘显现 -> 城外接触区 -> 正门 -> 仓库西侧攻击点 -> 主厅正面攻击点，继续遵守既有“正门 / 仓库 / 主厅”目标权威，不改变伤害、波次或胜负规则。
- 独立 `StationSpatialSandbox.tscn` 从第五波配置创建全部 48 个 `CharacterBody3D + CapsuleShape3D`（28 近战 / 4 长柄 / 10 弩手 / 6 骑射），沿细分后的 13 个队形节点 / 12 段路线从森林行进至主厅。全程压力采样零包络重叠、最小净距不低于 `0.12 m`，队形不越过配置道路 / 门宽，也不侵占无关建筑地块。该模拟不调用 CombatSystem，不结算伤害或胜负。
- C4-P2 已把灰盒结论落入 Main 正式战斗世界：后门到逃离完成点为 6 点 / `261.302 m`，按 `5 m/s` 普通逃离约 `52.26 s`、受击 `1.25x` 加速约 `41.81 s`，仍覆盖五轮至少 `30 s` 的干预窗口。途中保持 `escaping / escaped=false`，挽留、给钱、攻击和昏迷复苏继续有效；战斗先结束时，正式世界只为逃离者保留到其完成或留下。只有地图边缘实体到达才提交 `escaped / in_station=false`。非战日常默认路径仍待全图切换。
- 新距离会改变器械首射、敌我接触、集结和通勤时间。阶段 C 迁移正式坐标后，必须重跑五波平衡、敌人寻路、正门集结、后门逃离和器械射界；规划值当前没有进入 CombatSystem。
- 详细坐标、自然遮挡、集结排和镜头见 `docs/SCENE_SPACE_AND_VISUAL_PLAN.md`。

T0129C-A3 已在远端正式布局建立 234 个静态碰撞源：结构 78、地面 1、家具 131、自然边界 24，并生成独立 `0.25 m / 806 vertex / 772 polygon` 生产 NavigationMap；T0228 后主厅四器械平台与 `main_hall_slot_01–04` 的 `5 / 6 / 1 / 3` 解锁一致，仓库外沿攻击路线保持可达。当前活动敌人仍由 CombatSystem 创建 `Area3D` 并直接回写位置，A4 才会把实际路径 / 速度 / 避让交给 `enemy_foot / enemy_mounted` profile；伤害、攻击距离、目标优先级和胜负继续由 CombatSystem 权威结算。

## T0129 单敌战斗表现样片

- 格伦每次权威 HP 下降都会触发一次 GPU 血粒子和 CharacterPivot 短促位移回弹；表现计数和粒子状态只用于调试，不反写 HP、伤害或命中。
- HP 清零仍由 NPCSystem 提交 `unconscious=true`。T0133-P2 后，非骑乘生产 Chibi 首次昏迷会按需创建 12 个 PhysicalBone3D，最多同时模拟 6 人；约 1.8 秒后捕获姿态、停止物理并以骨骼覆盖冻结。复苏沿原 30% 权威阈值，在 0.42 秒内把覆盖权重渐隐回动画骨架并继续 `Lie_StandUp`。骑乘坠落和超预算单位继续使用既有受控 `Death_A`，表现层不改变 HP、碰撞权威或复苏门槛。
- CombatSystem 每次波次只把第一名敌人替换为红褐色 Quaternius 人形并在手部挂载青铜剑 / 木盾，其余敌人保留原轻量胶囊；正式样片仍由原敌人状态驱动移动、攻击、受击和移除。敌人败退后分离 `8.0 s` 的纯表现尸体，权威敌人会立即从活动集合移除。

## T0128 格伦战斗状态表现接线

格伦的统一状态机已经接收 `attack / hit_react / unconscious / get_up` 四类表现：攻击由既有 `attacking_* / winding_up_*` 行动选择，受击只在权威 HP 下降后触发，昏迷只在 NPCSystem 已提交 `unconscious=true` 后播放，复苏只在权威状态从昏迷切回清醒后播放。动画不拥有命中帧、伤害、HP 或复苏阈值。

T0128/T0129 的禁用模拟器占位已由 T0133-P2 接通：物理骨骼只在首次需要时创建，避免 48 个单位常驻全部刚体；模拟停止后保留姿态，复苏时回收到动画。旧 NPCArtView 仍是兼容表现，当前 Main 的 8 名 NPC 与四类步兵生产包装统一走 ChibiCharacterPilot；骑兵使用已验收坠马弧线。

## T0123–T0133 战斗美术表现边界

既有攻击 / 弹体事件现同时驱动 CombatVFXController：近战拖尾、投射物 / 人物命中闪光与火星、血液贴花、脚步尘和建筑碎屑均只读投影真实世界位置。NPC HP 清零后的权威结果始终是“昏迷”；恢复到 30% 后回收物理姿态并播放复苏起身，不出现死亡或永久尸体。

物理骨骼、碰撞、动画、粒子和贴花只消费 CombatSystem / NPCSystem / BuildingSystem 已确认结果，不反向计算伤害、HP、命中或建筑摧毁。当前预算为 6 个活跃布娃娃、28 个瞬时 VFX、12 个粒子源、14 个血迹和 22 个全部贴花；命中闪光使用无光照发光网格，不增加动态灯。血液可在设置→画面关闭。敌军密集接触时，CharacterBody3D 保留权威碰撞纠偏，EnemyArtView 使用最多 `2.5 × body_radius` 的局部补偿吸收单帧尖峰，再以 `1–2 m/s` 回收到物理根；步态采样读取限幅后的可见位移。独立 48 敌基准通过，可见位移峰值约 `0.097 m/帧`。A5-P2 仍有独立敌军胶囊拥堵风险，由 T0234 跟踪。

## T0121 全局数值合同与唯一失败条件

五波现固定在第 3–7 日每天 18:00 到达，敌军总量为 `8 / 16 / 24 / 36 / 48`，对应基准入伍 `2 / 3 / 5 / 6 / 7` 与器械 `1 / 1 / 2 / 3 / 4`。第五波工作流以 7 武器、8 防具、2 马、1 弩床 + 3 箭塔对 48 敌；弩床为 44 伤害、4.25 秒间隔。具体兵种、装备、人时与恢复账见 `docs/GAME_BALANCE.md`。

T1303 的 `no_available_combatants` 失败链已经删除。当前 Demo 唯一失败条件是主厅 HP 清零；全部 NPC 昏迷、逃离或无武器时不会立即结算，敌军与幸存器械继续推进。`tools/verify_t0121_fifth_wave_build.gd` 已验证 7 名 NPC 全部昏迷后器械完成 48 敌清理并进入最终胜利。

T0122 连续回放进一步覆盖跨波战损：自然路线第四波清敌后 6 人全部昏迷、主厅剩 `112 / 220`，该波仍正确判过，随后第五波因累积损失摧毁主厅；精细路线两次以确认的 7 武器、8 防具、2 马、4 器械满员进入第五波，均清空 48 敌并保住 `236–250 / 250` 主厅。胜利时 7 人可全部昏迷且器械有损失，仍不产生第二失败条件。当前连续证据不要求调整敌军配置。

陨石冲击按水平距离与敌人 ID 稳定排序，最多命中 12 个目标；燃烧仍可影响范围内其他敌人。战斗等级只读取最高单项武器 / 骑术训练经验，不读取职业总经验。

## T0118 斗志激昂对话内反馈

T0283 后，只有显式开启“鼓舞士气”toggle 的战时 NPC 回复才会把 `wartime_reaction` 与鼓舞请求标记绑定到本轮 history turn，并显示成功 / 逃离 / 继续参战结果。模型仍只表达意向，玩家完成对话后才由 `CombatSystem.apply_wartime_dialogue_reaction(...)` 应用持续至当天 24:00 的 buff 并写入 `battle_psychology_result / morale_boost_started`；取消会话仍不应用暂存效果。

## T0117 战斗 LLM 调用与手动验收口径

战斗期间可能出现三条直接业务调用：

1. 集结 / 战斗 / 避战中的守备官—NPC 对话，每个需要 NPC 回复的消息或普通攻击回合调用一次 `/npc/dialogue`（`call_type=dialogue`）。只有已入伍且持主武器、处于 `rally / combat` 的 NPC 可返回 `wartime_reaction=none|escape|morale_boost`；`avoid_combat` 对话强制为 `none`，只可沿普通对话合同处理应征。
2. NPC 在活动战斗中首次从不低于 30% HP 跌到 30% 以下且仍大于 0 时，调用一次 `/npc/battle_judgement`（`call_type=battle_judgement`）。实际 `combat` 且已入伍持主武器者的 `allowed_decisions` 为 `continue_fighting / escape_station / inspired`；其他避战 / 非战斗人员为 `avoid_battle / escape_station`。每名 NPC 每场只触发一次，直接清零、已经低于阈值、战斗已结束或迟到结果失效时不应用。
3. 正在逃离 NPC 的挽留消息，每个回复回合调用一次 `/npc/dialogue`，但使用 `dialogue_kind=escape_intervention`，唯一业务结果为 `escape_intervention_result=stay|leave`。挽留中的守备官攻击是显式无回复路径，不调用 `/npc/dialogue`、不写 stay / leave，只计一轮并加快逃离。

已完成的守备官对话（含战时公开对话与逃离挽留）还会为目标 NPC 调用一次 `/npc/plan_revision_judgement`；只有判别返回非空 `revision_hours` 时才追加 `/npc/revise_plan`。因此一个单回合且正常完成的战时 / 挽留会话通常能在 usage 中看到 `dialogue -> plan_revision_judgement ->（条件性）revise_plan`。低血量判定本身通常只有 `battle_judgement`；若它强制结束了已有且有内容的对话，结束对话仍可额外产生上述计划判别链。警铃、刷波、敌我自动攻击、程序启动逃离和清敌本身不调用 LLM。

手动验收建议在真实 provider、有效 Key、`LLM_FALLBACK_TO_MOCK=false` 下逐项重开场景隔离：

- 战时公开对话：GM 执行 `spawn_wave 1`、`alarm`，用 `behavior_modes` 确认艾达处于 `rally` 或 `combat`；必要时用 `step_enemies 1` 逐秒推进。点击艾达对话，分别用“守住缺口、一起撑住”和“局势已失，立刻从后门撤离保命”等明确话术，收到回复后点击完成。用 `enemies` 查看 `last_wartime_dialogue_result`，并检查 NPC 的 `morale_boost` 或 `escape_intent`。注意效果在完成会话时应用，单看回复但不完成对话不足以验收程序结果。
- 低血量参战者：保持敌人在场并先用 `behavior_modes` 确认艾达为 `combat`；新游戏艾达为 `120/120`，可执行 `damage_npc veteran_deputy_01 90 local_public` 让其跨入阈值且不昏迷。用 `enemies` 检查 `last_low_hp_judgement_result.decision`、`psychology_decision`、`llm_ok` 与 `rule_fallback`；真实结果合法值为继续战斗、逃离驿站或 `inspired`（程序映射为斗志激昂）。GM 扣血以守备官为伤害来源，可能另触发既有计划重估；核对低血量模型时应按 `call_type=battle_judgement` 过滤。
- 低血量避战者：有敌人时执行 `avoid_npc priest_01`，确认其为 `avoid_combat`；新游戏神父为 `85/85`，可执行 `damage_npc priest_01 64 local_public`。此时只允许 `avoid_battle / escape_station`，绝不应返回 `inspired`。
- 逃离挽留：执行 `escape_npc priest_01` 只建立程序逃离状态，本身不调用 LLM。回到主界面点击该 NPC，再点【对话】，分别使用明确挽留或放弃话术；检查响应的 `escape_intervention_result=stay|leave`、`active_escapes` 和 `last_escape_result`。点击攻击应看到 `llm_requested=false / guard_attack_no_reply`，不能把它算作模型选择。

低血量自然多选结果受人物与战局上下文影响，不保证一句话或一次伤害就覆盖 `escape_station / inspired`；需要重复测试时应清敌并开始新战斗，最好重开场景恢复未逃离、未加 buff 的基线。真实 provider 成功必须同时确认 usage 中 provider / model 正确、`fallback_used=false`，不能只看 Godot 的规则降级结果。

## T0114 虔诚陨石与无友伤边界

守备官在共享虔诚满 100 后可选取合法地表召唤陨石。默认半径 5.5 米、下落 1.15 战斗动作秒；落地使用 48 点攻击力与 5 点穿透，对范围内按距离和敌人 ID 稳定排序的最多 12 个目标结算一次冲击。随后地面燃烧 10 战斗动作秒，每 1 秒以 1 点攻击力、0 穿透对当时仍位于范围内的敌人结算一次；燃烧不受冲击 12 人上限限制。

两段伤害均只经过 `CombatSystem.apply_enemy_area_damage(center, radius, raw_attack_power, context)`：该入口只遍历 `_active_enemies`，用水平距离判断范围，并复用 `有效防御=max(0, defense-penetration)` 与 `20/(20+有效防御)`、敌人死亡和正常清敌 / 战斗结束结算。它不枚举 NPC、建筑或我方工程器械，也不调用三者的伤害入口，因此陨石和燃烧严格没有友伤；友方站在落点内也不会损失 HP。

T0173 起，待落陨石使用现实帧时间推进配置的 2.8 秒下落，并显式读取 TimeSystem 主动暂停状态：暂停时停止、恢复后继续；NPC 移动 / LLM 等待的 `1/60` 慢速以及玩家 x1 / x2 / x4 不改变下落时长。T0183 起，燃烧持续时间直接消费统一战斗游戏秒，配置 `combat_action_game_seconds_per_second = 1`。所有半径、时序、伤害和穿透都来自 `data/piety_ability.json`；HUD 只提交目标位置，不能自行扣虔诚、伤害或清敌。

T0172 起，选定落点与消费虔诚不再写 `piety_meteor_cast`；只有陨石真正落地并由 `apply_enemy_area_damage(...)` 返回冲击结果后，才写入全站公开 `piety_meteor_impact`，摘要固定为“由于全站虔诚祈祷，天降陨石砸向敌人并点燃了地面，而我方毫发无损。”。若权威 `defeated_count > 0`，再生成独立 `piety_meteor_enemy_defeated` 并记录实际人数；零击败不生成，燃烧 tick 仍不写重复事件。两类落地事件只解释已结算事实，不参与敌人 HP 或战斗结束判定。

## T0087 逃离挽留响应合同

逃离挽留不再从通用 `intent` 解析结果。`dialogue_kind=escape_intervention` 的唯一业务字段是 `EscapeInterventionDialogueResponse.escape_intervention_result`，值只能为 `stay` 或 `leave`。CombatSystem 仍负责暂停 / 恢复移动、记录轮次、第五轮收口、停止逃离或继续逃离并写入事件；LLM 不决定速度、位置、行为模式或事件事实。守备官攻击的无回复路径记录 `intervention_result=guard_attack_no_reply`，不伪装成 NPC 的 stay / leave 选择。

## T0081 战时生活消耗

`NPCNeedsSystem` 按行为模式为战时 NPC 选择唯一生活消耗档位：集结与避战每小时 `-4 饱食 / +8 疲劳`，逃离 `-5/+10`，战斗 `-8/+16`。战斗档位是重工作的两倍，移动 / 集结 / 避战 / 逃离均不增加职业经验；逃离挽留对话在逻辑时间推进时按对话档位处理。真正 `escaped=true` 的 NPC 不再参与站内生活模拟。

这些数值只消费 TimeSystem 已计算的有效逻辑秒：暂停不推进，敌人在场的 `1/60` 慢速（现实 1 秒 = 游戏 1 秒）自然生效；NPCNeedsSystem 不读取玩家倍率来额外放大战斗数值，也不修改 CombatSystem 的攻击、伤害、冷却或战斗移动公式。

## T0067 真实战斗心理与逃离链路验收

正常参战仍是程序状态机结果，不由 LLM 直接决定：NPC 必须已入伍、持有主武器、可行动且场上有敌军，才会从集结 / 接敌或避战装备分流进入 `combat`。真实 Main 场景已验证格伦在 `avoid_combat` 中接受应征后仍因无武器继续避战，实际装备剑盾后自动进入 `combat`。

低血量真实 Main 验收中，`continue_fighting`、非战斗人员的 `avoid_battle` 和 `escape_station` 已自然触发；后者实际进入逃离模式。参战低血量的 `escape_station` 与 `inspired` 在多组完整高压 / 有利上下文中仍被模型选择为 `continue_fighting`，但每个结果作为唯一允许项时均由同一真实 provider 正确返回并通过业务校验。另一个真实 `combat` 对话场景已自然返回 `wartime_reaction=morale_boost` 并实际应用士气，说明士气程序路径正常；当前偏置集中在低血量多选判定和战时逃离选择。

异步低血量结果应用前会重新确认：NPC 仍存在、未昏迷 / 离站、HP 仍低于阈值、仍可行动、行为模式与战斗资格未变、敌军仍在，并且当前战斗的 `wave_id + started_event_id` 与请求发起时相同。任一条件变化都把结果标为 `discarded`，不写 `battle_psychology_result`、不加士气且不开始逃离。

逃离开始现通过 `NPCSystem.set_npc_behavior_mode_and_move_to_world_position(...)` 原子完成行为中断、模式 / 状态提交和出口移动。预检或启动移动失败时不写 `escape_started`、不留下活动逃离；昏迷复苏后的续逃也复用同一接口，失败会把意向标为 `resume_failed`、移出活动逃离，再按现有敌军 / 装备条件走正常工作、战斗或避战分流。战时对话完成时触发逃离还增加了 DialogSystem 会话结束重入保护。

## T0054 驿站规则与战斗权威边界

共享 `station_rules` 以站内口吻告诉 NPC：遇敌时已入伍且有主武器者保卫驿站，未入伍或没有主武器者尽量在站内避敌，低士气者可能离开甚至临阵脱逃。这用于对话、计划、战时心理和反思保持同一世界观，不直接切换 `behavior_mode`，也不自行触发警铃、集结、避战或逃离。

实际资格仍由 CombatSystem / NPCSystem 根据征召、主武器、昏迷、逃离、敌人在场和当前状态判断；战时 LLM 只能在本次 `allowed_decisions` 中选择。规则里的“可能”不得被模型当作已发生事实，士气影响与逃离流程也继续走现有程序入口和事件记录。

## T0053 战时心理人物上下文一致性

低血量心理判定继续只在程序确认的阈值事件后触发，`CombatSystem` 提供 `combat_context / battlefield_context / allowed_decisions`，`LLMBridge` 通过共享 `NPCContext` 同时注入 NPC 职业与人格、欲望 / 恐惧 / 底线、权威状态、当前守备官指令、亲历 / 见闻短期记忆、`long_term_memory={knowledge_graph, diary}` 和地点。参战者的继续战斗 / 逃离 / 鼓舞与非战斗人员的继续避战 / 逃离因此使用和日计划、计划判别、正式修订一致的人物依据；长期记忆不能覆盖低血量或战场权威事实，也不能让非战斗人员绕过 `allowed_decisions` 直接参战。

## T0025 日程行动与战斗权威边界

`escaping_station` 可作为每日计划 / 修订中的特殊逃离意向，但 DailyPlanSystem 只把它交给 `CombatSystem.start_npc_escape(...)`，不会按普通 ActionSystem 行动直接改写逃离状态。集结、战斗、避战、昏迷和已进入逃离流程的 NPC 不执行日常计划，也不能成为即时自主闲聊目标；这些权威模式切换会结束自主对话，且结束清理不会把参与者强制恢复为 `idle`。`escape_intervention_dialogue` 仍是玩家干预入口，不进入计划候选。

T0049 后，战斗结束或无敌军时复苏并返回工作模式属于非对话计划触发：不调用对话判别层，直接以 `revision_scope=selected_hours`、`revision_hours=[current_hour]` 修订当前阶段。战时守备官对话和逃离挽留对话仍按实际对话内容先判别；对话窗内已经提交的攻击即使没有 NPC 回复，也作为本轮事实进入同一判别。仍在战斗 / 避战 / 逃离等高优先级模式中的复苏不强行派发日常计划。

## 战斗目标

战斗系统用于制造外部压力。  
它不是项目的唯一核心，真正的核心是战前动员、战中崩溃、战后记忆反噬。

战斗数值不再绑定玩家时间倍率。伤害、攻击间隔、攻击速度和战斗移动速度按配置、属性、熟练度、装备、防御和战斗状态计算；玩家选择 `x2` / `x4` 不会让战斗数值同步加快。战斗仍由 TimeSystem 的逻辑 tick 推进，暂停会停止推进，LLM 等待可通过全局慢速让战斗暂时变慢，但 CombatSystem 不读取玩家倍率作为额外伤害、攻速或移速输入。

当场景中存在任意活动敌人时，CombatSystem 会向 TimeSystem 注册 `combat_enemy_presence = 1/60` 慢速，使游戏内 1 秒等于现实 1 秒。玩家选择值继续保留；NPC 移动和 LLM 等待使用相同倍率，不会把战斗再次降得更慢。所有敌人消失后释放该请求，恢复玩家原先选择的正常时间倍率。

## 行为模式

T1103A 起，战斗相关运行时以 NPC 行为模式为主线，而不是“战斗触发时全员心理判定”。当前已保存并展示 `states.behavior_mode`，同时保留 T1103 的 `combat_mode` 兼容字段用于旧集结视觉。运行时至少区分：

| 模式 | 适用范围 | 行为 | 进入条件 | 退出 / 切换 |
|---|---|---|---|---|
| 工作模式 / 日常模式 | 所有未昏迷、未逃离 NPC | 按计划行动、处理异常、被对话打断、计划重评估 | 默认模式；其他模式结束后返回 | 警铃、接敌、非战斗人员遇敌、昏迷、逃离等高优先级事件打断 |
| 集结模式 | 已入伍、有主武器、当前可行动且没有合法攻击目标锁的 NPC | 前往城门外防线并等待接敌 | 守备官摇响警铃；原工作、睡眠、避战、旧集结或无目标战斗模式均可被同一次命令覆盖 | 集结开始时、途中或集合点按正常友军索敌域发现敌人后进入战斗模式；到达集合点等待 1 游戏小时仍未接敌，返回工作模式且不重评估计划 |
| 战斗模式 | 已入伍且有主武器的可战斗 NPC | 按兵种和战斗策略自动战斗 | 从集结模式接敌；或工作模式中敌人进入一定范围；正在睡觉的持武器入伍 NPC 只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式并重评估计划；HP 清零进入昏迷 |
| 避战模式 | 非战斗人员：未入伍 NPC，或已入伍但无主武器 NPC | 按敌人接近方位逐步远离，尝试离开接敌范围，不攻击敌人 | 非战斗人员附近出现敌人；正在睡觉的非战斗人员只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式；避战中应征但仍无主武器时继续避战，装备主武器且仍有敌人时进入战斗模式 |
| 逃离驿站 | 逃离意向已被程序应用、尚未离图的 NPC | 朝后门外出口移动；可被玩家进行最多 5 轮挽留 | 战时对话、低血量判定、逃离挽留失败或 GM 调试触发 | 到达出口后标记 `escaped=true`；挽留结果为留下时返回工作模式并重评估计划；昏迷后暂停，复苏继续逃离 |

避战模式是非战斗人员的同级行为模式，不等于已入伍且有主武器 NPC 在战斗模式中可选的“避战策略”。后者仍属于战斗模式。

任一高优先级模式触发时，如果该 NPC 正在与守备官对话，系统必须强制完成当前已有会话、关闭对话框并取消可取消 LLM 请求；未完成的 NPC 回复不伪造，但已经说出口的守备官消息和攻击事实随会话入库并进入判别。如果 NPC 正在做普通计划行动、移动、工作、吃饭、训练、治疗或计划 LLM 活动，系统应中断并进入新模式。睡觉 NPC 通常不因附近敌人直接切换模式，只有被敌人攻击时才按入伍状态和主武器进入战斗或避战。

模式切换的权威边界由 NPCSystem 维护；T0299 起所有模式变化都只保留在运行态 / GM 快照，不生成通用模式事件。避战开始 / 结束、攻击、受伤、警铃、集结、昏迷、复苏和逃离仍由具体事件记录。昏迷 NPC 复苏后按场上敌军、入伍状态和主武器分流：仍有敌军时，已入伍且有主武器者进入战斗模式，未入伍或无主武器者进入避战模式；没有敌军时返回工作模式并重新评估计划。

## 战斗触发

触发入口：

1. 守备官手动摇响警铃，所有已入伍持主武器、当前可行动且没有合法攻击目标锁的 NPC 进入集结模式；已锁定目标者保持原战斗状态。
2. 已入伍且有主武器 NPC 在工作模式或集结模式中接敌，进入战斗模式。
3. 未入伍 NPC、已入伍但无主武器 NPC 在工作模式中遇敌，进入避战模式。
4. 睡觉中的 NPC 只有被敌人攻击时才从睡觉进入战斗 / 避战。

> 历史说明：下段保留 T1103 当时的实现记录，其中“睡觉不响应”和独立近距接敌规则已由本页顶部 T0224 统一规则替代，不再代表当前警铃行为。

T1103/T1103A/T1103B/T1103C 已完成玩家手动摇响警铃后的集结、模式切换和非战斗人员避战闭环：HUD `AlarmButton` 和 GM `alarm` / `rally` 都调用 `CombatSystem.trigger_combat_alarm(...)`。警铃会给所有 NPC 写入 `combat_alarm_rang` 结构化事件；随后只有已入伍、已装备主武器、当前可行动且非睡觉的 NPC 响应集结并进入 `behavior_mode == "rally"`。响应者的普通日常行动会通过 `NPCSystem.set_npc_behavior_mode(...)` 的中断边界打断并释放工位，再移动到城门外防线。T0160 后阵型按步行近战居中前排、步行弓弩居中后排、所有骑乘单位分列左右翼，方向标记面向正门外敌人来袭方向。T0138-R1 后，已分配成年马在警铃 / 接敌时仍留在马厩，响应 NPC 先导航到马旁，实际抵达并标记 `ridden` 后 CombatSystem 才显示坐骑并继续集结 / 参战；日常工作模式下同样不显示骑乘。若集结途中或集合点附近遭遇敌人，只有已入伍且有主武器 NPC 会停止集结并进入 `behavior_mode == "combat"` 与 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy` 具体事实，模式切换本身不入库。未入伍或已入伍但无主武器 NPC 在工作模式中接敌会进入 `behavior_mode == "avoid_combat"`，按最近敌人方位生成短距离散射移动目标，不设置战斗 `combat_mode`，也不攻击敌人；睡觉中的非战斗人员只有被敌人攻击才进入避战。集结到点后等待 1 游戏小时仍未接敌会返回 `work` 且不触发计划重评估；场上敌人清空时，`combat` NPC 返回 `work` 并触发计划重评估，`avoid_combat` NPC 返回 `work` 且不触发计划重评估。T0299 起所有模式互转均不写通用模式事件，具体战斗和避战事实由 `attack_made`、`damage_taken`、`avoidance_started`、`avoidance_ended` 等事件表达。T1104 后，`combat` 模式中的入伍持主武器 NPC 已能执行基础自动攻击、扣除敌人 HP 并在敌人 HP 清零后移除敌人。T1105 后，战斗模式会按 NPC 当前手动选择的兵种策略决定基础攻击前的战术移动与攻击节奏。T1106 后，波次生成和敌军清空会分别写入广场 `combat_started` / `combat_ended`，并维护本场受伤、昏迷和击退统计；T1201 后，战时公开对话可应用斗志 buff 或触发逃离；T1202 后，战时低血量自身心理判定已接入；T1203 后，逃离会移动到后门外出口并在离图后标记 `escaped`；T1204A 后，逃离过程中可通过 NPC 面板进行最多 5 轮挽留，打开对话暂停逃离移动，未满 5 轮关闭恢复，给钱减速，逃离攻击加速且不请求 NPC 回复，并在昏迷复苏后继续逃离；T1302 后，主厅被摧毁会进入失败占位结算并停止正常推进；T1303 后，活动敌人在场且所有已入伍持主武器战斗人员均昏迷、已逃离或正在逃离时，会进入无可战斗人员失败；T1304 后，包含第 5 波的战斗清敌会进入 Demo 胜利占位结算并停止继续刷波。NPC 结局总结和命中 / 格挡仍留给后续任务。

### 骑战会合与马匹分伤（T0138）

- T0138-R1 后，有具体分配马的 NPC 进入 `rally / combat` 会先处于 `combat_mount_phase=going_to_stable_horse`；马保持在自己的真实马厩锚点并使用 `waiting_for_rider_at_stable`，不再参与双向会合。NPC 从实时位置经正式 NavMesh 前往马旁最近可达点，抵达前 `combat_mounted=false`，友方攻击推进跳过该 NPC；抵达后才进入骑乘，并在集结场景继续前往阵位或在战斗场景进入 `combat_ready`。
- 敌军对骑乘 NPC 的攻击先完成既有攻击、防御与穿透结算，再由 HorseSystem 随机把整数伤害的 `30%–50%` 分给实际所骑马匹并先扣马 HP，NPC 只承受剩余伤害。分伤比例来自 HorseSystem RNG，专项可固定种子，但 UI / LLM 不参与随机或 HP 写入。
- 马 HP 先清零：马进入 `dead`，双方分配与 `equipment.mount` 清空，NPC 保持战斗但 `combat_mounted=false`，立即使用步战属性 / 表现。NPC HP 先清零：沿既有昏迷链提交人物事实，存活马立即解除双方分配并进入 `returning_stable`；坠马动画尚未制作。
- 正常退战不会解除分配，马从当前骑乘位置返回原马厩锚点；只有到达后才重新计入在厩数量。工作模式以外的玩家装备 / 马匹变更统一拒绝。

## 兵种判定

兵种由装备和坐骑决定：

| 装备组合 | 实际兵种 |
|---|---|
| 剑盾 | 近战步兵 |
| 长杆武器 | 长杆步兵 |
| 弓 | 弓箭兵 |
| 弩 | 弩兵 |
| 近战武器 + 马 | 近战骑兵 |
| 远程武器 + 马 | 骑射单位 |
| 无武器 | 非战斗人员 / 避战单位 |

T0804-T0806 曾使用 `weapons` / `armor` / `defense_devices` / `horse_readiness` 聚合库存作为最小占位；T0035-T0038 已完成正式迁移，这四个 id 只保留兼容且不得正式消耗。铁匠铺 / 工械坊现在按分阶段配方产出剑盾、长杆、弓、弩、四个盔甲部位、弩床和箭塔各自的 `item_*` 库存，EquipmentSystem 逐件消耗 / 返还武器与盔甲的具体来源。坐骑由 HorseSystem 中的真实成年马分配，`equipment.mount` 只是带 `horse_id` 的兼容投影。T0031 后，艾达在新游戏初始化时从正式武器定义直接装载剑盾，开局兵种为近战步兵；这份故事装备不扣库存、不记录守备官赠送事件。T0902 后，兵种判定通过 `get_unit_type_snapshot(...)` 供 GM 与 CombatSystem 读取。T0107 后 CombatSystem 以 NPC 配置 `combat_base` 为人物差异起点，读取主武器伤害 / 射程 / 间隔、武器与盔甲的攻击 / 防御 / 穿透 / 攻速修正，以及坐骑战斗参数，统一生成基础、成长、装备、状态和最终战斗属性快照。EquipmentSystem 本身仍不结算攻击、防御、耐久或策略行为；器械部署仍由 DefenseDeviceSystem 权威处理。

T0903 后，训练场可以提升后续战斗会读取的武器熟练度和骑术。训练项目由受训 NPC 当前装备决定：主武器对应剑盾、长杆、弓或弩，坐骑对应骑术。T0043 后，全部有效教官位上的 NPC 以人数、“教练”和对应项目熟练度组成共享团队效率，同时作用于全部训练位；受训者按自己的装备成长，在岗教官提升“教练”。训练只改变 NPC 熟练度和基础状态消耗，不直接结算攻击、命中、伤害、防御、骑乘表现或当前战斗策略选择。

## T0034/T0036/T0038 具体库存与马匹战时生命周期（当前已实现）

具体库存迁移已落地：剑盾、长杆、弓、弩、四个盔甲部位、弩床和箭塔都必须消耗各自具体 `item_*` 库存；`weapons`、`armor`、`defense_devices` 聚合库存不再是可互换的正式结算来源。弓、弩、箭塔和弩床按既有攻击节奏与实体弹体工作，不读取或扣除额外弹药库存。

坐骑已由 HorseSystem 中的真实马匹实体承担，不再由 `horse_readiness` 生成匿名槽位。分配与战时切换规则如下：

- 分配前置为“NPC 已入伍且有主武器”；只能分配成年、未被占用、物理上位于马厩的马。分配建立预留关系，但 `work` 模式下马仍在马厩，NPC 兵种快照可以预览骑兵类型，世界表现不显示骑乘。
- NPC 进入 `rally` 或 `combat` 时，HorseSystem 将其已分配马标记为 `location= ridden`、写入 `ridden_by_npc_id`，并从马厩数量中移除；CombatSystem 只消费该权威结果显示骑乘和判定骑兵，不自行复制马匹。
- NPC 从 `rally` / `combat` 回到 `work`（包括集结超时、清敌、战斗结束）或进入 `unconscious` 时，马返回马厩并清除骑乘者，原分配关系保留。NPC 取消入伍、失去主武器或逃离驿站时，系统先让马返回马厩，再自动解除分配并清空坐骑槽；合法主武器之间的更换不解除。
- 若战时切换时分配马已不满足权威条件，NPC 不得凭旧装备槽生成坐骑，应按无坐骑兵种继续。马匹战斗受伤与马匹伤害分摊留给独立战斗设计，本轮不新增。

`equipment.mount` 只保存 `horse_id` / `horse_name` 和通用骑乘参数的兼容快照。HorseSystem 是马的位置、HP、饱食、成长、分配和骑乘关系的唯一权威；CombatSystem 不修改这些经营数值。马厩等级每升一级只使生育概率增加 10%，不影响战斗属性、成长速度、进食或自然恢复。

## 战时对话与心理结果

取消旧规则：战斗触发时不再全员进行一次心理判定。

T1201 已实现：已入伍且有主武器 NPC 在集结模式和战斗模式下可被守备官主动对话。该对话会：

- 强制 `local_public`，UI 中“同地点公开”默认开启且不可关闭。
- 在 Prompt 中明确当前模式是集结或战斗，并注入相关集结 / 战斗事件。
- 继承 T0603 对话上下文：NPC 设定、状态、短期事件库 / 见闻库、长期记忆、地点上下文、对话轮次和当前 `current_order`。
- 额外加入战局上下文：敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC 列表，仍在驿站但非战斗人员的 NPC 列表。
- 在回复结构中额外输出战时心理意向，例如 `wartime_reaction = none | escape | morale_boost`。

`morale_boost` 由 CombatSystem 应用为斗志激昂 buff，持续至生效当天 24:00，当前提高攻击力和 NPC 实体移动速度各 15%。开始和结束分别写入 `morale_boost_started` / `morale_boost_ended`；每次战时心理结果写入 `battle_psychology_result` 并进入广场公开事件。`escape` 由 T1203 的 `start_npc_escape(...)` 执行：写入 `escape_started`，让 NPC 前往后门外出口，并在离开地图后写入 `escaped`。T0087 后，逃离挽留回复只解析 `escape_intervention_result=stay|leave`；停止逃离、继续逃离、对话暂停 / 恢复、移动倍率、昏迷暂停和复苏续逃都由程序结算。LLM 不直接改 HP、速度、攻击力或逃离位置。

非战斗人员在避战模式下也可被守备官主动对话。该对话同样强制 `local_public`，Prompt 明确其正在躲避敌人袭击，并注入战局上下文。守备官仍可勾选“提出应征”，征召结果沿用日常对话逻辑；若避战中的 NPC 同意应征但仍无主武器，继续避战；只有已入伍且装备主武器并且场上仍有敌人时，程序才将其切入战斗模式。后端不可用或真实 provider 失败时，战时对话会使用规则 fallback 生成回复、应征结果和 `wartime_reaction`，但必须记录真实失败原因，不得用 mock 回复伪装模型成功。

## 低血量判定

T1202 已实现：当前战斗 / 敌人在场期间，当任一未昏迷、未逃离 NPC 的 HP 首次从不低于 30% 跌破 30%，且仍大于 0 时，触发自身心理判定。该判定不只覆盖 `combat` 模式中的已入伍持武器 NPC；`avoid_combat` 中的非战斗人员被敌人追上并打到残血时也会触发。

参战 NPC 的可能结果：

- 继续参战
- 逃离驿站
- 斗志激昂

不参战 / 避战 NPC 的可能结果：

- 逃离驿站
- 留在驿站继续避战（无事发生）

该请求由 `LLMBridge.request_npc_battle_judgement_async(...)` 异步调用 `/npc/battle_judgement`，没有守备官本轮发言，只根据 NPC 自身上下文、当前 `current_order`、亲历 / 见闻、低血量事实和战局上下文判断。每名 NPC 每波或每场战斗最多触发一次；返回时若战斗已经结束或波次已变化，旧结果会被丢弃。后端失败或输出越界时，Godot 按允许结果规则降级，并保留真实 provider 失败日志。开发期可用 mock 验证 Schema，Prompt 验收必须使用真实 API。

T1404 后，真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，Prompt 明确引用 `battlefield_context`、NPC 亲历事件、公开见闻和最新 `current_order`，但只能从请求的 `allowed_decisions` 中选择。后端在 `BattleJudgementResponse` Schema 校验后额外校验 `decision` 属于 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；越界结果返回 `model_output_invalid` 并写入 usage。真实 DeepSeek 已完成战时公开对话与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。

已入伍且有主武器、实际处于 `combat` 模式的 NPC 可以因判定获得斗志激昂或继续参战。未入伍 NPC、已入伍但无主武器 NPC、以及处于 `avoid_combat` 的非战斗人员，不会获得斗志激昂，也不会因此切入或继续战斗；他们只能触发逃离驿站意向，或继续留在驿站内避战。

低血量与逃离相关判定也必须继续携带最新 `current_order`，让 NPC 在受伤或恐惧时重新解释守备官要求，而不是把发布指令时的旧判断当成永久结果。已昏迷、已逃离、HP 已经低于 30% 后再次受击，或 HP 直接清零进入昏迷的 NPC 不触发该判定。

判定等待期间，守备官不能与该 NPC 对话。如果触发时守备官正与该 NPC 对话，当前对话被强制结束并取消未完成 LLM 请求，随后进入自身心理判定。该异步判定不设置 Godot 响应总时长，需要申请 TimeSystem 慢速，并在完成、失败、取消、连接 / 空闲错误或规则降级后释放。触发事实写入 `low_hp_triggered`，判定结果写入 `battle_psychology_result`，并通过 `debug_get_combat_snapshot().last_low_hp_judgement_result` 与 `active_battle.low_hp_judgements` 暴露给 GM / 自动化验证；模型失败原因通过后端 usage / 日志排查，不用 mock 结果遮蔽。

## 昏迷机制

NPC 不死亡。  
HP 清零后在原地倒下并进入昏迷。

规则：

- 昏迷 NPC 不能移动、工作、战斗、对话或执行计划。
- 昏迷 NPC 不接收地点/广场公开广播或状态见闻，见闻库暂停更新。
- 昏迷 NPC 会极慢自然恢复 HP。
- 其他NPC可治疗昏迷 NPC，使其更快恢复。
- HP 恢复到 30% 后复苏。
- 复苏后按场上敌军、入伍状态和主武器进入战斗、避战或工作模式。
- 若场上无敌军，复苏后重新评估计划；若仍有敌军，按模式切换进入战斗或避战，不再使用旧式战斗前全员判定。

当前 T0501/T0502/T0502A/T0503 已实现 HP 扣除、昏迷状态、自然恢复、协助治疗、自动复苏和昏迷见闻暂停的最小闭环：`NPCSystem.apply_damage_to_npc(...)` 是权威扣血入口，GM `attack_npc` / `damage_npc` 可触发调试扣血；HP 到 0 后 NPC 设置为昏迷、停止移动并阻断行动。系统会写入 `damage_taken` 和 `unconscious_started` 结构化事件，昏迷事件按当前信息地点 `local_public` 广播给同地点 NPC。昏迷 NPC 会随 `TimeSystem.logical_time_tick` 以每游戏小时 2 HP 的速度自然恢复；其他可行动 NPC 可协助治疗，治疗按医术熟练度增加恢复速度并按逻辑时间消耗第纳尔，每个昏迷目标最多 2 名治疗者。HP 达到 Max HP 的 30% 后自动复苏、回到 `idle`、重新允许行动，并写入 `revived` 本地公开事件。昏迷期间 NPC 不接收见闻广播，复苏后恢复接收。T1104 后，敌人攻击 NPC 会先按 NPC 盔甲防御计算实际伤害，再复用同一扣血 / 昏迷入口；`damage_taken` payload 会保留原始攻击力、防御值和防御后伤害。

## 战斗策略

T0284 后，某名 NPC 可用哪些策略只由当前主武器和坐骑判定出的兵种决定。NPC 面板只读显示当前策略；玩家只能在合法战时对话中显式开启策略请求，由模型在当前兵种候选内表达保持 / 切换，再由 CombatSystem 权威复验和应用。默认统一为“主动进攻”。更换主武器或坐骑后，CombatSystem 会把策略重置为新兵种默认策略；更换盔甲不会重置策略。`current_order` 可作为上下文，但不自动决定、覆盖或推断当前战斗策略。

### 剑盾/长杆步兵

- 主动进攻
- 避战

### 弓/弩步兵

- 主动进攻
- 拉开距离射击
- 避战

### 近战骑兵

- 主动进攻
- 避战

### 骑马远程

- 主动进攻
- 拉开距离射击
- 避战

这里的“避战”是已入伍且有主武器 NPC 在战斗模式中的战术策略，不是非战斗人员的同级避战模式。

当前策略语义：

- 主动进攻：近战步兵 / 长杆步兵 / 近战骑兵主动接近敌人，进入武器射程后攻击。
- 拉开距离射击：该旧 `45% / 72% / 90%` 控制带已由 T0232 废止。当前以 `1/3` 射程近身圈触发最高优先级清锁撤离，单段原始长度为 `2/3` 射程；安全后恢复普通远程攻击位接近与射击。
- 避战：入伍持武器 NPC 的战斗策略，复用非战斗人员的多敌加权站内目标算法，但保持 `behavior_mode == "combat"`；该策略只在最近敌人低于战斗避战安全阈值时启动，敌人已经远离到阈值外时保持 `combat_ready` 等待，不继续退向驿站边界或角落；该策略不主动攻击，清敌后按战斗模式退出规则回到工作模式。

## 非战斗人员避战模式

未入伍 NPC、以及已入伍但没有主武器的 NPC 都属于非战斗人员，不进入集结和战斗模式。敌人进入 `39.2 m` 避战范围后进入避战模式；程序对圈内全部敌军的反向单位向量做距离逆平方加权，目标距离等于避战半径。目标越界会沿原射线收回站内，落在实体中会修正到实体旁可达点，因此不会进入逃离驿站流程。只有当场上没有敌军后，避战 NPC 才退出避战回到工作模式。

T0209 当前实现：`CombatSystem` 在敌人接触扫描中检测工作模式非战斗人员，调用 `NPCSystem.set_npc_behavior_mode(..., "avoid_combat")` 并通过 `move_npc_to_world_position(...)` 移动到加权且已修正的站内目标。避战快照保存在 `active_avoidances`，包含全部圈内威胁、距离、权重、合成方向、原始 / 实际目标、边界和导航修正。敌军清空时避战 NPC 回到 `work` 且不触发计划重评估。若避战中的 NPC 被征召成功但仍没有主武器，继续避战；若随后装备主武器且仍有敌军，切入 `combat`；若无敌军则回到 `work`。T1103D 起，`work -> avoid_combat` 和 `avoid_combat -> work` 的模式切换本身不写事件，避战信息只由 `avoidance_started` / `avoidance_ended` 记录。

避战模式不得被实现为逃离驿站。逃离驿站是独立行为，需要明确的 LLM / 对话 / 调试结果触发，并会让 NPC 前往后门或小门离开地图。

## 逃离驿站行为

T1203/T1204A 已实现逃离闭环。`CombatSystem.start_npc_escape(...)` 是权威入口，战时公开对话 `wartime_reaction == "escape"`、低血量判定 `decision == "escape_station"` 或 GM `escape_npc <npc_id>` 都走同一接口。逃离开始时写入广场公开 `escape_started`，NPC 切到 `behavior_mode == "escaped"` 但 `states.escaped` 仍为 `false`，并以 `escape_intent.status == "escaping"` 前往后门外出口；这段期间普通行动和战斗 AI 不再把该 NPC 当作可用单位。逃离中的 NPC 被点击会打开 NPC 面板；若挽留轮次未用完，NPC 面板【对话】按钮调用 `DialogSystem.start_escape_intervention_dialogue(...)`，该对话强制 `local_public`、最多 5 轮、隐藏应征入口，并通过 `/npc/dialogue` 的 `dialogue_kind == "escape_intervention"` 请求结构化 `escape_intervention_result=stay|leave`。进入挽留时 `CombatSystem.pause_escape_for_dialogue(...)` 暂停移动，关闭、攻击或满 5 轮后由 `resume_escape_after_dialogue(...)` 恢复前往后门。

NPC 抵达后门外出口后，`NPCSystem` 将其标记为 `escaped=true`、`current_action="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件，并从 `CombatSystem.active_escapes` 中移除。若挽留结果为 `stay`，CombatSystem 会停止移动，把 `escape_intent.status` 设为 `stayed`，切回 `work` 并触发计划重评估；若结果为 `leave`，NPC 继续逃离，直至 5 轮上限，随后 NPC 面板【对话】置灰。未满 5 轮时玩家可关闭面板，NPC 立即继续逃离，之后仍可再次打开并再次暂停。逃离中给钱会降低 `escape_intent.speed_multiplier`；逃离挽留中的守备官攻击会提高该倍率、计为 1 轮并立即关闭面板，但不请求 NPC LLM 回复、不写攻击回复对话事件，也不写 `escape_intervention_result`。速度变化写入 `escape_speed_changed`，只有真正的挽留消息回复结果才写入 `escape_intervention_result`。如果逃离中 NPC 昏迷，`escape_intent.status` 暂停为 `paused_unconscious`，复苏后会再次移动到后门外出口。`debug_get_combat_snapshot()` 暴露 `active_escapes`、剩余挽留轮次、速度倍率与 `last_escape_result`。

## 基础攻击与伤害（T1104 / T0107）

T1104 已实现最小自动战斗，T1105 已接入不同兵种的玩家手动策略选择和对应战术移动。`CombatSystem` 在 `TimeSystem.logical_time_tick(game_delta_seconds, numeric_multiplier)` 推进中先处理我方策略与基础攻击，再处理敌方 AI；GM `step_enemies [game_seconds]` 使用同一套逻辑。T0183 后，只要活动敌人在场，`combat_enemy_presence` 慢速请求就把逻辑时间固定为游戏内 `1` 秒 = 现实中 `1` 秒；NPC 移动和 LLM 等待使用相同倍率，不会叠加为更慢速度。CombatSystem 不读取 Godot 全局时间缩放。

T0183 后不再维护独立的“战斗动作秒”换算：战斗攻击冷却、敌人移动、塔防攻击和战场持续效果直接消费 TimeSystem 游戏秒。敌人在场时现实 1 秒只产生 1 游戏秒，因此 `attack_interval = 1.5`、权威攻击 elapsed/cycle 与攻击动画的现实播放时长使用同一秒制；GM `step_enemies 1` 就是推进 1 游戏秒 / 1 战斗秒。经营生产、治疗、建筑倒计时仍按同一个 TimeSystem 游戏秒结算。

我方攻击条件：

- NPC 必须已入伍、有主武器、可行动，并处于 `behavior_mode == "combat"`。
- `behavior_mode == "avoid_combat"` 的 NPC 不攻击敌人，即使已经入伍或持有武器。
- 攻击目标当前选择最近的活动敌人，优先沿用 `states.combat_target_enemy_id`；不同策略会决定是否先接近、后撤、拉开冲击距离或直接站桩攻击。

数值口径：

- NPC 战斗等级由 `1 + floor(total_experience / 10)` 确定，当前上限 10。等级提高攻击、防御、穿透和攻速；力量 5 为攻击基线，每点仍约修正 8% 攻击，并在高于基线时增加防御和穿透。武器熟练度不再提供穿透；只有当前主武器 `required_skill` 对应的熟练度会按最高 `+35%` 的乘区提高该武器攻速，其他武器熟练度不提供通用攻速。
- NPC 原始攻击由主武器 `damage`、人物 `combat_base.attack_power`、装备攻击修正、等级、力量和斗志共同生成。防御与穿透由人物基础、等级 / 力量成长及主武器、四甲、坐骑修正合成。
- 攻击速度是规范真值，攻击间隔统一为 `1 / attack_speed`。NPC 先把武器基础间隔换算为速度，并叠加人物攻速基线、等级、当前武器对应熟练度、疲劳、饱食和装备正负修正；当前最短间隔为 0.25 战斗动作秒。骑术不进入攻速乘区；坐骑定义本身若有固定装备修正，仍按装备规则结算。玩家 `x2` / `x4` 不参与该倍率。
- NPC、敌人与器械使用同一穿透结算：`effective_defense = max(0, defense - penetration)`，`damage_multiplier = 20 / (20 + effective_defense)`，`damage_reduction = effective_defense / (20 + effective_defense)`。最终伤害四舍五入且至少 1 点；当前不设 70% 硬上限，高防御通过曲线自然产生边际收益递减。
- `get_npc_combat_stats(...)` 返回 `base / growth / equipment / condition / final`，GM、NPCPanel 和自动化只读该快照，不重新计算第二份数值。

敌人 HP 清零后从 `_active_enemies` 和 `Station/Enemies` 场景节点中移除；若场上敌人全部消失，沿用 T1103A/T1103B/T1106 的清敌退出规则：`combat` NPC 回到 `work` 并请求计划重评估，`avoid_combat` NPC 回到 `work` 且不因单纯避战结束重评估，未接敌的 `rally` NPC 回到 `work` 且不重评估计划。

我方攻击会写入 `attack_made` 结构化事件，payload 包含攻击者、目标敌人、武器、力量 / 熟练度输入、原始攻击力、防御、实际伤害、敌人 HP 前后值和是否击退敌人。敌人攻击 NPC 时会先计算 NPC 盔甲防御，再调用 `NPCSystem.apply_damage_to_npc(...)`；敌人攻击建筑仍直接以配置 `attack_power` 调用 `BuildingSystem.apply_damage_to_building(...)`，不在 CombatSystem 中自行改写建筑 HP。

## 战斗开始 / 结束流程（T1106）

T1106 已实现战斗开始和结束的最小闭环。`spawn_wave(...)` 成功生成敌人后会创建当前战斗运行态，并在广场写入 `combat_started` 公开事件；payload 包含波次、敌军数量、敌军 roster、我方已入伍且持主武器 NPC 的姓名 / 兵种，以及非战斗人员数量。该事件只描述程序已知的敌我态势，不触发额外数值结算。

战斗运行态记录本场受伤 NPC、昏迷 NPC、每名 NPC 击退敌人的数量和击退敌人列表。敌人被我方攻击清零时会计入对应 NPC；敌人攻击 NPC 造成 HP 下降时会计入受伤；NPC 昏迷会计入昏迷统计。敌军全灭或 GM 清敌后，`CombatSystem` 写入广场 `combat_ended` 公开事件，summary 会说明敌人被清空、本场受伤 / 昏迷人员和击退统计。

战斗结束回收仍由行为模式系统执行：`combat` NPC 回到 `work` 并请求计划重评估；`avoid_combat` NPC 回到 `work`，只记录避战结束事实，不强制计划重评估；未接敌的 `rally` NPC 在清敌或等待超时后回到 `work`，也不重评估计划。`debug_get_combat_snapshot()` 暴露 `active_battle`、`last_battle_start_result` 和 `last_battle_end_result`，GM 面板“敌人快照”可直接观察当前战斗与最近结算。

## 工程器械防御（T1508 / T0107）

工程器械的库存、槽位、部署运行态、HP、防御、穿透、攻速和触发冷却由 `DefenseDeviceSystem` 权威维护；CombatSystem 不保存第二份部署数据。部署由玩家直接操作，不选择 NPC。两者只通过攻击 / 受击窄接口协作：

T0036 已把部署成本迁移为具体物品：弩床只扣除 `item_wall_ballista`，箭塔只扣除 `item_wall_arrow_tower`。部署后的攻击、冷却和伤害接口未因库存迁移而改变；旧 `defense_devices` 仅作兼容保留，不参与正式部署结算。

- 弩床与箭塔同为 1 级工械坊可制造 / 部署的同级器械。弩床为高伤害、高穿透、远射程、慢攻速、低 HP；箭塔为较低伤害 / 穿透、稍近射程、高攻速、高 HP / 防御。
- 围墙与主厅都使用通用槽并提高到 6 级，每次升级最多解锁 1 个。围墙 1–6 级容量为 `1 / 2 / 2 / 3 / 3 / 4`，主厅为 `1 / 1 / 2 / 2 / 3 / 4`。围墙 Lv.3 / Lv.5 虽不扩槽，但各从建筑逐级配置累计 `+5%` 器械射程；最终倍率依次为 `1.0 / 1.0 / 1.05 / 1.05 / 1.10 / 1.10`。主厅固定 `range_multiplier=1.0`，不使用围墙加固收益。DefenseDeviceSystem 每次生成槽位、部署与选敌快照时按宿主当前等级解析倍率，因此升级前已部署的围墙器械也会立即获得收益。
- 器械按统一游戏秒推进冷却，在有效射程和前向射界内选择最近敌人，再调用 `CombatSystem.apply_defense_device_attack(...)`。该接口复用敌人有效防御、HP 扣除、清零移除、击退归属和最终波次结算。
- 敌人可把附近有效器械作为战斗目标，通过 `DefenseDeviceSystem.apply_damage_to_device(...)` 扣除器械 HP；HP 清零会释放槽位并移除部署。宿主建筑 HP 为 0 或处于不可用状态时，器械不攻击也不暴露为活动目标。
- T0274 后玩家可通过塔防属性面板请求 `DefenseDeviceSystem.undeploy_device(...)`。`hp == max_hp` 时删除部署、释放槽位并按器械定义的具体 `inventory_cost` 原样返库；`hp < max_hp` 时必须由调用者显式确认，确认后删除部署且不返库，未确认不产生变化。手动卸下不会创建战损废墟，槽位可立即重新部署；UI 不直接改库存、HP 或槽位占用。

既有部署与实际触发仍沿用 `defense_device_deployed` / `defense_device_triggered`；T0107 没有为器械受击、摧毁、穿透或僵直新增信息事件。当前数值仍是可迭代占位，后续平衡只调整数据定义。动画、炮臂转向、命中特效和正式模型通过表现层消费同一运行态，不参与伤害结算。

## 敌人 AI

Demo 阶段敌人使用规则 AI，不调用 LLM。

T1101 已完成敌人波次配置与调试生成；T0121 将 5 波调整为 `8 / 16 / 24 / 36 / 48` 人，单个敌人的 HP、攻击、防御和穿透整体低于我方平均武装单位，以逐波人数增长制造杀敌反馈和数量压力。每个敌人组记录 HP、武器类型、单位类型、攻击、防御、穿透、攻击速度 / 间隔、攻击抬手、移动速度、攻击范围和目标偏好。`CombatSystem` 会读取该配置，并可通过 `spawn_wave(...)` / `debug_spawn_wave(...)` 在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人实体。

T0140 为快速战斗测试增加了只由 GM 显式启用的正门方向出生选项；T0160 已将其从贴门的 `front_gate` 路线点迁移为独立 `gm_front_gate_enemy_spawn_zone`。正式动态波次生成可接收 `spawn_stage_id`，默认保持 `spawn`；GM 的直接生成、下一波和动态群战从 `station_layout.json` 的专用区域按现有碰撞体半径生成编队，结果记录 `spawn_stage_id / spawn_near_front_gate / spawn_in_gm_staging_zone / spawn_zone`。这只缩短 GM 测试前的行军距离，不改变敌军模板、NavigationMap、目标序列、攻击、HP、建筑伤害或胜负结算；日程自动波次仍从地图边缘林下生成。

T1301 已完成波次倒计时与自动来袭：每个波次配置可包含 `trigger_day`、`trigger_hour`、`trigger_minute` 和 `trigger_second`，当前 5 波默认分别在第 3-7 天 18:00 触发。`CombatSystem` 在 TimeSystem 的 `logical_time_tick` 中按逻辑时间比较配置触发点，只触发下一未触发波次，并记录 `triggered_wave_numbers`，避免同一波重复自动生成。`get_wave_schedule_snapshot()` 暴露下一波、已触发波次、待触发波次、活动敌人数量、最近自动触发结果和最近手动跳波结果；HUD 使用该快照显示下一波倒计时，GM “跳到下一波”按钮和 `next_wave` / `jump_wave` 命令调用 `debug_trigger_next_wave()` 触发下一未触发波次。T1304 后，包含最终配置波次（当前第 5 波）的战斗在敌人清空后触发 `victory/five_waves_survived`；`GameState.set_game_over(...)` 保存通用结算原因和 `settlement_snapshot`，快照记录剩余资源、建筑 HP / 损毁 / 摧毁、驿站是否仍可运转，以及 NPC 可行动 / 昏迷 / 逃离状态。胜利后 TimeSystem 停止推进，HUD 显示胜利占位界面，`spawn_wave(...)` 会因游戏已结算而拒绝继续生成敌人。

T1303 曾实现无可战斗人员失败条件；T0121 已删除其常量、检查入口、结算函数和 HUD 原因映射。战斗快照不再需要 `combatant_availability` 来决定失败；旧名脚本 `verify_no_available_combatants_failure.gd` 现反向验证“零可战人员时不失败、敌军继续推进、HUD 不出现结算”。

T1102 已完成敌人目标优先级、移动和敌方攻击，T1104 已把该推进扩展为双方基础攻击：`CombatSystem` 监听 `TimeSystem.logical_time_tick` 推进战斗 AI；敌人若在侦测范围内发现可行动 NPC，会优先攻击该 NPC，否则按城门、仓库、主厅顺序推进。T1104C 起围墙不再是攻击目标。T0183 起，敌人移动直接使用 `move_speed * game_delta_seconds`，进入射程后也直接按游戏秒中的 `attack_interval` 和 `attack_power` 推进；敌人在场的 `1/60` 慢速保证现实 1 秒只产生 1 游戏秒，玩家 `x2` / `x4` 不额外加快战斗。

攻击 NPC 时先按盔甲防御结算，再调用 `NPCSystem.apply_damage_to_npc(...)`；攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)` 并写入 `building_damaged`。主厅 HP 清零触发唯一失败条件，第 5 波清敌触发胜利。`debug_get_combat_snapshot()` 包含 TimeSystem 快照、`game_seconds`、数值相同的 `combat_seconds`、策略、逃离和胜负状态；GM 可观察 `combat_enemy_presence` 慢速请求，并用 `step_enemies 1` 推进 1 游戏秒 / 1 战斗秒。

T0107 后敌人攻击变为“冷却 -> 抬手 -> 命中”两阶段。`attack_windup` 大于 0 时，目标在抬手结束前不会受伤；`apply_enemy_stagger(...)` 会清空当前抬手并暂停行动。近战骑兵冲撞使用该接口打断敌人，随后再结算增伤武器攻击。T0110 后骑术只进入 `charge_damage + riding_skill × charge_damage_riding_scale` 的马匹冲撞伤害，不提高骑乘攻击速度。敌人还会把附近有效器械列为候选目标；对 NPC、敌人和器械的伤害均使用同一有效防御 / 穿透递减曲线。`debug_get_combat_snapshot()` 额外暴露 `friendly_combat_stats`、`defense_devices`、敌人抬手 / 僵直与骑兵冲锋阶段。

目标优先级：

1. 如果一定范围内有我方单位，优先攻击我方单位
2. 攻击城门
3. 城门被攻破后攻击仓库
4. 仓库被摧毁后攻击主厅

当前规则敌人不攻击围墙。T0129C-A1 已在远端 staging 建立围墙 / 城门静态碰撞，但正式敌人尚未接入；“敌人必须从城门进入、NPC / 敌人不能穿墙”要到 A4 + C3 将活动敌人迁为 CharacterBody3D / NavigationAgent3D 并启用正式根后才成立。

## 战场公开信息

战斗中关键事件必须先作为结构化事件写入 `MemorySystem`。每个事件关联 `subject_npc_id` 和 `location_id`；事件写入 NPC 自身事件库后，再按 `visibility` 发送到所在建筑的信息节点，由节点即时广播给当前在场 NPC；节点不保存事件历史。

通过信息节点公开广播的战斗事件包括：

- 敌袭开始、波次、敌军构成和我方已入伍持武器战斗人员
- 某 NPC HP 低于 30%
- 某非战斗人员开始 / 结束避战
- 某 NPC 击倒或击退敌人
- 某 NPC 昏迷
- 某 NPC 被治疗
- 某 NPC 复苏
- 某 NPC 逃离
- 建筑受损

若战斗发生在可进入建筑内部，事件可以同时广播到该建筑信息节点；室外战斗、城门/仓库/主厅受损、敌袭开始和战斗结束归入广场公开广播。

T1205/T0299 的战场公开信息验收覆盖敌我人数、集结、避战开始 / 结束、低血量、战时心理结果、击退敌人、昏迷、治疗、复苏、逃离、建筑受损和战斗结束；所有模式互转都只留在运行态，不通过 `npc_mode_changed` 广播。

战斗结束后，NPC 回到工作状态，并根据自身经历重新评估计划。
## T0132-P3 正门动态门扇与敌军边界

- 正门现在有两扇 world-static 层 `AnimatableBody3D` 实体门叶。我方 NPC 在和平或战斗中接近都可开门；敌军自身永远不能触发传感器。
- 敌军仍必须物理抵达正式 `front_gate` 攻击位并由模型接触固定门板战斗面后才能伤害正门。门扇开合不发布“抵达 / 突破”事实、不改目标选择；只有 BuildingSystem 判定正门 HP 为 0，表现层才解除门叶碰撞，既有门洞链接和仓库攻击阶段继续生效。
- 围墙平台仍只承载 DefenseDeviceSystem 的可见部署；平台、美术测距杆和城垛不参与伤害、射程、命中或目标选择计算。
- P3R2 只把四个平台和器械攻击原点移到正门左右墙段；敌军建筑目标序列仍为 `front_gate → warehouse → main_hall`，不会因为平台远离门楼而改为攻击 `wall`。
- P3R4 将右墙器械 facing 从城门统一轴改为 `north_east` 墙外法线，左墙使用 `north_west_a` 外法线；射程、扇区和目标选择公式未改，部署 / 攻击专项通过。
