# COMBAT_SYSTEM.md

## T0200 敌我统一战斗寻路

- CombatSystem 继续先按 T0196 / T0198 锁定“打谁”，再按单位当前武器解析距离、近战接触或远程弹道条件。未满足攻击条件时，只向该目标周围距离自身最近且可达的合法接敌点移动；路径长短、道路、门和暂时拥堵不得反写目标优先级。
- 敌我战斗请求统一携带 `shared_combat_navigation_v1`：无遮挡时 NavigationMap 给出近似直线最短路，静态建筑 / 围墙 / 家具 / 自然阻挡由 collider-baked NavMesh 绕行，活动实体先由 NavigationAgent3D RVO 局部避让。目标显著移动时更新同一个 request 的终点；路径失效或持续无进展时按既有限频率重规划，直到进入攻击条件或目标失效。
- 普通生活 / 工作移动仍保留最大重规划次数与卡死超时；战斗追击不会因为达到该普通上限而永久停住。进入武器有效条件后先释放移动权威，再进入既有起手锁与模型接触 / 弹体时间线，不允许边移动边攻击。
- 城外生产 NavMesh 现覆盖正式敌军生成区到驿站外墙，旧 `EnemyApproachNavigation` 狭长廊道不再创建。敌军路线数据只用于生成 / 阶段表现，道路只用于美术；墙体、密林和其他正式静态碰撞仍是实际阻挡。
- 正门七个独占攻击位按 collider-baked NavMesh 的真实门柱净空布置；首波 7 人均须到位并通过模型接触造成伤害，第 8 人继续遵守完整城门 waiter 规则。敌我每个角色使用稳定身份哈希产生的微小 RVO 优先级差以打破对称礼让，它不改变目标、路径或攻击位。同阵营活动角色交由 RVO / 接敌移动处理，不作为近战武器扫掠的世界阻挡；静态场景与敌对实体仍按首个真实接触裁决。

## T0198 友方分域在场锁与异源受击重扫

- 全部持武器友方 NPC 只使用 `friendly_enemy_presence_lock_v1`。NPC 位于驿站外时，候选是水平直线距离不超过精确 `37.2 m` 的活动敌人；NPC 位于驿站内时，候选扩展为 `interior_polygon` 内的全部活动敌人，站外敌人不进入整站候选。
- T0188 的“驿站破防时全部武装应征者立即切入 combat”继续有效；若响应者当时位于站外且圈内无敌人，只切换行为模式并保持空目标，不把远处站内敌人越域写入锁。
- 没有有效锁时按水平距离选择最近敌人；当前敌人仍有效且仍在当前分域时持续保持，不因另一敌人后来出现或变近而跳锁。`combat_target_enemy_id` 同时约束策略移动、武器射程复核、windup / impact 和状态显示，不能在移动层与攻击层各选一个目标。
- 当前锁定期间，另一个敌人经 `_apply_enemy_attack_to_npc(...)` 正式链实际扣除 NPC HP 后，记录一次 `friendly_enemy_damage_reacquire_request_v1`。下一次选择只绕过在场锁一次：站外重扫 `37.2 m` 圈，站内重扫整座驿站，并按当前距离取最近者；不强制精确反击伤害来源，圈 / 站外来源可触发重扫但不能越过分域成为目标。
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
- 近战仍须在 authored impact 窗由真实模型接触提交伤害；弓 / 弩仍只在 impact 释放带 attack id / sequence 的正式弹体。时间锁不会补伤、延长射程或改变播放倍率。
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
- T0198 起，站内武装 NPC 的新目标、首选目标与追击目标统一限定为整座驿站内的敌人，不能被更近的站外敌人截走；站外武装 NPC 则按统一 `37.2 m` 圈接敌。旧 `normal_contact_range=5 m` 不再决定武装 NPC 索敌，只保留为非战斗接触 / 避战兼容下限。
- 分配坐骑不会绕过取马流程：进入战斗只设置 `going_to_stable_horse`，HorseSystem 完成指定马匹会合前友军 AI 跳过攻击；上马回调把状态改为 `mounted / combat_ready` 后再执行策略。
- 非战斗避战的触发半径为 `max(8 m, 当前活动敌军最大远程攻击距离 + 2 m)`，持续安全距离为 `max(8.5 m, 最大远程攻击距离 + 2.5 m)`。短步目标、导航和清敌返回工作合同不变；`avoid_combat` 的实际位移档位由 T0155 固定为 run。

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
- ChibiCharacterPilot 的四武器步战 / 骑战攻击、受击、昏迷、起身和坠马，旧 NPCArtView 的战斗状态、友敌坐骑 / 逃马及相关粒子共同消费该合同。逻辑 attack elapsed、真实武器扫掠和伤害提交边界没有迁入表现层。
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
- 落地后的 4.2 米陨石带 world_static `StaticBody3D`，在本场战斗内形成真实碰撞；CombatSystem 写出既有 `combat_ended` 事件后，PietySystem 移除所有落地陨石实体。弹坑与灰烬没有 HP、伤害或占位权威，不随清敌消失。

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
- 正式第五波 48 敌压力通过，CPU p95 `7.436 ms`、导航 p95 `0.333 ms`、零 orphan；五波胜利、主厅失败、无可用战斗员失败、暂停 / 存档、骑乘坠落 / 逃马和战后清理均通过。

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
- 主厅槽按位置映射到 `back_wall / front_left / front_right`，并同时接受对应唯一 `main_hall_slot_*_platform` fixture。地面近战可以攻击支撑墙，远程弹体也可实际碰中支撑墙或平台，二者都解析为锁定器械。
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

