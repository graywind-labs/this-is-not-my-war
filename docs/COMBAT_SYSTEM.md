# COMBAT_SYSTEM.md

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

- CombatSystem 仅在 `unit_type=melee_infantry` 且 `weapon_type=sword_shield` 时装配 `EnemySwordShieldChibiArtView.tscn`；第一波 8 人及后续同类个体使用 Synty Dark Knight、KayKit 动画和内建剑盾。长杆、弓弩、骑兵继续使用旧回退，不能用剑盾模型冒充。
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
- P5/P6 的固定攻击位与剑盾 / 长杆预排不再参与当前运行逻辑。每个敌人独立查找侦测范围内最近可行动我方单位；没有单位目标时攻击当前未摧毁阶段建筑。所有追击者向目标自身或建筑接触点请求最短可行路径，道路仍没有权重。
- 进入射程者暂停移动并按原 CombatSystem 抬手 / 冷却 / 伤害链攻击；未进入射程者继续向同一目标施压。被前方实体挡住产生的 `stuck_timeout` 只记为 `pressing_blocked` 并等待下一次重寻路，不能伪造到达或永久退出战斗；目标移动超过 `0.35 m` 或前方空间释放后会重新请求路径。
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
- 城外仍受密林复合碰撞与正门开口约束，导航面改为 6 横断面的开放进军廊道；城内使用静态碰撞烘焙的生产 NavMesh。目标销毁时，尚在途中者允许用 `superseded` 原子替换为下一建筑目标，不把旧请求取消误记为导航失败。
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

- 战时公开对话：GM 执行 `spawn_wave 1`、`alarm`，用 `behavior_modes` 确认艾达处于 `rally` 或 `combat`；必要时用 `step_enemies 60` 推进。点击艾达对话，分别用“守住缺口、一起撑住”和“局势已失，立刻从后门撤离保命”等明确话术，收到回复后点击完成。用 `enemies` 查看 `last_wartime_dialogue_result`，并检查 NPC 的 `morale_boost` 或 `escape_intent`。注意效果在完成会话时应用，单看回复但不完成对话不足以验收程序结果。
- 低血量参战者：保持敌人在场并先用 `behavior_modes` 确认艾达为 `combat`；新游戏艾达为 `120/120`，可执行 `damage_npc veteran_deputy_01 90 local_public` 让其跨入阈值且不昏迷。用 `enemies` 检查 `last_low_hp_judgement_result.decision`、`psychology_decision`、`llm_ok` 与 `rule_fallback`；真实结果合法值为继续战斗、逃离驿站或 `inspired`（程序映射为斗志激昂）。GM 扣血以守备官为伤害来源，可能另触发既有计划重估；核对低血量模型时应按 `call_type=battle_judgement` 过滤。
- 低血量避战者：有敌人时执行 `avoid_npc priest_01`，确认其为 `avoid_combat`；新游戏神父为 `85/85`，可执行 `damage_npc priest_01 64 local_public`。此时只允许 `avoid_battle / escape_station`，绝不应返回 `inspired`。
- 逃离挽留：执行 `escape_npc priest_01` 只建立程序逃离状态，本身不调用 LLM。回到主界面点击该 NPC，再点【对话】，分别使用明确挽留或放弃话术；检查响应的 `escape_intervention_result=stay|leave`、`active_escapes` 和 `last_escape_result`。点击攻击应看到 `llm_requested=false / guard_attack_no_reply`，不能把它算作模型选择。

低血量自然多选结果受人物与战局上下文影响，不保证一句话或一次伤害就覆盖 `escape_station / inspired`；需要重复测试时应清敌并开始新战斗，最好重开场景恢复未逃离、未加 buff 的基线。真实 provider 成功必须同时确认 usage 中 provider / model 正确、`fallback_used=false`，不能只看 Godot 的规则降级结果。

## T0114 虔诚陨石与无友伤边界

守备官在共享虔诚满 100 后可选取合法地表召唤陨石。默认半径 5.5 米、下落 1.15 战斗动作秒；落地使用 48 点攻击力与 5 点穿透，对范围内按距离和敌人 ID 稳定排序的最多 12 个目标结算一次冲击。随后地面燃烧 10 战斗动作秒，每 1 秒以 1 点攻击力、0 穿透对当时仍位于范围内的敌人结算一次；燃烧不受冲击 12 人上限限制。

