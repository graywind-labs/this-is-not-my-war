# MODULE_INDEX.md

## T0270 左上 HUD 背景包裹索引

| 文件 | 职责 |
|---|---|
| `scenes/main/Main.tscn` | 把 HUDFrame 的场景初始边界同步到当前常驻内容尺寸，避免首帧使用旧背景 |
| `scripts/ui/HUD.gd` | 汇总常驻控件实际 / 最小尺寸，按内容边界和统一留白自动适配 HUDFrame |
| `tools/verify_t0270_hud_frame_content_bounds.gd` | 断言背景包含最右器械按钮、最下虔诚按钮，并保持右 / 下 `12px` 留白 |

稳定调用关系：`HUD 常驻控件布局 / 文字刷新 → 内容边界只读汇总 → HUDFrame 展示尺寸`。背景适配不移动控件、不改变按钮交互，也不把库存详情窗纳入常驻面板。

## T0269 敌方远程建筑实体命中索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 让正门 / 主厅弹体透明判断读取本发释放目标；建筑自身为敌方远程目标时保留真实碰撞 |
| `tools/verify_t0269_enemy_ranged_building_damage.gd` | 以正式弓 / 弩覆盖正门、仓库、主厅的自然索敌、起手、释放、碰撞身份与 HP 下降矩阵 |
| `tools/verify_t0260_projectile_transparent_gate_main_hall.gd` | 回归正门 / 主厅射向后方角色或主厅器械时仍可穿透宿主外壳 |

稳定调用关系：`敌方 selector → ranged windup / release target snapshot → 物理弹体 sweep → 目标感知的建筑透明判断 → BuildingSystem.apply_damage_to_building`。透明判断不修改建筑碰撞层、NavigationMap、瞄准点或 HP。

## T0268 HUD 敌袭提示与 NPC 面板信息精简索引

| 文件 | 职责 |
|---|---|
| `scripts/ui/HUD.gd` | 把下一波权威倒计时格式化为精炼来袭句式 |
| `scenes/main/Main.tscn` | 声明 NPC 标题栏状态、公开 / 私下单选和精简入口文案 |
| `scripts/ui/NPCPanel.gd` | 管理互斥组、语义映射、标题栏状态与认识 / 事件 / 见闻详情 |
| `scripts/ui/DialogPanel.gd` | 将玩家可见公开 toggle 与会话状态文案统一精简为“公开” |
| `scripts/systems/DialogSystem.gd` | 精简强制公开失败提示，不改变 `local_public` 权威值 |
| `tools/verify_time_system.gd`、`tools/verify_npc_panel_*.gd`、`tools/verify_dialogue_ui.gd` | 覆盖倒计时、单选、标题栏、记忆入口与对话 toggle |

稳定调用关系：`WaveSystem seconds_until → HUD 展示句式`；`公开 / 私下单选 → local_public / private → 既有权威交互接口`。

## T0266 无效弹药占位移除索引

| 文件 | 职责 |
|---|---|
| `data/resource_defs.json` | 具体库存目录收口为武器、盔甲、器械与货币，不再声明无效弹药商品 |
| `data/crafting_recipes.json` | 移除不可选弹药配方，保留四类工坊远程产物 |
| `scripts/systems/CraftingSystem.gd` | 同步正式配方 ID 集合 |
| `scripts/ui/HUD.gd` | 装备详情只投影武器、盔甲、NPC 已穿装备与存活马匹 |
| `data/npc_initial_long_memory.json` | 工坊知识与阶段标识同步为四类正式远程产物 |
| `tools/verify_*.gd` | 配方、HUD、GM、平衡与远程器械夹具同步删除旧占位合同 |

后端目录无该商品枚举、Schema、Mock 或 Prompt 分支，因此无需代码迁移；项目内原图标源文件与导入元数据一并删除。

## T0265 HUD 装备 / 器械库存图标窗索引

| 文件 | 职责 |
|---|---|
| `scripts/ui/HUD.gd` | 将具体库存、NPC 装备、存活马匹和活动部署组合为纯图标滚动投影；监听权威状态信号并提供只读调试快照 |
| `tools/verify_hud_resources.gd` | 覆盖一物一图标、状态颜色 / Tooltip、实时穿戴 / 分马 / 部署刷新、无正文与纵向滚动 |

稳定调用关系：`HUD 装备 / 器械按钮 → ResourceSystem + NPCSystem / HorseSystem / DefenseDeviceSystem 只读投影 → 图标 + Tooltip`。窗口不调用穿脱、分配、部署或资源结算接口。

## T0264 NPCPanel 装备窗口索引

| 文件 | 职责 |
|---|---|
| `scripts/ui/NPCEquipmentWindow.gd` | 复用 NPCDevLab 的人物轮廓、六槽坐标、图标按钮和精简选择列表；只发槽位 / 物品选择信号，不结算装备 |
| `scripts/ui/NPCPanel.gd` | 提供单一“装备”入口、窗口布局、锁定提示与收回确认，并把合法操作转发到既有权威系统 |
| `scripts/debug/NPCDevLab.gd` | 保留开发检视交互，并同步移除选择窗冗余说明 |
| `scenes/main/Main.tscn` | 隐藏旧装备摘要，将原入口文案收为“装备” |
| `tools/verify_t0264_npc_equipment_window.gd` | 覆盖六槽布局、具体库存、四类盔甲、坐骑、确认双分支、事件不变和战斗锁定 |

稳定调用关系：`NPCPanel【装备】 → NPCEquipmentWindow 选择 / 确认 → NPCPanel 前检 → EquipmentSystem / HorseSystem → NPCSystem 装备槽 + ResourceSystem / 马匹实体 + MemorySystem 原事件`。UI 不扣库存、不写装备槽、不创建第二套马匹分配。

## T0263 全塔防槽位敌方远程瞄准测试索引

| 文件 | 职责 |
|---|---|
| `tools/verify_t0263_enemy_ranged_all_defense_slots.gd` | 对单个槽位 / 器械组合执行正式敌方自然索敌、蓄力、弹体命中和 HP 隔离断言 |
| `tools/verify_t0263_enemy_ranged_all_defense_slots.ps1` | 枚举 8 槽位 × 2 器械的 16 个隔离 Godot 用例并汇总失败项 |

稳定验证关系：`矩阵选择槽位 / 器械 → 正式 Main 单目标部署 → 正式弓手自然 selector / windup / release → 实体弹体 → deployment HP`；无遮挡夹具只排除合法建筑遮挡对瞄准合同的干扰。

## T0262 敌方远程命中主厅塔防索引

| 文件 | 职责 |
|---|---|
| `scripts/world/DefenseDeviceView.gd` | 投影活动器械真实 projectile Area 中心与 deployment 身份 |
| `scripts/world/DefenseDevicePresenter.gd` | 按有效 deployment 提供只读弹体目标快照 |
| `scripts/systems/CombatSystem.gd` | 在敌方远程释放时锁定真实器械瞄准点，并沿物理碰撞提交既有器械伤害 |
| `tools/verify_t0262_enemy_ranged_main_hall_device_hit.gd` | 覆盖主厅塔防的直接弹道诊断和自然索敌 / 蓄力 / 释放 / 命中全链 |

稳定调用关系：`敌方自然索敌 → authored release → Presenter / View 读取真实受击 Area 中心 → 物理弹体 sweep → deployment 身份 → DefenseDeviceSystem HP`；宿主代理仍只服务近战 / 导航。

## T0261 已部署塔防选择与面板索引

| 文件 | 职责 |
|---|---|
| `scripts/world/DefenseDeviceView.gd` | 在活动 InteractionArea 上投影 deployment 身份，废墟时清理身份并关闭拾取 |
| `scripts/world/DefenseDevicePresenter.gd` | 对 interaction Area 做独立屏幕射线，过滤并选择有效的已部署器械 |
| `scripts/systems/BuildingSystem.gd` | 在宿主建筑拾取前转发塔防优先命中，不改变建筑选择权威 |
| `scripts/ui/DefenseDevicePanel.gd`、`scenes/main/Main.tscn` | 绑定只读塔防面板，只显示名称与六项必要战斗属性 |
| `tools/verify_t0261_defense_device_selection_panel.gd` | 覆盖围墙 / 主厅真实输入、面板互斥、字段精简和攻击范围圈联动 |

稳定调用关系：`世界左键 → BuildingSystem → DefenseDevicePresenter area-only ray → DefenseDeviceView / EventBus.defense_device_clicked → DefenseDevicePanel + AttackRangeIndicator → DefenseDeviceSystem 只读快照`。

## T0260 城门 / 主厅弹体透明索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 在通用物理弹体 sweep 内跳过正门 / 主厅建筑 collider，保留其他碰撞与唯一伤害提交 |
| `scenes/defense_devices/DefenseDeviceView.tscn` | 让既有非阻挡 InteractionArea 同时进入 projectile layer |
| `scripts/world/DefenseDeviceView.gd` | 活动 / 废墟状态切换交互与弹体受击层，不创建阻挡 Body |
| `tools/verify_t0260_projectile_transparent_gate_main_hall.gd` | 覆盖实体碰撞保留、弹体穿透、后方目标和主厅塔防直接受击 |

稳定调用关系：`角色 / NavigationAgent → 正门或主厅 StaticBody 阻挡`；`物理箭矢 sweep → 跳过正门 / 主厅 collider → 命中后方敌对 actor 或塔防 Area → 既有 HP 权威入口`。

## T0259 取马集结遇敌索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 区分空清场与真实战后收尾；在 mounting、接敌和重复警铃边界驱动同一取马路线恢复 |
| `scripts/systems/HorseSystem.gd` | 验证 pickup waiting 的真实 NPC 运动并从原地幂等重建马旁路线 |
| `tools/verify_t0259_mount_pickup_enemy_handoff.gd` | 覆盖预战集结、正式波次迁移、接敌锁定、停路、重复警铃及最终上马 |

稳定调用关系：`警铃 → HorseSystem 指定马旁路线 → 正式波次迁移 → pickup watchdog 原地续路 → 接敌保留取马 phase → 上马回调 → 战斗 / 集结`。

## T0258 治疗 pending 交接索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 仅承认当前治疗目标的真实 route started；旧移动状态被正式治疗接管，重复命令可幂等续接 pending |
| `scripts/ui/GMPanel.gd` | 等待空间交接后区分“已前往 / 已到位 / 会话等待”，不把准备成功误报为执行成功 |
| `tools/verify_t0258_heal_pending_handoff.gd` | 覆盖真实战后倒地、旧 `moving_to_*` 竞态、单次命令启动、重复命令与实体到位 |

稳定调用关系：`GM / 计划 assist_heal → formal session → 下一正式帧校验专属 movement target → NPCSystem 实体路线 → 到位 active`；任意其他 `moving_to_*` 不能短路该链。

## T0257 战后治疗与工作装备表现索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/NPCSystem.gd` | 以伤员实时身体位置建立治疗直达路线、避开占位并提供有界拥堵恢复 |
| `scripts/systems/ActionSystem.gd` | 让 GM / 计划共用正式治疗路线，在导航失败时先重试再清理 / 报错 |
| `scripts/systems/MemorySystem.gd` | 把治疗接近移动格式化为 NPC 行动，不把合成目标当建筑 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 保留装备权威，按工作 / 集结 / 战斗 / 武器训练状态切换武器与职业工具 |
| `tools/verify_t0257_postbattle_heal_work_presentation.gd` | 覆盖一键配装、工作在途 / 做饭工具、集结显武器、正式波次倒地与 GM 实体治疗 |
| `tools/verify_t0130_p5_ada_character_integration.gd` | 更新艾达工作收武器、武器训练拔剑与睡醒工作态断言 |

稳定调用关系：`战斗昏迷 → 保留倒地点 → GM / 计划 assist_heal → 身体坐标接近 → 到位后扣费 / helper / 恢复`；`权威装备槽 → 工作收起并显示职业工具 → 集结 / 战斗 / 武器训练重新显示主武器`。

## T0256 警铃解散与模式连续性索引

| 文件 | 职责 |
|---|---|
| `scenes/main/Main.tscn` | 在警铃右侧声明正式“解散”按钮 |
| `scripts/ui/HUD.gd` | 接线警铃 / 解散按钮并保持虔诚按钮布局 |
| `scripts/systems/CombatSystem.gd` | 筛选 rally NPC、统一返回工作、清理 rally runtime，并保持战斗 / 避战退出规则 |
| `scripts/systems/NPCSystem.gd` | 锁定模式打断坐标，连续交接正式战斗世界，调用计划捕获 / 恢复接口 |
| `scripts/systems/DailyPlanSystem.gd` | 捕获被行为模式打断的当前计划项，并在无重评估退出时续接同一项 |
| `tools/verify_t0256_mode_transition_continuity.gd` | 覆盖实际 HUD 解散、六类模式转换、正式波次、计划续接与首帧位移 |

稳定调用关系：`警铃 / 接敌 → 捕获当前计划 + 原地切换模式 → CombatSystem 正式移动`；`解散 / rally 超时 / avoid 清场 → 原地 work + 续接同一计划`；`combat 清场 → 原地 work + 战后计划重评估`。

## T0255 昏迷 NPC 身体点击索引

| 文件 | 职责 |
|---|---|
| `scenes/npc/NPC.tscn` | 在同一 InteractionArea 下定义站立竖直胶囊与昏迷贴地水平胶囊 |
| `scripts/npc/NPC.gd` | 按权威昏迷 / 复苏状态互斥切换交互形状，并保持实体碰撞 / RVO 原边界 |
| `scripts/systems/NPCSystem.gd` | 沿用生产相机射线解析 interaction collider 并发出既有 NPC 选择事件，本任务未改代码 |
| `tools/verify_t0255_unconscious_npc_body_click.gd` | 覆盖站立、倒地、旧悬空区域、面板打开与复苏恢复 |

稳定调用关系：`unconscious 状态刷新 → NPC 切换 InteractionCollision → NPCSystem 生产相机射线 → EventBus.npc_clicked → NPCPanel`；`BodyCollision / NavigationAgent / HP / 治疗` 不由选择形状反向影响。

## T0254 惩戒攻击 / 对话事件分离索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/DialogSystem.gd` | 攻击即时结算但不追加伪台词；仅真实发言提交对话事件，纯攻击结束改走 `guard_attack` 计划重评估 |
| `tools/verify_dialogue_session_lifecycle.gd` | 覆盖连续两次攻击、混合真实发言、取消锁与挂起超时的事件边界 |
| `tools/verify_escape_intervention_dialogue.gd` | 覆盖逃离攻击保留伤害 / 轮次 / 续逃且不生成无台词对话 |

稳定调用关系：`对话攻击 → NPCSystem 权威伤害 / damage_taken → 可选 NPC 真实回复`；完成时 `真实 history 非空 → dialogue_turn + 对话判别`，`真实 history 为空且 attack_committed → 不写 dialogue_turn + guard_attack 重评估`。

## T0253 GM 正式行动命令索引

| 文件 | 职责 |
|---|---|
| `scripts/ui/GMPanel.gd` | 提供行动 NPC / 拜访地点与目标分流，过滤直接行动选项，以显式替换模式调用正式接口并显示失败原因 |
| `scripts/systems/ActionSystem.gd` | 在真实前提校验后替换可中断日常行动；默认调用保持不替换，并继续拥有行动、协助与容量权威 |
| `scripts/systems/NPCSystem.gd` | 正式对话停止时把合成移动目标规范回真实地点，继续拥有实体路线与空间会话 |
| `tools/verify_gm_panel.gd` | 覆盖直接选项过滤、能力门槛、六类命令替换、主厅升级协助与无效命令原行动保留 |
| `tools/verify_t0129c_a5_p6b_formal_visit_location.gd` | 使用正式行动页独立 NPC / 地点选择器继续验证完整拜访路线 |

稳定调用关系：`GM 选择发起者 / 目标 → ActionSystem 校验真实前提 → 中断可中断旧日程 → NPCSystem 正式空间路线 → 原系统权威结算`；前提失败停在校验阶段，不由 GM 伪造成功。

## T0250 马厩马匹 UI 与点击索引

| 文件 | 职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 只显示实际在厩存活马的卡片，并按 HorsePanel 阈值合同渲染橄榄绿 / 暗红进度条与文字 |
| `scripts/ui/HorsePanel.gd` | 维持单马只读信息与条件警示色；T0271 后隐藏模板 / 位置冗余并把内部槽位投影为中文“X号” |
| `scripts/systems/BuildingSystem.gd` | 统一马匹精确点击路由；离厩马直接选择，在厩马继续受透明屋面规则约束 |
| `tools/verify_t0250_stable_horse_ui_and_click.gd` | 正式 Main 覆盖离厩过滤、五类颜色、说明删除与离厩马 / 建筑面板互斥 |

稳定调用关系：`世界精确马匹命中 → 读取 HorseSystem 位置 → 离厩直接 horse_clicked / 在厩结合屋面透明度 → HorsePanel 或 BuildingPanel 互斥显示`。

## T0249 固定目标引导到位与脱困索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 配置 `guidance_stall_recovery_seconds=0.75`，继续提供有效交接与引导圆几何参数 |
| `scripts/systems/CombatSystem.gd` | 计算近战有效余量、排除选点者自身占区、监督连续静止、重选引导圆并管理恢复生命周期 |
| `scripts/world/ActorMotionBody.gd` | 跨 enemy combat request 替换保留独立静止计时，并提供仅忽略 actor-body、始终保留 world-static 的临时碰撞恢复接口 |
| `tools/verify_t0180_gate_attack_positions.gd` | GM 第一波八单位自然接近空城门持续回归：无 waiter、全员攻击、全员真实伤门、脱困还原 |
| `tools/verify_t0243_guided_attack_zones.gd` | 覆盖自占区排除、他人重叠保留和跨 request 静止计时 |
| `tools/verify_t0186_melee_engagement_stability.gd` | 用每 authored 门面一个隔离实体继续验证固定目标持续近战时间线 |

稳定调用关系：`固定目标锁 → 自身排除的实时占区 → 最稀疏圆 → 动态有效到点余量 → ActorMotion 连续静止监督 → 必要时重选 / 临时 actor-body 脱困 → 真实受击体入射程 → 恢复碰撞 → 原攻击时间线`。

## T0248 箭矢穿透与附着索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 锁定远程 release 动作、逐子步跳过同阵营角色、保留世界 / 角色箭、在清敌 / 尸体 / GM 生命周期清理，并公开只读诊断 |
| `scripts/presentation/combat/CombatProjectileView.gd` | 生成箭 / 弩矢模型，按入射轨迹对齐并把箭头略插入真实碰撞点；不拥有伤害或碰撞裁决 |
| `tools/verify_t0248_projectile_friendly_pass_through_and_stick.gd` | 正式 Main 覆盖敌我双向穿同阵营、敌对 / 地面命中、实体跟随、尸体继承和自然战后清理 |
| `tools/verify_t0248_ranged_release_lock_and_interrupt.gd` | 正式 Main 覆盖敌我目标移出射程、release 前中断无箭、release 后中断但弹体继续 |
| `tools/verify_t0143_physical_ranged_projectiles.gd` | 既有物理弹体回归改在生产 NavMap 开放路段运行，继续验证建筑阻挡、移动目标闪避与双向伤害 |

稳定调用关系：`射程 / 目标有效起手 → 锁定 windup → authored release → 独立抛物线 sweep / 同阵营角色 RID 跳过 → 第一处合法敌对或世界碰撞 → 唯一伤害 + 箭矢附着 → 自然清敌或尸体生命周期清理`。

## T0247 敌我活体追击速度索引

| 文件 | 职责 |
|---|---|
| `data/physics_navigation.json` | 在 NPC、友方马匹、商车与敌军 actor profile 中声明友方 / 中立层 1、敌军层 2 的同阵营 RVO layer / mask |
| `scripts/systems/CombatSystem.gd` | 标记持续跟踪活体的接敌点，为敌我活体追击关闭固定终点制动，并继续拥有真实攻击距离交接 |
| `scripts/systems/HorseSystem.gd` | 友方独立马匹改用同体积的 `horse` profile，避免误继承敌军骑乘 RVO 层；返厩 / 会合权威不变 |
| `scripts/world/ActorMotionBody.gd` | 读取每 profile RVO 分层，支持 request 级最终制动开关并公开只读诊断；路径、碰撞与位移权威不变 |
| `tools/verify_t0247_locked_actor_pursuit_speed.gd` | 正式 Main 覆盖第一波敌军与艾达多次目标刷新、双向巡航速度、RVO 阵营、实体净距和攻击起手 |

稳定调用关系：`敌我目标锁 → 活体接敌点持续刷新 → ActorMotion 无固定终点制动 / 同阵营 RVO → CharacterBody 真实接近 → CombatSystem 武器交接距离 → T0245 锁定攻击时间线`。

## T0246 战时奔跑饱食索引

| 文件 | 职责 |
|---|---|
| `data/activity_needs.json` | 配置战时未骑乘实际奔跑的 `-0.1 饱食 / 游戏秒`追加速率 |
| `data/physics_navigation.json` | 配置 walk / run 速度与实际跑动判定余量 |
| `scripts/npc/NPC.gd` | 从真实水平位移累计一次性未骑乘跑动秒数；零饱食统一切 walk 并钳制速度 |
| `scripts/systems/NPCSystem.gd` | 向需求系统暴露 locomotion 快照与一次性跑动样本消费接口 |
| `scripts/systems/NPCNeedsSystem.gd` | 结合活动敌军事实、游戏秒上限和跑动样本结算追加饱食并公开诊断 |
| `tools/verify_t0246_combat_sprint_satiety.gd` | 正式 Main 覆盖计费 / 不计费边界、10 秒精确扣除、零饱食全模式限速与骑乘隔离 |

稳定调用关系：`NPC 真实物理位移 → 未骑乘 run 秒数 → NPCSystem 一次性消费接口 → CombatSystem 活动敌军事实 + TimeSystem 游戏秒 → NPCNeedsSystem 小数累计 / 饱食写回 → NPC locomotion 零饱食 walk 钳制 → ActorMotion profile`。

## T0245 移动角色近战锁定伤害点索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 起手后保留敌我移动角色 cycle target，在 authored impact 唯一结算；权威受伤同步取消 impact 前 / 后攻击并保留 cadence |
| `scripts/presentation/characters/CombatAnimationTiming.gd` | 继续提供剑盾 / 长杆步骑 authored impact 秒；不拥有命中、HP 或中断权威 |
| `scripts/systems/NPCSystem.gd` | 继续独占 NPC HP，并把伤害结果通知 CombatSystem；不自行判断攻击阶段或回滚伤害 |
| `tools/verify_t0245_locked_melee_impact.gd` | 正式 Main 覆盖敌我目标出圈命中、伤害点前零伤害中断、伤害点后不回滚及唯一提交 |

稳定调用关系：`射程 / 攻击线满足 → cycle target + windup → 目标可移动出圈 → CombatAnimationTiming authored impact → CombatSystem 锁定目标唯一伤害 → recovery`；任意正伤害可在 impact 前作废本次动作或在 impact 后只终止余下动作。固定目标仍走 `T0243 guidance → T0144 model contact`，远程仍走物理弹体。

## T0244 后门战时无碰撞通行索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 为后门声明 `disable_leaf_collision_while_enemy_present=true`，正门缺省不启用 |
| `scripts/presentation/buildings/FormalGateArtView.gd` | 只读活动敌军数，切换后门两扇门叶碰撞并公开只读快照；不拥有敌军、导航或 HP 权威 |
| `tools/verify_t0244_rear_gate_combat_passthrough.gd` | 正式 Main 验证和平阻挡、战时关闭、敌我双向穿门、清敌恢复和正门隔离 |

稳定调用关系：`CombatSystem 活动敌军数 → BackGateArt 门叶碰撞覆盖 → actor 统一物理通行`；门塔 / 墙段、NavigationMap、商路 / 逃离与 BuildingSystem 不经过该分支。

## T0243 建筑 / 塔防动态攻击引导索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 声明 `enemy_attack_guidance_zones_v2`、圆柱高度、真实重叠选择和受击体射程交接政策 |
| `scripts/systems/CombatSystem.gd` | 复用受击表面候选，生成非重叠近战 / 远程圆柱；统计真实敌军胶囊、动态选择稀疏区、更新 ActorMotion 终点并在受击体入射程时交接攻击 |
| `data/physics_navigation.json`、`scripts/world/StationLayoutController.gd` | 提供步兵 / 骑兵真实胶囊半径与高度、生产 NavigationMap 和建筑 / 塔防空间几何，不保存占区或攻击权 |
| `tools/verify_t0243_guided_attack_zones.gd` | 正式 Main 覆盖非重叠圆、体积占区、最少人数 / 最近选择、实时换区、锁保持、未到圆心攻击及塔防同源 |

稳定调用关系：`建筑 / 塔防真实受击表面 → CombatSystem 同武器引导圆 → 活动敌军胶囊实时重叠计数 → 最稀疏 / 最近可达圆 → ActorMotionBody → 最近受击接触点进入武器射程 → 既有真实攻击碰撞与 HP 权威`。

## T0242 敌方骑兵人马共同阵亡索引

| 文件 | 职责 |
|---|---|
| `scripts/presentation/characters/EnemyMountedArtView.gd` | 组合骑手 `Death_A` 与马匹 `Death`，固定阵亡根位置、保持马匹末帧，并在共同保留时间后整体释放 |
| `scripts/systems/CombatSystem.gd` | 敌军 HP 归零时照常立即移出权威战斗，把骑兵表现包装重挂后启动 `2.4 s` 共同尸体保留，不再计算逃跑目标 |
| `scripts/debug/NPCDevLab.gd`、`data/presentation/npc_dev_lab.json` | 提供 Main 同源的“敌方骑兵人马原地阵亡（实战）”验收，不写 HP / 胜负权威 |
| `tools/verify_t0242_enemy_mounted_shared_defeat.gd` | 在正式 Main 覆盖零漂移、人马双死亡动画、马匹末帧保持、同步清理、骑射同源与旧逃跑字段隔离 |

稳定调用关系：`CombatSystem 敌军 HP=0 / 权威移除 → EnemyMountedArtView.apply_profile → begin_mounted_shared_defeat → Death_A + horse Death / 原地保留 → defeat_cleanup_completed → 包装整体释放`。

## T0241 敌军战斗重定向速度索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 为 `enemy_*` 战斗移动替换声明动量连续，不改变目标 / 租约 / 攻击权威 |
| `scripts/world/ActorMotionBody.gd` | 在活动 request 被允许替换时继承受限水平速度，并公开期望、RVO、应用、实际速度和受限原因 |
| `tools/verify_t0241_enemy_combat_retarget_speed.gd` | 在生产 NavigationMap 开放道路覆盖步兵 / 骑兵巡航重定向、动量计数和最终目标制动 |

稳定调用关系：`CombatSystem 目标身份变化 → enemy combat motion options → ActorMotionBody request 替换并继承受限动量 → 原路径 / RVO / 碰撞 / 制动流水线 → 现有动态波次 motion 快照`。

## T0240 战斗避战近敌触发索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 将战斗避战从持久目标锁驱动改为最近实际威胁触发；复用全敌加权选点，隔离旧策略请求、恢复中断终点并保持原攻击锁 |
| `scripts/npc/NPC.gd` | 将战斗避战活动 / 待命状态投影为“正在避战 / 避战待命” |
| `scripts/systems/MemorySystem.gd` | 为地点行动摘要提供相同的战斗避战状态文本 |
| `tools/verify_t0240_combat_avoid_strategy_threat_trigger.gd` | 正式 Main 覆盖远锁近威胁、三敌加权、无伤害、策略切换、中断恢复、锁保持和安全距离待命 |
| `tools/verify_combat_strategies.gd` | 将既有避战策略断言更新到加权站内选点与显式待命状态 |

稳定调用关系：`CombatSystem 最近威胁触发 → T0209 全敌加权 / StationLayoutController 落点解析 → NPCSystem / ActorMotionBody 物理移动 → NPC / Memory 只读状态投影`。攻击目标锁与避战触发敌人分开记录。

## T0239 宿舍个人衣柜索引

| 文件 | 职责 |
|---|---|
| `scripts/presentation/buildings/FormalDormitoryArtView.gd` | 从正式床 fixture 只读筛选 8 个固定归属，生成左右各四座完整双门个人衣柜并暴露表现快照；零碰撞、导航、库存与睡眠权威 |
| `tools/verify_t0239_dormitory_personal_wardrobes.gd` | 锁定 8 个唯一住户 / 床位映射、柜体结构和尺寸、旧脚箱清理、零碰撞及 10 床 / 10 fixture 合同 |

稳定调用关系：`StationLayoutController 先生成 FixtureLayout → FormalDormitoryArtView 只读 assigned bed metadata → PersonalWardrobe presentation`。床位分配与睡眠仍只归 BuildingSystem / ActionSystem / NPCSystem。

## T0238 陨石坑 24 小时淡化索引

| 文件 | 职责 |
|---|---|
| `data/piety_ability.json` | 配置弹坑 `86400` 游戏秒寿命 |
| `scripts/systems/PietySystem.gd` | 监听逻辑游戏秒、维护每个弹坑进度、到期只清坑体，并与战中陨石实体清理隔离 |
| `scripts/presentation/combat/MeteorPresentation.gd` | 将淡化进度投影到凹坑、焦土、灰床、灰烬块和坑缘材质 Alpha，提供独立 `remove_crater()` |
| `tools/verify_t0238_meteor_crater_decay.gd` | 覆盖暂停现实帧、12/23/24 小时边界、材质透明度和战中岩体保留 |

稳定调用关系：`TimeSystem → EventBus.logical_time_tick → PietySystem crater lifetime → MeteorPresentation material alpha / crater removal`。`combat_ended → remove_landed_body` 是独立链，二者都结束后才释放共享表现根。

## T0237 避战事件摘要索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/MemorySystem.gd` | 将 `avoidance_started` 格式化为不展开敌军与加权方向的固定精简摘要，继续保留结构化 payload |
| `tools/verify_avoid_combat_mode.gd` | 在正式近敌避战流程中精确断言摘要文本，并确认敌军与避战目标详情仍存在于 payload |

稳定调用关系：`CombatSystem 提交 avoidance_started 结构化事实 → MemorySystem 生成精简摘要 → 亲历事件 / 地点旁观见闻共用同一事件`。本任务不修改避战选点、导航、行为模式或传播范围。

## T0236 敌军实体移动与动画同步索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 逐物理帧采样正式敌军 Actor 的水平位移，以活动运动请求和低速启停迟滞生成表现移动事实，并向步行 / 骑乘包装投影实际方向、速度和移动状态 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 复用既有 `moving / movement_speed` 接口播放 run；本任务不新增运动或伤害权威 |
| `scripts/presentation/characters/EnemyMountedArtView.gd` | 复用既有骑手 `mounted_walk` 与马匹 Walk 接口；本任务不修改骑乘实体运动 |
| `tools/verify_t0236_enemy_locomotion_presentation.gd` | 覆盖动作文本错位、`0.06 m/s` 拥挤爬行、步兵 / 骑兵真实动画片段与播放倍率、停止迟滞及攻击表现优先级 |

稳定调用关系：`ActorMotionBody / CharacterBody 实际 Transform → CombatSystem 水平位移采样 → ChibiCharacterPilot 或 EnemyMountedArtView → run / mounted_walk / horse Walk`。攻击、受击、昏迷、死亡和败退表现优先；表现采样不反向写入导航、目标锁、租约或伤害。

## T0235 我方远程战术接近恢复索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 在兼容 `shared_combat_navigation_v1` 下声明远程到达余量、静止换点门槛和旧点排除距离 |
| `scripts/world/ActorMotionBody.gd` | 独立采样不被动态目标更新清零的实体静止时间，并公开最小运动进展快照 |
| `scripts/systems/NPCSystem.gd` | 转发 ActorMotion 进展；保存换点次数和最近卡住诊断，不参与选点或位移 |
| `scripts/systems/CombatSystem.gd` | 监督 active-but-stuck 请求、排除旧点重选，并保证到达容差外沿仍位于 `95%` 攻击交接带内 |
| `tools/verify_t0235_friendly_ranged_tactical_recovery.gd` | 覆盖步行 / 骑乘弓弩、目标更新、无位移换点、到达边缘与真实攻击起手 |

稳定调用关系：`T0198 目标锁 → T0229 远程圆弧 → NPCSystem / ActorMotionBody → T0235 实体进展监督 → 必要时排除旧点重选 → 95% 内停止移动 → 正式攻击时间线`。T0232 活动撤离段在该链之前拥有最高优先级。

## T0233 后期波次固定目标远程容量索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 声明六个实际射程比例，以及远程建筑 / 塔防每排独立表面预算 |
| `scripts/systems/CombatSystem.gd` | 为正门、旋转建筑包络和单 / 多区域塔防代理生成远程六排候选，保留近战与租约 / 命中合同 |
| `tools/verify_t0233_ranged_fixed_target_position_capacity.gd` | 覆盖正门、仓库、主厅、城墙塔防、主厅双墙塔防的容量、射程、区域分布和近战回归 |
| `tools/verify_t0220_enemy_ranged_multirank_building_positions.gd` | 将既有多排回归推进到六排，并继续覆盖弓 / 弩 / 骑射与近处选内排 |

稳定调用关系：`配置比例 / 表面预算 → CombatSystem 几何候选 → NavigationMap 验路 → attack-position lease → 实际到位 → 射程复核 / 真实弹体碰撞`。

## T0232 我方远程保持距离撤离索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 以 `friendly_station_response_v4 / weighted_close_threat_retreat_v1` 声明 `1/3` 触发、`2/3` 单段和到达容差 |
| `scripts/systems/CombatSystem.gd` | 在目标锁前裁决近身优先级，复用多敌加权场，维护不可中途改令的撤离段，并在到点后续段或恢复普通远程链 |
| `scripts/world/StationLayoutController.gd` | 校验 v4 配置，继续用站内多边形、实体包络与生产 NavigationMap 解析撤离落点 |
| `scripts/systems/NPCSystem.gd`, `scripts/world/ActorMotionBody.gd` | 保存活动段诊断并执行既有世界移动；失活时由 CombatSystem 补发同一目标 |
| `scripts/npc/NPC.gd`, `scripts/ui/NPCPanel.gd`, `scripts/systems/MemorySystem.gd` | 将独立动作状态显示为“拉开距离”，不参与战斗裁决 |
| `tools/verify_t0232_keep_distance_retreat_cycle.gd` | 覆盖步行 / 骑射、近身清锁、多敌权重、段内不改令、同点恢复、到点续段 / 安全索敌与站内修正 |

稳定调用关系：`keep_distance 近身扫描 → T0209 加权威胁场 → StationLayoutController 站内 / 实体 / NavMap 修正 → NPCSystem → ActorMotionBody`；到点安全后回到 `T0198 目标锁 → T0229 远程攻击位 → 攻击时间线`。

## T0231 塔防精确到位恢复索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 配置近战塔防精确到位阈值、恢复带半径与无进展触发时间 |
| `scripts/world/ActorMotionBody.gd` | 提供可诊断、可恢复的运行态 RVO 开关；不改变 NavigationMap、碰撞或速度权威 |
| `scripts/systems/CombatSystem.gd` | 识别已持租约且卡在最后接近带的近战敌人，管理避让抑制生命周期，并继续以精确到位 + 真实武器碰撞授权攻击 |
| `tools/verify_t0231_defense_device_precise_arrival_recovery.gd` | 覆盖主厅 slot03 双墙租约、恢复触发、未提前攻击、到位交接、避让恢复和远距离拒绝 |
| `tools/verify_t0195_natural_defense_device_engagement.gd` | 保留自然整波真实墙碰撞与器械连续扣血回归 |

稳定调用关系：`reserved 塔防攻击位 → 进入恢复带且持续无进展 → 暂停该 Actor 的 RVO → 原路径精确到位 → 恢复 RVO / occupied → 真实武器扫掠碰撞 → 器械 HP`。候补不进入该链。

## T0230 主厅角落塔防双墙受击索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 为每个主厅角槽生成前 / 后墙与同侧侧墙两组宿主区域，并保留原主代理镜像 |
| `scripts/systems/DefenseDeviceSystem.gd` | 规范化 `host_proxy_regions[]`，投影到 deployment 与活动塔防目标 |
| `scripts/systems/CombatSystem.gd` | 按区域生成 `4 + 4` 攻击位、记录区域租约身份，并逐区域校验真实碰撞 |
| `tools/verify_t0230_main_hall_corner_dual_wall_contact.gd` | 覆盖四槽双墙映射、攻击位分布、两墙扣血、远端拒绝和主厅 HP 隔离 |
| `tools/verify_t0228_main_hall_defense_wall_contact.gd` | 保留解锁 / 原主墙回归，并按候选所属区域验证墙外位置 |

稳定调用关系：`主厅角槽 → 两个现有 StaticCollision 墙段区域 → 同一器械目标的区域化攻击位租约 → 任一对应墙面真实碰撞 → 唯一 DefenseDeviceSystem HP`。

## T0229 远程攻击位与正门接敌恢复索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 为远程目标锁生成 `95%` 射程可达攻击圆、过滤静态遮挡、随目标重选并恢复失活策略移动；集结跨正门沿用普通半径索敌 |
| `tools/verify_t0225_station_breach_global_friendly_targeting.gd` | 覆盖破防 8 人目标锁、步行弓 / 弩攻击位半径、活动导航与人为取消后的自动恢复 |
| `tools/verify_t0229_mounted_gate_wave_handoff.gd` | 覆盖四骑手自然集结到门洞、GM 第五波切战、真实离门位移、持续目标锁与重复警铃不覆盖 |
| `docs/COMBAT_SYSTEM.md` / `docs/AI_NPC_SYSTEM.md` | 记录目标锁、攻击位循环、警铃排除与移动权威边界 |

稳定调用关系：`CombatSystem 目标锁 → range × 0.95 圆弧候选 → NavigationMap 吸附 / 验路 + 静态攻击线 → 最近可达攻击位 → NPCSystem / ActorMotionBody → 到位复核 / 攻击时间线`；合法锁继续忽略警铃，移动中断由同一战斗循环恢复。

## T0228 主厅塔防墙面受击与前侧优先解锁索引

| 文件 | 职责 |
|---|---|
| `data/defense_device_defs.json` | 主厅前侧 `slot_03/04` 改为 Lv.1/3，背侧 `slot_01/02` 改为 Lv.5/6，保持四槽基础射程 `1.0x` |
| `data/station_layout.json`、`data/presentation/station_spatial_plan.json` | 同步四个平台的正式 / 设计空间等级合同 |
| `data/building_fixture_layouts.json` | 同步平台显示名和逐级 fixture 显隐顺序 |
| `scripts/world/StationLayoutController.gd` | 从主厅对应墙面生成宿主代理位置、瞄准点、墙段身份和外向方向 |
| `scripts/systems/DefenseDeviceSystem.gd` | 将宿主外向方向绑定到 slot、deployment 与活动防御目标快照 |
| `scripts/systems/CombatSystem.gd` | 生成敌军塔防攻击位时优先使用墙面外向方向，真实墙碰撞继续转交器械伤害 |
| `tools/verify_t0228_main_hall_defense_wall_contact.gd` | 覆盖六级解锁、四槽外侧攻击位、真实墙碰撞、器械扣血与主厅 HP 隔离 |

稳定调用关系：`主厅槽位 → 正式屋顶展示锚点 + 对应外墙受击代理 → 敌军外侧攻击位 → 真实墙碰撞 → DefenseDeviceSystem 器械 HP`。

## T0227 刚上马自动集结索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 统一刚上马后的集结 / 遇敌分流，为无旧 reservation 骑手分配稳定骑兵阵位，并恢复中断的集结移动 |
| `scripts/systems/HorseSystem.gd` | 沿用真实会合、上马事实与 `handle_npc_mount_ready(...)` 回调，无修改 |
| `scripts/systems/NPCSystem.gd` / `scripts/world/ActorMotionBody.gd` | 沿用世界移动活性查询、正式导航、RVO 和门路前缀，无修改 |
| `tools/verify_t0227_mount_auto_rally_and_recovery.gd` | 覆盖直接接敌取马、刚上马自动阵位、正门内侧中断恢复、自然到位和途中遇敌 |

稳定调用关系：`HorseSystem 真实上马完成 → CombatSystem 保留 / 生成骑兵阵位 → 正常友军索敌分流 → rally 或 combat`；`rally 意图 + NPCSystem 物理活性 → 等待或原阵位恢复`。

## T0226 避战移动自恢复索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 同时校验避战状态意图与底层移动活性，在未到点的请求中断后重算或恢复避战路段 |
| `scripts/systems/NPCSystem.gd` / `scripts/world/ActorMotionBody.gd` | 沿用现有世界移动活性查询与物理导航权威，无修改 |
| `tools/verify_t0226_avoidance_motion_recovery.gd` | 复现残留 `moving_to_*` 状态，覆盖圈内威胁重算、威胁离圈后原路段恢复与真实位移 |

稳定调用关系：`avoid_combat 意图 + NPCSystem 物理移动活性 → CombatSystem 等待 / 恢复判定 → 当前威胁重算或原目标恢复 → NPCSystem / ActorMotionBody 导航`。

## T0225 驿站破防全局友军索敌索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 把站内敌军事实提升为全体武装应征 NPC 共享的 `station_breach_global` 候选域，并在站内清空后恢复普通分域 |
| `tools/verify_t0225_station_breach_global_friendly_targeting.gd` | 使用 GM 一键征召配装与第五波 48 敌覆盖 8 人站外全局锁、站外近敌过滤、4 人取马、主动追击及普通半径恢复 |
| `tools/verify_t0198_friendly_target_lock.gd` | 更新历史站外破防断言，锁定站外响应者直接取得站内目标 |
| `docs/COMBAT_SYSTEM.md` / `docs/AI_NPC_SYSTEM.md` | 记录目标域、行为模式、坐骑和兵种策略边界 |

稳定调用关系：`interior_polygon -> station_breached -> station_breach_global -> 最近站内敌人 -> combat_target_enemy_id -> 取马 / 策略移动 / 攻击`；站内清空后回到 `entire_station / unified_radius`。

## T0224 统一警铃集结索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 统一警铃响应资格、合法目标锁保护、旧模式运行态清理、已骑乘直达与正常友军索敌打断 |
| `scripts/systems/NPCSystem.gd` | 沿用行为模式中断和世界移动权威，不新增警铃专用状态或移动器 |
| `scripts/systems/HorseSystem.gd` | 沿用未上马会合与 `handle_npc_mount_ready(...)` 回调；已上马状态由 CombatSystem 保持 |
| `tools/verify_t0224_unified_alarm_rally.gd` | 覆盖六类响应来源、唯一目标锁排除、两种骑乘阶段及 15 米索敌打断 |

稳定调用关系：`HUD / GM 警铃 → CombatSystem 筛选无目标持武器应征者 → NPCSystem 统一中断 / 移动 → HorseSystem 按需先会合 → T0198 正常友军索敌锁定 → combat`。已有目标锁的 NPC 不进入写路径。

## T0223 主厅基础射程与昏迷末帧保持索引

| 文件 | 职责 |
|---|---|
| `data/defense_device_defs.json` | 将主厅四槽基础射程倍率统一为 `1.0`，保留围墙等级加固的独立来源 |
| `scripts/ui/DefenseSlotPresenter.gd` | 仅在真实倍率不为 `1.0` 时显示宿主射程加成，主厅不再显示高台说明 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 昏迷 / 骑乘坠落的一次性 `Death_A` 结束后保持末帧，权威复苏边沿继续播放 `Lie_StandUp` |
| `data/npc_initial_long_memory.json` | 保留主厅槽位与部署资格知识，删除 8 名 NPC 的旧射程翻倍描述 |
| `tools/verify_t0223_main_hall_range_and_unconscious_pose.gd` | 覆盖主厅六级倍率、UI 文案隐藏、昏迷末帧保持、重复刷新零回卷和真实复苏起身 |

稳定调用关系：`槽位基础倍率 + 围墙等级收益 → DefenseDeviceSystem 最终射程 → UI / 感知 / 攻击圈只读`；`NPCSystem HP / 30% 门槛 → NPC profile 边沿 → ChibiCharacterPilot 单次倒地 / 起身表现`。表现层不修改 HP、复苏门槛或塔防结算。

## T0222 骑乘人物镜头与敌军详情索引

| 文件 | 职责 |
|---|---|
| `scripts/npc/NPC.gd` | 按站立 / 骑乘 / 倒地状态提供只读人物镜头焦点与相机高度 |
| `scripts/systems/CombatSystem.gd` | 接线正式敌军 InteractionArea，并提供敌军属性与人物构图只读快照 |
| `scripts/ui/NPCPortraitViewport.gd` | 复用共享 Main World3D 人物窗，统一观察 NPC 或敌军并按快照更新镜头 |
| `scripts/ui/EnemyPanel.gd` | 构建敌军属性列、左侧实时人物窗、目标失效与选择互斥生命周期 |
| `scripts/core/EventBus.gd` | 提供 `enemy_clicked(enemy_id)` 选择事件，供对象面板与攻击圈互斥收口 |
| `scripts/presentation/characters/EnemyMountedArtView.gd` | 向敌军人物镜头公开骑手表现的正面朝向 |
| `scenes/main/Main.tscn` | 在 `Main/UI` 注册 EnemyPanel，并沿用全局 UI 主题与右上对象面板层级 |
| `tools/verify_t0222_mounted_portrait_and_enemy_panel.gd` | 验证骑乘 / 下马构图、真实敌军点击、属性只读、尺寸与互斥停渲染 |

稳定调用关系：`NPC combat_mounted / CombatSystem enemy actor → 只读人物快照 → NPCPortraitViewport 共享世界相机`；`InteractionArea 左键 → EventBus.enemy_clicked → EnemyPanel 只读属性`。UI 不写战斗状态，对象切换只影响面板和视口渲染。

## T0221 通用建筑出口单调进度索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 从全部正式建筑 `entry_route` 计算向外方向，按横截面有符号进度过滤已越过的出口点 |
| `scripts/world/ActorMotionBody.gd` | 保留室外目标刷新时的活动前缀，逐帧推进已越过阶段，并公开保留次数诊断 |
| `tools/verify_t0221_monotonic_building_exit.gd` | 遍历 11 座可进入建筑，并验证真实 NPC 的目标刷新、横向偏移重建、越线推进与室内目标取消 |
| `tools/verify_t0221_mounted_stable_exit.gd` | 驱动四名正式骑手同时上马离厩，检查阶段不回退、门外不折返和全员抵达集结位 |
| `tools/verify_t0210_indoor_exit_prefix_navigation.gd` | 兼容按实际激活点数完成前缀，继续覆盖敌我从诊所出门及移动目标 |

稳定调用关系：`建筑 entry_route → StationLayoutController 向外进度 → ActorMotionBody 单调出口阶段 → NavigationAgent / RVO / CharacterBody 实体位移 → 原最终目标`；NPC、敌军和马匹上层系统只提供最终目标，不能重置已完成阶段。

## T0220 敌方远程建筑多排攻击位索引

> 历史基线：正式调用关系已由本文件顶部 T0233 索引取代。

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 数据化远程建筑外 / 中 / 内三排射程比例，并保留每排建筑表面候选上限 |
| `scripts/systems/CombatSystem.gd` | 从正式建筑表面展开多排候选，维持 NavMap 可达、路径分配、租约 / 占用和真实攻击权威 |
| `tools/verify_t0220_enemy_ranged_multirank_building_positions.gd` | 覆盖正门 / 仓库 / 主厅，弓 / 弩 / 骑射，近处内排选择及近战 / 塔防不变 |
| `tools/verify_t0149_enemy_attack_position_leases.gd` | 租约中断断言改按敌人所有权，允许释放槽位被 waiter 同步合法复用 |

稳定调用关系：`station_layout 排距 → CombatSystem 建筑接触面多排候选 → NavigationMap 吸附 / 最短可达分配 → lease reserved / occupied → ActorMotionBody 到位 → 真实武器 / 弹体接触`；排号不进入索敌、攻速或伤害结算。

## T0219 铁匠铺透明周界与正面单入口索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 为铁匠铺生成完整透明左右 / 后侧周界和正面两段墙，只保留中央门洞；沿用 world-static 与正式 NavMesh 来源合同 |
| `tools/verify_t0219_blacksmith_perimeter_navigation.gd` | 驱动真实格伦从背侧绕到正门进入，并验证纯室外路径绕过铁匠铺、不再穿堂 |
| `tools/verify_t0129c_a1_static_collision.gd` | 锁定 12 座建筑均为五段外壳、铁匠铺门心可通及新静态碰撞总数 |
| `tools/verify_t0129c_a3a_production_navigation.gd` | 要求包括铁匠铺在内的全部可进入建筑路径都穿过真实正面门洞 |

稳定调用关系：`铁匠铺透明 world-static 周界 → 正式 collider-baked NavigationMesh → NPC / 敌军共用 ActorMotionBody + NavigationAgent3D`；进铺仍为 `entry_outside → door_outside → door_inside → interior / workstation`，出铺仍由 T0210 反向门路前缀承担。

## T0218 昏迷 NPC 正门过滤索引

| 文件 | 职责 |
|---|---|
| `scripts/npc/NPC.gd` | 提供只读 `is_unconscious()`，将 profile 权威昏迷状态暴露给空间表现层 |
| `scripts/presentation/buildings/FormalGateArtView.gd` | 接受 `npc_id` 前排除昏迷者；马匹、商队车和敌军边界保持 |
| `tools/verify_t0218_unconscious_npc_gate_filter.gd` | 在同一门边位置验证清醒开门、原地昏迷闭门、倒地可交互和原地复苏再开门 |

稳定调用关系：`NPCSystem 提交昏迷 / 复苏 → NPC.profile / is_unconscious → FormalGateArtView 友军传感 → 既有门保持与开合`；门系统不读取 HP 阈值、不修改 NPC 状态。

## T0217 友方马匹开门与活动门叶通行索引

| 文件 | 职责 |
|---|---|
| `scripts/presentation/buildings/FormalGateArtView.gd` | 将无敌军身份的 `horse_id` ActorMotionBody 纳入友军传感；扩大正门提前量；活动 / 打开 / 关闭中的门叶关闭碰撞，完全闭合后恢复 |
| `scripts/systems/HorseSystem.gd` | 继续以既有 `horse_id + horse_motion_authority` ActorMotionBody 执行返厩 / 会合，无需新增门接口 |
| `tools/verify_t0217_friendly_horse_gate_trigger.gd` | 使用真实 HorseSystem 马匹自然穿门，验证开门、速度上限、活动门叶无碰撞、闭门恢复及敌方马拒绝 |

稳定调用关系：`HorseSystem 马匹 ActorMotionBody 接近 → FormalGateArtView 友军传感 → 活动门叶关闭碰撞并开门 → 马匹 / NPC 沿原导航穿门`；敌军攻门仍为 `五槽 → 固定门板战斗 Area → BuildingSystem HP`。

## T0215 昏迷实体释放与目标交接索引

| 文件 | 职责 |
|---|---|
| `scripts/npc/NPC.gd` | 昏迷时停止运动并关闭 BodyCollision / NavigationAgent avoidance，保留 InteractionArea；复苏或解除空间挂接时按当前生命状态恢复实体 |
| `tools/verify_t0215_unconscious_target_handoff_motion.gd` | 用三敌拥挤实体验证击昏艾达、仓库换锁、运动解暂停、真实位移 / 速度上限、昏迷交互与复苏实体恢复 |

稳定调用关系：`NPCSystem 提交昏迷 → NPC.update_profile → 关闭 Body / RVO、保留 InteractionArea → CombatSystem 重选仓库 → 原 ActorMotionBody 请求继续`；复苏为 `NPCSystem 30% 阈值 → NPC.update_profile → 恢复 Body / RVO`。

## T0214 站外避战回站与战时正门索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 声明站外避战使用正门及内侧 `5.0 m` 正式目标偏移 |
| `scripts/world/StationLayoutController.gd` | 按实际门体旋转解析正门内侧 NavMap 点，并复验站内边界与实体包络 |
| `scripts/systems/CombatSystem.gd` | 站外避战优先回站、进入站内后恢复加权避战；继续独占正门目标、五槽与伤害 |
| `scripts/presentation/buildings/FormalGateArtView.gd` | 允许战时友军触发门叶；排除敌军；提供非阻挡固定门板战斗接触 Area |
| `tools/verify_t0214_outside_avoidance_and_wartime_gate.gd` | 验证自然回站、战时开门、敌军拒绝、五槽不变与开门真实伤害 |

稳定调用关系：`站外避战接敌 → CombatSystem 回站阶段 → StationLayoutController 正门内侧点 → NPC ActorMotionBody 穿门 → 站内加权避战`。门侧关系为 `友军传感 → 活动门叶通行`，攻击侧独立为 `front_gate 目标 / 五槽 → 固定门板接触面 → BuildingSystem HP`。

## T0213 集结超时坐骑返厩与途中会合索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/HorseSystem.gd` | 从骑手实时位置下马；创建 / 清理马匹 ActorMotionBody；按步行速度返厩；再鸣警时冻结马匹、解析旁侧可达点并把骑手交回既有移动链 |
| `scripts/presentation/buildings/FormalStableArtView.gd` | 让移动马匹按实际导航速度转向并播放 Walk，途中等待时切回 Idle；公开动画诊断 |
| `data/horse_defs.json` | 定义友方马匹返厩步行速度 `3.2 m/s` |
| `tools/verify_t0213_rally_timeout_horse_return.gd` | 覆盖自然取马集结、超时下马、正式绕行、速度 / 单帧上限、途中再鸣警零漂移、重新上马与恢复集结 |

稳定调用关系：`CombatSystem rally timeout → NPC work → HorseSystem 从骑手实时位置下马 → ActorMotionBody / NavigationAgent3D / RVO 步行返厩`；途中再鸣警为 `HorseSystem 停马 → NPCSystem 寻路至马旁 → HorseSystem 完成骑乘 → CombatSystem.handle_npc_mount_ready → 原集结点`。

## T0212 骑兵败退坐骑速度索引（已由 T0242 废止）

| 文件 | 职责 |
|---|---|
| `scripts/presentation/characters/EnemyMountedArtView.gd` | 不再接收敌种移动速度；阵亡后固定包装根与马匹根 |
| `scripts/systems/CombatSystem.gd` | 不再把 `move_speed` 传入阵亡表现；继续独占敌军 HP、移除与胜负权威 |
| `scripts/debug/NPCDevLab.gd` | 复用同一原地共同阵亡包装，不再传递逃跑速度 |
| `tools/verify_t0212_mounted_defeat_run_speed.gd` | 历史文件名保留为 T0242 反向回归，锁定轻骑 / 骑射阵亡后均零位移 |

稳定调用关系：T0212 的 `enemy_waves.move_speed → 逃马` 已断开；当前以 T0242 的共同尸体保留合同为准。

## T0211 等待攻击位持续施压索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 为 waiter 选择并保持真实期望攻击位、继续正式移动、区分零租约等待与晋升，并切换候补 / 前排 RVO 优先级 |
| `data/station_layout.json` | 配置候补 `0.20`、正常攻击者 `0.55` 及 `0.08` 稳定身份微差 |
| `tools/verify_t0211_attack_wait_pressure.gd` | 验证候补持续靠近、前排零位移、胶囊阻挡、零攻击权限和释放晋升 |
| `tools/verify_t0207_attack_position_actual_occupancy.gd`, `tools/verify_t0195_natural_defense_device_engagement.gd` | 回归在途容量分离、期望槽位诊断与自然连续器械伤害 |

## T0210 敌我统一室内出口前缀索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 判定可进入建筑室内，排除实体封闭主厅，并从既有 entry route 生成反向四点出口前缀 |
| `scripts/world/ActorMotionBody.gd` | 分离最终目标与当前导航腿，在同一请求内推进前缀、保留目标更新并统一重规划 / 清理 / 调试状态 |
| `scripts/systems/NPCSystem.gd` | 继续转发所有友方普通、行动、战斗与避战移动；既有建筑分段路线与通用前缀按 authored point 自动续接 |
| `scripts/systems/CombatSystem.gd` | 继续提供敌我战斗最终目标与动态更新；不含建筑特例，正式敌军自动消费 ActorMotionBody 前缀 |
| `tools/verify_t0210_indoor_exit_prefix_navigation.gd` | 验证诊所四点顺序、同室内 / 主厅排除、门内续走、敌我实际出门、目标更新与零传送 |

稳定调用关系：`NPC / 战斗最终目标 -> ActorMotionBody 请求 -> StationLayoutController 室内判定 -> interior / door_inside / door_outside / entry_outside -> 同请求最终目标 -> 既有 NavigationAgent3D / RVO`。

## T0209 站内多敌加权避战索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 以 `friendly_station_response_v3 / weighted_enemy_repulsion_v1` 声明避战检测余量、逆平方指数、最小计权距离和边界内缩 |
| `scripts/systems/CombatSystem.gd` | 收集 `39.2 m` 圈内全部敌军，计算距离加权反向向量、等半径原始目标，并维护 `active_avoidances` 诊断与到点重算 |
| `scripts/world/StationLayoutController.gd` | 将原始目标沿射线限制在 `interior_polygon` 内，再拒绝实体包络并解析到生产 NavigationMap 可达点 |
| `scripts/systems/NPCSystem.gd`, `scripts/world/ActorMotionBody.gd` | 继续执行现有友军移动请求、NavigationAgent3D 路径、RVO 和 CharacterBody 实际位移；本任务未新增位移器 |
| `tools/verify_t0209_weighted_station_avoidance.gd` | 验证检测半径、单敌反向、双敌 4:1 权重、圈外排除、墙外 / 主厅内修正、非战斗与显式避战模式 |

稳定调用关系：`行为模式接敌 / 显式 avoid_combat → 圈内敌军集合 → 逆平方反向合成 → 等半径原始目标 → station polygon / 实体 / NavMap 修正 → NPCSystem → ActorMotionBody`。避战边界不调用逃离出口。

## T0208 正门五个门板攻击位索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 将正门攻击带声明为 `4.8 m / 5`，移除门塔攻击面的专用偏移配置 |
| `scripts/systems/CombatSystem.gd` | 仅生成五个门板候选，删除塔面候选和旧七槽相邻墙段代算正门命中 |
| `tools/verify_t0204_front_gate_alignment_and_tower_collision.gd` | 验证五槽都在门板平面、双塔仍实体阻挡、第一波为五租约三候补 |
| `tools/verify_t0180_gate_attack_positions.gd` | 验证自然第一波五名攻击者全部真实命中、三名候补保持正门 |
| `tools/verify_t0184_gate_attack_timeline.gd`, `tools/verify_t0186_melee_engagement_stability.gd`, `tools/verify_t0203_front_gate_attack_handoff.gd` | 按五名门板攻击者回归时间线、持续接触和移动→攻击交接 |

稳定调用关系：`五槽配置 → 实际门体几何 → 门板候选 / 租约 → 五名实体占用并攻击 → 三名正门 waiter`。门塔碰撞只参与物理与导航，不参与正门攻击位。

## T0207 攻击位实际占用索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 将固定攻击位分成在途 `reserved` 与到位 `occupied`；分配冲突看两者、索敌容量只看实际占用；候补移动已由 T0211 覆盖为真实槽位施压与低优先级让行 |
| `tools/verify_t0207_attack_position_actual_occupancy.gd` | 验证全预留 / 部分占用不为满、全实际占用才为满、候补不提前改锁或堵线 |
| `tools/verify_t0195_natural_defense_device_engagement.gd` | 按新合同验证完整第一波在途不改攻正门、候补原因、精确到位及弩床连续真实掉血 |
| `tools/verify_t0196_unified_enemy_targeting.gd` | 用显式 `occupied` 夹具继续验证塔防 / 仓库 / 主厅实际满位降级与正门满位例外 |

稳定调用关系：`索敌候选 → occupied-only 容量预览 → 目标保持 / 降级 → reserved 防抢位 → ActorMotionBody 抵达 → occupied 提交 → 实际满位资格`。候补只在晋升后取得移动到攻击位的权威。

## T0204 正门居中与双塔实体索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 声明正门双塔实体包络；攻击带当前由 T0208 收束为五个门板位 |
| `scripts/world/StationLayoutController.gd` | 生成左右塔 world-static 碰撞及导航源，并从实际旋转门根输出统一门战斗几何 |
| `scripts/systems/CombatSystem.gd` | 生成门体局部对称五槽、只接触门板，并按入场车道稳定分配空槽 |
| `tools/verify_t0204_front_gate_alignment_and_tower_collision.gd` | 验证五槽镜像 / 朝向、双塔尺寸与射线、导航绕行、门洞净宽及五租约三候补 |

稳定调用关系：`station_layout 门 / 塔局部几何 → StationLayoutController 塔碰撞 + NavigationMesh + gate_combat_geometry_v1 → CombatSystem 五个门板候选 / 车道保持租约 → ActorMotionBody 到位 → 真实剑模接触门板`。

## T0203 正门攻击交接索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 保持固定目标租约首次吸附并验路后的权威导航落点，阻止刷新时退回 authored candidate 导致移动 / 战斗终点分裂 |
| `tools/verify_t0203_front_gate_attack_handoff.gd` | 自然生成完整第一波，逐一要求正门 5 个门板租约持有者完成交接并通过真实模型接触扣血，同时输出槽位误差与运动诊断 |

稳定调用关系：`候选 authored position → NavigationMap 吸附 / 验路 → 租约权威 position → ActorMotionBody 到达 → CombatSystem 同点复核 → 模型接触伤害`。刷新只更新接触 / 目标事实，不改写已验证终点。

## T0202 友军攻击动画与清敌收口索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 在活动战斗的敌人集合提前清空时执行统一收口，清除友军攻击状态、近战扫掠和 pending commit，并恢复 NPC 行为模式 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 非循环攻击 clip 在同一权威 sequence 的 windup / recovery 末端保持末帧；只允许 sequence 变化重播 |
| `tools/verify_t0202_friendly_attack_cleanup.gd` | 使用正式艾达与第一波实体，从 windup 外部移除最后敌人并锁定下一步完整状态 / 表现清理 |
| `tools/verify_t0193_friendly_attack_cadence.gd` | 锁定跨中断单调起手间隔及同 sequence 动画零回卷 |
| `tools/verify_t0146_ranged_combat_matrix.gd` | 将弹道夹具移出 T0201 后不可进入的主厅内部，继续覆盖步战 / 骑战弓弩实体弹道 |

稳定调用关系：`CombatSystem 单调 sequence → NPC 状态 phase / elapsed → ChibiCharacterPilot 单次 clip`；`最后敌人移除 → 下一权威战斗步 → _handle_all_enemies_cleared → 清攻击状态 / 恢复工作`。表现层不决定攻速、伤害或战斗结束。

## T0201 主厅不可进入实体碰撞索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 为主厅声明 `solid_interior_blocker`、内缩尺寸和门导航 Link 关闭政策 |
| `scripts/world/StationLayoutController.gd` | 按建筑包络生成无可见网格的 world-static 内部阻挡，将其纳入正式导航源，并在网格分类与门 Link 生成时封闭主厅内部 |
| `tools/verify_t0201_main_hall_solid_collision.gd` | 锁定阻挡尺寸、分层、元数据、射线命中、11 个门 Link 及主厅前后生产路径绕行 |
| `tools/verify_t0129c_a1_static_collision.gd` | 更新静态碰撞总量并区分主厅内部阻挡与既有外墙攻击面 |
| `tools/verify_t0129c_a3a_production_navigation.gd` | 更新生产导航源与门 Link 基线，确认主厅不再具有可用门链接 |

稳定调用关系：`station_layout 主厅包络与 blocker 配置 → StationLayoutController 透明实体 / formal_navigation_source → NavigationMesh 绕行`。CombatSystem 仍命中既有外墙分段并消费原攻击位，透明实体不接管建筑 HP、器械平台、点击或失败结算。

## T0200 敌我统一战斗寻路索引

| 文件 | 职责 |
|---|---|
| `data/station_layout.json` | 定义 `shared_combat_navigation_v1`、开放城外生产 NavMesh 范围、道路零导航权威、目标更新阈值及塔防代理近战 `0.06 m` 精确到达容差 |
| `scripts/world/StationLayoutController.gd` | 烘焙站内外共享静态碰撞导航空间，停用旧敌军正门狭廊，继续提供物理城墙 / 密林 / 建筑绕行 |
| `scripts/world/ActorMotionBody.gd` | 敌我共享路径推进、同 request 目标更新、per-request 最终到达容差、直达 / 绕行诊断、稳定身份 RVO tie-break 与战斗持续阻塞重规划 |
| `scripts/npc/NPC.gd`、`scripts/systems/NPCSystem.gd` | 传递友军战斗运动选项并更新同一世界移动请求的目的地 |
| `scripts/systems/CombatSystem.gd` | 在现行目标锁后按武器条件选择接敌点，为敌我下发统一战斗移动；近战塔防代理精确到位后才交接，建筑保留独立校准容差 |
| `tools/verify_t0200_shared_combat_navigation.gd` | 覆盖直线、静态绕障、持续阻塞、敌我移动目标更新、近战 / 远程站距和进范围停步 |
| `tools/verify_t0199_enemy_initial_defense_priority.gd` | 额外锁定墙弩路径不再穿正门入站折返 |
| `tools/verify_t0180_gate_attack_positions.gd` | 覆盖八名敌人的稳定 RVO tie-break、七个城门攻击位自然到位 / 真实伤害及唯一候补 |
| `tools/verify_t0195_natural_defense_device_engagement.gd` | 完整第一波自然接近，要求塔防近战精确到位并产生至少三个独立器械 HP 下降帧 |

稳定调用关系：`CombatSystem 目标锁 → 武器合法接敌点 → ActorMotionBody / NavigationAgent3D 最短路 → RVO / 持续阻塞重规划 → 进入攻击条件 → 既有攻击时间线`。道路与敌军阶段路线均不拥有导航权威。

## T0199 全敌军统一调度与低优先级受击重扫索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 主 AI 对全部活动敌人无条件调用统一在场锁选择器；建筑 / 无武器 NPC 锁收到高威胁实际伤害也建立一次性最近重扫 |
| `data/station_layout.json` | 声明 `enemy_unified_presence_lock_v3`、低优先级当前目标伤害政策及既有范围 / 满位 / 城门例外 |
| `tools/verify_t0199_enemy_initial_defense_priority.gd` | 逐墙 / 主厅槽位验证首次进圈抢占城门，并故意移除动态标记验证主调度不再回退旧索敌 |
| `tools/verify_t0197_enemy_damage_reacquire.gd` | 增加建筑 / 无武器 NPC 当前锁的实际伤害重扫与最近高威胁选择 |
| `game_design.md` | 设计源完整记录敌我范围、候选池、在场锁、类别抢占、满位例外和异源受击重扫 |

稳定调用关系：`全部活动敌人 AI 更新 -> 统一 37.2 m 候选池 -> 高威胁抢占低优先级 -> 在场锁；高威胁实际扣 HP -> 一次性圈内最近重扫`。动态压力标记只影响运动 / 攻击位，不再切换索敌算法。

## T0198 友方分域在场锁索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 统一友方普通站外 `37.2 m` / 站内整站候选、破防时全员站内全局候选、在场锁、移动与攻击共锁、异源实际伤害一次性重扫及节奏锁保持 |
| `scripts/systems/NPCSystem.gd` | 受击只路由行为模式并保留现行目标，暴露友方锁 / 策略移动目标诊断字段；不再精确强写攻击者或重复中断 combat |
| `docs/AI_NPC_SYSTEM.md` | 记录友方目标属于程序权威、分域规则不进入 LLM / 计划，以及取马优先边界 |
| `scripts/world/StationLayoutController.gd` | 校验并暴露当前 `friendly_station_response_v4`、正式驿站多边形与避战 / 保持距离撤离目标解析器 |
| `data/station_layout.json` | 声明 `friendly_enemy_presence_lock_v1`、精确 `37.2 m`、整站范围和异源伤害重扫政策 |
| `tools/verify_t0198_friendly_target_lock.gd` | 覆盖站外边界 / 进战、站内跨半径、在场保持、异源真实伤害、分域重扫、节奏锁与存档排除 |

稳定调用关系：`正式敌人 HP 伤害 -> 友方一次性重扫请求 -> 当前分域最近敌人 -> combat_target_enemy_id -> 策略移动 / 攻击共用 -> T0193 起手锁`。

## T0197 异源受击最近重锁索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 在实际 HP 伤害提交点验证异源高威胁条件、记录 / 消费一次性请求、从现有 `37.2 m` 高威胁池最近重选，并保留攻击起手时间锁 |
| `data/station_layout.json` | 历史 T0197 v2 已由 T0199 的 `enemy_unified_presence_lock_v3` 覆盖；声明异源受击一次性重评估政策、来源和选择范围 |
| `tools/verify_t0197_enemy_damage_reacquire.gd` | 覆盖 NPC / 塔防交叉伤害、同目标 / 零伤害 / 非战斗 / 非高威胁排除、圈外来源不强锁、当前目标重新胜出、一次消费、节奏锁和存档排除 |
| `tools/verify_t0195_natural_defense_device_engagement.gd` | 保留完整第一波自然塔防持续伤害回归，要求至少三个独立 HP 下降帧，并区分“容量已满（必须重选）”与“尚有空位但对当前敌人暂不可达（属于寻路层等待）” |

稳定调用关系：`正式模型接触 / 弹体 -> _apply_damage_to_enemy 实际扣 HP -> 一次性重评估请求 -> 下一次敌军 AI 选择 -> 圈内最近高威胁 -> 恢复在场锁`。

## T0196 敌军统一范围锁定索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 统一 `37.2 m` 候选收集、持武器 NPC / 塔防同池最近首次锁定、无武器次级锁、单位在场保持、NPC 无攻击位、固定目标容量与完整城门例外 |
| `data/station_layout.json` | 声明现行 `enemy_unified_presence_lock_v3`、统一半径、锁政策、NPC unrestricted contact、固定目标满位政策、城门满位等待及 T0197 / T0199 受击例外 |
| `tools/verify_t0196_unified_enemy_targeting.gd` | 覆盖范围边界、首次最近、在场锁、抢占、多人围 NPC、塔防 / 仓库满位跳过、城门满位保持和建筑链 |
| `tools/verify_t0180_gate_attack_positions.gd` | 验证第一波 5 个门板固定位置 + 3 个强制城门 waiter 及占位者真实伤害 |

稳定调用关系：`单位有效事实 + 统一范围 -> CombatSystem 在场锁 -> NPC 直接接触 / 固定目标攻击位 -> ActorMotionBody 寻路 -> 模型接触 -> 权威伤害`。索敌不以路径可达性改写目标；完整城门容量是唯一固定目标例外。

## T0195 塔防严格优先候补索引（历史，已由 T0196 取代）

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 塔防攻击位满员时停止建筑层降级，转入既有塔防 waiter / 晋升链 |
| `data/station_layout.json` | 声明 `defense_device_full_policy=queue_before_buildings` |
| `tools/verify_t0195_natural_defense_device_engagement.gd` | 完整第一波从正式测试区自然接近，覆盖零城门目标、塔防候补、自然模型命中和建筑零伤害 |

## T0194 敌军受击反击与塔防射程覆盖索引（历史，已由 T0196 取代）

| 文件 | 职责 |
|---|---|
| `scripts/systems/DefenseDeviceSystem.gd` | 向活动塔防目标输出合并宿主倍率后的实际攻击射程 |
| `scripts/systems/CombatSystem.gd` | 逐塔防扩展威胁感知；让攻击建筑的敌军精确反击最近实际伤害来源，并保持有效 NPC 目标 |
| `data/station_layout.json` | 配置塔防实际射程外的敌军威胁感知余量 |
| `tools/verify_t0194_enemy_retaliation_and_defense_awareness.gd` | 覆盖墙 / 主厅倍率射程、基础范围外塔防优先、NPC / 塔防精确反击和 NPC 目标保持 |
| `tools/verify_t0150_enemy_target_priority.gd` | 在新塔防感知合同下继续覆盖纯建筑回退链 |

## T0193 我方单位跨中断攻速锁索引

| 文件 | 责任 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 让友军每次合法起手写入共享单调战斗时钟；取消 / 追击 / 模式切换保留 next sequence time；联合读档跨波次重建事务恢复相对锁，战斗结束清除 |
| `scripts/systems/NPCSystem.gd` | 在正式 NPC 空间检查点保存 attack sequence 与相对 lock remaining，恢复为 idle 时间线并等待 CombatSystem 重建绝对点 |
| `tools/verify_t0193_friendly_attack_cadence.gd` | 生产剑盾友军 0.2 秒中断压力、真实行为模式切换、正式动画回卷、真实伤害及 NPC+Combat 联合存读档回归 |
| `tools/verify_t0142_combat_animation_timeline.gd` | 四武器独立 authored 边界夹具显式重置跨中断锁，继续锁定近战 / 远程表现与 impact |

稳定调用关系：`友军装备 / 技能 -> CombatAnimationTiming 完整周期 -> _combat_timeline_seconds -> combat_attack_next_sequence_time -> windup / impact / recovery`；取消只结束当前阶段，正式联合存档只保存相对剩余量。

## T0192 友军战术移动交接索引

| 文件 | 责任 |
|---|---|
| `scripts/npc/NPC.gd` | 合成 NPC 本地移动标志与 ActorMotionBody request active 事实 |
| `scripts/systems/NPCSystem.gd` | 向领域系统只读暴露逐 NPC 物理移动存活性与该 NPC 实际 NavigationMap 的最近可达点；继续统一停止请求、清理 arrival context 与状态 |
| `scripts/systems/CombatSystem.gd` | 核对战术移动状态与真实 request；策略目的地按 NPC 实际 NavigationMap 投影；近战接近点预留导航到达容差，并进入射程内侧安全起手带后再释放移动权威 |
| `tools/verify_t0192_friendly_warehouse_intercept.gd` | 正式第一波 + 仓库拦截几何，中途取消导航并验证自动恢复、攻击交接与模型接触掉血 |
| `tools/verify_t0192b_friendly_occupied_approach.gd` | GM 正式动态波次 + 三名相邻静止仓库攻击者，必须击杀实际先接触的任意敌人、换向存活目标并再次以模型接触造成伤害；不写死相邻出生 ID，同时锁定精确到达与无静止战术移动 |

稳定调用关系：`CombatSystem 战术状态 / 原始策略点 -> NPCSystem 只读查询 -> NPC / ActorMotionBody request 存活事实 + 实际 NavigationMap -> 预留到达容差的接近点 -> 近战内侧安全起手带交接 -> 攻击时间线 -> T0245 锁定角色 authored impact`。

## T0191 敌军跨中断攻速锁索引

| 文件 | 责任 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 从攻击者 / 武器读取完整周期；以单调战斗时间轴保存逐敌最早下次起手时刻，使接触、寻路和目标中断不能清冷却重播 |
| `scripts/presentation/characters/CombatAnimationTiming.gd` | 将同一权威周期映射为固定 impact 比例与 authored 播放倍率 |
| `tools/verify_t0191_enemy_npc_attack_cadence.gd` | 锁定生产第一波数值、NPC / 建筑时间轴一致性、0.2 秒中断压力、正式 AnimationPlayer 无单序列回卷、逐敌起手间隔及艾达真实还击 |

稳定调用关系：`enemy attack_speed -> attack_interval -> CombatAnimationTiming -> attack_next_sequence_time -> 逐敌 windup / recovery`；取消当前相位不取消下一起手时刻，目标类型只在模型接触后选择 NPC、塔防或建筑伤害入口。

## T0189 敌军暂停运动索引

| 文件 | 责任 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 将 TimeSystem 全局暂停与正式敌军战术停步分层合成，下发所有敌军 ActorMotionBody；暂停近战采样 / 延迟伤害提交 |
| `tools/verify_t0189_enemy_pause_motion.gd` | 生产 Main 覆盖单兵、含骑兵正式波次的暂停零位移 / 零速度、状态冻结、恢复续路和战术停步保留 |
| `tools/verify_t0129c_a4_p7_dynamic_combat_pressure.gd` | 显式解除 headless / 重复战斗夹具暂停后再执行动态压力运动回归 |

## T0188 友军站内响应索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 以正式城内多边形提供世界坐标包含查询，并暴露友军响应配置 |
| `scripts/systems/CombatSystem.gd` | 统一站内敌军事实、武装应征全域切战、主动策略站内目标过滤、骑乘等待与动态避战距离 |
| `data/station_layout.json` | 声明向后升级后的 `friendly_station_response_v4`、友军分域锁定、多敌加权避战、保持距离撤离与主动策略 ID |
| `tools/verify_t0188_friendly_station_response.gd` | 生产 Main 覆盖站外 / 站内边界、远距追击、站内目标过滤、取马中转、上马后追击及远程射程外奔跑避战 |
| `tools/verify_combat_strategies.gd` | 按 T0188 的 8.5 米最低安全距离更新既有避战策略回归 |

稳定调用关系：`正式 interior_polygon -> 站内敌军事实 -> 全体武装响应 -> T0225 station_breach_global`；`活动远程射程 -> 避战触发与安全距离 -> avoid_combat -> T0155 run profile`。

## T0187 敌军五级索敌与塔防受击索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 执行五级类型优先级与三建筑白名单；合并同类反击候选；让城墙塔防直接使用城外 lease，并以物理接触半径生成真实受击点 |
| `data/station_layout.json` | 声明 `enemy_target_priority_v2` 的五级顺序，保留范围、锁、反击寿命和阻挡探测参数 |
| `tools/verify_t0150_enemy_target_priority.gd` | 覆盖五级逐层选择、满位回退、同级锁、反击证据、合法建筑链和清理 |
| `tools/verify_t0187_enemy_target_contract.gd` | 生产 Main 覆盖普通建筑白名单、右侧城墙塔防自然选中、真实攻击序列与器械 HP 下降 |

稳定调用关系：`NPC / 塔防 / 三建筑候选 -> 五级可达筛选 -> T0149 lease -> authored 武器扫掠 -> 宿主代理身份 -> DefenseDeviceSystem HP`。

## T0186 近战接触稳定性索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 忽略非战斗导航地板的近战误阻挡；在敌我活动攻击周期锁定目标，并为已占攻击位提供退出滞回 |
| `data/station_layout.json` | 数据化保存交战位置与攻击射程的 `0.18 m` 退出余量；严格进入容差和武器原始射程不变 |
| `tools/verify_t0186_melee_engagement_stability.gd` | 以生产 Main 验证 7 人长期真实围城、逐人攻击 / 伤害比例，以及艾达与第一波剑盾敌人的双向真实掉血 |

稳定调用关系：角色目标为 `严格射程进入 -> authored windup -> T0245 原 cycle target impact -> 权威伤害`；固定目标仍为 `引导区射程交接 -> 模型武器扫掠（跳过 navigation_floor）-> 合法宿主碰撞身份 -> 权威伤害`。任何滞回都不能用来启动超距攻击。

## T0185 全战斗表现时间合同索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/TimeSystem.gd` | 唯一提供现实帧到战斗表现秒 / 倍率的换算，并在快照暴露当前表现速率 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd`、`NPCArtView.gd` | 统一四武器步 / 骑攻击、受击、昏迷、起身、坠马、反馈与粒子时间 |
| `scripts/npc/NPC.gd`、`scripts/presentation/characters/EnemyMountedArtView.gd` | 让友敌正式坐骑动画和敌方共同尸体保留计时遵循相同暂停 / 1:1 合同 |
| `scripts/systems/CombatSystem.gd` | 以共享战斗帧 delta 推进敌我 / 塔防通用物理弹体，不改变碰撞与伤害权威 |
| `scripts/presentation/combat/MeteorPresentation.gd` | 统一陨石落地冲击波与粒子时间；不拥有冲击 / 燃烧伤害 |
| `tools/verify_t0185_combat_presentation_time_contract.gd`、`tools/verify_time_system.gd` | 锁定战斗 1:1、非战斗 x4 上限、暂停 / 恢复、四武器步骑动画和弹体位移 |

稳定调用关系：`real frame delta -> TimeSystem combat frame bridge -> AnimationPlayer / 粒子 / 表现根位移 / CombatSystem 弹体积分`。任何战斗表现不得再直接解释 `numeric_multiplier`；权威 attack timeline、模型接触和伤害入口保持独立。

## T0182 仓库 / 主厅真实外墙攻击索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 从正式建筑根节点输出真实中心、旋转基向量、包络、墙厚与正门缺口，不提供伤害权威 |
| `scripts/systems/CombatSystem.gd` | 分离路线接近点和建筑中心；沿旋转外墙生成紧密攻击位、跳过门洞并将局部接触点传给到位 / 朝向 / 物理命中链 |
| `data/station_layout.json` | 将仓库 / 主厅攻击轮廓声明为 `oriented_perimeter`，保留候选上限与通用租约参数 |
| `tools/verify_t0182_building_attack_positions.gd` | 覆盖仓库旋转轮廓、主厅轮廓、门洞排除、八人租约和每人独立物理建筑命中 |

稳定调用关系：`路线阶段点 -> 建筑邻域接近 / 阻挡预检`；`建筑真实 Transform + 包络 -> 外墙接触候选 -> NavigationMap 租约 -> 武器真实碰撞 -> BuildingSystem 伤害`。两类坐标不得互相覆盖。

## T0181 陨石建筑禁投与友军排出索引

| 文件 | 职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 查询陨石范围圆与旋转建筑 / 附属建筑占地、城墙线段、城门包络的相交事实 |
| `scripts/systems/PietySystem.gd` | 施放前权威拒绝建筑冲突；落地前协调友军排出并记录诊断结果 |
| `scripts/systems/NPCSystem.gd`、`scripts/world/ActorMotionBody.gd` | 按实体间距和生产 NavigationMap 选择安全点，以保留移动请求的外力位移执行排出 |
| `scripts/ui/HUD.gd` | 显示权威建筑冲突状态与 1.6 秒指定提示，不消费虔诚 |
| `scripts/presentation/combat/MeteorPresentation.gd`、`data/piety_ability.json` | 提供 StaticBody3D 同源碰撞半径及友军安全余量 |
| `tools/verify_t0181_meteor_safety.gd` | 覆盖建筑 / 城墙 / 城门禁投、HUD 提示、移动与昏迷 NPC 排出和状态保持 |

稳定调用关系：`HUD 地面点 -> PietySystem 验证 -> StationLayoutController 建筑相交`；合法落地时为 `表现碰撞半径 -> NPCSystem / NavigationMap 排出 -> StaticBody3D 创建`。

## T0180 城门局部接触点与近场候补索引

| 文件 | 职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 为结构攻击位保存局部表面接触点，统一攻击解锁 / 朝向 / 扫掠目标；按前排实际深度生成近场候补并保持租约晋升权威 |
| `data/station_layout.json` | 数据化保存攻击位到达余量与近场候补退让参数 |
| `tools/verify_t0180_gate_attack_positions.gd` | 覆盖五个门板槽最坏到达误差真实命中、其余三人正门等待、租约释放补位及正式第一波路径 |

稳定调用关系：`目标候选局部接触点 -> 攻击位租约 -> NavigationAgent 到位 -> CombatSystem 表面射程 -> T0144 武器扫掠 -> 建筑伤害`。候补只持有目标和近场等待点，不拥有攻击资格。

## T0179 方向化骑姿鞍座坐标索引

| 文件 | 职责 |
|---|---|
| `scripts/presentation/characters/MountedPresentationReference.gd` | 保存已验收骑乘参数，并把任意骑手局部偏移按当帧可见前向转换到父坐标；Main 与 NPCDevLab 共用 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 在平滑 yaw 更新后投影完整骑手根 / 坐姿偏移；坠马起点和相对朝向落点复用同一坐标基准 |
| `scripts/npc/NPC.gd` | 后置同步正式马匹到骑手同一可见前向，不拥有骑手鞍座数值 |
| `scripts/debug/NPCDevLab.gd` | 骑乘检视直接调用共享方向化偏移，不复制生产公式 |
| `tools/verify_t0179_friendly_mount_saddle_alignment.gd` | 覆盖 Main 四方向、逐帧 180° 转向、完整骑姿偏移、马匹前向及 NPCDevLab 同源结果 |

稳定调用关系：`ActorMotion 朝向 -> ChibiCharacterPilot 当帧可见前向 -> MountedPresentationReference 方向化鞍座偏移 -> NPC 后置马匹朝向同步`。该链仅投影表现，不改变 NPC / Horse / Combat 权威。

## T0178 共享路径点推进与避障速度合同索引

| 文件 | 当前职责 |
|---|---|
| `data/physics_navigation.json` | 数据化保存自适应中间点容差、合法捷径、错过点推进、RVO 最大偏转、反向速度拒绝与最终制动参数 |
| `scripts/world/ActorMotionBody.gd` | 在 NPC / 敌军共享移动层推进错过的权威路径点，并让 RVO 速度服从路径方向与制动速度；快照暴露路径点诊断计数 |
| `tools/verify_t0178_mounted_rally_departure.gd` | 走完整 GM 配装警铃路径，覆盖 8 名步行 / 骑乘 NPC 的有效转向、目标回退、路径效率、路径点推进与最终阵位 |

## T0177 装备图标中线对齐索引

| 文件 | 当前职责 |
|---|---|
| `scripts/debug/NPCDevLab.gd` | 将非空装备图标强制在槽位内水平 / 垂直居中，四个中央槽与轮廓共用中线 |
| `tools/verify_t0175_equipment_panel_icons.gd` | 断言图标对齐属性及头盔、胸甲、护腿、坐骑与轮廓的逐像素中心坐标 |
| `tools/capture_t0175_equipment_panel.gd` | 输出更新后的全装截图，目视复核中央图标竖线 |

## T0176 目标进展与实体阻挡寻路索引

| 文件 | 当前职责 |
|---|---|
| `scripts/world/ActorMotionBody.gd` | 幂等处理暂停状态；按剩余路径缩短量检测真实进展并暴露卡死诊断快照 |
| `scripts/systems/CombatSystem.gd` | 对齐动态敌军 RVO / 攻击位到达合同；在索敌可达预检前解析完整城门与仓库阻挡 |
| `tools/verify_t0176_navigation_recovery.gd` | 复现共享终点占用、城门 7 位 + 1 候补、门后目标阻断和紧密攻击位实际到达 |
| `tools/verify_t0129c_a4_p1_formal_enemy_navigation.gd` | 按当前生产接近区常开与非空 NavMesh 合同验证早期正式敌军路径试片 |
| `tools/verify_t0129c_a4_p7_dynamic_combat_pressure.gd` | 锁定完整城门满位后继续在城门候补、不得提前回退到仓库 / 主厅的新合同 |

## T0175 装备轮廓窗纯图标索引

| 文件 | 当前职责 |
|---|---|
| `scripts/debug/NPCDevLab.gd` | 创建紧凑六槽轮廓窗；空槽只显示加号、装备槽只显示配置图标，文字只进入 Tooltip |
| `scripts/ui/EquipmentSilhouette.gd` | 绘制无标题、无部位文字的两头身装备定位轮廓 |
| `tools/verify_t0175_equipment_panel_icons.gd` | 锁定友军空槽 / 全装与敌军只读固定装备的纯图标显示合同 |
| `tools/capture_t0175_equipment_panel.gd` | 输出空槽与全装两种装备窗实景截图供视觉 QA |

## T0174 可装备物品摄影棚图标索引

| 文件 | 当前职责 |
|---|---|
| `data/presentation/item_icon_render.json` | 保存 512 方图、四类纯色背景、正面 / 三分之四摄影机与类别取景倍率 |
| `assets/ui/item_icons/{weapon,armor,horse,defense_device}/` | 保存 34 张由正式 3D 模型生成的可装备物品 PNG |
| `data/weapon_defs.json`、`data/armor_defs.json`、`data/horse_defs.json`、`data/mount_defs.json`、`data/defense_device_defs.json` | 显式登记物品图标路径，供装备选择器与后续背包只读复用 |
| `scripts/debug/NPCDevLab.gd` | 用独立方形图标按钮 + 名称按钮显示配置物品；不拼接路径、不改变装配权威 |
| `scripts/systems/HorseSystem.gd`、`scripts/systems/EquipmentSystem.gd` | 将马匹模板图标投影到具体马快照与 NPC 坐骑装备项 |
| `tools/generate_item_icons.gd` | 从正式模型批量构图、按真实三角形包络取景、正方形裁切并输出视觉 QA 拼图 |
| `tools/verify_t0174_item_icons.gd`、`tools/capture_t0174_item_picker.gd` | 校验数量 / 尺寸 / 背景 / 导入 / UI 消费，并截图检查装备选择器 |

## T0171 马匹面板属性条告警索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/HorsePanel.gd` | 运行时创建文字在上、进度条在下的五组属性，并局部处理基础 HP / 饱食的严格阈值警示色 |
| `tools/verify_t0171_horse_panel_progress_alerts.gd` | 锁定正常、边界、低值与恢复状态的顺序、填充色和字体色合同 |

## T0170 透明马厩马匹点击优先级索引

| 文件 | 当前职责 |
|---|---|
| `scripts/presentation/characters/HorseWorldView.gd` | 在马匹交互 Area 上登记稳定 horse ID 与交互类型 |
| `scripts/systems/HorseSystem.gd` | 用主相机精确解析 horse Area 射线，并通过既有 horse_clicked 转发选择 |
| `scripts/systems/BuildingSystem.gd` | 在建筑通用选择前按具体马所属马厩的透明状态路由 HorsePanel / BuildingPanel |
| `scripts/presentation/buildings/FormalStableArtView.gd` | 让马厩单位优先状态与实际屋面 opacity threshold 同步 |
| `tools/verify_t0170_transparent_stable_horse_click.gd` | 验证透明点马、透明空白和不透明点马三条真实相机射线路径 |

## T0169 马匹面板紧凑镜头框索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/HorsePanel.gd` | 按视口将马匹实时镜头限制在与 NPC 人物框一致的 `190–210 × 300–420 px`，顶边对齐信息栏 |
| `scripts/ui/HorsePortraitViewport.gd` | 保留内部共享世界实时镜头、真实马匹跟随与关闭停渲染，不承担外框布局 |
| `tools/verify_t0162_horse_identity_slots_panel.gd` | 锁定马匹镜头宽高范围、顶边对齐和非通高布局，并回归身份 / 槽位合同 |

## T0168 Godot MCP 路径别名索引

| 文件 | 当前职责 |
|---|---|
| `AGENTS.md` | 登记规范工作区与 MCP Junction 别名，禁止仅按路径字符串误判副本 |
| `tools/verify_project_path_alias.ps1` | 只读验证 Junction 目标、Git 根 / HEAD 与关键文件哈希一致性 |
| `docs/CODING_RULES.md` | 要求路径身份比较先做规范化与 Junction 解析 |
| `docs/GODOT_ARCHITECTURE.md` | 记录 MCP 通过别名连接同一 Godot 工程的运行拓扑 |

## T0167 马匹毛色与取马路径索引

| 文件 | 当前职责 |
|---|---|
| `data/horse_defs.json` | 保存经实机审计的 24 套自然马毛颜色；灰鬃为暖烟灰 |
| `data/building_fixture_layouts.json` | 为八个真实 `horse_anchor` 登记朝中央走道开放的 `pickup_center` |
| `scripts/world/StationLayoutController.gd` | 校验接近点与槽位开放侧 / 距离关系，并投影为 Marker 元数据 |
| `scripts/presentation/buildings/FormalStableArtView.gd` | 按具体 horse ID 返回其真实槽位开放侧世界接近点 |
| `scripts/systems/HorseSystem.gd` | 校验接近点 NavMesh 吸附及完整路径，驱动骑手到马旁后上马 |
| `tools/verify_t0167_horse_coats_and_stable_pickup.gd` | 审计模板色域、八槽合同及格伦骑灰鬃完成正门集结的整段物理流程 |
| `tools/capture_t0167_horse_coat_palette.gd` | 输出 24 匹实际模型 / 材质同屏毛色验收图 |

## T0166 GM 面板整理索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/GMPanel.gd` | 提供固定一键征召快捷区、五页独立滚动分组、视口内自适应摆放，并收拢重复可见入口 |
| `tools/verify_t0166_gm_panel_organization.gd` | 锁定固定按钮、页签结构、旧按钮移除与通用第一波入口 |
| `tools/verify_gm_panel.gd` | 回归完整 GM 能力，并接受面板在按钮上下或左右相邻的合法布局 |

## T0165 陨石冲击表现索引

| 文件 | 职责 |
|---|---|
| `data/piety_ability.json` | 配置斜落时长 / 高度 / 横向偏移、主体 / 弹坑半径、两段震屏与冲击表现时长 |
| `scripts/presentation/combat/MeteorPresentation.gd` | 授权岩石主体、坑洼、火焰烟尘、爆炸碎屑、空气冲击波、临时碰撞实体与 T0238 的 24 小时淡化弹坑 / 灰烬 |
| `scripts/systems/PietySystem.gd` | 推进斜落、触发表现与震屏、维护 landed / crater 诊断，并在 combat_ended 清除陨石本体 |
| `scripts/camera/CameraRig.gd` | 在现有平移 / 缩放基准上提供可衰减的确定性镜头震动 |
| `tools/verify_t0165_meteor_cinematic_presentation.gd` | 锁定尺寸、斜线起点、VFX 组件、2 秒强震、碰撞实体及战后保留未到期弹坑的生命周期 |

## T0164 建筑名称与镜头渐隐索引

| 文件 | 当前职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 生成仅含本名的 38px 正式建筑 / 门名标签，并按镜头运动实时控制文字与描边 Alpha |
| `tools/verify_t0164_building_name_label_fade.gd` | 覆盖 14 个名称、字号、静止全隐、移动与缩放快速恢复 |
| `tools/capture_t0164_building_name_fade.gd` | 输出同机位运动可见与静止全隐 D3D12 对照图 |

## T0163 陨石自由落点索引

| 文件 | 当前职责 |
|---|---|
| `data/piety_ability.json` | 保留水平地面高度与陨石数值，不再配置驿站落点矩形 |
| `scripts/systems/PietySystem.gd` | 接受建筑排除区之外的任意有限 X/Z，拒绝 NaN / Inf，归一化 Y 后继续原施法结算；T0181 的建筑空间查询见本文件顶部索引 |
| `scripts/ui/HUD.gd` | 将鼠标射线投到无限水平地面并提交落点，不再裁剪驿站范围 |
| `tools/verify_t0163_unbounded_meteor_targeting.gd` | 覆盖远距离施法、坐标保真、无效坐标及提示文案 |

## T0162 独立马匹、马槽与面板索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/horse_defs.json` | 定义 7/7/8 马槽位、唯一名称 / 毛色模板、初始马与生态数值 |
| `scripts/systems/HorseSystem.gd` | 独占马匹身份、槽位、容量、繁育、成长、分配与死亡释放；向表现层提供只读快照 |
| `scripts/presentation/characters/HorseAppearance.gd` | 将模板毛色稳定映射到马匹模型，不保存玩法状态 |
| `scripts/presentation/characters/HorseWorldView.gd` | 包装单匹真实世界马、姓名浮层和点击区，转发 `horse_clicked` |
| `scripts/presentation/buildings/FormalStableArtView.gd` | 按 `stable_slot_id` 投影马厩实体，并提供取马 / 特写所需世界位置 |
| `scripts/ui/HorsePanel.gd`、`scripts/ui/HorsePortraitViewport.gd` | 展示单马只读信息与共享正式世界实时镜头 |
| `scripts/npc/NPC.gd`、`scripts/systems/EquipmentSystem.gd` | 把被分配马的稳定 ID、模板、毛色和槽位传到取马及骑乘表现 |
| `tools/verify_t0162_horse_identity_slots_panel.gd` | 覆盖身份、槽位、满厩、成长、点击面板、实时镜头与指定坐骑链路 |
| `tools/capture_t0162_horse_panel.gd` | 生成马名、银灰马与独立面板的非 headless 验收截图 |

## T0161 GM 一键征召与八人配装索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/gm_debug_presets.json` | 保存八名 NPC 的调试兵种、主武器、精确全甲部位和四匹马对应关系；不进入正常开局档案 |
| `scripts/systems/EquipmentSystem.gd` | 加载并预检调试预设，协调征召、库存补缺、正式装备消费、清理旧配装和马匹分配，输出幂等结果快照 |
| `scripts/systems/HorseSystem.gd` | 通过显式 `debug_ensure_horses(...)` 补建配置化成年测试马；继续独占马匹实体与唯一分配 |
| `scripts/ui/GMPanel.gd` | 暴露 `RecruitAndEquipAllButton` / `recruit_equip_all`，只调用 EquipmentSystem 调试入口并显示结果 |
| `tools/verify_t0161_gm_recruit_equip_all.gd` | 从真实按钮覆盖八人征召、精确配装、四马唯一分配、重复点击和 T0160 阵型 |

## T0160 正门外集结与 GM 敌军生成区索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/station_layout.json` | 保存 `friendly_rally_v1` 的中心、方向、阵型间距与区域，以及 `gm_enemy_spawn_v1` 的独立黄框区域 / 6 列生成合同 |
| `scripts/world/StationLayoutController.gd` | 把两份站内坐标配置投影为正式世界坐标，校验空间合同，并提供支持友军出站集结的双向正门 NavigationLink |
| `scripts/systems/CombatSystem.gd` | 按实际兵种 / 数量生成近战前排、远程后排、左右骑兵翼；保留取马 reservation、接敌中断与战斗权威；GM 波次使用独立测试区 |
| `scripts/ui/GMPanel.gd` | 继续只调用既有 `debug_spawn_wave(..., spawn_near_front_gate=true)`，不保存坐标、阵型、导航或战斗权威 |
| `tools/verify_t0160_front_gate_rally_formation.gd` | 覆盖混合阵型、唯一阵位、生产导航实际到位、第 1–5 波 GM 区域与正式远端生成不变 |
| `tools/verify_combat_alarm_rally.gd`、`verify_mounted_rally_after_stable_pickup.gd`、`verify_gm_panel.gd` | 分别回归接敌打断、取马后翼侧到位与 GM 入口 / 快照 |

稳定调用关系：`station_layout spatial contract -> StationLayoutController world projection -> CombatSystem reservation/spawn -> NPC or enemy ActorMotionBody`。UI 和表现层不决定阵位到达、模式切换、敌军目标或伤害。

## T0157 可摧毁单位与关键建筑废墟索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/building_defs.json`、`data/defense_device_defs.json` | 配置建筑废墟类型 / 恢复阈值和塔防废墟类型 / 现实时间寿命 |
| `scripts/systems/BuildingSystem.gd` | 锁存建筑摧毁事实，并只在可恢复建筑达到配置 HP 阈值后解除 |
| `scripts/systems/DefenseDeviceSystem.gd` | 器械 HP、槽位释放、临时废墟快照、同槽替换与超时清理权威；提供窄 GM 摧毁接口 |
| `scripts/world/DefenseDevicePresenter.gd`、`DefenseDeviceView.gd` | 在正式槽位投影活动器械或无点击 / 无攻击的废墟，并在宿主主厅摧毁时隐藏器械 |
| `scripts/presentation/defense/FormalBallistaArtView.gd`、`FormalArrowTowerArtView.gd` | 复用正常模型材质生成断梁、倾倒武器、松脱轮和屋顶 / 平台碎件 |
| `scripts/presentation/buildings/FormalGateArtView.gd`、`FormalWarehouseArtView.gd`、`FormalMainHallArtView.gd` | 分别负责门板倒塌与碰撞切换、30% 仓库废墟恢复、不可恢复主厅坍塌表现 |
| `scripts/ui/GMPanel.gd` | 提供“摧毁首个塔防 / 塔防废墟快照”；建筑继续复用既有受损 / 修复入口 |
| `tools/verify_t0157_destructible_ruins.gd`、`capture_t0157_destructible_ruins.gd` | 自动验证所有 HP / 清理边界，并输出四张 D3D12 视觉基线 |

稳定调用关系：`Combat / GM damage -> BuildingSystem or DefenseDeviceSystem -> destruction latch / ruin snapshot -> presentation projection`。表现层不结算 HP、槽位、路径或胜负。

## T0156 全量回归索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `tools/verify_t0156_full_regression.ps1` | 串行执行 T0141–T0155、生产导航 / NPCDevLab、战斗基础与胜负、五波 / 48 敌、存档、骑乘和 GM 共 33 项回归 |
| `tools/verify_combat_flow.gd` | 用正式剑模型采样与真实接触建立首个击杀，再验证整场事件、伤员、击杀归属、模式退出和计划重评估 |
| `tools/verify_combat_pacing.gd` | 验证攻击周期数量，并锁定缺少 authored 几何样本时 miss / 零伤害；测试余额推进显式标为 fixture |
| `tools/verify_t0129c_a3a_production_navigation.gd` | 验证 live-default 门链接、导航排除 fixture、敞口铁匠铺与其余 11 座建筑真实门路径 |
| `tools/verify_t0130_d1_npc_dev_lab.gd` | NPCDevLab 全量表现回归；受击路径遵守 T0154 唯一临时伤害事件合同 |

## T0155 工作行走与紧急奔跑索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/physics_navigation.json` | 保存 NPC walk/run 基础速度、动画参考速度、步频范围与紧急模式集合 |
| `scripts/npc/NPC.gd` | 选择并热更新权威移动 profile，量测实际水平位移，向表现层转发 locomotion 合同 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd`、`NPCArtView.gd` | 播放显式 walk/run/mounted 状态，并按实际速度与参考速度调整步频；不拥有位移 |
| `tools/verify_t0155_npc_locomotion_modes.gd` | 覆盖工作、普通交谈、四类紧急路线、停止、倍速、暂停恢复及骑乘 |

稳定调用关系：`NPC profile -> locomotion class -> ActorMotionBody/legacy displacement -> measured actual speed -> presentation cadence`。

## T0154 人物小窗与受击反馈索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/ui/NPCPortraitViewport.gd`、`scripts/ui/NPCPanel.gd` | 提供透明人物小窗点击面并只转发当前有效 NPC ID，不自行判断动作或改状态 |
| `scripts/systems/NPCSystem.gd` | 权威校验 idle 小窗请求；先生成唯一伤害事件，再以其 ID 派发 / 去重受击表现并处理昏迷压制 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd`、`NPCArtView.gd` | 支持 `talk_gesture / hit_react` 两类一次性事件；HP 差量保留视觉反馈但不重复启动受击动画 |
| `scripts/systems/DialogSystem.gd`、`scripts/ui/DialogPanel.gd` | 继续拥有攻击确认和既有对话攻击入口；不成为受击动画触发源 |
| `tools/verify_t0154_portrait_and_dialogue_hit_feedback.gd` | 覆盖小窗边界、零副作用、确认取消、唯一伤害关联、刷新去重和昏迷最终表现 |

稳定调用关系：`portrait click -> NPCSystem idle validation -> temporary talk_gesture`；`attack confirmation -> NPCSystem damage event + HP settlement -> event-ID hit_react or unconscious suppression`。

## T0153 主动呼叫循环示意索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/npc_interaction_presentation.json` | 配置主动问号示意的现实秒周期，不保存请求或动作权威 |
| `scripts/systems/NPCSystem.gd` | 持有短生命周期 presentation session，按现实时间推进、每次面向当前相机并处理全部终止清理 |
| `scripts/npc/NPC.gd`、`scripts/presentation/characters/ChibiCharacterPilot.gd`、`NPCArtView.gd` | 复用 T0152 `talk_gesture` 一次性表现及事件 ID 去重，不反写 NPC 状态 |
| `tools/verify_t0153_proactive_talk_gestures.gd` | 覆盖周期、相机重采样、倍速、暂停、LLM 边界和接受 / 过期 / 状态 / 取消清理 |

稳定调用关系：`existing proactive request -> real-time presentation session -> current camera facing -> temporary talk_gesture`。session 不进入存档、计划、记忆或模型请求。

## T0152 NPC-NPC 邀请示意索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 保证发起者抵达真实交谈位后只让发起者面向目标；接受后继续作为停止原动作的唯一权威入口 |
| `scripts/systems/DialogSystem.gd` | 在邀请实际提交和接受激活两个边界触发一次性表现，并维持拒绝 / 失败会话合同 |
| `scripts/systems/NPCSystem.gd` | 绑定正式空间会话、保留接受前真实站位、校验角色 / 距离、派发并记录去重临时表现事件 |
| `scripts/npc/NPC.gd`、`scripts/presentation/characters/ChibiCharacterPilot.gd`、`NPCArtView.gd` | 将 `talk_gesture` 播放为一个 authored clip 周期，再恢复权威动作投影；不反写 profile |
| `tools/verify_t0152_formal_dialogue_gestures.gd` | 覆盖取消、到达发送、工作等待、拒绝、接受顺序、相向与重复事件 |

稳定调用关系：`ActionSystem physical arrival -> DialogSystem invitation boundary -> NPCSystem validated temporary event -> character presentation one-shot`；接受路径为 `ActionSystem stop -> spatial handoff/facing -> invitee gesture -> authoritative dialogue activation`。

## T0151 攻击距离圈索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/combat/AttackRangeIndicator.gd` | 消费选中对象的权威射程快照，生成 / 跟随淡蓝半透明无碰撞环带并处理隐藏清理 |
| `scripts/systems/CombatSystem.gd` | 向集结 / 战斗远程 NPC 输出 `final.range` 只读快照 |
| `scripts/systems/DefenseDeviceSystem.gd` | 向活动 deployment 输出含宿主倍率的 `effect.range` 只读快照 |
| `scripts/world/DefenseDeviceView.gd`、`scenes/defense_devices/DefenseDeviceView.tscn` | 为正式已部署器械提供只发选择事件的点击热区 |
| `scripts/core/EventBus.gd`、`scripts/ui/NPCPanel.gd`、`scripts/ui/BuildingPanel.gd` | 广播器械选择 / 取消选择并保持对象面板互斥 |
| `tools/verify_t0151_attack_range_indicator.gd`、`tools/capture_t0151_attack_range_indicator.gd` | 覆盖权威半径、状态边界、点击 / 跟随 / 清理、无碰撞与 Forward+ 视觉基线 |

稳定调用关系：`world click -> selection event -> CombatSystem / DefenseDeviceSystem read-only range snapshot -> AttackRangeIndicator mesh`。圆环不进入攻击、弹体或伤害链。

## T0150 敌军索敌框架索引（历史，已由 T0196 整体取代）

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/station_layout.json` | 历史五级顺序、短锁 / 重评估与近期命中配置，现行字段见 T0196 |
| `scripts/systems/CombatSystem.gd` | 历史目标层 / 反击辅助仍兼容诊断，但现行裁决只走 T0196 统一选择器 |
| `scripts/systems/NPCSystem.gd`、`scripts/systems/DefenseDeviceSystem.gd` | 通过既有状态 / deployment 快照提供攻击意图与有效来源，不保存敌军目标权威 |
| `scripts/world/ActorMotionBody.gd` | 继续执行最终 lease / wait 位置的移动，并把路径失败交回 CombatSystem 释放和重选 |
| `tools/verify_t0150_enemy_target_priority.gd` | 转发 T0196 当前统一索敌专项，防止旧断言恢复被替代合同 |

历史调用关系不再是当前权威；当前调用关系见本文件顶部 T0196。

## T0149 敌军攻击位租约索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/station_layout.json` | 配置租约 schema、安全余量、导航 / 到位容差、近战 / 远程纵深比例、容量与三类建筑正面轮廓 |
| `scripts/systems/CombatSystem.gd` | 只为塔防与三座建筑动态生成结构正面位；查询可达性并建立唯一租约，塔防 / 仓库 / 主厅满位交回索敌重选，完整城门维护候补 / 补位 |
| `scripts/systems/DefenseDeviceSystem.gd` | 在既有宿主代理目标上补充正式槽位朝向，供 CombatSystem 生成墙段外侧攻击带 |
| `scripts/world/ActorMotionBody.gd` | 继续独占租约目标点的 NavigationAgent 移动、避让、到达与失败信号；不保存占位权威 |
| `tools/verify_t0149_enemy_attack_position_leases.gd` | 覆盖 48 敌固定租约 / 城门候补、近远程、塔防 / 建筑、NPC 零租约、可达过滤、换目标、僵直 / 死亡和清理 |

稳定调用关系：`target geometry + enemy radius / weapon range -> CombatSystem candidate -> NavigationMap reachability -> unique lease -> ActorMotionBody -> T0144/T0145 physical hit`。租约只授予接近位置，不授予伤害。

## T0148 塔防宿主受击代理索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/world/StationLayoutController.gd` | 从正式围墙段、主厅支撑墙和平台 fixture 生成每槽代理身份、接近点、瞄准点与局部命中半径；建筑墙 StaticBody 增加 segment metadata |
| `scripts/systems/DefenseDeviceSystem.gd` | 将正式代理绑定到 slot / deployment，向敌军输出低位活动目标，并保持器械 HP / 销毁与宿主建筑生命周期解耦 |
| `scripts/systems/CombatSystem.gd` | 提取 segment / fixture collider identity，统一校验近战和弹体代理命中，严格路由到器械或建筑伤害权威 |
| `tools/verify_t0148_defense_device_host_proxy.gd` | 覆盖围墙同段多槽、不同墙段、主厅墙 / 平台、近战 / 弹体、建筑 HP 解耦、显式建筑伤害和摧毁清理 |

稳定调用关系：`formal slot -> host_proxy -> enemy movement/facing/aim -> physical collider identity + local region -> DefenseDeviceSystem HP`。`target_type=building` 始终旁路代理并进入 BuildingSystem。

## T0147 塔防动作与物理弹体索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/defense_device_defs.json` | 保存箭塔 / 弩炮 authored 周期、释放点、弹体速度 / 重力和共享有效射程 |
| `scripts/systems/DefenseDeviceSystem.gd` | 推进每个部署实例的权威攻击相位、选择目标、单次 release，并在物理终态后登记结果与累计伤害 |
| `scripts/systems/CombatSystem.gd` | 从正式器械 muzzle 生成通用物理弹体，按重力 / sweep / 最大水平航程推进，并在实际敌军碰撞后唯一结算 |
| `scripts/world/DefenseDevicePresenter.gd`、`scripts/world/DefenseDeviceView.gd` | 转发相位到正式器械表现，提供当前 muzzle 只读 snapshot，不拥有命中权威 |
| `scripts/presentation/defense/FormalBallistaArtView.gd`、`scripts/presentation/defense/FormalArrowTowerArtView.gd` | 按权威相位瞄准、释放和装填；生产模式关闭内部假弹体并暴露真实发射点 |
| `scripts/core/EventBus.gd` | 提供 `defense_device_action_phase` 只读表现事件 |
| `tools/verify_t0147_defense_device_physical_attack.gd` | 覆盖两种器械的释放时序、朝向、模型发射点、碰撞唯一伤害、闪避、射程和攻速缩放 |

稳定调用关系：`DefenseDeviceSystem timeline -> formal muzzle snapshot -> CombatSystem projectile -> swept collision -> existing defense damage authority -> unique terminal result`。生产表现不能自行生成伤害或飞行事实。

## T0146 敌我弓弩步骑矩阵索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 从当前正式弓 / 弩的 LoadedArrow / LoadedBolt 输出只读 release snapshot，包含模型 Transform 与步 / 骑状态 |
| `scripts/npc/NPC.gd`、`scripts/systems/NPCSystem.gd` | 转发我方正式角色的模型发射事实；包装缺失时返回不可用，不伪造身体高度发射点 |
| `scripts/presentation/characters/EnemyMountedArtView.gd` | 转发骑射 rider 的模型发射事实并锁定 mounted wrapper 来源 |
| `scripts/systems/CombatSystem.gd` | 只接受 ready 的正式发射 descriptor，记录 provenance；继续复用 T0142 时间轴、T0145 ID 与 T0143 物理碰撞伤害 |
| `tools/verify_t0146_ranged_combat_matrix.gd` | 覆盖敌我 × 弓弩 × 步骑、真实 HorseSystem、攻速缩放、朝向、模型发射点、释放零伤害和实际碰撞唯一伤害 |

稳定调用关系：`production loaded projectile -> release snapshot -> CombatSystem descriptor -> T0145 attack_id -> T0143 physics -> damage authority`。任何包装缺口在 descriptor 边界失败，禁止身体高度补射。

## T0145 权威投射物攻击事实索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 为每次敌我远程 release 生成唯一 attack ID；在伤害回调前预留 ID，固化 hit / blocked / miss fact，并拒绝重复碰撞再次结算 |
| `tools/verify_t0145_projectile_attack_id.gd` | 覆盖 release—弹体—终态—damage result 的 ID 关联、真实命中、重复回调、同 sequence 多弹体唯一性、遮挡 / 落空和清理 |
| `tools/verify_t0142_combat_animation_timeline.gd` | 在原时间轴专项中补充远程 release 的 attack sequence、attack ID 与活动弹体关联断言 |

稳定调用关系：`T0142 attack_sequence -> CombatSystem attack_id -> swept collision -> terminal fact -> existing damage authority`。ID 去重发生在伤害入口之前；表现节点不参与命中事实。

## T0144 近战模型接触索引（T0245 后固定目标权威 / 角色诊断）

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/weapon_defs.json` | 保存剑盾 / 长杆步战范围、骑战范围、扫掠半径与量测窗口 |
| `scripts/presentation/characters/CombatAnimationTiming.gd` | 保存四武器 authored 周期；近战另区分步 / 骑真实接触秒 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 输出当前正式剑刃 / 长杆头世界端点和实际播放器片段；不判断命中或扣血 |
| `scripts/npc/NPC.gd`、`scripts/systems/NPCSystem.gd`、`scripts/presentation/characters/EnemyMountedArtView.gd` | 将正式模型接触段只读转发给 CombatSystem |
| `scripts/systems/CombatSystem.gd` | 维护敌我 swing、定密度当前段 / 帧间胶囊扫掠、固定目标物理帧唯一伤害提交、步 / 骑范围与调试快照；角色伤害由 T0245 authored impact 提交 |
| `tools/verify_t0144_melee_model_contact.gd` | 量测模型前向接触范围并覆盖剑盾 / 长杆、步 / 骑、敌我、闪避、非锁定实际目标与唯一伤害 |

稳定调用关系：固定目标为 `NPCDevLab 同源正式模型端点 -> CombatSystem frame sweep -> first actual collider -> existing damage authority`；普通移动角色为 `模型端点诊断 + cycle target -> T0245 authored impact -> existing damage authority`。

## T0143 弓弩物理弹体索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `data/weapon_defs.json` | 为弓 / 弩配置正式弹体速度、重力和最长寿命；不保存命中概率或预结算伤害 |
| `scripts/systems/CombatSystem.gd` | 在 authored release 创建敌我弹体，固定释放时瞄准点，按物理子步推进抛物线、扫掠碰撞并只在合法实际命中后调用既有权威伤害入口 |
| `scripts/presentation/combat/CombatProjectileView.gd` | 显示由 CombatSystem 投影的位置 / 速度驱动的低模箭与弩矢；无碰撞体、无 HP / 伤害权威 |
| `scripts/systems/NPCSystem.gd`、`scripts/npc/NPC.gd` | 提供 NPC 身体 RID 与角色包装发射 Transform 的只读桥接，不决定弹道或命中 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd`、`EnemyMountedArtView.gd` | 提供 loaded arrow / bolt 的正式释放 Transform；正式 profile 下禁用内部预览飞箭，DevLab 预览保持独立 |
| `tools/verify_t0143_physical_ranged_projectiles.gd` | 覆盖弓 / 弩、敌我、释放零伤害、真实第一碰撞目标、目标横移落空和唯一伤害 |

稳定调用关系：`CombatAnimationTiming release -> CombatSystem projectile -> physics sweep -> actual collider identity -> existing damage authority`。表现节点不报告命中，释放时锁定的 target 也不能覆盖实际碰撞事实。

## T0142 敌我攻击动画时间轴索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/characters/CombatAnimationTiming.gd` | 四类 NPCDevLab 已验收武器动作的 authored 周期、命中 / 释放点和比例单一来源；按权威 `attack_interval` 返回缩放后周期与播放倍率 |
| `scripts/systems/CombatSystem.gd` | 敌我共同维护攻击序号、windup、impact、recovery、目标和唯一提交；在命中相位结算伤害并持续下发目标朝向，敌军存档保存周期状态 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 只读权威周期 / elapsed / sequence，重启并定位已验收步战或骑战片段，按同一倍率播放；不自行决定伤害 |
| `scripts/systems/NPCSystem.gd` | 提供正式 NPC 朝向入口，并在模式退出、重新入战或昏迷时原子清理旧攻击周期 |
| `scripts/systems/MemorySystem.gd` | 将 `winding_up_*` 运行态显示为“准备攻击敌人”，不把动态战斗状态误查为静态 Action 定义 |
| `tools/verify_t0142_combat_animation_timeline.gd` | 覆盖四武器步 / 骑 profile、攻速缩放、敌我命中边界、唯一伤害、目标朝向、粗步进与僵直中断 |

稳定调用关系：`武器 / 敌军攻速 -> CombatSystem 完整周期 -> CombatAnimationTiming 相位比例 -> ChibiCharacterPilot 播放倍率与动作位置`。伤害只由 CombatSystem 在时间轴命中点提交；远程物理碰撞将在后续任务接管释放后的最终命中事实。

## T0141 正式敌军复用 DevLab 已验收包装索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/systems/CombatSystem.gd` | 按 `enemy_waves.json` 的 `weapon_type / mount_type` 选择正式两头身步兵或骑兵包装，并通过生产 `apply_profile(...)` 投影固定武器；继续独占敌军实体、碰撞、导航、HP、攻击与胜负权威 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 在生产 profile 首次出现长杆、弓或弩时按需创建同一套已验收武器节点，并按权威战斗状态显隐；不依赖 DevLab debug 装配状态 |
| `scripts/presentation/characters/EnemyMountedArtView.gd` | Main 与 DevLab 共用的轻骑 / 骑射包装；读取骑手正式 profile，并实现 T0242 的人马原地共同阵亡表现边界 |
| `scripts/debug/NPCDevLab.gd`、`data/presentation/npc_dev_lab.json` | 继续作为同一生产包装的表现检视入口，并明确四类武器、步战 / 骑战和骑兵包装是 Main 的正式表现基准；不成为运行时服务 |
| `tools/verify_t0141_formal_enemy_dev_lab_reuse.gd` | 在 Main 中生成代表波次，覆盖 7 个敌种、固定武器唯一显隐、步兵 / 骑兵包装、debug 状态隔离、碰撞 / 选择权威和旧 ActorMesh 隐藏 |

稳定调用关系：`enemy_waves.json -> CombatSystem 权威敌军 profile -> ChibiCharacterPilot / EnemyMountedArtView`。`NPCDevLab` 仅以相同 profile 和生产包装做可视验收，正式战斗不得反向调用其 `debug_*` 接口。

## T0130-D1R14 NPC 表现基准、护甲与开发检视索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scenes/debug/NPCDevLab.tscn`、`scripts/debug/NPCDevLab.gd` | 独立 NPC 表现检视台；提供角色选择、跨友方模式 / 六槽装配、四部位实际护甲预览、动作面板、坐席 / 坐骑参照和拖拽旋转，不拥有任何玩法权威 |
| `data/presentation/npc_dev_lab.json` | 配置开发检视动作、模式、前置条件、共享友方动作及装备文字占位；8 名友方共享除主持弥撒外的工作动作 |
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 两头身角色统一表现适配器；管理四类武器、职业工具、四部位程序低模护甲、骨骼跟随、可逆头发过滤、坐姿、饮酒、步战 / 骑战动作、上下半身动画合成、握点校准与只读诊断快照 |
| `scripts/presentation/characters/MountedPresentationReference.gd` | Main 与 DevLab 共用友方 / 敌方骑乘模型相对位置、缩放和骑手偏移基准，不持有骑乘状态或伤害权威 |
| `tools/verify_t0130_d1_npc_dev_lab.gd` | 回归角色目录、共享模式 / 装配、四槽实际护甲 Mesh 与左右根、全友方工作动作与工具、四武器步战 / 骑战、坐姿 / 骑姿、关键骨轨、握点、前向和表现权威边界 |
| `tools/capture_t0130_d1r14_armor.gd` | 永久护甲视觉 QA；批量输出八名友方正面与代表角色正面 / 侧面 / 背面截图，不创建另一套表现实现 |

稳定调用关系：`NPC / Enemy wrapper 只读权威状态 -> ChibiCharacterPilot 表现投影`；`NPCDevLab -> 同一生产包装 / 共享参数`。禁止正式场景复制一套近似 Transform，也禁止 DevLab 反向成为 NPC、装备、马匹或战斗系统的数据源。

T0130-D1R13 后，`NPCDevLab.gd` 对友军返回 `_shared_loadout`，对敌军只返回该 unit 的 `default_loadout`；后者由 `enemy_waves.json` 的 `weapon_type / mount_type` 构建。所有装备 UI 和 debug 装卸入口均在敌军分支拒绝写入，骑乘敌军仍复用 `EnemyMountedArtView`，并把固定武器投影给其中的骑手包装。

T0130-D1R14 后，四个护甲槽由 `NPCDevLab` 把共享装备 ID 投影给 `ChibiCharacterPilot.debug_set_armor_preview(...)`；正式包装则由 `apply_profile(...)` 读取同名槽位。两条入口只改变同一组 BoneAttachment 表现节点的可见性，不拥有库存、减伤或战斗结算。

## T0138-R2 骑兵队形集结与 DevLab 骑姿基准索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/characters/MountedPresentationReference.gd` | Main 与 NPCDevLab 共用的骑乘表现常量；保存友方已验收马匹位置 / 缩放、骑手根偏移及敌方正式包装马匹参数，不拥有骑乘或伤害权威 |
| `scripts/systems/CombatSystem.gd` | 在默认正式世界中生成近战前排、远程后排与左右骑兵翼阵位；骑兵取马完成后恢复预留翼侧阵位移动，并以 `0.3 m` 容差提交 `rallied` |
| `scripts/npc/NPC.gd`、`scripts/presentation/characters/ChibiCharacterPilot.gd` | 正式友方骑姿读取共享基准，并在骑手平滑转向后同步马匹实际可见前向 |
| `scripts/presentation/characters/EnemyMountedArtView.gd`、`scripts/debug/NPCDevLab.gd` | Main 与 DevLab 共用敌方骑兵包装；友方 DevLab 与 Main 读取同一骑姿参数，敌我骑乘均暴露位置、缩放和前向一致性快照 |
| `tools/verify_mounted_rally_after_stable_pickup.gd` | 从真实警铃、马厩取马、上马到正式正门翼侧阵位的全程 NavMesh 回归 |

## T0139 友方 NPC 坠马昏迷表现索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/characters/ChibiCharacterPilot.gd` | 只读 `combat_mounted → unconscious` 边沿，驱动约 `0.92 s` 的侧向坠马弧线、`Death_A` 落地姿势及复苏时的落点回正；不拥有 HP、解绑或返厩权威 |
| `scripts/npc/NPC.gd` | 正式战斗骑乘使用导入马匹、同步骑手抬高姿势与马匹 Idle / Walk 表现，并在权威骑乘状态清除后立即隐藏随身马模型 |
| `tools/verify_mounted_fall_animation.gd` | 覆盖正式 Main 骑姿、导入马、受击瞬时结算、半空 / 落地相位、复苏衔接及无马昏迷隔离 |

## T0123–T0136 Quaternius 美术升级与真实空间重构索引

| 文件 / 目录 | 当前职责 |
|---|---|
| `scripts/presentation/buildings/BuildingArtView.gd`、`FormalDiningHallArtView.gd`、`FormalTavernArtView.gd`、`FormalDormitoryArtView.gd`、`FormalWorkshopArtView.gd` | T0135-P8AR7/P8AR7R 可复用封闭 `PrismMesh` 山墙及四座建筑实例；P8AR7R 进一步把工械坊导入瓦顶抬高 / 转正，并把宿舍坡度、跨度、山墙和拼缝联动重算，使两栋屋面 X/Z 四边与墙顶连续贴合；全组仍属于 Exterior 透明 / 持久阴影链，不新增碰撞、导航或玩法权威 |
| `scripts/presentation/buildings/FormalBlacksmithArtView.gd`、`tools/verify_t0135_p8ar7_building_roof_closure.gd`、`tools/capture_t0135_p8ar7_building_roofs.gd` | T0135-P8AR7/P8AR7R/R2/R3 铁匠铺冷灰蓝平顶及四座封闭山墙；专项包含四向 AABB、工械坊七段山墙—瓦面净空和正门徽牌—檐口净空；抓图脚本输出基础视图、两栋返修建筑山墙 / 长檐及工械坊同用户角度高俯视到忽略目录 `artifacts/visual_qa/` |
| `scripts/presentation/buildings/DiningKitchenWorkFX.gd`、`scripts/presentation/buildings/FormalDiningHallArtView.gd` | T0135-P8AR4/P8AR4R/R2 三个食堂灶台独立的火焰 / 食材 / 蒸汽 / 专属烟囱烟表现，以及三根四壁围合中空烟囱；Lv.2 不再给前两根烟囱追加悬浮防火帽，只读真实 `occupied_by + work_dining_hall`，第三组保持 Lv.3，零餐食与占用权威 |
| `tools/verify_t0135_p8ar4_dining_kitchen_work_fx.gd`、`tools/capture_t0135_p8ar4_dining_kitchen_work_fx.gd` | 锁定三灶—三烟囱一一映射、空置全灭、布鲁诺真实到岗仅点亮占用灶、中断全灭，并以 Lv.2 屋顶 D3D12 近景确认中空烟囱无悬浮盖件 |
| `scripts/presentation/buildings/MedievalWashBasinBuilder.gd`、`scripts/presentation/buildings/FormalDormitoryArtView.gd`、`scripts/presentation/buildings/FormalClinicArtView.gd` | T0135-P8AR5/P8AR5R 宿舍 / 诊所共享木石盥洗架；凹盆、水面、铜储水罐 / 出水嘴与毛巾完整可读，宿舍实例向床列中线收拢并与偏置壁炉保持净空，presentation-only 且零碰撞 / 导航 / 工位权威 |
| `tools/verify_t0131_p5_dormitory_building_slice.gd`、`tools/verify_t0131_p3_clinic_building_slice.gd`、`tools/capture_t0135_p8ar5_wash_basins.gd` | 锁定两洗手池结构、局部坐标、零玩法节点、宿舍十床 / Lv.2 壁炉净空、诊所桌床净空及 D3D12 近景 |
| `scripts/presentation/environment/FormalDormitoryLatrineArtView.gd`、`data/station_layout.json.service_outbuildings`、`scripts/world/StationLayoutController.gd` | T0135-P8AR6/P8AR6R 宿舍西侧并排双卫生间：两套同规格外部木石低模壳、封闭门、常驻屋顶和通风结构；不进 BuildingSystem、不含室内 / 交互 / 功能，由布局控制器从两条配置分别登记静态导航障碍 |
| `tools/verify_t0135_p8ar6_dormitory_latrine.gd`、`tools/capture_t0135_p8ar6_dormitory_latrine.gd` | 锁定双间位置 / 朝向 / 包络、`0.19 m` 结构缝、完整外部结构、零 Area / 灯 / 动画 / BuildingSystem、两个独立静态碰撞、围墙 / 宿舍 / 菜园净距及 D3D12 近景 |
| `scripts/presentation/environment/BuildingFunctionalLightController.gd` | T0135-P8A/P8AR/P8AR2/P8AR3 全建筑实体功能灯：按 `18:00–06:00` 和三类占用规则接管 15 类正式宿主、39 个实体灯具 / 40 个局部光源；关闭相机距离淡出，并从源灯具可见性同步等级解锁；铁匠铺新增 `2→3→4` 工位灯，只读时间、NPC 地点 / 睡眠与建筑表现，零玩法权威 |
| `data/presentation/environment_art.json`、`scripts/presentation/environment/CelestialCycleController.gd` | P8A 配置逐建筑既有灯名、补建灯位、模式、色温 / 范围，并由天体控制器组合功能灯子系统和快照；P8AR3 将铁匠铺基础日光收束到后炉区 `8 m / 72°` 有影光型；P6R 保留 `120 m` 四级联 / 混合 / `0.12 / 0.30 / 0.60` 分割；P6R3 生产刷新间隔为 `0`，太阳 / 月亮 Basis 随每次时间信号连续更新，正值间隔只保留为可选低频降级 |
| `tools/verify_t0135_p6r_directional_shadow_stability.gd`、`tools/verify_t0135_p6r2_shadow_direction_cadence.gd`、`tools/verify_t0135_p6r3_origin_smooth_shadows.gd` | 锁定级联配置、唯一阴影权属、暂停冻结、可选 60 秒分桶；P6R3 进一步锁定正式根 / 相机 / NPC 原点归位、旧碰撞停用、旧存档坐标迁移，以及生产 Light Basis 逐信号连续变化 |
| `scripts/presentation/buildings/FormalBlacksmithArtView.gd`、`scripts/presentation/buildings/SmithyAmbientFX.gd`、`scripts/world/StationLayoutController.gd` | T0135-P8AR3/P8AR3R2/P8AR8 后炉砌体＋全敞开四柱正面铁匠铺；正面无墙 / 门 / 门框及隐形前墙碰撞，两根 Lv.2 加固柱接地且收在平顶底面下；同轴炉体 / 烟囱、逐级实体灯、吊装透明和只读炉火合同保持不变 |
| `tools/verify_t0135_p8ar3_blacksmith_hybrid_forge.gd`、`tools/capture_t0135_p8ar8_open_front_smithy.gd` | 锁定全敞开正面、四根原承重柱、零前墙碰撞、两根加固柱屋面净空，并继续覆盖炉口 / 烟囱、三砧、灯架、真实打铁和炉火；D3D12 抓图输出铁匠铺正面近景至忽略目录 `artifacts/visual_qa/` |
| `tools/verify_t0135_p8a_building_functional_lights.gd`、`tools/capture_t0135_p8a_building_functional_lights.gd`、`tools/capture_t0135_p8ar2_progressive_open_lights.gd` | 覆盖 15 类建筑、四个时间边界、九座条件建筑、宿舍醒 / 睡、39/40 数量、露天和铁匠铺逐级灯模 / 光源同步、距离淡出关闭、实体支撑、阴影 / 雾 / 零玩法节点；P8AR2 脚本用于最大拉远及三处三级对照 QA 图 |
| `scripts/presentation/props/FormalNoticeBoardArtView.gd`、`scenes/props/NoticeBoard.tscn`、`scripts/world/NoticeBoard.gd` | T0132-P6 主厅门旁正式公告牌：Quaternius 同源木 / 瓦 / 石 PBR 的双柱遮雨告示架、三张纸页 / 钉 / 封蜡 / 徽记；FormalStationLayout 与旧兼容地图共用模型，保留独立 Area 点击、短预览及 NoticeBoardPanel 入口，不进入 BuildingSystem |
| `tools/verify_t0132_p6_formal_notice_board.gd`、`tools/capture_t0132_p6_formal_notice_board.gd` | 锁定正式主厅前左侧位置、门 / 道路净空、模型细节、零实体导航阻挡、非建筑边界、真实点击开面板，并输出主厅关系 / 公告牌近景 D3D12 画面 |
| `scripts/presentation/props/FormalMerchantWagonArtView.gd`、`scenes/characters/MerchantChibiArtView.tscn` | T0132-P7/P7R 商队表现；生成唯一的双马四轮正交板车、满载分层货物、主篷与车夫前檐、随速滚轮、双马 Walk / Idle，并用两头身 ShopKeeper 的左右 Hand socket 动态连接两条缰绳；不持有报价或库存权威 |
| `tools/verify_t0132_p7_formal_merchant_wagon.gd`、`tools/verify_t0132_p7r2_merchant_rear_gate_dock.gd`、`tools/capture_t0132_p7_formal_merchant_wagon.gd`、`tools/capture_t0132_p7_formal_merchant_wagon_dock.gd` | 锁定双马 / 四轮两轴 / 车斗 / 两头身车夫 / 双手缰绳 / 满载密度，以及两片弧形帆布、五道篷弓、八根侧柱、前檐斜撑、交易标记净空、门宽和表现权威；P7R2 另以独立物理场景锁定六点商路的近门停车位、马组前缘—后门净距、自动开门与原路离场；输出前侧后、车夫近景及正式停靠 D3D12 画面 |
| `scripts/presentation/environment/FormalRoadNetworkArtView.gd` | T0132-P5 正式道路表现：只读消费 `station_layout_v2.roads` 的 42 段端点 / 宽度 / 分类，生成低饱和羽化泥肩、压实路芯、断续双车辙、嵌地边石与 31 组交汇补片；零碰撞、零导航权重、presentation-only |
| `tools/verify_t0132_p5_formal_roads.gd`、`tools/capture_t0132_p5_formal_roads.gd` | 锁定 42 段道路合同、分类、端点 / 宽度、细节密度、交汇收口、零碰撞 / 零导航权威和 Main 实装，并输出全站 / 广场 D3D12 画面 |
| `scripts/presentation/defense/FormalMainHallDefensePlatformArtView.gd`、`scenes/defense_devices/FormalMainHallDefensePlatformArtView.tscn` | T0132-P4b 主厅四槽统一木构平台：3.6×3.6 m WoodTrim 承台 / 甲板 / 护栏 / 垛口 / 短支柱 / 斜撑，保持原锚点与碰撞，presentation-only |
| `scripts/presentation/defense/FormalArrowTowerArtView.gd`、`scenes/defense_devices/FormalArrowTowerArtView.tscn` | T0132-P4b/P4bR 正式箭塔：Quaternius 木 / 铁 / 圆瓦 PBR 塔架、闭合人字顶、贴合屋脊、护板、储箭架、转台、动态弓弦、飞行箭和攻速同步补箭，presentation-only |
| `tools/verify_t0132_p4b_arrow_tower_art_slice.gd`、`tools/capture_t0132_p4b_arrow_tower_visuals.gd` | 锁定主厅木台替换、四槽锚点、箭塔双平台包络、PBR 结构、无假操作员、待机 / 发射 / 重装循环，并输出独立与真实主厅安装 D3D12 画面 |
| `scripts/presentation/buildings/FormalWarehouseArtView.gd` | T0132-P2/P2R/P2R2 仓库三级正式表现：16×16 m 地块内的封闭石基木构货栈，单一连续主屋脊与侧仓 / 高仓同族瓦面统一使用保留纹理的低饱和烟熏灰褐配色；逐级投影 `5→6→7` 分类储藏 fixture / 碰撞，分类表现不镜像实时库存，presentation-only |
| `tools/verify_t0132_p2_warehouse_building_slice.gd` | 锁定仓库封闭贴图体量、12 个立面模块、唯一完整主屋顶且禁止重复屋脊模块、14×14 m 包络、`5→6→7` fixture / 碰撞、零工位、常显屋顶、轻重损伤 / 修复、镜头点击及 BuildingSystem / ResourceSystem 权威不变 |
| `scripts/presentation/buildings/FormalMainHallArtView.gd` | T0132-P1/P1R3/P1R4/P1R5 主厅六级正式表现：24×20 m 中央指挥厅，封闭 PBR 实体、连续承重屋面 / 女儿墙 / 垛口、50 个原生墙门模块和不侵占四角平台的紧凑瓦顶；Lv.2 正面不再有挡窗短柱，Lv.4 使用屋脊守备旗，Lv.6 门楼基座改用贴图石材，逐级投影保持 presentation-only |
| `tools/verify_t0132_p1_main_hall_building_slice.gd` | 锁定主厅六级层、器械容量、fixture / 碰撞累计、22×18 m 包络、不透明屋顶、受损 / 修复、镜头点击及 BuildingSystem 权威不变；P1R3 额外验证封闭贴图体量、四个 3.6×3.6 m 平台上方无遮挡、运行态槽位与平台世界锚点一致，并真实部署一座 Lv.1 箭塔 |
| `scripts/presentation/buildings/FormalStableArtView.gd` | T0131-P9/T0138 正式马厩：16×16 m 露天马院及逐级 fixture / 碰撞 / 照料位 / 马锚；只读显示 HorseSystem 的真实在厩马，并按权威世界位置投影会合 / 返厩中的马，骑乘 / 阵亡时隐藏，presentation-only |
| `tools/verify_t0131_p9_stable_building_slice.gd` | 锁定马厩等级容量、fixture / 碰撞、八个马锚、逐锚点完整马体顶棚覆盖、真实马匹映射、16×16 m 地块、中央通道、宽自动低门、露天选择优先、遮棚透明与 BuildingSystem 权威不变 |
| `scripts/presentation/buildings/FormalTrainingGroundArtView.gd` | T0131-P8 正式训练场：16×18 m 地块内的露天夯土军训院、低石基木栅、自动低训练门、教官遮棚及维护 / 饮水 / 盾墙 / 挡箭网 / 护具背景；逐级投影 `1+2→1+3→2+4` 权威位置和 `6→8→10` fixture / 碰撞，棚顶 70→58 m 渐隐，开放 NPC 点击优先，presentation-only |
| `tools/verify_t0131_p8_training_ground_building_slice.gd` | 锁定训练场 `6→8→10` fixture / 碰撞、`1+2→1+3→2+4` 容量、六块 3×3 m 动作净空、等级增量绑定、16×18 m 地块、低矮自动门、露天选择优先与三组棚顶透明 |
| `scripts/presentation/buildings/FormalGardenArtView.gd` | T0131-P7 正式菜园：14×14 m 露天深土田园、低石基木篱、自动低园门、东侧农具棚与种子 / 药草 / 稻草人背景；Lv.2 灌溉育苗不扩容，Lv.3 才同步第三田畦、支路、支架与分拣；棚顶 70→58 m 渐隐，开放 NPC 点击优先，presentation-only |
| `tools/verify_t0131_p7_garden_building_slice.gd` | 锁定菜园 `6→8→9` fixture、`10→12→15` 碰撞部件、`2→2→3` 耕作位、第三地块语义绑定、14×14 m 包络、低矮自动园门、露天选择优先与棚顶透明 |
| `scripts/presentation/buildings/FormalTavernArtView.gd` | T0131-P6/P6R 正式酒窖：约 12×10 m 半石砌发酵作坊、深酒红低坡屋顶、桶箍葡萄藤徽记与瓶装 / 清洗 / 制桶背景；装饰储藏桶 `6→11→14`，Lv.2 增熟成冷却 / 管线但不扩容，Lv.3 才同步第三发酵位与装卸扩充；70→58 m 全外壳渐隐及自动门，presentation-only |
| `tools/verify_t0131_p6_tavern_building_slice.gd` | 锁定酒窖 `4→5→6` fixture、`2→2→3` 酿酒位、装饰桶 `6→11→14`、非库存元数据、地块包络、第三工位语义绑定、自动门、升级透明与空地点击回退 |
| `scripts/ui/NPCPortraitViewport.gd`、`scripts/ui/NPCPanel.gd` | T0134-P1/P1R/P1R2/P1R3 NPCPanel 左上实时人物框：共享 Main World3D 的独立副镜头，只读跟随真实 NPC 正面 / 动作；与面板同步启停，收至信息列约 52% 高、190–210 px 宽并采用 3.9 m / 40° 全身构图；正常状态无标题或地点冗余文字；排除主镜头渐隐建筑壳层并只看人物框不透明壳层 |
| `scripts/npc/NPC.gd`、`scripts/systems/NPCSystem.gd`、`scripts/presentation/characters/ChibiCharacterPilot.gd`、`scripts/presentation/characters/NPCArtView.gd` | 为实时人物框提供窄只读实体快照、中文地点补全和两类表现包装的实际可见 forward；T0130-P5/P7R 把 `sleeping_supine / lying_supine / seated_study` 只读投影给支持姿态动画的 Chibi 包装，旧包装保留卧姿父级旋转；不修改 NPC 权威状态 |
| `tools/verify_t0134_p1_npc_portrait_view.gd` | 验证同一 World3D / 同一 NPC 实体、正面全身镜头、目标切换、停渲染、1280×720 / 1920×1080 布局、两台相机建筑壳层互斥、渐隐建筑的不透明人物框副本，以及主镜头与 profile 零修改 |
| `docs/SCENE_SPACE_AND_VISUAL_PLAN.md` | T0129A 起长期维护的画面与空间规格源；T0135-P0R 已补充城内七层地表、有机广场、自然地形 / 可见美术 / 物理边界分层、右侧 `X[120,350+]` 三层山脉、河槽、敌军林下显现、分块散布与连续日月轨道合同 |
| `docs/ART_DIRECTION.md` | 统一低模风格、镜头距离屋顶透明、建筑 / 角色 / 动画 / 战斗 / UI 最低标准；T0135-P0R 冻结自然场景混合管线、分区资源语言、固定季节的太阳 / 月亮东升西落和低配灯光基线 |
| `docs/ART_PIPELINE.md` | Quaternius 资产来源、免费版先行、许可审计、源文件隔离、GLB 导入、命名、建筑 / 角色包装合同和逐步执行入口 |
| `docs/ART_BASELINE.md` | T0125 比例 / 导入 / 性能基线、T0126 建筑追加验证与 T0128 格伦骨骼装配 / 动画别名 / 网格告警结论 |
| `docs/QUATERNIUS_ASSET_INVENTORY.md` | 六个免费 Standard 包的 ZIP 哈希、实际模型 / 动画 / 纹理 / 骨骼 / 碰撞范围、候选用途与付费缺口 |
| `assets/THIRD_PARTY_ASSETS.md` | 实际进入项目和导出包的第三方资产、来源、许可证、用途与修改台账 |
| `art_source/` | 原始下载、六个已解包 Standard 包、许可证和 DCC 工作文件；根 `.gdignore` 阻止 Godot 导入，原始重复二进制由 `.gitignore` 排除 |
| `art_source/manifests/quaternius_free_standard_inventory.json` | 可复核的六包 SHA-256、文件格式、glTF / GLB 网格、材质、65 关节皮肤、动画和碰撞 / Godot 工程探测结果 |
| `art_source/licenses/CC0-1.0-legalcode.txt`、`QUATERNIUS_CC0_SOURCE_RECORD.md` | CC0 1.0 法律文本及逐包官方来源、免费档位与包内许可证路径 |
| `tools/download_quaternius_free.ps1` | 从官方 itch.io 免费入口解析 Standard 上传；支持 `127.0.0.1:7897` 代理、分片重试、合并和 ZIP 校验 |
| `tools/inventory_quaternius_assets.py` | 对本机隔离包计算 SHA-256 并重建机器资产清单 |
| `tools/pack_gltf_to_glb.py` | 把隔离 glTF 网格 / 骨骼打包为 GLB，可用 `--external-images` 输出稳定命名的外置贴图、用 `--external-image-prefix` 复用同材质纹理，并兼容错误 `_png.png` URI |
| `tools/verify_t0125_art_sandbox.gd` | 验证六包样本、比例配置、Mesh / Skeleton / AnimationPlayer 与 `Farm_Harvest` 自动播放 |
| `tools/verify_t0126_roof_visibility.gd` | 验证两座建筑注册、节点合同、逐建筑阈值、近 / 中 / 远 / 反向透明、持久 shadows-only 阴影与碰撞状态不变 |
| `tools/verify_t0127_blacksmith_interior_authority.gd` | 验证铁匠铺门外预留、穿门地点提交、工位占用 / active、真实退出、前 / 后门中断、昏迷及升级封闭清理 |
| `tools/verify_t0127a_paused_debug_movement.gd` | 验证暂停中新 GM 移动原子拒绝与明确提示、途中暂停 / 恢复，以及普通建筑和铁匠铺恢复后的坐标、地点人员和事件提交 |
| `tools/verify_t0128_character_animation.gd` | 验证格伦旧装配、共享状态 / 挂点 / 反馈，以及当前托马 / 布鲁诺 / 伊沃 / 马塞尔 / 艾达 / 莉娜 / 欧文 Synty 职业包装和未知角色 legacy fallback |
| `tools/verify_t0128_character_authority_integration.gd` | 通过真实 ActionSystem / NPCSystem 验证移动穿门、forge_01 占用、work 动画、昏迷释放和复苏起身同步 |
| `tools/verify_t0128a_character_motion_loop.gd` | 验证 Quaternius 180°源朝向修正、两个世界移动方向与 2.5 秒工作动画在约 6 秒内多次回卷 |
| `tools/inspect_t0130_character_assets.gd` | 输出 Synty / KayKit 导入场景树、骨名、AABB、Skin、材质与动画清单，供确定性重定向映射审计 |
| `tools/verify_t0130_p0_chibi_character_pilot.gd` | 验证双角色 ready、100+ 动作库、18 状态映射、Capsule 选择体、装备挂点、源骨架动画与目标骨架跨状态真实姿态变化 |
| `tools/verify_t0130_p0_48_enemy_performance.gd` | 实例化 48 名剑盾试片，验证共享 AnimationLibrary、状态切换、初始化 / 180 帧 CPU 观测与静态内存增量 |
| `tools/verify_t0130_p0_main_preview.gd` | 加载完整 Main，验证 presentation-only 试片启停、正式根层级、GM 按钮、双角色 ready、关闭清理与 NPC 权威集合不变；可选 D3D12 截图 |
| `scripts/presentation/buildings/BuildingAutoDoor.gd` | T0131-P1D/P7 可复用双扇门 / 低园门：监测碰撞层 2 的真实 CharacterBody 接近，平滑开启、清空延迟关闭；`leaf_visual_height` 允许低矮门叶而保持净通行合同，无阻挡碰撞，不写地点 / 工位 / 行动 / 导航权威 |
| `scripts/presentation/buildings/FormalBlacksmithArtView.gd` | T0129/T0131/T0135-P8AR3/P8AR7/P8AR8 正式地图铁匠铺：14×12 m 后炉砌体＋全敞开四柱正面锻造区，冷灰蓝平顶、同轴炉口 / 烟道 / 烟囱、三级丰富度与 `2→3→4` 实体灯；附属棚收在 16×16 m 地块内，吊装梁走屋顶透明链，正面不再设置墙、门或专属门框 |
| `tools/verify_t0129_blacksmith_art_slice.gd` | 只验正式铁匠铺的 footprint、三级 2→2→3 工位 / 资产增量、烟道、两侧附属棚地块边界与主屋面净空、升级梁架近 / 远透明、NPC / 建筑点击优先级、正式碰撞 / 导航、格伦 / 敌人反馈和临时 UI 主题 |
| `scripts/presentation/buildings/FormalWorkshopArtView.gd` | T0131-P1/P1R/P1D 正式工械坊：12×12 m Quaternius 外壳 / 低坡冷色屋顶 / 丰富室内工程杂物、Lv.2 收料吊臂、Lv.3 西侧有顶装配湾、3→6→7 fixture 视觉与碰撞、2→2→3 权威工位投影、升级梁架透明及 2.08 m 净口自动双扇门 |
| `scripts/presentation/buildings/FormalChapelArtView.gd` | T0131-P2R3 正式小教堂：12×12 m 暖灰石中殿、31° 主厅同款 `#65717a` 冷灰蓝板岩顶、山墙 / 尖拱门 / 圆窗 / 侧墙狭窗 / 圣坛端；主屋面十四根横向拼缝贴合坡面，Lv.2 恢复五根短金色屋脊饰杆并保留钟塔 / 彩窗 / 扶壁 / 礼仪陈设；70→58 m 外壳渐隐及 2.08 m 净口自动门；只投影表现，不拥有容量或礼拜结算 |
| `tools/verify_t0131_p2_chapel_building_slice.gd` | 覆盖小教堂中世纪轮廓、31° 坡度 / `#65717a` 色板、十四根拼缝左右各七且方向 / 厚度贴面、五根短金色饰杆、两级 11→16 fixture 与碰撞、固定 1+10 容量、高位钟塔、透明与自动门合同 |
| `scripts/presentation/buildings/FormalClinicArtView.gd` | T0131-P3/P3R 正式小诊所：12×12 m 暖象牙灰泥 / 鼠尾草绿木构、程序化宽缓四坡屋面与玻璃采光气楼、奶油护理雨棚、百叶窗、药草花箱和叶片药臼徽记；保留沿墙药材 / 清洗 / 布草 / 隐私帘陈设，逐级投影 6→7→8 fixture / 碰撞、固定 2 医生桌与 2→3→4 病床；70→58 m 全外壳渐隐及 2.08 m 自动门，presentation-only |
| `tools/verify_t0131_p3_clinic_building_slice.gd` | 覆盖小诊所治愈色板、四坡轮廓 / 采光气楼 / 护理入口 / 药草景观及通用工坊瓦顶缺席，并继续覆盖三级增量、固定 2 医生桌 / 2→3→4 病床、6→7→8 fixture 与碰撞、14×14 m 地块边界、完整透明链、空地点击回退和莉娜触发自动门 |
| `scripts/presentation/buildings/FormalDiningHallArtView.gd` | T0131-P4/P4R 正式食堂：约 14×12 m 横向暖赭灰泥 / 深橡木公共饭堂、低缓陶瓦屋顶、后厨成组烟囱、汤勺餐盘徽记及储粮 / 餐具 / 洗涤 / 柴薪陈设；逐级投影 14→14→15 fixture / 碰撞、2→2→3 灶台与固定 10 用餐席；P4R 将 Lv.2 / Lv.3 升级柜台迁到正面墙左右横排，避免与基础碗橱重叠；70→58 m 全外壳渐隐及 2.08 m 自动门，presentation-only |
| `tools/verify_t0131_p4_dining_hall_building_slice.gd` | 覆盖食堂三级容量 / fixture、正式厚木长桌替换、饭堂轮廓与职业陈设、第三灶—排烟罩—烟囱对应、升级柜台—基础碗橱零重叠及门前净空、16×14 m 地块边界、完整透明链、空地点击回退及布鲁诺触发自动门 |
| `scripts/presentation/buildings/FormalDormitoryArtView.gd` | T0131-P5/T0239 正式宿舍：约 14×13 m 暖灰泥 / 深木五段集体长屋、深酒红低坡屋顶、五个通风帽及月牙枕头徽记；十张固定床保留，床位 1–8 各生成一座大个人衣柜，9–10 保持预留；布草 / 洗漱 / 夜灯及 Lv.2 壁炉烟道、保温、修补与备柴不变；70→58 m 全外壳渐隐及 2.08 m 自动门，presentation-only |
| `tools/verify_t0131_p5_dormitory_building_slice.gd`、`tools/verify_t0239_dormitory_personal_wardrobes.gd` | 覆盖宿舍两级固定 10 床 / 8 归属 / 2 未来预留、fixture 与碰撞恒定、八座个人衣柜结构 / 映射 / 零权威、装饰—床体零相交、16×14 m 地块、壁炉烟道对齐、透明点击及艾达触发自动门 |
| `tools/verify_t0131_p1_workshop_building_slice.gd` | 覆盖工械坊三级外壳 / fixture / 碰撞、BuildingSystem 等级信号、正式路线、屋顶 + 墙体 + 升级梁架透明、主 / 附属屋面净空、14×14 m 地块边界、欧文点击优先和权威边界 |
| `tools/verify_t0131_p1d_building_auto_doors.gd` | 验证铁匠铺全敞开正面零门 / 零前墙碰撞且保留四柱，并以欧文真实 CharacterBody 继续验证工械坊门洞净宽高、接近开门、开启后中心净空、离开关门；铁匠铺吊灯—主屋面 AABB 净空继续覆盖 |
| `tools/capture_t0129_blacksmith_visuals.gd` | D3D12 实机逐级抓取正式铁匠铺 Lv.1–3 远景完整外壳与近景透明室内至 `artifacts/visual_qa/` |
| `tools/verify_t0129a_station_spatial_sandbox.gd` | 交叉读取空间配置、建筑 / 器械 / 波次权威数据，验证地形、12 地块、80 个最高等级占地、21:9 四角、48 人混编物理包络全路线、长逃离五轮窗口和地图边缘完成合同 |
| `assets/3d/quaternius/` | 截至 A3b12R 已筛选 54 GLB + 75 外置 PNG；含建筑 / 角色 / 动画基线、逐建筑家具样板、主厅组合，以及仓库木网格墙 / 坡屋顶 / 货运车 / 分类储藏道具，GLB / PNG 使用 Git LFS，贴图上限 2K |
| `assets/3d/synty/t0130_pilot/`、`assets/3d/kaykit/animations/rig_medium/` | T0130-P0–P8 运行时筛选：Synty 9 角色 FBX + 4 装备 / 职业道具 FBX + 18 调色板 PNG，KayKit Medium Rig 8 个 CC0 动作 GLB；P5–P8 未采用候选副本已移回隔离工作区，完整商业 / 免费源包均留在忽略的 `art_source/` |
| `assets/2d/`、`assets/materials/`、`assets/vfx/`、`assets/audio/` | UI / 头像 / 贴花、材质来源、VFX 来源与音频运行时资产 |
| `scenes/art/ArtSandbox.tscn` | 独立六包样本、两座 BuildingArtView、屋顶渐隐对照、2 m 网格、灯光、比例尺、动画与性能验证场景 |
| `scenes/art/StationSpatialSandbox.tscn` | T0129A v0.9 独立全站空间灰盒；在 v0.7 地形 / 地块 / 容量基础上接入 48 敌混编行军与长逃离压力体，不接入 Main 或权威系统 |
| `scenes/buildings/BuildingArtView.tscn` | Exterior / Roof / Interior / Upgrade / Marker / Trigger / Navigation / Collision / Click / VFX 合同；T0129 补齐炉膛、风箱、工具 / 材料、三级升级增量和三工位门槛，并按用户反馈采用低坡冷灰蓝屋顶、灰紫主体及越过屋脊的炉膛烟囱；NavigationRegion3D 现有室内 + 门口漏斗 NavMesh |
| `scenes/characters/GlenArtView.tscn` | 首个正式 NPC 外观：Quaternius 基础体 / 农民服 / 短发 / UAL2 rig、180°源朝向修正、AnimationTree、六挂点、低模锤子、血粒子与受控倒地接口；同时作为一名敌人样片基体 |
| `scenes/characters/GlenChibiPilot.tscn`、`EnemySwordShieldChibiPilot.tscn`、`GlenChibiArtView.tscn`、`TomaChibiArtView.tscn`、`BrunoChibiArtView.tscn`、`IvoChibiArtView.tscn`、`MarcelChibiArtView.tscn`、`AdaChibiArtView.tscn`、`LinaChibiArtView.tscn`、`OwenChibiArtView.tscn`、`EnemySwordShieldChibiArtView.tscn`、`scripts/presentation/characters/ChibiCharacterPilot.gd` | T0130-P0–P8/D1R7/P1R2/P1R4 两头身角色家族：Synty 可见模型、KayKit 隐藏驱动骨架、Godot 4.6 人形实时重定向、共享动画库、18 状态与六挂点；8 名初始 NPC 分别配置职业与战斗表现，步行剑盾敌人同样接入。D1R7 统一校准剑盾握持；P1R2 将格伦非打铁锤改为髋部横挂，P1R4 依据真实网格分区把工作握点移到木柄后段并锁定手后柄尾与锤头分离。开发 / 正式包装不复制 Transform；作者材质、父级碰撞和 P1R 可见层 180° 源轴修正保持不变 |
| `scenes/art/ChibiCharacterSandbox.tscn`、`scripts/presentation/ChibiCharacterSandbox.gd` | T0130-P0/P2–P8 八组动作自动轮播与按键切换沙盒，现并排显示 8 名初始 NPC 和剑盾敌人；第 4 / 6 组检查各职业工作与生活 / 治疗 / 训练，支持指定动作相位、艾达 / 伊沃原生脸、马塞尔头型、莉娜与欧文单人近景截图；不连接权威系统 |
| `project.godot`、`scenes/debug/NPCDevLab.tscn`、`scripts/debug/NPCDevLab.gd`、`scripts/ui/EquipmentSilhouette.gd`、`data/presentation/npc_dev_lab.json` | T0130-D1/D1R/D1R4/D1R6/D1R8/D1R9/T0139-D1/D2 单角色开发检视场景：配置驱动选择 8 名 NPC 与全部去重敌种，以跨角色共享的工作 / 战斗模式和六槽临时装配预览装备、坐骑并支持拖转；装配自动进入战斗，敌军固定战斗。敌方骑兵 / 骑射兵复用 Main 的 `EnemyMountedArtView`；我方装马后可以正式 `combat_mounted → unconscious` 边沿重复检查 `mounted_fall / Death_A`。全部状态为场景本地，不写正式库存、朝向、伤害或玩法权威 |
| `scripts/presentation/characters/EnemyMountedArtView.gd` | T0139/T0242 正式敌方骑兵表现包装：组合正式 Synty 骑手与 Quaternius 马匹，投影骑乘移动 / 攻击；敌方马无独立 HP，人马阵亡时分别播放 `Death_A / Death` 并原地共同延时释放。Main 与 NPCDevLab 共用同一脚本 |
| `tools/verify_t0130_d1_npc_dev_lab.gd` | T0130-D1/D1R/D1R4/D1R8/D1R9/T0139-D1/T0242 回归：覆盖友敌目录、共享模式 / 六槽装卸、动作切换、剑盾 / 友方临时坐骑、敌军战斗锁定、拖转与坐姿，并锁定敌方骑兵正式包装、无马 HP 和专属共同阵亡入口 |
| `tools/verify_npc_dev_lab_enemy_mounted_acceptance.gd` | T0139-D1/T0242 专项：覆盖骑兵与骑射兵正式包装、待机 / 移动 / 攻击 / 受击、`Death_A / Death` 原地同步、共同清理、点击动作重新生成及普通敌军隔离 |
| `tools/verify_npc_dev_lab_friendly_mounted_fall.gd` | T0139-D2 专项：覆盖我方坐骑前置、正式 `mounted_fall / Death_A` 边沿、中段侧向离鞍、马匹 Gallop 参照、重播 / 切换重置和敌方隔离 |
| `tools/verify_t0242_enemy_mounted_shared_defeat.gd` | T0242 Main 专项：锁定敌方伤害只扣单位 HP、骑兵阵亡立即退出权威战斗、人马原地双死亡动画、马匹末帧保持、共同释放及骑射包装合同 |
| `tools/verify_t0130_d1r2_sword_shield_alignment.gd` | T0130-D1R7 剑盾几何专项：覆盖开发预览、艾达、欧文与剑盾敌军共用左右手挂点、局部 Transform、剑柄 / 剑尖距离、盾面朝向、手部在盾背后的有符号净空、横向漂移、竖直轴及攻击状态不漂移 |
| `scenes/characters/TomaArtView.tscn` | A5-P5a 的 Quaternius / UAL2 托马历史回退外观；P2 后生产映射已切换 `TomaChibiArtView.tscn`，本场景保留兼容而不再是当前托马外观 |
| `scenes/characters/BrunoArtView.tscn` | A5-P5d 的 Quaternius / UAL2 布鲁诺历史回退外观；P3 后生产映射已切换 `BrunoChibiArtView.tscn`，本场景保留兼容而不再是当前布鲁诺外观 |
| `scenes/characters/IvoArtView.tscn` | A5-P5e 的 Quaternius / UAL2 伊沃历史回退外观；P4 后生产映射已切换 `IvoChibiArtView.tscn`，本场景保留兼容而不再是当前伊沃外观 |
| `scenes/characters/LinaArtView.tscn` | A5-P5g 莉娜低配正式外观：继承 Quaternius / UAL2 通用装配，使用青灰医护配色、棕红发并禁用铁锤；循环坐诊只读 `work_clinic_doctor` 权威状态 |
| `scenes/characters/AdaArtView.tscn` | A5-P5h 艾达 Quaternius / UAL2 历史回退外观；T0130-P5 后生产映射已切换 `AdaChibiArtView.tscn`，本场景保留兼容而不再是当前艾达外观 |
| `scenes/environment/FormalEnvironmentArtView.tscn` | T0135 正式环境表现根；当前组合 P1R2 城内地表 / 杂物、P2 河谷、P3 东侧山脉、P4R 全周渐变密林、P5 五区自然接触层、P6 日月方向光与 P7 动态环境 / 室内可读；不持有导航、时间或战斗权威 |
| `scripts/presentation/environment/FormalGroundSurfaceArtView.gd` | 环境组合控制器：保留 P1R2 城内连续深草、排水、草石和功能杂物，并组合 P2–P7 地形、森林、自然散布、天体与动态环境控制器；独立广场 / 门口贴片均为零，不生成第二套玩法权威 |
| `scripts/presentation/environment/FormalStationDetailArtView.gd` | P1R2 驿站生活层：从纯表现配置生成仓储、畜养、餐饮、工艺、公共服务、收获与训练 10 个功能杂物组 / 42 个 Quaternius 道具；剥离导入碰撞，不持有导航、交互或资源权威 |
| `scripts/presentation/environment/FormalTerrainArtView.gd` | T0135-P2/P3 正式地形：生成断开两岸、四级河坡、河床 / 动态水面，以及近中远三层各 400 三角的连续东侧山脉与无碰撞岩石破形；只读环境配置和正式地形尺寸，不持有碰撞或导航权威 |
| `scripts/presentation/environment/FormalForestArtView.gd` | T0135-P4R 全周渐变密林：369 个 `40 m` 区块生成 7393 棵统一圆锥低模针叶树与 4076 丛灌木；按围墙距离、河槽 / 河岸和山体分别控制密度，补齐中央侧林，保留敌军显现林幕及商旅 / 逃离峡口，零逐树碰撞 |
| `scripts/presentation/environment/FormalEnvironmentScatterView.gd` | T0135-P5 河岸 / 山脚 / 林下 / 道路边缘 / 城内空地五区自然散布，合批生成 4375 个低模草、蕨、灌木、岩石和 81 段湿痕 / 苔藓 / 泥肩过渡；统一排除河槽、道路核心、建筑地块、公共地点与正式路线，零玩法权威 |
| `scripts/presentation/environment/CelestialCycleController.gd` | P6/P7/P7R2–R4 只读绝对游戏时间，连续计算日月轨道、环境与薄雾；优先绑定正式 BuildingArtView，消费屋顶显露信号，以 `06:00 → 12:00 → 18:00` 亮度 / 色温曲线驱动七座建筑各一盏屋檐下有影补光，不维护第二套时钟或玩法权威 |
| `data/presentation/environment_art.json` | `environment_art_v1` 环境表现配置；包含 P1R2–P5 自然层、P6 日月、P7 环境锚点 / 雾及 P7R2–R4 室内日照亮度、色温、柔和覆盖与遮光参数，始终是纯表现配置 |
| `assets/3d/quaternius/nature/ground_detail/` | T0135-P1 从 Stylized Nature MegaKit 筛入的 2 个卵石、2 个短草和 1 个三叶草 GLB 及 3 张共享纹理；实例均剥离碰撞并关闭阴影，不作为资源、障碍或导航来源 |
| `tools/verify_t0135_p1_formal_ground_surface.gd`、`tools/capture_t0135_p1_ground_surface.gd` | P1R2 专项锁定零可见 ReservedLot、零独立 Plaza / DoorWear、草石密度、10 个功能杂物组、权威边界和 42 段道路不变，并生成 D3D12 全站 / 广场 / 东西工作区 / 后部服务区 QA 图 |
| `tools/verify_t0135_p2_formal_river_valley.gd`、`tools/capture_t0135_p2_river_valley.gd` | P2 专项锁定 `24–34 m` 河槽、`7–11 m` 水面、`-1.2 m` 高差、两岸断开、旧盒隐藏、8 段河岸碰撞不变，并生成全景 / 中段 / 南北河段 D3D12 QA 图 |
| `tools/verify_t0135_p3_east_mountain.gd`、`tools/capture_t0135_p3_east_mountain.gd` | P3 专项锁定三层 X / 高度 / 全长包络、旧岩条隐藏、4 段山脊碰撞不变和零新增玩法权威，并生成全景 / 近景 / 低角度 / 南北山段 D3D12 QA 图 |
| `tools/verify_t0135_p6_celestial_cycle.gd`、`tools/capture_t0135_p6_celestial_cycle.gd` | P6 专项锁定六时点方位 / 高度 / 能量、连续过渡、单主阴影、暂停冻结和旧光退役，并生成同机位六时点 D3D12 QA 图 |
| `tools/verify_t0135_p7_environment_readability.gd`、`tools/capture_t0135_p7_environment_readability.gd` | P7/P7R4 专项锁定连续环境相位、昼夜亮度下限、唯一 WorldEnvironment、七座 / 7 盏室内补光、屋顶联动与近景雾衰减，并生成昼 / 夕 / 夜全站及昼夜诊所、铁匠铺 QA 图 |
| `tools/verify_t0135_p7r_persistent_shell_shadows.gd` | P7R 专项锁定七座封闭建筑近 / 远透明、Lv.3 升级显隐、太阳 / 月亮持久阴影、shadows-only 代理与可见 Mesh 零重复投影；复用 P7 昼夜诊所抓图验收实体阴影 |
| `tools/verify_t0135_p7r2_interior_daylight_curve.gd` | P7R2 专项锁定 `00/06/07/09/12/15/17/18/20` 点室内倍率、早升午峰晚降、对称与秒级连续、七座统一联动及封闭屋顶零漏光 |
| `tools/verify_t0135_p7r3_interior_daylight_tint.gd` | P7R3/R4 专项锁定午夜暖色、上午 / 下午过渡、正午室外日光匹配、七盏中央宽角低衰减有影覆盖、秒级连续与封闭零漏光 |
| `tools/verify_t0135_p7r4_contained_interior_lighting.gd` | P7R4 专项锁定七座各一盏正式可见灯、铁匠铺正式路径 / 能量 / 色温、灯位低于屋面、屋顶与外墙持久遮光、体积雾零贡献及封闭零活动灯 |
| `tools/verify_t0135_p4_dense_forests.gd`、`tools/capture_t0135_p4_dense_forests.gd` | P4/P4R 专项锁定统一三种针叶树型、中央横带覆盖、驿站 8 m 净距、远近渐变、河岸 / 山体稀疏、出生遮蔽和 12 段森林碰撞不变，并生成全周 / 山林 D3D12 QA 图 |
| `tools/verify_t0135_p5_natural_scatter.gd`、`tools/capture_t0135_p5_natural_scatter.gd` | P5 专项锁定五区密度、81 段地表过渡、河槽 / 道路 / 地块 / 广场零侵入、正式路线净距和零新增玩法节点，并生成全站、河岸、山脚、敌路林缘与林下 D3D12 QA 图 |
| `resources/materials/environment/`、`scenes/vfx/environment/`（规划） | 地表 / 泥土 / 河水 / 湿痕 / 雾材质及烟火尘环境 VFX；不提交资源、伤害或事件事实 |
| `resources/materials/`、`resources/themes/blacksmith_vertical_slice_theme.tres` | 环境 / 角色材质及 T0129 深木 / 黄铜 HUD、NPCPanel、BuildingPanel 临时正式 Theme；全量 UI 仍待 T0134 |
| `data/presentation/art_scale_baseline.json` | 单位、朝向、人形 / 建筑 / 门尺度、贴图过滤、阴影、色板、继承与沙盒性能软上限；不保存权威玩法结算 |
| `data/presentation/character_appearances.json` | NPC ID 到正式外观场景的表现映射；8 名初始 NPC 已全部使用各自 Synty 两头身生产包装；不保存 NPC 状态或装备事实 |
| `data/presentation/station_spatial_plan.json` | T0129A `station_spatial_plan_v7` 米制目标配置：保留 v6 地形 / 12 地块 / 80 占地 / 21:9 合同，并新增第五波 48 人队形、13 节点敌路与 6 点逃离节奏配置；目前只供独立灰盒与校验读取 |
| `data/station_layout.json` | T0129B/C `station_layout_v2` 正式空间合同；A5-P7 已设为 `formal_layout_active=true`，登记 12 建筑、61 工位、2 个非交互服务附属物、站内外共享生产 NavMesh、独立后门逃离区域、十阶段敌路、5 点商路、6 点逃离路和默认总切换权威边界；P6R3 后正式根位于世界原点，旧 `(1000,0,0)` 偏移仅供无 `world_origin` 的旧空间存档迁移 |
| `tools/verify_t0129c_a4_p1_formal_enemy_navigation.gd` | 验证开放城外生产 NavMesh、道路零导航权威、敌人胶囊 / 分层、spawn→front_gate 五阶段实体到达、avoidance、零活动波次提交、正门 HP 不变与停止清理 |
| `tools/verify_t0129c_a4_p2_formal_active_enemy_front_gate.gd` | 保留 P2 边界回归：一名真实活动敌人抵门前零攻击、抵门后既有 4 点伤害与事件，以及清敌 / 死亡节点清理 |
| `tools/verify_t0129c_a4_p3_formal_active_enemy_warehouse.gd` | 保留 P3 边界回归：验证破门后九阶段实体路线、门洞链接、到仓前零伤害、到仓后 `150 -> 146` 与停止清理 |
| `tools/verify_t0129c_a4_p4_formal_active_enemy_main_hall.gd` | 验证十阶段实体路线、仓毁后到主厅前零伤害、首次 `180 -> 176`、最终 `failure / main_hall_destroyed` 与停止清理 |
| `tools/verify_t0129c_a4_p5_formal_first_wave.gd` | 验证第一波 8 个独立 Body / Agent、碰撞与 avoidance、逐人到达攻击权威、单体死亡清理、剩余 7 人十阶段和整波停止清理 |
| `tools/verify_t0129c_a4_p6_formal_second_wave.gd` | 验证第二波 12 剑盾 + 4 长杆正式实体、分角色同侧槽位、阶段目标原子改向、主厅前后排几何、攻击提交与整波清理 |
| `data/physics_navigation.json` | T0129C `physics_navigation_v1`：统一物理层、NPC / 步兵 / 骑乘胶囊、`1.8 m` 建筑门净空、`0.25 × 0.1 m` StaticBody 生产 NavMesh、RVO `0.10 m` 预判缓冲、按胶囊计算的波次生成间距、正式大波次帧预算、卡死恢复和运动 / 玩法 / 表现权威边界 |
| `data/building_fixture_layouts.json` | T0129C-A3 / T0130-P7R / T0135-P8AR3 `building_fixture_layout_v1` 全 12 建筑实物合同；共 109 件配置物 / 61 个 NPC 站位 / 36 个床、椅、祈祷表现锚点 / 8 个马匹净空锚点。铁匠铺三砧现统一由石脚 / 木墩承地、热铁贴砧面、站位距砧心 1.10 m，共享炉迁到后炉墙；其他已验收 fixture 数量与容量不变 |
| `scripts/presentation/ArtSandbox.gd` | 克隆导入材质并统一过滤 / 阴影、播放代表动画、提供相机与屋顶验证快照；不写权威状态 |
| `scripts/presentation/StationSpatialSandbox.gd` | 从空间配置生成地形、八方向地块、最高容量占地、道路、自然环境与聚焦视图，并汇总敌军 / 逃离压力状态；不修改 Main、导航、地点、工位或战斗事实 |
| `scripts/presentation/StationEnemyStressSimulation.gd` | 从第五波配置创建 48 个带 Capsule 物理包络的混编敌人，执行森林出生到主厅的 13 队形节点 / 12 段 presentation-only 行军和净距采样 |
| `scripts/presentation/StationEscapeStressSimulation.gd` | 用带 Capsule 包络的逃离 NPC 压力体沿后门至地图边缘的 6 点路径运行，核算默认 / 给钱 / 受击速度和五轮干预窗口；不提交 `escaped` 或 `in_station` |
| `scripts/world/StationLayoutController.gd` | 正式布局、碰撞与空间配置只读投影；A5-P7 默认启用正式相机、生产 NavigationMap、三块 Region 与 Link；T0132-P1R3 从主厅平台 fixture 与正式正门墙段生成器械世界锚点，P1R5 将 Lv.4 fixture 最终改为石座 / 铁箍连接的酒红燕尾守备旗，Lv.6 保持实体贴图门楼指挥塔及同色瓦顶；继续提供建筑门路、敌路、商路、逃离路和公共锚点，不提交玩法结算 |
| `tools/verify_t0129c_a5_p7_default_formal_world.gd` | A5-P7 专项：验证新局 8 个唯一正式出生点、统一生产导航、非战工作零传送与结束留位、战斗接管留位、默认 6 点商路 / 6 点逃离路及 GM 兼容往返 |
| `tools/verify_t0129c_a5_p4c_formal_escape_route.gd` | 验证 6 点后路配置、12 顶点 / 5 多边形 Region、后门 Link、中途对话暂停 / 恢复、战斗结束后逃离租约、地图边缘原子提交与完成后正式世界释放 |
| `assets/3d/quaternius/props/chapel_{bench,book_stand,candlestick_triple,chalice,book}.glb` | A3b9R 从 Fantasy Props Standard 筛选的教堂主体家具；配套 `chapel_T_Trim_*` 9 张纹理，只供表现层实例化，碰撞与容量仍由配置 / BuildingSystem 决定 |
| `assets/3d/quaternius/props/workshop_{workbench,shelf,rope}.glb` | A3b10R 从 Fantasy Props Standard 的 `Workbench / Shelf_Simple / Rope_1` 打包；配套 `workshop_T_Trim_Furniture_* / workshop_T_Trim_Metal_*` 6 张纹理，供工械坊工程台与共享设施组合，不包含容量权威 |
| `assets/3d/quaternius/buildings/main_hall_{wall_window,wall_door,roof,tower_roof,stairs,support,platform_floor}.glb`、`props/main_hall_{banner,lantern}.glb` | A3b11R 从 Medieval Village / Fantasy Props Standard 筛选的主厅模块；复用既有材质并新增 11 张 Brick / UnevenBrick / MetalOrnaments / Cloth 纹理，只供主体、加固与装饰表现 |
| `assets/3d/quaternius/buildings/warehouse_{wall_woodgrid,roof_wooden,wagon}.glb`、`props/warehouse_{shelf_arch,bag,metal_crate,apple_barrel,chest}.glb` | A3b12R 从 Medieval Village / Fantasy Props Standard 筛选的仓库模块；八件 GLB 全部复用既有外置纹理，不保存库存数量或工位权威 |
| `scripts/world/ActorMotionBody.gd`、`scenes/debug/ActorMotionBody.tscn` | T0129C-A2a/P7R 可复用实体运动组件；CharacterBody3D 实体胶囊、独立 InteractionArea、NavigationAgent3D 路径 / RVO、profile 速度 / 加速度双重约束、暂停、到达 / 失败、连续卡死采样与有界重寻路；支持绑定专属 NavigationMap，并在同步宽限后以路径末端水平距离复核 Recast 高度偏移造成的假不可达，导航岛外目标仍失败；快照暴露速度、RVO 与单帧位移峰值，只发运动结果，不写玩法权威 |
| `scripts/world/MerchantWagon.gd`、`scenes/world/MerchantWagon.tscn` | 行商实体与权威边界；复用 ActorMotionBody，委托 FormalMerchantWagonArtView 呈现双马、两头身车夫、四轮满载板车及速度动画；支持旧图 2 点路线与正式 6 点折线 NavigationMesh，只有物理停靠后可点交易牌，不结算交易或复制库存 |
| `assets/3d/quaternius/animals/merchant_horse.glb` | Quaternius Ultimate Animated Animal Pack 的 CC0 马匹 glTF 打包件，供行商马车运行时实例化及 Walk / Idle 动画 |
| `assets/2d/ui/merchant_trade_marker.svg` | A5-P4a-R 小型羊皮纸钱袋交易牌；Sprite3D billboard，仅表达可交易状态，不拥有交易权威 |
| `scripts/debug/ActorMotionSandbox.gd`、`scenes/debug/ActorMotionSandbox.tscn` | 5 实体独立运动沙盒；并行覆盖静态绕障、2.4 m 对向会车、暂停恢复、物理阻挡卡死和 NavMesh 外不可达，不挂入 Main |
| `scripts/presentation/buildings/RoofVisibilityController.gd` | 唯一相机距离采样、全局归一化与 BuildingArtView 注册 / 广播 / 只读快照；T0134-P1R3 同步配置主镜头只看渐隐建筑壳层 19、排除人物框不透明壳层 18 |
| `scripts/presentation/buildings/BuildingArtView.gd`、`SmithyAmbientFX.gd` | scene-local 主屋顶 / 升级结构 / 外墙渐隐、internal shadows-only 持久阴影、T0134-P1R3 internal 人物框不透明壳、交互包围体和真实等级投影；铁匠铺火焰 / 炉光 / 烟 / 火星 / 风箱只随真实占用＋打铁动作启停，所有副本与炉火均 presentation-only |
| `scripts/presentation/characters/NPCArtView.gd` | 骨骼重绑、本地循环 AnimationLibrary、15 状态、六挂点、锤子、朝向 / 暂停、血粒子、受击回弹及带冲量受控倒地；训练示范 / 练习、站立主持、长凳坐姿祈祷与座椅坐姿进食均为只读循环，不产生伤害、事件、虔诚、资源或需要值事实；快照只供诊断，presentation-only |
| `scripts/presentation/characters/ChibiCharacterPilotPreviewController.gd` | Main 中只读启停 T0130 P0 双角色历史预览；临时根固定在 FormalStationLayout，关闭整根释放，不改变 NPC / Combat 权威集合；独立动作沙盒在 P7 已扩为格伦 / 托马 / 布鲁诺 / 伊沃 / 马塞尔 / 艾达 / 莉娜 / 剑盾八角色 |
| `scenes/characters/OwenArtView.tscn`、`scenes/characters/BrunoArtView.tscn`、`scenes/characters/IvoArtView.tscn`、`scenes/characters/MarcelArtView.tscn`、`scenes/characters/LinaArtView.tscn`、`scenes/characters/AdaArtView.tscn` | A5-P5c–P5h 建立的 6 名 Quaternius / UAL2 历史职业包装；T0130-P8 后均不再是生产映射，只保留兼容回退。所有包装只读 NPC 状态 |
| `scenes/npc/NPC.tscn`、`scripts/npc/NPC.gd` | 通用 NPC 根为 CharacterBody3D，实体胶囊、独立 InteractionArea 与 NavigationAgent3D 分层；A5-P7 后默认日常、战斗与逃离均使用 ActorMotionBody 导航 / RVO / move_and_slide，旧坐标仅供 GM 临时兼容；动作信号驱动走 / 跑表现，挂接后仍保留交互，逃离完成后 Body 与点击表面同时不可选 |
| `scripts/systems/BuildingSystem.gd` | T0127 新增工位预留、提交、单独释放和铁匠铺空间路线查询；继续独占 `reserved_by / occupied_by` 权威 |
| `scripts/systems/NPCSystem.gd`、`scripts/systems/ActionSystem.gd`、`scripts/systems/MemorySystem.gd` | 保留门外 → 门内 → 工位事务及 P5/P6 全部正式消费者；A5-P7 新增 8 人默认正式居民生命周期，行动从当前 Body 出发，完成 / 中断后只释放事务并保留最后正式坐标。P7R3 的诊所床侧锚点读取家具碰撞投影并保留医生 Body 碰撞；挂接、服务依赖、资源时序、地点事件、目标投影与统一清理仍由三系统分权完成 |
| `tools/verify_t0129c_a5_p5b_formal_blacksmith_work.gd` | A5-P5b 专项：验证无目标预检、途中零扣料、穿门 / 锻造位占用、循环打铁、单周期唯一阶段提交、原位续周期及切目标零幽灵清理 |
| `tools/verify_t0129c_a5_p5b_gm_blacksmith_start.gd` | A5-P5b-R GM 入口专项：从新局无制造目标开始，发出真实按钮 `pressed` 信号，验证自动选配方、正式会话启动、GM 窗口关闭、格伦实体出现并进入 `work_blacksmith` |
| `tools/verify_t0129c_a5_p5c_formal_workshop_work.gd` | A5-P5c 专项：实际点击 GM 按钮，验证无目标预检、自动选配方、途中零扣料、欧文穿门 / 工程位占用、无锤循环动作、单阶段提交、日计划原位续作及换目标零幽灵清理 |
| `tools/verify_t0129c_a5_p5d_formal_dining_work.gd` | A5-P5d 专项：实际点击 GM 按钮，验证缺粮迁移前失败、有粮 pending 零扣料、布鲁诺穿门 / 灶台占用、无锤循环动作、`1 粮 -> 2 餐食`、日计划同 session 原位续作及中断零幽灵清理 |
| `tools/verify_t0129c_a5_p5e_formal_garden_work.gd` | A5-P5e 专项：实际点击 GM 按钮，验证 pending 零产出、伊沃实体到达田畦工作面后占用、无锤循环耕作、精确缩放产粮、日计划同 session 原位续作及中断零幽灵清理 |
| `tools/verify_t0129c_a5_p5f_formal_tavern_work.gd` | A5-P5f 专项：实际点击 GM 按钮，验证缺粮迁移前失败、有粮 pending 零扣料 / 零产出、马塞尔实体到达发酵桶后占用、无锤循环酿酒、精确缩放产酒且金钱不变、日计划同 session 原位续作及中断零幽灵清理 |
| `tools/verify_t0129c_a5_p5g_formal_clinic_work.gd` | A5-P5g 专项：实际点击医生 / 患者 GM 按钮，验证双 pending 零治疗、桌 / 床双实体到位、占床后 `lying_supine` 挂接、莉娜无锤循环坐诊、治疗扣费和最后医生离岗后的失败下床 / 零幽灵清理 |
| `tools/verify_t0129c_a5_p5h_formal_training_work.gd` | A5-P5h 专项：实际点击教官 / 学员 GM 按钮，验证双 pending 零成长、指挥位 / 木桩站位双实体到位、艾达 / 格伦独立训练循环、团队成长和最后教官离岗失败 / 零幽灵清理 |
| `tools/verify_t0129c_a5_p5i_formal_chapel_work.gd` | A5-P5i 专项：实际点击祈祷 / 主持 GM 按钮，验证双路线 pending 零虔诚、祭坛 / 长凳占用与挂接、独祷↔参礼原位转换、跨小时计划保护、主持退出后保留席位 / 时长恢复独祷及最终零幽灵清理 |
| `tools/verify_t0129c_a5_p5j_formal_dining_eat.gd` | A5-P5j 专项：实际点击用餐 GM 按钮，验证无食物迁移前失败、pending 途中零扣粮 / 零事件 / 零恢复、首个餐位占用与 `sitting` 挂接、餐食优先、粮食兜底、循环进食、完成及中断后的工位 / 会话 / 挂接 / 碰撞清理 |
| `tools/verify_t0129c_a5_p6a_formal_dormitory_sleep.gd` | A5-P6a 专项：实际点击睡眠 GM 按钮，验证固定床预留、pending 途中零恢复 / 零睡眠事件 / 零反思、到床占用与 `sleeping_supine` 挂接、active 疲劳恢复，以及完成 / 中断后的床位、会话、挂接和碰撞清理 |
| `tools/verify_t0129c_a5_p6b_formal_visit_location.gd` | A5-P6b 专项：实际点击拜访 GM 按钮，验证广场→建筑、室内→室内、室内→广场的真实路线，pending / 暂停零事实、无工位、事件唯一、途中换目标、建筑失效以及完成 / 停止保留最后物理地点 |
| `tools/verify_t0129c_a5_p6c_formal_npc_dialogue.gd` | A5-P6c 专项：点击真实找人对话 GM 按钮，验证跨建筑实体接近距离、邀请 pending 不打断目标工作、接受时工位释放且 Body 不跳位、结束后双方空间会话清理 |
| `tools/verify_t0129c_a5_p6d1_formal_repair_assist.gd` | A5-P6d-1 专项：穷尽 15 类修复目标外沿槽，验证多人独立槽、暂停零移动、途中零 helper / 倍率 / 事件、实际到位单次提交，以及完成 / 目标途中消失后的统一清理 |
| `tools/verify_t0129c_a5_p6d2_formal_upgrade_assist.gd` | A5-P6d-2 专项：穷尽 15 类升级施工目标外沿槽，验证多人独立槽、暂停零移动、途中零 helper / 倍率 / 事件、升级进度广播不打断合法路线、实际到位单次提交，以及完成 / 目标途中升级结束后的统一清理 |
| `tools/verify_t0129c_a5_p6d3_formal_heal_assist.gd` | A5-P6d-3 专项：验证昏迷目标正式投影、两名治疗者独立接近位、第三人途中拒绝、暂停零移动、抵达前零首付 / helper / HP / 经验 / 事件、合法距离原子提交，以及复苏和途中目标复苏后的统一清理 |
| `tools/verify_t0130_p1_formal_character_integration.gd` | T0130-P1/P1R/P1R2/P1R4 专项：验证正式格伦映射、待机锤髋部横挂及锤头朝前、真实工位切回右手后多个 Hammering 相位的后段锤柄握点、柄尾长度与锤头最小分离、循环锤击与面向铁砧、父级碰撞保留、第一波 8 个正式剑盾两头身实体、移动动画与动态可见朝向、无重复选择体和 GM 入口 |
| `tools/verify_t0130_p2_toma_character_integration.gd` | T0130-P2 专项：验证托马独立模型 / 土色轮廓、父级碰撞、真实马厩路线 / 面向 / 工位、`Working_B` 周期回卷、照料工具时机、交谈、驾车坐姿预留、昏迷 / 起身和 GM 入口 |
| `tools/verify_t0130_p3_bruno_character_integration.gd` | T0130-P3 专项：验证布鲁诺独立 ShopKeeper 厨师轮廓、父级碰撞、真实食堂灶台路线 / 面向 / 占用、`Working_C` 周期回卷、厨具时机、真实就座进食、交谈、昏迷 / 起身和 GM 入口 |
| `tools/verify_t0130_p4_ivo_character_integration.gd` | T0130-P4/P4R/P4R2 专项：验证伊沃 Deckhand 作者 BaseMaterial、`_01_A + vertex_color_use_as_albedo` 原生脸、父级碰撞、真实菜园路线 / 面向 / 占用、`Digging` 周期回卷、园锄显隐、全周期锄刃前向距离 / 双手握持覆盖率、真实小教堂祈祷席、交谈、昏迷 / 起身和 GM 入口 |
| `tools/verify_t0130_p5_ada_character_integration.gd` | T0130-P5/P5R2 专项：验证艾达 ShieldMaiden 轻装老兵轮廓、`Blue_A + vertex_color_use_as_albedo` 原生脸、零程序化面部节点、父级碰撞、权威剑盾换装显隐、真实训练格挡循环、固定床 `sleeping_supine -> Lie_Idle`、交谈 / 攻击、昏迷 / 起身和既有 GM 入口 |
| `tools/verify_t0130_p5r3_ada_profile_sync.gd` | T0130-P5R3 专项：验证艾达玩家档案外貌与当前 ShieldMaiden 模型一致，并通过共享 `NPCPromptProfile` 原样进入 `npc_setting.appearance`；不调用模型或改变行为规则 |
| `tools/verify_t0130_p6_marcel_character_integration.gd` | T0130-P6/P6R/P6R2 专项：验证马塞尔 Wizard 长袍基础的分离尖帽拓扑移除、`Purple_A + vertex_color_use_as_albedo` 作者材质、Body 木质圣徽的竖直 / 朝外 Transform、Head 灰白圆冠及其零碰撞、行走 / 交谈 / 酿酒 / 弥撒 / 坐席祷告、受击 / 昏迷 / 复苏、父级碰撞和零重复选择体；正式酒窖与礼拜另由既有专项验证实体到位后才 active |
| `tools/verify_t0130_p7_lina_character_integration.gd` | T0130-P7 专项：验证莉娜 GovDaughter 作者材质 / 原生脸、低饱和 `Blue_A`、父级碰撞、零重复选择体、Body 药包、诊所病历册、治疗绷带、共享状态、循环动作及受击 / 昏迷 / 复苏；正式诊所巡床与昏迷目标接近另由专项验证到位后才 active |
| `tools/verify_t0130_p7r_clinic_rounds.gd` | T0130-P7R/P7R2/P7R3 专项：验证四张病床正确卧姿、无病人坐桌、双病人真实占床、左右床侧均以 `0.79 + 0.35 + 0.08 m` 形成无重叠治疗位、治疗时保留 Body / Interaction 碰撞、换床、300 游戏秒轮换及回椅 |
| `tools/verify_t0130_p8_owen_character_integration.gd` | T0130-P8 专项：验证欧文 Firstmate 作者材质 / 原生脸、护目镜 / 工具带 / 扳手骨挂点、父级碰撞、职业动作、真实剑盾装备同步、受击 / 昏迷 / 复苏与档案外貌投影；正式工械坊、修复和升级另由 P5c / P6d1 / P6d2 锁定到位前后表现边界 |
| `scripts/systems/CombatSystem.gd` | 保持敌人权威结算；A4-P7 覆盖五波逐敌索敌 / 追击 / 动态接触 / 补位；P7R 限制 RVO 速度与表现转向；A5-P1 让战斗 / 非战斗人员同图；A5-P2 按最大胶囊生成并以每帧 8 敌轮转、逐敌累计时间和状态签名去重控制正式第五波负载 |
| `scripts/systems/SpatialSaveSystem.gd` | A5-P8 正式空间检查点总协调：写入 / 读取 `formal_spatial_save_v1`，保证生产 NavigationMap 先于 NPC、波次、逃离和行商恢复；不序列化 RID / NodePath |
| `tools/verify_t0129c_a5_p8_formal_spatial_save.gd` | A5-P8 专项：在途动作安全回滚，并在销毁 / 重建 Main 后联合恢复 8 NPC、第一波 8 敌、活动逃离和在途正式商车 |
| `tools/verify_t0129c_a4_p7_dynamic_combat_pressure.gd` | 验证五波正式实体数量、foot / mounted 实体碰撞层、无固定槽运行态、第二波共享目标接触 / 后排施压、profile / Agent 速度一致、零超速、单帧位移 / 转角上限、最小中心距、前排死亡后补位和清理 |
| `tools/verify_t0129c_a4_p7b_default_formal_combat_world.gd` | 验证默认刷波零旧 Area3D、敌我 Body 同一生产 NavigationMap、碰撞层有效、NPC 实际移动、敌人追踪移动目标重规划，以及清敌后保留最后正式坐标并恢复日常运动模式 |
| `tools/verify_t0129c_a5_p1_formal_noncombat_avoidance.gd` | 验证初始 8 名可行动 NPC 全部迁入正式战斗空间、非战斗名单与碰撞 / 导航绑定、避战目标吸附 NavMesh、实体连续远离敌人及清敌后 8 人可逆恢复 |
| `tools/verify_t0129c_a5_p2_default_fifth_wave_pressure.gd` | 验证默认第五波 48 敌 + 8 NPC、骑乘生成净距、RVO 拥堵净距、速度 / 单帧位移、3 名非战斗持续避战、零导航失败、前排死亡后补位、逐敌轮转全覆盖、CombatSystem P95 帧时与清理零孤儿 |
| `scripts/ui/BuildingPanel.gd` | 逐工位显示空闲、在途预留或真实占用；不自行分配 / 提交位置 |
| `tools/verify_t0129b_c1_station_layout.gd` | 持续验证 C1 静态几何 / 镜头合同在 `station_layout_v2` 中未回退，并确认 78 个结构阻挡 + 1 个烘焙地面、生产 NavigationRegion 预览外禁用和旧玩法根零变更 |
| `tools/verify_t0129b_c4_p1_formal_merchant_route.gd` | C4-P1 正式远距商路专项；P7R2 后验证 6 点 / 地图边缘至后门外路线、约 7 m 车根停靠净距、约 1.2 m 马组前缘净距、折线实体进场、抵达后才开放交易、原路离场释放以及旧图兼容路线恢复 |
| `tools/verify_t0129b_c2_spatial_contract.gd` | 逐位置对照 v7 验收基线，验证 61 + 4 = 65、135 个权威 Marker + 44 个家具安全站位 + 24 个挂接锚点、`11303` 格合同网格、123 / 123 对照目标、独立生产地图中的 65 个 Godot 路径、预览启停和旧 NPC 零移动 |
| `tools/verify_t0129c_a1_static_collision.gd` | 验证 `physics_navigation_v1`、三层 / 三类胶囊、78 个结构阻挡 + 1 个地面、12 个 `1.8 m` 物理门洞、侧墙射线阻挡和 12 条生产地图门外到室内路径 |
| `tools/verify_t0129c_a3a_production_navigation.gd` | 验证 `0.25 × 0.1 m` StaticBody 烘焙、专属 NavigationMap、234 个 source body（含 131 个 fixture 与 24 个自然阻挡）、12 个门链接，并从每座建筑侧墙外确认路径绕正门进入室内 |
| `tools/verify_t0129c_a3b2_clinic_fixtures.gd` | 验证诊所 2 装饰诊疗桌 + 2 工作椅 + 4 病床的可见物 / BoxShape / 站位一一对应、2 个坐姿与 4 个床面锚点、`mount_after_arrival` 路线语义、站位避开全部家具、射线命中及六位置生产导航可达 |
| `tools/verify_t0129c_a3b3_dormitory_fixtures.gd` | 验证宿舍 10 张床的可见物 / BoxShape / 床边站位 / 睡眠锚点四件套、两列密集碰撞零重叠、最近床体 `0.06 m` 配置净空、10 条生产路径，以及 BuildingSystem 的 8 个固定归属和 2 个未来床位选择 |
| `tools/verify_t0129c_a3b4_dining_hall_fixtures.gd` | 验证食堂 3 灶台、2 张非权威长桌和 10 把一席一椅的可见物 / BoxShape；覆盖 13 个到达点、10 个 `sitting` 锚点、家具零重叠、门外生产路径、一级只开放 2 灶台及第 11 个用餐者失败 |
| `tools/verify_t0129c_a3b5_tavern_fixtures.gd` | 验证酒窖 3 套发酵桶、Lv.2 非权威熟成架、空桶组和验酒桌；覆盖 3 个桶外站位 / 工作朝向、家具零重叠、门外生产路径、一级只开放 2 位及三级精确增加第 3 位 |
| `tools/verify_t0129c_a3b6_garden_fixtures.gd` | 验证菜园 3 块逐级田畦与灌溉 / 堆肥 / 推车 / 工具架 / 围栏 / 收获箱；三块田畦各用前侧开放的 3 段 U 形碰撞和 9 株作物，覆盖三级容量、共享设施非权威、工作面无整体碰撞及三条生产路径 |
| `tools/verify_t0129c_a3b7_training_ground_fixtures.gd` | 验证训练场 `1+2 -> 1+3 -> 2+4` 六位置、2 面教官旗 / 4 木桩、4 件共享设施非权威、六块 `3 × 3 m` 动作净空、家具零重叠、BuildingSystem 等级容量与六条生产路径 |
| `tools/verify_t0129c_a3b8_stable_fixtures.gd` | 验证马厩 8 个开放马栏 / 27 个复合碰撞部件、3 个照料站位、8 个 `1.4 × 2.2 m` HorseAnchor、共享 Lv.2 草料架非权威、BuildingSystem `2 -> 2 -> 3`、初始两匹成年马仍在厩及三条生产路径 |
| `tools/verify_t0129c_a3b9_chapel_fixtures.gd` | 验证小教堂五排左右 Quaternius 长凳、十个 `seated_prayer` 单席、完整祭坛、开放彩窗、五件 Lv.2 非扩容结构、中央通道和十一条生产路径 |
| `tools/verify_t0129c_a3b10_workshop_fixtures.gd` | 验证工械坊三张 Quaternius 工作台分别映射制弓 / 机构 / 攻城总装角色，四件共享设备具有货架 / 绳卷 / 制图 / 材料细节，并保持 7 碰撞、`2 -> 2 -> 3` 权威容量与 15 / 13 / 14 点三条真实站位路径 |
| `tools/verify_t0129c_a3b11_main_hall_fixtures.gd` | 验证 `MainHallArt`、21 个砖石门窗模块、中央入口 / 屋顶、四个正式木构平台及 Lv.2 / 4 / 6 加固细节；同时锁定不可进入、零 NPC 工位、7 碰撞与前侧先开的槽位权威 |
| `tools/verify_t0129c_a3b11_main_hall_fixtures.gd` | 验证主厅 `slot_01/02/03/04 = Lv.5/6/1/3`、三档结构加固及零 NPC 站位 |
| `tools/verify_t0129c_a3b12_warehouse_fixtures.gd` | 验证 A3b12R `WarehouseArt`、8 件 Quaternius 资产、7/7/0 fixture 合同、`5/1/1` 分级、类别符号非库存权威、货运车碰撞、中央通道与 17 点敌军攻击路径 |
| `tools/verify_t0129c_a3b13_natural_boundaries_and_a3_complete.gd` | 验证 24 个自然 StaticBody、道路 / 敌路 / 商路净空、234 个静态源、788 / 754 生产网格和全部 61 个工位路线 |
| `tools/verify_t0129c_a3_door_queue.gd` | 在正式生产地图中并发驱动 3 个 NPC 胶囊穿过小教堂 `1.8 m` 门洞，验证 RVO 回调、零穿透和全部到达 |
| `tools/verify_t0129c_a3b1_blacksmith_fixtures.gd` | 验证铁匠铺 5 个可见家具 / 5 个 BoxShape / 3 个站位一一对应，站位不与实体重叠、朝设备射线命中、路线目标与逻辑湾中心分离，并由生产 NavigationServer 抵达全部三个锻造位 |
| `tools/verify_t0129c_a2_actor_motion.gd` | 验证 5 个 CharacterBody、Body / InteractionArea 分层、绕障、RVO 会车净距、暂停零漂移、卡死两次重寻路、不可达原因和零玩法权威提交 |
| `tools/verify_t0129c_a2b_p1_glen_formal_navigation.gd` | 验证格伦 CharacterBody 分层、正式绕障 / avoidance、门后地点提交、forge_01 原子占用、停止还原和不可达零幽灵占用 |
| `tools/verify_t0129c_a2b_p2_clinic_formal_navigation.gd` | 验证莉娜到诊疗桌站立、到病床先提交占用后挂接 `lying_supine`、挂接期间 Body / InteractionArea 分层，以及停止、不可达和昏迷零幽灵状态 |
| `tools/verify_t0129c_a2b_p3_dormitory_formal_navigation.gd` | 验证数据驱动试点登记表、艾达固定选择 `dormitory_bed_01`、先提交后挂接 `sleeping_supine`、`current_action=idle`，以及停止、不可达、改派、建筑失效和昏迷零幽灵状态 |
| `tools/verify_t0129c_a2b_p4_dining_formal_navigation.gd` | 验证布鲁诺首个空闲餐位、1 号席被占时选择 2 号席、提交后挂接 `sitting`、`current_action=idle`，以及停止、不可达、改派、建筑失效和昏迷零幽灵状态 |
| `tools/verify_t0129c_a2b_p5_chapel_formal_navigation.gd` | 验证马塞尔首个空闲祈祷席、1 号席被占时选择 2 号席、提交后挂接 `seated_prayer`、不启动祈祷 / 虔诚，以及停止、不可达、改派、建筑失效和昏迷零幽灵状态 |
| `tools/verify_t0129c_a2b_p6_stable_formal_navigation.gd` | 验证托马首个空闲马厩照料位、1 号位被占时选择 2 号位、栏外站立到达后提交占用、HorseAnchor 净空与 Body 碰撞保持，以及停止、不可达、改派、建筑失效和昏迷零幽灵状态 |
| `tools/verify_t0129c_a5_p5a_formal_stable_work.gd` | 验证托马途中仅预留且 HorseSystem 不计劳动力、到位后 active + 无铁锤循环动作 + 马匹照料推进、同计划原位复用同一栏位，以及中断释放 / 旧世界恢复 |
| `scenes/main/Main.tscn`、`scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | GM 除既有正式导航 / 协助 / 敌军切片外，提供角色沙盒、真实建筑行动与工械坊 / 教堂 / 诊所 / 食堂 / 宿舍 / 酒窖 / 菜园逐级美术预览；T0131-P7 新增 `garden_art_level 1|2|3`，所有入口只转发既有权威接口或只读 / presentation-only 快照 |
| `docs/TASKS.md` | T0123–T0129C、T0129 与 T0130 八名初始 NPC 已 Done；T0131 按逐建筑切片推进，P1 工械坊已验收，P2 小教堂已实现并待用户逐级视觉验收；T0132–T0136 待后续 |

六个 Quaternius 免费 Standard 包已在 `art_source/` 本机隔离区下载并解包；T0125 建立样本与材质基线，T0126–T0127 完成首个建筑包装、屋顶和铁匠铺室内权威链，T0128–T0128A 完成格伦角色、挂点、朝向与循环动画。T0129A v0.9 已完成空间灰盒；T0129B-C1 / C2a 接入 `station_layout_v2` 与 65 个权威位置，T0129C-A3 完成全 12 建筑家具、24 个自然阻挡和 236 个静态源，A3b9R–A3b12R 已完成四座粗糙建筑逐座精修。A4 / A5 已迁移五波敌人、全部 NPC 日常消费者、商旅、逃离和默认正式世界；A5-P8 以 `formal_spatial_save_v1` 完成全新 Main 下的空间恢复。T0129 已获用户最终确认；T0130 已完成八名初始 NPC 的 Synty / KayKit 迁移与逐人返修。T0131 已完成并验收工械坊 P1，P2 小教堂已实现并待用户视觉验收，继续遵守逐建筑交付，不批量铺开其余建筑。

## T0121 / T0122 全局数值难度模型与连续回放索引

| 文件 | 当前职责 |
|---|---|
| `docs/GAME_BALANCE.md` | 已确认并实施的全局玩法数值合同：第 3–7 日 18:00 五波、入伍 / 敌群 / 器械 / 装备、制造与经济人时、治疗 / 批次修复、工作 / 虔诚流、难度 KPI 和验证证据 |
| `docs/TASKS.md` | T0121 已完成范围与验收；T0122 自动连续回放进展与仍待真实玩家 / LLM 分布验收的 Partial 边界 |
| `docs/CURRENT_STATE.md`、`docs/DEV_LOG.md` | 记录实施后的唯一失败条件、波次 / 制造 / 经济 / 成长 / 修复 / 虔诚合同及自然 / 精细连续回放结果 |
| `data/action_defs.json`、`data/crafting_recipes.json`、`data/building_defs.json`、`data/merchant_defs.json` | 5400 秒制造周期、阶段 / 材料、批次修复、餐食与交易权威配置 |
| `data/enemy_waves.json`、`data/defense_device_defs.json`、`data/piety_ability.json` | 五波时间 / 构成、弩床 44 / 4.25、陨石冲击 12 目标权威配置 |
| `scripts/systems/CombatSystem.gd`、`NPCSystem.gd`、`CraftingSystem.gd`、`BuildingSystem.gd`、`PietySystem.gd`、`MemorySystem.gd` | 唯一失败条件、战斗等级来源、隐藏配方、批次修复、冲击上限及陨石事件字段的权威结算 |
| `tools/verify_t0121_game_balance.gd`、`tools/verify_t0121_fifth_wave_build.gd` | 全局配置 / 公式合同与第 7 日 48 敌成型构筑实战回归 |
| `tools/verify_t0122_continuous_workflow.gd` | 第 1 日至第 7 日无资源发放连续回放；`natural` 验证第四 / 五波策略墙，`focused` 验证确认工作构筑可由实际制造、交易、治疗和加班闭合并通关 |

下文按历史任务累积的长段落若仍提到 T1303 `no_available_combatants`、旧 `8 / 12 / 18 / 26 / 36` 波次或制造 3600 秒，均已由本节 T0121 当前合同取代；保留只用于解释旧任务来源，不再表示运行时现状。

## T0119 NPC 征募难度与逃离倾向索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 8 人公开人物线索、职业底线、有效准备方向与礼物态度；不公开内部难度、概率或完整答案 |
| `data/npc_initial_long_memory.json` | 守备官开局前关系仅为基础印象；战时征募、装备与命令尚未经验证，后续实际事实决定关系 |
| `data/prompts/dialogue_system_prompt.txt` | 严格已知事实、差异化征募路线、礼物作用、承诺兑现和逃离挽留决定 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/battle_judgement_system_prompt.txt` | 按人物和实际压力事实决定日常 / 战时逃离倾向，艾达保持稳定锚点 |
| `data/prompts/plan_revision_judgement_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 只让与已解决 / 新增实际原因相关的计划阶段进入修订并恢复工作或继续逃离 |
| `data/prompts/daily_reflection_system_prompt.txt` | 将建设、资源、装备、指令、攻击、承诺和礼物按实际经历写入主观长期记忆，不写隐藏指标 |
| `tools/verify_npc_initial_long_memory.py` | 校验 8 人关系种子的战前 / 战时语义边界 |
| `tools/verify_npc_recruitment_escape_real.py` | 基线及征募、日计划、战斗、挽留真实 provider 矩阵，保存逐次审计和行为断言 |
| `tools/verify_daily_reflection_prompt_real.py` | 真实反思回归：诊所、装备 / 职责承诺兑现及无关酒礼边界 |
| `docs/audits/T0119_NPC_RECRUITMENT_ESCAPE/` | 24 次基线、180 次最终矩阵的原始 JSONL、聚合结果、Prompt hash、token 与费用 |

## T0116 制造失败事实与计划对话执行前复核索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/CraftingSystem.gd`、`scripts/systems/ActionSystem.gd` | 完成阶段失败保留项目快照；`work_failed` 输出真实失败原因、所需资源和紧凑阶段事实 |
| `scripts/systems/LLMBridge.gd` | 构造完整执行前复核上下文、注入制造项目、发送 / 收束 `dialogue_intent_revalidation` 异步请求 |
| `scripts/systems/DailyPlanSystem.gd` | 记录意图制定元数据；执行前去重、三分支落地、当前小时重估及迟到响应保护 |
| `backend/schemas/npc_ai.py`、`backend/app.py` | 复核请求 / 响应 Schema、三枚举业务合同和一次真实模型纠错重试 |
| `backend/services/model_adapter.py`、`data/prompts/dialogue_intent_revalidation_system_prompt.txt` | 正式 Prompt、供应商投影 / hydration、Mock 三分支与制造字段语义 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | “对话意图复核”按钮及 `intent_revalidation <npc_id>` 观察入口 |
| `tools/verify_dialogue_intent_revalidation.py/.gd`、`tools/verify_dialogue_intent_revalidation_real.py` | Mock endpoint、Godot 异步运行态和真实 DeepSeek 三分支验收 |
| `tools/verify_crafting_pipeline.gd` | 锁定阶段材料不足事件的原因、required_resources 与制造项目字段 |

## T0115 主动交涉竞态与陈旧失败隔离索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/DailyPlanSystem.gd` | 传播 action-failure 来源；统一顶层 / 嵌套目标签名；拒绝当前小时原样重复刚失败行动并进行同阶段有界重试 |
| `scripts/systems/NPCSystem.gd` | 主动交涉与两类移动的原子 start result；对话成功后才消费 proactive，拒绝时保留交涉 |
| `scripts/systems/DialogSystem.gd` | 校验主动交涉草稿确实激活为同一 dialogue ID；失败或同步撤销时清理草稿而不制造幽灵 active dialogue |
| `tools/verify_npc_proactive_talk.gd` | 覆盖陈旧制造失败、规划中点击、创建—激活竞态、问号恢复和最终 NPC 发起对话 |
| `tools/verify_action_failure_plan_revision_judgement.gd` | 覆盖 action-failure 来源传播、同失败行动本地拒绝、计划不落地与单条 stage-two 重试 |
| `tools/verify_npc_movement_location.gd` | 覆盖移动开始替换旧失败终态及到达位置回归 |

## T0114 共享虔诚与无友伤陨石索引

| 文件 | 当前职责 |
|---|---|
| `data/piety_ability.json` | 虔诚上限 / 祈祷产率、水平地面高度、陨石半径 / 时序 / 冲击与燃烧数值的唯一配置源 |
| `scripts/systems/PietySystem.gd` | 共享虔诚累计与消耗、选点校验、现实时间陨石下落、逻辑时间燃烧、表现生命周期，以及仅在落地后生成影响 / 条件式击杀事件和调试快照 |
| `scripts/systems/ActionSystem.gd`、`scripts/core/EventBus.gd` | 按 active 祈祷的实际有效逻辑秒提交产出；发布虔诚变化、施放与落地信号 |
| `scripts/systems/CombatSystem.gd` | `apply_enemy_area_damage(...)` 只枚举活动敌人并复用既有防御、死亡和清敌结算 |
| `scripts/ui/PietyAbilityButton.gd`、`scripts/ui/HUD.gd` | 左上十字架圆形蓄能 / 满值发亮，以及地面范围预览、确认与取消交互 |
| `scenes/main/Main.tscn` | 注册 PietySystem 与世界 `Effects` 容器，保持结算系统先于 HUD 初始化 |
| `scripts/systems/MemorySystem.gd` | 为 `piety_meteor_impact / piety_meteor_enemy_defeated` 生成正式流程摘要并将其作为全站公开例外传播；旧 `piety_meteor_cast` 仅兼容历史数据 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 填满虔诚、读取快照和按战斗动作秒推进陨石的观察入口 |
| `tools/verify_piety_meteor_ability.gd` | 覆盖产率、暂停 / 封顶、十字架 HUD、选点、落地时序、全站见闻、条件式击杀事件、敌人范围伤害、三类友方零伤害、燃烧和清敌 |

## T0108 / T0109 稳定知识与 LLM 线程生命周期索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_initial_long_memory.json` | 8 人开局前围墙 / 主厅通用器械位置认知；两条六级曲线、每次至多一槽与非扩槽等级；T0223 后不含主厅射程加成 |
| `scripts/systems/LLMBridge.gd` | 异步 HTTP 协作取消、退出拒绝新请求、慢速 / NPC 活动释放、worker 回调抑制与 `_exit_tree()` 线程 join |
| `tools/verify_npc_initial_long_memory.py/.gd` | 锁定 8 人稳定知识迁移、运行态加载、中文知识 UI 和六类长期记忆 payload 注入 / 去重 |
| `tools/verify_npc_initial_long_memory_real.py` | 真实 provider 验证两条槽位曲线、非每级扩槽、主厅双倍射程和守备官直接部署 |
| `tools/verify_llm_bridge.gd`、`tools/verify_llm_bridge_shutdown.gd` | 锁定退出静态合同，并以本地悬挂 TCP 覆盖显式取消、退出收束和线程零残留 |

## T0107 / T0110 / T0112 塔防与战斗基础索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json`、`data/weapon_defs.json`、`data/armor_defs.json`、`data/mount_defs.json` | NPC 差异化战斗基础、装备正负修正与骑兵冲锋参数 |
| `data/defense_device_defs.json`、`data/building_defs.json` | 弩床 / 箭塔同级数值、围墙 / 主厅 8 个通用槽、六级错峰解锁、围墙 Lv.3 / Lv.5 射程增量与主厅 `1.0x` 基础射程 |
| `data/enemy_waves.json` | 5 波 `8 / 16 / 24 / 36 / 48` 弱单体敌群，第 3–7 日每天 18:00 到达，以及穿透、攻速、抬手配置 |
| `scripts/systems/CombatSystem.gd` | 统一属性快照与 `20 / (20 + 有效防御)` 曲线、当前武器熟练度攻速、骑术冲撞伤害、敌人抬手 / 僵直、远程距离带和骑兵冲锋状态机 |
| `scripts/systems/DefenseDeviceSystem.gd` | 双建筑通用槽、器械库存 / HP / 防御 / 穿透 / 攻速、实时宿主射程倍率、自动攻击与敌方受击接口；T0132-P1R3 接收正式只读槽位锚点，使 UI、部署模型和攻击原点共用同一运行态位置，并保留显式 legacy 恢复 |
| `scripts/ui/DefenseSlotPresenter.gd`、`scenes/main/Main.tscn` | 仅显示已解锁空槽的世界圆形 `+`、自收束部署卡与实际射程提示 |
| `scripts/ui/NPCPanel.gd`、`scripts/ui/BuildingPanel.gd`、`scripts/world/DefenseDeviceView.gd` | NPC 最终战斗属性、逐级升级收益 / 槽位提示、建筑槽位兼容入口；T0132-P4a/P4b 起弩床与箭塔均使用正式模型和攻击动作 |
| `tools/verify_t0107_combat_foundation.gd` | 综合覆盖属性、成长、装备、双建筑槽、Prompt 隔离、弱敌群和骑兵冲击 |

## T0106 全量紧凑短期记忆索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/MemorySystem.gd` | 继续保存完整权威事件 / 见闻、稳定 ID 和原始 payload；熟睡总结只轮转快照索引 |
| `scripts/systems/LLMBridge.gd` | 六类 payload 统一投影当前索引全部亲历 / 见闻；输出 `summary + details`，压缩计划段并省略重复大结构 |
| `scripts/systems/DailyReflectionSystem.gd` | 用相同事件压缩器构造带 `memory_kind` 的完整反思快照 |
| `backend/schemas/common.py`、`backend/services/model_adapter.py` | Schema 接收 `details`；供应商边界再次白名单化记忆项，并为反思删除重复短期记忆副本 |
| `data/prompts/*_system_prompt.txt` | 六类正式 Prompt 统一声明“全部当前短期索引、非最近 N 条”及紧凑字段语义；旧判别文件仅保留兼容说明 |
| `scripts/ui/GMPanel.gd` | “短期记忆 / LLM”同时显示权威原始计数与模型实际读取的全量紧凑投影 |
| `tools/verify_full_compact_short_memory.gd`、`tools/verify_short_memory_provider_projection.py` | 覆盖六类 Godot / provider 输入的全量、顺序、分类、压缩和去重边界 |
| `tools/verify_full_compact_short_memory_real.py` | 用第 8 条之前的缺铁因果、后续 12 条事件和当前 20 铁验证真实模型的时间因果读取 |

## T0105B 弥撒跨小时完成优先索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 识别主持者 / 参礼者的 active 弥撒承诺；参礼祈祷计时到期后继续等待，并在弥撒结束时按“恢复祈祷 → 必要时完成祈祷”顺序结算 |
| `scripts/systems/DailyPlanSystem.gd` | 整点不切走 active `lead_mass` 或 `mass_attendance`，保存当前小时待执行计划；弥撒结束后按既有服务依赖顺序统一派发 |
| `tools/verify_service_dependency_interruptions.gd` | 隔离真实后端，覆盖主持 / 参礼跨小时、祈祷先到期、结束事件顺序、待执行计划和普通工作不受保护 |

## T0105A 弥撒结束事件语义索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 主持者自然完成时发出 `mass_completed`；T0105B 后不再由计划小时边界强制完成 |
| `scripts/systems/DailyPlanSystem.gd` | 区分普通整点接管与外部中断；T0105B 后整点改为等待弥撒自身完成 |
| `scripts/systems/MemorySystem.gd` | 继续按结构化 trigger 确定性区分“弥撒结束”与“因主持中断而结束”，不从自由文本猜测 |
| `tools/verify_service_dependency_interruptions.gd` | 覆盖自然完成、跨小时等待后完成和对话中断三条路径的事件、摘要、祈祷席与模式 |

## T0103 NPC-NPC 重复收尾 Prompt 索引

| 文件 | 当前职责 |
|---|---|
| `data/prompts/dialogue_system_prompt.txt` | 明确软阈值不是最低 / 目标轮数；已解决或只能复述时当轮短收尾，禁止为续聊制造新事项 |
| `scripts/systems/DialogSystem.gd`、`scripts/systems/LLMBridge.gd` | 构造与系统模板同口径的动态 `soft_round_guidance`，继续透传无硬上限与结构化结束字段 |
| `tools/verify_dialogue_prompt.py`、`tools/verify_llm_bridge.gd`、`tools/verify_dialogue_invitation_contract.gd` | 锁定系统模板、LLMBridge fallback 与 DialogSystem 会话 guidance 的同口径防复述规则 |
| `tools/verify_npc_npc_dialogue_real.py` | 真实 provider 覆盖邀请接受 / 拒绝、第 6 轮兜底，以及截图铁匠铺、诊所、马厩已解决话题的当轮结束与相似度检查 |

## T0102 建筑面板标签隐藏与玩家显示本地化索引

| 文件 | 当前职责 |
|---|---|
| `data/building_defs.json` | 为 5 个旧生产建筑补齐中文初始位置名与升级位置前缀；内部 `id / type / tags` 不变 |
| `scripts/ui/BuildingPanel.gd` | 不再显示建筑标签；逐位置优先显示配置中文名，并为未知位置、资源、成员与马匹位置提供中文保底 |
| `scripts/ui/NPCPanel.gd` | 从 ActionSystem 配置读取正常行动中文名，并为移动、未知行动、行为模式与计划来源提供中文显示 |
| `scripts/ui/HUD.gd` | 隐藏装备系统实现类名，并让未知资源显示中文保底 |
| `tools/verify_building_panel_workstations.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_hud_resources.gd` | 覆盖标签隐藏、初始 / 升级位置中文、内部键不泄漏及 UI 状态回归 |

## T0101 守备官背景知识与回答边界索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_initial_long_memory.json` | 为 8 名 NPC 的 `guard_officer` 主体保存职责、三年前到站、来站前经历未知、开局前尽责和睦四条根本知识 |
| `data/prompts/dialogue_system_prompt.txt` | 身份追问回答未知；三年旧事只给低细节总体结论，禁止举例 / 引语 / 具体共同经历并立即转回当下 |
| `data/prompts/daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt` | 允许参考低细节共同背景，但禁止补全过去或把和睦扩张为无条件服从 / 信任 |
| `data/prompts/daily_reflection_system_prompt.txt` | 不把守备官自我追问当成披露；后来明确自述只记录为“守备官自称……”的 NPC 主观认知 |
| `tools/verify_npc_initial_long_memory.py/.gd`、`tools/verify_dialogue_prompt.py` | 覆盖 8 人四关系、250 条图谱、六类 payload、玩家知识面板和 provider 投影 |
| `tools/verify_guard_officer_background_dialogue_real.py` | 真实 provider 验证身份未知、三年前到站、尽责和睦 / 无旧事 / 转题 |

## T0100 NPC 宗教信仰字段索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 为 8 名初始 NPC 保存唯一精简 `religion="天主教"`；现有背景无需改写 |
| `scripts/core/NPCPromptProfile.gd` | 在 10 项共用人物字段中定义“宗教信仰”，同时服务对话 `npc_setting` 与 NPCPanel【背景】 |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/common.py` | 把 `religion` 注入并保留在六类正式共享 `NPCIdentity`，不进入权威结算 |
| `data/prompts/*_system_prompt.txt` | 只在相关话题 / 经历中自然参考信仰，不让其覆盖个性、职业或程序事实 |
| `tools/verify_npc_character_profiles.gd`、`tools/verify_npc_initial_long_memory.gd`、`tools/verify_npc_panel_state.gd` | 覆盖 8 份档案、六类 payload 与玩家背景弹窗 |
| `tools/verify_npc_character_dialogue_real.py` | 用真实 provider 逐人核验宗教字段与职业声音 |

## T0099 对话记录、快捷键与攻击确认索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/NPCPanel.gd` | 守备官对话记录只按日期生成 `【第X天】` 分组，保留时间排序、完整转写与全局档案只读边界 |
| `scenes/main/Main.tscn`、`scripts/ui/DialogPanel.gd` | 提供 Tab 应征 toggle 快捷键与每次打开后的首次攻击确认，确认后仍复用 DialogSystem 权威攻击入口 |
| `tools/verify_npc_dialogue_history_ui.gd`、`tools/verify_dialogue_ui.gd` | 覆盖纯日期分组、快捷键禁用边界、取消 / 确认 / 后续攻击和重新打开重置 |

## T0098 祈祷 / 弥撒合并索引

| 文件 | 当前职责 |
|---|---|
| `data/action_defs.json` | 只定义 `pray_at_chapel / lead_mass`；祈祷不再依赖或互斥主持弥撒 |
| `scripts/systems/ActionSystem.gd` | 在同一祈祷 active 中维护 `personal_prayer / mass_attendance`，主持开始 / 结束时原地转换并保留位置与进度 |
| `scripts/systems/MemorySystem.gd` | 注册并摘要 `prayer_joined_mass / prayer_resumed_alone`，沿小教堂 `local_public` 传播 |
| `scripts/systems/DailyPlanSystem.gd`、`scripts/systems/LLMBridge.gd` | 移除独立参加弥撒的排序、候选、依赖和失败归一化 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt`、`data/prompts/plan_revision_judgement_system_prompt.txt`、`data/prompts/dialogue_system_prompt.txt` | 只提示选择祈祷后程序会自动参礼 / 恢复独祷，不再要求教堂失败替代 |
| `tools/verify_service_dependency_interruptions.gd`、`tools/verify_mass_prayer_runtime.gd` | 覆盖四类起始 / 转换、pending 保留、正常 / 异常结束、事件广播及不重估 |
| `tools/verify_mass_prayer_revision_real.py`、计划 / 对话 Prompt 专项 | 验证真实对话承诺修订只选择 `pray_at_chapel`，旧行为不再暴露 |

## T0097 计划模型决策编译索引

| 文件 | 当前职责 |
|---|---|
| `backend/services/model_adapter.py` | 按 action 候选读取 `location_id / target_npc_id / building_id` 中真正必需的选择，丢弃其余模型字段，并编译现有完整 `PlanItem` |
| `backend/app.py` | 对缺失 / 非法的地点、NPC、建筑决策给出按行为区分的动态白名单错误，继续校验完整内部候选 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 用正向最小决策协议替代 action kind 回显与逐字段禁止清单 |
| `tools/verify_plan_action_contract.py` | 覆盖固定行为噪声丢弃、已移除行为拒绝、三类目标字段、Mock 编译和完整响应不变 |
| `tools/verify_plan_day_prompt_real.py`、`tools/verify_mass_prayer_revision_real.py`、`tools/verify_workstation_dialogue_revision_real.py` | 验证真实 provider 的建筑、合并后祈祷和 NPC 目标最小输出 |

## T0095/T0096 Pending 与熟睡总结水位索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 统一 pending 暂停闸门、抵达提交条件、逻辑 tick 暂停保护与单次失效 |
| `scripts/npc/NPC.gd`、`scripts/systems/NPCSystem.gd` | 暂停保留物理路线；到达后提交地点事实；日记保存窗口标签、触发时刻和记录范围 |
| `scripts/systems/MemorySystem.gd` | 原子读取短期正文 + 稳定 ID，并只轮转成功请求快照内的 ID |
| `scripts/systems/DailyReflectionSystem.gd` | 维护 21:00 窗口、上次成功内容终点、本次请求快照和“接到守备命令的第N天”归属 |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/npc_ai.py`、`data/prompts/daily_reflection_system_prompt.txt` | 传输 / 校验 / 解释 `summary_window + reflection_period`，限制模型回顾范围 |
| `scripts/ui/NPCPanel.gd` | 优先显示新 `record_label`，兼容旧“第N天”与开局前日记 |
| `tools/verify_pending_action_pause_resume.gd` | 穷尽固定地点目录与目标行动的暂停、抵达临界、恢复和单次失败；正式菜园夹具走真实 NavigationServer 到田畦并验证 reservation→occupancy 单次提交 |
| `tools/verify_daily_reflection_system.gd`、`tools/verify_daily_reflection_*.py` | 覆盖异步增量保留、跨夜归属、Schema / Mock / Prompt / 真实 provider |

## T0094 睡眠语境、教堂到达、对话记录与床位显示索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 逐项显示床位实时空闲 / 占用，不暴露固定归属 |
| `scenes/main/Main.tscn`、`scripts/ui/NPCPanel.gd` | 在对话右侧提供“记录”，从全局事件档案按日期 / 时间显示守备官会话；T0099 起不再附加历史波次阶段 |
| `scripts/systems/DialogSystem.gd`、`scripts/systems/LLMBridge.gd` | 在真正打断前构造并仅向目标 NPC 对话请求传递 `interrupted_activity_context` |
| `backend/schemas/npc_ai.py`、`data/prompts/dialogue_system_prompt.txt` | 校验临时活动上下文，并要求睡眠 NPC 正确理解被叫醒与暂定恢复 |
| `scripts/systems/ActionSystem.gd`、`scripts/systems/NPCSystem.gd` | 固定地点 / 教堂最终到达守卫与移动中断地点收束；旧弥撒祈祷失败已由 T0098 替代 |
| `scripts/systems/DailyPlanSystem.gd`、`data/prompts/dialogue_plan_revision_judgement_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 把明确谈妥的当下弥撒承诺映射为当前小时祈祷修订与可靠派发 |
| `scripts/systems/DailyReflectionSystem.gd` | 维护 21:00 锚定窗口、跨中断睡眠累计、成功去重和扩展调试快照 |
| `tools/verify_fixed_dormitory_beds.gd`、`tools/verify_npc_dialogue_history_ui.gd` | 覆盖固定床规则与隐藏归属文案、历史筛选 / 分组 / 长记录滚动 |
| `tools/verify_mass_prayer_runtime.gd`、`tools/verify_mass_prayer_revision_real.py` | 覆盖教堂到达守卫、祈祷模式转换和真实计划续接 |
| `tools/verify_dialogue_sleep_summary_boundaries.gd`、`tools/verify_daily_reflection_system.gd`、`tools/verify_sleep_interruption_dialogue_real.py`、对话 Schema / Prompt 专项 | 覆盖临时睡眠语境、21:00 窗口累计、完成去重和真实回复 |

## T0092 LLM 等价精简索引

| 文件 | 当前职责 |
|---|---|
| `backend/services/model_adapter.py` | 投影最小 provider 请求、生成动态最小输出合同，并补齐完整游戏响应 |
| `scripts/systems/LLMBridge.gd` | 避免重复发送默认日计划规则，只保留显式自定义规则 |
| `data/prompts/*.txt` | 六类正式调用只要求不可推导的输出，并保留有效人物 / 现场判断规则 |
| `tools/verify_llm_contract_compaction.py` | 量化六类输入与 provider 输出字符缩减，检查投影不含 `null` |
| `tools/verify_*prompt*.py`、`tools/verify_dialogue_business_contract.py`、`tools/verify_plan_action_contract.py` | 验证最小模型输出可补齐、真正业务错误仍被拒绝 |

## T0091 `talk_to_npc` 目标驱动合同索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd` | 构造只含目标 NPC、不含地点的对话行动候选 |
| `scripts/systems/DailyPlanSystem.gd` | 导入模型计划时不保存对话地点，只把目标 NPC 交给运行时 |
| `scripts/systems/ActionSystem.gd` | 按目标 NPC 实时位置接近、追踪与有限重定向，不依赖计划地点 |
| `backend/app.py` | 向模型剥离对话候选地点，并校验 T0097 编译后的 action + NPC target |
| `backend/services/model_adapter.py` | 读取 provider 的 `target_npc_id`、丢弃冗余地点并编译内部对话目标 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 区分固定地点行动与目标驱动对话 |
| `tools/verify_plan_action_contract.py`、`tools/verify_plan_action_catalog.gd`、`tools/verify_npc_npc_plan_action.gd` | 覆盖候选省略地点、冗余字段丢弃与动态执行 |

## T0089 教堂失败后计划修订索引（已由 T0098 废止）

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 精确 `failure_id` 仍服务其他真实行动失败；教堂模式转换不再写失败 |
| `data/prompts/plan_revision_judgement_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 已移除教堂双向失败替代规则 |
| `tools/verify_service_dependency_interruptions.gd`、`tools/verify_mass_prayer_runtime.gd` | 改为验证模式转换不产生失败或修订请求 |

## T0088 建筑工期、时间显示与友军颜色索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/TimeSystem.gd` | 统一 HUD 时钟及剩余时长的正常分钟精度 / LLM 慢速秒精度格式 |
| `scripts/systems/BuildingSystem.gd` | 保留作业权威秒数，并提供稳定总工期与显示口径剩余时长 |
| `scripts/systems/MemorySystem.gd` | 在建筑外部状态变化中传播 active job 与可读总工期，不逐 tick 广播剩余时间 |
| `scripts/systems/LLMBridge.gd` | 向六类 NPC 请求投影无裸秒数的 repair / upgrade job 可读上下文 |
| `scripts/ui/HUD.gd`、`scripts/ui/BuildingPanel.gd` | 监听慢速状态切换并立即刷新时钟、波次与建筑剩余时间 |
| `scenes/npc/NPC.tscn`、`scripts/npc/NPC.gd`、`scripts/ui/NPCPanel.gd` | 分离世界姓名 / 状态标签，并把入伍 NPC 姓名显示为淡绿色 |

## T0085 升级协助完成后的计划重估索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd` | 计划 Schema 往返优先保留显式 `target.location_id`，统一把 `assist_upgrade` 计入工作统计，并把 6 阶段下限表述为软建议 |
| `scripts/systems/DailyPlanSystem.gd` | 为已结束的协助目标构造本轮失败上下文，并移除日计划 / 修订应用层的工作数量硬拒绝 |
| `scripts/systems/BuildingSystem.gd` | 升级 / 修复协助正常结束时清空陈旧行动失败上下文 |
| `backend/app.py` | 保留小时、白名单、目标 / 地点与即时行动等业务校验，移除 plan_day / revise_plan 的最低工作数量拒绝 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt`、`data/prompts/plan_revision_judgement_system_prompt.txt` | 将通常至少 6 个工作阶段保留为强规划建议，并明确不能为凑数扩大修订范围 |
| `tools/verify_building_upgrade_action_failure.gd`、`tools/verify_daily_plan_system.gd`、`tools/verify_plan_action_contract.py` | 覆盖升级结束重估、室外地点、工作计数与低工作量合法计划 |
| `tools/verify_upgrade_assist_real.py` | 使用真实 provider 验证升级结束后恢复诊所工作的修订 |

## T0084 固定宿舍床位索引

| 文件 | 当前职责 |
|---|---|
| `data/building_defs.json` | 按叙事到站顺序把床位 1–8 配置给艾达、托马、布鲁诺、伊沃、格伦、欧文、马塞尔、莉娜，床位 9–10 保留未分配 |
| `scripts/systems/BuildingSystem.gd` | 在通用位置申请中执行专属位置约束，并把归属与运行时占用分开维护 |
| `scripts/systems/ActionSystem.gd` | 继续复用睡眠生命周期，并在位置失败上下文保留固定 / 保留位信息 |
| `scripts/ui/BuildingPanel.gd` | 只读显示床位实时空闲 / 占用；T0094 起不显示专属归属 |
| `tools/verify_fixed_dormitory_beds.gd` | 覆盖叙事顺序、乱序 / 重复分配、空余床、真实睡眠复用和隐藏归属后的宿舍面板文案 |

## T0083 应征结果反馈与事件标题索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/DialogSystem.gd` | 将合法 `accept / reject` 绑定到产生结果的具体 NPC 历史回复，不修改真实回复文本 |
| `scripts/ui/DialogPanel.gd` | 在对应回复下方渲染绿色对勾接受行或红色叉号拒绝行 |
| `scripts/systems/MemorySystem.gd` | 以“守备官与 XX 对话”作为完成会话全文摘要标题，正文仍只转写真实发言 |
| `tools/verify_dialogue_ui.gd`、`tools/verify_dialogue_session_lifecycle.gd` | 覆盖两种彩色富文本、逐回复元数据、精简标题与全文保留 |

## T0082 多轮会话事件与应征锁索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/DialogSystem.gd` | 维持会话内应征 toggle，首次应征消息后永久锁定本场取消，并让锁定会话挂起超时按完成收口 |
| `scripts/ui/DialogPanel.gd` | 投影 sticky toggle、应征锁 disabled 状态与不可取消 tooltip |
| `scripts/systems/MemorySystem.gd` | 从完成会话的 `dialogue_text` 逐句生成完整确定性 summary，保持单事件与单次广播 |
| `scripts/ui/NPCPanel.gd` | 继续通过通用事件摘要显示完整会话，无第二套对话详情数据 |
| `tools/verify_dialogue_session_lifecycle.gd`、`tools/verify_dialogue_ui.gd` | 覆盖两轮四句单事件、NPC 事件库全文、sticky 开关、系统 / UI 取消锁和挂起超时完成 |

## T0081 统一生活消耗与协助经验索引

| 文件 | 当前职责 |
|---|---|
| `data/activity_needs.json` | 生活数值边界、每小时速率、行为模式映射与 idle / movement 默认档位的唯一配置源 |
| `data/action_defs.json` | 25 个行为各声明唯一 `needs_profile`；三类协助声明 `timed_experience` |
| `scripts/systems/NPCNeedsSystem.gd` | 按有效逻辑秒解析档位、累积小数、钳制边界、截断行动有效时间并驱动协助经验 |
| `scripts/systems/ActionSystem.gd` | 移除旧生活扣除；保留吃饭正向恢复；按配置累计并写入工程 / 医术成长 |
| `scripts/systems/NPCSystem.gd` | 提供协助治疗到 30% 复苏阈值前的精确有效秒数 |
| `scenes/main/Main.tscn` | 在 TimeSystem 后优先挂载 NPCNeedsSystem，使 tick 读取推进前快照 |
| `tools/verify_activity_needs_framework.gd`、`tools/verify_assist_timed_experience.gd` | 穷尽行动 / 行为模式，并覆盖三类协助的有效时间经验 |

## T0080 建筑门口失败与升级协助认知索引

| 文件 | 当前职责 |
|---|---|
| `scripts/core/EventBus.gd`、`scripts/systems/NPCSystem.gd` | NPC 抵达不可进入建筑时先完成门口落点收束，再广播带到达事实的 `npc_building_entry_failed` |
| `scripts/systems/ActionSystem.gd` | 保留赶路中的 pending 行动；在门口事件后写唯一结构化失败；室内 active 仍在升级开始时立即中断 |
| `scripts/systems/LLMBridge.gd` | 投影实时升级 / 修复布尔状态，并把 `assist_upgrade` 描述为广场室外、无需入内、当前可用且计入劳动 |
| `scripts/systems/DailyPlanSystem.gd`、`backend/app.py` | 在 Godot 规则计划、日计划 endpoint 与正式修订校验中把 `assist_upgrade` 计为工作阶段 |
| `data/prompts/dialogue_system_prompt.txt`、`data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_judgement_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 统一升级协助的室外可执行语义、工作量语义和同建筑失败后的优先考虑规则 |
| `tools/verify_building_upgrade_action_failure.gd`、`tools/verify_dynamic_station_context.gd` | 覆盖路上不失败、门口失败、active 立即失败、实时升级状态和动态协助候选 |
| `tools/verify_plan_revision_endpoint.py`、`tools/verify_upgrade_assist_real.py` | 覆盖 Mock / endpoint 工作阶段校验及真实 provider 对话与正式修订选择 |
| `game_design.md`、`docs/AI_NPC_SYSTEM.md`、`docs/ECONOMY_AND_BUILDINGS.md` | 固化非全知门口判定、室内清退和室外协助升级边界 |

## T0079 当前计划连续时段显示索引

| 文件 | 当前职责 |
|---|---|
| `scripts/ui/NPCPanel.gd` | 隐藏与行动名相同的重复 `reason`，按完整展示语义合并连续小时，并按合并后的可见时段计算当前标记与首次滚动位置 |
| `tools/verify_npc_panel_state.gd` | 覆盖 `13:00–16:00` 合并、重复说明隐藏、不同说明拆段、当前时段标记、刷新与 0 点 / 1 点边界 |
| `game_design.md`、`docs/UI_UX.md` | 固化当前计划只读合并显示、重复说明隐藏和底层 24 小时权威计划不变的设计边界 |

## T0078 NPC 主动交涉收口索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/DialogSystem.gd` | 识别 NPC 发起的主动守备官会话，权威拒绝取消；挂起超时按完成收口；向计划判别传递 `proactive_talk` |
| `scripts/systems/DailyPlanSystem.gd` | 仅在结束时当前项仍为 `seek_guard_officer` 时，把当前小时加入 `required_revision_hours`，并复用统一即时 / deferred 派发 |
| `scripts/ui/DialogPanel.gd` | 主动交涉时禁用取消按钮并显示专用 tooltip，守备官主动普通会话保持可取消 |
| `backend/app.py` | 将程序指定但模型遗漏的 required 小时权威并入判别响应，并通过 `model_normalizations` 公开来源 |
| `data/prompts/plan_revision_judgement_system_prompt.txt` | 解释主动找守备官交涉完成后必须重排当前阶段，后续仍从正常候选选择 |
| `tools/verify_npc_proactive_talk.gd` | 覆盖取消锁、超时完成、必选当前小时、正式修订和新行动立即开始 |
| `tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_dialogue_plan_revision_judgement_real.py` | 覆盖程序归并、Prompt / Mock 及真实 provider 的主动交涉 required 小时 |

## T0076 对话跨小时延续与当前计划落地索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 保存日计划对话来源，普通同日跨小时保留接近 / 等待与预约，公开只读 carryover 快照；同小时替代、跨日和权威失效仍产生结构化失败 |
| `scripts/systems/DialogSystem.gd` | 让自主邀请 / 正式会话继承计划来源，并把发起者、目标和自主标记传给对话后判别；普通整点不自行结束会话 |
| `scripts/systems/DailyPlanSystem.gd` | 整点重建 pending / active 对话屏障；发起者判别必选当前小时；所有当前小时修订共用立即派发与可靠 deferred marker |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/npc_ai.py`、`backend/app.py` | 构造、校验 `required_revision_hours`，保留精确选时和正常动态候选合同 |
| `backend/services/model_adapter.py`、`data/prompts/plan_revision_judgement_system_prompt.txt` | 正式 Prompt、紧凑重试与显式 Mock 都要求响应包含全部 required 小时 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 只读 `dialogue_carryover` 查看 pending / active / deferred 状态，替换旧普通跨小时过期扫描入口 |
| `tools/verify_npc_npc_dialogue_edges.gd`、`tools/verify_npc_npc_plan_action.gd` | 覆盖等待 / 正式会话跨小时、发起者必改当前小时、双人屏障和结束后新小时派发 |
| `tools/verify_plan_revision_remaining_day.gd` | 覆盖其他修订来源的当前小时直接执行、对话屏障及行为模式解除后 deferred 执行 |
| `tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_dialogue_plan_revision_judgement_real.py` | 覆盖 Schema / endpoint / Mock / Prompt 与真实 provider 的 required 小时及正式当前小时修订 |

## T0093/T0086 提前完成行动连续续接索引

| 文件 | 当前职责 |
|---|---|
| `data/action_defs.json` | 以 `reevaluate_current_hour_on_completion` 标记协助修理 / 升级 / 治疗、病床治疗与饮酒完成后需重排连续计划段；字段名保留以兼容既有数据 |
| `scripts/systems/DailyPlanSystem.gd` | 识别不同成功结果，延迟确认小时边界，从当前小时收集连续相同 action + target，直接发起 `action_completed` 正式修订，拒绝当前小时原样重复并立即派发新行动 |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/npc_ai.py` | 在 Godot 规范化与后端 Schema 中保留 `action_completed` 合法枚举 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_judgement_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt` | 用游戏时间、建筑总工期 / 剩余时间约束安排范围；正式修订识别连续完成段 |
| `scripts/ui/HUD.gd` | 处理主键盘数字行 `1 / 2 / 3 -> x1 / x2 / x4`，排除小键盘、修饰键和文本输入焦点 |
| `tools/verify_plan_completion_reevaluation.gd` | 覆盖五类配置 / 完成结果、连续三小时边界、重复拒绝、即时执行、单小时、跨小时接管与倍速快捷键 |
| `tools/verify_upgrade_assist_real.py` | 用真实 provider 验证连续三小时 `action_completed` 升级协助修订且不使用 fallback |

## T0075 计划行动完成策略索引

| 文件 | 当前职责 |
|---|---|
| `data/action_defs.json` | 为全部 25 个配置行为声明 `completion_policy`，作为新增行为必须选择的完成语义 |
| `docs/DATA_SCHEMA.md`、`docs/AI_NPC_SYSTEM.md` | 定义合法策略枚举、配置约束与当前全部 action id 的穷尽分类 |
| `scripts/systems/ActionSystem.gd` | 校验完成策略枚举及计划可选性，公开只读策略 / 配置错误；继续负责实际行动与周期结算 |
| `scripts/systems/DailyPlanSystem.gd` | 生产成功后 deferred 续开；单次行为跨计划版本按小时去重；整点相同行动 / 目标保留进度、不同项中断切换 |
| `tools/verify_plan_action_completion_policy.gd` | 穷尽 25 项完成策略和 5 项完成后重估标记；以正式菜园实体到位后的 active 为起点，覆盖生产续开、完成 / 开始事件顺序、同 / 异行动跨小时与未完成产出边界 |
| `tools/verify_plan_slot_dispatch_once.gd` | 覆盖单次吃饭提前完成、下一小时可执行及同小时替换计划版本仍不重放 |
| `tools/verify_daily_plan_system.gd`、`tools/verify_player_dialogue_plan_resume.gd` | 规则计划在 NPC 实际抵达正式田畦后验证生产续开与幂等采用，并回归对话恢复后的单次行为边界 |

## T0074 制造目标提醒索引

| 文件 | 当前职责 |
|---|---|
| `scenes/main/Main.tscn` | 在 `UI` 下挂载 `CraftingTargetAlerts`，保留既有 HUD 与对象面板层级 |
| `scripts/ui/CraftingTargetAlertPresenter.gd` | 只读制造项目快照，把两个建筑名称位置投影到屏幕并维护红色提醒、tooltip、点击与目标变化显隐 |
| `scripts/systems/BuildingSystem.gd` | 提供世界点击与提醒按钮共用的正式 `select_building(...)` 入口；继续广播既有 `building_clicked` |
| `tools/verify_crafting_target_alerts.gd` | 覆盖双提醒、颜色 / 位置 / tooltip、真实鼠标点击、对应面板和目标显隐状态机 |

## T0073 指令面板文案与计划影响验收索引

| 文件 | 当前职责 |
|---|---|
| `scenes/main/Main.tscn`、`scripts/ui/OrderPanel.gd` | 提供无 placeholder 的自由文本输入、精简标题与世界内叙事说明；发布仍只提交软性指令 |
| `tools/verify_npc_order.gd` | 覆盖新标题、说明、空 placeholder 及既有指令存储 / 事件合同 |
| `tools/verify_order_plan_effect.gd` | 确定性覆盖面板发布、`current_order` 正式 payload 注入与权威 24 小时计划合并 |
| `tools/verify_order_plan_effect_real.gd` | 使用已配置真实 provider 验证新指令实际改变 NPC 当前小时计划，拒绝 Mock / fallback |

## T0072 应征即时刷新与软性指令入口索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/DialogSystem.gd` | 在合法接受回复进入历史后立即提交权威入伍状态；会话完成仍负责记录完整对话事件，但不再延迟或重复应用征召 |
| `scripts/ui/NPCPanel.gd` | 监听既有 `npc_state_changed` 即时刷新“已入伍”和“指令”入口；个人酒标签精简为“酒” |
| `scripts/ui/OrderPanel.gd`、`scripts/systems/NPCSystem.gd` | 既有自由文本软性指令输入、权威 `current_order` 保存、事件与计划重评估链路 |
| `tools/verify_dialogue_ui.gd`、`tools/verify_dialogue_session_lifecycle.gd`、`tools/verify_wartime_dialogue.gd` | 覆盖普通 / 战时应征即时生效、面板即时刷新及取消不回滚边界 |
| `tools/verify_npc_order.gd`、`tools/verify_npc_panel_interactions.gd` | 覆盖新入伍 NPC 指令输入闭环和精简酒标签 |

## T0071 NPC-NPC 对话私有上下文隔离索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd` | 只为回复者构造完整 NPCContext；说话者仅投影姓名、外表、健康和已说出口文本；对话行动候选不暴露目标实时地点 / 行动 / 入伍状态 |
| `backend/schemas/npc_ai.py`、`data/prompts/dialogue_system_prompt.txt` | 拒绝非空 `speaker_npc / speaker_context.state`，并约束回复者只能使用自己的信息空间 |
| `tools/verify_dialogue_private_context_boundary.gd` | 用格伦独有的私有铁盔批次标记审计伊沃的对话及其余五类 payload |
| `tools/verify_dialogue_private_context_real.py` | 使用真实 provider 验证回复者不会声称知道对方未公开安排 |
| `tools/verify_backend_schemas.py`、`tools/verify_dialogue_prompt.py` | 覆盖 Schema 拒绝和 Prompt 边界文本 |

## T0070 全员名册、职业知识与仓库容量索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd`、`backend/schemas/common.py`、六份正式 Prompt | 向六类请求提供全体登记成员及必填 `recruited / in_station` 标签；仓库满载工作失败归一为资源不足 |
| `tools/station_context_fixture.py`、`tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_npc_roster_knowledge_real.py` | 覆盖 fixture、Schema、六类动态 payload、离站成员保留与真实模型名册 / 艾达知识理解 |
| `data/npc_initial_long_memory.json` | 保存 226 条种子关系；新增训练场、诊所、马厩、食堂职业细节，并把 8 条仓库关系更新为按等级扩容 / 受袭次序 |
| `data/resource_defs.json`、`scripts/systems/ResourceSystem.gd` | 配置并权威计算六项仓库容量，提供剩余空间、批量预检和原子入库 |
| `scripts/systems/ActionSystem.gd`、`scripts/systems/MerchantSystem.gd` | 在工作产出和购买扣费前预检容量，满载失败不产生部分结算 |
| `scripts/ui/BuildingPanel.gd`、`scripts/ui/HUD.gd` | 仓库面板显示六项上限，左上角受限资源悬停显示上限 |
| `tools/verify_warehouse_capacity_ui.gd`、`tools/verify_work_output_framework.gd`、`tools/verify_merchant_trade_system.gd` | 覆盖等级容量、UI、满载工作与购买原子失败 |

## T0077 LLM 日预算与 GM 运行成本索引

| 文件 | 当前职责 |
|---|---|
| `backend/services/llm_cost_ledger.py` | 逐 provider 尝试追加人民币 / token JSONL；按上海自然日重放，维护进程内并发费用预留，并在账本故障时失败关闭 |
| `backend/services/model_adapter.py` | 读取 DeepSeek 缓存命中 / 未命中 usage，使用官方人民币价结算每次尝试；供应商调用前预留每日额度并把 session / daily 快照暴露给 debug endpoint |
| `backend/.env.example` | 记录 V4 Flash 官方人民币单价、每日 20 元、上海时区、1.77 元单次预留和两个本地日志路径 |
| `scripts/systems/LLMBridge.gd` | 为 `/debug/llm_usage` 提供不阻塞主线程的异步查询和完成信号 |
| `scripts/ui/GMPanel.gd` | 在面板顶栏周期显示本次后端运行 token / 人民币与今日持久化金额 / 上限 |
| `tools/verify_api_budget_debug.py` | 覆盖 provider usage、HTTP 429、持久化账本、重建 adapter 后继续拦截和上海时区 |
| `tools/verify_llm_persistent_audit_log.py`、`tools/verify_gm_panel.gd` | 覆盖缓存 token / 人民币 billing 审计，以及 GM 顶栏格式和异步入口 |
| `backend/logs/llm_cost_ledger.jsonl` | 默认本地计费账本；由 `.gitignore` 排除，不属于仓库交付文件 |

## T0069 后端 LLM 持久化审计索引

| 文件 | 当前职责 |
|---|---|
| `backend/services/llm_audit_logger.py` | 以按路径进程内共享锁追加 JSONL；递归脱敏凭据与配置 API Key；写盘失败不阻断业务 |
| `backend/services/model_adapter.py` | 为调用分配 audit id，记录输入、逐次 provider body / 聚合响应、解析结果、usage、fallback 和最终状态，并关联业务校验失败 |
| `backend/app.py` | 把 Pydantic / 业务校验详情和被拒绝模型输出交给审计器；显式 `/mock/model` 复用主后端日志配置 |
| `tools/verify_llm_persistent_audit_log.py` | 使用临时文件与 fake provider 覆盖成功、重试、HTTP 失败、业务无效、Mock 并发、脱敏、默认配置和写盘失败 |
| `backend/logs/llm_calls.jsonl` | 默认本地运行时日志；由 `.gitignore` 排除，不属于仓库交付文件 |

## T0068 T0067 真实 LLM 调用审计包索引

| 文件 | 当前职责 |
|---|---|
| `tools/export_t0067_llm_audit.py` | 只读解析本机 T0067 会话证据，恢复 usage / 原始测试输出，重建静态定向矩阵 provider body，并生成无 Key / 请求头审计包；不调用 provider |
| `docs/audits/T0067_LLM_94_CALLS/README.md` | 说明 94 次调用统计、证据级别、文件导航和不可恢复边界 |
| `docs/audits/T0067_LLM_94_CALLS/call_inventory.csv` | 94 行调用库存；真实 request id 与 aggregate-only 占位明确分列 |
| `docs/audits/T0067_LLM_94_CALLS/SCENARIO_TEXTS.md`、`RESULTS.md` | 汇总 Agent 编写的场景话术与可读结果 |
| `docs/audits/T0067_LLM_94_CALLS/formal_system_prompts/` | 保存战斗判定、对话、日计划三类完整 system Prompt |
| `docs/audits/T0067_LLM_94_CALLS/direct_calls/` | 保存 16 路确定性重建完整 provider body、原始结果和 usage，不含请求头 |
| `docs/audits/T0067_LLM_94_CALLS/raw_outputs/`、`recovered_marker_events.json` | 保存从会话证据恢复的原始测试输出和去重场景事件 |
| `docs/audits/T0067_LLM_94_CALLS/main_usage_*` | 保存 Main 聚合统计、历史尾部 12 条原始记录和按修复语义合并后的 11 个真实请求 |

## T0067 真实战斗心理、日常逃离与挽留验收索引

| 文件 | 当前职责 |
|---|---|
| `backend/schemas/common.py` | 在正式 NPC 状态上下文保留 behavior / combat / strategy / morale / escape 五类权威投影 |
| `backend/app.py` | 对对话响应执行逃离挽留、避战、应征和战时反应的上下文业务校验 |
| `backend/services/model_adapter.py` | 业务输出无效时原地更新同一供应商请求的 usage，避免调用、token 与预算双计 |
| `scripts/systems/CombatSystem.gd` | 低血量迟到结果复验；原子逃离入口调用；复苏续逃失败分流 |
| `scripts/systems/NPCSystem.gd` | 提供行为模式与世界移动的原子提交接口，避免逃离半状态 |
| `scripts/systems/DialogSystem.gd` | 屏蔽避战战时反应、保护暂存结果应用并防止结束会话重入 |
| `tools/verify_combat_psychology_real_game.gd` | 用新 Main 场景、真实波次、装备、伤害和事件测试低血量自然选择与实际应用 |
| `tools/verify_daily_escape_plan_real_game.gd` | 检查日计划逃离候选，并在基准 / 高压真实上下文中测试模型选择 |
| `tools/verify_dialogue_escape_real_game.gd` | 真实 Main 覆盖战时、避战应征、挽留成功和五轮失败；支持 `REAL_DIALOGUE_SCENARIO` 单场景复测 |
| `tools/verify_combat_escape_prompt_real.py` | 用正式 provider 运行受限结果和对话全分支定向矩阵，区分“分支可达”与“自然选择” |
| `tools/verify_backend_schemas.py`、`tools/verify_dialogue_business_contract.py`、`tools/verify_mock_model_adapter.py` | 回归五字段保留、对话业务组合拒绝及业务无效输出 usage 不双计 |
| `tools/verify_low_hp_battle_judgement.gd`、`tools/verify_escape_station_behavior.gd`、`tools/verify_wartime_dialogue.gd` | 回归迟到结果丢弃、计划逃离实际执行、原子移动失败及战时暂存反应完成 |

## T0066 公告牌与当前计划 UI 索引

| 文件 | 当前职责 |
|---|---|
| `data/notice_board_defaults.json` | 保存公告牌日程表黄色建议文案的权威默认值，供 UI 和日程事件 / 见闻共同读取 |
| `scripts/ui/NoticeBoardPanel.gd` | 提供精简后的“通告 / 日程表”双页草稿编辑；隐藏冗余默认说明，保留按需校验 / 发布反馈 |
| `scripts/ui/NPCPanel.gd` | 当前计划首次打开时定位当前行动前两项；保留完整计划、刷新滚动和其他详情模式合同 |
| `tools/verify_notice_board_tabs.gd` | 验证新文案、旧标签缺失、默认状态提示为空，并回归草稿 / 发布 / 广播边界 |
| `tools/verify_npc_panel_state.gd` | 验证 08:00 当前行动第三项定位、00:00 / 01:00 开头夹取及既有详情刷新滚动 |

## T0065 公告牌全站单次广播索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/MemorySystem.gd` | 权威保存公告牌两页；实际变更分别生成 `plaza_notice_changed` / `plaza_schedule_changed`，按事件类型向全站当前可接收见闻的 NPC 广播一次；写入广场入场见闻前剔除公告牌三项 |
| `scripts/ui/NoticeBoardPanel.gd` | 继续维护两页独立草稿 / 发布入口并把成功提示明确为全站 NPC 广播；T0066 后玩家页签名为“日程表” |
| `tools/verify_notice_board_tabs.gd` | 端到端覆盖所有 NPC 跨地点单次接收、两页独立变更检测、未变化不广播，以及后来进入广场不重复获得公告牌内容 |
| `tools/verify_notice_board_input.gd`、`tools/verify_plaza_local_public_broadcast.gd`、`tools/verify_location_info_nodes.gd` | 回归公告牌点击 / 预览、普通广场事件地点边界、公告专用全站边界与无公告牌入场见闻 |

## T0063 守备官赠酒与 NPC 饮酒闭环索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json`、`scripts/systems/NPCSystem.gd` | 在个人 `money` 旁保存非负 `wine`；负责驿站库存赠酒转移及个人资源查询 / 原子扣减 |
| `scenes/main/Main.tscn`、`scripts/ui/NPCPanel.gd` | 在给钱右侧提供给酒数量和按钮，以“酒”标签显示目标 NPC 个人酒库存 |
| `data/action_defs.json`、`scripts/systems/ActionSystem.gd` | 定义并执行 `drink_wine`；本人酒不足时拒绝，成功开始实际扣 1 并记录上下文事件 |
| `scripts/systems/MemorySystem.gd`、`scripts/systems/DailyPlanSystem.gd` | 保存 `wine_given / wine_consumed` 事件与见闻，并把无酒失败规范为资源不足进入既有重估链 |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/common.py`、`backend/app.py` | 同步个人 `money / wine`、`drink` kind、动态候选、背景行为说明及计划个人酒数量业务校验 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 解释饮酒前提、实际扣减和仅通过上下文产生的心理影响；禁止情绪数值和删除记忆 |
| `tools/verify_npc_wine_drinking.gd` | 端到端验证个人酒默认值、赠酒、候选、执行扣减、事件上下文与无酒失败 |
| `tools/verify_npc_panel_interactions.gd`、`tools/verify_dynamic_station_context.gd` | 回归面板给酒 / 见闻与六类正式请求的行为背景目录 |

## T0061 NPC 背景叙事与知识面板收束索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 保存 8 人稳定根本人设、精简 `religion` 与宽松 `speech_style`；不再保存会限定口吻的 `signature_lines` |
| `scripts/core/NPCPromptProfile.gd` | 统一构造背景弹窗与对话 `npc_setting` 的 10 项人物字段，不再提供“代表性表达” |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/common.py` | 为对话、日计划、修改判别、正式修订、战时心理和首次睡眠反思提供同一身份上下文；六类 payload 均含 `religion` 且不携带固定样例句 |
| `data/npc_initial_long_memory.json` | 保存 8 人按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜拼接的宏观身世 / 到站群像、未改动的近日微观日常、统一 `role` 的守备官职责和叙事化建筑常识；T0070 后含 4 条职业关键规则及 8 条按等级扩容仓库关系，共 226 条完整元数据 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 只把 `speech_style` 视为宽松表达习惯；解释前两篇宏观背景、近日时间边界、T0101 四关系守备官种子和实时程序事实优先 |
| `scripts/ui/NPCPanel.gd` | “背景”详情移除代表性表达；“知识”详情只显示中文主体 / 关系 / 值，不显示可信度或更新时间 |
| `scripts/ui/GMPanel.gd` | 不新增入口；既有 `long_memory <npc_id>` 继续显示含 `confidence / day / time` 的完整运行态图谱，用于核对玩家 UI 隐藏而底层保留 |
| `tools/verify_npc_initial_long_memory.py` | 静态校验八人到站时序、前两篇宏观 / 拼图叙事、近日未改、守备官 `role`、建筑叙事化、4 条职业规则、仓库容量语义和 226 条底层元数据 |
| `tools/verify_npc_character_profiles.gd`、`tools/verify_npc_initial_long_memory.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_daily_reflection_system.gd`、`tools/verify_gm_panel.gd` | 5 个 Godot 专项校验档案 / 六类身份上下文无 `signature_lines`、运行态种子、反思追加、GM 原始数据与玩家 UI 隐藏边界；最终最大 payload 字符数为 `battle_judgement=32057 / daily_reflection=29242 / dialogue=48330 / plan_day=47118 / plan_revision_judgement=50053 / revise_plan=49952` |
| `tools/verify_npc_initial_long_memory_real.py` | 真实 DeepSeek `deepseek-v4-flash` 完成 3 次记忆路径调用，0 失败，全部 `fallback_used=false` |

## T0060 NPC 初始长期记忆文案重写索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | T0060 当时保存 7 类根本人设；当前已由 T0061 移除固定代表性表达，只保留宽松职业语气与稳定人物内核 |
| `data/npc_initial_long_memory.json` | T0060 确立 24 篇开局前日记、227 条中文 `value_label` 与每人 25 个知识主体；当前前两篇、守备官和建筑中文叙事已由 T0061 进一步收束，近日记录保持不变 |
| `scripts/systems/LLMBridge.gd` | 向六类正式请求注入唯一规范长期记忆，并把结构化日记投影为带“往昔”或“第 N 天 HH:MM:SS”时间标签的 `list[str]` |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | T0060 确立自然中文、种子时间边界与实时事实优先；当前固定台词和守备官种子口径以 T0061 为准 |
| `tools/verify_npc_initial_long_memory.py` | 当前同时覆盖 T0060 的 8 人 / 24 篇日记 / 25 主体与 T0061 的到站时序、守备官单条职责、建筑叙事化和元数据边界 |
| `tools/verify_npc_character_profiles.gd`、`tools/verify_npc_initial_long_memory.gd` | 当前校验宽松档案文案、运行态种子、时间标签、玩家知识显示和六类 payload 的无固定台词 / 去重 / 隐私边界 |
| `tools/verify_npc_initial_long_memory_real.py` | T0060 当时用真实 provider 追问莉娜、欧文、布鲁诺 3 条记忆路径；T0061 当前版本再次完成 3 次真实调用，0 失败且无 fallback |
| `tools/verify_dialogue_prompt.py`、`tools/verify_plan_day_prompt.py`、`tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_plan_revision_prompt.py`、`tools/verify_battle_judgement_prompt.py`、`tools/verify_daily_reflection_prompt.py` | 分别验证六类 Prompt 都保留自然中文、时间边界和程序权威合同 |

## T0059 NPC 初始长期记忆与根本人设索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 保存 8 人身份、根本人设、职业语气和权威初始状态；`diary / knowledge_graph` 保持空占位，不复制种子记忆 |
| `data/npc_initial_long_memory.json` | 独立保存 8 人各 3 篇开局前日记，以及覆盖 15 建筑、其余人物、守备官和个人故事主体的 `key_value_replace_v1` 初始图谱 |
| `scripts/systems/NPCSystem.gd` | 在生成 NPC 前校验档案与种子 id / 结构，再把日记和知识图谱深拷贝到运行态 |
| `scripts/systems/LLMBridge.gd` | 向六类业务注入规范长期记忆；避免 NPCContext 重复图谱，并阻止对话 participant 复制或泄露私人长期记忆 |
| `backend/schemas/common.py` | `NPCContext.long_term_memory` 作为当前规范字段；旧 `knowledge_graph` 仅保留兼容，Godot 正式 payload 不再填充 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 区分开局前长期记忆与实时事实；T0101 后固定守备官三年前到站、过去未知和低细节尽责和睦背景，并禁止反思补造旧事 |
| `tools/verify_npc_initial_long_memory.py` | 静态校验 8 人、24 篇日记、15 建筑 / 人物覆盖、中文标签、职业详略、开放守备官与六份 Prompt |
| `tools/verify_npc_initial_long_memory.gd` | 加载真实 Main，验证运行态种子、NPC 面板文本与六类 payload 注入 / 去重 / 隐私边界 |
| `tools/verify_npc_initial_long_memory_real.py` | T0059 当时追问莉娜 / 欧文旧往事；当前已由 T0060 的莉娜 / 欧文 / 布鲁诺 3 条新记忆路径覆盖 |
| `tools/verify_daily_reflection_system.gd`、`tools/verify_gm_panel.gd` | 把旧“初始日记为空”假设改为以种子条数为基线，继续验证追加反思与既有长期记忆入口 |

## T0058 NPC LLM 公开资源与升级常识索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd` | 从 ResourceSystem 实时投影五项公开资源；组装六字段 `station_context`；收窄计划类资源兼容字段 |
| `backend/schemas/common.py`、`backend/schemas/__init__.py` | 定义五项严格资源条目及 `StationSceneContext` 完整性校验 |
| `data/station_context.json` | 保存第六条“升级缓慢、协助可加快”世界内规则，不保存运行态资源或目标 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 解释资源白名单、隐藏库存边界、升级常识与各调用职责 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 复用 `station_context` 只读入口显示公开资源与规则 |
| `tools/station_context_fixture.py`、`tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd` | 构造 / 验证资源 Schema、六类实时 payload、隐藏库存排除和规则 |
| `tools/verify_plan_action_catalog.gd`、`tools/verify_station_context_real.py`、`tools/verify_plan_day_prompt_real.py` | 验证英文技术值 / 中文名称、真实资源理解和真实计划选择升级协助 |

## T0057 建筑升级行动失败链路索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 区分指向升级建筑的 pending / active 依赖行动；先清理移动 / 位置，再写带完整中文上下文的 `*_failed_building_upgrading` |
| `scripts/systems/DailyPlanSystem.gd` | 将 `building_upgrading / building_unavailable` 规范为 `target_unavailable`，复用 T0050 判别与精确修订 |
| `tools/verify_building_upgrade_action_failure.gd` | 可控 provider 覆盖路上 pending、进行中 active、失败上下文、第一层判别与非空后的第二层修订 |
| `docs/GM_PANEL.md` | 记录复用“指定行动 → 升级 → plan_request”的验证方式，不新增伪造失败的按钮 |

## T0055 持续活动 / 周期结算常识索引

| 文件 | 当前职责 |
|---|---|
| `data/station_context.json` | 增加世界内持续参与、周期完成后结算、离岗后不自动产出的第五条规则 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 按各自任务禁止把未完成周期或无人参与活动写成已产出 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py` | 在当前六条规则合同中验证持续活动规则随六类 payload 注入，并用真实对话检查菜园离岗后不会自动产出 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 复用既有 `station_context` 只读入口显示包含该规则的当前规则集，不新增按钮或权威逻辑 |

## T0054 NPC LLM 驿站常识上下文索引

| 文件 | 当前职责 |
|---|---|
| `data/station_context.json` | 数据驱动保存精简驿站简介和当前六条世界内规则，不保存人员、建筑、行为或资源运行态副本 |
| `scripts/systems/LLMBridge.gd` | 从 NPCSystem / BuildingSystem / ActionSystem / ResourceSystem 构造唯一顶层六字段 `station_context`，供六类正式 NPC LLM 请求复用；提供只读 debug 快照 |
| `backend/schemas/common.py`、`backend/schemas/__init__.py` | 定义必填非空的人员、建筑、工作模式行为、五项基础资源和规则合同 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 解释完整世界目录、单次候选和程序权威边界，禁止补造名单外成员 / 建筑 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 通过按钮 / `station_context` 命令只读观察运行态上下文，不修改世界事实 |
| `tools/station_context_fixture.py` | 从正式配置构造 Python 测试上下文，避免测试维护第二份建筑 / 行为清单 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py`、`tools/verify_gm_panel.gd` | 覆盖 Schema、六类 Godot payload、全员标签名册、目录来源、叙事规则、GM 入口和真实 provider 语义 |

## T0053 对话等待来源与上下文统一索引（普通跨小时口径已由 T0076 覆盖）

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 保存日计划对话来源元数据；同小时计划被替代、跨日或权威目标失效时释放预约并写完整失败上下文；普通同日跨小时由 T0076 延续 |
| `scripts/systems/DailyPlanSystem.gd` | 日计划对话派发时附加来源项；行动失败优先使用上下文中的旧 `failed_plan_item` 进入 T0050，两阶段链；普通整点 carryover 见 T0076 |
| `scripts/systems/LLMBridge.gd` | 判别、日计划、正式修订和战时心理共用 NPCContext；长期记忆同时含知识图谱和日记 |
| `backend/schemas/common.py` | `NPCContext.long_term_memory={knowledge_graph, diary}` 及兼容知识图谱字段 |
| `backend/schemas/npc_ai.py` | 判别请求继承 StationAwareNPCRequest、必填 NPCContext / 现实条件并支持 `plan_item_superseded` |
| `data/prompts/plan_revision_judgement_system_prompt.txt` | 结合失败事实与人物 / 记忆 / 指令上下文选择精确修订小时，不制定行动 |
| `data/prompts/plan_revision_system_prompt.txt` | 正式修订延续同一人物与长短期记忆，并区分旧失败项 / 当前项 |
| `data/prompts/battle_judgement_system_prompt.txt` | 低血量参战 / 避战 / 逃离心理读取同一长期记忆与人物上下文 |
| `scripts/ui/GMPanel.gd` | T0076 已用只读 `dialogue_carryover` 替换旧 `expire_plan_dialogues` |
| `tools/verify_npc_npc_dialogue_edges.gd` | 回归计划等待续接、普通跨小时延续、预约保留，以及同小时 / 权威失败边界 |
| `tools/verify_action_failure_plan_revision_judgement.gd` | 回归判别 / 正式修订两层失败事实与完整人物上下文 |
| `tools/verify_dynamic_station_context.gd` | 防止日计划 / 修订 / 战时心理丢失共享人设、长短期记忆或地点字段 |
| `tools/verify_gm_panel.gd` | 回归只读 `dialogue_carryover` 命令存在且可安全执行 |

## T0052 计划阶段对话互斥与等待续接索引

| 路径 | 职责 |
|---|---|
| `scripts/systems/NPCSystem.gd` | 公开 `is_npc_plan_llm_active(...)`，以统一 `kind=plan` 识别每日计划、修改判别和计划修订活动 |
| `scripts/systems/DialogSystem.gd` | 玩家草稿 / 首次实际交互拒绝计划中目标；自主邀请启动前返回 `npc_planning`，不取消计划请求 |
| `scripts/systems/ActionSystem.gd` | `talk_to_npc` 目标计划中时保留 pending action、双方预约和开场白，状态清除后延迟续接邀请 |
| `scripts/systems/LLMBridge.gd` | 日计划允许并行计划目标作为稍后对话候选；即时失败修订只提供当前可执行对话目标 |
| `scripts/ui/NPCPanel.gd` | 计划活动期间禁用对话按钮并提示“NPC正在思考”，状态清除后自动恢复 |
| `tools/verify_dialogue_sleep_summary_boundaries.gd` | 玩家入口不取消计划、按钮禁用 / 恢复与既有深睡边界回归 |
| `tools/verify_npc_npc_dialogue_edges.gd` | 自主对话等待期间不请求 / 不失败 / 不释放预约，计划清除后自动邀请 |
| `tools/verify_plan_action_catalog.gd` | 日计划与即时修订对计划中 NPC 的候选差异 |

## T0051 可拖动弹窗与守备官会话生命周期索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/DraggablePanel.gd` | 顶部栏拖动、锚点解除、用户位置保留、视口夹取 |
| `scripts/ui/DialogPanel.gd` | 完成 / 取消 / 挂起 UI、即时消息展示、挂起气泡恢复 |
| `scripts/systems/DialogSystem.gd` | 守备官会话三态权威、整场事件提交、迟到回复丢弃、两小时超时 |
| `scripts/npc/NPC.gd` | 自主对话 / 挂起守备官会话双色头顶气泡 |
| `scripts/ui/NPCPanel.gd` | 对话按钮橙点与挂起会话恢复；主面板 / 记忆详情拖动 |
| `scripts/ui/BuildingPanel.gd` | 建筑面板拖动并与自适应高度共存 |
| `scripts/ui/OrderPanel.gd` | 指令面板拖动；不隐式覆盖活动守备官会话 |
| `scripts/ui/NoticeBoardPanel.gd` | 公告牌窗口拖动 |
| `scripts/ui/MerchantPanel.gd` | 商人窗口拖动 |
| `scripts/ui/HUD.gd` | 装备 / 器械库存详情拖动 |
| `scenes/main/Main.tscn` | 三个会话按钮与 NPC 对话按钮橙点节点 |
| `data/action_defs.json` | 非计划可选运行态 `talk_to_guard_officer` 显示定义 |
| `tools/verify_dialogue_session_lifecycle.gd` | 拖动、即时消息、三态、攻击锁、气泡 / 橙点与超时自动化 |

## T0049/T0050 通用计划判别、精确阶段修订与最新记录定位索引

| 路径 | 职责 |
|---|---|
| `data/prompts/plan_revision_judgement_system_prompt.txt` | 按 `trigger_kind=dialogue|action_failure` 结合权威事实和共享人物 / 长短期记忆 / 指令上下文判断是否需要修改计划，只输出精确 `revision_hours`；空数组表示 0 个阶段 |
| `data/prompts/plan_revision_system_prompt.txt` | 保留既有完整修订上下文，但将输出限制为请求中的 `selected_hours` |
| `backend/schemas/npc_ai.py`、`backend/schemas/__init__.py` | 定义通用 `PlanRevisionJudgementRequest/Response` 及旧对话名兼容别名，并把 `PlanRevisionRequest/Response` 收紧为非空精确小时合同 |
| `backend/app.py`、`backend/services/model_adapter.py` | 提供 `/npc/plan_revision_judgement`（旧对话端点兼容），校验判别 / 修订小时集合，并支持第六类正式 LLM 调用的 Prompt、Mock 与 usage 元数据 |
| `scripts/systems/LLMBridge.gd` | 按触发类型构建含完整共享 NPCContext 的判别 payload、异步调用通用端点；修订 payload 使用同一人物上下文、`revision_scope=selected_hours` 与精确 `revision_hours` |
| `scripts/systems/DialogSystem.gd` | 守备官-NPC 有效会话为目标判别；NPC-NPC 邀请拒绝或正式结束为双方分别判别，并在发起双方请求前登记会话组派发屏障；对话内已提交攻击即使无 NPC 回复也进入同一判别 |
| `scripts/systems/DailyPlanSystem.gd` | 对话与日常行动失败先判别、只合并非空判别选中小时；其他程序触发继续直接受限修订；NPC-NPC 双方链终态后按依赖顺序放行，跨小时玩家对话和行动失败判别终态前延迟旧计划重派；保留真实三次尝试、过期 / epoch 丢弃和单后继队列 |
| `scenes/main/Main.tscn`、`scripts/ui/DialogPanel.gd` | 删除守备官对话“结束后重估计划”开关，由 NPC 判别层统一决定 |
| `scripts/ui/NPCPanel.gd` | 事件库 / 见闻库详情首次打开滚到最底部，打开期间刷新保留玩家阅读位置 |
| `scripts/ui/GMPanel.gd` | 复用既有计划 / LLM 观察入口查看最近判别与精确修订；手动重估只触发当前小时，不增加第二套权威入口 |
| `tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_dialogue_plan_revision_judgement_real.py` | 对话 / 行动失败通用判别层 Schema / Prompt / endpoint、严格第二层范围与真实 provider 验收 |
| `tools/verify_action_failure_plan_revision_judgement.gd` | Godot 行动失败空 / 非空判别、严格小时合并、完整第二层上下文与计划派发屏障专项 |
| `tools/verify_player_dialogue_plan_resume.gd`、`tools/verify_npc_npc_plan_action.gd`、`tools/verify_plan_revision_remaining_day.gd`、`tools/verify_npc_panel_state.gd` | 空集合恢复、双方独立判别、精确小时合并 / 竞态与详情滚动行为回归；A5-P6b-R 后食堂 / 诊所 / 教堂前置均等待实体真实到位，旧文件名保留但合同已改为 selected hours |

## T0047 建筑面板真实点击竞态修复索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 用 fit generation 与每阶段最多 4 帧采样保证透明测量一定收尾；透明阶段递归禁用鼠标，修复 / 升级回调复验面板交互状态 |
| `tools/verify_building_panel_real_click.gd` | Camera3D 投影全部 15 个建筑 ID 的可见点击点，向 Viewport 发送真实鼠标事件，并锁定面板显示与零状态突变 |
| `tools/verify_building_repair_upgrade.gd`、`tools/verify_npc_panel_state.gd` | 按新的有界测量上限等待内容收敛，继续覆盖修复 / 升级与 NPC / 建筑面板互斥 |

## T0046 长期记忆、动态驿站上下文与公告牌索引

| 路径 | 职责 |
|---|---|
| `backend/schemas/common.py`、`backend/schemas/npc_ai.py` | 建立 `StationAwareNPCRequest` 顶层必填上下文；T0070 后人员条目严格要求 `recruited / in_station`，反思响应仅含日记和知识更新 |
| `scripts/systems/LLMBridge.gd` | 从运行态动态构建中文全员名册并保留逃离 / 站外 NPC，以 `in_station=false` 标记；同一构造器覆盖六类业务 payload |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | T0046 建立共享场景与反思输出基础；T0054 已扩充共享场景字段与世界内规则 |
| `scripts/systems/DailyReflectionSystem.gd`、`scripts/systems/NPCSystem.gd`、`scripts/ui/NPCPanel.gd` | 仅写入第一人称日记 + 替换式知识图谱，规范化时剔除旧 `memory_summary`，向玩家显示中文知识主体 / 关系 / 值 |
| `data/notice_board_defaults.json` | 守备官口吻的初始通告、10 条通用参考日程和固定“仅供参考、可自行安排”备注 |
| `scripts/systems/MemorySystem.gd` | 权威保存广场当前通告 / 参考日程并校验时段；T0065 后发布事件改为全站单次广播，广场入场见闻不再携带公告牌三项；仍预写初始 NPC 见闻并过滤离站者 |
| `scripts/ui/NoticeBoardPanel.gd`、`scenes/main/Main.tscn` | 提供“通告 / 参考日程”双 Tab 草稿编辑、日程增删改 / 全天重叠提示、发布 / 退出语义与容器尺寸 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py` | Schema、运行态 8→7 名单和真实 provider 基础场景验收 |
| `tools/verify_notice_board_tabs.gd`、`tools/verify_notice_board_input.gd`、`tools/verify_escape_station_behavior.gd`、`tools/verify_reference_schedule_real_plans.gd` | 草稿取消、双页 UI、日程增删改 / 全天重叠提示、初始 / 全站单次广播 / 无公告牌入场重复 / 离站见闻和 8 人真实计划采样 |

## T0045 建筑布局、镜头输入与成长文案索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 按建筑缓存稳定自然高度，在容器排版后再应用修复 / 升级内容尺寸 |
| `scripts/camera/CameraRig.gd` | 事件式跟踪 WASD 与 Shift；基础 `28 m/s`、Shift+WASD `56 m/s`；按键释放、文本焦点或窗口失焦时清理平移 / 加速 / 拖拽状态 |
| `scripts/systems/NPCSystem.gd`、`scripts/systems/MemorySystem.gd` | 保持技能点权威结算，把属性成长事件改为 NPC 锻炼体力 / 脑力叙事 |
| `tools/verify_camera_rig_input.gd` | 覆盖 WASD `28 m/s`、Shift `56 m/s`、精确 1:2、按键释放、窗口失焦、中键取消和文本输入焦点 |
| `tools/verify_building_repair_upgrade.gd`、`tools/verify_skill_progression.gd` | 覆盖建筑进度面板无满高闪烁与力量 / 智力精确成长文案 |

## T0044 对话恢复与对象面板收敛索引（恢复触发已由 T0049 接管）

| 路径 | 职责 |
|---|---|
| `scripts/systems/DailyPlanSystem.gd` | 校验被打断行动与当前计划一致后，通过专用入口清除该计划阶段签名，并复用正常计划派发 / 校验 |
| `scripts/systems/DialogSystem.gd` | 记录玩家对话是否确实打断运行时行动；T0049 判别为空且仍为工作模式时才请求恢复 |
| `scripts/ui/NPCPanel.gd` | 提供未入伍禁用控件提示、事件 / 见闻玩家详情白名单、首次打开定位最新记录，并避免刷新帧临时撑满高度 |
| `scripts/ui/BuildingPanel.gd` | 精简马厩文案，把修复 / 升级提示移到 UI 覆盖层，并避免刷新帧临时撑满高度 |
| `tools/verify_player_dialogue_plan_resume.gd` | 覆盖实际中断后不重估恢复、空闲对话不重放、重估不恢复和普通同阶段派发仍去重 |
| `tools/verify_npc_panel_state.gd`、`tools/verify_npc_panel_interactions.gd`、`tools/verify_building_panel_workstations.gd`、`tools/verify_building_repair_upgrade.gd` | 覆盖信息白名单、征召提示、马厩文案及对象面板闪框边界 |

## T0043A 服务依赖与弥撒参与索引（教堂部分已由 T0098 更新）

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 声明诊疗 / 训练的持续依赖；祈祷与主持弥撒不再互斥或形成依赖 |
| `scripts/systems/ActionSystem.gd` | 验证有效诊疗 / 训练服务者、协调等待和处理中途离岗；教堂用内部模式表达参礼 |
| `scripts/systems/DailyPlanSystem.gd` | 按服务者、普通行动、依赖者、对话顺序派发，并规范化依赖失败类型 |
| `scripts/systems/LLMBridge.gd` | 把仍有效的依赖和实时可用性投影到计划及对话候选 |
| `scripts/systems/MemorySystem.gd` | 区分祈祷、主持弥撒与祈祷内部参礼转换摘要 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt`、`data/prompts/dialogue_system_prompt.txt` | 约束模型理解服务依赖和合并后的教堂行为，不越过程序事实 |
| `tools/verify_service_dependency_interruptions.gd` | 覆盖无服务者、服务者离岗及教堂主持正常 / 异常转换的端到端专项 |
| `tools/verify_plan_action_catalog.gd`、`tools/verify_gm_panel.gd` | 验证独立参加弥撒候选已移除，通用 GM 仍可指派祈祷 / 主持 |

## T0042 NPC 面板人物背景弹窗索引

| 路径 | 职责 |
|---|---|
| `scripts/core/NPCPromptProfile.gd` | 从 NPC 档案构造 Prompt 与玩家背景弹窗共用的 `npc_setting` 字段集合 |
| `scripts/systems/LLMBridge.gd` | 通过共享构造器继续向 LLM 发送 NPC 人设 |
| `scenes/main/Main.tscn`、`scripts/ui/NPCPanel.gd` | 在姓名旁提供“背景”按钮并用共用详情弹窗只读展示同一份人设 |
| `tools/verify_npc_panel_state.gd` | 验证按钮位置、全部人设字段、开关弹窗与切换 NPC 无旧内容残留 |

## T0041 非计划对话行动参考索引

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 行为定义单一数据源；不为对话复制第二份行动 ID 清单 |
| `scripts/systems/LLMBridge.gd` | 用与每日计划相同的动态候选构造器填充所有对话 `allowed_actions` |
| `backend/schemas/npc_ai.py` | 要求 `NPCDialogueRequest.allowed_actions` 至少包含一条候选 |
| `data/prompts/dialogue_system_prompt.txt` | 把候选解释为能力参考而非计划或已执行事实 |
| `tools/verify_dialogue_action_reference.gd` | 覆盖 7 个对话上下文、非空参考和计划 / 对话候选一致性 |
| `tools/verify_dialogue_prompt.py`、`tools/verify_dialogue_prompt_real.py` | fake-provider Prompt 合同与玩家-NPC / NPC-NPC 真实能力认知验收 |

> 本文件用于帮助 Agent 快速找到模块位置。
> 每新增、移动、删除重要代码文件，都必须更新这里。

## T0033 玩家对话剩余日重评估索引（历史方案，已被 T0049 取代）

| 路径 | 职责 |
|---|---|
| `data/npc_profiles.json` | 为马塞尔补充简短“擅长酿酒”人设，不改变神父职业 |
| `scenes/main/Main.tscn`、`scripts/ui/DialogPanel.gd` | 提供“结束后重估计划”开关及守备官 / NPC 发起默认值展示 |
| `scripts/systems/DialogSystem.gd` | 只在开关开启且完成有效回复后请求剩余日重评估；关闭时只恢复本次确实打断且仍匹配当前计划的行动 |
| `scripts/systems/LLMBridge.gd`、`scripts/systems/DailyPlanSystem.gd` | 构建 `remaining_day` 修订上下文，校验并覆盖当前小时至 23 点 |
| `backend/schemas/npc_ai.py`、`backend/app.py` | 声明修订范围并校验剩余小时、即时行动、工作阶段与白名单 |
| `backend/services/model_adapter.py`、`data/prompts/plan_revision_system_prompt.txt` | 按修订范围生成紧凑提示；真实业务校验失败时用同一 provider 做一次纠正请求 |
| `tools/verify_plan_revision_remaining_day.gd` | Godot 剩余日范围、过去小时保留和非法结果拒绝回归 |
| `tools/verify_plan_revision_prompt.py`、`tools/verify_plan_revision_endpoint.py`、`tools/verify_plan_revision_prompt_real.py` | 后端 Prompt / endpoint 与真实 provider 剩余日合同验收 |
| `tools/verify_dialogue_ui.gd`、`tools/verify_dialogue_sleep_summary_boundaries.gd`、`tools/verify_npc_proactive_talk.gd` | 开关默认值、有效轮次、攻击例外与主动交涉回归 |

T0048 历史补充：`remaining_day` 曾从玩家对话专用范围提升为所有正式计划重估的唯一范围。T0049 已取代该方案：对话先判别精确 `revision_hours`，非对话默认只修订当前小时；`tools/verify_plan_revision_remaining_day.gd` 文件名暂保留，但验证合同改为 selected hours。

## T0032 自主对话气泡鼠标拾取修复索引

| 路径 | 职责 |
|---|---|
| `scripts/npc/NPC.gd` | 为可见自主对话气泡写入交互类型、NPC 与会话元数据 |
| `scripts/systems/NPCSystem.gd` | 区分全局射线命中的气泡与 NPC 本体，分别路由到旁听弹窗或 NPC 面板 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | 用 Camera3D 屏幕投影和 Viewport 真实鼠标事件验证气泡点击、重开与本体点击回归 |

## T0031 NPC-NPC 旁听复验与艾达初始剑盾索引

| 路径 | 职责 |
|---|---|
| `data/npc_profiles.json` | 用 `initial_equipment.main_weapon=sword_shield` 声明艾达的开局故事装备 |
| `scripts/systems/EquipmentSystem.gd` | 从正式装备定义装载空的初始槽位，不扣全局库存、不写玩家赠送事件 |
| `tools/verify_equipment_system.gd` | 验证艾达开局剑盾、面板显示、零库存消耗 / 零初始赠送事件及后续正常换装 |
| `tools/verify_unit_type_classification.gd`、`tools/verify_combat_pacing.gd` | 验证艾达开局近战步兵分类与第一波实战节奏 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | 验证进行中关闭后按同一 `dialogue_id` 重开最新状态、自然结束后窗口保留到手动关闭 |

## T0029/T0030 NPC-NPC 邀请与软轮次会话索引

| 路径 | 职责 |
|---|---|
| `backend/schemas/npc_ai.py` | 声明邀请 / 正式会话阶段、无硬上限哨兵、软轮次字段和接受 / 拒绝结果 |
| `backend/app.py` | 校验邀请结果、正式回复、`max_rounds=0`、软轮次字段和阶段一致性 |
| `backend/services/model_adapter.py` | 为显式开发 Mock 提供阶段一致的邀请 / 正式回复和软性收尾行为 |
| `data/prompts/dialogue_system_prompt.txt` | 约束目标先接受 / 拒绝、正式会话无硬上限、事情结束 / 第 6 轮起软性收尾和最后一句语义 |
| `scripts/systems/DialogSystem.gd` | 邀请不提前打断、接受后激活会话、结束标记回复先入库且不追加调用；T0049 起拒绝与正式结束都为双方独立判别计划 |
| `scripts/systems/LLMBridge.gd` | 透传 `dialogue_phase`、当前轮次和软性指导，并维持逐请求慢速 |
| `tools/verify_dialogue_invitation_contract.gd` | Godot 邀请接受 / 拒绝、越过软阈值、任一方结束、无追加调用和差异化计划重评估合同 |
| `tools/verify_npc_npc_dialogue_real.py` | 真实 provider 邀请接受 / 拒绝和第 6 轮软性结束 smoke |

## T0028 NPC-NPC 自主对话旁听索引

| 路径 | 职责 |
|---|---|
| `scripts/core/EventBus.gd` | 广播带 NPC 与会话 ID 的自主对话气泡点击 |
| `scripts/npc/NPC.gd` | 为自主会话双方创建三点气泡、独立点击区与结束清理表现 |
| `scripts/systems/DialogSystem.gd` | 提供只读观察快照、参与者 / 会话校验、待回复展示状态与逐轮慢速选项 |
| `scripts/ui/DialogPanel.gd` | 只读旁听模式、实时轮次 / 历史 / 等待状态与本地关闭边界 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | fake provider 双方气泡、旁听交互、关闭不打断、同会话重开、实时更新与结束后手动关闭验证 |
| `tools/verify_npc_npc_dialogue_observer_real.gd` | 真实 provider Godot 气泡、旁听、真实回复与慢速注册 / 释放验证 |
| `tools/verify_llm_time_slowdown_audit.gd` | 六类正式 LLM 慢速审计，并连续验证三轮对话逐轮注册 / 释放 |

## T0025 NPC-NPC 计划行动索引

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 配置计划可选的对话、祈祷、主持弥撒、地点拜访、主动找守备官、训练协作、协助行动和特殊逃离意向；普通祈祷不要求神父，主持弥撒使用 `required_ability` 校验 |
| `data/prompts/plan_revision_system_prompt.txt` | 工位占用等行动失败的紧凑真实修订 Prompt |
| `backend/app.py` | 编译后精确候选业务校验、按行为必要目标错误、来源元数据与 NPC-NPC 回复身份 / 类型校验 |
| `scripts/systems/ActionSystem.gd` | 对话接近 / 预定 / 打断、拜访、祈祷、训练协作、治疗失败事件、运行态目标快照与结构化失败上下文 |
| `scripts/systems/DailyPlanSystem.gd` | 目标计划解析、教官 / 普通 / 受训者 / 对话批派发顺序、单时段派发签名、真实异步修订、计划版本、单后继队列和迟到失败上限 |
| `scripts/systems/DialogSystem.gd` | 目标邀请接受 / 拒绝、无硬上限的真实自主 NPC-NPC 对话、双层回复身份校验、玩家只读草稿和结束 / 中断恢复边界 |
| `scripts/systems/LLMBridge.gd` | 全设计行动动态候选、未来计划 / 即时修订目标过滤、建筑 / 资源 / 工位占用者上下文 |
| `tools/verify_plan_action_catalog.gd` | 设计行动目录、目标组合、即时忙碌过滤和路由回归 |
| `tools/verify_plan_extended_actions.gd` | 祈祷 / 拜访从 DailyPlan 执行到计时完成和事件入库 |
| `tools/verify_npc_npc_plan_action.gd` | 工位失败、对话移动 / 释放 / 轮次 / 双方重评估主链路 |
| `tools/verify_npc_npc_dialogue_edges.gd` | 批执行、玩家草稿、取消、昏迷 / 移动等对话竞态 |
| `tools/verify_plan_target_replacement.gd` | 同一 action id 更换 NPC / 地点目标时的当前计划替换回归；通过确定性非 Mock 测试桥等待执行前意图复核完成，再断言真实运行目标 |
| `tools/verify_training_plan_coordination.gd` | 同批教官先落地、受训者后落地的训练协作回归 |
| `tools/verify_plan_revision_single_successor.gd`、`tools/verify_plan_revision_late_failure_bound.gd` | 修订单后继队列、迟到落地失败和有界重试回归 |
| `tools/verify_plan_slot_dispatch_once.gd` | 每小时单次行为提前完成后不重放；同小时新计划版本也不能绕过消费记录 |
| `tools/verify_daily_plan_system.gd` | 24 小时计划、按声明 hour 纠正数组乱序、重复 / 缺失 / 越界小时拒绝、小时执行与生产续开回归 |
| `tools/verify_plan_action_contract.py` | 后端行动种类与精确候选组合合同 |
| `tools/verify_npc_npc_dialogue_real.py`、`tools/verify_workstation_dialogue_revision_real.py` | 真实 provider 对话与工位修订验收 |

## 文档入口

| 内容 | 文件 |
|---|---|
| 完整玩法设计源 | `game_design.md` |
| Agent 规则 | `AGENTS.md` |
| 项目简报 | `docs/PROJECT_BRIEF.md` |
| 当前状态 | `docs/CURRENT_STATE.md` |
| 任务列表 | `docs/TASKS.md` |
| 技术架构 | `docs/TECH_ARCHITECTURE.md` |
| Godot 架构 | `docs/GODOT_ARCHITECTURE.md` |
| 代码规范 | `docs/CODING_RULES.md` |
| 数据结构 | `docs/DATA_SCHEMA.md` |
| AI NPC 系统 | `docs/AI_NPC_SYSTEM.md` |
| 记忆与信息节点 | `docs/MEMORY_AND_INFO_SPACE.md` |
| 经济与建筑 | `docs/ECONOMY_AND_BUILDINGS.md` |
| 战斗系统 | `docs/COMBAT_SYSTEM.md` |
| UI | `docs/UI_UX.md` |
| GM 调试面板 | `docs/GM_PANEL.md` |
| Prompt | `docs/PROMPTS.md` |
| API 成本 | `docs/API_BUDGET.md` |
| 长期记忆 | `docs/LONG_TERM_MEMORY.md` |
| 开发日志 | `docs/DEV_LOG.md` |
| 变更记录 | `docs/CHANGELOG.md` |

## Godot 模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 主场景 | `res://scenes/main/Main.tscn` | 游戏入口 |
| 驿站地图 | `res://scenes/world/Station.tscn` | 低模驿站 |
| NPC 场景 | `res://scenes/npc/NPC.tscn` | 通用 NPC 实体 |
| 敌人场景 | `res://scenes/enemy/Enemy.tscn` | 通用敌人实体 |
| 建筑场景 | `res://scenes/buildings/Building.tscn` | 通用建筑实体 |
| UI 主界面 | `res://scenes/ui/HUD.tscn` | 资源、时间、按钮 |
| 对话 UI | `res://scripts/ui/DialogPanel.gd`（节点内嵌于 `Main.tscn`） | NPC 对话 |
| 指令 UI | `res://scripts/ui/OrderPanel.gd`（节点内嵌于 `Main.tscn`） | 已入伍 NPC 自然语言指令 |
| NPC 面板 | `res://scenes/ui/NPCPanel.tscn` | 状态、装备、按钮 |
| 建筑面板 | `res://scenes/ui/BuildingPanel.tscn` | 建筑信息 |
| GM 调试面板 | `res://scripts/ui/GMPanel.gd` | 开发验证入口 |
| 公告牌交互 | `res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd` | 主厅前公告点击、预览与“通告 / 参考日程”草稿编辑、发布 |
| 商人交易系统 | `res://scripts/systems/MerchantSystem.gd`、`res://scripts/ui/MerchantPanel.gd` | 后门定时到访、资源买卖与交易事件 |
| 分阶段制造系统 | `res://scripts/systems/CraftingSystem.gd` | 铁匠铺 / 工械坊配方、项目目标、阶段推进、具体成品入库与特殊状态 |
| 真实马匹系统 | `res://scripts/systems/HorseSystem.gd` | 马匹生态、成长 / 生育、个体状态、分配、战时骑乘与马厩特殊状态 |
| 工程器械系统 | `res://scripts/systems/DefenseDeviceSystem.gd` | 围墙 / 主厅通用槽、器械 HP / 防御 / 穿透、库存消耗与权威自动攻击 |
| 工程器械槽位 UI | `res://scripts/ui/DefenseSlotPresenter.gd`（节点内嵌于 `Main.tscn`） | 已解锁空槽圆形 `+`、自收束部署选择和实际射程提示 |
| 工程器械表现 | `res://scripts/world/DefenseDevicePresenter.gd`、`res://scripts/world/DefenseDeviceView.gd`、`res://scenes/defense_devices/DefenseDeviceView.tscn` | 部署快照、`ModelMount`、正式模型配置 / 动作转交与箭塔回退 |
| 正式弩床表现 | `res://scripts/presentation/defense/FormalBallistaArtView.gd`、`res://scenes/defense_devices/FormalBallistaArtView.tscn` | PBR 木 / 铁结构、平台包络、目标转台、动态弓弦、后坐、飞行重箭和攻速同步重装 |
| 每日计划系统 | `res://scripts/systems/DailyPlanSystem.gd` | 正式真实 LLM 8 路并发计划、显式调试计划、按小时执行与异常重评估 |
| 游戏启动编排 | `res://scripts/systems/GameStartupSystem.gd` | 静止调试、正式循环与新手引导占位三状态开关 |
| 熟睡总结系统 | `res://scripts/systems/DailyReflectionSystem.gd` | 21:00 锚定窗口累计睡眠满 1 游戏小时后的第一人称日记、替换式知识图谱键值更新、短期记忆轮转与深度睡眠锁 |

## Godot 当前已创建

路径：`project.godot`
用途：Godot 项目配置，当前启动场景为 `res://scenes/main/Main.tscn`，并注册 `MCPGameBridge`、`EventBus`、`GameState`、`ConfigLoader` Autoload。
依赖：Godot 4.6，`addons/godot_mcp` 自动加载配置。
当前状态：T0101 已验证可打开并运行，核心 Autoload 加载无报错。

路径：`addons/godot_mcp/`
用途：Godot MCP 编辑器插件与运行桥接，供 Codex / MCP server 查看场景、节点、资源、截图、运行状态和编辑器状态。
依赖：Node 侧 `@satelliteoflove/godot-mcp`；插件监听 `127.0.0.1:6550`。
当前状态：2026-06-17 已升级到 `4.0.1`，与本机 npm server `4.0.1` 对齐；新增/保留运行态采样、输入名解析、执行保护和网格校验相关脚本。`MCPGameBridge` 显式预加载 `mcp_runtime_state_sampler.gd`、`key_names.gd`、`joy_names.gd` 和 `mcp_exec_guard.gd`，避免换机或 `.godot` 缓存未刷新时 Autoload 解析失败。T0064 后 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs` 不再只依赖易清理的 npx 缓存，而是优先使用 broker lock / 全局 Godot MCP 包内 SDK；`6550` 是当前 Godot 插件的正常单例监听，`8765` 是 broker 单例监听。Codex MCP 已通过 broker 实际调用 `godot_project.addon_status` / `godot_editor_read.get_state` 复验连接正常。换环境恢复时先运行 `tools/check_godot_mcp.ps1` 与 `node tools/verify_godot_mcp_topology.mjs`，再按 T0005 / T0009 / T0017 / T0064 检查。

路径：`res://scenes/main/Main.tscn`
用途：最小可运行主场景，包含 `WorldRoot/Station/Ground`、`WorldRoot/Station/Buildings`、`WorldRoot/Station/NPCs`、`WorldRoot/Station/Enemies`、`WorldRoot/Station/DefenseDevices`、`WorldRoot/Station/Props`、`Systems/*`、`UI/HUD`、`UI/NPCPanel`、`UI/BuildingPanel`、`UI/DefenseSlotPresenter`、`UI/DialogPanel`、`UI/OrderPanel`、`UI/NoticeBoardPanel`、`UI/MerchantPanel`、`UI/GMPanel`、`CameraRig/Camera3D`、`SunLight`。`Systems` 下已包含 `LLMBridge`、`MerchantSystem`、`CraftingSystem`、`HorseSystem` 与 `DefenseDeviceSystem`。`Buildings` 下已有主厅、宿舍、食堂、仓库、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、围墙、城门、后门等低模建筑/门墙占位；主厅前 `NoticeBoard` 已有独立点击和公告预览，但不绑定建筑定义、不具备 HP / 等级 / 工作位。`DefenseDevices` 由 presenter 生成已部署器械表现；`DefenseSlotPresenter` 把围墙 / 主厅槽位投影成可点击圆形标记并打开部署卡。其余 HUD、对象面板、公告、交易、GM 与相机结构不变。
依赖：绑定 `res://scripts/systems/TimeSystem.gd`、`NPCNeedsSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`CraftingSystem.gd`、`HorseSystem.gd`、`MemorySystem.gd`、`MerchantSystem.gd`、`DefenseDeviceSystem.gd`、`CombatSystem.gd`、`EquipmentSystem.gd`、`LLMBridge.gd`、`DialogSystem.gd`、`DailyPlanSystem.gd`、`GameStartupSystem.gd`、`DailyReflectionSystem.gd` 作为系统脚本，绑定 `res://scripts/ui/HUD.gd`、`NoticeBoardPanel.gd`、`MerchantPanel.gd` 和 `GMPanel.gd` 作为 UI 脚本，并给主厅前公告牌绑定 `res://scripts/world/NoticeBoard.gd`、给器械表现容器绑定 `DefenseDevicePresenter.gd`，相机继续使用 `res://scripts/camera/CameraRig.gd`。
当前状态：T0403/T0409 已完成地点信息节点与进入快照；T0401 已完成基础 TimeSystem，HUD 时间以 `HH:MM:SS` 推进，速度按钮可切换 `x1` / `x2` / `x4`，暂停按钮和空格可暂停/继续，空格不触发加速；T0271 后外部 slowdown / cap 实际降低倍率时，速度按钮锁定并显示有效倍率与精炼原因，释放后恢复玩家倍率。T0012 后 HUD 主栏按资源定义顺序显示非聚合资源库存，并提供装备/器械详情按钮，详情面板贴近各自按钮左下且夹在屏幕内；T1301 后 HUD 显示下一波倒计时，T1302-T1305 后 HUD 可显示主厅摧毁、无可战斗人员失败、第 5 波胜利和 NPC 结局总结，结局明细使用滚动区；T0305 已完成 NPC 工作 / 吃饭 / 睡觉最小行动闭环，并按 `game_design.md` 补齐酒窖、铁匠铺、工械坊、马厩、协助修复和协助升级的最小效果；T1506 后主厅公告牌可点击输入并显示当前广场公告；T1507 后后门商队每天 10:00-16:00 可买基础资源、卖酒并写入结构化公开事件。低模驿站、HUD 信息、建筑调试标签和 NPC 调试标签可见，可用 WASD/鼠标中键/滚轮查看驿站；T1101 后正门外地面和正门道路已扩大，`WorldRoot/Station/Enemies` 可由 CombatSystem 生成正门外低模敌人占位；T1103 后 HUD 警铃可触发入伍持武器 NPC 前往城门外防线集结，步行近战居中在前、步行远程居中在后、骑兵与骑射分列左右翼，集结 / 接敌时显示方向标记和坐骑表现；T1105 后已入伍持武器 NPC 可在 NPC 面板选择当前兵种可用战斗策略，T1105A 后战斗内避战够远时保持等待；T1106 后敌人波次开始 / 结束会写入广场公开事件并维护本场受伤、昏迷和击退统计；T1304/T1305 后包含第 5 波的战斗清敌会进入胜利结算，记录资源 / 建筑和 NPC 结局快照并停止继续刷波；建筑节点运行时具备点击区并可发出 `building_clicked`，右上角建筑面板可显示被点击建筑的基础信息、建筑状态、精确运作效率，以及按配置顺序逐项列出的具体位置名称与占用情况，并触发倒计时修复/升级；NPC 点击可发出 `npc_clicked` 并打开 NPC 面板；可通过调试接口让 NPC 直线移动到指定建筑、战斗集结世界坐标或策略移动目标，或安排工作、协助修复、协助升级、训练、吃饭、睡觉，到达后更新地点 `people_present`、写入只含行动事实的 `location_entered` / `location_exited`，并给进入者写入一次地点快照见闻；室内到室内切换会在事件与地点信息层经由广场，再进入持续行动。吃饭、睡觉、工作和训练通过 `logical_time_tick` 推进，完成后结算资源/状态并写入结构化事件。T0035/T0036 后，铁匠铺 / 工械坊按 11 个分阶段配方产出具体 `item_*` 库存，制造工作必须先选目标，一个周期提交一个阶段，建筑面板显示阶段进度并在非零进度切换目标时确认；T0037/T0038/T0056 后，马厩由 HorseSystem 维护两匹初始 60% 刚成年马与后续小马的生态、成长、拆分 HP、累积繁育概率 / 冷却、分配和战时骑乘，NPC 面板只为已入伍且有主武器者提供成年马分配；EquipmentSystem / DefenseDeviceSystem 逐件消费具体库存，四类旧聚合 id 仅兼容保留；T0903 后，训练场可通过教官位和训练位提升当前装备对应的武器熟练度 / 骑术，并让教官提升“教练”；T0904 后，工作 / 诊所 / 训练的熟练度提升同步增加经验、产生未分配技能点；T0015 后 NPC 面板把经验显示在 HP 右侧，并只在有未分配技能点时显示属性旁 `+1`，GM 可把选中 NPC 设为入伍并由玩家分配力量或智力。暂停期间 NPC 移动与行动结算停止，未开始行动保持 pending，已开始行动保持 active，恢复后继续；建筑修复和升级进度也随逻辑时间暂停/加速。未实现复杂生产平衡、正式工程器械美术或命中/格挡；T1508 部署闭环已完成。
T0132-P4a/P4b 状态补充：弩床与箭塔均已接入正式模型、可见弹体和攻速同步重装 / 补箭循环；两类器械继续共用 DefenseDeviceSystem 权威槽位与即时结算。
T0107/T0110/T0112 当前补充：Main 世界可直接点击围墙 / 主厅已解锁空槽 `+` 部署弩床或箭塔，锁定槽不显示；已部署弩床使用正式 PBR 模型与攻速同步动作，箭塔仍显示低模回退；NPCPanel 显示最终战斗属性。围墙六级容量为 `1 / 2 / 2 / 3 / 3 / 4`，Lv.3 / Lv.5 各累计 `+5%` 器械射程；主厅容量为 `1 / 1 / 2 / 2 / 3 / 4` 且固定 `1.0x` 基础射程。BuildingPanel 的升级提示读取下一等级真实成本、工期、Max HP、器械射程和槽位收益。CombatSystem 使用递减防御曲线，武器熟练度只提高当前对应武器攻速，骑术只提高马匹冲撞伤害，并保留弱敌人潮、远程距离带、敌人抬手 / 僵直和骑兵冲锋循环。
T0035-T0038/T0056 当前补充：`Main/Systems` 已挂载 CraftingSystem 与 HorseSystem。铁匠铺 / 工械坊由 11 个分阶段配方产出具体 `item_*` 库存，建筑面板提供目标下拉、阶段进度和非零进度切换确认；马厩初始化两匹 60% 刚成年马并逐个显示基础 / 照料额外 HP、成长、繁育概率 / 冷却等生态状态，HorseSystem 处理成长、繁育、喂食、恢复、分配和 `rally` / `combat` 战时离厩。装备 / 部署已逐件消耗具体库存，旧 `weapons` / `armor` / `defense_devices` / `horse_readiness` 仅兼容保留且不得正式消耗。依赖补充：`Main.tscn` 绑定 `res://scripts/systems/CraftingSystem.gd` 与 `res://scripts/systems/HorseSystem.gd`，ActionSystem、BuildingPanel、NPCPanel、HUD、EquipmentSystem、MemorySystem、CombatSystem 和 DefenseDeviceSystem 通过窄接口消费其权威状态。
T1204A 补充：逃离 NPC 会显示头顶 `!` 和 HUD 警告，点击后先打开 NPC 面板；玩家通过【对话】按钮进入强制公开的逃离挽留对话，最多 5 轮。挽留面板打开时 CombatSystem 暂停逃离移动，未满 5 轮关闭后恢复移动且可再次打开，5 轮用完后 NPC 面板【对话】置灰。LLM / Mock 只返回留下或继续逃离意向，CombatSystem 负责停止或继续逃离；守备官给钱会减速，逃离挽留中的攻击会加速、计 1 轮、关闭面板且不请求 NPC LLM 回复，攻击昏迷只暂停逃离并在复苏后继续。
T1001-T1003/T0022 补充：`Main.tscn` 已挂载 `DailyPlanSystem`，规则计划只作为显式调试；正式开局和新一天的 `/npc/plan_day` 使用真实 provider 、8 路并发和 `llm_plan_day` 来源，失败不使用 Mock 或规则降级。行动异常 / 指令变化后的计划重评估仍是独立修订链路。
T0019 补充：`Main.tscn` 已挂载 `GameStartupSystem`。默认正式模式会暂停时间，让 8 名 NPC 在第 1 天 06:00 记录起床并进入“制定计划”；全部 24 小时计划完成后才统一执行当前项并恢复时间。静止调试模式不生成计划，新手引导模式当前只保留占位快照。
T1004/T1005/T1405 补充：`Main.tscn` 已挂载 `DailyReflectionSystem`；T0094 后 NPC 在当前 21:00 锚定窗口累计睡眠满 1 游戏小时会生成熟睡总结，增量追加长期日记、按 `subject + relation` 替换式更新知识图谱当前键值，并轮转该 NPC 当前短期事件 / 见闻索引；总结请求和应用期间 NPC 进入不可打断的深度睡眠锁。

T0043 覆盖上段主场景中的旧分组显示口径：BuildingPanel 现在按配置顺序逐位置显示“名称：空闲 / 姓名占用中”；Main 的既有 BuildingSystem、NPCSystem、ActionSystem、MemorySystem 和 LLMBridge 共同承担升级封闭、自动占位、团队效率和资格 / 可用性候选上下文，无需新增权威系统节点。

路径：`res://scenes/world/`, `res://scenes/npc/`, `res://scenes/enemy/`, `res://scenes/buildings/`, `res://scenes/ui/`
用途：后续世界、NPC、敌人、建筑和 UI 场景目录。
依赖：暂无。
当前状态：目录已创建，具体场景待后续任务实现。

路径：`res://scripts/core/`, `res://scripts/systems/`
用途：后续核心单例与系统脚本目录。
依赖：暂无。
当前状态：T0101 已创建核心 Autoload 脚本与部分系统占位脚本。

路径：`res://scripts/core/EventBus.gd`
用途：全局事件总线，声明基础跨系统信号。
依赖：作为 Autoload 注册于 `project.godot`。
当前状态：T0703 后已包含资源、时间、建筑、NPC、记忆与地点信号，以及 `recruitment_changed`、`npc_order_changed`、`npc_plan_reevaluation_requested`；`DailyPlanSystem` 监听指令变化、行动失败和对话结束等统一计划重评估请求。T1302 后新增 `game_over_changed(result, reason)`，用于主厅失败等结算状态广播。T0028 新增 `npc_dialogue_bubble_clicked(npc_id, dialogue_id)`，只转发 3D 自主对话气泡点击给旁听 UI。

路径：`res://scripts/core/GameState.gd`
用途：全局运行状态，保存当前天数、小时、分钟、秒和是否处于战斗中。
依赖：作为 Autoload 注册于 `project.godot`；需要广播时通过 `/root/EventBus` 查找事件总线。
当前状态：T0101 已创建；保存当前天、时、分、秒和战斗状态。T1102 新增 `game_over`、`game_result`、`failure_reason` 和 `set_game_over(...)`；T1302 后会记录 `game_over_day/hour/minute/second` 并通过 `EventBus.game_over_changed` 广播主厅被摧毁后的失败状态，供 TimeSystem 停止推进和 HUD 显示失败界面。T1304 后新增通用 `game_over_reason` 与 `settlement_snapshot`；失败仍写 `failure_reason`，胜利写 `game_result="victory"`、`game_over_reason="five_waves_survived"` 并保存资源 / 建筑 / NPC 结算快照。T1305 后 `set_game_over(...)` 会规范化胜负 `settlement_snapshot` 并补齐 NPC 结局明细，包括最终状态、入伍状态、最后位置、Mock 最终看法、Mock 后续命运和记忆依据。

路径：`res://scripts/core/ConfigLoader.gd`
用途：统一 JSON 配置读取入口。
依赖：作为 Autoload 注册于 `project.godot`；使用 Godot `FileAccess` 和 `JSON`。
当前状态：T0101 已创建；文件缺失、打开失败、解析失败时会 `push_error` 并返回默认值。

路径：`res://scripts/systems/TimeSystem.gd`
用途：基础逻辑时间系统，负责 24 小时阶段、秒级显示、暂停、加速、跨天、LLM / NPC 移动减速和数值倍率出口。
依赖：读取 `/root/GameState`，通过 `/root/EventBus.time_changed`、`time_scale_changed`、`logical_time_tick`、`hour_started` 与 `day_started` 广播时间变化；监听 `/root/EventBus.game_over_changed` 在失败 / 结算时暂停；由 `HUD.gd` 的 `SpeedButton` 调用 `cycle_speed()`，由 `PauseButton` 和空格调用 `toggle_paused()`；LLMBridge / DialogSystem 与 `NPC.gd` 调用 `request_time_slowdown(...)` 与 `release_time_slowdown(...)`。
当前状态：T0401 已实现；默认无敌人时现实 1 秒 = 游戏内 1 分钟，支持 `x1` / `x2` / `x4` 与独立暂停。LLM 等待和 T0137 NPC 移动使用 `1/60` 慢速；T0183 后活动敌人在场也注册唯一 `combat_enemy_presence = 1/60` 请求，使现实 1 秒 = 游戏 1 秒，其他同倍率请求不会叠慢，最后一名敌人消失后恢复玩家已选倍率。`get_time_scale_snapshot()` 暴露玩家倍率、有效倍率、全部慢速 / 上限请求与最近原因；T1302 后 `GameState.game_over` 为真时不再推进逻辑时间。

路径：`res://scripts/systems/NPCNeedsSystem.gd`
用途：NPC 饱食 / 疲劳的统一持续结算权威。
依赖：通过 ConfigLoader 读取 `data/activity_needs.json`；监听 `EventBus.logical_time_tick`；只读 NPCSystem、ActionSystem 和 BuildingSystem 快照，通过 NPCSystem 写回状态，并把三类协助有效秒数交给 ActionSystem 成长入口。
当前状态：T0081 已实现全部在站 NPC 的唯一档位解析、跨行动小数余量、0–100 边界、有限行动 / 建筑作业 / 协助治疗的有效时间截断，以及完成后的 idle 剩余时间结算；`escaped=true` 的 NPC 不再推进站内生活值。

路径：`res://scripts/systems/ResourceSystem.gd`
用途：基础资源与具体物品库存事实源。
依赖：通过 `/root/ConfigLoader` 读取 `data/resource_defs.json`，通过 `/root/EventBus.resource_changed` 广播资源变化，供 HUD 刷新。
当前状态：T0202 已实现基础资源读写；T0036 后同一接口权威保存剑盾、长杆、弓、弩、四个盔甲部位、弩床和箭塔 10 种具体 `item_*` 库存。`weapons` / `armor` / `defense_devices` / `horse_readiness` 仅为旧测试 / 存档兼容项，定义标记 `deprecated=true`、`formal_consumption_allowed=false` 且正式 HUD 隐藏；EquipmentSystem、DefenseDeviceSystem 与 CraftingSystem 不再把它们用于正式结算。

路径：`res://scripts/systems/BuildingSystem.gd`
用途：基础建筑系统，负责建筑配置读取、场景节点绑定、点击识别和基础状态查询。
依赖：通过 `/root/ConfigLoader` 读取 `data/building_defs.json`，绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，并通过 `/root/EventBus.building_clicked` 广播点击选择、通过 `/root/EventBus.building_state_changed` 广播状态刷新。
当前状态：T0304 已实现基础建筑数据读取、场景节点绑定、运行时点击区、调试标签状态显示、`get_building(...)` 等查询接口、建筑入口坐标查询 `get_building_entry_position(...)`、地点当前状态占位 `get_building_location_context(...)` 和最小修复/升级逻辑；2026-05-20 已补充 `_unhandled_input` 相机射线拾取，真实鼠标点击建筑可稳定触发 `building_clicked`。T0006 后建筑受损、修复进度、协助者变化、修复完成和升级只触发 `building_state_changed`，不再伪装为建筑点击。T0801 新增 `claim_workstation(...)` / `release_workstation(...)`，作为工作位占用和释放的权威接口；工位变化仍通过 `building_state_changed` 交给 MemorySystem 广播地点内部状态差量。修复/升级消耗由 `ResourceSystem` 结算，资源不足时不会改变建筑状态；修复和升级都会创建随 `logical_time_tick` 推进的倒计时作业，并可被多个 NPC 按工程熟练度协助加速；建筑受损、正在修复或正在升级时不能开始升级，只有完好建筑可升级；协助者离开对应建筑或被改派时会从作业中移除；T1102 新增 `apply_damage_to_building(...)` 供 CombatSystem 结算敌方建筑伤害，并写入 `building_damaged` 结构化事件；建筑/地点节点后续只保存当前状态并负责广播，不保存事件历史。 T0035/T0037 后新增 `get_building_special_state(...)`、`get_building_special_state_section(...)`、`set_building_special_state_section(...)`，作为 CraftingSystem / HorseSystem 写入内部特殊状态的唯一建筑接口；BuildingSystem 不自行结算制造或马匹生态。

T0043/T0084/T0127 补充：BuildingSystem 现在权威维护逐位置 `id/type/name/assigned_npc_id/reserved_by/occupied_by/status`、统一可进入 / 可用状态、受损效率、固定位置类型与 `upgrade.level_effects`。升级可配置成本、时长、Max HP、位置和效率增量；施工期间封闭建筑、拒绝占位并清退使用者，完成后一次应用奖励。`reserve_workstation(...)` 只预留，`commit_workstation_reservation(...)` 在物理抵达后提交占用；旧 `claim_workstation(...)` 仍服务尚未迁移的建筑。宿舍床位优先且仅使用调用者自己的专属床，没有归属的未来 NPC 只能使用未分配床位。

路径：`res://scripts/systems/NPCSystem.gd`
用途：基础 NPC 系统，负责读取 NPC 档案、生成 NPC 占位实体和转发 NPC 点击事件。
依赖：通过 `/root/ConfigLoader` 读取 `data/npc_profiles.json`，实例化 `res://scenes/npc/NPC.tscn` 到 `Main/WorldRoot/Station/NPCs`，并通过 `/root/EventBus.npc_clicked` 广播点击事件。
T0129C-A2b-P1–P6 增量：格伦→铁匠铺、莉娜→诊疗位 / 病床、艾达→宿舍固定床、布鲁诺→食堂用餐席、马塞尔→小教堂祈祷席与托马→马厩照料位可在显式 GM 试点中绑定远端正式 NavigationMap。统一登记表驱动 NPC / 建筑 / 工位类型；全部只在穿门后提交地点、到站后提交工位，床 / 椅 / 长凳 `mount_after_arrival` 必须先由 BuildingSystem 提交占用，随后才挂到 occupant anchor；马厩采用 `stand`，保持 Body 碰撞与 HorseAnchor 净空。停止、不可达、改派、建筑失效和昏迷统一释放自身预留 / 占用与表现挂接；所有试点保持 `current_action=idle`，不提前启动对应行动结算。默认非战日常仍是旧地图兼容链，默认战斗已进入正式世界。
当前状态：T0403/T0409 后，移动到达会通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present` 并写入进入快照；室内信息地点切换到另一个室内信息地点时，会在事件与地点信息层插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链，物理表现仍是直线移动占位。T0501/T0502/T0503 已实现 HP 扣除、昏迷恢复和协助治疗；T0808 已实现诊所病床治疗和研读医术。T0702 新增征召权威更新入口；T0703 新增 `get_current_order(...)`、`publish_npc_order(...)` 和最近计划重评估请求快照，只有已入伍 NPC 的指令文本变化时才写入私有事件并发出请求。T1001 新增 `get_npc_plan(...)` / `set_npc_plan(...)` 和 `stop_npc_movement_for_system(...)`，供每日计划系统保存计划并在小时计划切换时安全中断移动。T1004 新增 `get_npc_long_memory(...)` 与 `apply_daily_reflection(...)`，用于写入长期日记并合并知识图谱更新；T1405 后知识图谱更新为替换式键值结构，不再写 append-only `patches`。T0704 新增 `give_money_to_npc(...)`；T0013 后旧占位武器兼容入口已移除，正式装备统一通过 T0901 `EquipmentSystem`。T0901 新增 `get_npc_equipment(...)` / `set_npc_equipment_slot(...)`，NPCSystem 只负责保存装备槽和刷新 NPC 状态，不负责库存扣除或兵种判定；T1103C 起，如果避战中的已入伍 NPC 获得主武器，会交给 CombatSystem 按当前敌军分流到战斗。T0904 新增 `increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，统一熟练度经验、未分配技能点和玩家分配力量 / 智力。T0705 新增 `debug_start_proactive_talk(...)`、`get_proactive_talk(...)` 和 `handle_npc_clicked(...)`，可让 NPC 进入主动找守备官交涉状态、显示问号气泡、点击后打开既有对话面板，并在超时或对话结束后请求计划重评估。T1204A 后，`handle_npc_clicked(...)` 对正在逃离的 NPC 返回未接管，让点击路径打开 NPC 面板而不是直接进入挽留对话；NPCPanel 再通过【对话】按钮进入逃离挽留。T1102 新增只读 `get_npc_world_position(...)` 供 CombatSystem 做附近单位目标选择；敌人对 NPC 的伤害复用既有 `apply_damage_to_npc(...)` 昏迷链路。T1202 后，`apply_damage_to_npc(...)` 的权威扣血结果会延迟通知 CombatSystem 进行战时低血量判定。T1103 新增 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 将入伍持武器 NPC 移动到城门外集结点或暂停逃离挽留移动。T1103A 新增 `set_npc_behavior_mode(...)`、`get_npc_behavior_mode_snapshot(...)`、`debug_get_behavior_mode_snapshot(...)` 和睡觉判定接口，统一保存 `behavior_mode`、进入原因和进入时间，并继续兼容 `combat_mode`。T1103B/T1103C 后，避战快照包含 `avoidance_target_id` / `avoidance_target_name` / `avoidance_target_position`，`set_npc_recruited(...)` 会在 NPC 避战中应征成功时交给 CombatSystem 分流：无主武器继续避战，有主武器且仍有敌军进入 `combat`，无敌军回到 `work`。T1105 后，NPCSystem 运行时状态会保存 `states.combat_strategy` 和 `combat_strategy_move_target_*` 策略移动目标，并在行为模式快照中暴露这些字段。T1204A 后，守备官给钱或攻击逃离 NPC 会通知 CombatSystem 调整逃离速度，逃离挽留攻击不触发 NPC LLM 回复，攻击导致昏迷时逃离暂停并在复苏后继续。模式切换可强制中断普通行动、移动、可取消 LLM 和当前对话；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 不写入 `npc_mode_changed`，其他需要留痕的模式变化仍可记录。仍不实现复杂避障。

路径：`res://scripts/systems/EquipmentSystem.gd`
用途：正式装备系统，负责具体武器 / 盔甲库存与 NPC 装备槽交换、真实马匹分配桥接和兵种判定。
依赖：读取 `data/weapon_defs.json`、`data/armor_defs.json` 和 `data/mount_defs.json`；调用 ResourceSystem 逐件结算定义中的 `source_resource_id`，调用 NPCSystem 写入槽位，调用 HorseSystem 分配 / 取消真实马匹，并通过 MemorySystem 写入 `equipment_given` / `equipment_changed`。
当前状态：T0036 后主武器与四个盔甲部位只消耗各自具体 `item_*`，换装先消耗新物品再返还旧物品，卸装返还原物品；旧聚合库存不参与。T0038 后坐骑公开入口委托 HorseSystem，`equipment.mount` 只保存 `horse_id` / `horse_name` 和通用骑乘参数的兼容投影；收回主武器会自动取消马匹分配。T0138 后所有玩家换装 / 分配 / 收回仅允许 `work` 模式，系统因马死亡、骑手昏迷或资格失效执行的内部清理使用显式 bypass，不开放给 UI。T0031 的艾达故事初始剑盾仍不扣库存、不写守备官赠送事件。兵种、战斗数值读取和策略归一化继续沿用既有接口；EquipmentSystem 不结算马匹生态、HP、死亡或战斗伤害。

路径：`res://scripts/systems/CraftingSystem.gd`
用途：铁匠铺 / 工械坊制造项目、配方阶段和具体成品入库的唯一权威。
依赖：读取 `data/crafting_recipes.json`；调用 ResourceSystem 结算阶段材料 / 成品，调用 BuildingSystem 写入 `special_state.production`，由 ActionSystem 提交周期进度 / 阶段完成，由 BuildingPanel 提交目标选择并只读显示。
当前状态：T0035 已实现 11 个冻结配方、未选目标阻止工作、1 个工作周期完成 1 个阶段、中断只清除当前周期小数进度、已提交阶段保留、切换目标中断制造并清零原项目、非零进度需要确认、全部阶段完成后对应 `item_*` 入库并从同一项目第 1 阶段继续。对 NPC 信息空间只发布目标与整数阶段，不发布小数进度。

路径：`res://scripts/systems/HorseSystem.gd`
用途：真实马匹个体生态、马厩数量、成长 / 生育、分配与战时骑乘的唯一权威。
依赖：读取 `data/horse_defs.json`；监听 TimeSystem / NPC 状态，读取 ActionSystem 的 active `work_stable` 养马人，调用 ResourceSystem 结算进食粮食、BuildingSystem 写入 `special_state.horses`、EquipmentSystem 同步坐骑投影。
当前状态：T0056 后栗风、灰鬃以 60% 成长刚成年开局；每匹马独立保存总 HP、基础 / 照料额外 HP、饱食、成长、繁育概率 / 冷却、进食、位置、分配和骑乘。T0138 后仅 `work` 可手动分配 / 收回；T0138-R1 后 `rally / combat` 使用 `waiting_for_rider_at_stable`，马留在真实马厩锚点，只有 NPC 从实时位置经正式 NavMesh 前往马旁，到达后才 `ridden`。骑乘受击先随机扣马 `30%–50%` 结算后伤害；马死亡清分配并让 NPC 转步战，NPC 昏迷清分配并让存活马 `returning_stable`，正常退战返厩但保留分配。生态与繁育公式保持不变。

路径：`res://scripts/npc/NPC.gd`
用途：通用 NPC 实体脚本，保存 `npc_id` 和档案快照，刷新短姓名/HP/当前行动标签，处理点击、实体运动表现与逐 NPC 移动慢速生命周期。
依赖：绑定到 `res://scenes/npc/NPC.tscn`，通过 `/root/EventBus.npc_clicked` 发出点击事件；运动开始 / 结束时调用 `Main/Systems/TimeSystem` 的既有慢速请求接口。
T0129C-A2b-P2–P4 增量：提供 `attach_to_spatial_anchor(...) / detach_from_spatial_anchor()`。家具锚点挂接只在权威占用提交后发生，诊所应用 `lying_supine`、宿舍应用 `sleeping_supine`、食堂应用 `sitting`；挂接时关闭 CharacterBody 实体碰撞、保留 InteractionArea 点击，解除时恢复碰撞和 LegacyVisuals / ArtMount 基础 Transform。空间姿态不自动启动治疗、睡眠或进食行动。
当前状态：T0304 已创建；普通点击 NPC 会打印 ID 并发出 `npc_clicked(npc_id)`；头顶标签只显示短姓名、HP 和当前行动摘要；T0705 后若 NPC 有主动交涉状态，点击会优先交给 `NPCSystem.handle_npc_clicked(...)` 打开对话，不再先弹出 NPC 面板，并在运行时显示 `ProactiveTalkBubble` 问号气泡；T0028/T0029 后受邀者接受自主 NPC-NPC 会话后，双方运行时才显示浅色 `AutonomousDialogueBubble` 三点气泡与独立点击区；点击只发出带 `dialogue_id` 的旁听请求，结束 / 失败 / 中断后隐藏并禁用点击。邀请等待 / 拒绝阶段不显示正式对话气泡，已接受的自主对话期间气泡替代重复的通用三点 LLM 标记。T1103 后运行时创建 `CombatMountVisual` 和 `CombatFacingMarker`，T1103A 起优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结/接敌方向标记，兼容旧 `combat_mode`，且只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动中的 NPC 头顶行动摘要显示“战术移动”；T1204A 后逃离中的 NPC 头顶显示 `!` 警告标记，行动摘要显示“逃离”，逃离移动会读取 `escape_intent.speed_multiplier`；支持 `move_to_location(...)` 实体移动，到达后发出 `movement_arrived` 给 `NPCSystem` 写回地点状态；T0137 后开始运动即持有逐 NPC `1/60` TimeSystem 慢速请求，停止、到达、失败、取消或退出时统一释放。

路径：`res://scenes/npc/NPC.tscn`
用途：通用 NPC 低模占位场景。
依赖：绑定 `res://scripts/npc/NPC.gd`，由 `NPCSystem` 实例化。
当前状态：T0303 已创建；当前包含 `Area3D` 点击区、低模胶囊身体、头部和 `Label3D` 短姓名/HP/当前行动调试标签。T0705 后问号气泡由 `NPC.gd` 运行时创建，T1204A 后逃离警告 `!` 标记也由 `NPC.gd` 运行时创建，不需要手改场景资源。

路径：`res://scripts/systems/MemorySystem.gd`
用途：事件、见闻与地点/广场信息节点系统。
依赖：由 ActionSystem、NPCSystem、DialogSystem、CombatSystem、BuildingSystem 等系统写入事件；读取 GameState / TimeSystem 的游戏时间；通过 EventBus 广播 `event_recorded`、`npc_memory_changed`、`location_info_changed` 和 `public_event_added`。
当前状态：T0405 已实现 NPC 短期记忆容器查询；支持 `get_npc_short_term_memory(...)`、`get_npc_short_term_memory_ids(...)`、`clear_npc_short_term_memory(...)`、`record_player_interaction(...)`、`debug_record_player_money_given(...)`、`debug_record_player_attack_npc(...)`、`debug_get_npc_witness_events(...)`、`debug_get_npc_short_term_memory(...)` 和 `debug_clear_npc_short_term_memory(...)`。T0404/T0408/T0409 已实现广场信息即时广播并统一为 `location_id == "plaza"` 的 `local_public`；支持 `move_npc_between_locations(...)`、`get_location_snapshot(...)`、`get_location_people_present(...)`、`is_enterable_location(...)`、`set_plaza_notice(...)`、`broadcast_plaza_event(...)`、`broadcast_plaza_state_change(...)`、`notify_key_entity_state_changed(...)` 及对应调试接口。MemorySystem 监听 `building_state_changed`：任一建筑可传播外部状态会同步进广场 `building_external_states` / `key_entities` 并生成带具体建筑名和具体事实的 `plaza_status_changed`；可进入建筑的外部或内部可传播状态会生成 `location_status_changed` 本地见闻。可传播外部状态计算等级、`condition`、`is_enterable` 与 `operational_efficiency` 分档；精确 HP、精确效率和剩余修复/升级时长不触发广播。广场和可进入建筑进入快照都会生成 `people_statuses`，把当前在场 NPC 的生命状态写为健康/受伤/昏迷，昏迷时可列出治疗者，并把 `current_action` 翻译成精简中文；T1103 后行动状态摘要会把集结 / 接敌状态显示为“前往城门外防线 / 在城门外集结 / 准备接敌”，T1105 后会把策略移动显示为“进行战术移动”，T1203/T1204A 后会把逃离显示为“正朝后门逃离 / 已离开驿站”；可进入建筑还会提供逐位置 `id/type/name/occupied_by/status`，位置按 ID 比较，新增、移除、改名、改类型和占用变化会触发本地差量见闻。NPC 进入广场会获得当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑会获得该建筑外部 + 内部状态。T0407 已实现：`location_entered` / `location_exited` 事件库只保留进出行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化改为字段级差量见闻。T0402 已升级为结构化事件事实源；支持 `add_event(...)`、`get_event_log()` / `get_all_events()`、`get_npc_daily_events(...)`、`get_npc_witness_events(...)`、`get_plaza_events(...)`、`add_witness_event(...)` 和调试查询接口。T0502A 后，`add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，复苏后自动恢复。事件会规范化为包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload` 的结构，并首先写入对应 NPC 当天事件库；`local_public` 会转发给事件地点当前在场且未昏迷 NPC 的见闻库，广场事件通过同一机制转发给广场当前在场且未昏迷 NPC 并可被广场查询返回。玩家非对话交互写入时 actor id 使用 `guard_officer`，summary 使用“守备官”。T0705/T0051 后，主动交涉发起仍写 `proactive_talk_started`，预设开场问题随完成会话的单条 `dialogue_turn` 入库；`proactive_talk_message` 仅作旧事件兼容。守备官-NPC 对话取消不写事件或见闻，NPC-NPC 仍按完成轮次写入。T1103 新增 `combat_alarm_rang`、`combat_rally_started` 和 `combat_rally_encountered_enemy` 事件模板，记录听到警铃、前往城门外集结和集结途中接敌；T1105 新增 `combat_strategy_selected`，记录守备官为入伍持武器 NPC 设置当前战斗策略；T1202 新增 / 完善 `low_hp_triggered`、`battle_psychology_result` 和低血来源的 `morale_boost_started` 摘要，支持“继续参战 / 继续避战 / 逃离 / 斗志激昂”的公开事件表达；T1203 新增 `escape_started` / `escaped` 摘要；T1204A 新增 `escape_intervention_result` 与 `escape_speed_changed` 摘要，记录挽留后留下 / 继续逃离和给钱 / 攻击造成的逃离速度变化。公告变更写入 `plaza_notice_changed`，建筑状态变更写入 `plaza_status_changed` 或 `location_status_changed`。MemorySystem 不提供按地点查询事件的长期接口，地点 / 广场节点也不保存事件历史；熟睡总结只轮转指定 NPC 当前短期事件 / 见闻索引，不删除全局事件档案，因此 T0094 的“记录”仍可读取旧会话。T0035/T0037 后增加建筑内部特殊状态白名单：铁匠铺 / 工械坊只保留 `production.target_item_id`、`target_name`、`completed_stages`、`total_stages`、`current_stage_index`、`current_stage_name`；马厩只保留物理在厩 `horses.total`、`adult`、`foal`。进入者通过一次地点快照获得完整白名单状态，后续只给当时仍在该建筑且可接收的 NPC 写字段级 `location_status_changed` 差量；不广播到广场，不传播制造小数进度或马匹个体详情。

T0095 补充：正式熟睡总结使用 `get_npc_short_term_memory_snapshot(...)` 取得正文和稳定 `event_ids / witness_ids`，成功后由 `clear_npc_short_term_memory_snapshot(...)` 只轮转请求快照内的 ID；整批 `clear_npc_short_term_memory(...)` 仅保留给显式调试和旧调用兼容。

T0043 当前口径：精确 HP、精确效率和剩余时长仍不传播；外部传播 `condition / is_enterable / operational_efficiency` 分档，室内逐位置状态按 ID 比较并传播新增、移除、改名、改类型和占用变化。

路径：`res://scripts/systems/MerchantSystem.gd`
用途：后门商人到访和交易权威系统。
依赖：读取 `data/merchant_defs.json`；监听 EventBus 时间信号；调用 ResourceSystem 结算；调用 MemorySystem 广播结构化事件；控制 `MerchantEntranceMarker` 点击区和显示。
当前状态：T1507 已实现每日配置时段到访、粮食/木材/石料/铁买入与酒卖出。成功交易记录方向、资源、数量、单价、总价和资源/金钱差量；商人未到、数量非法、报价不存在、余额或库存不足时不改变资源且不记录成功事件。T0129C-A5-P3 后，同一游戏分钟内的重复时间信号不再重复更新商人 Marker，分钟变化仍执行完整到离场判定。

路径：`res://scripts/systems/DefenseDeviceSystem.gd`
用途：权威维护工程器械定义、围墙 / 主厅通用槽、部署运行态、器械 HP / 防御 / 穿透 / 攻速、库存消耗、弩床 / 箭塔自动攻击和既有结构化事件。
依赖：读取 ConfigLoader、ResourceSystem、BuildingSystem、CombatSystem、MemorySystem 与 TimeSystem；不依赖 NPCSystem 或表现节点。
当前状态：围墙与主厅各有 4 个通用槽；围墙所需等级为 `1 / 2 / 4 / 6`，主厅按 ID 为 `5 / 6 / 1 / 3`（前侧 `03/04` 先开），每次升级最多增加 1 槽。围墙宿主倍率按等级为 `1.0 / 1.0 / 1.05 / 1.05 / 1.10 / 1.10`，主厅固定 `1.0x`；既有围墙部署随宿主等级实时刷新。弩床只消耗 `item_wall_ballista`，箭塔只消耗 `item_wall_arrow_tower`。`deploy_device(device_id, slot_id)` 不需要部署者，失败无资源副作用；敌人可经对应墙面代理伤害活动器械，器械摧毁后释放槽位。

路径：`res://scripts/systems/ActionSystem.gd`
用途：日常行动权威系统，负责工作、吃饭、睡觉、训练、诊所、祈祷、地点拜访、NPC-NPC 对话接近，以及带目标协助行动的移动、占位、结算、中断和失败事实。
依赖：通过 `/root/ConfigLoader` 读取 `data/action_defs.json`，调用 `NPCSystem` 移动与状态接口、`ResourceSystem` 资源结算接口，并写入 `MemorySystem` 结构化事件。
当前状态：T0402 已在 T0305 工作 / 吃饭 / 睡觉最小行动闭环上接入结构化事件；提供 `debug_assign_work(...)`、`debug_assign_repair_assist(...)`、`debug_assign_upgrade_assist(...)`、`debug_assign_heal_assist(...)`、`debug_assign_eat(...)`、`debug_assign_sleep(...)`、`debug_assign_action(...)` 和只读 `get_healing_helpers_for_target(...)`。T1001 新增 `get_pending_action_id(...)`、`get_active_action_id(...)`、`get_runtime_action_id(...)` 和 `interrupt_npc_action(...)`，供计划系统判断与中断行动。T0075 后初始化会验证每个配置行为的 `completion_policy`，并公开只读策略和错误列表；生命周期与资源结算仍不由策略配置直接完成。T0801 后，工作支持真实位置占用/释放和统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；T0803 后，配置了 `output_scaling` 的工作可按熟练度、属性和建筑等级提高实际产出，当前菜园产粮使用该规则。T0035 后，`work_blacksmith` / `work_workshop` 要求制造目标，调用 CraftingSystem 校验项目 revision / 阶段材料、同步当前周期进度并在完整周期结束时提交一个阶段；中断或切换目标会清除未完成周期，已提交阶段由 CraftingSystem 保留。T0037 后，`work_stable` 不再产出匿名库存，其 active 状态供 HorseSystem 选择有效养马人并按养马能力推进马匹成长 / 生育。训练场使用 `training_instructor_station` 教官位和 `training_practice_slot` 训练位：无武器且无坐骑不能当教官或受训者；受训者需要至少一名在岗教官；全部在岗教官按人数和技能形成团队贡献，统一提高全部在位受训者的效率。诊所同样由全部 `clinic_doctor_station` 在岗人员按医术形成团队贡献，提高所有 `clinic_patient_bed` 占用者的恢复效率。当前工作支持菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺 / 工械坊推进具体制造项目，以及马厩养马人照料真实马匹。建筑修复和升级由 `BuildingSystem` 创建倒计时作业；A5-P6d-1 / P6d-2 后，NPC 必须真实抵达目标建筑外沿的独立维修 / 施工槽，才会加入 helper 并加速倒计时。协助治疗仍是待迁移的兼容行为：治疗者前往目标所在信息地点，最多 2 人协助同一目标，按医术熟练度调用 `NPCSystem` 加速昏迷恢复，并按逻辑时间消耗第纳尔。工作、训练、吃饭、睡觉会以 `local_public` 写入事件，让同地点当前在场 NPC 收到见闻；协助修复/协助升级同样以 `local_public` 写入 `repair_assist_started` / `upgrade_assist_started`，事件 Schema 与兼容地点字段保持不变；协助治疗写入 `healing_started` / `healing_completed`，进入治疗者和目标事件库，并写入同地点其他在场 NPC 的见闻库，事件信息不暴露医术熟练度。T0401 暂停语义修正后，暂停期间不会执行行动结算；吃饭、睡觉、工作和训练到达地点后进入 active 行动并随 `logical_time_tick` 推进。行动系统自身不实现 LLM 日程、战斗、器械部署或其他职业特殊生产平衡；T1508 部署由独立 DefenseDeviceSystem 负责。T0025 后新增 `assign_npc_dialogue(...)`、祈祷与地点拜访执行，`get_runtime_action_snapshot(...)` 暴露 pending/active 的 action、target、location、耗时、实际位置和 T0098 `prayer_mode`；治疗中途缺钱或离开地点写 `healing_failed`，不再伪装完成。对话接近会预定双方，开始前打断普通工作并释放位置；吃饭、睡觉、祈祷、主持弥撒、诊疗和训练都会自动申请同类型空位，满位或建筑封闭时返回结构化失败并触发计划重估。祈祷不依赖神父，主持开始 / 结束只切换祈祷内部模式；`lead_mass` 对所有 NPC 可见，但只有具备“主持弥撒”能力者可执行。

T0043/T0098 当前口径：训练使用 `training_instructor_station` / `training_practice_slot`，诊所使用 `clinic_doctor_station` / `clinic_patient_bed`；全部在岗教官 / 医生形成团队贡献。吃饭、睡觉、祈祷和主持弥撒也申请具体位置。祈祷始终可用，弥撒期间自动处于参礼模式；只有 `lead_mass` 需要“主持弥撒”能力。封闭、满位和摧毁等真实失败仍进入计划重估。

T0081 当前口径：ActionSystem 不再从行动定义读取饱食 / 疲劳变化；吃饭仅保留食物恢复。`advance_timed_action_experience(...)` 按 `timed_experience` 配置累计三类协助的有效秒数，每满 3600 秒调用统一熟练度成长并写 `skill_improved`。

路径：`res://scripts/systems/DailyPlanSystem.gd`
用途：每日计划系统，负责正式真实 LLM 和显式调试用 24 小时 NPC 计划、写入计划事件，并按小时打点调用行动系统；T0049/T0050 后还负责对话 / 日常行动失败计划修改判别、精确阶段修订和其他直接受限修订。
依赖：读取 `NPCSystem` 的 NPC、熟练度和计划字段；调用 `LLMBridge.request_npc_daily_plan_async(...)`、`request_plan_revision_judgement_async(...)` / `request_npc_plan_revision_async(...)` 获取后端结果；调用 `ActionSystem` 执行计划项并安全中断旧行动；调用 `MemorySystem.add_event(...)` 写入 `wake_up` / `plan_created` / `plan_revised`。
当前状态：T1001 已实现规则计划调试、保存和按小时执行。T0025 后以 `(day, hour, plan_version, action_id, target_id, dialogue_goal)` 保证普通派发幂等；T0075 增加生产完成后的受控续开、每小时单次逻辑项消费，以及整点相同运行态采用 / 不同项中断。批量执行按教官、其他非对话、受训者、对话顺序落地。T0022 后，正式 `/npc/plan_day` 先检查非 Mock 真实 provider，默认 8 路并发，将成功项标记为 `llm_plan_day`，每名 NPC 最多尝试 3 次真实请求。开局和 `day_started` 只在整批全部成功后恢复时间并执行；否则保持暂停与 `planning_day`。T0049/T0050 后，实际对话与明确的日常计划行动失败都先请求通用判别，空 `revision_hours` 不修订，非空才通过 `/npc/revise_plan` 精确合并所选小时；T0254 后纯攻击无台词会话不构造对话判别，而由既有 `guard_attack` 来源直接受限重评估。指令变化、战斗结束 / 复苏和 GM 等其他来源继续直接受限修订。双目标 NPC-NPC 会话等待双方判别 / 修订终态后按依赖顺序放行，跨小时玩家对话和行动失败判别也会延迟旧计划重派到链路终态。成功项标记 `llm_plan_revision`，失败最多 3 次真实请求并保留原计划；请求日 / 小时 / 计划版本 / 对话 epoch、单后继队列和连续迟到落地失败上限共同防止旧结果覆盖与无限循环。
T0024 补充：正式批次快照新增 `max_observed_concurrent`，用于区分“配置为 8”与“实际同时在飞达到 8”；真实开局和 `day_started` 均已完成实际峰值 8 的验收。

路径：`res://scripts/systems/GameStartupSystem.gd`
用途：游戏启动编排系统，集中提供静止调试、正式循环（无新手引导）和正式循环（新手引导占位）三个启动状态。
依赖：读取 `NPCSystem.get_npc_ids()`；调用 `DailyPlanSystem.begin_new_day_planning_for_npc(...)`、异步计划批次、统一当前项执行和自动执行开关；调用 `TimeSystem.set_paused(...)`。
当前状态：T0019/T0022 已实现并挂载到 `Main/Systems/GameStartupSystem`。正式模式先暂停时间与自动执行，让 8 名 NPC 进入计划制定状态，再发起 8 路并发真实计划。收到整批成功信号并确认每人都有 24 小时 `llm_plan_day` 后，才统一执行第 1 天 06:00 项并恢复时间；失败保持暂停。静止模式不生成计划；教程模式只记录占位状态。

路径：`res://scripts/systems/DailyReflectionSystem.gd`
用途：熟睡总结系统，负责监听睡觉开始 / 结束和逻辑时间、按 21:00 锚定窗口累计同窗睡眠，在满 1 游戏小时后生成反思、写入长期日记、替换式更新知识图谱当前键值并轮转当前短期记忆。
依赖：监听 `EventBus.event_recorded` 的 `sleep_started`；读取 `MemorySystem.get_npc_short_term_memory_snapshot(...)`；调用 `LLMBridge.request_npc_daily_reflection_async(...)` 请求 `/npc/daily_reflection`；调用 `NPCSystem.apply_daily_reflection(...)` 写入长期记忆；调用 `MemorySystem.clear_npc_short_term_memory_snapshot(...)` 只轮转本次请求快照内的短期索引。
当前状态：T1004/T1005/T1405 已实现；T0094 后每名 NPC 在一个 21:00 锚定窗口内跨中断累计睡眠，满 1 游戏小时后自动异步生成且成功应用后该窗口去重一次。T0095 后请求显式携带窗口与内容范围，日记按锚点标为“接到守备命令的第N天”，实际触发时刻独立保存；成功只推进本次请求快照水位，失败不消耗窗口也不推进内容。发起到完成期间不可被对话、指令或行动改派打断，后端不可用时使用模板降级，知识图谱按 `subject + relation` 替换当前值，GM 可通过 `debug_generate_reflection(...)` 强制触发。
T0024 补充：最多 8 路首次睡眠总结同时在飞，`get_async_reflection_snapshot()` 暴露当前活动数、实际峰值、启动 / 完成计数和逐 NPC 结果。真实 provider 成功写为 `llm_daily_reflection`，显式 Mock provider 写为 `mock_daily_reflection`；缺少来源证明或模型 fallback 不会被猜成真实成功。

路径：`res://scripts/systems/CombatSystem.gd`
用途：敌人波次读取、调试生成、目标选择、基础移动、双方基础攻击、敌人在场 1:1 时间、不同兵种战斗策略和战斗调试快照系统，后续继续承接正式战斗流程。
依赖：通过 `/root/ConfigLoader` 读取 `data/enemy_waves.json`；在 `Main/WorldRoot/Station/Enemies` 下生成运行时敌人节点。
当前状态：`CombatSystem` 读取 5 波敌人配置并按 TimeSystem 在第 3–7 日每天 18:00 自动触发，支持波次查询、调试生成 / 清除 / 跳转和战斗快照。敌人与我方会按逻辑时间推进移动、寻敌、攻击、伤害、昏迷、逃离和器械作战；战时有效倍率上限为 x1。T0121 后 Demo 唯一失败条件是主厅 HP 清零；全部武装 NPC 昏迷或逃离时，敌军与幸存器械仍继续结算。最终波敌军全灭写入 `victory/five_waves_survived`，保存资源、建筑和 NPC 结局快照。

T0183 后，CombatSystem 不把玩家 `x2` / `x4` 作为战斗倍率；活动敌人存在时通过 TimeSystem 注册 `combat_enemy_presence = 1/60`，清敌或最后一个敌人被移除时释放。CombatSystem、DefenseDeviceSystem 和 PietySystem 直接把游戏秒作为攻击、移动、塔防与持续效果秒，最近 AI / 我方攻击快照中的 `game_seconds` 与 `combat_seconds` 数值一致；第一波仍按艾达持剑基准校准。T1105 的兵种策略、换装重置和战斗内避战合同保持不变。

T1103 新增 `trigger_combat_alarm(...)` / `debug_trigger_combat_alarm(...)`、`get_active_rallies(...)` 和 `get_last_alarm_result(...)`，警铃会写入全员警铃事件，并让入伍持武器 NPC 按前后排集结。T1103A 后，CombatSystem 通过 NPCSystem 的 `behavior_mode` 接口统一维护集结等待 1 小时超时、工作 / 集结 / 战斗 / 避战切换、敌军清空后的退出和昏迷复苏分流；T0209 后 `active_avoidances`、`debug_trigger_npc_avoidance(...)`、`get_active_avoidances(...)` 使用圈内多敌逆平方合成与站内可达目标，未入伍或已入伍但无主武器 NPC 清敌后回到 `work` 且不请求计划重评估。T1106 后，CombatSystem 会在波次生成时写入广场 `combat_started`，在敌军全灭或 GM 清敌时写入广场 `combat_ended`，并维护本场受伤 / 昏迷 NPC、低血量判定与各 NPC 击退敌人统计；清敌时 `combat` 回 `work` 并请求计划重评估，`avoid_combat` 与未接敌 `rally` 回 `work` 且不强制重评估。T0138 后，分配马的响应者先等待物理会合，CombatSystem 在 `handle_npc_mount_ready(...)` 后才继续阵位 / `combat_ready`，会合中跳过友方攻击；敌军对实际骑乘 NPC 的结算后伤害经 HorseSystem 先扣马匹随机 `30%–50%`，再由 NPCSystem 扣剩余人物 HP。`debug_get_combat_snapshot()` 增加 `horse_lifecycle`。

T1201 新增 `build_battlefield_context(...)` 与 `apply_wartime_dialogue_reaction(...)`，战时对话可写入 `battle_psychology_result` 和 2 游戏小时 `morale_boost` 攻击 / 移动加成。T1202 新增 `handle_npc_damage_applied(...)`、低血量判定记录、`low_hp_triggered` 事件写入、`/npc/battle_judgement` 请求应用和规则降级：参战且已入伍持主武器的 `combat` NPC 可继续参战、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战。T1203 新增 `start_npc_escape(...)` / `debug_start_npc_escape(...)` / `handle_npc_escape_completed(...)`，战时逃离意向和 GM 调试会写入 `escape_started`、移动到后门外出口，并在 NPC 离图后记录 `escaped`。T1204A/T1204B 已包含 `apply_escape_intervention_result(...)`、`get_escape_intervention_state(...)`、`pause_escape_for_dialogue(...)`、`resume_escape_after_dialogue(...)`、`handle_escape_money_given(...)`、`handle_escape_guard_attack(...)` 和 `record_escape_attack_intervention_round(...)`：逃离 NPC 最多接受 5 轮挽留，打开对话时暂停移动、关闭时恢复移动，结果只会是留下或继续逃离；给钱会降低逃离速度，逃离挽留攻击会提高逃离速度、计 1 轮并关闭面板但不请求 NPC 回复，也不写 `escape_intervention_result`，昏迷只暂停逃离并在复苏后继续前往后门。T1303 新增 `combatant_availability` 快照和无可战斗人员失败评估。T1304 新增最终波次胜利评估、胜利结算快照和结算后刷波拒绝；T1305 后胜利快照经 `GameState` 补齐 NPC 结局明细。`debug_get_combat_snapshot()` 包含行为模式快照、避战快照、逃离快照、逃离挽留轮次和速度倍率、可战斗人员可用性、战斗策略快照、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量判定结果、最近逃离结果、最近失败结果、最近胜利结果、最近模式切换结果、最近避战结果、最近我方攻击结果和 TimeSystem 倍率快照，`debug_advance_rally_wait(...)` 可供 GM / 自动化推进集结等待。当前仍不实现命中率。

路径：`res://scripts/systems/LLMBridge.gd`
用途：Godot 侧后端桥接脚本，负责请求 `/health`、`/debug/llm_usage`、`/npc/dialogue`、`/npc/plan_revision_judgement`、`/npc/plan_day`、`/npc/revise_plan`、`/npc/battle_judgement` 与 `/npc/daily_reflection`，构造 NPC 中心请求 payload，并管理 LLM 等待期间的 TimeSystem 慢速请求。
依赖：挂载到 `Main/Systems/LLMBridge`；读取 `NPCSystem`、`ActionSystem`、`MemorySystem`、`GameState` 和 `TimeSystem`；使用 Godot 原生 `HTTPClient` 请求游戏后端。
当前状态：T0604/T0604A 已实现原生 HTTP 后端桥接；T1401/T1406 提供 usage、预算和 Godot 运行态快照。T0049/T0050 后，对话、通用计划修改判别、每日计划、计划修订、低血量心理判定和首次睡眠总结六类业务均支持异步请求并发出专用完成信号；2 秒配置只保护后端连接和 health / usage 等只读短请求。开局批量计划由 GameStartupSystem 全局暂停时间，其余影响当前场景状态的请求按 payload 申请慢速，并在成功、失败、取消、连接 / 空闲错误后释放。T0053 起判别、日计划、修订和低血量心理 payload 复用包含人设 / 状态 / 指令 / 长短期记忆 / 地点的 NPCContext；判别另带权威触发事实、原计划、候选和实时条件，修订使用同一上下文、`selected_hours` 和精确 `revision_hours`。运行态快照包含逐请求 call_type 和慢速注册 / 释放审计。LLMBridge 不修改征召、资源、HP、模式或行动权威状态。

路径：`res://scripts/systems/DialogSystem.gd`
用途：Godot 侧对话会话权威入口，维护参与者、历史、公开性和轮次，调用 LLMBridge 并写入 MemorySystem。
依赖：`NPCSystem`、`LLMBridge`、`MemorySystem`、`Main/UI/DialogPanel`。
当前状态：T0701/T0702/T0051 已实现玩家-NPC 不限轮次对话及“完成 / 取消 / 挂起”生命周期。玩家消息发送即显示；完成时只在存在真实发言时把完整 history 作为一条 `dialogue_turn` 入库并为目标 NPC 判别，取消不入库不判别，挂起保持 `talk_to_guard_officer` 且 2 游戏小时后自动取消。攻击立即结算并锁定取消；T0254 后攻击说明不进入 history，纯攻击完成或超时只保留独立伤害事件并请求 `guard_attack` 重评估。完成等待中的会话会取消迟到回复并以玩家最后一句真实发言结尾。T0029/T0030 后 NPC-NPC 仍先邀请、接受后进入无硬轮次上限的正式会话，结束标记回复先入库且不追加调用。T0049 后，邀请拒绝或正式会话结束都会为实际参与双方分别请求计划修改判别，并在任一请求发出前预注册同一会话组的派发屏障；玩家会话跨小时则把新小时派发延迟到判别链终态。空 `revision_hours` 不修订，并仅在本次对话确实打断、仍匹配原计划且行为模式允许时恢复行动；非空才把精确小时交给 DailyPlanSystem。自主会话气泡、只读旁听、主动交涉开场、战时公开对话、强制完成与逃离挽留沿用对应生命周期边界。

路径：`res://scripts/ui/DialogPanel.gd`
用途：显示 NPC 名字、对话历史、公开性、轮次、输入框、发送、完成、取消和挂起按钮，并管理可拖动标题栏与会话恢复入口。
依赖：调用 `Main/Systems/DialogSystem`。
当前状态：T0701/T0702 已创建并绑定到 `Main/UI/DialogPanel`；T0028/T0029/T0030 后可切换到自主 NPC-NPC 无硬上限会话只读旁听模式，显示双方、轮次、软性收尾、等待状态、pending 开场与历史，隐藏玩家操作；旁听关闭只隐藏本地 UI，自然结束后保留最终记录。T0268 后普通玩家对话右上角只保留“公开”“提出应征”，删除“结束后重估计划” toggle；公开仍对应 `local_public`。普通发送和攻击继续异步；等待中的普通消息被取消后不入库、不判别。攻击一旦提交仍保留独立事实并锁定取消，但 T0254 后不显示为台词，纯攻击结束不生成对话事件。T1201 后战时公开性锁定开启；T1204A 后逃离挽留显示当前 / 最大 5 轮、隐藏应征并保留攻击，关闭 / 达上限 / 攻击的移动与轮次边界不变。

路径：`res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd`
用途：主厅前公告牌点击、当前公告世界预览和自由文本输入。
依赖：通过 EventBus 打开面板；面板调用 MemorySystem 的广场公告接口。公告牌不依赖 BuildingSystem。
当前状态：T1506 已绑定 `Main/WorldRoot/Station/Buildings/NoticeBoard` 与 `Main/UI/NoticeBoardPanel`；支持发布和以空文本清空，相同文本不重复广播。

路径：`res://scripts/ui/MerchantPanel.gd`
用途：商人报价、数量、驿站库存和交易结果界面。
依赖：只读 MerchantSystem / ResourceSystem 状态并提交交易请求，不自行修改库存。
当前状态：T1507 已绑定 `Main/UI/MerchantPanel`；仅在商人到访时可交易，离场会刷新为不可用。

路径：`res://scripts/world/DefenseDevicePresenter.gd`、`res://scripts/world/DefenseDeviceView.gd`、`res://scenes/defense_devices/DefenseDeviceView.tscn`
用途：把权威部署快照转换为场景表现，并响应器械 action 信号。
依赖：只读 DefenseDeviceSystem 与 EventBus；每个 view 固定包含 `ModelMount`。
当前状态：T0112 后已绑定 `Main/WorldRoot/Station/DefenseDevices`；显示 HP / 有效射程并在宿主等级变化时刷新。T0132-P4a/P4b 已让 `DefenseDeviceView` 把部署快照和动作事件转交正式模型，弩床与箭塔分别使用各自 FormalArtView 场景。

路径：`res://scripts/ui/DefenseSlotPresenter.gd`
用途：把器械槽世界坐标投影为屏幕交互，并显示部署选择。
依赖：只读 DefenseDeviceSystem、BuildingSystem、ResourceSystem、Camera3D 与相关状态信号；部署只调用 `deploy_device(...)`。
当前状态：T0112 后只为已解锁空槽显示圆形 `+`，锁定槽与已占槽都隐藏标记；两器械部署卡在窗口放大时仍按内容收束，无实际倍率时隐藏加成行，围墙加固与主厅高台倍率只在生效时显示。

路径：`res://scripts/ui/HUD.gd`
用途：HUD 展示脚本，刷新标题区下方的天数、`HH:MM:SS` 时间 / 阶段、主栏资源、具体装备 / 器械详情、速度 / 暂停按钮和后端状态占位。
依赖：读取 GameState，监听时间与资源信号，从 ResourceSystem 读取定义 / 库存，从 EquipmentSystem / NPCSystem / HorseSystem 读取装备详情与真实马匹汇总。
当前状态：T0036/T0038 后按 `show_in_main_hud` 过滤主栏，旧聚合资源不显示；“装备”详情按 `detail_group` 投影具体武器、盔甲并追加存活马匹；“器械”详情显示弩床 / 箭塔具体库存和部署。T0129C-A5-P3 后波次栏读取 CombatSystem 轻量 HUD 快照，普通倍率按游戏分钟刷新，LLM 慢速精确秒仍逐秒刷新。HUD 只读系统状态，不直接修改资源、装备、马匹或器械事实。
当前状态：T0604 后，HUD 后端状态会读取 `LLMBridge.get_last_backend_status()` 并监听 `backend_status_changed`；T0401 已接入真实时间推进、秒级时间显示、速度按钮、暂停按钮和空格暂停；速度按钮显示玩家设定倍率，空格只触发暂停/继续，不触发速度切换；LLM 等待造成的有效逻辑倍率由 TimeSystem 提供给后续调试 UI；T0012 已接入真实资源主栏去重与装备/器械详情定位；2026-05-20 已让 HUD 根节点忽略鼠标，避免全屏背板拦截建筑点击；T1103 后警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")` 触发集结；T1204A 后 HUD 会在任一 NPC 正在逃离或昏迷暂停逃离时显示“警告：某人正在逃离驿站”。

路径：`res://scripts/ui/UIInputFocusManager.gd`
用途：Main UI 层输入焦点管理脚本，统一处理 LineEdit / TextEdit 点击外部失焦。
依赖：挂载到 `Main/UI`，读取当前 GUI 焦点和鼠标悬停 Control，不参与资源、HP、事件或行动结算。
当前状态：T0704 反馈修正已创建；任意文本输入控件获得焦点后，点击输入框外任意位置会释放焦点，NPC 给钱数量框、对话输入框和指令 TextEdit 已纳入验证。

路径：`res://scripts/ui/BuildingPanel.gd`
用途：建筑信息面板脚本，展示基础建筑 / 工位 / 修复升级，以及制造项目和马匹个体状态。
依赖：监听建筑、制造和马匹状态信号；从 BuildingSystem / CraftingSystem / HorseSystem / NPCSystem 读取只读快照，只把制造目标选择交给 CraftingSystem。
当前状态：基础工位、修复 / 升级和面板互斥规则保持不变。T0035 后铁匠铺 / 工械坊显示配方下拉、当前阶段、已完成 / 总阶段、实时进度条和 active 工人；非零进度更换目标先弹 ConfirmationDialog，只有确认才清零并切换。马厩顶部显示“在厩 / 离厩”汇总；T0271 后逐匹卡片只显示中文名称、毛色、成年 / 小马、中文编号马槽、HP、自然 / 照料额外上限、饱食、成长、进食和分配对象，不显示内部 horse id 或重复位置；修复 / 升级浮动提示位于 UI 覆盖层，响应式刷新不再先撑满屏幕高度。

T0043/T0127 补充：通用位置区不再按 type 聚合，而按 `building.workstations` 配置顺序逐项显示“具体位置名：空闲 / 已为 NPC 预留 / NPC 名占用中”；服务人员位置在前、承载位置在后，并显示建筑状态与精确运作效率。UI 不使用“主动 / 被动工位”术语，也不自行分配或提交位置。

路径：`res://scripts/ui/NPCPanel.gd`
用途：NPC 信息面板脚本，监听 NPC 点击和状态变化并展示 NPC 基础状态。
依赖：监听 `/root/EventBus.npc_clicked`、`/root/EventBus.npc_state_changed` 和 `/root/EventBus.building_clicked`，从 `Main/Systems/NPCSystem` 读取 NPC 档案与状态。
T0024 补充：事件库上方改为“当前计划 / 日记 / 知识”三等分按钮，共用详情弹窗读取当前计划、增量日记和替换式知识图谱；不再在面板正文动态创建日记滚动区。
当前状态：`Main/UI/NPCPanel` 监听 NPC 状态、记忆和计划信号，显示权威成长、战斗属性、计划、日记及记忆详情。T0268 后标题栏在背景按钮右侧直接显示当前行动与灰暗行为模式；玩家入口使用“当前计划 / 日记 / 认识”和“事件 / 见闻”，不显示库名或条数。T0271 后力量 / 智力与战斗最终值不再带冗余字段前缀，旧装备摘要保持空且隐藏；饱食 / 疲劳由 NPCNeedsSystem 配置边界投影为标签在上、条件变色进度条在下。非对话交互用互斥“公开 / 私下”圆形单选映射 `local_public / private`；装备由单一按钮打开六槽窗口，所有权威事实仍由原系统裁决。

路径：`res://scripts/ui/OrderPanel.gd`
用途：已入伍 NPC 自然语言指令撰写与发布面板。
依赖：调用 `NPCSystem.get_current_order(...)` / `publish_npc_order(...)`；内嵌于 `Main/UI/OrderPanel`。
当前状态：T0703 已实现；打开时预填当前指令，发布变化文本时显示修订结果，关闭或相同文本无副作用。

路径：`tools/verify_npc_damage_unconscious.gd`
用途：验证 T0501 NPC HP 扣除、昏迷状态、行动阻断和同地点见闻传播。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem`、`MemorySystem` 和 `NPCPanel`。
当前状态：T0501 已创建；验证致命伤害会把 HP 降到 0、设置昏迷、阻止行动和移动，并让同地点 NPC 收到 `unconscious_started` 见闻。

路径：`tools/verify_npc_unconscious_natural_recovery.gd`
用途：验证 T0502 NPC 昏迷自然恢复、自动复苏、复苏事件和复苏后行动恢复。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`NPCSystem.debug_advance_unconscious_recovery(...)`、`ActionSystem` 和 `MemorySystem`。
当前状态：T0502/T0502A 已创建；验证昏迷 NPC 每游戏小时恢复 2 HP，达到 Max HP 30% 后写入 `revived`、同地点 NPC 收到见闻，并重新允许行动指派；同时验证昏迷期间拒收见闻、复苏后重新接收见闻。

路径：`tools/verify_npc_unconscious_healing.gd`
用途：验证 T0503 NPC 昏迷协助治疗、治疗者上限、治疗消耗、医术加速、治疗事件和资源不足失败。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem.debug_assign_heal_assist(...)`、`ResourceSystem` 和 `MemorySystem`。
当前状态：T0503 已创建；验证其他 NPC 可协助治疗昏迷目标，每个目标最多 2 名治疗者，治疗会持续消耗第纳尔，高医术治疗明显快于自然恢复；治疗事件进入治疗者和目标事件库、同地点其他在场 NPC 见闻库，且不暴露医术熟练度。

路径：`res://scripts/ui/GMPanel.gd`
用途：GM 调试面板脚本，为 M1-M4 已完成但前端不易直接验证的系统能力提供可拖动按钮、命令输入框、调试按钮和结果输出。
依赖：挂载到 `Main/UI/GMPanel`；调用 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem` 和 `CombatSystem` 的已有公开接口或 `debug_*` 接口；使用顶部 `GM_ENABLED` 常量控制开发/上线显示。
当前状态：GM 面板支持资源、时间、建筑、NPC、行动、记忆、公告、征募、技能点、战斗波次、警铃集结、策略、逃离和结算等已有系统的调试入口；`snapshot` / `time_snapshot` 可查看倍率与时间上限，战斗区支持生成、跳转、推进和清除敌人。T0252 后“正式行动”页拥有独立 NPC 选择器，普通行动、拜访、对话、修复、升级、治疗及其停止 / 快照入口统一读取该页选择，不再依赖“常用”页隐藏状态。T0121 没有新增按钮，既有入口已经可以验证五波、器械和主厅失败；旧 `combatant_availability` 只可作为观察性快照，不再触发失败。GMPanel 只转发现有权威接口，不自行结算资源、伤害或胜负。

路径：`res://scripts/camera/CameraRig.gd`
用途：基础俯视摄像机控制脚本，驱动 `Main/CameraRig` 的平移和 `CameraRig/Camera3D` 的本地距离缩放。
依赖：绑定到 `res://scenes/main/Main.tscn` 的 `CameraRig`，读取键盘 WASD / Shift 按下与释放事件、鼠标中键拖拽和滚轮输入；查询当前 GUI 文本焦点以避免输入时平移。
当前状态：T0105 已创建并绑定；T0045B 后 WASD 基础速度为 `28 m/s`，Shift+WASD 为 `56 m/s`；支持 X/Z 边界限制、缩放距离限制，并保持高机位俯视角；T1101 后 Z 轴正向边界扩展到可查看正门外敌人生成区。不实现角色控制或第一人称自由视角。

## Godot 脚本规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 事件总线 | `res://scripts/core/EventBus.gd` | 全局信号 |
| 游戏状态 | `res://scripts/core/GameState.gd` | 全局状态 |
| 配置加载 | `res://scripts/core/ConfigLoader.gd` | JSON 配置加载 |
| 时间系统 | `res://scripts/systems/TimeSystem.gd` | 天数、阶段、加速、慢速请求与敌人在场 1:1 逻辑时间 |
| NPC 生活消耗 | `res://scripts/systems/NPCNeedsSystem.gd` | 饱食 / 疲劳档位、有效时间、小数余量与边界 |
| 资源系统 | `res://scripts/systems/ResourceSystem.gd` | 金钱、粮食等 |
| 建筑系统 | `res://scripts/systems/BuildingSystem.gd` | 建筑 HP、等级、逐位置状态、可进入性、损伤效率与升级封闭 |
| NPC 系统 | `res://scripts/systems/NPCSystem.gd` | NPC 生成与管理、正式室内路线、诊所安全导航点与贴床表现挂接 |
| NPC 展示脚本 | `res://scripts/npc/NPC.gd` | NPC 占位实体、标签和点击事件 |
| 行动系统 | `res://scripts/systems/ActionSystem.gd` | 工作、吃饭、睡觉、训练 |
| 制造系统 | `res://scripts/systems/CraftingSystem.gd` | 配方目标、阶段、项目进度与具体成品入库 |
| 马匹系统 | `res://scripts/systems/HorseSystem.gd` | 马匹生态、成长 / 生育、分配与战时骑乘 |
| 对话系统 | `res://scripts/systems/DialogSystem.gd` | 与后端对话 |
| 征召系统 | `res://scripts/systems/RecruitmentSystem.gd` | 入伍状态 |
| 记忆系统 | `res://scripts/systems/MemorySystem.gd` | 事件、见闻、短期记忆 |
| 商人系统 | `res://scripts/systems/MerchantSystem.gd` | 到访时段、报价、资源买卖与交易事件 |
| 工程器械系统 | `res://scripts/systems/DefenseDeviceSystem.gd` | 器械配置、槽位、部署和自动效果 |
| 工程器械表现 | `res://scripts/world/DefenseDevicePresenter.gd`、`res://scripts/world/DefenseDeviceView.gd` | 部署快照可视化和模型替换挂点 |
| 游戏启动编排 | `res://scripts/systems/GameStartupSystem.gd` | 三状态启动与 NPC 新一天循环 |
| 战斗系统 | `res://scripts/systems/CombatSystem.gd` | 攻击、策略、波次 |
| 昏迷系统 | `res://scripts/systems/UnconsciousSystem.gd` | 昏迷、治疗、复苏 |
| LLM 桥接 | `res://scripts/systems/LLMBridge.gd` | HTTP 请求后端 |
| HUD 展示 | `res://scripts/ui/HUD.gd` | 时间、资源、按钮和后端状态占位 |
| 建筑面板 | `res://scripts/ui/BuildingPanel.gd` | 建筑状态、精确效率、逐位置占用展示与修复/升级按钮 |
| NPC 面板 | `res://scripts/ui/NPCPanel.gd` | NPC 基础状态展示与刷新 |
| 公告牌 UI | `res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd` | 公告点击、预览与“通告 / 参考日程”双 Tab 输入 |
| 商人 UI | `res://scripts/ui/MerchantPanel.gd` | 商人报价与交易请求 |
| 摄像机控制 | `res://scripts/camera/CameraRig.gd` | 俯视平移、缩放和边界限制 |

## 数据文件规划

| 内容 | 推荐路径 | 说明 |
|---|---|---|
| 资源定义 | `data/resource_defs.json` | 初始资源、显示顺序和基础分类 |
| 制造配方 | `data/crafting_recipes.json` | 铁匠铺 / 工械坊具体物品与分阶段材料 |
| 马匹定义 | `data/horse_defs.json` | 初始马匹与生态 / 成长 / 生育平衡参数 |
| 商人定义 | `data/merchant_defs.json` | 到访时段、可买卖资源和单价 |
| 工程器械定义 | `data/defense_device_defs.json` | 弩床 / 箭塔、围墙 / 主厅通用槽、效果与表现元数据 |
| NPC 档案 | `data/npc_profiles.json` | 8 个初始 NPC |
| NPC 初始长期记忆 | `data/npc_initial_long_memory.json` | 8 人开局前日记与替换式知识图谱种子 |
| 建筑定义 | `data/building_defs.json` | 建筑 HP、逐位置、固定类型、活动效率和逐级升级效果；公告牌不在此表中 |
| 行动定义 | `data/action_defs.json` | 工作、诊疗、训练、吃饭、睡觉、祈祷、主持弥撒及其位置映射 |
| 活动生活消耗 | `data/activity_needs.json` | 0–100 边界、每小时速率与行为模式映射 |
| 武器定义 | `data/weapon_defs.json` | 剑盾、长杆、弓、弩 |
| 盔甲定义 | `data/armor_defs.json` | 头盔、胸甲、腕甲、腿甲 |
| 坐骑定义 | `data/mount_defs.json` | HorseSystem 同步装备槽时使用的通用骑乘参数 |
| 敌人波次 | `data/enemy_waves.json` | 5 波 Demo |
| Prompt 模板 | `data/prompts/*.txt` | 计划、对话、判定、总结 |

## 数据文件当前已创建

路径：`data/resource_defs.json`
用途：资源配置，记录资源 id、显示名、分类、初始数量、最小值和 HUD 顺序。
依赖：由 `ResourceSystem` 通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取。
当前状态：除第纳尔、粮食、餐食、酒、木材、石料、铁外，T0036 已加入剑盾、长杆武器、弓、弩、铁盔、锁子甲、铁护腕、铁护腿、弩床、箭塔 10 种具体 `crafted_item`。具体物品通过 `detail_group` 进入装备 / 器械详情，`show_in_main_hud=false` 不占主栏。`weapons` / `armor` / `defense_devices` / `horse_readiness` 仅为兼容项，已标记弃用、正式结算禁用并从 HUD 隐藏。

路径：`data/crafting_recipes.json`
用途：铁匠铺 / 工械坊具体物品配方、阶段顺序和逐阶段材料成本。
依赖：由 CraftingSystem 读取，ActionSystem 只提交工作周期，BuildingPanel 只读配方和项目快照。
当前状态：T0035 已创建 10 个制造配方。铁匠铺包含铁盔、铁护腕、长杆、铁护腿、剑盾、锁子甲；工械坊包含弓、弩、弩床、箭塔。每个阶段单独声明材料，全部阶段完成才产出 1 件对应 `item_*`。

路径：`data/horse_defs.json`
用途：初始马匹与马匹饱食、进食、恢复、成长、生育和照料额外 HP 平衡配置。
依赖：由 HorseSystem 读取；不作为装备匿名库存或战斗伤害定义。
当前状态：T0056 后初始栗风、灰鬃成长均为 0.6；配置马厩 / 离厩饱食消耗、20% 缺口触发进食、进食周期与粮食恢复、自然 HP 恢复、幼马 / 完全成长上限、成年阈值、基础成长时长、逐分钟繁育概率增量 / 上限、1440 分钟产后冷却和养马额外 HP 上限。`stable_level_birth_bonus_per_level=0.1` 只用于繁育概率增量，即马厩每升一级 +10%，不影响成长、进食或自然恢复。

路径：`data/merchant_defs.json`
用途：配置后门商人身份、地点、每日到达/离开时间和买卖报价。
依赖：由 MerchantSystem 通过 ConfigLoader 读取。
当前状态：T1507 已创建；商人每天 10:00 到达、16:00 离开，可向驿站出售粮食/木材/石料/铁并收购酒。价格只在此配置，不写死在 UI。

路径：`data/defense_device_defs.json`
用途：工程器械与围墙 / 主厅通用槽配置，记录成本、HP、防御、穿透、攻速、建筑等级要求、自动攻击、世界坐标、倍率、射界和表现元数据。
依赖：由 DefenseDeviceSystem 通过 ConfigLoader 读取；DefenseDevicePresenter / View 只消费系统规范化快照。
当前状态：包含围墙 / 主厅各 4 个通用槽；围墙槽所需等级为 `1 / 2 / 4 / 6`，主厅按 ID 为 `5 / 6 / 1 / 3`，主厅 `range_multiplier=1.0`。弩床 / 箭塔同为 Tier 1，分别形成高伤远射低耐久与速射高耐久定位；具体库存成本保持独立。T0132-P4a/P4b 已为两者分别设置正式 `model_scene / projectile_speed / reload_fraction`。

路径：`data/building_defs.json`
用途：建筑配置，记录建筑 id、等级、HP、标签、工作位、输入输出、修复和升级规则。
依赖：由 `BuildingSystem` 通过 `ConfigLoader.load_data_file("building_defs.json")` 读取，并通过 `scene_nodes` 绑定到低模建筑实体。
当前状态：T0206 后为 15 条建筑/门墙定义，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊；所有建筑都有 `upgrade` 最小规则，既有关键建筑保留 `repair` 规则，`repair` 可配置每点缺失 HP 耗时和等级耗时系数。T0043 后不可进入建筑不保留内部位置；小教堂固定 `chapel_altar ×1 + chapel_prayer_seat ×10`，小诊所初始 `clinic_doctor_station ×1 + clinic_patient_bed ×2`，训练场初始 `training_instructor_station ×1 + training_practice_slot ×2`，食堂初始 `dining_kitchen_station ×1 + dining_seat ×10`，宿舍固定 `dormitory_bed ×10`。诊疗位、病床、教官位、训练位和灶台可按逐级配置扩容；祭坛、祈祷席、用餐席和宿舍床位固定。升级配置还可增加效率与 Max HP；T0110 后围墙 / 主厅以 `max_level=6` 和完整 `level_effects` 配置每级成本、工期和耐久收益。公告牌仍独立于建筑定义。

路径：`data/action_defs.json`
用途：行动配置，记录行动 id、类型、地点需求、技能、耗时、资源输入输出、唯一生活消耗档位和可选有效工时经验。
依赖：由 `ActionSystem` 读取并作为 NPC 日程与工作白名单。
当前状态：`ActionSystem` 读取 24 个行动定义，覆盖生产、制造、照料、治疗、训练、吃饭、睡觉、祈祷和参数化协助。`work_blacksmith` / `work_workshop` 在 T0121 后为 5400 秒基础周期，阶段材料和成品由 CraftingSystem 结算；菜园、酒窖与马厩仍为 3600 秒基础工作周期，吃饭 1200 秒、睡觉 23400 秒。菜园产出受耕种 / 力量 / 建筑等级缩放，食堂一粮基础产两餐，酒窖一粮产酒且不自动换钱；治疗需要医生与病床同时工作并消耗第纳尔。所有定义声明唯一 `needs_profile`，协助行动通过 `timed_experience` 累计对应技能。

路径：`data/activity_needs.json`
用途：NPC 活动生活消耗配置，记录 0–100 边界、每小时饱食 / 疲劳速率、行为模式映射、动态 idle / movement / unconscious 档位和说明。
依赖：由 `NPCNeedsSystem` 通过 ConfigLoader 读取；行动通过 `needs_profile` 引用，不复制数值。
当前状态：T0081 已覆盖 idle、dialogue、visit、movement、rally、avoid_combat、escape、combat、轻 / 重工作、两类训练、吃饭、睡眠、病床、祈祷、饮酒和昏迷休息。

T0043 补充：诊所 / 训练位置类型已替换为 `clinic_doctor_station`、`clinic_patient_bed`、`training_instructor_station`、`training_practice_slot`；吃饭、睡觉、普通祈祷和主持弥撒分别映射 `dining_seat`、`dormitory_bed`、`chapel_prayer_seat`、`chapel_altar`。`lead_mass` 对所有 NPC 可见但要求“主持弥撒”能力。NPC 不选择编号，满位 / 封闭失败由程序返回并触发计划重估。

路径：`data/weapon_defs.json`
用途：主武器配置，记录武器类型、装备槽、库存来源、射程、伤害、防御、穿透、攻速修正、攻击间隔、技能需求和兵种分类辅助字段。
依赖：由 `EquipmentSystem` 读取；后续战斗系统可继续读取其中的数值字段。
当前状态：只包含剑盾、长杆、弓和弩四类正式主武器，具体库存不可互换。T0107 后四类武器提供不同防御 / 穿透 / 攻速修正；CombatSystem 以战斗动作秒推进冷却并把最终攻速换算为间隔。不实现耐久或品质。

路径：`data/armor_defs.json`
用途：盔甲配置，记录头盔、胸甲、腕甲、腿甲的库存来源、护甲值、攻击 / 穿透 / 攻速修正和重量占位。
依赖：由 `EquipmentSystem` 读取。
当前状态：包含铁盔、锁子甲、铁护腕和铁护腿，装备 / 卸装逐件结算；T0107 后重甲以攻速负修正换防御，护腕提供小额攻击 / 穿透。

路径：`data/mount_defs.json`
用途：真实马匹同步到 NPC 坐骑槽时使用的通用骑乘参数模板。
依赖：由 EquipmentSystem 读取定义，由 HorseSystem 注入具体 `horse_id` / `horse_name` 后写入装备槽。
当前状态：`riding_horse` 不声明库存来源；日常分配马仍在马厩，只有 `rally` / `combat` 显示骑乘。T0107 后模板包含骑乘速度、攻速、冲锋速度、武器增伤、马匹冲撞伤害、骑术缩放与僵直时长。

路径：`data/enemy_waves.json`
用途：敌人波次配置，记录波次编号、触发时间、正门外生成点、生成位置、生成散布和敌人组数值。
依赖：由 `CombatSystem` 通过 `ConfigLoader.load_data_file("enemy_waves.json")` 读取。
当前状态：T0121 后 5 波总数为 `8 / 16 / 24 / 36 / 48`，敌人个体整体弱于我方平均武装单位，后期主要靠人数、远程和骑兵混编提高压力；第二、四波是相对难度峰值。敌人组包含穿透、规范攻速、兼容间隔和攻击抬手，抬手可被僵直打断。自动来袭固定在第 3–7 天每天 18:00，目标过滤围墙并按附近单位 / 器械、城门、仓库、主厅推进。

路径：`data/npc_initial_long_memory.json`
用途：独立保存 8 名初始 NPC 的开局前日记和知识图谱，不与根本人设或运行时权威状态混写。
依赖：由 `NPCSystem` 与 `npc_profiles.json` 同时读取；两者 NPC id 必须完全一致，验证通过后才生成 NPC。
当前状态：T0059 已配置 8 人 × 3 篇第一人称生命切片；T0061 起前两篇分别承担宏观身世 / 来站原因与按一致时序相互拼接的到站群像，近日篇继续保留 T0060 的微观站内生活。每人图谱覆盖其余 7 人、守备官、全部 15 座配置建筑和至少 2 个个人故事主体；T0101 后守备官统一包含 `role / arrival_at_station / past_before_station / pre_game_relationship` 四条关系，建筑中文 `relation_label / value_label` 使用世界内叙事。T0070 后新增 4 条职业关键规则，8 条仓库技术值更新为 `level_based_bulk_storage_and_post_breach_attack_target`；当前共 250 条关系，`confidence / day / time` 完整保留。后续反思在运行态追加 / 替换，不回写本文件。

路径：`data/npc_profiles.json`
用途：NPC 档案配置，记录身份、性格、欲望、恐惧、底线、基础 / 战斗数值、状态、技能、入伍状态、装备、知识图谱和日记。
依赖：由 `NPCSystem` 通过 `ConfigLoader.load_data_file("npc_profiles.json")` 读取并生成 NPC 实体。
当前状态：8 名初始 NPC 的正式 Demo 短档案为托马 / 马夫、布鲁诺 / 厨子、伊沃 / 园丁、格伦 / 铁匠、艾达 / 老兵副官、马塞尔 / 神父、莉娜 / 医生、欧文 / 工程师。每人包含基础外观、人设、状态、技能、装备、计划与空记忆占位；T0107 后另有按设定区分的 `combat_base.attack_power / defense / penetration / attack_speed_multiplier`，只供 CombatSystem 使用，不进入 Prompt。具体开局历史和知识仍来自 `data/npc_initial_long_memory.json`。

路径：`data/prompts/dialogue_system_prompt.txt`
用途：`/npc/dialogue` 真实 provider 的系统 Prompt 模板，覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=dialogue` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T1402 已接入；T0100 起模板读取精简 `religion`、宽松 `speech_style` 与其他稳定人设，从目标 NPC 的职业经验、关注点和判断习惯出发回应，不读取或模仿固定样例句。T0087 后模板按 `dialogue_kind` 分别限制 `recruitment_result / wartime_reaction`、`invitation_result / should_end_dialogue` 与 `escape_intervention_result=stay|leave`，不再使用通用 `intent`。T1501 的 mock / fake real-provider 与 8 人真实 DeepSeek 职业身份对话保留为历史验收；当前版本的静态、Prompt、Mock / endpoint、Godot 与真实 DeepSeek 复验均已完成。

路径：`data/prompts/daily_plan_system_prompt.txt`
用途：`/npc/plan_day` 真实 provider 的系统 Prompt 模板，覆盖每日 24 小时计划生成。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=plan_day` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T1403/T0085 已接入；模板要求输出 0-23 点共 24 阶段、只使用 `allowed_actions` / `idle`，并强烈建议通常至少 6 个工作阶段但明确这不是程序硬门槛。`current_order` 只能作为守备官当前指令参考，不能越过行动白名单、资源、HP、地点、建筑、工位或程序强制层。

路径：`data/prompts/plan_revision_judgement_system_prompt.txt`
用途：`/npc/plan_revision_judgement` 的范围判别系统 Prompt，根据完整本轮对话或程序权威行动失败事实、原计划和共享人物 / 记忆 / 指令上下文返回 0 个或若干个需要修改的精确小时。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=plan_revision_judgement` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T0049/T0050 已接入；`revision_hours=[]` 明确表示不需要后续修订，非空集合必须升序、去重且不早于当前小时。失败工作阶段改为非工作且原计划处于最低工作数时，判别还需选择最少未来补偿阶段。该 Prompt 不生成新计划、不修改权威状态。

路径：`data/prompts/plan_revision_system_prompt.txt`
用途：`/npc/revise_plan` 真实 provider 的精确阶段计划修订 Prompt，只返回请求 `revision_hours` 中的小时。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=revise_plan` 时读取；后端 `backend/app.py` 在 Schema 后校验响应与请求小时集合完全一致、行动白名单、即时行动一致性和工作阶段。
当前状态：T0049 已把唯一合同改为 `revision_scope=selected_hours`；`revised_plan` 恰好覆盖 `revision_hours`，只有集合包含当前小时时才输出匹配的 `immediate_action`，否则必须为 `null`。既有完整上下文、reason / summary 长度、fake / real provider 与 Godot 异步边界继续保留。

路径：`data/prompts/battle_judgement_system_prompt.txt`
用途：`/npc/battle_judgement` 真实 provider 的系统 Prompt 模板，覆盖战时低血量自身心理判定。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=battle_judgement` 时读取，并与通用 JSON / Schema guard 拼接；后端 `backend/app.py` 会在响应 Schema 校验后继续做业务约束校验。
当前状态：T1404 已接入；模板要求引用 NPC 亲历事件、公开见闻、`battlefield_context` 和 `current_order`，但只能从请求的 `allowed_decisions` 中选择，且 `current_order` 不能强制参战或强制逃离。后端会拒绝越界 `decision` 和逃离布尔不一致结果。已通过 fake real-provider 验证和真实 DeepSeek `/npc/battle_judgement` smoke test。

路径：`data/prompts/daily_reflection_system_prompt.txt`
用途：`/npc/daily_reflection` 真实 provider 的系统 Prompt 模板，覆盖首次睡眠总结、第一人称日记和知识图谱替换式更新。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=daily_reflection` 时读取，并与通用 JSON / Schema guard 拼接；后端 `backend/app.py` 会在响应 Schema 校验后继续做业务约束校验。
当前状态：T1405 已接入；模板要求区分亲历事件与见闻，输出符合 NPC 语气的 `diary_entry`，并把 `knowledge_graph_updates` 作为 `subject + relation -> value` 的当前状态更新，不能把知识图谱写成增量日记。后端会拒绝 NPC / 日期不匹配、空字段和世界内文本使用“玩家”的结果。已通过 fake real-provider 验证和真实 DeepSeek `/npc/daily_reflection` smoke test。

## 后端模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 后端入口 | `backend/app.py` | Flask/FastAPI 入口 |
| 模型适配器 | `backend/services/model_adapter.py` | DeepSeek/MiniMax 等统一接口 |
| 对话服务 | `backend/services/dialog_service.py` | NPC 对话 |
| 计划服务 | `backend/services/planning_service.py` | 每日计划 |
| 判定服务 | `backend/services/judgement_service.py` | 战斗/逃离判定 |
| 记忆服务 | `backend/services/memory_service.py` | 总结、知识图谱 |
| 成本统计 | `backend/services/budget_service.py` | token 与费用 |
| 数据模型 | `backend/schemas/*.py` | Pydantic 或 dataclass |

## 后端当前已创建

路径：`backend/app.py`
用途：Flask 后端入口，当前提供 `GET /health`、`GET /debug/llm_usage`、`POST /mock/model`，以及 `/npc/dialogue`、`/npc/plan_revision_judgement`、`/npc/plan_day`、`/npc/revise_plan`、`/npc/battle_judgement`、`/npc/daily_reflection` 六类正式业务接口；旧对话判别 URL 保留兼容。
依赖：`flask`, `python-dotenv`。
当前状态：业务接口复用同一个 `ModelAdapter` 实例保留 usage；`GET /health` 返回非敏感运行配置。所有业务先校验请求 / 响应 Schema；`/npc/plan_revision_judgement` 还校验触发类型所需事实、NPC id、`needs_revision` 与小时集合一致性及时间边界；`/npc/plan_day` 校验 24 小时覆盖、白名单和工作阶段；`/npc/revise_plan` 校验 NPC id、响应与请求 `revision_hours` 完全一致、白名单、工作阶段和即时行动一致性。六个正式 LLM 成功接口统一通过 `model_success_payload(...)` 附加 provider 元数据。不合法结果记录 `model_output_invalid`；预算超限返回 HTTP 429，生产 / Demo 默认不自动 mock fallback。

路径：`backend/requirements.txt`
用途：记录 Python 后端依赖。
依赖：至少包含 `flask`, `python-dotenv`, `pydantic`, `requests`。
当前状态：T0002 已确认可用于安装后端最小依赖。

路径：`backend/.env.example`
用途：本地 `.env` 配置模板。
依赖：无。
当前状态：默认 `LLM_PROVIDER=mock` 服务本地开发；真实 provider 配置包含 `LLM_THINKING_MODE=disabled`、温度、JSON 模式、成本和累计预算变量，不包含客户端单次输出 token 上限。真实 API Key 只放本地 `backend/.env` 或服务器环境。

路径：`backend/services/model_adapter.py`
用途：模型供应商适配器边界，后续由对话、计划、判定服务复用。
依赖：环境变量 `LLM_PROVIDER`, `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`, `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS`, `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS`, `LLM_FALLBACK_TO_MOCK`, `LLM_THINKING_MODE`、成本与累计预算变量。
当前状态：支持 mock、DeepSeek 和 OpenAI-compatible provider，生产自动 mock fallback 默认关闭。六类正式 call_type 使用流式 SSE，不发送客户端单次输出 token 上限、不设置生成总时长，并在 JSON 为空、截断或非法时按业务紧凑重试一次。`plan_revision_judgement` 与 `revise_plan` 分别读取人物上下文一致的范围判别和精确修订 Prompt；旧 dialogue call type 映射到通用 Prompt。Usage 记录 provider/model、request/NPC、token、费用、`finish_reason`、响应长度、尝试次数、HTTP / 异常、Schema / 预算错误和降级来源。

路径：`backend/schemas/common.py`
用途：后端 AI 接口共享 Schema，定义游戏时间、请求元信息、事件摘要、短期记忆、NPC 身份/状态/上下文、行动候选和通用错误响应。
依赖：`pydantic`。
当前状态：T0601 已创建；T0703A 新增 `CurrentOrderContext` 并接入共享 `NPCContext`，让所有复用该上下文的 NPC 中心请求携带最新指令。T0100 后 `NPCIdentity` 显式包含精简 `religion`，语言字段仍只保留宽松 `speech_style`，固定 `signature_lines` 已删除；Schema 只提供数据模型，不调用 LLM，也不改变游戏权威状态。

路径：`backend/schemas/npc_ai.py`
用途：NPC AI 请求/响应 Schema，覆盖玩家-NPC / NPC-NPC / 逃离挽留对话、对话 / 行动失败通用计划修改判别、每日计划、精确小时计划修订、战斗判定、首次睡眠总结、知识图谱更新、主动交涉和玩家话术分类。
依赖：`pydantic`，复用 `backend/schemas/common.py`。
当前状态：T0603 后，对话请求 Schema 已重整为显式输入；T0703A 新增顶层 `current_order`，并让每日计划、修订、战斗判定、首次睡眠总结等通过共享 `NPCContext.current_order` 复用最新指令。T0049/T0050 定义 `PlanRevisionJudgementRequest/Response`，通过 `trigger_kind` 选择完整对话或权威行动失败事实、原计划和可为空的精确 `revision_hours`；旧 `DialoguePlanRevisionJudgement*` 名为兼容别名，`PlanRevisionRequest` 只接受 `selected_hours` 与非空精确小时。T1202 后，`BattleJudgementRequest` 包含 `combat_context`、`battlefield_context` 和 Godot 提供的 `allowed_decisions`，用于低血量自身心理判定。T0087 后，统一 `NPCDialogueRequest` 按 `dialogue_kind` 分派到 `PlayerNPCDialogueResponse / NPCNPCDialogueResponse / EscapeInterventionDialogueResponse`，三个响应禁止额外字段；逃离挽留使用 `escape_intervention_result=stay|leave`，攻击不走对话 Schema。战斗判定响应继续使用 `BattleJudgementResponse.decision` 表达允许集合内的意向。

路径：`backend/schemas/__init__.py`
用途：统一导出后端 Schema 类型。
依赖：`backend/schemas/common.py`、`backend/schemas/npc_ai.py`。
当前状态：T0601 已创建。

路径：`backend/schemas/README.md`
用途：记录后端 Schema 分组和权威边界。
依赖：无。
当前状态：T0601 已创建。

路径：`backend/services/`, `backend/data/`
用途：后端服务层和后端本地数据目录。
依赖：暂时无。
当前状态：T0002 创建目录骨架，用 `.gitkeep` 保留空目录。

## 更新规则

新增任何实际文件后，在本文件加入：

```text
路径：
用途：
依赖：
当前状态：
```
## Tools

| 内容 | 文件 |
|---|---|
| Godot MCP 连接与拓扑自检（区分正常 6550 owner、8765 broker 与已建立连接） | `tools/check_godot_mcp.ps1` |
| Godot MCP fresh proxy / 多会话隔离 / 单 broker 拓扑验证（失败时输出子 proxy stderr） | `tools/verify_godot_mcp_topology.mjs` |
| 建筑修复/升级验证 | `tools/verify_building_repair_upgrade.gd` |
| 建筑面板工位显示验证 | `tools/verify_building_panel_workstations.gd` |
| 七类工作建筑初始双主工位与 1–3 级容量曲线验证 | `tools/verify_initial_dual_workstations.gd` |
| 固定宿舍床位、空余床与重复睡眠验证 | `tools/verify_fixed_dormitory_beds.gd` |
| 五建筑位置、资格、团队效率、升级封闭与损伤效率综合验证 | `tools/verify_building_service_positions.gd` |
| NPC 面板与状态验证 | `tools/verify_npc_panel_state.gd` |
| NPC 移动与地点验证 | `tools/verify_npc_movement_location.gd` |
| NPC 移动期间统一时间慢速、并发 / LLM / 暂停叠加与逻辑时间消费者验证 | `tools/verify_npc_movement_time_slowdown.gd` |
| NPC 熟练度 schema 验证 | `tools/verify_npc_skill_schema.gd` |
| NPC 姓名、人设、宗教信仰、职业语气与 LLM 上下文验证 | `tools/verify_npc_character_profiles.gd` |
| 简单行动系统验证 | `tools/verify_action_system_basic.gd` |
| 职业工作产出框架验证 | `tools/verify_work_output_framework.gd` |
| 食堂粮食加工餐食验证 | `tools/verify_dining_hall_meals.gd` |
| 菜园粮食产出验证 | `tools/verify_garden_grain_output.gd` |
| 旧 T0804-T0806 聚合生产历史回归 | `tools/verify_blacksmith_metal_gear.gd`、`tools/verify_workshop_ranged_devices.gd`、`tools/verify_stable_horse_care.gd` |
| 具体配方与分阶段制造闭环验证 | `tools/verify_crafting_pipeline.gd` |
| 真实马匹生态、分配与战时生命周期验证 | `tools/verify_horse_ecology_assignment.gd` |
| T0138 骑战会合、战时换装锁、马匹分伤 / 阵亡、骑手昏迷解绑与返厩验证 | `tools/verify_mounted_combat_lifecycle.gd` |
| T0138-R1 马留在厩、NPC 绕开主厅取马并实际抵达上马验证 | `tools/verify_stable_horse_pickup_navigation.gd` |
| 马匹基础 / 额外 HP、初始成长、累积繁育概率、冷却与 UI 验证 | `tools/verify_horse_care_feedback.gd` |
| 酒窖酿酒、出售与 NPC 个人饮酒边界验证 | `tools/verify_tavern_wine_trade.gd`、`tools/verify_npc_wine_drinking.gd` |
| 公告牌输入与广场广播验证 | `tools/verify_notice_board_input.gd` |
| 商人时段、买卖与事件验证 | `tools/verify_merchant_trade_system.gd` |
| 具体弩床 / 箭塔库存、部署、战斗效果、事件与模型挂点验证 | `tools/verify_defense_device_deployment.gd` |
| T0132-P4a 弩床正式场景、PBR 结构、平台包络、发射 / 重装循环验证 | `tools/verify_t0132_p4a_ballista_art_slice.gd` |
| T0132-P4a 弩床待机、发射、重装与真实围墙平台 D3D12 画面采集 | `tools/capture_t0132_p4a_ballista_visuals.gd` |
| 递减防御、武器 / 骑术职责、六级错峰槽位和逐级升级提示验证 | `tools/verify_t0110_combat_balance.gd` |
| T0107 统一战斗属性、双建筑槽、Prompt 隔离、弱敌群与骑兵冲击综合验证 | `tools/verify_t0107_combat_foundation.gd` |
| 部署弹窗缩放 / 文案、锁定槽隐藏与围墙射程曲线验证 | `tools/verify_t0112_defense_deployment_ui.gd` |
| 小诊所治疗验证 | `tools/verify_clinic_treatment.gd` |
| 训练场熟练度验证 | `tools/verify_training_system.gd` |
| 熟练度经验与技能点验证 | `tools/verify_skill_progression.gd` |
| 三状态启动与正式游戏循环验证 | `tools/verify_game_startup_modes.gd` |
| 真实 8 NPC 并发开局与 `llm_plan_day` 来源验证 | `tools/verify_game_startup_real_async.gd` |
| 真实 8 NPC 并发首次睡眠总结、来源与长期记忆验证 | `tools/verify_daily_reflection_real_async.gd` |
| 正式计划拒绝 Mock provider 验证 | `tools/verify_formal_plan_real_only.gd` |
| 规则版每日计划验证 | `tools/verify_daily_plan_system.gd` |
| 真实失败不降级与显式开发 Mock 计划验证 | `tools/verify_daily_plan_llm.gd` |
| 行动异常与计划重评估验证；使用当前可用制造配方，并锁定缺材料 / 满工位在正式迁移前失败且无残留会话 | `tools/verify_daily_plan_reevaluation.gd` |
| 首次睡眠总结系统验证 | `tools/verify_daily_reflection_system.gd` |
| 对话懒打断、异步取消、对话窗攻击与首次睡眠总结边界验证 | `tools/verify_dialogue_sleep_summary_boundaries.gd` |
| 后端每日计划端点验证 | `tools/verify_plan_day_endpoint.py` |
| 后端计划修订端点验证 | `tools/verify_plan_revision_endpoint.py` |
| 后端首次睡眠总结端点验证 | `tools/verify_daily_reflection_endpoint.py` |
| 具体武器 / 盔甲库存与真实马匹分配装备验证 | `tools/verify_equipment_system.gd` |
| 兵种判定验证 | `tools/verify_unit_type_classification.gd` |
| 敌人波次与生成验证 | `tools/verify_enemy_wave_generation.gd` |
| 敌人波次倒计时与自动来袭验证 | `tools/verify_enemy_wave_schedule.gd` |
| 主厅失败条件验证 | `tools/verify_main_hall_failure.gd` |
| 零可战人员仍继续战斗验证（保留旧文件名） | `tools/verify_no_available_combatants_failure.gd` |
| T0121 全局数值合同验证 | `tools/verify_t0121_game_balance.gd` |
| T0121 第七天第五波成型构筑验证 | `tools/verify_t0121_fifth_wave_build.gd` |
| 第 5 波胜利条件验证 | `tools/verify_five_wave_victory.gd` |
| 敌人目标优先级验证 | `tools/verify_enemy_target_priority.gd` |
| 基础攻击与伤害验证 | `tools/verify_combat_damage.gd` |
| 敌人在场 1:1 战斗时间验证 | `tools/verify_combat_time_cap.gd` |
| T0184 城门前排小步攻击动画与真实命中验证 | `tools/verify_t0184_gate_attack_timeline.gd` |
| 战斗节奏验证 | `tools/verify_combat_pacing.gd` |
| 兵种战斗策略与避战距离验证 | `tools/verify_combat_strategies.gd` |
| 战斗开始 / 结束流程验证 | `tools/verify_combat_flow.gd` |
| 战时公开对话心理结果验证 | `tools/verify_wartime_dialogue.gd` |
| 低血量自身心理判定验证 | `tools/verify_low_hp_battle_judgement.gd` |
| 战场公开信息综合验证 | `tools/verify_battlefield_public_info.gd` |
| 逃离驿站行为验证 | `tools/verify_escape_station_behavior.gd` |
| 逃离挽留入口、暂停与攻击规则验证 | `tools/verify_escape_intervention_dialogue.gd` |
| 警铃与集结验证 | `tools/verify_combat_alarm_rally.gd` |
| NPC 行为模式状态机验证 | `tools/verify_behavior_mode_state_machine.gd` |
| 非战斗人员避战模式验证 | `tools/verify_avoid_combat_mode.gd` |
| HUD 具体物品分组、旧聚合隐藏与真实马匹汇总验证 | `tools/verify_hud_resources.gd` |
| 时间系统验证 | `tools/verify_time_system.gd` |
| 结构化事件底座验证 | `tools/verify_structured_memory_events.gd`；菜园 / 食堂 / 宿舍等待正式工位 active，缺材料制造验证迁移前失败 |
| 地点信息节点验证 | `tools/verify_location_info_nodes.gd` |
| 广场本地公开广播验证 | `tools/verify_plaza_local_public_broadcast.gd` |
| NPC 短期记忆容器验证 | `tools/verify_npc_short_term_memory_container.gd`；用餐事件夹具等待真实座位 active 后结算 |
| 行动事件本地公开广播验证 | `tools/verify_action_local_public_broadcast.gd` |
| NPC 扣血与昏迷验证 | `tools/verify_npc_damage_unconscious.gd` |
| NPC 昏迷自然恢复验证 | `tools/verify_npc_unconscious_natural_recovery.gd` |
| NPC 昏迷协助治疗验证 | `tools/verify_npc_unconscious_healing.gd` |
| NPC 面板非对话交互验证 | `tools/verify_npc_panel_interactions.gd`，T1006 起确认攻击入口已移出 NPC 面板 |
| NPC 主动交涉验证 | `tools/verify_npc_proactive_talk.gd` |
| GM 调试面板验证 | `tools/verify_gm_panel.gd` |
| 后端 Schema 验证 | `tools/verify_backend_schemas.py` |
| Mock / Real Model Adapter 验证 | `tools/verify_mock_model_adapter.py`；开发期 mock / fallback 验证不等于真实 API 验收 |
| `/npc/dialogue` Mock 接口验证 | `tools/verify_dialogue_mock_endpoint.py` |
| NPC 对话 Prompt fake real-provider 验证 | `tools/verify_dialogue_prompt.py` |
| NPC 对话 Prompt 真实 provider smoke 验证 | `tools/verify_dialogue_prompt_real.py` |
| 对话 / 行动失败通用计划修改判别 fake / endpoint 验证 | `tools/verify_dialogue_plan_revision_judgement.py` |
| 对话 / 行动失败通用计划修改判别真实 provider 验证 | `tools/verify_dialogue_plan_revision_judgement_real.py` |
| Godot 行动失败两段式判别 / 修订验证 | `tools/verify_action_failure_plan_revision_judgement.gd` |
| 8 名 NPC 职业身份对话真实 provider 验证 | `tools/verify_npc_character_dialogue_real.py` |
| 每日计划 Prompt fake real-provider 验证 | `tools/verify_plan_day_prompt.py` |
| 每日计划 Prompt 真实 provider smoke 验证 | `tools/verify_plan_day_prompt_real.py` |
| 战时 / 低血量心理 Prompt fake real-provider 验证 | `tools/verify_battle_judgement_prompt.py` |
| 战时 / 低血量心理 Prompt 真实 provider smoke 验证 | `tools/verify_battle_judgement_prompt_real.py` |
| 首次睡眠总结 Prompt fake real-provider 验证 | `tools/verify_daily_reflection_prompt.py` |
| 首次睡眠总结 Prompt 真实 provider smoke 验证 | `tools/verify_daily_reflection_prompt_real.py` |
| API 额度与调试信息验证 | `tools/verify_api_budget_debug.py` |
| LLM 正式 call_type 输出限制审计 | `tools/verify_llm_call_audit.py`，覆盖六类正式调用不发送 `max_tokens`、截断重试和运行配置快照 |
| Godot LLMBridge 验证 | `tools/verify_llm_bridge.gd`，T0604A 起包含不依赖 `curl.exe` / `OS.execute` 的静态检查；T1401 起覆盖 usage 查询不遗留慢速请求 |
| Godot LLM 时间降速审计 | `tools/verify_llm_time_slowdown_audit.gd`，覆盖六类正式同步 / 异步请求的慢速注册、释放、开局全局暂停边界与只读接口不降速 |
| 对话 UI、轮次与对话事件验证 | `tools/verify_dialogue_ui.gd` |
| NPC-NPC 自主对话气泡与只读旁听验证 | `tools/verify_npc_npc_dialogue_observer_ui.gd` |
| NPC-NPC 自主对话真实 provider 旁听与慢速验证 | `tools/verify_npc_npc_dialogue_observer_real.gd` |
| NPC-NPC 邀请、软轮次、单方结束与双方独立计划判别合同验证 | `tools/verify_dialogue_invitation_contract.gd` |
| 入伍 NPC 自然语言指令验证 | `tools/verify_npc_order.gd` |
| A5-P3 完整 Main 时间链与隔离战斗帧预算验证 | `tools/verify_t0129c_a5_p3_main_tick_budget.gd` |
## T0132-P3/P3R 围墙与城门表现

- `scripts/presentation/buildings/FormalFortificationArtView.gd`：14 段正式木栅寨墙、立柱 / 束梁 / 斜撑、巡逻道 / 木垛口、围墙六级增量、位于正门左右墙段而非门楼上的四个木制器械台及木构损伤投影；P3R3 删除升级期悬挂盒体，P3R4 让左右平台 / 横杆 / 旗面分别吸附真实墙切线，只读建筑与槽位权威。
- `scripts/presentation/buildings/FormalGateArtView.gd`：大小有别的木制正 / 后门门楼、低石垫、双扇实体门叶、友军 / 商队接近开门、敌军过滤和门毁开放投影。
- `scripts/world/StationLayoutController.gd`：隐藏旧城防灰盒视觉、保留原静态碰撞 / 导航，并挂载 `FortificationArt`；P3R4 在 `north_west_a / north_east` 实墙段分别采样四个槽位，输出平台中心、墙段 ID、墙外法线和旋转，供部署模型与攻击原点共用。
- `tools/verify_t0132_p3_fortification_slice.gd`：审计 14 墙段、木构材质、平台曲线、平台—正式锚点—DefenseDeviceSystem 位置 / 朝向一致、左右真实墙段与角度、横杆 / 旗面数量和方向、门楼净空、冗余盒体为零、门叶及 GM 入口。

## T0132-P4a 正式弩床表现

- `scripts/presentation/defense/FormalBallistaArtView.gd` / `scenes/defense_devices/FormalBallistaArtView.tscn`：同源 PBR 正式模型、转台瞄准、动态弦、床面装填箭、飞行重箭、后坐与绞盘重装。
- `scripts/world/DefenseDeviceView.gd`：把部署配置与单次动作事件转发给可选正式模型，并保留无正式场景时的箭塔占位回退。
- `scripts/systems/DefenseDeviceSystem.gd`：在已结算动作结果中追加正式槽位原点、目标坐标和最终攻击间隔，只供表现层消费。
- `tools/verify_t0132_p4a_ballista_art_slice.gd` / `tools/capture_t0132_p4a_ballista_visuals.gd`：分别执行结构 / 时序专项与 D3D12 四状态视觉 QA。