## T0144 近战模型接触权威

- 剑盾 / 长杆攻击起手只建立 CombatSystem swing；正式包装逐帧提供当前可见刃段 / 杆头端点。CombatSystem 按武器配置的样本数优先查询当前武器胶囊，未命中时再扫相邻样本的刀尖 / 中段运动轨迹；首个终止碰撞决定 `hit / blocked`，没有碰撞为 `miss`。
- 锁定目标只负责朝向与起手，不是命中承诺。友军只可命中活动敌军，敌军只可命中实际 NPC 或锁定器械 / 建筑宿主；实际先碰到另一合法敌对单位时，既有伤害链作用于实际 collider 身份。
- 步战 / 骑战按各自动画量测接触点和范围：剑盾 `1.45 / 0.96 m`、长杆 `2.98 / 2.66 m`。距离表示面朝目标时目标碰撞体中心可被当前模型触及的前向范围，不使用横挥侧向半径冒充射程。
- 伤害仍只由 CombatSystem 提交。表现帧只登记首个接触，紧接的物理帧消费唯一 damage commit；若权威攻击边界先到，则读取同一 swing 的接触结果，不能重复结算。模型包装、BoneAttachment、武器 Mesh 与 AnimationPlayer 都不拥有 HP；攻击中断、模式退出或清敌会清理未结算 swing 与待提交队列。

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
- ActorMotionBody、碰撞、NavigationAgent、HP、受击、击退统计、坠亡逃马和胜负流程全部保留；旧 ActorMesh 仅在正式包装存在时隐藏。
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
- 集结到达判定使用 `0.3 m`，覆盖 ActorMotionBody / NavigationAgent 的停止容差；人物停止时必能被提交为 `rallied`。本修正不改变接敌距离、骑兵伤害、马匹分伤、昏迷或逃马权威。

## T0139 友方骑手坠马与敌方骑兵逃马表现边界

- 骑乘 NPC 的 HP 归零、昏迷事实、双方马匹分配清理和存活马返厩仍由 CombatSystem / NPCSystem / HorseSystem 在同一受击结算中立即完成。
- 角色表现仅从 `combat_mounted=true` 到 `unconscious=true` 的边沿触发一次坠马：约 `0.92 s` 侧向翻落并播放 `Death_A`，落地后停留；它不提交伤害、不延迟解绑、不控制马匹返厩。
- 复苏继续遵守 30% HP 权威门槛并播放 `Lie_StandUp`；无马昏迷保持原表现。
- 敌方骑兵 / 骑射兵的马匹是纯表现节点，没有独立 HP、分伤、HorseSystem 记录或装备所有权；我方伤害完整进入敌军单位 HP，避免额外血池改变波次数值。
- 敌军 HP 清零时权威敌军立即移除并照常推进击退统计、清敌与胜负判断。随后保留的表现包装只负责骑手 `Death_A` 坠亡和马匹以 `18 m/s` 逃向前门外地图边界，离场后释放；动画不会延迟、撤销或重复任何结算。
- `NPCDevLab` 的敌方骑兵验收也直接调用 `EnemyMountedArtView.apply_profile / set_movement_active / begin_mounted_defeat_escape`，仅改变独立开发场景表现，不向 CombatSystem 提交模拟伤害。
- T0139-D2 的我方 DevLab 入口以两次本地 `apply_profile` 复制正式骑乘到昏迷边沿，不扣 HP、不解除马匹分配、不发送事件；马匹 `Gallop` 仅是检视台上的返厩语义参照。