两段伤害均只经过 `CombatSystem.apply_enemy_area_damage(center, radius, raw_attack_power, context)`：该入口只遍历 `_active_enemies`，用水平距离判断范围，并复用 `有效防御=max(0, defense-penetration)` 与 `20/(20+有效防御)`、敌人死亡和正常清敌 / 战斗结束结算。它不枚举 NPC、建筑或我方工程器械，也不调用三者的伤害入口，因此陨石和燃烧严格没有友伤；友方站在落点内也不会损失 HP。

陨石时序使用逻辑 tick，但将游戏秒除以配置的 60 换算为战斗动作秒，因此暂停停止推进，玩家世界时间倍率仍经 TimeSystem 生效，而大招表现与既有战斗动作尺度一致。所有半径、时序、伤害和穿透都来自 `data/piety_ability.json`；HUD 只提交目标位置，不能自行扣虔诚、伤害或清敌。

## T0087 逃离挽留响应合同

逃离挽留不再从通用 `intent` 解析结果。`dialogue_kind=escape_intervention` 的唯一业务字段是 `EscapeInterventionDialogueResponse.escape_intervention_result`，值只能为 `stay` 或 `leave`。CombatSystem 仍负责暂停 / 恢复移动、记录轮次、第五轮收口、停止逃离或继续逃离并写入事件；LLM 不决定速度、位置、行为模式或事件事实。守备官攻击的无回复路径记录 `intervention_result=guard_attack_no_reply`，不伪装成 NPC 的 stay / leave 选择。

## T0081 战时生活消耗

`NPCNeedsSystem` 按行为模式为战时 NPC 选择唯一生活消耗档位：集结与避战每小时 `-4 饱食 / +8 疲劳`，逃离 `-5/+10`，战斗 `-8/+16`。战斗档位是重工作的两倍，移动 / 集结 / 避战 / 逃离均不增加职业经验；逃离挽留对话在逻辑时间推进时按对话档位处理。真正 `escaped=true` 的 NPC 不再参与站内生活模拟。

这些数值只消费 TimeSystem 已计算的有效逻辑秒：暂停不推进，敌人在场的 `x1` 上限和 LLM 慢速自然生效；NPCNeedsSystem 不读取玩家倍率来额外放大战斗数值，也不修改 CombatSystem 的攻击、伤害、冷却或战斗移动公式。

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

当场景中存在任意活动敌人时，CombatSystem 会向 TimeSystem 注册 `combat_enemy_presence` 时间流速上限，把有效倍率上限设为 `x1`。如果敌人出现前玩家速度高于 `x1`，实际有效倍率压到 `x1`，玩家选择值保留；如果已有 LLM 慢速，实际倍率继续使用更慢者。所有敌人消失后释放该上限，恢复正常时间逻辑。

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

T1103/T1103A/T1103B/T1103C 已完成玩家手动摇响警铃后的集结、模式切换和非战斗人员避战闭环：HUD `AlarmButton` 和 GM `alarm` / `rally` 都调用 `CombatSystem.trigger_combat_alarm(...)`。警铃会给所有 NPC 写入 `combat_alarm_rang` 结构化事件；随后只有已入伍、已装备主武器、当前可行动且非睡觉的 NPC 响应集结并进入 `behavior_mode == "rally"`。响应者的普通日常行动会通过 `NPCSystem.set_npc_behavior_mode(...)` 的中断边界打断并释放工位，再移动到城门外防线。阵型按近战步兵 / 长杆步兵 / 近战骑兵前排，弓箭兵 / 弩兵 / 骑射单位后排排列，方向标记面向正门外敌人来袭方向。HorseSystem 只有在 NPC 进入 `behavior_mode == "rally"` 或 `"combat"` 时才让已分配成年马离厩并标记 `ridden`，CombatSystem 据此显示低模坐骑；日常工作模式下马仍在马厩且不显示骑乘。若集结途中或集合点附近遭遇敌人，只有已入伍且有主武器 NPC 会停止集结并进入 `behavior_mode == "combat"` 与 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy` 和必要的 `npc_mode_changed`。未入伍或已入伍但无主武器 NPC 在工作模式中接敌会进入 `behavior_mode == "avoid_combat"`，按最近敌人方位生成短距离散射移动目标，不设置战斗 `combat_mode`，也不攻击敌人；睡觉中的非战斗人员只有被敌人攻击才进入避战。集结到点后等待 1 游戏小时仍未接敌会返回 `work` 且不触发计划重评估；场上敌人清空时，`combat` NPC 返回 `work` 并触发计划重评估，`avoid_combat` NPC 返回 `work` 且不触发计划重评估。T1103D 起，工作 / 战斗和工作 / 避战互转不再写 `npc_mode_changed`，具体战斗和避战事实由 `attack_made`、`damage_taken`、`avoidance_started`、`avoidance_ended` 等事件表达。T1104 后，`combat` 模式中的入伍持主武器 NPC 已能执行基础自动攻击、扣除敌人 HP 并在敌人 HP 清零后移除敌人。T1105 后，战斗模式会按 NPC 当前手动选择的兵种策略决定基础攻击前的战术移动与攻击节奏。T1106 后，波次生成和敌军清空会分别写入广场 `combat_started` / `combat_ended`，并维护本场受伤、昏迷和击退统计；T1201 后，战时公开对话可应用斗志 buff 或触发逃离；T1202 后，战时低血量自身心理判定已接入；T1203 后，逃离会移动到后门外出口并在离图后标记 `escaped`；T1204A 后，逃离过程中可通过 NPC 面板进行最多 5 轮挽留，打开对话暂停逃离移动，未满 5 轮关闭恢复，给钱减速，逃离攻击加速且不请求 NPC 回复，并在昏迷复苏后继续逃离；T1302 后，主厅被摧毁会进入失败占位结算并停止正常推进；T1303 后，活动敌人在场且所有已入伍持主武器战斗人员均昏迷、已逃离或正在逃离时，会进入无可战斗人员失败；T1304 后，包含第 5 波的战斗清敌会进入 Demo 胜利占位结算并停止继续刷波。NPC 结局总结和命中 / 格挡仍留给后续任务。

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

T1104 已实现最小自动战斗，T1105 已接入不同兵种的玩家手动策略选择和对应战术移动，但仍不包含命中率、格挡、士气修正、完整动画或正式战斗结算。`CombatSystem` 在 `TimeSystem.logical_time_tick(game_delta_seconds, numeric_multiplier)` 推进中先处理我方策略与基础攻击，再处理敌方 AI；GM `step_enemies [game_seconds]` 使用同一套逻辑。T1104A 后，玩家时间倍率不再直接影响伤害、攻击间隔、攻击速度或战斗移动速度；敌人在场时 TimeSystem 会把有效倍率上限压到 `x1`，LLM 慢速仍可进一步降低有效推进速度。CombatSystem 不读取真实帧率或 Godot 全局时间缩放。

T1104B 后，战斗攻击冷却使用“战斗动作秒”作为基准：`60` 游戏秒折算为 `1` 战斗动作秒。默认 `x1` 下现实 1 秒仍推进游戏内 1 分钟，但不会让 `attack_interval = 1.5` 的单位在现实 1 秒内攻击几十次；GM `step_enemies 60` 约等于推进 1 秒战斗动作，`step_enemies 600` 约等于推进 10 秒战斗动作。该换算只用于战斗攻击 / 移动表现层，经营生产、治疗、建筑倒计时仍按 TimeSystem 的游戏秒结算。

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
- 器械按 `60` 游戏秒 = `1` 战斗动作秒推进冷却，在有效射程和前向射界内选择最近敌人，再调用 `CombatSystem.apply_defense_device_attack(...)`。该接口复用敌人有效防御、HP 扣除、清零移除、击退归属和最终波次结算。
- 敌人可把附近有效器械作为战斗目标，通过 `DefenseDeviceSystem.apply_damage_to_device(...)` 扣除器械 HP；HP 清零会释放槽位并移除部署。宿主建筑 HP 为 0 或处于不可用状态时，器械不攻击也不暴露为活动目标。

既有部署与实际触发仍沿用 `defense_device_deployed` / `defense_device_triggered`；T0107 没有为器械受击、摧毁、穿透或僵直新增信息事件。当前数值仍是可迭代占位，后续平衡只调整数据定义。动画、炮臂转向、命中特效和正式模型通过表现层消费同一运行态，不参与伤害结算。

## 敌人 AI

Demo 阶段敌人使用规则 AI，不调用 LLM。

T1101 已完成敌人波次配置与调试生成；T0121 将 5 波调整为 `8 / 16 / 24 / 36 / 48` 人，单个敌人的 HP、攻击、防御和穿透整体低于我方平均武装单位，以逐波人数增长制造杀敌反馈和数量压力。每个敌人组记录 HP、武器类型、单位类型、攻击、防御、穿透、攻击速度 / 间隔、攻击抬手、移动速度、攻击范围和目标偏好。`CombatSystem` 会读取该配置，并可通过 `spawn_wave(...)` / `debug_spawn_wave(...)` 在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人实体。

T1301 已完成波次倒计时与自动来袭：每个波次配置可包含 `trigger_day`、`trigger_hour`、`trigger_minute` 和 `trigger_second`，当前 5 波默认分别在第 3-7 天 18:00 触发。`CombatSystem` 在 TimeSystem 的 `logical_time_tick` 中按逻辑时间比较配置触发点，只触发下一未触发波次，并记录 `triggered_wave_numbers`，避免同一波重复自动生成。`get_wave_schedule_snapshot()` 暴露下一波、已触发波次、待触发波次、活动敌人数量、最近自动触发结果和最近手动跳波结果；HUD 使用该快照显示下一波倒计时，GM “跳到下一波”按钮和 `next_wave` / `jump_wave` 命令调用 `debug_trigger_next_wave()` 触发下一未触发波次。T1304 后，包含最终配置波次（当前第 5 波）的战斗在敌人清空后触发 `victory/five_waves_survived`；`GameState.set_game_over(...)` 保存通用结算原因和 `settlement_snapshot`，快照记录剩余资源、建筑 HP / 损毁 / 摧毁、驿站是否仍可运转，以及 NPC 可行动 / 昏迷 / 逃离状态。胜利后 TimeSystem 停止推进，HUD 显示胜利占位界面，`spawn_wave(...)` 会因游戏已结算而拒绝继续生成敌人。

T1303 曾实现无可战斗人员失败条件；T0121 已删除其常量、检查入口、结算函数和 HUD 原因映射。战斗快照不再需要 `combatant_availability` 来决定失败；旧名脚本 `verify_no_available_combatants_failure.gd` 现反向验证“零可战人员时不失败、敌军继续推进、HUD 不出现结算”。

T1102 已完成敌人目标优先级、移动和敌方攻击，T1104 已把该推进扩展为双方基础攻击：`CombatSystem` 监听 `TimeSystem.logical_time_tick` 推进战斗 AI；敌人若在侦测范围内发现可行动 NPC，会优先攻击该 NPC，否则按目标偏好选择仍有 HP 的城门、仓库或主厅。T1104C 起，围墙不再作为敌人攻击目标：城门被攻破后敌人直接转向仓库，仓库被摧毁后再转向主厅；旧配置中的 `wall` / `front_wall` 会在目标偏好规范化时过滤。敌人移动按配置 `move_speed` 和 `game_delta_seconds / 60` 折算为战斗动作秒级位移；玩家 `x2` / `x4` 不额外提高敌人移动速度。进入 `attack_range` 后按战斗动作秒中的 `attack_interval` 和 `attack_power` 进行接触式攻击。攻击 NPC 时会先按 NPC 盔甲防御计算实际伤害，再调用 `NPCSystem.apply_damage_to_npc(...)`；攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)` 并写入 `building_damaged` 事件。T1302 后，主厅 HP 清零时 `GameState` 写入 `game_over=true`、`game_result="failure"`、`failure_reason="main_hall_destroyed"` 和失败时间，广播 `game_over_changed`，`TimeSystem` 自动暂停并停止逻辑推进，HUD 显示失败占位界面；T0121 后这是唯一失败条件。T1304 后，最终波次清敌时 `GameState.game_result` 会写入 `victory`，`game_over_reason` 写入 `five_waves_survived`，`failure_reason` 保持为空，并保存胜利 `settlement_snapshot`。T1104 后，`CombatSystem` 同时维护最近我方攻击快照 `last_friendly_attack_result`，并在最近 AI 推进结果中返回 `friendly_attacks`。T1104A 后，活动敌人存在期间 `debug_get_combat_snapshot()` 会包含 TimeSystem 时间倍率快照，GM 可观察 `combat_enemy_presence` 上限请求；T1104B 后快照会同时包含 `game_seconds` 与 `combat_seconds`，便于检查战斗动作秒换算；T1105 后快照包含 `combat_strategies`，用于查看每名入伍持武器 NPC 当前策略、可选策略和策略移动目标；T1204A 后快照包含 `active_escapes`、`last_escape_result`、已用 / 剩余挽留轮次、逃离速度倍率和暂停 / 恢复状态；T1304 后快照包含 `last_victory_result` 供 GM / 自动化验证。GM 面板提供“警铃集结”“推进敌人AI”“行为模式快照”“模拟避战”“触发逃离”“推进集结等待”按钮和 `alarm` / `rally` / `step_enemies [game_seconds]` / `behavior_modes` / `avoid_npc <npc_id>` / `escape_npc <npc_id>` / `advance_rally_wait [game_seconds]` 命令；敌人快照会显示目标、当前行动、最近 AI 推进结果、我方攻击结果、集结状态、避战目标、逃离目标、战斗策略、行为模式、失败 / 胜利结果和时间上限状态。

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