## T0132-P5 道路表现与战斗寻路边界

- 正式 42 段泥路只由 `FormalRoadNetworkArtView` 显示，显式保持 `roads_affect_navigation=false`，且没有 CollisionObject 或 NavigationRegion。车辙、泥肩、碎石和交汇补片不能改变敌我单位的路径成本、目标选择、挤压、攻击距离或到达判定。
- 当前正式波次继续按 NavigationMesh、CharacterBody 实体碰撞和 avoidance 寻找目标的最短可行路线；道路不是必须途经点。P5 后第一波动态直攻回归通过。

## T0132-P4b 箭塔攻击表现与结算边界

- DefenseDeviceSystem 继续按 `attack_interval=1.39 s`、伤害 16、穿透 4、基础射程 28 和宿主槽倍率即时选敌 / 结算；正式箭塔只消费既有 `origin_position / target_position / attack_interval` 表现快照。
- 每次已结算攻击驱动一次转台瞄准、弓弦释放、已装填箭隐藏、可见飞行箭和约 `58%` 间隔的机械回位；飞行体与动作都不提交命中、伤害、穿透或击败。目标在箭飞行期间移动或失效，不改写已发生的结算。
- 主厅木制平台替换只影响 Mesh / 材质。四槽坐标、`1/3/5/6` 解锁、`3.93 m` 锚点、碰撞、主厅 `2.0x` 射程和围墙槽加成都未改变。

## T0132-P4a 弩床攻击表现与结算边界

- DefenseDeviceSystem 仍按 `attack_interval=4.25 s`、伤害 44、穿透 8、基础射程 34 和宿主槽倍率即时选择目标并调用 CombatSystem 结算；动画完成、弩箭飞行时间和任何视觉碰撞都不提交伤害。
- 单次 `defense_device_action_resolved` 追加 `origin_position / target_position / attack_interval`，三者是本次权威射击发生时的只读快照。目标之后移动、昏迷或被移除不会改写已经结算的事实；飞行弩箭只追到快照坐标并自动清理。
- `DefenseDeviceView` 把同一事件交给正式弩床，按事件频率播放转台瞄准、弓弦释放、后坐、弹体飞行和重装；待机箭只在重装完成后出现。主厅 `2.0x` 射程与围墙 Lv.3 / 5 射程加成不改变攻速或表现层职责。

## T0132-P2 仓库受击表现边界

- 仓库实体美术没有修改敌人 `front_gate→warehouse→main_hall` 目标序列、正式攻击点或动态接触逻辑；正门到仓库的导航回归仍为17点，第一次有效攻击继续由 CombatSystem 扣减 BuildingSystem 仓库 HP。
- 裂纹、松脱门板、碎石和烟尘只读 `hp/max_hp` 分级显示，修复后随权威 HP 清除。分类货物、侧仓与挑高安全仓不拥有库存损失、被掠夺比例、伤害或攻击完成权威；尚未实现的仓库受击资源流失规则仍不得由表现层推导为生效。

## T0132-P1 主厅城防与损伤表现边界

- 主厅器械槽位仍由 DefenseDeviceSystem 权威解锁，Lv.1–6 容量保持 `1/1/2/2/3/4`，平台对应解锁等级为 `1/3/5/6`；表现层不拥有部署、射程、器械 HP、攻击或命中。
- P1R3 修复旧空间坐标分裂：主厅四槽的运行态攻击原点、世界部署模型和 UI 标记现在统一绑定正式平台世界锚点；围墙四槽也统一绑定正式正门墙段。主厅平台局部中心保持 `(-7,-5)/(7,-5)/(-7,5)/(7,5)`，安装高度为 `3.93 m`，不改变 `2.0x` 射程、伤害、攻速、穿透或目标选择公式。显式 GM legacy compatibility 才恢复配置中的旧地图位置。
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

- 昏迷 NPC 继续是不可行动但可碰撞 / 可交互的 CharacterBody；`assist_heal` 治疗者必须通过生产导航抵达其周围合法距离，不能用后台 `current_location` 代替接近。
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
- 避战候选仍按敌方方位生成短步长散射目标；A5-P1 对正式 NPC 把目标投影到生产 NavMesh，NPCSystem 再通过 ActorMotionBody 请求真实运动。道路没有权重，静态碰撞、实体碰撞和 avoidance 决定路线；不以字典位置或后台地点代替到达。
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

T0129C-A3 已在远端正式布局建立 234 个静态碰撞源：结构 78、地面 1、家具 131、自然边界 24，并生成独立 `0.25 m / 806 vertex / 772 polygon` 生产 NavigationMap；主厅四器械平台与 `main_hall_slot_01–04` 的 `1 / 3 / 5 / 6` 解锁一致，仓库外沿攻击路线保持可达。当前活动敌人仍由 CombatSystem 创建 `Area3D` 并直接回写位置，A4 才会把实际路径 / 速度 / 避让交给 `enemy_foot / enemy_mounted` profile；伤害、攻击距离、目标优先级和胜负继续由 CombatSystem 权威结算。

## T0129 单敌战斗表现样片

- 格伦每次权威 HP 下降都会触发一次 GPU 血粒子和 CharacterPivot 短促位移回弹；表现计数和粒子状态只用于调试，不反写 HP、伤害或命中。
- HP 清零仍由 NPCSystem 提交 `unconscious=true`；表现层播放 `LayToIdle` 受控倒地，并叠加衰减的水平 / 垂直冲量和落地回稳。复苏沿原 30% 权威阈值播放起身。本轮没有创建逐骨骼 physical bones，因此应称“带物理反馈的受控倒地”，完整布娃娃仍在 T0133。
- CombatSystem 每次波次只把第一名敌人替换为红褐色 Quaternius 人形并在手部挂载青铜剑 / 木盾，其余敌人保留原轻量胶囊；正式样片仍由原敌人状态驱动移动、攻击、受击和移除。敌人败退后仅分离 2.4 秒表现尸体，权威敌人会立即从活动集合移除。

## T0128 格伦战斗状态表现接线

格伦的统一状态机已经接收 `attack / hit_react / unconscious / get_up` 四类表现：攻击由既有 `attacking_* / winding_up_*` 行动选择，受击只在权威 HP 下降后触发，昏迷只在 NPCSystem 已提交 `unconscious=true` 后播放，复苏只在权威状态从昏迷切回清醒后播放。动画不拥有命中帧、伤害、HP 或复苏阈值。

T0128 使用 UAL2 骨骼动画完成受控倒地 / 起身，并在骨架下建立禁用 `PhysicalBoneSimulator3D` 接口占位；T0129 已增加血粒子、位移冲击与落地回稳，但尚未创建 physical bones、碰撞关节、贴花或布娃娃姿态回收。上述完整内容仍由 T0133 批量实施，不能把当前受控倒地计为逐骨骼布娃娃完成。

## T0123–T0133 战斗美术表现边界

后续战斗美术将补齐近战、长杆、弓、弩、骑兵、敌人和工程器械的攻击 / 命中 / 格挡 / 击退动作，以及命中闪光、火星、血液粒子 / 贴花、脚步尘、建筑碎屑和受损反馈。NPC HP 清零后可进入布娃娃或受控倒地表现，但权威结果始终是“昏迷”；恢复到 30% 后停止物理模拟、对齐角色并播放复苏起身，不出现死亡或永久尸体。

物理骨骼、碰撞、动画、粒子和贴花只消费 CombatSystem / NPCSystem / BuildingSystem 已确认结果，不反向计算伤害、HP、命中或建筑摧毁。48 敌第五波是表现压力基准，必须限制同时活跃的布娃娃、贴花、动态灯和粒子，并提供关闭血液的选项。T0133 前只有格伦与每波第一名敌人是正式样片，其余战斗仍以基础自动攻击和占位表现为运行时事实。

## T0121 全局数值合同与唯一失败条件

五波现固定在第 3–7 日每天 18:00 到达，敌军总量为 `8 / 16 / 24 / 36 / 48`，对应基准入伍 `2 / 3 / 5 / 6 / 7` 与器械 `1 / 1 / 2 / 3 / 4`。第五波工作流以 7 武器、8 防具、2 马、1 弩床 + 3 箭塔对 48 敌；弩床为 44 伤害、4.25 秒间隔。具体兵种、装备、人时与恢复账见 `docs/GAME_BALANCE.md`。

T1303 的 `no_available_combatants` 失败链已经删除。当前 Demo 唯一失败条件是主厅 HP 清零；全部 NPC 昏迷、逃离或无武器时不会立即结算，敌军与幸存器械继续推进。`tools/verify_t0121_fifth_wave_build.gd` 已验证 7 名 NPC 全部昏迷后器械完成 48 敌清理并进入最终胜利。

T0122 连续回放进一步覆盖跨波战损：自然路线第四波清敌后 6 人全部昏迷、主厅剩 `112 / 220`，该波仍正确判过，随后第五波因累积损失摧毁主厅；精细路线两次以确认的 7 武器、8 防具、2 马、4 器械满员进入第五波，均清空 48 敌并保住 `236–250 / 250` 主厅。胜利时 7 人可全部昏迷且器械有损失，仍不产生第二失败条件。当前连续证据不要求调整敌军配置。

陨石冲击按水平距离与敌人 ID 稳定排序，最多命中 12 个目标；燃烧仍可影响范围内其他敌人。战斗等级只读取最高单项武器 / 骑术训练经验，不读取职业总经验。

## T0118 斗志激昂对话内反馈

`wartime_reaction=morale_boost` 的战时 NPC 回复会把 `wartime_reaction` 标记绑定到本轮 NPC history turn，DialogPanel 在该台词下显示绿色“↑ {NPC名}受到了激励，进入斗志激昂状态”。该反馈不改变 T1201 的权威边界：模型仍只表达意向，玩家完成对话后才由 `CombatSystem.apply_wartime_dialogue_reaction(...)` 应用 2 游戏小时 buff 并写入 `battle_psychology_result / morale_boost_started`；取消会话仍不应用被暂存的战时效果。

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
| 集结模式 | 已入伍、有主武器、当前可行动 NPC | 前往城门外防线并等待接敌 | 守备官摇响警铃 | 集结途中或集合点敌人进入一定范围后进入战斗模式；到达集合点等待 1 游戏小时仍未接敌，返回工作模式且不重评估计划 |
| 战斗模式 | 已入伍且有主武器的可战斗 NPC | 按兵种和战斗策略自动战斗 | 从集结模式接敌；或工作模式中敌人进入一定范围；正在睡觉的持武器入伍 NPC 只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式并重评估计划；HP 清零进入昏迷 |
| 避战模式 | 非战斗人员：未入伍 NPC，或已入伍但无主武器 NPC | 按敌人接近方位逐步远离，尝试离开接敌范围，不攻击敌人 | 非战斗人员附近出现敌人；正在睡觉的非战斗人员只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式；避战中应征但仍无主武器时继续避战，装备主武器且仍有敌人时进入战斗模式 |
| 逃离驿站 | 逃离意向已被程序应用、尚未离图的 NPC | 朝后门外出口移动；可被玩家进行最多 5 轮挽留 | 战时对话、低血量判定、逃离挽留失败或 GM 调试触发 | 到达出口后标记 `escaped=true`；挽留结果为留下时返回工作模式并重评估计划；昏迷后暂停，复苏继续逃离 |

避战模式是非战斗人员的同级行为模式，不等于已入伍且有主武器 NPC 在战斗模式中可选的“避战策略”。后者仍属于战斗模式。

任一高优先级模式触发时，如果该 NPC 正在与守备官对话，系统必须强制完成当前已有会话、关闭对话框并取消可取消 LLM 请求；未完成的 NPC 回复不伪造，但已经说出口的守备官消息和攻击事实随会话入库并进入判别。如果 NPC 正在做普通计划行动、移动、工作、吃饭、训练、治疗或计划 LLM 活动，系统应中断并进入新模式。睡觉 NPC 通常不因附近敌人直接切换模式，只有被敌人攻击时才按入伍状态和主武器进入战斗或避战。

T1103A 已实现模式切换的权威边界：进入集结 / 战斗 / 避战时会中断普通行动、移动、可取消 LLM 与当前对话；需要留痕的模式变化会写入 `npc_mode_changed`。T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 的互转不再写入 `npc_mode_changed`，也不通过该事件广播；避战开始 / 结束、攻击、受伤、警铃、集结、昏迷和复苏仍由具体事件记录。昏迷 NPC 复苏后按场上敌军、入伍状态和主武器分流：仍有敌军时，已入伍且有主武器者进入战斗模式，未入伍或无主武器者进入避战模式；没有敌军时返回工作模式并重新评估计划。T1103B/T1103C 已实现非战斗人员的避战移动、清敌退出、避战中应征 / 装备分流，以及 `avoidance_started` / `avoidance_ended` 事件。

## 战斗触发

触发入口：

1. 守备官手动摇响警铃，符合条件的已入伍持武器 NPC 进入集结模式。
2. 已入伍且有主武器 NPC 在工作模式或集结模式中接敌，进入战斗模式。
3. 未入伍 NPC、已入伍但无主武器 NPC 在工作模式中遇敌，进入避战模式。
4. 睡觉中的 NPC 只有被敌人攻击时才从睡觉进入战斗 / 避战。

T1103/T1103A/T1103B/T1103C 已完成玩家手动摇响警铃后的集结、模式切换和非战斗人员避战闭环：HUD `AlarmButton` 和 GM `alarm` / `rally` 都调用 `CombatSystem.trigger_combat_alarm(...)`。警铃会给所有 NPC 写入 `combat_alarm_rang` 结构化事件；随后只有已入伍、已装备主武器、当前可行动且非睡觉的 NPC 响应集结并进入 `behavior_mode == "rally"`。响应者的普通日常行动会通过 `NPCSystem.set_npc_behavior_mode(...)` 的中断边界打断并释放工位，再移动到城门外防线。T0160 后阵型按步行近战居中前排、步行弓弩居中后排、所有骑乘单位分列左右翼，方向标记面向正门外敌人来袭方向。T0138-R1 后，已分配成年马在警铃 / 接敌时仍留在马厩，响应 NPC 先导航到马旁，实际抵达并标记 `ridden` 后 CombatSystem 才显示坐骑并继续集结 / 参战；日常工作模式下同样不显示骑乘。若集结途中或集合点附近遭遇敌人，只有已入伍且有主武器 NPC 会停止集结并进入 `behavior_mode == "combat"` 与 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy` 和必要的 `npc_mode_changed`。未入伍或已入伍但无主武器 NPC 在工作模式中接敌会进入 `behavior_mode == "avoid_combat"`，按最近敌人方位生成短距离散射移动目标，不设置战斗 `combat_mode`，也不攻击敌人；睡觉中的非战斗人员只有被敌人攻击才进入避战。集结到点后等待 1 游戏小时仍未接敌会返回 `work` 且不触发计划重评估；场上敌人清空时，`combat` NPC 返回 `work` 并触发计划重评估，`avoid_combat` NPC 返回 `work` 且不触发计划重评估。T1103D 起，工作 / 战斗和工作 / 避战互转不再写 `npc_mode_changed`，具体战斗和避战事实由 `attack_made`、`damage_taken`、`avoidance_started`、`avoidance_ended` 等事件表达。T1104 后，`combat` 模式中的入伍持主武器 NPC 已能执行基础自动攻击、扣除敌人 HP 并在敌人 HP 清零后移除敌人。T1105 后，战斗模式会按 NPC 当前手动选择的兵种策略决定基础攻击前的战术移动与攻击节奏。T1106 后，波次生成和敌军清空会分别写入广场 `combat_started` / `combat_ended`，并维护本场受伤、昏迷和击退统计；T1201 后，战时公开对话可应用斗志 buff 或触发逃离；T1202 后，战时低血量自身心理判定已接入；T1203 后，逃离会移动到后门外出口并在离图后标记 `escaped`；T1204A 后，逃离过程中可通过 NPC 面板进行最多 5 轮挽留，打开对话暂停逃离移动，未满 5 轮关闭恢复，给钱减速，逃离攻击加速且不请求 NPC 回复，并在昏迷复苏后继续逃离；T1302 后，主厅被摧毁会进入失败占位结算并停止正常推进；T1303 后，活动敌人在场且所有已入伍持主武器战斗人员均昏迷、已逃离或正在逃离时，会进入无可战斗人员失败；T1304 后，包含第 5 波的战斗清敌会进入 Demo 胜利占位结算并停止继续刷波。NPC 结局总结和命中 / 格挡仍留给后续任务。

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

T0804-T0806 曾使用 `weapons` / `armor` / `defense_devices` / `horse_readiness` 聚合库存作为最小占位；T0035-T0038 已完成正式迁移，这四个 id 只保留兼容且不得正式消耗。铁匠铺 / 工械坊现在按分阶段配方产出剑盾、长杆、弓、弩、四个盔甲部位、箭束、弩床和箭塔各自的 `item_*` 库存，EquipmentSystem 逐件消耗 / 返还武器与盔甲的具体来源。坐骑由 HorseSystem 中的真实成年马分配，`equipment.mount` 只是带 `horse_id` 的兼容投影。T0031 后，艾达在新游戏初始化时从正式武器定义直接装载剑盾，开局兵种为近战步兵；这份故事装备不扣库存、不记录守备官赠送事件。T0902 后，兵种判定通过 `get_unit_type_snapshot(...)` 供 GM 与 CombatSystem 读取。T0107 后 CombatSystem 以 NPC 配置 `combat_base` 为人物差异起点，读取主武器伤害 / 射程 / 间隔、武器与盔甲的攻击 / 防御 / 穿透 / 攻速修正，以及坐骑战斗参数，统一生成基础、成长、装备、状态和最终战斗属性快照。EquipmentSystem 本身仍不结算攻击、防御、耐久或策略行为；器械部署仍由 DefenseDeviceSystem 权威处理。

T0903 后，训练场可以提升后续战斗会读取的武器熟练度和骑术。训练项目由受训 NPC 当前装备决定：主武器对应剑盾、长杆、弓或弩，坐骑对应骑术。T0043 后，全部有效教官位上的 NPC 以人数、“教练”和对应项目熟练度组成共享团队效率，同时作用于全部训练位；受训者按自己的装备成长，在岗教官提升“教练”。训练只改变 NPC 熟练度和基础状态消耗，不直接结算攻击、命中、伤害、防御、骑乘表现或当前战斗策略选择。

## T0034/T0036/T0038 具体库存与马匹战时生命周期（当前已实现）

具体库存迁移已落地：剑盾、长杆、弓、弩、四个盔甲部位、弩床和箭塔都必须消耗各自具体 `item_*` 库存；`weapons`、`armor`、`defense_devices` 聚合库存不再是可互换的正式结算来源。箭束 `item_arrow_bundle` 当前已作为具体库存显示和制造，但尚未新增弓 / 弩逐次弹药消耗。

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

`morale_boost` 由 CombatSystem 应用为斗志激昂 buff，持续 2 游戏小时，当前提高攻击力和 NPC 实体移动速度。开始和结束分别写入 `morale_boost_started` / `morale_boost_ended`；每次战时心理结果写入 `battle_psychology_result` 并进入广场公开事件。`escape` 由 T1203 的 `start_npc_escape(...)` 执行：写入 `escape_started`，让 NPC 前往后门外出口，并在离开地图后写入 `escaped`。T0087 后，逃离挽留回复只解析 `escape_intervention_result=stay|leave`；停止逃离、继续逃离、对话暂停 / 恢复、移动倍率、昏迷暂停和复苏续逃都由程序结算。LLM 不直接改 HP、速度、攻击力或逃离位置。

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

T1105 后，某名 NPC 可用哪些策略只由当前主武器和坐骑判定出的兵种决定。玩家在已入伍且有主武器 NPC 的面板中，通过“装备武器”旁的策略下拉框手动选择当前策略；默认是该兵种列表中的第一种进攻 / 输出策略。更换主武器或坐骑后，CombatSystem 会把策略重置为新兵种默认策略；更换盔甲不会重置策略。`current_order` 可作为 NPC 理解守备官意图的 LLM 上下文，但不再自动决定、覆盖或推断当前战斗策略。

### 剑盾/长杆步兵

- 主动进攻
- 避战

### 弓/弩步兵

- 最大化输出
- 保持距离射击
- 避战

### 近战骑兵

- 主动进攻
- 拉开距离冲击
- 避战

### 骑马远程

- 最大化输出
- 保持距离射击
- 避战

这里的“避战”是已入伍且有主武器 NPC 在战斗模式中的战术策略，不是非战斗人员的同级避战模式。

当前策略语义：

- 主动进攻：近战步兵 / 长杆步兵 / 近战骑兵主动接近敌人，进入武器射程后攻击。
- 最大化输出：远程兵种站桩射击，不为了保持距离主动移动。
- 保持距离射击：远程兵种使用武器射程的 `45% / 72% / 90%` 作为最小、理想和最远控制带；太近时退到理想距离，太远时接近，位于安全带内才稳定射击。
- 拉开距离冲击：近战骑兵执行 `withdraw -> ready -> charging -> impact` 循环。先拉到重置距离，再以坐骑冲锋速度接近；命中时先结算马匹独立冲撞与僵直，再用冲锋倍率结算武器攻击，随后重新脱离。
- 避战：入伍持武器 NPC 的战斗策略，复用非战斗人员短步长避战目标算法，但保持 `behavior_mode == "combat"`；该策略只在最近敌人低于避战安全阈值时按敌人来袭方向短距离远离，敌人已经远离到阈值外时保持 `combat_ready` 等待，不继续退向驿站边界或角落；该策略不主动攻击，清敌后按战斗模式退出规则回到工作模式。

## 非战斗人员避战模式

未入伍 NPC、以及已入伍但没有主武器的 NPC 都属于非战斗人员，不进入集结和战斗模式。敌人进入一定范围后进入避战模式，按最近敌人的接近方位生成短距离远离目标，并用 NPC / 敌人组合生成稳定散射角，让不同 NPC 向不同方向四散移动。避战会尝试逐步退到接敌范围之外，但不会一步挪到驿站角落，也不会离开驿站太远。只有当场上没有敌军后，避战 NPC 才退出避战回到工作模式。

T1103B/T1103C 当前实现：`CombatSystem` 在敌人接触扫描中检测工作模式非战斗人员，调用 `NPCSystem.set_npc_behavior_mode(..., "avoid_combat")` 并通过 `move_npc_to_world_position(...)` 移动到按敌方方位计算出的短步长目标。避战快照保存在 `active_avoidances`，包含敌人、距离、目标点、移动步长、目标点敌距、原因和最近结果。敌军清空时避战 NPC 回到 `work` 且不触发计划重评估。若避战中的 NPC 被征召成功但仍没有主武器，继续避战；若随后装备主武器且仍有敌军，切入 `combat`；若无敌军则回到 `work`。T1103D 起，`work -> avoid_combat` 和 `avoid_combat -> work` 的模式切换本身不写事件，避战信息只由 `avoidance_started` / `avoidance_ended` 记录。

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
- 围墙与主厅都使用通用槽并提高到 6 级，每次升级最多解锁 1 个。围墙 1–6 级容量为 `1 / 2 / 2 / 3 / 3 / 4`，主厅为 `1 / 1 / 2 / 2 / 3 / 4`。围墙 Lv.3 / Lv.5 虽不扩槽，但各从建筑逐级配置累计 `+5%` 器械射程；最终倍率依次为 `1.0 / 1.0 / 1.05 / 1.05 / 1.10 / 1.10`。主厅固定 `range_multiplier=2.0`，不使用围墙加固收益。DefenseDeviceSystem 每次生成槽位、部署与选敌快照时按宿主当前等级解析倍率，因此升级前已部署的器械也会立即获得收益。
- 器械按统一游戏秒推进冷却，在有效射程和前向射界内选择最近敌人，再调用 `CombatSystem.apply_defense_device_attack(...)`。该接口复用敌人有效防御、HP 扣除、清零移除、击退归属和最终波次结算。
- 敌人可把附近有效器械作为战斗目标，通过 `DefenseDeviceSystem.apply_damage_to_device(...)` 扣除器械 HP；HP 清零会释放槽位并移除部署。宿主建筑 HP 为 0 或处于不可用状态时，器械不攻击也不暴露为活动目标。

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

T1205 收尾检查已通过 `tools/verify_battlefield_public_info.gd` 综合验收：敌我人数、集结 / 必要模式切换、避战开始 / 结束、低血量、战时心理结果、击退敌人、昏迷、治疗、复苏、逃离、建筑受损和战斗结束均能进入广场或同地点见闻；后续 NPC 对话 payload 与 NPC 面板见闻库都能看到这些公开摘要。`work <-> combat` 与 `work <-> avoid_combat` 仍按 T1103D 规则降噪，不通过 `npc_mode_changed` 广播。

战斗结束后，NPC 回到工作状态，并根据自身经历重新评估计划。
## T0132-P3 正门动态门扇与敌军边界

- 正门现在有两扇 world-static 层 `AnimatableBody3D` 实体门叶。和平时我方 NPC 接近可开门；只要 CombatSystem 存在活动敌军，正门保持锁闭，敌军自身也永远不能触发传感器。
- 敌军仍必须物理抵达正式 `front_gate` 攻击点后才能伤害正门。门扇开合不发布“抵达 / 突破”事实、不改目标选择；只有 BuildingSystem 判定正门 HP 为 0，表现层才解除门叶碰撞，既有单向门洞链接和仓库攻击阶段继续生效。
- 围墙平台仍只承载 DefenseDeviceSystem 的可见部署；平台、美术测距杆和城垛不参与伤害、射程、命中或目标选择计算。
- P3R2 只把四个平台和器械攻击原点移到正门左右墙段；敌军建筑目标序列仍为 `front_gate → warehouse → main_hall`，不会因为平台远离门楼而改为攻击 `wall`。
- P3R4 将右墙器械 facing 从城门统一轴改为 `north_east` 墙外法线，左墙使用 `north_west_a` 外法线；射程、扇区和目标选择公式未改，部署 / 攻击专项通过。
