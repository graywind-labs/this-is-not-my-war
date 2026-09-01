# TECH_ARCHITECTURE.md

## T0315 完工表现与待命名事务边界

建筑链路为 `BuildingSystem 权威完成 → building_job_completed DTO → MilestoneAlertPresenter FIFO → 玩家确认关闭`。UI 是否显示、何时关闭不参与 HP、等级、材料、助手效率或建筑状态提交；信号也不是第二份任务状态。

出生链路为 `HorseSystem 繁育条件 / 模板 / 容量复验 → 单个 pending birth（候选 id、模板、槽位、亲代）→ 命名请求 → HorseSystem 名称复验 → 正式马库原子插入 → 亲代冷却 / 状态信号 / 马厩摘要 → horse_born`。命名确认是正式世界事实的提交边界；确认前不能由列表、面板、分配或 MemorySystem观察到新马。模板名只是默认输入，确认后的实例 `name` 才是所有消费者的唯一来源。

pending birth 只存在于当前运行态，与本项目现阶段其他马匹生态状态一致；未来若引入完整存档 / 恢复流程，必须把待命名事务与正式自定义马名纳入同一版本化存档 Schema，不能靠 UI 文本恢复。

## T0314 制造暂存与正式库存事务边界

数据流为 `CraftingSystem 最终阶段原子扣料 → building_id/item_id 聚合 pending_outputs → 只读 UI 投影 → 玩家确认 → CraftingSystem 全量原子提交 → ResourceSystem 正式库存`。pending 与生产 project 分离，因此切换目标、阶段中断、工人离岗或建筑 HP 变化不影响已制成物；收取也不改变 target、revision、active cycle 或项目阶段。

`output_resources` 继续专指已经进入正式库存的产出，`pending_output_resources` 专指已制成但未收取物。HUD、装备与器械部署不接触 pending；MemorySystem、世界反馈与 LLM 事件投影必须保留该语义差异。表现层可把聚合数量展开成逐件图标，但不得把展开节点当作库存事实或逐件收取入口。

## T0313 马匹连续差值聚合与表现分层

`HorseSystem 每分钟权威生态提交 → 逐 horse_id / 字段累计实际差值 → 一次外层 _advance_simulation 结束时量化完整显示单位 → WorldFeedbackPayload → Presenter`。累计器属于马匹权威系统，因为只有它能区分自然回血支付的饱食与常规环境消耗、成长带来的自然 HP 增长、照料额外 HP，以及繁育概率成功清零；Presenter 不从马匹快照前后猜来源。

HP / 回血饱食 / 额外 HP 以整数单位消费累计值，成长 / 繁育概率以 `0.001` 比例即 `0.1%` 消费，所有不足单位的余量继续保留。一次高速逻辑 tick 无论包含多少个固定分钟，都只在外层结束刷新；每匹马使用自己的替换频道和锚点。繁育进入冷却时清理概率余量，死亡清理该马全部余量，避免失效状态在未来跨阈值后回放。

离厩不会改变原自然回血资格，但 `_advance_care` 和 `_roll_births_for_minute` 仍只处理在厩马。TimeSystem 暂停不发送逻辑 tick，累计器与权威生态都不推进；Presenter 对已出现反馈继续使用现实时间。该层不新增存档字段、MemorySystem 事件、GM 结算接口或第二套马匹状态。

## T0312 多权威 HP 提交与统一表现

`NPCSystem / CombatSystem / HorseSystem / BuildingSystem / DefenseDeviceSystem` 各自在写入自身 HP 后调用同一个 `WorldFeedbackPayload.emit_hp_change(...)`。payload 只比较提交前后值并产生 damage / healing 语义；它不拥有防御、穿透、坐骑分伤、复苏、建筑摧毁或器械废墟规则。表现层按 `anchor_type:id + channel` 管理生命周期，伤害替换、治疗短窗合并都不反写权威状态。

命中位置属于只读表现上下文。正式近战 / 弹体已有碰撞坐标时向下透传，缺失时 Presenter 查询系统实时位置；目标移除时使用 payload 保存的提交瞬间回退坐标。坐标缺失只会隐藏反馈，不得阻止或回滚伤害。现有 MemorySystem 事件、血条刷新与 T0310 复苏提示继续独立消费同一权威事实。

## T0311 权威变化与世界反馈分层

数据流为 `业务系统完成原子提交并计算实际差值 → WorldFeedbackPayload 构造只读表现 DTO → EventBus.world_feedback_requested → WorldFeedbackPresenter 投影 / 动画`。ResourceSystem 的 `resource_changed` 仍表示绝对库存刷新，不能被 Presenter 用来猜消费来源或交易语义；失败、中断、容量回滚、达到上限和零差值不会产生成功飘字。

`WorldFeedbackPresenter` 只保存最长 2 秒的显示对象、锚点回退和频道信息。它不进入 MemorySystem，不构造见闻，不保存游戏状态，也不把 UI 数字反写系统。普通工作显式抑制通用成长入口的独立表现并与同次资源提交合组，从而既保留 `NPCSystem.increase_npc_skill` 作为单一成长权威，又避免同一事实显示两遍。

## T0306 权威事件与 LLM 聚合投影分层

数据流为 `业务系统逐次结算 → MemorySystem 原始事件 / 传播 / UI → LLMBridge 只读聚合投影 → Model Adapter 防御性字段清洗 → provider`。聚合器不回写 MemorySystem，不改变事件 ID 水位，也不让后端或模型判断分组。亲历和见闻分别投影；同一天的连续白名单战斗段可按类型签名复用首条输出槽，任何非白名单事件都会清空当前分组索引。`DailyReflectionSystem` 和 LLMBridge 直接构造反思 payload 的路径均复用同一入口，避免熟睡总结出现另一套压缩规则。

## T0299 运行态诊断与叙事事件分层

`NPCSystem.set_npc_behavior_mode(...)` 仍原子更新 current / previous / reason 与进入时间，但返回的 `event` 固定为空；各业务系统只为警铃、集结、避战、伤害、昏迷、复苏和逃离等具体事实调用 MemorySystem。MemorySystem 另设开发专用事件拒绝表，阻止旧 `npc_mode_changed` 调用重新进入全局、亲历、见闻和 LLM 记忆链。

必要失败与计划修订事件在入库归一化层净化原因：只有自然中文叙述进入 `payload.reason / payload.summary` 和事件 summary；内部英文枚举、路径式标识和未知 action id 使用稳定中文兜底。仍需查询的 action / source 等结构化索引可以保留，但不以未知 ID 生成玩家 / NPC 可见文本。

## T0289 情绪合同与表现边界

后端 `DialogueEmotion` 是非权威但受限的响应枚举。模型输出先经别名 / 未知值归一化，再进入 Pydantic；归一化记录并入既有 `model_normalizations`，不会改变 `recruitment_result / wartime_reaction / combat_strategy_decision / work_encouragement_reaction / escape_intervention_result`。Godot 的 `DialogueEmotionCatalog` 集中维护 UI 所需映射与时长，DialogSystem 对规则降级和 GM 预览也使用同一目录。

数据流严格单向：`provider → HTTP response → LLMBridge → DialogSystem turn → EventBus → 两类表现消费者`。Emoji 气泡是瞬时 presentation，不回写 NPC profile、MemorySystem、CombatSystem 或 ActionSystem。活动对话历史可携带表现元数据，完成守备官会话的事件净化继续只保存纯台词；这避免 UI 后缀变成 Prompt 记忆中的伪台词。

## T0288 会话锁与事件单一事实边界

- “是否允许取消”由已经发送的动作事实决定，而不是当前 checkbox 视觉状态或模型是否已返回。四类 request session flag 单向置真，直到会话收口。
- “特殊结果”与“说过的话”分属两类事件：结果在模型回复业务校验后立即写 `dialogue_special_interaction_result`；完成会话只写净化后的 `dialogue_turn`。普通对话事件不再复制结构化结果，避免事件库、见闻和后续记忆把同一结果理解为发生两次。
- UI 仍可在运行态读取带结果的 turn 生成彩色反馈，但持久化边界由 DialogSystem 在进入 MemorySystem 前统一白名单化，MemorySystem 不依赖 UI 清理。

## T0287 调试入口与状态投影边界

GMPanel 不直接写征召、buff、策略、逃离或记忆；它只选择枚举并调用 DialogSystem 的调试编排。DialogSystem 复用正式结果事件和 UI 信号，NPCSystem / CombatSystem 的薄 `debug_*` 包装复用既有权威私有方法。NPCPanel 只读当前 buff 字典，因此图标显隐、Tooltip 与跨日清除不会形成第二份状态。

## T0286 结果事件与 UI 权威边界

四类模型结果先由 DialogSystem 按现有业务规则合法化和应用，再作为 `dialogue_special_interaction_result` 进入 MemorySystem；公开传播也由 MemorySystem 执行。成功弹窗只订阅结果，不写入伍、buff 或策略。逃离警报只订阅 CombatSystem 已成功开始行为后的 EventBus 信号，不把 LLM 意向、计划或 UI 点击视为逃离事实。

## T0285 工作鼓励权威边界

`DialogSystem` 只管理四选一特殊对话意图和模型结果暂存；`NPCSystem` 管理工作鼓励资格、buff 生命周期与统一倍率；`ActionSystem / BuildingSystem` 读取倍率后仍自行结算工作；`CombatSystem` 管理逃离。后端只在开关开启时拼接对应 Prompt / Schema，不能写资源、HP、技能、建筑或行动事实。GM 与 UI 只调用这些接口，不建立第二套结算。

## T0271 状态展示与有效倍率边界

- NPCNeedsSystem 继续独占饱食 / 疲劳的配置边界和持续结算，仅新增只读 `get_need_bounds(...)`；NPCPanel 负责比例、颜色和文案，不写回需求值。
- HorseSystem 继续保存内部 horse / slot id。HorsePanel 与 BuildingPanel 只在显示层删除冗余字段并本地化编号，不改变槽位占用、位置、繁育或分配事实。
- TimeSystem 继续拥有玩家倍率、slowdown / cap 请求和 effective scale；HUD 只读 snapshot 决定按钮显示、禁用和 Tooltip。锁定期间按钮及数字快捷键不改玩家倍率，限制释放后无需重设即可恢复。

## T0270 HUD 内容与背景边界

- HUDFrame 只承担常驻 HUD 背景投影，不拥有时间、资源、波次、战斗或虔诚状态。HUD.gd 从现有常驻 Control 的实际尺寸和 combined minimum size 汇总右下内容边界，再增加固定展示留白。
- 资源值与后端状态可能改变文字最小宽度，因此对应刷新只请求一次 deferred 适配；不会重排标题、资源条或按钮，也不会把可拖拽库存详情、陨石提示、结算页等临时层计入背景。
- 场景初始边界与当前稳定内容同步，避免 `_ready` 前首帧露出；运行时适配继续处理主题最小尺寸和动态文案。所有权威业务接口与输入信号不变。

## T0269 建筑目标与宿主透明权威边界

- CombatSystem 的弹体 sweep 必须同时读取碰撞体稳定 `building_id` 与本发 `target_at_release`。只有正门 / 主厅不是该发敌方弹体明确建筑目标时，宿主外壳才可被排除并继续原线段查询。
- 目标正是 `building/front_gate` 或 `building/main_hall` 时，第一处合法外壳命中保持实体权威，并沿既有 CombatSystem → BuildingSystem 入口结算建筑 HP；仓库从不属于透明白名单，始终按普通建筑碰撞。
- 该判断不改 selector、release aim、碰撞层、NavigationMap、角色通行、建筑失败条件或塔防独立 HP。后方角色和主厅器械仍由 T0260 / T0262 的真实后续碰撞裁决，不提供逻辑补伤。

## T0268 高频 UI 投影边界

- HUD 只重写下一波 `seconds_until` 的展示句式，不改变 WaveSystem 波次身份、生成时间或倒计时权威。
- NPCPanel 的两个单选项只把选择映射到既有 `local_public / private`；公开传播范围、事件写入与对话强制公开仍由 DialogSystem / MemorySystem 裁决。
- 当前行动、行为模式、认识、事件和见闻均是现有 NPC / MemorySystem 状态的只读重排与重命名；没有新增缓存、计划状态、记忆类型、Prompt 字段或 LLM 调用。

## T0266 无效弹药占位移除边界

- 前端数据定义、制造目录、HUD 投影、NPC 初始知识和验证夹具不再声明独立弹药商品；远程战斗仍由 CombatSystem 的攻击节奏、射线 / 物理弹体与命中结算完整负责。
- 后端 Schema、Mock、Prompt 与业务服务原本没有该商品的枚举或结算分支，经全目录复核无需迁移；前后端均不新增替代字段。

## T0265 HUD 装备 / 器械只读投影边界

- HUD 不维护“已分配库存”或“已部署库存”第二份账。未分配数量来自 ResourceSystem；NPC 身上的五类装备来自 NPCSystem，马匹实体与归属来自 HorseSystem，活动器械和正式槽位名来自 DefenseDeviceSystem。
- 同一种具体物品的 UI 总数是“当前库存 + 当前分配 / 部署实体”；正式穿脱、分马或部署仍只由原系统扣除、返还和记录事件，HUD 只在状态信号后重建图标。摧毁器械从活动 deployment 移除后不再显示成可回收物品。
- 图标路径读取装备 / 器械定义与马匹快照；UI 不按显示图标反推 item id、库存或结算结果。

## T0264 NPCPanel 装备 UI 权威边界

- `NPCEquipmentWindow` 只持有六槽显示、当前可选项与点击信号；它不读取或写入库存、NPC 装备槽、马匹占用、战斗兵种或事件。
- `NPCPanel` 从 NPCSystem 当前装备、ResourceSystem 具体物品库存和 HorseSystem 可用马匹构造只读选项；提交前复验已入伍、未逃离和工作模式，再调用 EquipmentSystem 的主武器 / 盔甲 / 坐骑 / 卸装入口。
- 收回确认只延迟原权威调用。“否”不调用系统，“是”才调用 `unequip_npc_slot`；因此具体物品返还、主武器与马匹联动、战斗策略规范化和 MemorySystem 事件继续保持单一来源。

## T0262 远程弹体瞄准与塔防身份边界

- CombatSystem 继续独占敌方索敌、攻击时间线、弹道 sweep 与唯一伤害提交；目标是 defense device 时，只在释放瞬间向表现层读取真实 projectile hit Area 的世界中心作为 aim snapshot，不按目标锁或动画直接补伤。
- DefenseDevicePresenter / DefenseDeviceView 只投影当前活动 deployment 的受击形状位置与身份。它们不修改 HP、建筑、攻击结果或弹体轨迹；废墟、隐藏或已失效 deployment 不提供目标快照。
- T0148 的宿主墙面代理点继续服务近战接敌与导航，T0260 / T0269 的正门 / 主厅弹体透明仍只影响“宿主不是本发建筑目标”的 sweep；实际命中 Area 后由 CombatSystem 把 deployment 身份路由回 DefenseDeviceSystem 的既有 HP 权威。

## T0260 世界实体与弹体透明边界

- Building / StationLayout 继续独占正门、主厅的 `StaticBody3D`、NavigationMap 与角色通行规则；本任务不改任何建筑碰撞层、导航源或实体 Transform，因此“不能直接穿过去走”仍由原物理 / 导航链保证。
- CombatSystem 独占箭矢 / 弩箭的物理 sweep。它只在弹体查询内部按稳定 `building_id` 排除不是本发敌方建筑目标的 `front_gate / main_hall` collider 并继续同一线段；当建筑自身是目标时保留第一处碰撞。其他建筑、围墙、地形、敌对角色及合法塔防受击区保持第一处命中权威。
- DefenseDeviceView 的既有交互 `Area3D` 兼任 projectile hit area，但不引入 `StaticBody3D`、不参与角色碰撞。DefenseDeviceSystem 继续独占器械 HP，CombatSystem 只把实际碰撞身份路由到既有伤害入口。

## T0250 马匹选择与马厩展示边界

- HorseSystem 继续独占马匹生命、位置、分配与个体快照；BuildingPanel 只按快照 `alive / location` 过滤实际在厩卡片并渲染状态颜色，不反写任何马匹事实。
- BuildingSystem 继续独占世界点击编排。HorseSystem 只提供精确射线命中和既有选择信号：离厩马命中可直接选择，实际在厩马才继续读取 FormalStableArtView 的屋面透明阈值决定选马或选建筑。
- HorsePanel 与 BuildingPanel 各自渲染同一稳定颜色 / 阈值合同；两者不拥有 HP、饱食、成长或繁育结算。

## T0249 固定目标引导与脱困权威边界

- CombatSystem 独占动态到点余量、占区自排除、连续静止监督和引导区重选；它不直接写 Transform、速度、攻击命中或 HP。
- ActorMotionBody 继续独占 NavigationAgent、路径、RVO、CharacterBody 位移与碰撞掩码应用。enemy combat request 可跨替换保留独立静止采样；恢复窗口只移除 actor-body mask，world-static mask 始终保留，结束路径统一恢复。
- 固定目标真实伤害仍只由模型扫掠 / 弹体碰撞提交。动态容差和恢复不得扩大武器射程，也不得在未命中时逻辑补伤。

## T0248 弹体碰撞、动作释放与表现生命周期边界

- CombatSystem 独占远程 cycle target、authored release、弹体运动、碰撞身份、唯一伤害提交和战斗结束清理。NPC / 敌军 AI 在起手前负责射程与目标有效性；进入 windup 后不能因目标移动取消已锁动作，受击只能按 release 前 / 后边界中断。
- 同阵营穿透在同一物理 sweep 内通过逐 RID 排除实现，不修改 actor collision layer / mask，也不关闭角色实体碰撞。world_static、建筑、地形和敌对 actor 仍由 PhysicsServer 第一处合法碰撞裁决；表现层不能把视觉箭当作命中或补伤依据。
- CombatProjectileView 只拥有箭模型、朝向和附着 Transform。敌军致死前先重挂到美术根，随后复用既有尸体重挂生命周期；registry 只读节点存活事实。HP、死亡、尸体时长、战斗结束与 GM 清场仍由各既有系统拥有，不新增第二套伤害或尸体系统。

## T0247 动态活体追击的运动权威边界

- CombatSystem 继续独占目标锁、活体接敌点刷新和攻击距离交接，并用 `tracks_live_target` 只标识该目标会持续移动。它可以为此 request 关闭固定终点制动，但不能直接写速度、Transform 或绕过实际攻击范围。
- ActorMotionBody 继续独占路径、加速度、RVO、CharacterBody 碰撞与位移。`final_target_braking_enabled=false` 只移除活体预测终点的到点减速，路径中间点制动、反向速度剔除、同阵营 RVO、静态碰撞和实际实体碰撞仍然生效。
- RVO 阵营来自 `physics_navigation.actor_profiles`，而不是 CombatSystem 临时改层：NPC、`horse` 与中立商车为层 1，敌军步兵 / 骑乘为层 2。友方独立马不再借用敌军 `enemy_mounted` profile，只复用相同胶囊数值。层只影响局部避让感知，3D 物理 `actor_body` 层仍统一，因此敌我不会因 RVO 分层获得穿透能力。

## T0246 运动事实与生活消耗权威边界

- NPC / ActorMotionBody 继续独占实际位移与速度。NPC 实体只把“未骑乘、run 档、实际速度高于 walk 档”的物理秒数暂存为一次性样本，不读取敌军集合也不自行修改饱食。
- NPCNeedsSystem 继续独占 NPC 持续生活值变化。它读取 CombatSystem 的活动敌军事实，消费 NPCSystem 暴露的跑动样本，以本 tick 游戏秒为计费上限并按配置累积整数扣除；无敌时同样消费并丢弃样本，避免和平跑动被下次战斗追溯收费。
- 零饱食钳制放在 NPC `_resolve_locomotion_state / _get_authoritative_move_speed` 的统一 profile 源头，NPCSystem 状态刷新会立即重配活动 ActorMotion 请求。战术系统仍只提交目的地，不复制限速逻辑。
- 骑乘排除以 `states.combat_mounted` 的权威事实为准；HorseSystem 继续拥有马匹速度 / 饱食，NPCNeedsSystem 不重复结算马匹移动。

## T0245 近战动作、命中与受击中断权威边界

- CombatSystem 独占普通近战 cycle target、authored impact、伤害提交和受击中断。NPC / 敌军 AI 只在 idle 阶段用射程、攻击线与导航决定是否起手；进入 windup 后，移动目标的位置变化不能回到寻路层取消本次动作。
- 移动角色之间使用 `locked_actor_timeline`：impact 时只验证原目标仍存活 / 可攻击，不复核距离或模型 collider，并沿既有伤害入口结算一次。表现包装继续输出武器端点，但它们只成为诊断数据，不产生、提前提交或改写伤害目标。
- 权威扣血入口在写回受击者时同步取消其活动 windup / recovery。取消发生于 impact 前则 active swing 与 pending commit 一并作废；impact 后只取消余下动作，已提交事实不可回滚。敌我 cadence 的 `next_sequence_time` 不因中断清零。
- 固定目标仍由 T0243 / T0144 的受击体接触裁决；远程仍由 T0145 弹体事实裁决；冲锋仍由骑乘碰撞裁决。UI、GM、AnimationPlayer、Mesh、ActorMotionBody 都不拥有 HP 或中断结算权。

## T0244 后门门叶碰撞覆盖边界

- CombatSystem 继续独占“存活活动敌军集合”；FormalGateArtView 只读 `get_active_enemy_count()`，不能生成 / 清除敌军或改变战斗状态。后门配置开启时，该只读事实只决定两个门叶 CollisionShape 是否禁用。
- 门叶是运行时 AnimatableBody 物理阻挡，不是生产 NavigationMap 的第二权威。门塔与墙段 StaticBody、商路 / 逃离 NavigationLink、BuildingSystem 后门 HP 和正门固定战斗接触 Area 均保持原所有权。
- 覆盖解除后仍统一进入 `_should_enable_leaf_collisions()` 的摧毁 / 门态判断，不另存可漂移的战斗布尔值；快照只投影当前敌军数、覆盖原因和最终碰撞事实。

## T0243 固定目标引导、运动与伤害权威边界

- CombatSystem 独占建筑 / 塔防引导区生成、真实敌军胶囊占区统计、稀疏区选择、目标锁保持和“受击体已入射程”的攻击交接。引导记录是每敌可替换的导航建议，不是目标容量、位置所有权或攻击许可。
- ActorMotionBody / NavigationServer3D 继续独占吸附、可达路径、RVO、CharacterBody 碰撞与实际位移。CombatSystem 只把当前最稀疏圆心提交为目标；同锁换圆使用既有 `update_motion_target(...)`，不直接写 Transform，也不因路径改变重排目标。
- 受击接触点只用于射程与攻击表现；最终命中仍由近战扫掠或物理弹体碰撞提交给 BuildingSystem / DefenseDeviceSystem。GM / UI 只读 `enemy_attack_guidance_zones_v2` 快照，不能占区、强制换圆、授予攻击或扣 HP。

## T0236 敌军移动事实与表现边界

- ActorMotionBody / CharacterBody 继续独占路径、RVO、碰撞和实际位移。CombatSystem 只在物理帧读取正式 Actor 的水平 Transform，并维护一个逐敌表现采样缓存；它不会用动画状态反向修正运动。
- `current_action` 是 UI / AI 意图文本，不再被当成移动事实。实际位移经低速启停迟滞投影到 ChibiCharacterPilot / EnemyMountedArtView；初次移动激活同时要求 ActorMotion 请求有效，以区分拥挤爬行和无请求碰撞去穿透。攻击、受击、昏迷、死亡和败退状态仍拥有更高表现优先级。
- 没有新增 Autoload、NavigationMap、节点、信号、配置 Schema、攻击结算器或伤害接口；逐帧采样返回 Vector3，避免为每名敌军每物理帧创建临时 Dictionary。

## T0235 远程战术移动监督边界

- ActorMotionBody 仍独占 CharacterBody、NavigationAgent、RVO、路径与速度权威，只额外公开最小运动进展快照；CombatSystem 不直接移动实体，而是依据连续静止证据取消旧请求并通过 NPCSystem 提交另一个攻击位。
- 目标更新保留 request id 和路径权威，但不再重置独立实体静止计时。这样动态目标追踪与“身体是否真的移动”成为两个互不冒充的事实；普通 path-progress stuck 机制保持不变。
- 攻击位选择负责为到达容差预留射程内余量；攻击时间线仍独立复核实际距离和静态攻击线。没有新增 Autoload、NavigationMap、节点、伤害接口、传送或第二套运动控制器。

## T0233 远程固定目标容量边界

- `station_layout.json` 只声明远程纵深比例和每排表面预算；CombatSystem 按当前敌人的 `attack_range / weapon_type / motion radius` 生成候选，不把敌人波次数或坐标写死进代码。
- 同一 `_get_enemy_attack_position_row_specs(...)` 现在覆盖建筑与塔防代理；建筑四面生成器、正门前线生成器和塔防多宿主区域生成器只负责几何展开。NavigationServer 路径、租约冲突、实际占用和攻击时间线仍是后续独立权威。
- 远程预算与近战预算分开读取，避免为后期波次扩容时放宽近战真实接触。没有新增伤害接口、传送、第二 NavigationMap、Autoload 或场景节点。

## T0232 保持距离撤离状态边界

- CombatSystem 在友军目标选择前运行 `keep_distance` 近身优先状态机，NPCSystem 只保存运行字段并执行既有世界移动接口，ActorMotionBody / NavigationAgent3D 继续独占实际位移。
- 多敌权重复用 CombatSystem 的避战威胁场；障碍、边界和可达修正复用 StationLayoutController。没有新增 Autoload、节点、信号、攻击结算器或第二张导航图。
- 已提交撤离段是不可变命令：移动层失活只能补发原终点；只有到达边沿允许重新采样敌军。该边界防止目标锁、伤害重扫和攻击位更新在途中争抢身体控制权。

## T0231 塔防精确到位恢复边界

- CombatSystem 只决定何时临时抑制一个已持塔防攻击位租约的敌军 Actor 的局部 RVO；ActorMotionBody 继续拥有路径、速度、CharacterBody 碰撞与到达状态权威。
- `0.32 m` 恢复带不改变攻击许可。CombatSystem 仍需确认 `0.06 m` 精确到位，之后攻击时间线仍只能由正式武器扫掠 / 投射物碰撞提交伤害。
- 生命周期在 CombatSystem 的租约释放、候补切换、离带、精确到位和全量清理入口统一恢复避让，避免运行态覆盖泄漏到下一目标。

## T0230 多区域宿主代理权威边界

- StationLayoutController 从主厅现有矩形包络和五段 StaticCollision 生成每槽两个 `host_proxy_regions`，是墙段位置、法线和局部范围的唯一空间权威。DefenseDeviceSystem 只把区域绑定到一个 deployment / HP，并保留首区域单值镜像。
- CombatSystem 对区域列表展开攻击位，租约仍按同一 `defense_device:<deployment_id>` 目标键互斥，但槽 id 加入区域 / 采样点，从而在两面墙分配容量。NavigationServer / ActorMotionBody 继续决定可达与实际位移。
- 碰撞分类逐区域验证精确墙段及局部半径后才把伤害转交 DefenseDeviceSystem；BuildingSystem 不接收代理命中。UI、GM、表现层和屋顶射击节点只观察，不创建区域或决定伤害。

## T0229 目标锁、攻击位与移动权威分层

- CombatSystem 独占目标锁、武器射程、攻击线和远程攻击位选择；NPCSystem / ActorMotionBody 独占导航请求与实体位移。`behavior_mode=combat`、`combat_ready` 或 `moving_to_combat_strategy_*` 都不能替代底层 request 活性。
- 远程攻击位只读取目标位置、最终武器射程与执行 NPC 当前生产 NavigationMap。32 点圆弧候选先做导航吸附 / 路径校验，再以 world-static 射线判断能否真实攻击；选择结果仍通过 NPCSystem 的统一世界移动接口提交，不直接写 Transform 或 NavigationAgent 内部路径。
- 警铃仍以合法目标锁为只读排除条件；战斗 AI 的移动恢复是同一目标锁内的幂等推进，不让 UI / GM 重新派令来修复系统状态。站内破防域与正门 rally 跨界半径均由 CombatSystem 统一裁决。

## T0228 主厅器械展示锚点与墙面受击代理分层

- DefenseDeviceSystem 仍独占部署、器械 HP 和屋顶射击原点；StationLayoutController 从同一主厅槽位生成低位 `host_proxy_position / aim_position` 与所属墙段，并新增墙面法线 `host_proxy_outward_direction`。屋顶器械朝向不再兼任敌军接敌面的方向权威。
- CombatSystem 的固定塔防攻击位优先消费宿主代理外向方向，在对应外墙平面外侧建立租约和接触点；真实近战 / 弹体仍必须命中相同 `building_segment_id` 和局部半径，才把伤害转交 DefenseDeviceSystem。主厅 BuildingSystem HP 不参与器械代理命中。
- 主厅解锁仍由 DefenseDeviceSystem 配置与正式 spatial / fixture 三级一致性校验共同约束，当前前侧 `slot_03/04=Lv.1/3`，背侧 `slot_01/02=Lv.5/6`，总容量曲线不变。

## T0227 上马事实、集结意图与移动权威

- HorseSystem 仍独占真实上马完成事实，并仅在会合完成后调用 `CombatSystem.handle_npc_mount_ready(...)`。CombatSystem 独占刚上马后的集结意图、阵位和遇敌分流；NPCSystem / ActorMotionBody 仍独占物理路线与位移。
- 阵形以完整可行动武装名单统一计算，而不按回调先后每次构造单人阵形。目标锁只在“是否应立即转战斗”时生效，不会从阵形基准中删除其他骑手导致阵位随上马顺序飘移。
- 集结意图不再把 `moving_to_*` 当成移动权威；恢复分支只经 NPCSystem 重发原阵位，不直接修改 Transform、门状态或 NavigationAgent 内部路径。

## T0226 避战意图与物理移动权威分离

- CombatSystem 拥有避战意图、威胁场和目标运行态；NPCSystem / ActorMotionBody 拥有世界移动是否真正活动的权威。`current_action` 不能替代底层活性检查。
- 恢复分支仍通过 `NPCSystem.move_npc_to_world_position(...)` 和共用 ActorMotionBody 路由，不直接写 Transform。当前威胁为空时从 `_active_avoidances` 重建原目标参数，不制造新威胁事实。
- 该自恢复是幂等的：补发成功后底层活性为真，后续推进只更新 status，不每帧重建请求或重复写避战开始事件。

## T0225 破防共享目标域权威

- CombatSystem 以 StationLayoutController 的 `interior_polygon` 结果建立共享 `station_breached` 事实。该事实为真时，`_get_friendly_target_scope(...)` 对每名武装应征 NPC 返回 `station_breach_global / station_enemy_only=true`，NPC 本人的空间位置只保留作诊断，不再裁剪站内候选。
- 行为接触、在场锁保持、最近重选、异源受击重扫、策略移动和攻击射程检查都消费同一个 scope。NPCSystem、HorseSystem、ActorMotionBody、GM 与表现层不得另选目标或把站外近敌混入破防候选。

## T0224 警铃命令、目标锁与骑乘权威

- CombatSystem 独占警铃响应集合、阵位 reservation 和友军目标锁判断。警铃只读取 NPCSystem 的行为 / 可行动状态与 EquipmentSystem 的入伍装备投影；行为模式和地点不参与响应资格，合法活动敌人目标锁是持武器可行动者唯一的战斗态排除条件。
- 接受命令仍通过 NPCSystem 的统一模式中断与世界移动接口，旧避战运行态和 CombatSystem 的无目标近战运行态在重派前清理。已锁目标者完全不进入写路径，因此目标、移动、攻击时间线与表现不会被铃声重置。
- HorseSystem 继续独占马匹位置和会合 / 骑乘生命周期。CombatSystem 只读取 `combat_mounted`：已骑乘者保持状态直接移动，未骑乘者等待既有 `handle_npc_mount_ready(...)` 回调恢复同一阵位。途中索敌复用 T0198 正常友军目标域，不建立警铃专用半径。

## T0223 配置射程与昏迷表现单次播放权威

- `data/defense_device_defs.json` 继续是槽位基础倍率唯一配置源；主厅四槽改为 `1.0`，DefenseDeviceSystem 仍将基础倍率与宿主逐级收益合成最终射程。UI、敌军感知和攻击圈不维护主厅例外。
- NPCSystem 继续独占 HP、昏迷和 30% 复苏状态；`ChibiCharacterPilot` 只缓存当前非循环表现状态。`unconscious` / `mounted_fall` clip 结束后保持末帧，重复 profile 投影不创建新的状态边沿；只有权威布尔值变化才能进入倒地或起身。
- 本任务不新增系统、信号、存档字段或数值结算路径。新增快照字段只用于验证当前动画是否仍在播放及其时间位置。

## T0221 出口前缀的单调进度权威

- StationLayoutController 仍独占建筑正式路线与室内包络；`get_indoor_exit_navigation_prefix(...)` 现在同时返回出口向外方向，并以当前位置相对各路线点横截面的有符号进度跳过已越过点。距离点很近仍沿用原到达容差，横向 RVO 偏移不再清零纵向进度。
- ActorMotionBody 独占活动阶段。室外最终目标更新只保留当前前缀并更新最终点；外力位移导致重建时读取控制器的单调进度。物理帧若实体已越过当前横截面，会推进到下一腿，永远不降低阶段序号。
- 上层 NPCSystem、HorseSystem 与 CombatSystem 不复制建筑判断，也不能因行为 / 索敌 / 集结刷新把移动层拉回旧阶段。最终目标回到同建筑室内是唯一正常取消出口前缀的目标更新分支。

## T0220 远程建筑攻击位几何与权威边界

> 历史基线：T0233 已把三排建筑几何扩为六排固定目标几何，并加入塔防代理；租约与命中权威边界不变。

- 数据层只声明远程建筑排距比例；CombatSystem 以同一武器射程、实体半径和正式建筑接触面展开三排候选。正门复用五个门板横向样本，旋转仓库 / 主厅复用原四面最多 20 个表面样本，避免每排重新选择不同墙面。
- 多排只增加租约候选，不新增导航器或第二套攻击条件。所有排都进入原 NavigationMap 吸附 / 路径长度、物理间距冲突、`reserved → occupied`、waiter 晋升和真实模型 / 弹体接触链；索敌、伤害与攻速权威不读取排号。
- NPC 动态目标继续绕过固定租约；塔防代理继续使用单排，近战继续使用原单排。`range_row_*` 只是候选、租约和目标快照诊断，不能替代可达、抵达或命中事实。

## T0214 回站目标、自动门与战斗接触分层

- CombatSystem 只在避战语义层判断 NPC 是否站外，并请求 `front_gate_inside_reentry`；StationLayoutController 依据布局、实际旋转门根、生产 NavigationMap、`interior_polygon` 和实体包络拥有内侧点权威。NPCSystem / ActorMotionBody 继续独占路线与位移。
- FormalGateArtView 的传感层只判断友军是否需要通行，不读取活动敌军数量。活动门叶仍负责硬碰撞；固定 `FixedGateCombatContactArea` 使用独立碰撞层，只在敌军已锁 `front_gate` 的攻击查询中加入，使门打开时仍能获得真实接触，又不参与运动阻挡或截断友军攻击。
- 敌军目标、五槽、租约、候补、攻击时间线与伤害均仍由 CombatSystem 掌握；门角度和传感器不能新增目标、攻击权限或伤害。

## T0210 室内出口前缀的权威分层

- StationLayoutController 独占“当前在哪座可进入建筑内”与反向正式门路解析；它只消费既有 building envelope、`solid_interior_blocker` 和 `building_spatial.entry_route`，不复制诊所坐标或建立敌我两套路线。
- ActorMotionBody 独占前缀运行态，并明确分离上层 `_target_position` 与 NavigationAgent 当前 leg target。每个前缀点只切换底层导航腿，不发 `motion_arrived`；只有最终目标抵达才完成上层请求。持续重规划、路径合同、制动和可达性均针对当前腿，目标锁与 request id 保持上层权威。
- NPCSystem 的既有分段建筑进出可与通用前缀组合：已经站在 authored point 的角色从下一点继续，不会退回室内。CombatSystem 仍只调用 `request_motion / update_motion_target`，不需要知道建筑 ID。

## T0209 避战方向、边界与移动权威

- CombatSystem 是避战威胁集合和方向的唯一权威。检测半径读取敌军统一 `37.2 m` 索敌值再加配置余量 `2.0 m`；每个圈内敌军贡献 `away_i × (R/max(d_i,1.0))²`，合成后归一化。Navigation / RVO 不得改变敌军权重、加入圈外目标或自行选择“安全建筑”。
- CombatSystem 只生成距 NPC 一个完整避战半径的原始目标。StationLayoutController 独占“仍在驿站内且不落在实体里”的空间约束：以 `station.interior_polygon` 截断越界射线，在生产 NavigationMap 上从原目标向 NPC 有界回采，并通过 `get_building_area_overlap(...)` 排除建筑、附属物、墙和门体包络。
- NPCSystem / ActorMotionBody 继续独占实际移动、路径推进、RVO、碰撞和到达。非战斗自动避战与显式 `avoid_combat` 使用同一入口；避战不调用后门出口，不设置 `escaped`，也不因目标修正把空间结论伪装成逃离事实。


## T0208 正门门板攻击面边界

- `data/station_layout.json` 是正门攻击带数量与宽度的唯一配置源；当前 `position_count=5 / width=4.8`。CombatSystem 依据 `gate_combat_geometry_v1` 生成五个门板接触点，不再为候选索引推导门塔身份。
- 门塔仍属于 StationLayoutController 的 world-static / NavigationMesh 权威，不属于 CombatSystem 的正门攻击面。正门伤害只接受真实 `building_id=front_gate` 接触，不通过槽位 ID 把相邻围墙碰撞改写成正门命中。

## T0204 正门几何与导航权威

- `station_layout_v2.station.front_gate` 同时声明门洞净宽与两侧塔实体包络。StationLayoutController 从实际旋转后的门根生成碰撞、导航烘焙源和 `gate_combat_geometry_v1`；CombatSystem 只消费该几何，不复制一套世界坐标或从路线点反推门朝向。
- 两侧塔是 world-static 空间事实，继续用 `building_id=front_gate / collision_category=gate_post` 接入既有建筑身份；可见模型与碰撞共享同一局部中心及尺寸，但 T0208 后攻击接触只落在门板平面。塔体阻挡不得缩窄 `front_door_clear_width`，破门只开放原门洞，不移除结构塔。
- 槽位分配的车道距离是现有候选集上的稳定排序输入；NavigationMap 可达性、租约冲突和 ActorMotionBody 路径仍是后续权威，车道保持不能新增槽位或绕过 waiter。

## T0202 友军攻击时间与表现边界

- CombatSystem 的 `_combat_timeline_seconds / combat_attack_next_sequence_time` 仍是友军起手频率唯一权威；ChibiCharacterPilot 只消费 `combat_attack_sequence / phase / elapsed / playback_multiplier`。AnimationPlayer 停止不代表新攻击，只有 sequence 变化才能 reset 攻击 clip。
- 清敌收口必须覆盖“最后敌人在本友军循环之外移除”的入口。活动战斗非空而敌人集合为空时，逻辑 tick / 友军步统一调用既有 `_handle_all_enemies_cleared`，并在模式切换前清空瞬时近战 sweep 与 pending commit；目标、phase 和表现不能各自延迟清理。

## T0201 主厅不可进入空间权威

- `station_layout_v2.buildings[].solid_interior_blocker` 是不可进入建筑内部阻挡的配置入口。StationLayoutController 依据同一建筑包络生成 world-static `StaticBody3D`，不生成可见网格，并将碰撞体加入 `formal_navigation_source`；物理尺寸、导航烘焙和合同网格共用同一配置，不另建隐藏坐标表。
- `blocks_navigation_link=true` 时不创建该建筑的跨门 NavigationLink，合同网格也把阻挡足迹判为不可走。主厅前后移动因此消费生产 NavigationMap 的外侧绕行；CombatSystem 仍以既有外墙 `building_segment_id` 和攻击位作为接敌表面，内部阻挡不拥有 HP、伤害、平台或点击权威。

## T0200 战斗目标与移动权威边界

- CombatSystem 独占目标锁、武器攻击条件与接敌点选择；ActorMotionBody 独占 NavigationAgent3D 路径推进、RVO、速度、碰撞和无进展检测。NPCSystem 只转发友军世界移动请求及同请求目标更新，不能按路径结果重排战斗目标。
- `motion_options.persistent_repath=true` 只用于目标仍有效的战斗接近。它绕过普通移动的最大重规划 / 卡死终止上限，但仍按数据化采样间隔重算，不逐帧寻路；目标变化通过 `update_motion_target(...)` 保留 request id，避免取消 / 重建引发状态与攻击时间线抖动。
- ActorMotionBody 以角色稳定身份在阵营基础值附近生成小幅 `avoidance_priority` 差异，打破同优先级 RVO 对称死锁；这是局部避让的确定性 tie-break，不得被 CombatSystem 用作索敌、路径或攻击位排序输入。
- ActorMotionBody 可从单次 `motion_options.target_desired_distance` 读取最终到达容差，并同步给 NavigationAgent、自身到达判定和路径可达复核；没有覆盖时继续使用角色 profile。CombatSystem 只对近战塔防宿主代理租约传入 `0.06 m`，避免扩大武器射程或建立补伤通路；建筑与日常移动不继承该精确容差。
- StationLayoutController 的单一生产 NavigationMap 同时覆盖站内与北侧城外战场，并从 `formal_navigation_source` 静态碰撞烘焙。旧敌军进门廊道不再拥有导航权威；道路表现没有碰撞、区域成本或路径偏好。

## T0198 友方目标与受击重扫权威边界

- CombatSystem 是武装 NPC 战斗目标的唯一裁决者：正常时按“站外 `37.2 m` 水平圈 / 站内 `interior_polygon` 整站”生成最近候选；任一敌人进站后，全部武装应征者统一改用只含站内敌人的 `station_breach_global`。策略移动和攻击时间线只能消费该结果，不能独立重排。
- NPCSystem 仍拥有 NPC 状态和行为模式，但敌人伤害只让未参战武装 NPC 进入 combat；已经参战时不重复中断，也不把攻击者写成权威目标。实际 HP 扣减返回后，CombatSystem 才能依据受击前锁 ID 创建一次性重扫请求。
- 请求仅影响下一次目标选择，不产生仇恨表、精确反击、扩大范围或补伤；请求字典不序列化。目标变化重建移动 / 取消当前 phase 时，T0193 单调 next-sequence 时刻仍是唯一攻速权威。

## T0197 受击重评估权威边界

- CombatSystem 的 `_apply_damage_to_enemy(...)` 是唯一能产生异源受击重评估请求的位置；必须先有正整数 HP 扣减，再验证当前锁与伤害来源都是高威胁单位且两者 key 不同。动画、意图、弹体释放、GM 和 UI 都不能伪造该信号。
- 请求只让下一次正式选择暂时绕过一次在场保持；候选仍完全来自 T0196 的 `37.2 m` 高威胁池并按水平距离排序。伤害来源没有独立仇恨层、范围扩张或精确反击权，消费后恢复普通在场锁。
- 请求保存在 CombatSystem 独立短生命周期字典中，敌人移除 / 清场时清理，正式空间存档不序列化。攻击时间线的单调 next-sequence 权威、NPC / 塔防状态所有权和寻路边界均不变。

## T0196 统一敌军目标权威

> T0243 已把固定目标“满位消失 / 城门 waiter”替换为无容量上限的动态稀疏引导；本节其余目标优先级与在场锁仍有效。

- CombatSystem 是唯一目标裁决者：从 NPCSystem、EquipmentSystem 与 DefenseDeviceSystem 读取有效单位事实，在同一个 `37.2 m` 水平圈内生成“持武器 NPC + 塔防”池和无武器 NPC 池；同级首次按直线距离选择，后续只用目标有效性 / 是否离圈判断在场锁。
- 目标选择层不再调用 NavigationMap 路径距离、阻挡抢占、近期命中或逐器械射程扩圈。它只决定“打谁”；ActorMotionBody、攻击位 NavMap 校验和后续寻路继续决定“怎样到达”，不得反写新的目标优先级。
- NPC 明确不进入攻击位系统。固定位置容量只作用于塔防与建筑：塔防、仓库、主厅满位视为对该敌人消失；完整城门是强制破口例外，满位仍保持目标并使用现有 waiter。CombatSystem 之外的 GM / UI / 表现层不能写目标或容量事实。

## T0195 塔防满位候补权威（历史，已由 T0196 取代）

- CombatSystem 在目标可用性预检中把“可达塔防但攻击位已满”解释为严格候补，而非允许进入建筑层；排队、位置释放与晋升仍完全复用 T0149 lease / waiter 权威。
- 该例外只存在于 `defense_device → building` 边界。塔防失效或确实不可达后才允许建筑回退；GM、DefenseDeviceSystem 和表现层仍不能强制敌军目标。

## T0194 塔防威胁范围与受击抢占权威（历史，已由 T0196 取代）

- DefenseDeviceSystem 负责把槽位与宿主倍率合并成 deployment 的最终 `effect.range`，并只读投影为活动目标 `effective_attack_range`；CombatSystem 负责据此计算逐目标敌军感知半径，配置只提供额外威胁余量。
- CombatSystem 的伤害提交点记录 NPC / deployment 的近期命中序列。只有当前目标是建筑时，最近实际来源才走精确抢占；当前有效 NPC 目标保持、有效 impact 的 recovery 收尾、可达攻击位与路线阻挡仍由 CombatSystem 一处裁决。
- DefenseDeviceSystem、NPCSystem、GM 与表现层不能直接写敌军目标。新增范围和关系字段是短生命周期决策证据，不改变投射物 / 近战碰撞与 HP 权威，也不进入正式空间存档。

## T0193 双方共享的单调攻击起手权威

- CombatSystem 的 `_combat_timeline_seconds` 现在同时是敌军与友军起手时间权威；双方都用“last start / earliest next start”表达攻速，目标、寻路和行为状态只能取消当前阶段，不能生产新的时间。
- NPCSystem 仍拥有 NPC 状态与空间存档，但只保存相对 `lock_remaining`，不保存 CombatSystem 进程内绝对时刻。CombatSystem 在联合读档重建正式波次时暂存 / 恢复这个相对量，并在下一权威步映射回当前时钟。
- `combat_attack_cooldown` 保留为兼容与观察字段；攻击 sequence 是否可增加只比较单调时钟和 next sequence time。战斗结束是清锁的唯一正常生命周期边界，短暂 work / avoid / unconscious 往返不能重置本场频率。

## T0192 友军追击的状态 / 运动双权威交接

- 坐标空间权威属于 actor 实际绑定的 NavigationMap，而不属于“默认波次 / GM 波次”等运行模式。NPCSystem 只读桥接 `NavigationAgent.get_navigation_map()` 的最近点查询；CombatSystem 负责把战斗语义目标投影后再提交运动。这样正式日期波次和使用同一生产世界的 GM 动态波次不能分叉到不同坐标边界。
- NPCSystem 继续拥有 NPC 领域状态与 movement arrival context；ActorMotionBody 继续拥有 NavigationAgent / RVO / request 存活事实。新的 `is_npc_world_movement_active(...)` 只是只读桥接，不把战斗语义下沉到运动体。
- CombatSystem 不再用 `current_action` 字符串替代 request 存活性。两层不一致时，先经 NPCSystem 停止 / 清理旧 arrival context，再按当前敌人坐标重新提交；这使丢失取消回调不会成为永久状态。
- CombatSystem 在策略目标生成层消化 Navigation 容差：近战 approach standoff 从 `range * 0.85` 再内缩数据化 `arrival_tolerance`。这保证通用 ActorMotion 即使在合法容差边界到达，也位于战斗安全带内；无需改动 NPC 通用或工位导航配置。
- 攻击交接按“进入近战内侧安全带→释放运动权威→建立 attack timeline”执行；安全带只决定何时停步，不改武器 range、动画、模型接触或 HP 伤害权威。

## T0189 全局暂停与敌军战术停步分层

- `TimeSystem` 仍是全局暂停唯一事实源，通过 `EventBus.gameplay_pause_changed` 即时通知 CombatSystem；CombatSystem 同时在物理帧入口重申当前事实，封住新建 actor 或新 navigation request 把暂停布尔重置后的单帧滑行窗口。
- `ActorMotionBody` 仍是实体速度、NavigationAgent / RVO 与路径采样权威，不读取 CombatSystem 战术语义。CombatSystem 在正式敌军 slice 保存独立 `tactical_motion_paused`，再将“全局暂停 OR 战术停步”的合成结果下发运动体。
- 暂停只冻结游戏权威和世界实体推进，不冻结 UI / LLM；运动请求、目标与路径保留。近战接触采样 / damage commit 与物理弹体同样遵守暂停，避免静止画面内延迟扣血。

## T0188 友军战斗响应权威

- 正式城内多边形归 StationLayoutController 所有；CombatSystem 只消费“某敌人是否在站内”，并把它作为全域友军响应与主动策略目标过滤的唯一事实。距离索敌只在站内无敌时生效。
- 武装 / 应征、行为模式、策略、坐骑阶段和 locomotion 分属 EquipmentSystem / NPCSystem / CombatSystem / HorseSystem / NPC.gd 既有权威。全域响应只编排这些接口，不复制装备、骑乘、速度或伤害状态。
- 避战距离由配置下限和活动敌人最大远程射程动态合成；NPCSystem 仍只接收短步世界目标，ActorMotionBody 执行 NavigationAgent / RVO 位移，T0155 run profile 决定速度与动画分类。

## T0185 战斗权威秒与表现帧的单一桥接

- TimeSystem 同时拥有逻辑游戏秒与战斗表现秒的换算权威。系统层继续消费 `get_game_delta_seconds(real_delta)` / `logical_time_tick`；逐帧动画、粒子、根位移与物理弹体只能消费 `get_combat_frame_delta_seconds(real_delta)` 或其倍率版本，禁止读取 `numeric_multiplier` 后自行推导。
- 战斗表现换算定义为 `min(real_delta, game_delta)`：敌人在场 `game_delta == real_delta`，暂停为 0；无敌人的 x1 / x2 / x4 逻辑加速不会越过 authored x1。这样兼容调试 / 清场后的残余表现，也保留未来更严格慢速降低表现速率的能力。
- CombatSystem 仍独占 attack sequence、impact、近战接触、弹体碰撞与伤害；DefenseDeviceSystem 仍独占器械 timeline；表现层只按统一秒制投影状态。PietySystem 的 pending meteor 是已明确的数据化例外：稳定现实战斗表现秒并显式检查主动暂停。

## T0183 敌人在场统一 1:1 时间权威

- CombatSystem 以活动敌人字典是否为空作为唯一战斗限速事实；首名敌人生成 / 读档恢复时向 TimeSystem 注册 `combat_enemy_presence = 1/60` 慢速，最后一名敌人移除 / 清空时只释放该请求。玩家选择倍率继续保留，战后恢复。
- TimeSystem 仍是唯一逻辑时间生产者，不修改 `Engine.time_scale`。敌人在场时 `get_game_delta_seconds(1.0) = 1.0`；NPC 移动、LLM 等待与敌人在场请求取最小值，但三者当前均为 `1/60`，所以不会把战斗叠加降得更慢。
- CombatSystem、DefenseDeviceSystem 与 PietySystem 的战时冷却 / 移动 / 持续效果直接消费 `game_delta_seconds`。逐帧攻击 clip 与物理弹体由 T0185 的专用战斗帧接口桥接，因此逻辑时间轴与表现同为一秒制。

## T0181 陨石空间安全权威

- StationLayoutController 独占正式建筑空间查询：将世界圆形范围转换到建筑局部坐标检查旋转矩形，并检查城墙线段厚度与城门包络。PietySystem 只消费查询结果，不维护第二份建筑位置。
- PietySystem 在虔诚消费和 pending 创建前权威复验建筑冲突；HUD 只显示失败原因。地图仍是无限水平地面，但合法集合排除与完整陨石效果圆相交的建筑区域。
- 合法落地时的数据流为 `MeteorPresentation 碰撞半径 -> PietySystem -> NPCSystem 安全点搜索 -> ActorMotionBody 外力位移 -> MeteorPresentation 创建 StaticBody3D`。排出发生在静态碰撞生成前，不经过伤害、AI 计划或 ActionSystem。

## T0238 陨石坑时间生命周期边界

- TimeSystem 仍是唯一逻辑游戏时间生产者。`EventBus.logical_time_tick(game_delta_seconds, ...)` 让 PietySystem 推进 crater lifetime；MeteorPresentation 只接收归一化 `fade_progress` 并调整坑体材质 Alpha，不读取时钟或自行计时。
- PietySystem 分别持有 crater lifetime 与 landed meteor body 两个索引。满 24 游戏小时只调用 `remove_crater()`；`combat_ended` 只调用 `remove_landed_body()`。两侧都已结束后才释放共享 MeteorPresentation 根节点。
- 生命周期状态是当前运行会话的表现诊断，不新增存档、事件、记忆或伤害权威。

## T0178 路径推进与避障运动权威

- NPCSystem / CombatSystem 只提交目的地和领域状态；ActorMotionBody 统一拥有 NavigationAgent 路径索引、RVO 速度、制动和实体位移。马厩、广场、城门与普通工作路线不得各自复制“防绕圈”特判。
- 中间路径点容差由 `2 × RVO radius + stopping_distance` 动态生成并受配置上限约束。提前推进前必须证明从当前位置到下一权威路径点的 NavMesh 路径近似直达；最终目标仍使用独立精确容差。
- 若实体已经进入动态容差后被避障推出，或已经越过当前路径点的入射平面，ActorMotionBody 推进 NavigationAgent 现有路径索引并清除上一帧安全速度；不得重新规划到门洞内侧或直接跳向最终目标。
- RVO 只提供避让方向：其输出速度必须服从当前路径制动上限，偏转角不得超过配置值，路径反向分量会被拒绝。不可前进时停下并沿用 T0176 有界卡死恢复，不以绕圈制造虚假位移。

## T0176 导航进展与阻挡权威

- `ActorMotionBody.set_motion_paused(...)` 是状态切换接口而非采样心跳。重复提交相同值不得清空卡死窗口；只有真实的暂停→恢复切换才重建采样基线。
- 卡死恢复的权威进展是 NavigationAgent 当前路径从 actor 到终点的剩余长度下降量。实体发生位移只作诊断，不再证明请求有进展；因此绕圈、侧滑与抖动会进入既有重寻路 / 有界失败合同。
- NavigationLink 只表达阻挡物开放后的可通行连接，不证明当前实体门板已经开放。CombatSystem 在候选目标机会评估前解析可攻击阻挡链；阻挡位满时沿用同一攻击位候补，不把门后目标误判为可用。
- 动态敌军每侧 RVO padding 等于攻击位 `safety_margin / 2`，因此两个 agent 的有效直径与槽间距一致；攻击位判定和 NavigationAgent 使用同一 `arrival_tolerance`。

## T0171 马匹属性告警表现边界

- HorsePanel 只根据 HorseSystem 快照中的当前值 / 最大值计算显示比例，不修改 HP、饱食、成长或繁育权威；基础 HP 与饱食之外的属性不参与危险状态。
- 进度条颜色通过 HorsePanel 局部 StyleBox override 实现，避免修改全局主题并误伤其他 ProgressBar。危险字体色同样只加在当前 Label，恢复后移除 override、回到主题文字色。
- 阈值采用严格小于：饱食 `< 0.20`、基础 HP `< 0.30`；边界值不告警，显示判断不改变系统层的饥饿、受伤或战斗规则。

## T0170 透明建筑内马匹点击权威边界

- BuildingSystem 继续独占建筑与室内单位的世界点击编排；HorseSystem 只读物理射线、验证现存马匹并发出既有 `horse_clicked`，HorsePanel 不参与射线或透明度判断。
- 精确命中在厩马时，以这匹马所属 `stable` 的 BuildingArtView opacity 为准：透明则单位优先，不透明则建筑优先。不能使用射线上“最近建筑 ID”代替所属建筑，因为俯视透视下多个透明 AABB 可能前后重叠。
- 点击只改变互斥面板选择，不写马匹位置、槽位、分配、HP、行动或建筑状态；非马匹区域继续走原 BuildingSystem / NPCSystem 选择链。

## T0169 马匹镜头布局边界

- HorsePanel 独占外框尺寸与信息栏排布；HorsePortraitViewport 继续只负责共享 World3D、相机跟随和渲染生命周期。缩小外框不改变 HorseSystem、马匹实体、点击选择或相机目标权威。
- 马匹与 NPC 镜头统一使用 `190–210 × 300–420 px` 的可见框范围；内部设计分辨率可独立保持 `260×480`，由 SubViewportContainer 拉伸适配，不把布局尺寸反向写入世界相机或马匹数据。

## T0168 工程路径身份边界

- 规范工作区为 `D:/这不是我的战争/`；`D:/MyGames/这不是我的战争/` 是指向它的 NTFS Junction，是同一物理工作树的受支持别名，不是同步副本。
- 工程身份判断必须先解析 Junction，再核对 Git 根 / HEAD 和关键文件；不得把字符串相等当成身份权威。只有解析或一致性校验失败时，才停止使用该 MCP 连接。
- 文件编辑与 CLI 命令优先使用规范路径；Godot MCP 可继续通过 Alias 使用 `res://`。本规则不引入文件同步、双写、第二个编辑器或第二套导入缓存。

## T0167 毛色与取马导航边界

- 毛色仍由 horse_defs 模板提供、HorseSystem 领取，HorseAppearance 只投影材质；本轮调整颜色数据，不把名称 / 颜色判断写入 GDScript。
- `pickup_center` 是 fixture 空间合同，不是第二个马位。FormalStableArtView 只做 horse ID→槽位→世界坐标投影；HorseSystem 验证路径并管理上马状态；NPCSystem / ActorMotionBody 继续承担实际寻路和碰撞。
- 路径不可达时明确失败，不移动马、不穿越隔栏、不偷偷改用其他马。CombatSystem 的阵位、接敌和战斗权威没有迁移。

## T0166 GM 入口层整理边界

- 本轮只调整 GMPanel 的可见控件树、分组和窗口定位；EquipmentSystem、CombatSystem、NPCSystem、BuildingSystem 等仍独占各自权威状态与结算。
- 被移除按钮的能力由通用按钮或命令行覆盖；相关命令解析和 `debug_*` 接口保留，避免 UI 整理破坏自动化或深层诊断。

## T0165 陨石表现、物理实体与权威边界

- PietySystem 继续独占虔诚消费、逻辑时序、冲击 / 燃烧状态与 CombatSystem 伤害提交；`MeteorPresentation` 只消费目标、进度和配置，生成可重建的 Mesh、粒子、灯光、冲击波与弹坑，不计算 HP 或击杀。
- 落地陨石的 `StaticBody3D` 是用户明确要求的临时 world_static 空间实体，生命周期由 PietySystem 监听既有 `event_recorded(type=combat_ended)` 后统一结束。T0238 起弹坑 / 灰烬改为独立的 24 游戏小时淡化表现态，仍不进入伤害、导航权威或结构化事件。
- CameraRig 的震动只在 Camera3D 基准局部位置上施加确定性衰减偏移，结束后精确回到当前缩放基准；它不修改 CameraRig 世界位置、平移边界或缩放距离。

## T0164 建筑名称镜头联动表现边界

- StationLayoutController 只读 `display_name` 生成正式 NameLabel；`orientation` 继续用于布局旋转但不进入文案。CameraRig / Camera3D Transform 只作为透明度动画输入，不反向修改镜头或建筑。
- 标签 Alpha 是可重建表现态，不进入 BuildingSystem、存档、点击、地点、制造或信息传播。文字与描边共用一个 Alpha，避免正文消失后残留黑色轮廓。

## T0163 陨石自由选点权威边界

- HUD 只负责相机射线与无限水平地面的交点计算；PietySystem 校验坐标有限性、归一化 Y，并继续独占虔诚消费和效果状态。T0181 起不恢复旧驿站矩形边界，但会通过 StationLayoutController 排除与完整效果圆相交的正式建筑、城墙和城门区域。
- CombatSystem 的范围伤害入口、无友伤隔离、时序和事件链没有变化；解锁的是中心坐标范围，不是伤害对象或结算权限。

## T0162 马匹权威与表现边界

- HorseSystem 独占马匹模板领取、历史名称唯一性、马槽占用、容量、繁育、成长、死亡和 NPC 分配。BuildingSystem 只保留原 `total / adult / foal` 数量投影；UI、马厩 ArtView 与 NPC 骑乘模型不得反写马匹事实。
- `FormalStableArtView -> HorseWorldView` 依据 `stable_slot_id` 把权威个体映射到真实实体；HorsePanel / HorsePortraitViewport 只共享主世界并读取选中 ID。`horse_clicked` 只表达选择，不授予喂养、成长、出生、分配或战斗权威。
- 骑乘链路始终使用同一稳定 ID：EquipmentSystem 投影分配马身份，CombatSystem 请求该马表现位置，NPC 抵达后读取同一模板颜色生成骑乘外观。表现不可按槽位索引或当前列表顺序替换马。

## T0161 GM 批量配装权威边界

- `gm_debug_presets.json` 只描述调试目标；GMPanel 只发起一次请求。EquipmentSystem 负责预检和编排，但每项事实仍交给 NPCSystem、ResourceSystem、EquipmentSystem 正式单件接口与 HorseSystem 写入。
- 流程顺序为：全员 / 模式 / 引用预检 → 确保调试马 → 归还旧配装 → 入伍 → 补足具体库存缺口 → 正式消费配装 → 唯一分配马匹。最终完全匹配时走只读幂等快照，不重放装备事件或库存变化。
- 调试马创建是 HorseSystem 显式 `debug_*` 能力，不能被正常繁育或 NPC 计划调用。正常开局档案、战斗系统、Prompt 与存档没有反向依赖 GM 预设。

## T0151 射程圈权威边界

- CombatSystem / DefenseDeviceSystem 分别独占友方战斗属性与器械宿主加成后的有效射程；`AttackRangeIndicator` 只读快照、生成 Mesh 和跟随位置，不保存或反推射程。
- EventBus 的 `npc_clicked / defense_device_clicked / world_selection_cleared` 只表达玩家选择，不授予攻击、目标或伤害权威。器械点击 Area 不属于战斗碰撞层，范围环本身没有 CollisionObject3D。
- 选择、可见性和程序 Mesh 都是可重建表现态，不写入存档；读档后的模式、装备、deployment 与宿主状态仍由原系统决定下一次点击是否显示。

## T0150 索敌与反击权威边界

- CombatSystem 独占五级目标优先级、建筑白名单、目标锁、重评估、反击证据和阻挡物决策；LLM、NPC表现、塔防表现与 GM 均无权指定敌军目标或伤害。
- NPCSystem / DefenseDeviceSystem 只提供当前可行动状态、世界位置与塔防事实；活动弹体、索敌与实际伤害仍由 CombatSystem 权威裁决。全部活动敌人进入同一统一范围 / 在场锁选择器；高威胁实际命中只生成一次圈内最近重扫，不提供精确来源抢占，也不改变伤害、命中或阵营规则。
- 目标筛选先只读预检 T0149 空位和 NavigationMap 可达性，确定目标后才建立唯一 lease。满位回退与候补建立不能同时发生，避免落选高优目标留下幽灵候补。
- 正式路线的可破坏 chokepoint 与 world-static 射线只用于确认白名单中的城门 / 仓库 / 主厅是否挡路；普通建筑不能被升级为战斗目标。最终占位、动作、碰撞和 HP 仍分别由既有系统负责。锁、反击和筛选缓存均不进存档，恢复后由当前世界事实重建。

## T0149 攻击位租约权威边界

> 历史合同：T0243 的 `enemy_attack_guidance_zones_v2` 已取代固定目标 lease、候补队列和到点许可；本节仅描述旧 schema。

- CombatSystem 独占攻击目标对应的 lease、enemy→slot 反向索引、候补队列和失败槽冷却；StationLayout 数据只提供生成政策与建筑正面轮廓，ActorMotionBody / NavigationServer 只负责物理移动与可达性事实。
- 租约决定“谁可以向哪个接敌位置移动”，不决定目标优先级、动画命中、弹体碰撞或 HP。NPC / DefenseDeviceSystem / BuildingSystem 只提供当前目标位置、轮廓 / 代理和生命状态，不保存敌军占位。
- 候补提升与释放是同一 CombatSystem 事务：先删除旧正向 / 反向索引，再按距离重验候补可达性并建立新租约。表现、UI 和 GM 只读 snapshot，不允许强制占位或绕过 NavigationMap。
- lease 内含 Vector3、导航判定与运行帧，属于可重建瞬时态；存档继续只保存敌军实体空间 / 攻击周期，恢复后从正式地图重新分配，避免保存失效 NavMap / Node 关联。

## T0148 塔防宿主代理权威边界

- 空间权威由 StationLayoutController 从正式墙段、建筑墙段和平台 fixture 生成稳定代理身份；DefenseDeviceSystem 只绑定代理与器械 HP，CombatSystem 只负责碰撞身份校验和伤害路由。
- 代理不是新建筑、第二个 HP 条或表现碰撞体。命中事实必须满足“当前锁定 deployment + 精确宿主身份 + 局部区域”，随后只进入 DefenseDeviceSystem；普通建筑目标只进入 BuildingSystem。
- UI、GM、器械 Presenter 和正式模型只观察 `host_proxy` 快照，不创建、删除或改写代理。器械销毁释放部署目标，宿主 StaticBody3D 与建筑状态由原系统继续维护。

## T0146 模型发射点权威边界

- `ChibiCharacterPilot` 独占武器模型与 loaded arrow / bolt 的 Transform，只读返回发射事实；NPC、NPCSystem 和 EnemyMountedArtView 仅转发，不计算弹道或伤害。CombatSystem 独占是否接受 release、初速度、物理推进、碰撞和伤害。
- 正式 release 不设身体中心 fallback。包装 / 武器 / loaded projectile 缺失属于可观察失败，必须零弹体零伤害；这避免画面没有箭、身体侧面却凭空产生权威攻击。
- 步 / 骑只是同一攻击时间轴和弹体系统的 source profile，不复制 ProjectileSystem。当前数据没有 mounted crossbow 敌种，兼容验收不等于新增玩法单位。

## T0145 弹体事实与去重权威边界

- 攻击时间轴提供 `attack_sequence`，CombatSystem 在 release 时结合来源与单调 projectile sequence 生成唯一 `attack_id`；表现层、弹体 Mesh 和 collider 都无权自行生成伤害事实或修改 HP。
- 首次物理终止碰撞会在任何伤害回调前预留 ID，随后把实际 collider、终态和唯一 damage result 固化为 fact。重复碰撞、回调重入或对同一 ID 的人工重放只读取已存 fact，不再次进入伤害权威。
- 去重表与活动物理弹体同属短生命周期战斗运行态，清弹体、退出战斗或重建场景时一并丢弃；不跨存档保存包含 Node / RID 的半完成事实，避免恢复后的幽灵命中。

## T0144 近战接触权威边界（T0245 后固定目标权威 / 角色诊断）

- 表现包装只输出当前真实武器端点与播放器片段；CombatSystem 独占 swing 生命周期、连续碰撞、阵营合法性、实际目标选择和伤害提交。动画 / Mesh 不能回调扣血。
- 固定建筑 / 城门 / 塔防的 `locked_target` 只决定起手、朝向和有效性，命中事实继续来自 world_static 胶囊扫掠的合法宿主 collider。普通角色对角色近战由 T0245 的 cycle target + authored impact 结算；actor_body 扫掠仅作模型诊断，不再转移或否决这次角色伤害。
- 步 / 骑命中秒与范围分别来自同一生产模型量测。攻速缩放完整周期与接触秒，空间端点和扫掠半径不随攻速膨胀；范围使用面向目标方向的实际可接触距离，不使用横挥侧向半径。
- 活动 swing 含 RID 排除列表、帧间几何、攻击上下文与一次性提交状态，不进入空间存档；固定目标的表现帧命中加入待提交 key，移动角色则只在 authored impact 直接提交。清敌 / 初始化同时丢弃 swing 与待提交队列，目标失效或受击中断清理对应 key，避免恢复后重复命中。

## T0143 弹体命中权威边界

- 攻击时间轴只负责确认“何时离弦”；释放目标只用于计算初速度，不是命中承诺。弹体创建后，CombatSystem 独占位置、速度、重力、寿命、扫掠碰撞和 hit / blocked / miss 状态。
- `CombatProjectileView` 是无碰撞体的只读 Mesh 投影，不能发信号扣血。角色包装只提供已验收 loaded arrow / bolt 的发射 Transform，并通过 profile 字段关闭正式路径中的预览飞箭；NPCDevLab 不进入这条权威链。
- 每个物理子步先积分抛物线，再对起终点执行 world_static + actor_body 连续查询。首个 collider 决定结果：合法敌对实体进入既有伤害权威，其他 collider 只阻挡。释放时目标 ID 不能在落空后触发兼容补伤害。
- 弹体运行态包含 Node 与 RID 排除列表，因此不进入 formal spatial checkpoint。保存 / 重建发生在飞行中时丢弃弹体是显式策略，比序列化物理服务器对象后产生重复命中更安全。

## T0142 战斗时间轴权威边界

- `CombatAnimationTiming` 是四类已验收攻击动作的时间元数据源，但不拥有 HP 或战斗状态。CombatSystem 用权威 `attack_interval` 缩放 authored 周期，并独占 `idle -> windup -> impact -> recovery -> idle` 推进和伤害提交。
- `combat_attack_sequence` 是表现重播边沿；`elapsed / cycle / impact / playback` 是同一周期的只读投影。`ChibiCharacterPilot` 在新序号到来时重启并 seek 到权威 elapsed，之后用同一倍率推进；角色用于日常动作差异的 `playback_speed` 不得参与正式攻击速度。
- 目标死亡 / 昏迷 / 离场、攻击者失能与受击在权威层中断周期；普通角色目标在动作中移动出起手射程不再中断。表现层不能因为动画已经开始而补造伤害；存档恢复保存敌军周期字段，避免恢复后幽灵命中或重复提交。
- T0143 后远程 authored 释放点只创建弹体，最终伤害由 CombatSystem 物理碰撞结果提交；近战空间接触也不得回落为表现节点扣血。

## T0141 正式敌军表现复用边界

- 正式数据流固定为 `enemy_waves.json weapon_type / mount_type -> CombatSystem enemy profile -> ChibiCharacterPilot / EnemyMountedArtView`。NPCDevLab 只用同一生产包装验收效果，不进入 Main 的运行时依赖链。
- CombatSystem 继续创建并维护 ActorMotionBody、NavigationAgent、碰撞、HP、目标、攻击和胜负事实；本次替换其子级表现包装，不改变权威实体标识、攻击节奏或结算顺序。
- `ChibiCharacterPilot.apply_profile(...)` 可按生产 profile 延迟创建四类武器节点；节点显隐只读固定武器和战斗表现状态，不能把 `_debug_equipment_preview_active` 或 DevLab 临时 loadout 带入正式世界。
- 骑兵继续通过 `EnemyMountedArtView` 组合同一骑手和马匹包装。马匹的敌方纯表现、无独立 HP及坠亡逃逸边界不变。
- T0141 不实现动画事件驱动伤害、近战武器空间接触或物理弹体；这些能力必须在后续任务中由 CombatSystem 的权威时间轴 / 命中结果驱动表现，不能由表现节点自行扣血。

## T0130-D1R12 角色表现、动画与玩法权威边界

- `ChibiCharacterPilot` 只把 NPC / Combat / Equipment / Horse 状态投影为可见模型、动画和附件；工作工具接触砧、锅、土地、桌面或病床不产生生产 / 治疗事实，武器动画和可见投射物也不产生伤害事实。
- `NPCDevLab` 的模式、动作和装配是场景级临时状态。它可以跨角色复用以便对照，但不写 NPCSystem、ActionSystem、EquipmentSystem、HorseSystem、CombatSystem、ResourceSystem 或存档；敌军动作目录也不能反向定义正式敌军能力。
- 表现复用以“同一生产包装 / 同一共享参数”为边界，而不是把 DevLab 变成运行时服务。正式 Main 消费权威状态后调用包装，DevLab 构造只读测试 profile 调用同一包装，两者不得各自维护近似武器、坐席或骑姿 Transform。
- 骨骼合成必须保持职责分层：Hips 决定骑乘下半身基座时，不允许为瞄准或前倾直接覆盖；步战源 Hips 中属于上半身构图的旋转应数学转移到 Spine。附件跟随必须由 BoneAttachment 的局部关系承担，动作期全局校准不得抵消骨动画。
- 数值诊断是可重复回归，不是视觉合理性的替代品。每个附件至少暴露父骨、局部 Transform、真实握点距离及必要的工作端 / 前向点积；每个复合动作至少断言下半身基线、关键上半身骨轨和代表相位。最终仍需实景截图确认穿模、正反、接地、重心和动作意图。

## T0138 骑战会合与马匹伤害权威边界

- `HorseSystem` 继续独占马匹个体、分配、HP、死亡和世界位置。T0138-R1 当前上马流为 `stable + waiting_for_rider_at_stable -> ridden -> returning_stable -> stable`：马在取用前固定于真实马厩锚点，NPCSystem 独自执行到马旁最近 NavigationMap 点的导航请求，人物抵达后才提交 `combat_mounted=true`。旧 `approaching_rider` 仅保留运行态兼容，不再由新流程创建。
- `CombatSystem` 只在目标确实 `ridden_by_npc_id` 且 NPC 为 `combat_mounted` 时，把已经完成防御结算的伤害交给 HorseSystem 拆分。HorseSystem 先扣马匹随机 `30%–50%`，CombatSystem 再把剩余整数伤害交给 NPCSystem；马死亡和 NPC 昏迷仍分别由 HorseSystem / NPCSystem 提交各自事实，UI 与表现层不参与结算。
- 正常退出集结 / 战斗只清骑乘投影并让马实体返厩，保留分配；骑手昏迷、马死亡、取消入伍、失去武器或逃离会通过内部系统事务清空双方分配。内部清理可绕过玩家换装锁，但玩家公开入口只有 `work` 模式可调用。

## T0135-P8AR8 铁匠铺敞开正面的权威边界

- 正面围合删除同时发生在表现壳与正式静态碰撞源：表现层不再显示墙 / 门，导航烘焙源也不再包含两段前墙，避免“看起来敞开、实际有隐形墙”的双轨状态。
- 此改动只扩大铁匠铺正面的物理开口，不新增第二套入口或地点权威。既有中央路线点继续决定 NPC 进入 / 离开和 `people_present` 提交；四根表现承重柱不自行生成碰撞。
- 工械坊继续独占当前双扇自动门回归样本；铁匠铺不再实例化 `BuildingAutoDoor`，但其 BuildingSystem、CraftingSystem、fixture、炉火状态投影和存档 Schema 均不变。

## T0135-P6R3 正式世界原点与连续阴影边界

- `CelestialCycleController` 对每个 `time_changed` 从 GameState 绝对时刻重算并立即写入太阳 / 月亮 Basis、能量、颜色、主阴影、天空、环境、雾和室内光；生产 `directional_transform_update_interval_game_seconds=0` 表示不分桶。正值间隔仅是低频降级能力，不是默认表现。
- 阴影稳定性由空间精度而非跳帧获得：默认正式世界根位于原点，CameraRig、生产 NavigationMap、NPC、敌军、商人和塔防都消费同一批原点附近的世界坐标。旧 `(1000,0,0)` 只作为无 `world_origin` 老存档的迁移源，不参与新运行态。
- `StationLayoutController` 在正式模式禁用旧白盒视觉分支的显示与 CollisionObject3D layer / mask；GM 旧图兼容恢复原值。它不会禁用 NPC / Enemies / Effects 等仍被系统持有的运行根。P6R 的 `120 m` 级联和 P7R shadows-only 实体壳继续生效。

## T0135-P6R 动态阴影稳定化边界

- 稳定化只发生在 presentation 配置和两盏天体 `DirectionalLight3D` 上：阴影覆盖由 `180 m` 收紧为 `120 m`，四级联边界启用混合并使用 `0.12 / 0.30 / 0.60` 分割。它不改变太阳 / 月亮轨迹、方向计算频率、色温、能量或主阴影比较器。
- `CelestialCycleController` 继续每次从 GameState 绝对时刻直接重算，不缓存第二套时钟；暂停和倍速仍由 TimeSystem 唯一决定。新增快照只公开实际渲染参数，不成为存档或玩法状态。
- P6R 当时未启用 TAA、方向量化或低频跳步；用户实机确认高频波动仍存在后，P6R2 仅增加上述 `60` 游戏秒 Transform 采样。`120 m` 外仍只失去远景实时细节阴影，碰撞、导航、敌路、建筑透明壳持久阴影和室内遮光不受影响。

## T0135-P8AR6 卫生间表现与权威边界

- 两间卫生间属于正式空间配置中的非交互服务附属物，不是第十三 / 十四座玩法建筑；它们不拥有 HP、等级、库存、资源、工位、地点提交、NPC 行动、事件或 UI 权威，也不因外观节点存在而推断卫生状态。
- 唯一玩法相关边界是物理实体性：`StationLayoutController` 为每一间负责与主体墙身一致的独立静态盒碰撞，并将两者纳入现有显式静态碰撞 NavMesh 烘焙。表现脚本不自行创建碰撞，从而避免视觉层与导航层重复登记。
- 因没有室内和可进入语义，封闭门不响应角色，屋顶 / 墙体不加入近景透明链，也不创建夜间功能灯。若未来要增加如厕需求或卫生值，必须另立任务并通过系统数据与动作事务实现，不能复用当前表现元数据充当结算事实。

## T0135-P8AR4 食堂工作表现只读边界

- 食堂灶台状态继续由 BuildingSystem 占用与 NPCSystem 行动共同构成；`DiningKitchenWorkFX` 只把稳定事实投影为逐灶 VFX，不建立 `is_cooking` 副本，不根据粒子、灯光或模型反推生产事实。
- 单灶控制粒度保证未来多个 NPC 同时烹饪时各自独立启停；发光、粒子和食物 Mesh 均无碰撞、导航、点击或资源接口。第三灶不能因表现节点预建而绕过三级容量解锁。
- P8AR4R 的中空烟囱只把原实心表现 Mesh 拆成四壁围合，不改变烟雾绑定、屋顶渐隐、建筑碰撞、导航或灶台容量；中央孔洞没有新碰撞体，也不成为可通行空间。
- P8AR4R2 删除的 Lv.2 `WestSparkGuard / CenterSparkGuard` 仅是表现节点；不替换为新碰撞、不调整烟雾出口，也不改变 BuildingSystem 等级、fixture 或餐食结算。Lv.2 无屋顶增量后从 `additional_roof_fade_paths` 移除该空路径。

## T0135-P8AR5 洗手池表现边界

- 宿舍 / 诊所洗手池是共享构建器生成的静态表现，不注册 BuildingSystem 工位，不读取或写入资源，不提供清洁、治疗、恢复、用水或交互接口。
- 两个实例靠墙且位于现有通行区外，因此不新增碰撞或导航障碍；专项以最高建筑等级同时显示的真实 Mesh AABB 验证宿舍洗手池—十床 / 壁炉、诊所洗手池—医生桌 / 病床零重叠。未来若洗手成为玩法，必须另立权威任务和 fixture，而不能根据当前装饰节点推断状态。
- P8AR5R 只调整宿舍表现 Transform：洗手池向中线移动 `0.9 m`，二级壁炉 / 烟囱向另一侧移动 `1.0 m`；不修改床位配置、NPC 到达点、StaticCollision、NavigationMesh 或睡眠恢复加成。

## T0135-P8AR3 铁匠铺状态投影边界

- 炉火启停合同为 `forge occupied_by != null` 且占用 NPC 同时满足 `current_location=blacksmith / current_action=work_blacksmith`。表现控制器监听现有事件后只读重算，不申请 / 释放工位，不写 NPC 状态，不推进 CraftingSystem，也不使用每帧权威轮询。
- 工位的铁砧、承台、碰撞和 NPCStand 共享 `building_fixture_layout_v1` 坐标来源；正式 ArtView 只增加旁侧装饰和详细炉体。共享炉 primitive 在正式铁匠铺仅保留元数据根，由同坐标 fixture 碰撞提供物理权威，避免两个炉体叠加。
- 半开放壳体通过同一 `StationLayoutController` 静态碰撞特例缩短侧墙、收窄前墙段；仍保留五段可审计 StaticBody、正式门路线和生产 NavMesh。视觉柱 / 灯支撑不注册碰撞或导航。
- 后炉日间 SpotLight、四盏夜间功能灯、炉火 OmniLight 互不充当玩法权威：日间填光随屋顶显露与太阳色温，功能灯随夜间 / 建筑占用 / 等级，炉火只随真实打铁。三者都有实体阴影、零体积雾贡献或既有壳体遮光，且不按相机距离熄灭。
- P8AR3R2 的壁灯托架和磨轮仍是 authored presentation-only Mesh，不注册碰撞、导航或点击；不再为铁匠铺灯具生成专用落地柱、跨梁或局部门架。吊链随屋顶透明是表现树归属修正，不改变吊装、升级或生产事实。

## T0135-P8AR2 远景灯火与逐级灯具投影边界

- 功能 OmniLight 与被接管的既有灯统一关闭 `distance_fade_enabled`；相机距离不再进入启灯判定。最大拉远仍亮不等于新增时间或照明权威，时间 / 占用规则保持 P8A 单一来源。
- 菜园、训练场、马厩的 authored 灯具使用 `functional_lantern_required_level=1/2/3`，数量合同为 `2/1/1`。BuildingArtView 负责灯具 / 支撑可见性，控制器以同一源灯具 `is_visible_in_tree()` 决定发光核心和 OmniLight 是否解锁，避免两套等级判断漂移。
- 控制器只新增 `building_state_changed` 只读监听，并延后一帧刷新以等待 BuildingArtView 完成投影；不调用升级、不写 BuildingSystem。快照提供 `unlocked_fixture_count / required_level_counts / distance_fade_disabled` 供自动审计。

## T0135-P8AR 露天工作照明与安装支撑边界

- 菜园、训练场和马厩仍沿用 P8A `occupied_night` 权威读取，没有新增“正在工作”时钟或工位占用结算；返修只把每处灯具从一盏增至四盏，并按开放场地尺寸提高表现能量、范围和低衰减覆盖。
- 菜园 / 训练场灯柱与主厅门廊灯柱是无碰撞、无导航、无点击的 authored 表现结构；马厩复用已有棚柱，酒窖复用墙体并增加纯表现木背板。`mounted_to_structure / mount_surface` 只服务视觉审计，不构成建筑 fixture、工位或空间权威。
- 主厅灯柱可见 AABB 继续受 `22×18 m` 既有包络测试约束，不能以照明为由扩大敌军接触面或占用塔防平台。新增 OmniLight 仍有影、零体积雾贡献；P8AR2 后不再按相机距离衰减。

## T0135-P8A 实体功能灯的只读投影边界

- `BuildingFunctionalLightController` 是 `CelestialCycleController` 的子表现控制器，只读 `GameState` 绝对时刻以及 NPCSystem 的 `current_location / is_npc_sleeping`；它监听既有 `EventBus.time_changed / npc_state_changed` 后全量重算，不推进时间、不缓存第二时钟，也不写 NPC、建筑、行动、资源或存档。
- 配置把建筑分成 `always_night / occupied_night / awake_occupied_night` 三种模式。时间边界统一为 `18:00（含）–06:00（不含）`；常亮守备结构不依赖 NPC，普通建筑依赖实际地点占用，宿舍额外排除已睡 NPC。
- 实体灯具、发光核心和 OmniLight 全部是 presentation-only。导入灯具剥离碰撞 / Navigation，局部光开启阴影、关闭体积雾贡献；P8AR2 已取消相机距离淡出。P7R4 环境填光继续负责基础可读度，P8A 只表达夜间真实灯具的局部增量，不把光亮解释为库存、燃料或生产结算。

## T0135-P7R4 局部室内光与实体遮光边界

- 室内填光仍是 `CelestialCycleController` 管理的纯表现节点，但由每座两盏无影灯收敛为一盏有影 SpotLight。光源位于正式建筑局部中心、屋檐以下；P7R opaque shadows-only 屋顶 / 外墙代理既阻挡日月方向光，也阻挡该局部光，因此镜头透明与物理遮光保持分离，只有真实门洞可能产生自然溢光。
- `building_art_view` group 可能同时含正式节点与隐藏兼容节点。控制器不再以 group 遍历顺序决定同 ID 绑定，而是优先 `/FormalStationLayout/`、其次当前可见节点，并降权 `/WorldRoot/Station/` 旧路径；这只修正表现节点归属，不改变 BuildingSystem 的建筑 ID 或任何玩法权威。
- 七盏灯关闭体积雾贡献，不持有碰撞、Area、导航、点击、工位、火源或资源语义。屋顶封闭仍由既有 reveal 权重隐藏补光；P7R4 不改材质 alpha、NPC 选择和日照 / 色温时间曲线。

## T0135-P7R3 日光色温与柔和面状填光边界

- 白昼室内颜色只读同一帧 `_sun_state.color` 与 `_environment_state.ambient_color`，再按表现配置混合 / 去饱和；不创建独立天气、太阳、环境或色温权威。夜间建筑暖色只是可读性表现，不声明实际蜡烛、炉火或资源消耗。
- P7R3 当时使用两盏高位无影 SpotLight 近似面光；P7R4 已替换为单盏屋檐下有影灯。日光色温派生规则继续有效，节点数量与遮光规则以 P7R4 为准。
- P7R shadows-only 壳体仍提供唯一建筑实体阴影；日光漫射只在屋顶显露权重非零时启用，不通过照明改写壳体 alpha 或 NPC 选择规则。

## T0135-P7R2 室内日照同步曲线边界

- `CelestialCycleController` 仍只读 TimeSystem 已写入 `GameState` 的绝对时刻；室内倍率由表现配置的 `06:00 / 12:00 / 18:00` 锚点直接重算，不累计亮度、不推进时间，也不增加存档字段或光照玩法事件。
- 夜间可读基线与白昼增量分离：`06:00–12:00` 连续上升，`12:00–18:00` 连续回落，峰值只改变七座既有补光能量。屋顶显露权重继续与该倍率相乘，因此封闭建筑不会因正午峰值漏光。
- P7R shadows-only 壳体继续独占建筑实体阴影；P7R2 不修改阴影、材质 alpha、点击、碰撞、导航、NPC 地点、工位、火源或生产事实。

## T0135-P7R 透明壳体与阴影渲染职责分离

- `BuildingArtView` 不再把 alpha 当作是否存在实体阴影的开关。每个屋顶 / 外墙 / 升级渐隐 Mesh 的可见实例固定 `cast_shadow=OFF`，其 internal 子实例复用原始 Mesh 与未渐隐材质并固定 `SHADOWS_ONLY`；因此颜色透明与阴影轮廓是两个渲染职责，不产生双影。
- shadows-only 实例作为源 Mesh 的 internal 子节点，自动继承建筑旋转、门叶动画、升级父节点和整体显隐；它没有脚本、碰撞、Area、导航、点击、工位或玩法 ID。所有建筑美术计数只统计 authored Mesh，明确排除 `persistent_shell_shadow_proxy` 元数据实例。
- 日月方向光仍是唯一阴影权威。P7R 不增加第三盏方向光、不修改 Environment、TimeSystem、BuildingSystem 或存档；太阳 / 月亮接管只改变照射方向与能量，同一套壳体代理自然继续投影。

## T0135-P7 环境表现与室内补光权威边界

- `CelestialCycleController` 继续是 `GameState / EventBus` 的只读表现消费者，并在 P6 两盏天体方向光之外拥有唯一动态 `WorldEnvironment`。天空、环境光、曝光、色调和雾都由同一太阳高度快照派生；控制器不推进时间、不写存档，也不生成天气或光照玩法事件。
- `RoofVisibilityController` 新增只读 `roof_visibility_changed(camera_distance, zoom_normalized, view_snapshots)` 表现信号。室内补光只消费各建筑既有 `roof_opacity / exterior_opacity / interior_revealed_for_selection`，不会反向修改屋顶、点击优先级、NPC 地点或建筑状态。
- 七座封闭可进入建筑的 `InteriorFillLights` 只含有影 SpotLight3D，并明确关闭体积雾能量；阴影只用于让建筑壳阻挡局部光，它们仍没有碰撞、Area、NavigationRegion 或工位元数据。显露室内时降低的是同一全局传统雾的表现密度，不创建第二套局部环境，也不更改相机、寻路或战斗视线权威。
- P7 的暖光是可读性填光，不代表炉火、蜡烛、库存、生产状态或资源消耗。实际火把、灯笼、烟与生产粒子仍由 P8 读取真实时间 / 行动状态后实现。

## T0135-P6 天体表现与时间权威边界

- `CelestialCycleController` 是 `GameState / EventBus` 的纯表现消费者。它把绝对时刻映射为两盏 DirectionalLight 的 Transform、颜色、能量和阴影开关，不推进时间、不保存角度，也不生成日出 / 日落玩法事件。
- TimeSystem 继续独占推进、暂停和倍速；GM `set_time` 仍只调用 TimeSystem。读档或跳时后控制器从当前日内秒数立即重算，因此没有需要迁移的存档字段。
- 同时可见的太阳与月亮允许各自提供直射填光，但能量比较器最多只授予一盏主阴影。Main 的旧固定 SunLight 是被退役的兼容节点，不再构成第三个光照权威。

## T0131-P9 马厩表现与马匹 / 照料权威边界

- `FormalStableArtView` 只生成露天马院、遮棚、背景陈设、等级表现与 HorseSystem 的只读马匹投影；它不创建马、不改马匹位置 / 成长 / 驯化，不提交建筑等级、NPC 地点、工位、事件或资源。
- `stall_01..03`、`2→2→3` 照料容量、八个 `HorseAnchors` 和马匹档案继续来自配置、BuildingSystem 与 HorseSystem。马槽、鞍具、干草和产驹用品只表达功能，不代表额外容量、草料库存或新马。
- ActionSystem / NPCSystem 继续负责托马的实体路线、到达、占用与周期动作；HorseSystem 独占马匹位置、照料、骑乘和成长事实。GM `stable_art_level` 只改表现预览状态。
- 自动低门只读取实体接近；露天点击优先与遮棚渐隐只影响显示和射线排序，不替代 StaticCollision、NavigationMap、工位提交或 HorseSystem 状态。

## T0131-P8 训练场表现与训练权威边界

- `FormalTrainingGroundArtView` 只生成露天地块、边界、遮棚、背景陈设与等级表现，并按只读预览等级同步既有 fixture 的显示和碰撞；它不提交建筑等级、地点、工位、装备、技能、疲劳、饱食、事件或记忆。
- `training_instructor_01..02 / training_student_01..04`、六块 `3 × 3 m` 动作区和 `1+2→1+3→2+4` 容量继续来自 `building_defs.json / station_layout.json / building_fixture_layouts.json / BuildingSystem`。地面框、战术板和遮棚携带的 workstation 元数据只用于审计，不能反向创建位置。
- ActionSystem / NPCSystem 继续负责真实会话、实体路线、到达与动作状态；BuildingSystem 独占预留 / 占用，训练成长继续由既有逻辑时间公式结算。GM `training_ground_art_level` 只改表现根预览状态。
- 自动训练门只读取碰撞层 2 的角色接近；露天点击优先与遮棚渐隐只影响射线排序和显示。它们不替代正式 StaticCollision、NavigationMap、工位提交或训练依赖检查。

## T0131-P6 酒窖表现与酿酒 / 交易权威边界

- `FormalTavernArtView` 只生成建筑壳、酒窖背景陈设、等级结构增量，并按只读预览等级同步既有 fixture 的显示与碰撞；它不扣粮、不产酒、不换钱，也不提交地点、工位、等级、HP、事件或记忆。
- `cellar_01..03`、发酵桶、站位和 `2→2→3` 容量继续来自 `building_defs.json / building_fixture_layouts.json / BuildingSystem`。Lv.2 铜管、冷却水槽和储桶架只表达效率，只有 Lv.3 第三发酵桶的同 ID fixture 才构成第三位置。
- ActionSystem / NPCSystem 继续负责真实移动、预留、到达和占用，ResourceSystem 只在完整酿酒周期原子结算粮食与酒；MerchantSystem 是出售酒换钱的唯一权威。GM `tavern_art_level` 只改表现根预览状态。
- P6R 新增的 `6→11→14` 装饰桶只由 `FormalTavernArtView` 生成和计数，并统一声明 `non_workstation_non_inventory_decoration`；它们没有 StaticBody、工位 Marker、库存绑定或路线成本，不能被任何系统当作容量 / 酒量事实。

## T0131-P5 宿舍表现与睡眠权威边界

- `FormalDormitoryArtView` 只生成壳体、生活陈设、二级结构增量并投影既有 fixture 的可见 / 碰撞状态；它不分配床号、不提交占用、不恢复疲劳，也不写建筑等级、HP、地点、事件或记忆。
- 十床与固定归属继续来自 `building_defs.json / BuildingSystem`。`StationLayoutController` 将配置中的 `assigned_npc_id` 复制到床边 Marker 仅供只读快照审计；NPCSystem 与 ActionSystem 仍必须通过 BuildingSystem 预留、实体到达、提交占用并挂接床面后，才建立真实睡眠。
- Lv.2 美术只读取等级并显示壁炉、烟道、保温和修补，不把 `sleep_recovery +0.2` 自行换算或结算；GM `dormitory_art_level` 不改变权威等级。

## T0131-P4 食堂表现与玩法权威边界

- `FormalDiningHallArtView` 与程序化 `dining_table` 只负责壳体、职业语义、装饰和等级可见性；它们不提交建筑等级、资源、餐食、饱食、地点、工位或事件。食堂生产 / 进食仍由 ActionSystem、BuildingSystem、ResourceSystem 与 NPCSystem 权威结算。
- `kitchen_01/02/03`、`dining_seat_01..10` 和共享桌 ID 继续来自 `building_fixture_layouts.json`。表现层只按 BuildingSystem 等级同步现有 fixture 的可见性与碰撞；Lv.2 没有第三口完整灶台，Lv.3 的第三罩 / 烟囱也不能反向创建容量。
- 自动门只读取碰撞层 2 的实体接近，屋顶 / 外墙渐隐只读取相机距离；两者都不代替 StaticCollision、NavigationMap、地点提交或点击优先级。GM 三级预览只覆盖显示层，验收结束后不改变权威 Lv.1。

## T0134-P1 实时人物框权威边界

- 实时人物框是纯表现消费者：`NPCPanel -> NPCPortraitViewport -> NPCSystem.get_npc_portrait_snapshot -> NPC.gd/ArtView` 单向读取。它不设置位置、朝向、动作、工位、HP、地点或选中状态，也不创建第二个 NPC。
- 副镜头和主镜头共享 World3D，Camera3D 只属于 SubViewport，不会替换 Main 当前相机。射线遮挡修正只移动副镜头；人物框关闭后停渲染，避免常驻第二视图成本。
- 共享 World3D 不再意味着共享建筑透明结果：实际会渐隐的屋顶 / 外墙源 Mesh 只进入主镜头视觉层 19，并在源节点下维护同 Mesh、同最终色板、禁用透明和阴影的 internal 纯渲染副本供人物框视觉层 18 使用。两台 Camera3D 通过互斥 cull mask 消除材质状态串扰；副本不带碰撞、导航、Area、地点、工位或建筑状态。
- 地点名称由 MemorySystem 既有地点快照补全；UI 不维护另一份地点映射。表现正面分别由 Synty 包装和 Quaternius 回退包装报告，统一转换为世界方向后供镜头构图。

## T0130-D1 开发检视与权威系统边界

- NPC 开发检视场景是纯表现工具：可自由切换角色、动画、临时装备和坐骑，但不注册 NPC / 敌人实体，不调用 ActionSystem、EquipmentSystem、HorseSystem、CombatSystem 或 ResourceSystem，也不提交行动、伤害、库存和所有权事实。
- 角色能力目录决定哪些动作永远可能出现，当前工作 / 战斗模式只决定按钮是否可用；它们都不反向修改正式 NPC 的职业、征召或行为模式。敌军战斗模式锁定同样只是检视约束，不成为 CombatSystem 的第二套 AI 状态机。
- 工作 / 战斗模式与装备、坐骑选择作为一份跨预览角色共享的场景内存保存，离开场景即丢弃。共享角色包装的 debug 装备覆盖仍为逐实例字段，默认关闭；正式生产实例只读权威 `profile.equipment`。未建模护甲 / 武器只显示文字状态，不以占位 UI 冒充已有 3D 资产。
- T0130-D1R9 只修正开发工具实例化的 `merchant_horse.glb` 局部源轴：马模型不再叠加 `180°` yaw，人物与马的根节点仍统一消费检视 yaw。快照以导入马的本地 `+Z` 正面和人物包装报告的实际可见前向计算点积；该度量与局部校准均不进入 HorseSystem、CombatSystem 或正式世界朝向。

## T0130-P7 医疗表现与治疗权威边界

- `medical_kit` 只在共享 Chibi 包装内建立 Body 药包、LeftHand 病历册和 RightHand 绷带，均为无碰撞、无 Area、无选择面的表现附件；模型或道具接触不构成诊疗、收费、HP 恢复、医术增长或事件事实。
- `work_clinic_doctor -> work / Working_B` 继续由正式工位 active 状态驱动；新增 `assist_heal` 与实际运行态 `assist_heal_<target>` 都只读映射到第 17 个 `medical_treatment / Working_A` 循环。前缀匹配仅消费 ActionSystem 已提交的当前行动，不解析目标或改变 helper 会话。
- 病历册只在 active 诊所值班时显示，绷带只在 active 正式协助治疗时显示；药包作为身份轮廓持续跟随 Chest。行动在途、病人复苏、会话失败、移动、其他生活态与昏迷不会伪装成正在治疗。
- `LinaChibiArtView.tscn` 不包含 CharacterBody、NavigationAgent、SelectionArea 或权威治疗组件；父级 NPC 继续拥有碰撞、点击、路径、治疗距离与空间提交。

## T0130-P6 神父身份附件与职业动作边界

- `remove_detached_headwear` 只在明确开启的包装实例上处理目标 ArrayMesh：以三角形连通与同位顶点重建拓扑岛，仅删除完全位于头脸上方的大型分离附件岛。马塞尔实测删除尖帽 114 个三角面；身体、脸、胡须、Skin 权重、原表面材质与骨骼不变。默认关闭，不影响其余角色。
- `show_wooden_cross` 在既有 Body/Chest `BoneAttachment3D` 下创建两个无碰撞 PrimitiveMesh，只提供职业身份阅读；它不注册交互、导航、装备槽或选择体。`mass_leader_clip` 与已有 `work_clip` 同为包装级表现覆盖，仍复用进程共享 AnimationLibrary。
- `show_rounded_tonsure_hair` 默认关闭；马塞尔开启后，包装按目标 Skeleton 的 Head global rest 把单个低分段 SphereMesh 反算到 Head `BoneAttachment3D` 局部空间。它只补齐原模型平顶，节点树没有 CollisionShape3D、Area3D、选择面或物理骨，不参与射线优先级与导航。
- 马塞尔的 `Working_A / Ranged_Magic_Spellcasting_Long / Sit_Chair_Idle` 分别只投影已 active 的 `work_tavern / lead_mass / pray_at_chapel`。ActionSystem、BuildingSystem、ResourceSystem 与 PietySystem 仍按实体抵达、工位事务和逻辑时间结算；动画时刻和手势不回写权威。

## T0130-P5 装备与卧姿表现边界

- `synced_sword_shield` 与通用武器预览只消费 `profile.equipment.main_weapon.id` 或显式 debug preview，不持有库存、兵种或换装结果。当前剑盾、长杆、弓、弩均有匹配表现；切换武器时必须隐藏不匹配附件，正式装备事实仍属于 EquipmentSystem。
- T0130-D1R7 将剑 / 盾实例化统一收敛到共享几何校准：剑柄采样点反算到 RightHand；盾面法线对齐角色可见正面、朝上轴对齐世界 Up，并沿盾面正向留出 `0.045 m` 手部净空，使 LeftHand 基准点保持在盾背后。开发预览、`synced_sword_shield`、敌军 `sword_shield` 与欧文隐藏预载不允许各自复制 Transform；这些数值和快照度量只属于 BoneAttachment 下的表现，不改变装备或战斗权威。
- P5R2 的 `use_imported_character_material` 只改变目标 Mesh 的表现材质：复制 FBX 导入 BaseMaterial3D 以保留顶点色面部合同，再替换获准的 `_A` Albedo 和明度；不得从材质反推身份、装备或状态。P5R 程序化面部已删除，不形成第二套面部状态。
- `set_spatial_attachment_pose` 是父级空间挂接到表现层的只读语义投影。Chibi 包装用 `Lie_Idle` 表现 `sleeping_supine / lying_supine`，旧包装保留既有父级 Transform；两条路径都不能提交床位、恢复疲劳或生成睡眠事实。
- 训练格挡、攻击、受击、昏迷与复苏仍只读 ActionSystem / CombatSystem / NPCSystem；Synty 模型、KayKit 动画、武器节点和血粒子都不拥有玩法结算。

## T0130-P4 园丁表现与菜园 / 教堂权威边界

- `garden_hoe` 是共享表现包装中的项目 PrimitiveMesh 附件，只由只读 `work_garden + work` 投影控制；它不调用 ActionSystem、ResourceSystem、BuildingSystem 或 PietySystem，也不因锄面接触土地而生成生产事实。
- `Digging` 进入进程共享 AnimationLibrary 的循环白名单，不为伊沃复制独立动画库。包装新增可选 palette grade 与 seated offset，默认值保持前三名角色不变；伊沃专用参数只改变材质输出和可见网格局部坐姿。
- P4R2 只为伊沃开启既有 `use_imported_character_material`：逐 Mesh 复制 Deckhand 导入 BaseMaterial3D，以 `_01_A` 替换 Albedo 并保留顶点色面部；材质不能反推园丁行动、工位、粮食或虔诚事实。
- `IvoChibiArtView.tscn` 不包含 CharacterBody、NavigationAgent 或 SelectionArea。真实田畦、教堂长凳、挂接、碰撞开关、粮食和虔诚继续属于父级 NPC 与既有系统；园锄在 `seated_prayer`、移动、受击和昏迷时强制隐藏。

## T0130-P3 厨师表现与食堂权威边界

- `cook_spoon` 是共享表现包装内的低多边形职业附件，只由只读 `work_dining_hall + work` 投影控制；它不调用 ActionSystem、ResourceSystem 或 BuildingSystem，也不因动画接触锅具而产生烹饪事实。
- 同一布鲁诺包装把真实 `eat_at_dining_hall` 映射为 `seated_eating`，但座位预留、占用、挂接、碰撞切换、食物扣除和饱食恢复仍属于既有权威链。灶台勺不会跟随到餐桌。
- `BrunoChibiArtView.tscn` 不包含 CharacterBody、NavigationAgent 或 SelectionArea；生产实体继续使用父级碰撞。狭窄灶台路线保持生产速度与既有到达容差，本步不以表现测试加速值改变运动配置。

## T0130-P2 职业动作与工具适配边界

- `ChibiCharacterPilot` 的骨架、17 状态和共享动画库保持单一实现，但允许包装覆盖 `work_clip / medical_treatment_clip`；职业差异属于场景配置，不能把 NPC ID 或制造 / 照料规则写入动画系统。
- 工具可见性由“只读权威 action -> 表现状态”单向投影：格伦只在 `work_blacksmith` 拿锤，托马只在 `work_stable` 拿马刷式工具，布鲁诺只在 `work_dining_hall` 拿木柄铜勺，伊沃只在 `work_garden` 拿木柄铁锄。工具节点、动画时间和 BoneAttachment 都不能提交 BuildingSystem、HorseSystem、PietySystem 或资源生产事实。
- 托马的生产场景仍无 SelectionArea、BodyCollision 或 NavigationAgent，继续复用 NPC 父级。`vehicle_seated` 只证明表现合同可用，不建立托马与 MerchantWagon 的权威关系。

## T0130-P1 生产角色表现适配边界

- `ChibiCharacterPilot` 从纯试片扩展为可复用的只读表现适配器，接口与既有 NPCArtView 合同对齐：`apply_profile / set_movement_active / set_facing_direction / debug_get_snapshot`。它仍不注册 NPC / 敌人、不持有 HP、不调用行动或伤害接口。
- 生产 NPC 包装和敌人包装不携带沙盒 SelectionArea；碰撞与点击继续属于父级 NPC / ActorMotionBody。试片场景保留自己的选择胶囊，生产场景与独立沙盒场景分离。
- NPC 映射仍由 `character_appearances.json` 决定；敌种映射由 CombatSystem 按 `unit_type + weapon_type` 选择。当前放行格伦、托马、布鲁诺、伊沃、马塞尔、艾达、莉娜和步行剑盾兵，欧文及其他敌种保留 Quaternius 回退。
- 共享 AnimationLibrary 继续避免每实例复制动画，但每个两头身角色仍有 KayKit 源骨架 + Synty 目标骨架。离线烘焙和完整目标机性能仍属于后续生产优化，不在 P1 改写。
- 源资产轴与运行时朝向分层处理：Synty 可见模型的本地 `+Z` 正面在表现根固定补偿 `180°`，项目实体仍按 `-Z` 目标合同计算 yaw。测试读取补偿后的真实可见轴，不能再用未经补偿的逻辑轴代替画面朝向。

## T0130-P0 角色试片表现边界

- 第三方完整源固定走 `art_source -> 许可 / 清单 -> assets 筛选子集 -> 包装场景` 单向管线；Synty 商业原包不得进入仓库或导出包，KayKit CC0 也只复制实际使用的 Medium Rig GLB。
- `ChibiCharacterPilot`、动作沙盒和 Main 预览控制器属于 presentation-only。它们可拥有 Skeleton、AnimationPlayer、RetargetModifier、Mesh、BoneAttachment、选择碰撞和诊断快照，但不能注册到 NPCSystem / CombatSystem 活动集合或写任何权威事实。
- P0 用实时双骨架换取迭代速度，并通过静态共享 AnimationLibrary 控制内存；正式量产前另行评估导入期 / 离线烘焙，不能在未验证时直接把 48 份实时源骨架当最终架构。
- GM `character_pilot` 只启停临时表现根或切换沙盒，不构造刷波、伤害、行动或地点接口。生产切换门槛仍是用户视觉验收后显式修改 `character_appearances.json` / CombatSystem 包装引用。
- 表现附件的几何诊断必须来自真实网格分区，并与实际运行截图共同验收。T0130-P1R4 将格伦工作锤拆成柄尾、后段握点和最近锤头三个采样区，防止“错误点贴手但画面仍握锤头”的伪通过；所有模型 Transform 调整还须检查正面、侧面和必要动作相位的穿模、方向、接地与重心。

## T0129C-A5-P8 正式空间检查点边界

- `SpatialSaveSystem` 只协调空间权威，不成为 NPC、战斗、交易或行动的第二套结算器。格式为 `formal_spatial_save_v1`，消费者子结构分别由 NPCSystem、CombatSystem、MerchantSystem 产生和恢复。
- 加载顺序固定为：正式根启用 → 生产 NavigationMap 强制同步 → 对话 / 在途行动回滚 → NPC 安全坐标与静默地点成员恢复 → 活动波次重建 → 逃离续接 → 行商阶段恢复。RID、NodePath、节点引用和工位会话 ID 均不入盘。
- 活动事务采用释放后回到保存坐标，不重放 `location_entered / action_started`；波次按配置重建实体并按 `spawn_index` 套用存活者空间状态；行商恢复本身不广播到离场事件。

## T0129C-A5-P6d-3 治疗协助空间事务边界

- `ActionSystem` 独占 `assist_heal` pending / active、两人上限、首付 / 续费、helper、恢复、经验与事件；`NPCSystem` 独占可逆目标投影、正式地点路线、目标 Body 接近和空间会话；既有 NPC HP / 复苏入口仍是唯一生命权威。
- 事务顺序固定为 `unconscious + money preflight -> reserve healer session/target projection -> formal location route -> distinct body approach -> arrival revalidation -> charge first coin -> add helper -> ordinary healing tick`。到位前不提交任何治疗事实。
- 目标复苏信号延迟到当前 HP 事务结束后统一清理，避免同步回调重复写 `healing_completed`。所有中断先释放目标投影与 formal session，再移除 pending / active helper；没有新增存档事实、治疗公式或第二套结算。

## T0129C-A5-P6d-2 升级协助空间事务边界

- `assist_upgrade` 复用 formal exterior session，但使用独立 `service_kind=upgrade` 与施工槽占用。ActionSystem 独占 pending、upgrade helper、事件和目标失效；NPCSystem 独占实体路线；BuildingSystem 继续独占升级资源、倒计时、倍率和等级应用。
- 事务顺序为 `active-upgrade preflight -> reserve construction slot -> physical route -> exterior arrival -> add upgrade helper -> ordinary upgrade tick`。升级建筑封闭不等于室外施工路线无效；建筑状态清退扫描会显式跳过目标一致的 formal exterior assist。
- 完成或中断继续从既有 ActionSystem / BuildingSystem 出口清理 helper，再结束可逆空间会话。没有新增第二套升级结算或存档事实。

## T0129C-A5-P6d-1 修复协助空间事务边界

- `ActionSystem` 独占 `assist_repair` pending / active、目标有效性、helper 与事件；`NPCSystem` 独占可逆正式空间会话和实体移动；`StationLayoutController` 只提供按最大等级包络推导的外沿槽；`BuildingSystem` 继续独占修复进度与倍率。
- 事务顺序固定为 `repair preflight -> reserve exterior slot -> physical route -> exterior arrival -> add helper -> ordinary repair tick`。到位前不得提交 helper、有效工时、工程经验或开工事件。
- 维修位只是一段会话内的空间占用，不新增 BuildingSystem 工位或存档事实。完成、目标消失和任意中断都从既有 ActionSystem 出口移除 helper，再结束 formal session；GM 只调用公开事务接口。

## T0129C-A5-P6c 对话空间事务边界

- `ActionSystem` 独占 `talk_to_npc` pending、双方预约、一次重定向和失败；`NPCSystem` 独占双方 CharacterBody 投影、正式地点路线、NavigationAgent / RVO 接近与可逆空间会话；`DialogSystem` 仍独占邀请和正式会话。
- 事务顺序固定为 `LLM 意图复核 -> formal location route -> entity approach -> invitation pending -> accept-time spatial transfer -> ordinary action interruption -> conversation`。拒绝或失败不会提前释放目标工作位，接受时先交接 Body 再释放工作会话。
- 正式对话结束信号以 `dialogue_id` 回收空间会话。所有失败 / 中断出口复用同一清理函数；GM 只调用 ActionSystem / DialogSystem 接口并读取快照，不创建第二套对话或空间结算。

## T0129C-A5-P6b 拜访空间事务边界

- `visit_location` 使用 `ActionSystem pending -> NPCSystem formal location session -> physical route -> location commit -> ActionSystem active` 单一事务链；没有 BuildingSystem 工位 reservation / occupancy 阶段。
- 物理门槛提交地点，目标室内点 / 公共锚点提交行动开始。途中改派先结束旧会话，再创建新目标会话；暂停、建筑失效、昏迷和不可达只清理尚未提交的路线，不伪造到达。
- MemorySystem 继续接收既有 `location_exited / location_entered / visit_started / visit_completed`，事件 Schema 未变。GM 只调用 ActionSystem / NPCSystem 的公开或 debug 接口，不写地点或事件事实。

## T0129C-A5-P5i 礼拜空间事务

- 小教堂继续使用 `ActionSystem -> NPCSystem formal session -> BuildingSystem reservation -> physical arrival -> occupancy -> active` 单一事务链；在途不会进入 PietySystem 的 active 贡献集合。
- 已占席祈祷者与主持弥撒之间只切换 `prayer_mode`，不销毁或重领祈祷席。跨小时计划延后、主持退出恢复独祷和完成 / 中断事件复用既有 T0098 / T0105B 状态机。
- 表现层只读取 action / mode 并挂接姿态，不写虔诚、事件或计划；本步没有后端、Prompt、LLM provider 或 API 变化。

## T0129C-A5-P5h 训练服务空间事务

- 训练服务沿用 `ActionSystem -> NPCSystem formal session -> BuildingSystem reservation -> physical arrival -> occupancy -> active` 单一事务链，没有增加第二套训练结算。
- 装备前检在创建正式会话前完成；到位后再次复验。教官 / 学员 active 记录 `formal_spatial_authority`，因此普通中断、昏迷、建筑失效和最后教官离岗均走同一会话 / 工位清理出口。
- 该任务完全是 Godot 本地权威与表现迁移，不涉及后端、Prompt、LLM provider 或 API 调用。

## T0129C-A5-P5b 真实打铁跨系统边界

`work_blacksmith` 仍由 ActionSystem 负责行动生命周期，CraftingSystem 独占制造目标、项目 revision、阶段领取、材料扣除与产物，BuildingSystem 独占工位预留 / 占用，NPCSystem 独占角色地点、实体导航和可逆正式会话。业务预检发生在空间迁移之前，但到位后仍必须重校验，避免途中目标 / 材料变化造成过期提交。

工作周期完成与正式会话结束是两个独立层次：`repeat_while_planned` 可在同一会话 / 工位上启动下一周期；只有确认没有同行动 pending / active 时才可结束会话。延迟清理携带 `session_id`，表现 / NavigationMap 隐藏延后且可被新会话取消，玩法权威清理不延后。GM 只调用上述公开 / `debug_*` 链，不复制任何结算。

## T0129C-A5-P3 高频时间投影边界

`logical_time_tick` 继续逐帧同步驱动权威模拟，不能为降低 UI 成本而降低战斗、需求、恢复或行动结算频率。表现层改为消费窄投影：HUD 使用 `CombatSystem.get_wave_hud_snapshot()`，不再通过完整 `get_wave_schedule_snapshot()` 深拷贝活动战斗和历史结果。普通倍率下 HUD / MerchantSystem 以 `day:hour:minute` 去重时间表现与到访检查；TimeSystem 处于 LLM 慢速、需要精确秒显示时，HUD key 包含秒。GameState 和完整 tick 的权威时间推进没有降采样。

## T0129C-A5-P1 战时全员空间迁移边界

CombatSystem 只决定一次默认战斗需要进入正式世界的 NPC 集合并区分战斗人员 / 非战斗人员；NPCSystem 仍独占 Body 迁移快照、NavigationMap 绑定、运动请求、状态提交与可逆恢复。`begin_formal_combat_world()` 允许“全部因昏迷等暂时不可行动而零迁移”的合法空结果，但锚点缺失或 NavigationMap 绑定失败不会被伪装成成功。

避战的行为决定、退出条件与事件仍归 CombatSystem；正式目标只经过步长限制与生产 NavMesh 投影，真正路径、RVO、实体碰撞和 `move_and_slide` 仍由 ActorMotionBody 处理。`NPCSystem.get_npc_state()` 的高频读取只复制 states，而不再为每次战斗采样深拷贝整份静态 NPC 档案，返回值隔离语义不变。

逃离出口由当前空间决定：正式战斗中的已迁移 NPC 从 StationLayoutController 取得地图边缘 `(-54,-305)`，通过同一生产 NavigationMap 上的后门单向链接与 6 点后路 Region 实际行进；其他非战日常路径暂保留旧常量。开始、对话恢复、复苏恢复和活动快照共享 `escape_intent.exit_position`；只有 NPCSystem 收到最终物理到达信号后才提交离站事实。战斗结束会保留仍在逃离的 NPC 及正式世界导航租约，其余 NPC 立即恢复，逃离完成或留下后再统一释放。

## T0129C-A4-P7 动态接敌压力控制器

正式敌军继续使用三层权威边界：CombatSystem 逐敌选择目标、判断射程并提交攻击；ActorMotionBody 独占路径、RVO、实体碰撞和 `move_and_slide`；表现只读取实际位移与战斗状态。P7 删除 CombatSystem 运行态的固定槽分配，改为多个 Agent 对同一目标接触点产生独立运动意图，拥堵形状由胶囊碰撞和局部 avoidance 自然形成。

每次逻辑战斗步重新评估最近可行动我方单位，否则使用当前未摧毁建筑。目标变化或移动超过 `0.35 m` 时 supersede 原请求；进入各自武器射程后暂停运动并复用既有攻击链。ActorMotionBody 的真实不可达仍是失败，但同伴拥堵导致的 `stuck_timeout` 被 CombatSystem 解释为可恢复的 `pressing_blocked`，下个战斗步重新请求，因此前排移开 / 昏迷后后排可补位且不会用超时提交攻击权威。

StationLayoutController 的 `get_formal_wave_navigation_config()` 对 1–5 波返回统一 `c3_p7_dynamic_assault`；旧攻击槽转换代码只供历史 P5/P6 兼容。P7b 后普通 `spawn_wave()` 也调用同一正式实体工厂，并先显式启用正式地图 / 镜头，再由 NPCSystem 迁移可战斗 NPC，避免不可见远端 staging 接管却没有我方实体。

P7b 的运行边界为：CombatSystem 选择波次、敌人实体和目标；NPCSystem 独占 NPC 迁移记录、运动请求及恢复；StationLayoutController 独占正式 NavigationRegion / NavigationLink / 镜头启停。默认敌人查询 NPC 时必须通过 `is_npc_in_formal_combat_world()` 过滤另一坐标世界的日常 NPC。战斗结束顺序是行为模式收口 → NPC 正式运动停止与原坐标恢复 → 正式地图退出；不把临时正式坐标写回 NPC 档案。默认后续波次可以继续加入当前正式世界，显式 debug 切片仍拒绝与其他活动敌人混用。

A4-P7R 补齐运动稳定合同：ActorMotionBody 在应用 profile 时同步设置 NavigationAgent `max_speed`，并把 RVO safe velocity 限制到 profile 上限后再走 `move_toward(..., acceleration * delta)`；最终 velocity 仍二次限速。CombatSystem 不再按旧 formation 行列设置不同 avoidance priority；T0200 后仅保留与编队无关的稳定身份微差来打破对称礼让。表现方向属于独立只读滤波状态：忽略低于 `0.35 m/s` 的碰撞恢复，合法方向变化按 `360°/s` 夹取；它只驱动可见朝向，不反写路径、速度、索敌或攻击权威。

## T0129C-A4-P6 可复用正式波次工厂与分角色槽位（历史）

第一波入口现为 `_debug_run_formal_wave_slice(wave_number)` 的兼容包装，第二波通过同一工厂读取自己的权威波次模板、构造 ActorMotionBody、注册 `_active_enemies`、连接运动信号并启动既有战斗生命周期。没有复制第二套移动、伤害或清理系统。

StationLayoutController 的 `get_formal_wave_navigation_config(wave_number)` 负责把 station / building-local 槽位转换到世界空间；CombatSystem 只把 `unit_type` 映射为 `melee_front / polearm_rear`。主厅阶段在角色内部按当前物理位置领取最近未占槽，剑盾前排形成后才放行长杆后排；目标摧毁仍由既有建筑权威触发请求替换，表现、运动、战斗和配置边界不变。

## T0129C-A4-P5R2 多敌直攻与同侧攻击位权威

第一波正式切片保持三层边界：`ActorMotionBody` 独占路径、速度、avoidance 与碰撞移动；CombatSystem 为每个敌人独立保存当前建筑目标、分配攻击位、物理到达和攻击许可；表现层只读取 Body 位移方向。道路只画材质 / 网格，不进入寻路权重；建筑 HP、事件、失败和战斗结束仍只走既有 BuildingSystem / CombatSystem / GameState 权威链。

第一波不再消费十阶段折点，只向正门、仓库、主厅下发单一当前目标。目标摧毁时用 `superseded` 替换尚在运行的请求；这是有意重定向，不记为失败。每名敌人按稳定索引领取独立攻击位，主厅位置全部限制在北侧正面同一纵深，只做横向错位；NavigationMap 吸附后由 `motion_arrived` 唯一解锁攻击，旧超时假到达保持删除。

## T0129B-C3-P4 主厅到达 / 失败权威桥接

仓库到主厅均位于核心生产 NavMesh，不新增导航网或瞬移链接。CombatSystem 在仓毁后只请求完整敌路的 `main_hall` 阶段；ActorMotionBody 实际到达后才开放目标选择。运动层仍不拥有 HP 或失败结算，最终摧毁沿既有 BuildingSystem -> CombatSystem -> GameState 单向链提交失败。

## T0129B-C3-P3 破门后导航 / 仓库权威桥接

外围敌路 Region 与核心驿站 Region 原先在正门处属于两个导航岛。P3 在同一专属 NavigationMap 增加 `EnemyFrontGateLink`，连接正式 `front_gate` 与 `gate_turn`；T0160 将其扩为双向实体通行，使友军警铃响应者也能从站内走到正门外集结区。ActorMotionBody 仍沿链接端点执行实体位移，未瞬移或直接写最终坐标；敌军是否越门仍由正门摧毁后的目标阶段决定，链接不授予攻击或破门权威。链接只随正式世界 / 显式切片启用。

CombatSystem 在正门摧毁后只下发下一物理阶段并锁住攻击，直到 `motion_arrived(warehouse)` 才恢复目标选择。BuildingSystem 继续独占正门 / 仓库 HP 与摧毁，MemorySystem 继续只接收实际伤害事件。仓库摧毁后不回退到旧主厅坐标。

## T0129B-C3-P2 单敌空间 / 战斗权威桥接

P2 没有复制攻击系统。正式 `ActorMotionBody` 只更新活动敌人字典中的实时位置和路线阶段；CombatSystem 仍是目标、抬手、冷却、伤害、战斗事件和结束清理的唯一权威。`attack_unlocked` 只能由 `motion_arrived(front_gate)` 设置，逻辑时间推进不能伪造到达。正门目标的空间位置来自正式路线，而建筑 HP / 名称 / 摧毁仍来自 BuildingSystem。

P2 的门毁 hold 已由 P3 替换；主厅仍保持未迁移边界。

## T0129B-C3-P1 敌军外围导航分层

边缘林下出生点距驿站核心导航范围约 281 m，因此 C3-P1 没有扩大或重烘焙已经验收的核心 NavMesh。`StationLayoutController` 从正式敌路的 spawn 至 front_gate 生成一条独立导航带（10 顶点 / 4 多边形），与核心 Region 绑定同一个专属 NavigationMap，并随正式预览 / 显式试点启停。这样核心 788 顶点 / 754 多边形及 61 工位路线保持稳定，外围敌路又能直接使用统一 `ActorMotionBody`。

CombatSystem 仍拥有敌人阶段与未来攻击提交，运动组件只拥有实体位移、路径、avoidance 和到达 / 失败结果。P1 样片不加入活动敌人集合；这是对空间和运动的隔离验收，不是第二套战斗系统。

## T0129B 空间配置迁移架构

正式空间现在以 `data/station_layout.json / station_layout_v2` 为目标数据合同，但采用分阶段切换而非一次性替换：C1 生成远端静态 staging；C2a 生成公共地点、12 套入口路线、65 个权威位置、8 个 NPC 初始点和确定性 AStar 合同网格；T0201 后正式 staging 共生成 241 个 StaticBody / 255 个 CollisionShape，其中包含 58 段建筑外墙、1 个主厅内部阻挡、14 段围墙、4 根城门柱、1 个烘焙地面、133 个家具碰撞部件和 24 个自然边界。当前 `0.25 m` 生产 NavMesh 为 `928 vertex / 862 polygon`，使用 237 个导航源和 11 个建筑门链接。主厅 `MainHallArt` 与仓库 `WarehouseArt` 都是纯表现组合；仓库以 `BuildingArtView` 接入统一屋顶渐隐，但不创建进入触发体、NPC 工位或库存事实。全部 12 座建筑的 107 件配置物提供 61 个 NPC 到达点、36 个表现锚点与 8 个 HorseAnchor；主厅和仓库不会伪造 NPC 工位。

旧 `WorldRoot/Station` 只保留开发兼容；A5-P7 后正式 NavigationMap、Region、门链接、日常 NPC 与默认行商均随新局启用。NPCSystem / BuildingSystem 对可进入建筑消费正式路线和事务：物理穿门后提交地点，抵达后提交占用；床 / 椅 / 长凳位置再于提交后挂接，取消或失败均反向清理。A4 已迁移默认五波敌军，C4-P2 已让 NPC 消费 6 点地图边缘逃离路；P7R2 后 MerchantSystem 默认消费 `rear_spatial_v1` 六点商路，旧 `(-40,-120)` 仅为进门引导，只有到达距后门约 `7 m` 的 `(-28.2,-52.4)` 才提交停靠。

任何系统都不能根据建筑中心猜测入口、工位、射界或完成点；必须读取正式配置的对应字段。`station_spatial_plan_v7` 只保留设计对照和压力验收，正式控制器不直接消费它；C2a 专项允许读取两份数据进行漂移检查，但运行时只读取 `station_layout_v2`。

家具、落脚点与附着表现采用分层合同：`station_layout_v2.positions[].center / size` 是容量、升级和空间预留使用的逻辑工作湾；`building_fixture_layout_v1.fixtures[]` 是逐件可见设备及碰撞，`npc_stand` 是 CharacterBody 实际到达点，可选 `occupant_anchor` 只用于到达并提交占用后的床面 / 座位表现挂接，可选 `horse_anchor` 只为 HorseSystem 中实际在厩马匹预留独立实体净空。路线查询对已有实物合同的工位返回 `interior_target_position=站位`，并保留 `logical_position_center_position / target_fixture_id / arrival_mode`；需要挂接时再返回 occupant anchor，不能把任何锚点作为寻路终点。任何权威系统都不能从家具视觉节点反推占用或马匹数量，任何运动层也不能把逻辑湾中心、家具中心或马匹锚点重新当成 NPC 实体站位。

A3b9R 将这套分层合同应用到教堂：每个 Quaternius 半排长凳只映射一个固定 `chapel_prayer_seat`，实体先抵达长凳侧前方 stand，BuildingSystem 提交占用后表现层才可使用 `seated_prayer` 锚点。长凳宽度、座垫数量或装饰书本都不能反向增加祈祷容量。

A3b10R 对工械坊采用同一边界：`workshop_role` 只选择制弓 / 机构 / 总装的表现包装，`asset_path` 只实例化 Quaternius 主体；是否解锁、能否开工、制造目标、阶段、资源和 `reserved_by / occupied_by` 仍分别由 BuildingSystem、CraftingSystem 与 ActionSystem 决定。共享工具墙、吊架、测量台和材料架没有 `workstation_id`，不能因为视觉上可操作就被运动层当作新增工位。

运动权威边界已经冻结：NPCSystem / CombatSystem / Merchant / Escape 只下发 movement intent、destination 和完成语义；运动组件独占路径、速度、avoidance、`move_and_slide`、卡死采样和重寻路；表现层只读取速度 / 朝向播放动画。NavigationAgent 到达不能自行提交地点、工位、伤害或逃离，仍由既有系统在物理门、具体位置或地图边缘完成条件满足后原子提交。

A5-P2 为正式大波次增加了不改变数值结算的时间分片：CombatSystem 每帧轮转最多 8 名敌人，并为每个敌人独立累计未处理帧的游戏秒 / 战斗动作秒；因此索敌刷新可拆帧，而冷却和攻击次数仍使用完整累计时间。接触与避战复核采用 6 / 3 帧节奏，CharacterBody / NavigationAgent 的 `_physics_process` 不分片。该预算仅用于默认正式战斗世界；显式 debug 推进仍一次处理全部敌人，便于确定性回归。

`ActorMotionBody` 是该边界的 A2a 参考实现。Body 使用 `actor_body=2`、mask `world_static|actor_body=3`；点击 / 对话 `InteractionArea` 使用 bitmask 4、mask 0。每物理帧必须调用 `get_next_path_position()`，候选速度先经加速度约束，再写入 NavigationAgent velocity，下一次 `velocity_computed` 的 safe velocity 必须再次受 profile 最大速度与加速度约束后才能交给 `move_and_slide`；NavigationAgent 自身 `max_speed` 也必须同步到该 profile。卡死超时只累计连续无进展采样时间，不用完整路线耗时；目标超出导航岛时返回 `target_unreachable`，物理阻挡持续存在时只做配置上限内的重寻路并返回 `stuck_timeout`。`motion_arrived / motion_failed / motion_cancelled` 是结果通知，不是玩法提交。

P3 为室内狭窄终点补充平面可达性复核：NavigationAgent 初次同步后若报告不可达，运动层用同一 NavigationMap 的 `map_get_path` 重新取路径，并只在路径末端与目标的水平距离小于到达容差时接受。这样可忽略 Recast 路面高度与角色目标 Y 的小偏差；真正位于导航岛外的目标末端水平误差仍超限并返回 `target_unreachable`。

A2b-P1 保持该边界：NPCSystem 在启用试点前强制中断格伦当前 ActionSystem 行动并登记试点锁，避免自动日计划覆盖正在执行的正式路线；NPC.gd 只把 NavigationAgent 的到达 / 失败翻译为 NPCSystem 结果。专属 NavigationMap 首次绑定允许约半秒同步宽限，再按 `is_target_reachable()` 判定不可达；失败处理只释放 pending reservation / occupancy 和路线状态，不伪造地点到达。

A2b-P2 扩展同一边界：`arrival_mode=stand` 只在具体诊疗站位提交占用；`mount_after_arrival` 的路径终点仍是床边站位。NPCSystem 必须先调用 BuildingSystem 提交 `reserved_by -> occupied_by`，确认成功后才调用 NPC 的表现锚点接口；若挂接失败则反向释放已提交占用。躺卧期间禁用实体 Body 以避免床体持续推挤，但点击 InteractionArea 继续有效。昏迷、建筑失效、不可达、停止和返回旧图都经过同一事务清理；锚点姿态不启动 ActionSystem 治疗，也不是地点 / 工作事实源。

A2b-P3 将上述事务泛化为按 `pilot_id` 查询的统一启动、停止和快照接口。宿舍试点在预留后额外校验返回 ID 必须为登记的 `dormitory_bed_01`，防止固定归属错误时静默占用其他空床；进门步骤以路线的 `interior_position` 落地，最终床边到达后沿既有先提交、后挂接顺序应用 `sleeping_supine`。试点不调用 ActionSystem 睡眠接口。

A2b-P4 不设置 `expected_workstation_id`，让 BuildingSystem 成为非固定餐位排序的唯一权威。专项先验证空场返回 `dining_seat_01`，再由另一 NPC 占用 1 号席并验证返回 `dining_seat_02`；停止布鲁诺试点只按 NPC ID 和本次 workstation ID 释放自身事务。椅面 `sitting` 仍在占用提交后挂接，且不调用 ActionSystem 进食接口。

## T0127 铁匠铺空间事务边界

```text
ActionSystem 派发 work_blacksmith
  -> BuildingSystem.reserve_workstation：只写 reserved_by
  -> NPCSystem：门外 -> 门内 -> 具体 Marker
     -> 穿门：MemorySystem.move_npc_between_locations，提交 current_location / people_present
     -> 抵达 Marker：ActionSystem 提交 reservation
  -> BuildingSystem.commit_workstation_reservation：reserved_by -> occupied_by
  -> ActionSystem 创建 active，才开始权威计时 / 制造结算
```

铁匠铺路线由 NPCSystem 维护单一阶段状态，BuildingArtView 只提供坐标，碰撞、屋顶和动画都不能自行提交事实。离开按反向路线，在门内阶段仍保持铁匠铺地点，穿过出口才提交广场。升级、行动失败、昏迷、战斗 / 对话改派和逃离都先释放预留 / 占用，再按物理阶段决定门外停止或真实退出；最终失败结果不能被退出移动的 start result 覆盖。

本合同目前只对 `blacksmith / work_blacksmith` 生效。其他建筑继续使用旧的入口直达与到达提交，不得因为 BuildingSystem 已支持 `reserved_by` 就推断其已经拥有真实室内。LLM、NPC-NPC 对话与本地公开事件继续只读 NPCSystem / MemorySystem 已提交的逻辑地点，不读世界坐标或屋顶透明度。

## T0126 屋顶透明的单向表现边界

`RoofVisibilityController` 是唯一相机距离采样器，输出 `camera_distance / zoom_normalized` 并调用已注册 `BuildingArtView`；每座包装只把该输入映射为自身 smoothstep alpha 与屋顶阴影开关。该链路不向 BuildingSystem、NPCSystem、ActionSystem、MemorySystem 或 EventBus 回写，也不修改碰撞、点击区、导航、HP、等级、工位或地点事实。

`BuildingArtView.tscn` 的 InteriorTrigger 与 NavigationRegion3D 在 T0126 只是空间合同：碰撞 shape 已存在，导航区域保持禁用。T0127 才允许通过既有 ActionSystem / NPCSystem 的事务式移动链把 EntryMarker、室内 Marker 和地点权威对齐；不得以“屋顶已透明”推断 NPC 已进入建筑。

## T0125 导入基线的非权威边界

`ArtSandbox.gd`、GLB、Skeleton、AnimationPlayer、材质 surface override、rim、outline、灯光和相机只属于技术美术验证。`art_scale_baseline.json` 只提供显示尺度、色板、过滤与性能软上限，不参与建筑、地点、工位、行动、资源、HP 或战斗结算。T0125 没有连接 EventBus、没有新增 Autoload / 系统节点，也没有修改 Main；正式包装场景仍须只读既有权威状态。

## T0123 美术表现与权威模拟的规划边界

美术升级不建立第二套建筑、NPC、战斗或地点权威。Quaternius Mesh、Skeleton、AnimationTree、碰撞、导航、屋顶透明、粒子、贴花、布娃娃和 UI Theme 均属于表现 / 空间执行层；资源、HP、伤害、建筑等级、位置容量、行动进度、事件与记忆仍由现有系统决定。

T0127 的真实室内迁移需要把物理位置与权威地点重新对齐，但不会让碰撞或动画成为事实源。目标数据流为：

```text
ActionSystem 请求并预留位置
  -> NPCSystem / NavigationAgent3D 执行到门口和室内 Marker 的路径
  -> 穿过门口时提交 current_location / people_present
  -> 抵达具体 Marker 后把 reserved_by 提交为 occupied_by
  -> ActionSystem 才开始权威行动计时与结算
```

离开、升级清退、行动失败、昏迷、战斗打断和逃离使用反向 / 中止事务，不能提前把仍在室内的 NPC 写成广场人员，也不能留下幽灵预留。T0127 已按该合同完成铁匠铺首个样本；其他建筑仍沿用入口占位流程，等待 T0131 逐座迁移。

## T0116 对话执行前异步边界

DailyPlanSystem 是计划对话预检编排器：执行签名通过后先发复核，不先中断 ActionSystem。LLMBridge 只负责构造上下文和 HTTP 生命周期；Backend 只校验模型决策；continue / modify 的最终 ActionSystem / NPCSystem 调用及 cancel 的计划重估都由 DailyPlanSystem 完成。请求上下文保存 day/hour/plan_version/item_identity，所有回调先比对再落地。

制造失败数据沿 `CraftingSystem result -> ActionSystem work_failed payload -> MemorySystem -> LLM compact projection` 单向传播。ActionSystem 只对失败码做稳定中文映射，不再用缺失 message 的默认值猜原因；资源和阶段结算权威边界不变。

## T0115 陈旧失败隔离与主动交涉交接

```text
ActionSystem 权威失败
  -> plan_revision_judgement 选择小时
  -> revise_plan 返回选中小时
     -> Godot 对当前小时比较 action_id + target + dialogue_goal
        ├─ 原样重复失败项：不落地，留在同一 stage-two 有界重试
        └─ 合法新项：合并计划并派发
           -> seek_guard_officer
              -> NPCSystem 原子写 proactive_talk_started + 空失败上下文
              -> 单次 npc_state_changed

玩家点击主动交涉
  -> DialogSystem 创建并激活同一草稿
     ├─ 规划中 / 状态竞态拒绝：清草稿，保留 proactive
     └─ 激活成功：NPCSystem 才消费 proactive，进入 NPC 发起对话
```

失败去重不再依赖“新行动恰好没有触发状态通知”。所有本次审计覆盖的新行动入口在通知观察者前提交完整状态；建筑移动、世界目标移动和主动交涉都用非失败 start result 覆盖旧终态。目标比较兼容 provider Schema 的顶层专用字段与内部计划的嵌套 `target`，并把 `dialogue_goal` 纳入主动交涉 / 对话类 one-shot 身份，避免不同诉求被误判为同一活动。

DialogSystem 的草稿激活返回值必须同时满足 `ok=true / activated=true / dialogue_id` 与刚创建草稿一致，不能把“草稿已被同步监听器撤销”当作成功。UI 不拥有回滚职责；NPCSystem 只根据最终业务结果消费主动交涉。没有新增 endpoint、Schema、Prompt、EventBus 信号或第二套计划权威。

## T0114 虔诚—陨石权威数据流

```text
ActionSystem active 祈祷有效秒
  -> PietySystem 共享累计 / 100 封顶
     -> EventBus.piety_changed
        -> HUD 圆环 / 满值发亮

HUD 任意有限水平地面点
  -> PietySystem 满值与坐标有效性校验、消费、效果时序
     -> CombatSystem.apply_enemy_area_damage
        -> 仅活动敌人：防御、死亡、清敌 / 战斗结束
     -> MemorySystem：施放本地公开 / 落地全站公开 / 条件式击杀事件
```

PietySystem 是新增的单一权威边界：配置加载、共享值、落点有限性、陨石 / 燃烧状态和消费都在这里；T0163 起不再存在驿站选点范围。ActionSystem 只提交已经发生的 active 时长，HUD 只显示和提交目标。CombatSystem 的范围入口刻意只接触 `_active_enemies`，从结构上隔离 NPC、建筑和我方器械伤害，因此“无友伤”不依赖阵营标签或 UI 过滤。表现节点挂在 `WorldRoot/Station/Effects`，不保存权威状态。T0159 后，PietySystem 只在冲击结算返回后提交落地事件，并按 `defeated_count > 0` 条件提交独立击杀事件；MemorySystem 将这两类重大事件作为全站公开例外写入所有合格 NPC 见闻，仍不反向参与伤害或击杀判断。

## T0113 对话权威实况投影

```text
DialogSystem 打断前活动 ─┐
NPCSystem 当前装备槽 ────┼─> LLMBridge dialogue truth builder
ActionSystem 训练运行态 ─┘       ├─ activity_truth
                                ├─ equipment_truth
                                └─ training_truth
                                      -> NPCDialogueRequest 成套校验
                                      -> ModelAdapter 保留装备空槽 null
                                      -> dialogue provider
```

该投影是只读冗余事实层，不拥有行动、装备或训练结算权。`activity_truth` 优先读取对话打断快照，避免对话期间的 `talk_to_guard_officer` 覆盖原活动；训练资格按“装备 → 在岗教官 → ActionSystem 环境”顺序给出单一首要 blocker。旧测试客户端可三组全部省略，正式 Godot 请求不会省略；只携带一部分会在 Pydantic 边界失败。

## T0106 全量紧凑记忆数据流

```text
MemorySystem 完整权威事件 / 见闻
  -> LLMBridge 按当前短期索引顺序读取全部记录
     -> summary + 决策相关 details
        ├─ 普通五类：experienced_events / witnessed_events
        └─ 熟睡总结：day_events + memory_kind
  -> Pydantic EventSummary 丢弃旧 payload
  -> ModelAdapter 外层字段白名单再次清洗
     └─ daily_reflection 删除重复 npc.short_term_memory
  -> provider
```

MemorySystem 继续负责完整 payload、事件 ID、传播和快照水位，不因为 token 优化改变权威数据。压缩发生在只读投影层：大结构优先由确定性 summary 表达，24 项计划额外压为连续 `plan_segments`；原因、资源缺口、投入产出、指令变化和其他摘要未充分表达的标量 / 小结构进入 `details`。Model Adapter 的第二层清洗确保旧客户端或测试夹具携带的 `payload / event_id / extra` 不能越过供应商边界。

当前七类正式调用（含执行前复核）均使用同一投影器，不存在独立的“无记忆轻量判别”路径。对话保留等价顶层 `short_memory` 合同；其余调用使用共享 `NPCContext.short_term_memory`。反思在 Godot 内仍可携带 NPC 上下文便于 Schema / 本地调试，但供应商实际请求只保留反思水位对应的全量 `day_events`，避免证据重复与 token 翻倍。

## T0105B 弥撒跨小时完成屏障

```text
hour_started 派发当前小时计划
  -> ActionSystem 判断 NPC 是否仍在主持 / 参加弥撒
     ├─ 否：沿用原计划切换规则
     └─ 是，且新计划不同：保持 active、工位和进度，登记 deferred

ActionSystem 弥撒自然完成
  -> 参礼者恢复独祷
  -> 已到时长的祈祷正常完成
  -> DailyPlanSystem 在同一 deferred 批次按既有依赖顺序
     执行此时的当前小时计划
```

参礼祈祷达到自身时长时只把进度停在上限，不在弥撒中完成或释放祈祷席。弥撒结束后的状态信号只负责唤醒计划屏障；延迟标记不写入事件、记忆或模型上下文。保护只由 `hour_started` 使用，对话、主动改派、建筑失效、昏迷等既有权威中断仍走原路径；普通行动的整点切换与完成策略不变。

## T0105A 弥撒正常结束与中断分流

```text
lead_mass 结束
  ├─ 自身 duration 到期
  │    -> ActionSystem 正常完成
  └─ 对话 / 改派 / 建筑失效等外部原因
       -> ActionSystem 中断

正常完成 -> prayer_resumed_alone.trigger=mass_completed
外部中断 -> prayer_resumed_alone.trigger=mass_leader_stopped
```

正常完成入口复用主持者的 `prayer_completed`、祭坛释放和参礼者恢复独祷逻辑，不由 DailyPlanSystem 伪造事件。T0105B 起，普通计划小时边界不再构造结束原因，而是等待弥撒自身完成；MemorySystem 仍只根据结构化 trigger 选择摘要，LLM 不参与。

## T0101 守备官知识边界数据流

```text
data/npc_initial_long_memory.json
  guard_officer.{role, arrival_at_station, past_before_station, pre_game_relationship}
  -> NPCSystem 初始化 knowledge_graph
     ├─ NPCPanel【知识】中文只读显示
     └─ LLMBridge long_memory / npc.long_term_memory
         -> dialogue / plan_day / plan_revision_judgement
         -> revise_plan / battle_judgement / daily_reflection
```

本任务不增加人物卡、endpoint、`call_type`、响应字段或权威状态。到站时间和开局前总体相处是初始长期认知；“过去未知”是明确知识边界，不是允许模型填空。对话专门限制守备官自我追问；熟睡反思把后来明确自述保存为单独、带“自称”语义的 NPC 主观关系，不能覆盖全局客观过去。

## T0100 宗教信仰人设投影

```text
data/npc_profiles.json.religion="天主教"
  -> NPCPromptProfile.build_setting(...)
     ├─ NPCPanel【背景】
     └─ dialogue.npc_setting
  -> LLMBridge._build_npc_context(...).identity
     -> plan_day / plan_revision_judgement / revise_plan
     -> battle_judgement / daily_reflection
  -> backend NPCIdentity.religion
```

`religion` 是精简、稳定的人物背景字段，不进入知识图谱，也不复制到 `station_context.resident_roster`；它不能替代个性、职业、记忆或实时程序事实。该变更不新增 endpoint、`call_type`、运行时状态或权威结算，正常调用频率不变。

## T0099 对话面板本地交互边界

```text
NPCPanel 记录
  -> MemorySystem.get_all_events()
  -> 只筛守备官—当前 NPC 已完成会话
  -> day / time / append sequence 排序
  -> 仅按 day 输出【第X天】

DialogPanel 可见输入
  ├─ Tab + 应征 toggle 可用
  │    -> 改变 button_pressed
  │    -> 既有 toggled handler
  │    -> DialogSystem.set_recruitment_request_pending(...)
  └─ 每次打开后的第一次攻击
       -> ConfirmationDialog
       ├─ 取消：无系统调用，保护保持
       └─ 确认：既有 DialogSystem.attack_target_npc(...)
            -> 成功后仅本次打开免重复确认
```

日期与攻击确认状态都是 UI 投影 / 防误触状态，不进入 MemorySystem、DialogSystem 会话 Schema 或存档。攻击伤害、惩戒事件、NPC 回复和计划判别仍由既有系统执行；应征快捷键不能绕过 toggle 的 visible / disabled 状态，也不修改 `session_had_recruitment_request` 的既有锁语义。

## T0098 祈祷内部模式状态机

```text
pray_at_chapel pending
  -> 真正抵达小教堂 + 占用祈祷席
  -> 读取当前有效 lead_mass
       ├─ 无主持者 -> prayer_mode=personal_prayer
       └─ 有主持者 -> prayer_mode=mass_attendance

active pray_at_chapel
  ├─ lead_mass 开始 -> 原地切到 mass_attendance
  ├─ 当前主持正常结束 / 异常退出
  │    ├─ 有替换主持者 -> 仅重绑定 provider_npc_id
  │    └─ 无替换主持者 -> 原地切回 personal_prayer
  └─ 祈祷自身时长结束 -> 正常完成 pray_at_chapel
```

模式转换只修改 active action 的 `prayer_mode / provider_npc_id`，不更换 action id，不释放 `chapel_prayer_seat`，不重置 `elapsed_seconds`，也不调用行动失败或计划重估。ActionSystem 写入 `prayer_joined_mass / prayer_resumed_alone`；MemorySystem 生成确定性摘要并按小教堂 `local_public` 广播。DailyPlanSystem 与 LLMBridge 不再包含教堂服务依赖、互斥或失败归一化分支。

## T0097 计划模型决策编译

```text
provider plan item
  -> hour + action_id
  -> 仅按所选行为读取必要选择
       ├─ visit_location                    -> location_id
       ├─ talk_to_npc / assist_heal         -> target_npc_id
       ├─ assist_repair / assist_upgrade    -> building_id
       └─ 固定 / 无目标行为                 -> 无额外选择
  -> 丢弃 action_kind / priority / target_id / 无关 selector / 任意 extra
  -> 用完整 allowed_actions 精确命中候选
  -> 编译内部 PlanItem
       {hour, action_id, action_kind, location_id, target_id,
        priority=50, reason, dialogue_goal}
  -> Flask 完整响应 Schema + 业务校验
  -> Godot 既有计划消费与 ActionSystem 权威执行
```

编译器位于 Model Adapter 的 provider 输出边界。它不会修改 Godot 请求、`PlanItem`、DailyPlanSystem 或 ActionSystem，也不会从无关字段猜目标。固定行为的地点与 kind 来自唯一合法候选，所以模型给 `pray_at_chapel` 多附一个 `target_id=chapel` 或错误地点不会破坏修订；需要目标的行为若专用选择为空或未命中白名单，则先编译为可校验的无效内部组合，再由 HTTP 业务层以 `location_id / target_npc_id / building_id` 对应错误拒绝。

Mock 先投影成同一最小模型决策，再经过同一编译器，避免开发路径绕过边界。修订的 `immediate_action` 继续从编译后的当前小时项确定性生成。模型原始多余字段仍保留在本地审计日志的 `provider_output_parsed` 证据中，但不会进入 Godot 响应或 `model_normalizations`；后者不再承担 action kind / 冗余地点修复。

## T0095/T0096 提交与反思水位数据流

```text
pending(action + target + options + movement_target)
  -> 暂停：NPC 移动冻结，ActionSystem 提交与 logical tick 返回
  -> 恢复：继续原 movement_target
  -> 抵达：NPCSystem 清 movement_target，写实际地点与 idle
  -> ActionSystem 统一提交闸门
       ├─ 地点 / NPC / 服务目标失效：一次结构化失败
       └─ 条件仍成立：申请工位并进入 active
```

移动停止清理与行动失败分开：对话目标 / 服务提供者失效时先使用 `emit_state_changed=false` 收束移动，随后由唯一结构化失败发状态变化，避免 DailyPlanSystem 抢到中间结果。ActionSystem 的逻辑 tick 也检查暂停，即使外部调试误发 tick 也不推进 active。

```text
21:00 summary_window 累计睡眠达标
  -> MemorySystem 原子短期快照（正文 + event_ids / witness_ids）
  -> reflection_period = 上次成功 end .. 本次请求快照时刻
  -> /npc/daily_reflection(summary_window, reflection_period, day_events)
  -> 长期记忆写入
  -> 只从当前短期索引移除本次快照 ID
  -> 保存本次 end，作为下次 start
```

窗口只管资格和归属，水位只管内容，触发时刻只管真实请求时间。请求在飞期间的新 ID 不属于旧快照，因此不会被旧回调清除；漏掉窗口不会推进水位。

## T0094 对话实况、历史投影与夜间总结数据流

```text
守备官第一条有效消息
  -> DialogSystem 在中断前读取 ActionSystem runtime snapshot + 当前计划
  -> interrupted_activity_context（目标私有、仅本会话）
  -> LLMBridge -> NPCDialogueRequest
  -> 对话 Prompt 按“被打断的活动 / 计划不变时暂定恢复”回答
  X 不进入 MemorySystem / EventRecord / 传播 / 长期记忆
```

对话完成仍只写既有 `dialogue_turn`。NPCPanel 的“记录”从 MemorySystem 全局 append-only 事件档案筛选目标 NPC 与守备官会话，按事件 `day / time` 排序；T0099 起只按日期分组，不再计算或显示历史波次标签。短期事件 / 见闻索引被熟睡总结清空后，已完成会话仍可查看；UI 不建立独立数据库。

```text
sleep_in_dormitory 的有效逻辑秒
  -> DailyReflectionSystem 解析 21:00 锚定窗口
  -> 同一 night_<anchor_day>_2100 跨多次睡眠累计
     ├─ 未满 3600 秒：保留 accumulated / remaining
     ├─ 达标但并发或旧请求占用：保持 eligible 可重试
     └─ 达标发起既有 /npc/daily_reflection
          -> 长期记忆成功应用 + 短期索引轮转
          -> completed_windows_by_npc 登记该窗口
```

T0095 起总结窗口及记录范围会进入后端 `DailyReflectionRequest`，帮助模型严格限制正文内容；日记按窗口锚点归档，实际触发日 / 时间独立保存。失败不消耗窗口也不推进内容水位，21:00 边界开启下一窗口。现有深度睡眠锁、最多 8 路并发、TimeSystem 慢速和明确模板降级来源不变。

固定地点行动开始前由 ActionSystem 同时校验 `current_location`、`movement_target` 和 `moving_to_*`；教堂再在 `_start_pray(...)` 做最终到达守卫。T0098 后弥撒开始只扫描 active 祈祷者并原地切换内部模式；pending 祈祷保持原移动与计划，到达后根据当时是否存在有效主持者选择模式。守备官已谈妥的当前参礼承诺仍可让对话计划链重排当前小时，但正式行为统一为 `pray_at_chapel`。

## T0092 双层 LLM 合同

```text
Godot 完整业务请求
  -> Flask 完整请求 Schema
  -> ModelAdapter provider projection
       ├─ 删除 meta / null / 同值副本 / 分支外字段
       └─ 保留人物、记忆、现场事实、白名单
  -> provider 最小 JSON 决定
  -> ModelAdapter deterministic hydration / T0097 plan compiler
       ├─ 固定响应 envelope 与派生布尔值
       └─ 按行为选择字段命中候选，补齐 action_kind / priority / location / internal target
  -> Flask 完整响应 Schema + 业务校验
  -> Godot 既有消费链
```

投影和补齐只在 `ModelAdapter` 的 provider 边界执行，不能代替 Flask / Godot 的业务校验。T0097 起计划项会先丢弃全部模型固定回声和无关字段，再只用行为对应的地点 / NPC / 建筑选择命中候选；真正的行动、必要目标或修订小时错误仍会被拒绝。Mock 也经过同一 hydration，以保证本地和真实 provider 的 Godot 响应形状一致。

## T0091 目标驱动对话计划数据流

```text
LLMBridge allowed_actions
  -> talk_to_npc {action_id, action_kind, target_id, target_kind, target_name}
  -> backend 发给 provider 时再次移除 location_id
  -> T0097 模型用 target_npc_id 选择 NPC
     └─ 其他地点 / 通用目标字段在编译边界直接丢弃
  -> DailyPlanSystem 只保存 target_npc_id
  -> ActionSystem 执行时查询目标实时地点并追踪
```

内部仍使用 action + target + location 的精确候选合同。T0097 只是把 provider 选择改为行为专用字段并由程序编译，不让模型决定寻路，也不放宽对话目标资格、自聊、内部 `action_kind=chat` 或 `dialogue_goal` 校验。

## T0087 对话响应按类型分派

```text
NPCDialogueRequest.dialogue_kind
  ├─ player_npc          -> PlayerNPCDialogueResponse
  ├─ npc_npc             -> NPCNPCDialogueResponse
  └─ escape_intervention -> EscapeInterventionDialogueResponse
                               -> 分支 Schema extra=forbid
                               -> 分支业务校验
                               -> Godot 对应唯一消费字段
```

请求合同保持统一，便于 LLMBridge 继续复用人物、记忆、地点和行动候选构造；响应合同在 HTTP 层按请求类型选择，模型不能再把邀请、应征、战时和逃离字段混装进一个对象。应征权威只消费 `recruitment_result`，NPC-NPC 生命周期只消费 `invitation_result / should_end_dialogue`，逃离权威只消费 `escape_intervention_result=stay|leave`。通用 `intent` 已删除；分支外字段和旧失效意图均在进入 Godot 前以 `model_output_invalid` 拒绝。

供应商偶发把 `emotion / suggested_event_type / debug_reason` 返回为 `null` 时，HTTP 层只对这些非权威元数据替换 Schema 默认值，并把路径、原值、目标值和来源写入 `model_normalizations`。这不会改变 `recruitment_result / invitation_result / should_end_dialogue / wartime_reaction / escape_intervention_result`，也不会触发 Mock fallback。

## T0085 计划工作量软约束与目标失效数据流

```text
BuildingSystem 完成 upgrade / repair
  -> 释放协助者并清空 last_action_failure_context
  -> 下个计划小时仍命中旧 assist_upgrade
     -> DailyPlanSystem 查询实时作业状态
        -> 生成 no_active_upgrade / target_resolved_or_inactive
        -> /npc/plan_revision_judgement 选择受影响小时
        -> /npc/revise_plan 返回新合法行动
           -> 只校验精确小时、白名单、目标/地点、即时行动等硬合同
           -> 合并并立即/延迟可靠派发
```

`minimum_work_phase_count` 等字段为兼容 Schema 与 Prompt 规划上下文继续保留，但 backend 和 Godot 不再据此拒绝响应。`assist_upgrade` 的工作计数与 `location_id=plaza` 在 LLMBridge、DailyPlanSystem 和 backend 之间一致，避免历史计划计数失真或把室外协助重新投影进封闭建筑。

## T0084 固定床位分配数据流

```text
building_defs.json.workstations[].assigned_npc_id
  -> BuildingSystem 规范化位置配置
     -> claim_workstation(dormitory, npc, dormitory_bed)
        ├─ NPC 有固定床：只检查并申请自己的位置
        └─ NPC 无固定床：跳过全部专属位置，只申请未分配床
           -> ActionSystem 保存 workstation_id
              -> 完成 / 中断 / 封闭时只释放 occupied_by

BuildingSystem.get_building(dormitory)
  -> BuildingPanel 只读显示实时“空闲 / XX占用中”，不暴露固定归属
```

归属是建筑配置事实，`occupied_by` 是运行时使用事实，两者不能混用。ActionSystem 不维护第二份 NPC—床位表，UI 不参与分配；LLM 仍只选择“睡觉”行动，不接收床位编号选择权。

## T0083 应征结果的前端投影

后端玩家对话 `PlayerNPCDialogueResponse.recruitment_result` 由 T0087 保留并成为应征唯一结构化结果。Godot 业务层完成既有上下文校验和权威入伍应用后，把有效 `accept / reject` 作为可选元数据写入对应 NPC history turn；UI 按元数据渲染结果，MemorySystem 只读取 turn 的真实文本生成摘要。该分层避免通过会话级 `last_recruitment_result` 给旧回复补错结果，也避免把 UI 文案伪装成模型发言。

## T0081 持续生活消耗与成长数据流

```text
TimeSystem.logical_time_tick(effective_game_seconds)
  -> NPCNeedsSystem
       -> NPCSystem 状态 / behavior_mode
       -> ActionSystem active / external_active 快照
       -> BuildingSystem 修复 / 升级剩余时间
       -> activity_needs.json 唯一速率档位
       -> NPCSystem.update_npc_state(satiety, fatigue)
       -> ActionSystem.advance_timed_action_experience(...)
            -> NPCSystem.increase_npc_skill(...)
            -> MemorySystem.skill_improved
```

`data/action_defs.json` 的每条配置行为只保存 `needs_profile` 引用，不再携带饱食 / 疲劳总量或每小时重复字段；`data/activity_needs.json` 是速率、边界、行为模式映射和动态默认档位的唯一数值源。NPCNeedsSystem 在 tick 开头结算，因此有限 active 行动可用 `duration - elapsed` 截断；建筑协助用 `remaining / speed_multiplier` 截断；治疗协助用复苏前理论秒数截断。剩余时间按 idle 结算，切换档位时保留未满 1 点的小数，钳制到边界时丢弃继续越界方向的余量。

ActionSystem 仍独占行动生命周期、食物恢复、工位 / 资源和成长事件；NPCNeedsSystem 不产出资源、完成行动、恢复 HP 或决定经验技能。BuildingSystem / NPCSystem 只提供有效时间事实，不复制经验计时器。工作 / 训练的既有完成 / 有效时长成长保持原入口，三类 assist 使用 `timed_experience` 配置补齐工程 / 医术成长；非工作行动没有该配置。

## T0080 建筑门口失败与升级协助数据流

```text
BuildingSystem.upgrade_building()
  -> building_state_changed(condition=upgrading)
     ├─ ActionSystem active 依赖行动
     │    -> 立即释放位置 / 周期 -> 清退广场
     │    -> *_failed_building_upgrading(interrupted_phase=active)
     └─ ActionSystem pending 依赖行动
          -> 保留 pending 与移动目标，不产生失败
          -> NPCSystem 抵达建筑入口后查询 BuildingSystem availability
             -> 不可进入：收束到广场并发 npc_building_entry_failed
                -> ActionSystem 清除 pending
                -> *_failed_building_upgrading(
                     interrupted_phase=pending,
                     arrival_check_failed=true
                   )
                -> DailyPlanSystem T0050 判别 -> 按需精确修订

BuildingSystem 当前升级作业
  -> LLMBridge allowed_actions.assist_upgrade
     -> plaza / requires_building_entry=false / counts_as_work_phase=true
     -> DailyPlanSystem + backend 工作阶段统计（Prompt 建议）
     -> LLM 只能选择候选；ActionSystem / BuildingSystem 权威执行与结算
```

`npc_building_entry_failed` 只表达 NPC 已经到达入口且程序拒绝进入的观察事实，不替代 BuildingSystem 可用性判断，也不直接调用 LLM。NPCSystem 先写最终室外地点，再发信号；ActionSystem 拥有 pending 行动和结构化失败，DailyPlanSystem 仍从唯一最终失败启动既有两层链。没有 pending 行动所有权的普通访客只被收束到广场，不伪造计划失败。

LLMBridge 的 `current_building_states.is_upgrading / is_repairing` 必须调用 BuildingSystem 实时查询，不能读取 `get_building()` 中不存在的便利布尔字段。`assist_upgrade.target_id` 仍是被协助建筑，`location_id / execution_location` 才是实际执行地点；Godot 与后端 Prompt 统计使用同一行动语义，但工作量不作为接受门槛。

## T0078 NPC 主动交涉完成数据流

```text
当前计划 seek_guard_officer
  -> NPCSystem 生成问号并由 NPC 发起 player_npc 会话
     -> DialogPanel：取消 disabled + 专用 tooltip
     -> DialogSystem：取消接口权威拒绝
        ├─ 完成
        └─ 挂起满 2 小时 -> 按完成收口
           -> DailyPlanSystem 核对结束时当前计划仍为 seek_guard_officer
              -> judgement.required_revision_hours=[当前小时]
                 -> 后端保留模型选择的额外小时，并权威并入任何遗漏 required 小时
                    -> selected-hours revise_plan（普通动态 allowed_actions）
                       -> T0076 当前小时立即 / deferred 派发
```

`required_revision_hours` 是程序已经确认的范围事实，不是模型建议。后端只归并小时并记录 `model_normalizations`，不替模型选择行动、地点或目标；正式修订、Godot 合并和 ActionSystem 执行校验仍保持原权威边界。守备官发起会话与结束时已不再执行 `seek_guard_officer` 的会话不获得该强制范围。

## T0076 对话延续与当前小时派发数据流

```text
DailyPlanSystem 派发 talk_to_npc（保存来源日/小时/版本/计划项）
  -> ActionSystem pending：接近 / 等待目标计划
     -> 普通 hour_started
        -> ActionSystem 保留 pending 与预约
        -> DailyPlanSystem 为发起者登记 carryover barrier
        -> 跳过新小时计划，不中断移动
     -> DialogSystem invitation / active（继承计划来源）
        -> 普通 hour_started：邀请保留发起者；正式会话保留双方
        -> 对话结束：双方进入同一 resolution group
           ├─ 发起者 judgement.required_revision_hours=[当前小时]
           │    -> selected-hours revise_plan -> normal allowed_actions
           └─ 受邀者普通独立 judgement -> 按需 revise_plan
        -> 全组终态
           -> current-hour deferred marker
           -> 依赖排序派发结束时当前计划

任意 revise_plan 修改当前小时
  -> 合并并写 current-hour dispatch marker
     ├─ 当前可执行：立即正常派发，成功后消费 marker
     ├─ 对话 / 行为模式阻塞：保留 marker，状态解除后派发
     └─ 派发失败：保留 marker，并由权威失败链产生唯一后继修订
```

后端 `PlanRevisionJudgementRequest.required_revision_hours` 是范围下限，不是行动选择。Pydantic 校验排序 / 时效，endpoint 校验响应包含全部 required 小时，ModelAdapter Prompt / 紧凑重试 / Mock 共用同一合同；`PlanRevisionResponse` 的精确选时、即时行动一致性与候选校验不变。

## T0075 配置化完成策略数据流

```text
data/action_defs.json.completion_policy
  -> ActionSystem.initialize() 校验 / 建立行为目录
     -> DailyPlanSystem 派发当前计划项
        ├─ active 与新小时 action + 必要 target 相同
        │    -> 采用既有 runtime，保留进度
        ├─ 新小时计划不同
        │    -> interrupt_npc_action -> 正常派发新项
        ├─ repeat_while_planned 成功 completed
        │    -> deferred -> 再读当前计划 -> 清除本阶段签名
        │       -> 正常派发 / 重新校验下一周期
        └─ once_per_plan_hour 已消费
             -> 日期 + 小时 + 逻辑计划项去重（不含 plan_version）
             -> 不重复派发
```

普通 `(day, hour, plan_version, action, target, dialogue_goal)` 签名仍负责同一计划版本的幂等派发；生产成功回调只有在配置策略与当前逻辑计划项都匹配时才可受控清除签名。每小时单次记录独立于计划版本，避免同小时修订后重复吃饭 / 饮酒。续开通过 deferred 调用发生，使 ActionSystem 先完成旧周期结算和 `work_completed` 记录，再产生下一周期 `work_started`；重新派发失败继续进入原有结构化失败与计划修改判别，没有新建资源或制造结算路径。

## T0073 指令发布到计划变化的数据流

```text
OrderPanel 发布自由文本
  -> NPCSystem.publish_npc_order(...)
     -> current_order + private order_assigned
     -> npc_plan_reevaluation_requested(reason=order_changed)
        -> DailyPlanSystem 当前小时 selected_hours 修订
           -> LLMBridge /npc/revise_plan（包含最新 current_order）
              -> 后端 Schema / Prompt / 白名单校验
                 -> 合并回权威 24 小时计划
```

UI 叙事文字只表达成员会“尽量遵循”，不改变上述权威边界。指令发布不会直接调用 ActionSystem；只有真实 provider 返回、通过精确小时集合与行动白名单校验的修订才会改变 DailyPlanSystem 计划。T0073 的确定性专项锁定 payload 注入和合并边界，真实专项确认 `order_changed` 可把当前计划从空闲改为前往指定地点。

## T0071 NPC-NPC 对话私有上下文边界

```text
回复者 NPC 自身
  -> npc_setting / npc_state / short_memory / long_memory
     / location_context / current_order / target_npc

说话者 NPC
  -> speaker_name + speaker_text
     + speaker_context{speaker_id,name,kind,appearance,health_status,state={}}
  -X-> speaker_npc / private NPCContext
```

`LLMBridge.build_npc_dialogue_payload(...)` 是正式对话 payload 的唯一构造点，不再调用 `_build_npc_context(...)` 构造说话者。后端 `NPCDialogueRequest.speaker_npc` 只接受 `null`，`SpeakerContext.state` 必须为空；因此旧客户端、手工请求或未来重构不能把说话者的短期 / 长期记忆、`current_order`、地点上下文、技能 / 属性或个人资源重新混入回复者请求。模型只能从回复者自己的信息空间、对方已说出的文本和可观察外表 / 健康作答。

其余五类正式请求继续各自携带唯一目标 NPCContext，没有第二名 NPCContext。`talk_to_npc` 候选只提供目标 id / 名称，不再投影目标当前地点、行动或入伍状态；ActionSystem 在计划真正执行时读取目标权威地点并追踪移动。其他 `allowed_actions` 仍承担程序合法性与路由约束，但 Prompt 明确其元数据不自动转化为目标 NPC 见闻。

## T0070 全员名册与仓库容量数据流

```text
NPCSystem 全部登记实体
  -> LLMBridge._build_station_context(...)
     -> resident_roster[{npc_id,name,identity,recruited,in_station}]
        -> 六类请求 / Pydantic StationResidentContext / Prompt

data/resource_defs.json.warehouse_capacity
  + BuildingSystem.warehouse.level
     -> ResourceSystem 容量 / 剩余量 / 原子入库
        ├─ ActionSystem 工作产出预检
        ├─ MerchantSystem 购买预检
        ├─ BuildingPanel 仓库上限行
        └─ HUD 资源悬停提示
```

名册标签和容量均由 Godot 权威状态投影，后端与 LLM 只读。没有 `warehouse_capacity` 的资源视为无限，而不是容量 0；配置为受限的六项资源在批量入库前整体校验，失败时不得先扣输入。UI 不缓存或计算容量，始终调用 ResourceSystem。仓库受击资源损失尚未接入这条数据流。

## T0077 每日人民币硬预算与 provider 尝试账本

```text
ModelAdapter.generate(...)
  -> 进程内累计预算检查
  -> LLMCostLedger.reserve(audit_id:attempt)
     -> 重放 Asia/Shanghai 当日 provider_usage
     -> 已用 + 全部在途预留 + 本次 ¥1.77 <= ¥20
  -> provider HTTP
     -> 读取 prompt_cache_hit/miss + completion usage
     -> LLMCostLedger.settle(...) 释放预留并追加 JSONL
     -> audit provider_response_received 同步保存 billing
  -> /debug/llm_usage
     -> session（当前 ModelAdapter 进程）
     -> daily（从持久化账本重放）
     -> GMPanel 异步顶栏
```

DeepSeek V4 Flash 默认人民币价为缓存命中输入 ¥0.02/M、缓存未命中输入 ¥1/M、输出 ¥2/M。单次预留 ¥1.77 覆盖官方 1M 上下文与 384K 最大输出的缓存未命中理论上界；预留只占用在途额度，拿到真实 usage 后释放未用部分。每个 HTTP 尝试独立结算，所以非法 JSON / 截断后的紧凑重试不会漏算。价格、预留、上限、时区和账本路径均由后端环境配置；配置价格缺失、账本不可读写或预留会越过上限时失败关闭并返回 `budget_exceeded`，不进入 Mock。

JSONL 是跨后端重启的当日费用事实源；`ModelAdapter._usage_records` 继续表达业务调用最终结果，两者不得相加。当前 Flask 部署复用单个 ModelAdapter，进程内锁覆盖 Godot 的并发请求；未来若改为多 worker，必须把预留和追加迁移到支持跨进程原子事务的集中存储后才可继续宣称全局硬预算。

## T0069 LLM 调用持久化审计

`ModelAdapter.generate(...)` 为每次调用创建唯一 `audit_id`，`LLMCallAuditLogger` 以 append-only JSONL 写入同一调用的生命周期事件。正式 provider 在 `_send_chat_completion(...)` 生成请求体后、加入 Authorization 请求头前记录完整 `messages / temperature / thinking / response_format`；流式 SSE 仍由现有传输层聚合，审计保存聚合后的供应商响应和原始模型 `content`，不保存逐个 SSE 网络分块。

```text
call_started(input_payload)
  -> provider_request_sent(attempt, full body, no headers)
     -> provider_response_received(http_status, aggregated response)
        -> provider_output_parsed | provider_output_rejected
  -> call_completed(content, usage, error/fallback)
     -> business_validation_failed (optional, same audit_id)
```

`record_model_output_invalid(...)` 继续原地修改内存 usage，避免调用 / token 双计，同时通过 usage timestamp 找回原 `audit_id` 并追加不可变的业务校验失败事件。日志写盘按解析后的绝对路径使用进程内共享锁，每个事件一次性追加一行；目录创建或写入失败只更新 `audit_log.last_error / last_error_timestamp`，不改变模型业务结果。多进程服务器仍依赖操作系统 append 语义，部署阶段若启用多个 worker，应为各 worker 配置独立文件或接入集中日志收集器。

日志正文保存前递归处理敏感 key、JSON 字符串中的凭据字段、Bearer / `sk-...` 格式和当前配置 API Key。供应商请求头从不传入日志器。`get_runtime_config_snapshot()` 只公开启用状态、JSONL 版本、显示路径、正文开关与最近错误；HTTP / GM 不提供日志下载，避免把人物私密上下文扩散到客户端。

## T0067 LLM 判定复验与原子逃离边界

```text
Godot 权威 NPC / 战场状态
  -> LLMBridge NPCContext
     -> Pydantic NPCStateContext（保留五个模式 / 心理 / 逃离字段）
        -> real provider
           -> Schema + dialogue / battle business validation
              -> Godot apply-time stale validation
                 -> CombatSystem 权威结果

CombatSystem.start_npc_escape(...)
  -> NPCSystem.set_npc_behavior_mode_and_move_to_world_position(...)
     ├─ preflight：NPC、世界节点、移动能力、目标
     ├─ interrupt：行动、对话、LLM、旧移动
     └─ 单次提交：behavior_mode + state_changes + 新移动
  -> 成功后才写 escape_started / active_escapes / escape_intent
```

这条链把“模型意向”“业务可接受”“当前仍有效”“程序已成功提交”分为四层。后端不决定 HP、战斗资格、移动或事件；Godot 也不会把迟到或业务越界的结构化 JSON 当作权威事实。低血量 pending 除 request id 外绑定 `wave_id + started_event_id`，防止同一波编号的新战斗误收旧回复。

DialogSystem 在完成会话并应用暂存战时反应时设置结束中标记。逃离模式切换再次尝试强制结束同一会话，只会得到幂等的 `dialogue_end_in_progress`，不会重复提交对话事件或递归调用。复苏续逃失败不再留下“活动逃离但没有移动”的半状态。

ModelAdapter 在供应商完成生成时先取得真实 token 与 finish 元数据；若随后 HTTP 业务层判定输出无效，`record_model_output_invalid(...)` 会优先用上游 usage timestamp，并结合非空 request id、call type 和 NPC，找到精确的成功 usage 后原地替换为 `SchemaValidationError` 失败记录。这样一次上游请求只消耗一次调用 / token / 预算，重复报告幂等，同时保留真实失败原因；只有找不到对应上游记录时才追加独立失败记录。

## T0063 个人酒转移、行动与 LLM 投影

```text
ResourceSystem.wine
  -> NPCSystem.give_wine_to_npc(...)
     -> npc.states.wine
        -> ActionSystem.get_action_eligibility(...)
        -> spend_npc_owned_resources({wine: 1})
           -> MemorySystem.wine_consumed
              -> 六类后续 NPC 上下文

data/action_defs.json: drink_wine
  -> ActionSystem
     ├─ DailyPlan / dialogue allowed_actions（本人有酒时）
     └─ LLMBridge.station_context.work_mode_actions + description（完整背景目录）
```

NPCSystem 是个人金钱 / 酒持有量和扣减的唯一权威，ResourceSystem 继续只保存驿站库存。LLMBridge 把目标个人 `money / wine` 投影进 NPC 状态，把完整行动说明投影进共享背景目录；后端只校验计划白名单、kind 和可安排数量，不执行扣减。事件上下文承载非数值心理影响，不新增情绪状态或记忆删除路径。本任务不新增 endpoint、call_type、Autoload 或模型调用。

## T0061 人设投影与知识展示边界

```text
data/npc_profiles.json（无 signature_lines；含精简 religion 与宽松 speech_style）
  -> NPCPromptProfile.build_setting(...)
     -> dialogue.npc_setting
     -> LLMBridge._build_npc_context(...).identity
     -> NPCPanel【背景】

data/npc_initial_long_memory.json
  -> NPCSystem 完整运行态（保留 value/confidence/day/time）
     ├─ LLMBridge 六类正式上下文（完整长期记忆）
     ├─ GM 原始调试（完整记录）
     └─ NPCPanel._format_knowledge_graph_block(...)
          -> 仅 subject_label / relation_label / value_label
```

`signature_lines` 已从档案、共享构造器、Pydantic `NPCIdentity` 和六类正式 Prompt 移除；不保留兼容镜像。T0100 后身份另含精简 `religion`，人物声音仍只由宽松 `speech_style`、其余根本人设、长期记忆与当前事实共同形成。三篇初始日记的数据结构和投影路径不变：前两篇内容分别承担宏观身世 / 来站原因 / 到站时间与接手工作 / 相遇群像，八人按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜互相补全；“近日”仍是原有微观片段。

T0061 当时守备官种子图谱只保留一条 `role` 职责关系；T0101 已在同一主体新增三年前到站、来站前经历未知和开局前尽责和睦三条关系。建筑知识主要改写中文 `relation_label / value_label` 的叙事表达；独立机械审校同时把仓库旧的“容量 / 受击丢货 / 减少掠夺”技术值收为当前运行态真实存在的“集中登记 / 正门失守后的受袭次序”，其余技术 `value` 不变。`confidence / day / time` 与替换式更新结构完整保留。NPCPanel 隐藏可信度与更新时间是纯展示过滤，不改变 NPCSystem、后端、存档或 GM 可观察数据。本任务不新增 endpoint、`call_type`、调用频率、场景节点或权威结算。

## T0060 内容重写与日记投影边界

```text
8 字段运行态日记
  -> LLMBridge._build_existing_diary_entries(...)（唯一投影点）
     -> day=0：“往昔·…：正文”
     -> 新熟睡总结：“接到守备命令的第N天 HH:MM:SS：正文”
     -> 无 record_label 的旧 day>0 记录：“第N天 HH:MM:SS：正文”
     -> 旧纯字符串 / 缺日期或时间元数据：兼容保留可读内容
  -> 六类既有 LLM 请求的 list[str]
```

本任务只重写人物档案、初始长期记忆内容并补足 Prompt 的文风与时间解释。首次睡眠反思仍只返回正文，Godot 继续负责权威 day / time 元数据和下一次上下文前缀。后端 Schema、endpoint、`call_type`、权威状态与结算边界均不变；15 座建筑认识仍属于人物叙事化常识，不成为第二套建筑规则源。

## T0059 初始长期记忆数据流

```text
data/npc_profiles.json（根本人设 + 权威初始状态 + 空记忆占位）
data/npc_initial_long_memory.json（3 篇历史日记 + key_value_replace_v1 图谱）
  -> NPCSystem.initialize()
     -> 校验两份数据的 NPC id 完全一致、日记 / 图谱 / 关系有效
     -> 深拷贝到 8 名 NPC 运行态后再生成实体
        -> NPCPanel / GM long_memory 只读同一运行态
        -> LLMBridge
           -> dialogue.long_memory（唯一目标长期记忆）
           -> npc.long_term_memory（计划 / 判别 / 修订 / 战时心理 / 反思）
        -> DailyReflectionSystem
           -> 日记追加
           -> subject + relation 知识替换
```

基础档案、种子历史和运行时更新各有单一职责：`background_story` 是稳定系统人设；独立 JSON 是开局前可被后续认知演化覆盖的历史；运行态才接收当天反思。初始数据缺失、出现未知 id、空日记、错误 schema 或空关系时，NPCSystem 中止本轮 NPC 初始化并报告具体原因，不静默回到空长期记忆。

`LLMBridge._build_long_memory_context(...)` 是长期记忆投影的唯一构造器。`NPCContext.knowledge_graph` 仅为旧夹具兼容字段，当前 Godot 正式 payload 不再填充；对话 target / speaker 参与者上下文通过 `include_long_term_memory=false` 省去重复并维持 NPC 私人记忆边界。该优化不改变反思写入、UI 展示或任何程序权威结算。

## T0058 公开基础资源与升级常识数据流

```text
ResourceSystem 当前运行态
  -> LLMBridge 白名单 grain / meal / wood / stone / iron
     -> station_context.basic_resource_reserves（六类 NPC LLM 请求）
     -> current_resource_states（计划 / 判别 / 修订兼容字段，同一五项）

data/station_context.json 第六条规则
  -> “升级缓慢推进，可协助加快”
  -> 六份 Prompt
  -> 仅在 allowed_actions 存在动态 assist_upgrade 目标时允许选择
```

LLMBridge 是公开资源投影的唯一组装点；不得把 `ResourceSystem.get_resource_snapshot()` 全量暴露给模型。`StationSceneContext` 要求五项资源按稳定顺序各出现一次，后端拒绝其他资源 id。资源数量只读且每次请求重新读取，不写入记忆事件，也不授权模型扣除或增加资源。升级规则只解释既有 BuildingSystem / ActionSystem 事实；升级作业、倒计时、协助加速和完成仍由程序权威结算。

## T0057 建筑升级导致行动失败的数据流（pending 时序由 T0080 修正）

```text
BuildingSystem.upgrade_building()
  -> building_state_changed(condition=upgrading)
  -> ActionSystem 识别真正指向该建筑的 pending / active 行动
     -> pending：保留前往建筑的移动，到入口被拒后才清理待执行动作
     -> active：释放位置 / 周期并将建筑内 NPC 收束到广场
     -> 写 <action_id>_failed_building_upgrading + 权威失败上下文
  -> DailyPlanSystem 规范为 target_unavailable
  -> T0050 action_failure 判别
  -> revision_hours 非空时进入精确阶段修订
```

升级封闭只把真正依赖目标建筑的 pending / active 行动记为失败；active 在状态变化时立即失败，pending 必须等 NPCSystem 在入口重查可进入性后失败。单纯停留者会被清退；没有行动所有权的普通访客到门口被拒时也不会伪造行动失败。ActionSystem 必须在 NPCSystem 完成门口位置收束后一次性写最终 `failed` 状态，避免同步 `npc_state_changed` 用无上下文中间结果抢占失败去重。失败上下文包含 action / building、`condition=upgrading`、`failure_reason=building_upgrading`、pending / active 阶段和中文摘要；LLM 只判断受影响小时及合法替代行动，不决定升级、封闭、移动、位置或失败事实。

## T0055 周期规则的数据边界

新增常识只修改 `data/station_context.json.station_rules` 和六份 Prompt 解释，不新增 Schema 字段或 Godot 结算代码。LLMBridge 仍原样把配置规则注入六类请求；ActionSystem、CraftingSystem、HorseSystem、BuildingSystem、ResourceSystem 等继续各自决定有效参与、周期推进、部分进度与最终结算。LLM 不获得周期计时或资源写权限。

## T0054 驿站常识数据流

```text
data/station_context.json ── 精简简介 / 世界内规则 ┐
NPCSystem ── 全体登记成员及 recruited / in_station     │
BuildingSystem ── 已加载全部建筑                      ├─> LLMBridge._build_station_context(...)
ActionSystem ── 可计划行为定义 + 特殊逃离意向          │
                                                       └─> 六类请求顶层 station_context
                                                            └─> Pydantic StationSceneContext
```

静态叙事规则只在 `data/station_context.json` 维护；人员、建筑和行为类型不复制成 Prompt 专用数据。T0058 后 `StationSceneContext` 要求 `setting_summary / resident_roster / building_roster / work_mode_actions / basic_resource_reserves / station_rules` 全部存在且列表非空。Godot 在每次构建 payload 时读取运行态：离站者立即从人员目录消失；建筑目录保持已配置身份完整，即使某座建筑当前受损 / 摧毁；行为目录包含工作模式可计划类型而不展开每个动态 NPC 目标；基础资源严格只投影五项。

该目录是世界知识层，不是决策授权层。`allowed_actions / allowed_decisions`、`current_building_states / current_resource_states`、NPC state、战场上下文和各系统校验继续负责当前事实与合法性。后端 Schema 和 Prompt 都不得依据背景规则替代权威结算。GM 只读入口调用 LLMBridge 的 debug 快照，不建立第二套组装或结算逻辑。

## T0053/T0076 计划对话延续、失效与共享人物上下文数据流

```text
DailyPlanSystem dispatch talk_to_npc
  -> ActionSystem pending(plan day/hour/version + assigned_plan_item + target)
  -> target llm_activity(kind=plan): keep reservations and wait
  -> logical tick / target-plan retry / hour_started pre-dispatch validation
       ├─ same-day old hour -> keep wait/invite/session + rebuild dispatch marker
       ├─ same-hour item still talks to same target -> continue wait/invite
       └─ same-hour replacement / cross-day / authoritative invalidation
            -> release + stop approach
            -> last_action_result=talk_to_npc_failed_plan_superseded
            -> context(old item + current item + old/current time/version)
            -> DailyPlanSystem T0050 judgement -> optional selected-hours revision
```

ActionSystem 只对带 `plan_action_source=daily_plan` 的 pending 对话应用日计划延续 / 替代规则，避免 GM / 测试直接交谈冒充跨小时日计划。普通同日整点时，DailyPlanSystem 为 pending、邀请中和正式会话重建 carryover marker，暂缓当前小时计划；对话自然结束并完成双方判别 / 必要修订后再派发当前项。真正失效时，移动停止可能同步发出状态信号，因此先用非失败 cleanup reason 停止，再一次性写入最终结构化失败；否则第一条无上下文失败会被 DailyPlanSystem 去重并吞掉真正上下文。DailyPlanSystem 收到失败时优先使用 `failure_context.failed_plan_item`，不能用当前项替代旧失败项。

`LLMBridge._build_npc_context(...)` 是 plan_day、plan_revision_judgement、revise_plan 和 battle_judgement 的共享人物入口，包含 identity、state、current_order、short_term_memory、`long_term_memory={knowledge_graph, diary}`、location / plaza context。范围判别请求也继承 StationAwareNPCRequest 并读取候选、建筑和资源状态；两层之间完整传递失败项 / 类型 / 摘要 / 上下文。判别仍只输出小时，修订仍只输出合法计划，战时心理仍只输出允许的意向。

## T0052 计划—对话互斥数据流

```text
LLMBridge plan request -> NPCSystem.llm_activity(kind=plan)
  ├─ NPCPanel: dialogue disabled + “NPC正在思考”
  ├─ DialogSystem player entry: npc_planning（不 cancel、不推进 epoch）
  └─ ActionSystem NPC talk: approach -> pending(waiting_for_target_plan)
       -> 保留 speaker/target reservation

plan activity terminal -> npc_state_changed -> deferred retry
  -> 重验地点 / 行动能力 / behavior_mode / 阻塞状态
  -> DialogSystem.start_autonomous_npc_dialogue -> 原邀请 LLM 流程
```

计划活动不能直接并入 `NPCSystem.is_npc_dialogue_blocked(...)`：后者表示深睡 / 战时等应立即拒绝并清理的不可打断状态，而计划活动对玩家是拒绝、对已有 NPC 对话行动是可等待。ActionSystem 因此在启动成功前持续拥有 pending action 和预约；只有邀请请求真正接受启动后才释放，`npc_planning` 竞态也回到等待而不是失败。即时计划修订候选使用当前可执行过滤，正式日计划候选允许并行计划目标，避免引入新的失败 / 重试 LLM 调用。

## T0051 守备官会话提交与挂起数据流

```text
DialogPanel.send
  -> DialogSystem 立即 append 守备官 history turn
  -> dialogue_updated（UI 先显示）
  -> LLMBridge async /npc/dialogue
  -> 回复仅 append NPC turn，并暂存 recruitment / wartime / escape branch result

完成：cancel pending reply -> MemorySystem 单次提交整场 dialogue_turn
     -> 应用暂存的程序权威结果 -> T0049/T0050 计划修改判别
取消：cancel pending reply -> 不提交事件 / 不应用暂存结果 -> 恢复合法原行动
挂起：ui_visible=false + NPC 会话锁 + 7200 逻辑秒
     -> 恢复窗口，或超时走取消（含攻击则走完成）
```

客户端取消只使对应 request id / dialogue id 失效；后端即使已经返回，迟到结果也不得再改变历史、事件或 NPC 状态。攻击伤害先由 NPCSystem 权威落地，与会话暂存事务分离。玩家会话事件采用“完成时整场一次提交”，NPC-NPC 则继续采用“每轮成功即提交”，两者不能混用。

## T0046 请求场景、反思 Schema 与公告牌数据流

`backend/schemas/npc_ai.py` 使用 `StationAwareNPCRequest` 为所有携带 NPC 人设的请求提供一份顶层必填 `station_context`；`NPCContext` 本身不嵌套该字段。T0046 先建立动态在站人员基础，T0054 再扩充完整建筑、工作模式行为与世界内规则。`DailyReflectionResponse` 仅含 `diary_entry` 与 `knowledge_graph_updates`，知识 patch 可同时保存技术 `subject / relation / value` 和中文 `subject_label / relation_label / value_label`；不再有 `memory_summary`。

公告牌 UI 只管理草稿。发布后由 `MemorySystem` 校验并权威更新广场 `current_notice / reference_schedule / schedule_advisory_note`。T0065 起，`plaza_notice_changed / plaza_schedule_changed` 是公告牌专用全站广播：发生实际变化的页面各生成一条事件，由 `_broadcast_public_event(...)` 按事件类型选择全部在站 NPC，再通过既有接收资格过滤昏迷、睡觉与离站者；其他 `local_public` 事件仍按地点在场范围转发。广场 `location_entry_snapshot` 在写入见闻前剔除公告牌三项，权威广场快照本身仍保留它们供 UI / GM / 只读系统查询。初始内容来自 `data/notice_board_defaults.json` 并预写初始在站 NPC 见闻；逃离完成时 NPCSystem 调用 MemorySystem 将该 NPC 从全部地点人员节点移除，接收资格也再次过滤离站状态。UI 不直接写见闻或广场事实。

## T0043A 服务提供者—承载者运行时闭环

`data/action_defs.json` 用 `required_active_action_id`、`blocked_by_active_action_id`、`interrupts_action_ids` 与 `complete_with_required_action` 声明诊所 / 训练等依赖和互斥。Godot `ActionSystem` 是唯一生命周期权威：验证服务者的行动、地点、建筑可用性及实际位置占用；协调 pending；开始 / 释放位置；在服务者停止时同步失败依赖者。T0098 后教堂不再使用这些依赖字段：弥撒只改变同一祈祷行动的内部模式。`DailyPlanSystem` 只负责同批派发顺序和接收真实结构化失败，`LLMBridge` 只把仍有效的约束投影为候选上下文。

依赖检查不用姓名、职业或固定 NPC id：诊所 / 训练依有效 provider action 及对应工位占用，主持资格另由 action 的 `required_ability` 校验。这样升级新增多个服务位置后，人数和技能团队效率、零服务者失败规则仍沿用同一实现。

## T0043 建筑位置、效率与封闭数据流

```text
data/building_defs.json
  -> BuildingSystem（位置清单/占用、可进入性、升级、HP 与实际效率权威）
  -> ActionSystem（资格校验、同类空位自动分配、多人诊疗/训练、失败与中断）
  -> NPCSystem（进入前/到达时复验，封闭时退出到广场）
  -> MemorySystem（外部效率分档 + 室内逐位置快照/差量）
  -> BuildingPanel（只读逐位置与精确效率展示）

ActionSystem + BuildingSystem
  -> LLMBridge.allowed_actions.context
     (eligible / available_now / unavailable_reason / required_ability)
  -> DailyPlanSystem 在真实失败后重评估
```

位置数量、名称、类型、固定归属和占用只由 `BuildingSystem` 的建筑状态决定。NPC 只选择行动与建筑，`ActionSystem` 调用 `claim_workstation(...)` 取得合法位置：普通位置使用同类型第一个空位，宿舍床位按 T0084 使用 NPC 自己的固定床或未分配床；无合法位置、升级封闭或建筑摧毁均返回结构化失败。诊所和训练场分别聚合全部在岗医生 / 教官的数量与技能，不建立 UI 或 LLM 决定的一对一配对。

升级的成本、时长、Max HP、位置增量与活动效率增量都来自 `upgrade.level_effects`；固定位置类型拒绝扩容。施工开始后建筑不可进入：室内 active 依赖行动立即以建筑升级失败、释放位置并进入 T0050；路上 pending 继续到入口，只有实际被拒后才以同一权威原因失败。完成后一次应用升级效果。建筑受损倍率与升级加成由 `BuildingSystem` 计算，`ActionSystem` 只消费倍率；UI 可显示精确值，NPC 信息空间只传播分档，避免逐 HP 修复刷屏。LLM 只看行动资格、即时可用性和失败原因，不决定占位、效率、资源、HP 或升级事实。

## T0041 非计划对话行动参考数据流

```text
data/action_defs.json + NPC / 建筑 / 动态目标状态
  -> ActionSystem 行动定义
  -> LLMBridge._build_allowed_action_candidates(npc_id, true)
  -> 同时进入 DailyPlanRequest.allowed_actions 与 NPCDialogueRequest.allowed_actions
  -> dialogue_system_prompt.txt 只把它解释为能力边界
```

`NPCDialogueRequest.allowed_actions` 为非空 Schema 合同，覆盖玩家-NPC 与 NPC-NPC 的全部 `/npc/dialogue` 子路径。后端不把对话响应解析成计划，也不允许模型直接执行候选；Godot 仍负责真正的行动选择、校验、移动、工位、资源、HP、战斗与事件事实。该复用保证未来行动候选变化不会要求另改一份对话行为清单。

## T0035-T0038 制造与马匹权威边界（当前实现）

当前实现包含两个不调用 LLM 的 Godot 权威域：`CraftingSystem` 从配方配置维护铁匠铺 / 工械坊的目标、项目 revision、整数阶段、逐阶段原子材料结算和具体成品入库；`HorseSystem` 从马匹配置维护个体 HP、饱食、进食、自愈、繁育、成长、额外 HP、位置与唯一分配。`ActionSystem` 只提供一个完整工作周期并提交阶段 / 当前有效养马人，`ResourceSystem` 只保存通用资源与具体物品计数，UI 只提交选择和展示快照。

```text
BuildingPanel -> CraftingSystem.set_target()
ActionSystem work cycle -> CraftingSystem.complete_stage()
CraftingSystem -> ResourceSystem(逐阶段材料 / 具体成品)
CraftingSystem -> BuildingSystem.special_state.production

logical_time_tick + 有效 work_stable -> HorseSystem
HorseSystem -> ResourceSystem(马匹进食粮食)
HorseSystem -> BuildingSystem.special_state.horses(仅数量)
NPCPanel(work only) -> HorseSystem.assign/unassign -> EquipmentSystem mount 兼容快照
NPC behavior_mode -> HorseSystem 会合 / 骑乘 / 返厩状态机
CombatSystem(结算后伤害) -> HorseSystem 先扣马 HP -> NPCSystem 再扣剩余 HP
```

`MemorySystem` 只对白名单内部特殊状态做进入快照和室内字段级差量；不得把完整制造运行态或逐匹马详情加入全局建筑上下文或广场外部状态。面板可直接查询权威系统获得小数进度 / 个体详情，但不能据此写资源、阶段、HP 或分配事实。旧 `weapons / armor / defense_devices / horse_readiness` 聚合键只保留为弃用兼容数据，正式制造、装备、部署和马匹分配均已迁移到具体物品或马匹实体。

## T0029/T0030 NPC-NPC 邀请与软轮次结束数据流

```text
发起者抵达目标
  -> DialogSystem 以 invitation phase 请求目标接受 / 拒绝
  -> 拒绝：不打断目标当前行动；双方分别判别各自计划是否需要修改
  -> 接受：打断双方普通行动并释放工位，进入无硬轮次上限的正式会话
  -> 每轮携带 current_round + soft_round_threshold/guidance
  -> 任一回复 should_end_dialogue=true：先记录该最后一句，停止下一次 LLM
  -> 正式会话结束后，双方分别判别各自计划是否需要修改
  -> revision_hours=[]：保持原计划并按恢复边界继续被打断行动
  -> revision_hours 非空：各自仅修订所选小时
```

邀请、每一轮正式回复和会话结束后的计划修改判别都是独立 LLM 请求，各自申请并释放 TimeSystem 慢速。后端只返回邀请意向、回复文本、结束意向或精确 `revision_hours`；是否打断行动、释放工位、恢复行动、应用修订以及写事件仍由 Godot 权威决定。玩家-NPC 路径在一轮完整的“玩家消息 + NPC 有效回复”发生后自动登记判别，不再读取 UI 开关。打开 / 关闭空窗口或取消未完成回复不会伪造有效对话。

## T0049/T0050 通用计划修改判别数据流

```text
实际对话结束或日常计划行动失败
  -> 对话：DialogSystem 为每名相关 NPC 保存完整 dialogue_history 与判别基线 current_plan
  -> 失败：DailyPlanSystem 保存程序权威 failed_plan_item / failure_type / failure_context 与基线计划
  -> 双目标 NPC-NPC 会话先为双方预注册同一 dialogue_id 的计划派发屏障
  -> LLMBridge POST /npc/plan_revision_judgement，并用 trigger_kind 区分 dialogue / action_failure
  -> revision_hours=[]：不调用 revise_plan；对话路径满足条件时恢复被打断的原行动
  -> revision_hours=[精确小时...]：DailyPlanSystem 携带既有完整修订上下文
  -> POST /npc/revise_plan，输出仅允许覆盖请求小时
  -> 后端与 Godot 双层校验返回小时集合与请求完全一致
  -> 合并选中小时，其他小时保持原值
  -> NPC-NPC 双方链路全部终态后按计划依赖顺序放行；跨小时玩家对话同样延迟新小时派发
```

明确的日常计划行动失败进入同一判别层，且第一层等待、非空后的第二层修订都计入该 NPC 的计划派发屏障；第二层继续使用原有完整失败上下文，只把输出范围限制为第一层选中的小时。守备官指令变化、战斗结束 / 复苏、主动交涉未被响应而超时和 GM 手动重估等其他触发仍直接构造受限小时集合并复用同一真实 `/npc/revise_plan`、三次真实尝试、过期响应丢弃和单后继队列边界。对话窗内已提交攻击属于有效对话事实：即使攻击回复取消或该分支没有 NPC 回复，也保留攻击轮并进入同一判别；非对话伤害按其自身入口处理。

派发屏障只约束对话结束后的当前计划落地，不把异步 LLM 调用改成阻塞请求。所有双目标 NPC-NPC 会话都在两次第一层请求发出前登记组屏障，不以是否跨小时为条件；双方各自的第一层空结果，或非空后第二层成功 / 最终失败 / 取消，都会登记为终态。组内全部终态后，`DailyPlanSystem` 使用既有计划依赖顺序统一调度，避免一方率先行动触发新对话并推进另一方 epoch。玩家-NPC 对话只有跨小时需要延迟新小时计划，判别链终态后再按最终计划派发。

## T0025 工位失败到自主交涉的数据流

```text
BuildingSystem 工位申请失败
  -> ActionSystem 写结构化占用者上下文
  -> DailyPlanSystem 以 revision_hours=[current_hour] 异步 /npc/revise_plan
  -> 后端按动态 allowed_actions 校验精确目标组合
  -> ActionSystem 追踪并预定对话双方
  -> DialogSystem 释放普通行动/工位并自动调用 /npc/dialogue
  -> MemorySystem 写双方轮次
  -> DialogSystem 为实际参与对话的双方分别进入 T0049 判别层
```

Godot 始终拥有移动、工位、行为模式、资源、HP 和事件权威；后端只返回对话文本与计划意向。每日未来计划可以保留短暂忙碌目标作为将来对话选项，而即时修订会排除当前规划 / LLM 活动、已有对话和 approach reservation，避免模型得到程序必然拒绝的“立即行动”。ActionSystem 的运行态快照携带 action / target / location / phase；DailyPlanSystem 用请求日、小时、计划版本、同一时段派发签名、单后继队列和连续迟到落地失败上限，防止旧响应覆盖新计划、短行动重复刷取或后续失败丢失。同批当前项按教官、其他非对话、受训者、对话顺序派发。

## 总体架构

项目采用 Godot 前端 + Python 后端 + LLM API 的架构。

```text
Godot 4.6 客户端
  ↓ HTTP
Python / Game Backend
  ↓
Model Adapter
  ↓
DeepSeek / MiniMax / Qwen / Zhipu 等模型
```

正式分发方向：

- 玩家电脑运行 Godot 客户端。
- Godot 客户端请求游戏服务器后端；本地开发可临时请求 `127.0.0.1` 的后端，并显式使用 mock provider 做开发验证。
- 服务器后端负责调用真实 LLM Provider、持有供应商 API Key、统一限流、排队、规则 / 模板降级、成本统计和调用日志。
- Godot 导出客户端不保存真实供应商 API Key，也不直接请求 DeepSeek / MiniMax / 通义千问 / 智谱等模型接口。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式，不是 Demo 阶段的必需路径，也不能成为默认架构。
- Mock provider 不是成品 / Demo 的模型失败兜底。真实 provider 失败、无 Key、超时、非 JSON 或 Schema 校验失败时，生产 / 演示路径必须返回可处理错误并记录真实失败原因；允许规则 / 模板降级继续游戏流程，但不能用 mock 内容伪装模型成功。

当前后端实现状态：

- 使用 Flask 作为 Python Backend 的最小 Web 框架。
- `backend/app.py` 提供 `GET /health`，用于 Godot 或开发者确认本地服务可用；另提供 `GET /debug/llm_usage`、`POST /mock/model` 调试接口和各类 NPC AI 业务接口。
- `backend/services/model_adapter.py` 是模型供应商隔离层；默认 `mock` 服务本地开发，也支持 `deepseek` / `openai_compatible`。生产自动 mock fallback 默认关闭。正式 `dialogue`、`plan_revision_judgement`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection` 请求使用流式 SSE 聚合完整 JSON，不向供应商发送客户端单次输出 token 上限，也不设置模型生成总时长。连接建立和流完全无数据分别由 provider connect / idle timeout 保护；持续 token 或 keep-alive 会继续等待。DeepSeek 结构化路径默认 `LLM_THINKING_MODE=disabled`；六类调用的 JSON 为空、截断或非法时都可按业务紧凑重试一次。六个成功业务端点统一通过同一 helper 附加 `model_provider` / `model_name` / `model_fallback_used`，避免各路由或 Godot 调用方自行猜来源。Usage 记录 `finish_reason`、响应长度和尝试次数，累计预算守门继续由 T1406 变量独立控制。
- `backend/schemas/common.py` 和 `backend/schemas/npc_ai.py` 提供后端 AI 请求/响应 Pydantic Schema；统一 `NPCDialogueRequest` 覆盖玩家-NPC、逃离挽留与真实 NPC-NPC 对话，T0087 后按 `dialogue_kind` 分派到三个响应 Schema。NPC-NPC 继续用 `dialogue_phase / invitation_result` 区分邀请与正式会话，并使用 `max_rounds=0` 与一致的软轮次字段；后端和 Godot 校验回复者身份、`response_kind` 及当前分支字段，但不替业务系统结算权威状态。
- T0703A 后共享 `NPCContext` 与对话顶层 `NPCDialogueRequest` 都包含单条最新 `current_order`；Mock 只把它作为参考上下文，Godot 保持指令和行动事实权威。
- 真实 API Key 必须通过本地 `backend/.env` 或环境变量提供；仓库只保留 `.env.example` 模板。开发可显式 `LLM_PROVIDER=mock`，生产 / 演示配置应使用真实 provider 并关闭自动 mock fallback。

后端部署方向：

- 服务器运行的应用入口仍是 `backend/app.py`。
- 本地开发可以 `python backend/app.py`，但正式部署不能使用 Flask debug server。
- T1407 需要补齐生产 WSGI 启动方式，例如 Linux 服务器使用 `gunicorn backend.app:app`，或 Windows 服务器使用 `waitress-serve --call backend.app:create_app`。
- T1407 还需要补齐 `backend/README.md` 部署说明、生产依赖、环境变量、日志、健康检查、限流、预算、mock fallback 关闭策略和重启策略。
- Godot 客户端只配置后端服务地址；真实供应商 API Key 只存在于服务器后端环境中。

## 职责划分

### Godot 负责

- 场景渲染
- 角色移动
- 建筑点击
- UI 展示
- 资源数值
- 逻辑时间流逝与倍率
- LLM 等待期间的 TimeSystem 慢速请求注册/释放
- 敌人在场期间的 TimeSystem `combat_enemy_presence = 1/60` 慢速注册 / 释放
- 统一战斗秒：攻击、位移、塔防、持续效果与攻击动画共用游戏秒 / 现实秒 1:1 基准
- 工作产出
- 广场公告当前状态、公告牌输入路由与在场 NPC 广播
- 商人到访时段、交易报价校验和资源买卖结算
- 工程器械库存消耗、围墙 / 主厅通用槽占用、器械 HP / 防御 / 穿透、弩床 / 箭塔自动攻击和部署事件
- 战斗执行
- NPC 行为模式切换：工作、集结、战斗、避战、昏迷、逃离
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件权威写入、地点/建筑信息节点当前状态维护、即时广播、NPC 事件库与见闻库维护
- 已入伍 NPC `current_order` 的权威保存、指令发布差异判断、`private` `order_assigned` 事件写入和计划重评估触发
- 与后端通信
- T0604A/T0022 后通过 `Main/Systems/LLMBridge` 的 Godot 原生 `HTTPClient` 请求后端；对话、每日计划和计划修订都有异步路径。正式开局和正式新一天全局暂停时间并发起 8 个真实每日计划；常规计划修订申请 TimeSystem 慢速，异步完成后释放

### Python 后端负责

- Prompt 拼装
- 把 Godot 提供的 `current_order` 作为独立参考上下文注入所有 NPC 中心 Prompt
- LLM 调用
- 结构化 JSON 校验
- 对话生成
- 每日计划生成
- 战斗/逃离心理判定
- 战时公开对话结构化意向生成
- 首次睡眠总结
- 知识图谱更新
- API 成本统计
- 模型供应商切换

### LLM 负责

- NPC 如何理解事件
- NPC 如何理解、调整或拒绝守备官当前指令
- NPC 如何说话
- NPC 是否愿意征召
- NPC 如何在战时对话或低血量压力下表达逃离、继续战斗或斗志激昂意向
- NPC 是否主动找玩家交涉
- NPC 的主观日记与反思

### 事件与记忆边界

Godot 是事件事实源。资源、HP、建筑、移动、战斗、工作、公告、商人交易、对话收发等权威结果先由 Godot 侧系统结算，再写入 `MemorySystem`：

```text
程序系统结算权威结果
  ↓
MemorySystem.add_event(...)
  ↓
写入 subject_npc_id 的 NPC 事件库
  ↓
按 visibility 发送到对应地点/建筑信息节点；广场也是地点节点
  ↓
信息节点即时广播给当前在场且可接收见闻的 NPC；昏迷或睡觉 NPC 不写入见闻库，接收者写入见闻库
  ↓
NPC 进入地点时，只读取当前状态快照，不继承过去事件
  ↓
进入广场见闻快照包含当前在场 NPC、这些 NPC 的生命状态 / 行动状态和建筑外部状态，不含公告牌通告 / 参考日程 / 备注；进入可进入建筑快照包含建筑内 NPC 的生命状态 / 行动状态；室内到室内切换在事件层经由广场
  ↓
LLM 调用前从事件库 + 见闻库生成摘要
```

后端和 LLM 可以根据事件库、见闻库和知识图谱生成解释、对话、计划、日记和知识图谱当前键值更新，但不能直接新增会改变权威数值的事实。对话全文作为对话事件 `payload` 的一部分保存，不单独建立谈话库。

T1506/T1507/T0046 遵守同一边界：`NoticeBoardPanel` 只把通告或参考日程草稿交给 `MemorySystem.set_plaza_notice(...)` / `set_plaza_reference_schedule(...)`，公告牌权威状态只在广场节点；`MerchantPanel` 只把交易意图交给 `MerchantSystem`，由后者校验配置、到访时段、数量和库存，再调用 `ResourceSystem` 结算。成功到达、离开与交易写入结构化广场公开事件，失败交易不修改资源也不伪造成功事件。两条路径均不调用 LLM。

T0107 覆盖 T1508 的围墙专属入口：`DefenseSlotPresenter` 把围墙 / 主厅槽位从 3D 世界投影为圆形 `+` / 等级标记，并只提交 `device_id + slot_id`；BuildingPanel 保留当前建筑的兼容入口。`DefenseDeviceSystem` 校验建筑等级 / 可用性、槽位和库存并原子部署，保存器械 HP / 防御 / 穿透 / 攻速与最终有效射程；T0223 后主厅使用 `1.0x` 基础射程，围墙等级收益继续动态合成。弩床与箭塔通过 CombatSystem 窄接口伤害敌人，敌人也通过 DefenseDeviceSystem 窄接口伤害器械。围墙槽所需等级为 `1 / 2 / 4 / 6`；T0228 后主厅按 ID 为 `5 / 6 / 1 / 3`，即前侧 `03/04` 先解锁。BuildingPanel 通过 `BuildingSystem.get_upgrade_level_effect(...)` 展示下一等级真实成本、工期、Max HP 和扩槽收益。`DefenseDevicePresenter` / `DefenseDeviceView` 仅消费快照创建已部署低模，不能反向决定库存、HP、槽位、射程或攻击事实。该路径不调用 LLM，也不为器械受击 / 摧毁新增信息事件。

T0701/T0051 起，`DialogSystem` 是 Godot 侧会话权威入口：它维护参与者、历史、公开性、轮次和守备官会话生命周期。守备官消息发送后立即写入内存历史；“完成对话”取消仍在等待的回复，并在至少存在一句真实发言时把完整历史作为一条 `dialogue_turn` 写入 `MemorySystem`，应用会话中仍暂存的战时 / 挽留意向并进入 T0049/T0050 判别。“取消对话”不入库、不广播、不应用仍暂存的意向也不判别；“挂起对话”保持 NPC 的 `talk_to_guard_officer` 运行态和原会话。攻击由 `NPCSystem.apply_damage_to_npc(...)` 立即权威扣 HP 并锁定取消；T0254 后攻击说明仅作为 LLM 语境，不写入 history，纯攻击完成或超时不生成 `dialogue_turn`，而以既有 `guard_attack` 事实请求计划重评估。T0082 起，“提出应征”是会话内持续开关，第一次带标记的消息发送后 `session_had_recruitment_request` 永久锁定本场取消；该开关随后关闭只影响后续请求，挂起超时仍按完成。完成的守备官会话 summary 从真实 `dialogue_text` 逐句生成，但事件、广播和判别仍各只有一次。`local_public` 完成会话只向同地点非参与者广播一次。判别返回空 `revision_hours` 时只在动作确被本次对话打断、仍匹配当前计划且行为模式允许时恢复原小时行动；非空时才把精确小时交给 DailyPlanSystem。T0702 起，后端只返回应征意向；T0072 起，合法接受回复进入会话历史后立即由 `DialogSystem` 调用 `NPCSystem.set_npc_recruited(...)` 应用，拒绝仍不改变状态。T0029/T0030/T0049 后，自主 NPC-NPC 会话仍按实际完成轮次入库：邀请不计正式轮次，任一方结束标记回复先入库再停止下一次调用，邀请拒绝和正式结束分别为实际参与双方判别。T1103A/T0051 后，行为模式切换调用 `force_end_dialogue_for_npc(...)` 强制完成已有守备官会话、取消未完成回复并优先切换模式，不丢弃已经说出口的消息或独立攻击事实。

T1201 已扩展同一边界：集结 / 战斗 / 避战模式下的守备官对话强制 `local_public`，并额外携带 `interaction_context` 与 `battlefield_context`；后端只返回文本、征召意向和 `wartime_reaction`，斗志 buff、逃离流程、模式切换和事件入库仍由 Godot 执行。T1202 后，低血量自身心理判定触发时，Godot 复用强制完成已有会话和取消未完成 LLM 请求的边界，并通过 `allowed_decisions` 限制非战斗人员不能获得斗志激昂或继续参战。T1404 后，战时公开对话与低血量心理判定已完成真实 provider smoke 验证；后端会拒绝 `/npc/battle_judgement` 越界 `decision` 与逃离布尔不一致结果，并写入失败 usage。T1203 后，逃离意向由 Godot 的 `CombatSystem.start_npc_escape(...)` 转为后门移动、`escape_started` / `escaped` 事件和最终 `escaped=true` 状态。T1204A/T0051 后，逃离挽留由 NPC 面板【对话】进入，打开或挂起时 `CombatSystem` 都保持逃离暂停；完成、取消或满 5 轮时恢复。玩家消息轮次复用 `/npc/dialogue`，强制公开并限制 5 轮，LLM 只返回留下或继续逃离意向且在完成时应用。逃离挽留攻击不调用 `/npc/dialogue`，由 Godot 直接扣 HP、加速、计轮并自动完成会话。

### LLM 不负责

- 资源扣除
- HP 扣除
- 伤害计算
- 建筑摧毁
- 寻路
- 战斗命中
- 工作产出
- 是否真的拥有某件装备
- 是否真的能执行某行动

## T0107 战斗属性与塔防数据流

```text
npc_profiles / weapon_defs / armor_defs / mount_defs
  -> CombatSystem.get_npc_combat_stats(...)
  -> base / growth / equipment / condition / final
  -> max(0, defense - penetration)
  -> 20 / (20 + effective_defense) 伤害倍率
  -> NPCPanel / GM 只读展示

defense_device_defs
  -> DefenseDeviceSystem（槽位、库存、HP、自动攻击）
  -> DefenseSlotPresenter（世界槽位交互投影）
  -> DefenseDevicePresenter / View（已部署模型）
  <-> CombatSystem（双方伤害窄接口）
```

CombatSystem 是 NPC / 敌人伤害、远程距离带、敌人抬手 / 僵直和骑兵冲锋阶段的权威；配置与 UI 不直接扣 HP。T0110 后当前主武器的 `required_skill` 只进入该武器攻速乘区，不进入穿透；非当前武器熟练度不生效。骑术只进入马匹冲撞伤害，不进入骑乘攻速。EquipmentSystem 会把完整定义副本写入运行时装备槽，但 `LLMBridge` 的 Prompt 专用装备投影只保留 T0107 前已有的身份、装备类型、武器伤害 / 射程 / 间隔、盔甲值与坐骑速度等白名单字段，排除新增防御、穿透、攻速修正和所有 `charge_*` 参数，因此本任务不扩展 NPC Prompt 战斗属性。

## T0035-T0038 制造、具体库存与马匹当前技术边界

T0035-T0038 已按 T0034 冻结的设计完成系统与正式路径迁移：`ActionSystem` 提交制造阶段，`EquipmentSystem` / `DefenseDeviceSystem` 消耗同名具体库存，`HorseSystem` 管理逐匹马实体；旧聚合键不再参与权威结算。

### 权威职责

- `ResourceSystem` 继续是基础资源和可数量化具体成品库存的唯一事实源。正式可扣除的成品键是 `item_sword_shield / item_polearm / item_bow / item_crossbow / item_iron_helmet / item_mail_chest / item_iron_bracers / item_iron_greaves / item_wall_ballista / item_wall_arrow_tower`。`weapons / armor / defense_devices` 类别合计只能由这些键汇总为只读摘要，不得作为可消费的并行权威库存。
- `CraftingSystem` 读取数据驱动配方，权威保存每座铁匠铺 / 工械坊的建筑级目标、项目版本、已完成阶段和当前工人周期投影。它校验目标归属、换目标确认、阶段版本和材料；阶段提交时通过 `ResourceSystem` 原子扣材料，最后一阶段后只向对应具体成品 ID 加 1。UI、LLM 和 `ActionSystem` 都不直接写阶段或产出。
- `ActionSystem` 仍权威管理 NPC 的工位、熟练度 / 属性 / 建筑等级耗时、行动打断和单个工人周期。完整周期只向 `CraftingSystem` 提交一次阶段请求；中断只清该工人未提交的小数进度。多工位可并行跑周期，但 `CraftingSystem` 必须串行校验并落账，避免同一阶段或成品重复结算。
- `EquipmentSystem` 只扣除 / 返还当次装备的同一具体物品 ID；`DefenseDeviceSystem` 只扣弩床或箭塔自身 ID。故事初始装备仍可经 NPC 档案初始化，不伪造玩家库存消耗。
- `HorseSystem` 是马匹个体、总 HP / 基础 HP 派生值 / 养马额外 HP、饱食、进食、自愈、成长、独立累积繁育概率 / 产后冷却、物理位置和分配映射的唯一事实源。它消费 `TimeSystem` 逻辑时间，在进食周期完成时调用 `ResourceSystem` 原子扣粮食，并从 `ActionSystem` / `BuildingSystem` 只读获取当前有效养马人与马厩等级。UI 只读取拆分后的公开快照，不写概率、冷却或 HP；`horse_readiness` 不再是马的数量、分配或骑乘事实。
- 马匹分配使用单一交易边界：`HorseSystem` 复验 `work` 模式、NPC 已入伍且有主武器、马匹成年 / 在厩 / 未分配，再让 `EquipmentSystem` 在 `equipment.mount` 保存具体 `horse_id` 的轻量投影。马的分配关系、HP、死亡与物理位置仍只由 `HorseSystem` 修改；`CombatSystem` 通知 `rally / combat` 进出并消费马匹分伤结果，不直接搬移马或写马状态。收回主武器、取消入伍、马死亡、骑手昏迷或逃离必须经同一内部边界自动解除分配。

当前制造数据流：

```text
BuildingPanel 提交目标 / 确认放弃旧进度
  -> CraftingSystem 校验建筑、配方、项目版本与确认条件
ActionSystem 完成一个工人周期
  -> CraftingSystem 串行提交一个阶段
  -> ResourceSystem 扣该阶段材料
  -> 最后阶段时 ResourceSystem 增加具体成品 ID
  -> BuildingPanel 刷新项目 / 进度 / 库存
```

当前马匹数据流：

```text
TimeSystem 逻辑时间 + 马厩有效养马人快照
  -> HorseSystem 结算饱食、进食、非战斗自愈、繁育、成长与额外 HP
  -> 进食完成时 ResourceSystem 扣粮食
NPCPanel 在 work 模式提交分配 / 取消分配
  -> HorseSystem 校验并更新分配事实
  -> EquipmentSystem 同步具体 horse_id 坐骑投影
CombatSystem 切换 rally / combat
  -> HorseSystem 让分配马在真实马厩锚点等待
  -> NPCSystem 导航到马旁，人物抵达后才进入 ridden
结算后敌军伤害
  -> HorseSystem 先扣随机 30%-50% 马匹 HP
  -> CombatSystem 将剩余伤害交给 NPCSystem
```

### `internal_state.special_state` 当前传播实现

`CraftingSystem` / `HorseSystem` 先把归一化白名单写入 `BuildingSystem.special_state`；`MemorySystem._get_building_full_state_snapshot(...)` 将其纳入 `internal_state.special_state`，并在 `MemorySystem._on_building_state_changed(...)` 中做独立缓存、嵌套字段差分与摘要格式化。只有同地点、在场且可接收见闻的 NPC 获得进入快照或变化事件，完整实时运行态不会进入全局建筑上下文。

当前约束如下：

1. 由 `CraftingSystem` / `HorseSystem` 向 `BuildingSystem` 提供归一化的只读特殊状态，`MemorySystem._get_building_full_state_snapshot(...)` 把它挂到 `internal_state.special_state`。铁匠铺 / 工械坊白名单只是 `production.{target_item_id,target_name,completed_stages,total_stages,current_stage_index,current_stage_name}`；马厩白名单只是 `horses.{total,adult,foal}`，且只统计物理在厩马。
2. 为 `MemorySystem._on_building_state_changed(...)` 增加独立特殊状态缓存与嵌套字段差分。目标、整数阶段或在厩数量的语义变化仍走现有 `location_status_changed`，但使用 `reason=building_internal_special_state_changed` 和 `changed_special_state`；`_broadcast_location_state_changed(...)` 必须把 `changed_special_state` 视为已有差量，不再夹带整个地点快照。
3. 扩展进入快照和差量摘要格式化，但继续复用 `MemorySystem.add_event(...)` 的同地点 `local_public` 接收路由。这条现有路由已限定当时在场且可接收见闻的 NPC，无需新增全局广播或建筑事件历史。
4. 当前工人周期小数进度、马匹名字 / HP / 饱食 / 成长 / 进食 / 分配详情只供 UI 直读相应权威系统，不进 `special_state`。逐帧 / 逐逻辑 tick 的 UI 进度刷新不触发建筑信息见闻，只在白名单语义字段变化时通知 `MemorySystem`。
5. `LLMBridge._build_building_state_context(...)` 不得因此把完整 `special_state` 追加到所有 NPC 共享的建筑状态。同地点 NPC 通过进入快照 / 差量见闻获得合法信息；对应工作行动候选只需暴露“是否已选合法目标”等最小可执行条件，不向建筑外 NPC 泄露制造目标、阶段或马匹数量。

## 推荐通信接口

### 健康检查

`GET /health`

返回：

```json
{
  "ok": true,
  "service": "war-not-mine-backend",
  "model_adapter": {
    "provider": "deepseek",
    "model": "deepseek-v4-flash",
    "configured": true,
    "fallback_to_mock": false
  }
}
```

### Mock Model 调试接口

`POST /mock/model`

输入：

```json
{
  "call_type": "battle_judgement",
  "payload": {}
}
```

输出包含：

- `ok`
- `provider`
- `call_type`
- `content`
- `usage`

该接口只用于 T0602 后端调试、Schema 验证和自动化测试，不替代 `/npc/dialogue`、`/npc/plan_day` 等正式业务接口。它显式使用 mock provider，不受本地 `.env` 中未来真实 provider 配置影响；`content` 按 `call_type` 返回可被当前 Schema 校验的稳定 JSON；`usage` 记录 request id、NPC id、关联事件 id、伪输入/输出 token、估算费用和成功/失败状态。成品 / Demo 真实 provider 失败时不得退回该接口的内容伪装成功。

### LLM Usage 调试接口

`GET /debug/llm_usage`

返回：

- `ok`
- `model_adapter`：当前 provider、model、base_url、configured、fallback_to_mock 和 timeout。
- `summary`：累计调用次数、成功 / 失败数、fallback 次数、输入 / 输出 token、费用估算、最近失败原因和按 call_type 聚合的统计。
- `summary.budget`：预算是否启用、上限、已用量、剩余额度、下一次调用可能触发的超限原因和最近预算错误。
- `records`：逐次调用记录，必须能定位 request id、call_type、provider、model、NPC id（如有）、HTTP 状态或异常类型、失败原因、`fallback_used`、`degradation_source` 和是否使用规则 / 模板降级。

该接口只读，不触发模型调用，也不代表 Godot 侧需要申请 TimeSystem 慢速。

### NPC 对话

`POST /npc/dialogue`

输入 Schema：`NPCDialogueRequest`
输出 Schema：`PlayerNPCDialogueResponse` / `NPCNPCDialogueResponse` / `EscapeInterventionDialogueResponse`

覆盖玩家-NPC、NPC-NPC 和逃离挽留对话。T0603 当前对话输入必须能表达：

- 目标 NPC：`npc_id`、`npc_name`、`npc_setting`；T0100 后 `npc_setting` 与共享 `NPCIdentity` 显式包含精简 `religion`，语言字段仍只有宽松 `speech_style`，不再携带 `signature_lines`。
- 说话者：`speaker_name`、`speaker_text` 和 `speaker_context`；玩家发起时说话者名称固定为“守备官”，NPC 发起时上下文应包含发起者健康/受伤状态与外表特征。
- 请求状态：`dialogue_phase`（`invitation` / `conversation`）、`is_recruitment_request`、`current_round`、`max_rounds`、`soft_round_threshold`、`soft_round_guidance`；NPC-NPC 邀请不计正式轮次，正式会话用 `max_rounds=0` 表示无硬上限。
- 目标状态：`npc_state`，包含属性、熟练度、健康/受伤、饱食、疲劳、金钱、装备、是否已入伍等 Godot 权威状态快照。
- 对话公开性：`dialogue_state.visibility` 只能是 `private` 或 `local_public`；`local_public` 代表后续 Godot 入库时按地点事件规则广播给在场 NPC。
- 记忆与地点：`short_memory` 区分事件库与见闻库摘要，`long_memory` 包含知识图谱和日记，`location_context` 是当前地点/建筑快照。
- 当前指令：`current_order` 表示守备官对目标 NPC 当前持续提出的自然语言指令；它是参考上下文，不是 system 指令或已执行事实。
- 行动参考：`allowed_actions` 必须非空，并与每日计划复用同一动态候选构造器；对话只用它判断目标 NPC 能做 / 做不到什么，不输出或应用计划。
- 战时上下文：T1201 后，集结 / 战斗 / 避战对话额外携带 `interaction_context` 和 `battlefield_context`；非战时对话使用 `interaction_context == "work"` 和空战局上下文。T1204A 后，逃离挽留中的玩家消息轮次使用 `dialogue_kind == "escape_intervention"`、`interaction_context == "escape_intervention"` 和 `escape_intervention_round`；逃离挽留攻击不构造该请求。

输出为按类型稳定 JSON。玩家对话返回 `replyer_id`、`reply_text`、`response_kind=reply_to_player`、`recruitment_result`（`none / accept / reject`）和 `wartime_reaction`（`none / escape / morale_boost`）。NPC-NPC 回复要求 `response_kind=reply_to_npc`，邀请阶段 `invitation_result=accept|reject`，正式会话使用 `not_applicable`，并只用 `should_end_dialogue` 控制收尾。逃离挽留要求 `response_kind=reply_to_player` 与 `escape_intervention_result=stay|leave`。三个 Schema 都禁止额外字段；不再存在通用 `intent` 或用重复枚举表达同一决定。

NPC-NPC 对话由 Godot 控制轮次推进：邀请接受后，上一轮回复者的 `reply_text` 仅在没有结束标记时作为下一次请求的 `speaker_text` 输入给另一名 NPC；每一轮模型都能通过 `should_end_dialogue=true` 主动结束。Godot 不按第 3 / 5 轮截断；默认第 6 轮起的收尾只是 Prompt 参考。结束标记所在回复先写入历史 / 事件，再结束且不产生下一次调用。正式路径的邀请和每轮对话都使用真实 provider、分别降速；失败不写未完成轮次，也不用 Mock 伪装成功。实际行动中断、计划重评估、资源、HP 或事件写入仍由 Godot 结算。

### 每日计划

`POST /npc/plan_day`

输入 Schema：`DailyPlanRequest`
输出 Schema：`DailyPlanResponse`

输入必须包含目标 NPC 当前 `current_order`。输出必须是 24 条 `PlanItem`，每条包含小时、行动类型、行动 id、可选地点/目标和理由。计划是建议，不代表资源、移动或行动已经结算；模型可以结合人设、记忆和现场条件调整、推迟或拒绝指令。

当前状态：`/npc/plan_day` 使用 `DailyPlanRequest` / `DailyPlanResponse`，真实 provider 读取独立 Prompt，并校验 0-23 点覆盖和精确行动候选。通常至少 6 个工作阶段是 Prompt 强建议，不是 backend / Godot 的接受门槛。成功响应附加 provider / model / fallback 元数据和 `model_normalizations`（未规范化时为空数组）。其他 Schema、白名单和小时错误仍失败；正式开局与新一天仍只接受真实 `source=llm_plan_day`，失败保持暂停，不使用规则 / Mock 冒充成功。

### 对话 / 行动失败通用计划修改判别

`POST /npc/plan_revision_judgement`

输入 Schema：`PlanRevisionJudgementRequest`
输出 Schema：`PlanRevisionJudgementResponse`

`trigger_kind=dialogue` 时，请求携带 `dialogue_kind`、本轮完整 `dialogue_history`、结束原因、会话元数据和对话对应的原计划；`trigger_kind=action_failure` 时，改为携带程序权威的 `failed_plan_item`、失败类型 / 摘要 / 必要上下文、原计划和工作阶段下限。T0053 起两种分支都携带动态驿站场景、完整 NPC 人设 / 状态 / 长短期记忆 / 地点 / 指令、行动候选及实时建筑 / 资源条件。模型只返回需要修改的精确 `revision_hours` 与简短理由；空数组严格表示 0 个阶段，无需调用计划修订。后端与 Godot 拒绝重复、越界或早于当前小时的选择。NPC-NPC 会话为双方分别构造请求，不能共用一方结论。旧 `/npc/dialogue_plan_revision_judgement` 和旧 Schema 名仅作为兼容别名。

### 计划修订

`POST /npc/revise_plan`

输入 Schema：`PlanRevisionRequest`
输出 Schema：`PlanRevisionResponse`

用于通用判别选中阶段，以及守备官发布新指令、战斗结束 / 复苏、主动交涉超时和 GM 手动重估等直接触发后的计划修订。请求必须包含最新 `current_order`、`revision_scope=selected_hours` 与非空、排序且去重的 `revision_hours`。对话路径（包括其中已提交的攻击轮）与行动失败路径都沿用既有完整修订上下文，但小时集合来自上一层判别；其他直接触发的范围由各自程序入口给出。

当前状态：`/npc/revise_plan` 使用 `PlanRevisionRequest` / `PlanRevisionResponse`，读取紧凑计划修订 Prompt，并额外校验 NPC id、响应小时集合与请求完全一致、精确行动候选，以及包含当前小时请求时的 `immediate_action`；工作阶段统计继续输入 Prompt，但不再作为业务拒绝条件。成功响应附加 provider / model / fallback 元数据和 `model_normalizations`。Godot 通过异步真实 provider 调用，成功时只合并所选小时；其他失败、重试、过期响应和单后继队列规则不变。

### 战斗判定

`POST /npc/battle_judgement`

输入 Schema：`BattleJudgementRequest`
输出 Schema：`BattleJudgementResponse`

只覆盖战时 HP 首次低于 30% 的自身心理判定，以及必要的逃离检查；不再用于“战斗触发时全员判定”。请求必须包含目标 NPC 当前 `current_order` 和 `battlefield_context`；输出只表达继续战斗、逃离、斗志激昂或继续避战等意向，不能把守备官指令直接当成强制结果。伤害、buff、逃离移动和状态变更由 Godot 执行。

Godot 负责按目标 NPC 状态提供 `allowed_decisions`：已入伍且有主武器、实际处于 `combat` 模式的 NPC 可继续战斗、逃离或斗志激昂；避战 / 非战斗人员只能逃离或继续避战。T1404 后，真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，后端在 `BattleJudgementResponse` Schema 校验后额外校验 `decision` 属于 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；越界结果返回 `model_output_invalid` 并写入 usage。若仍有非法结果进入 Godot，Godot 必须规则降级，不让非战斗人员获得斗志激昂或直接参战。真实 DeepSeek 已完成战时公开对话与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。

### 首次睡眠总结

`POST /npc/daily_reflection`

输入 Schema：`DailyReflectionRequest`
输出 Schema：`DailyReflectionResponse`

输出第一人称日记和 `KnowledgeGraphPatch` 列表；T0046 起不再输出与日记并列的当天长期摘要。

当前状态：T1004/T1005/T1405/T0024 已在 Flask 后端接通 `/npc/daily_reflection`，使用 `DailyReflectionRequest` 校验输入、调用 `ModelAdapter.generate("daily_reflection", ...)`，再用 `DailyReflectionResponse` 校验输出并附加 provider 元数据。接口历史名仍是 daily_reflection，当前玩法语义是熟睡总结。Godot 侧 `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`；T0094 后按 21:00 锚定窗口累计多段睡眠，达到 1 游戏小时后通过异步接口调用，只有成功应用才完成该窗口。最多允许 8 路同时在飞，并暴露实际峰值、逐 NPC 窗口与完成窗口快照。真实成功标记 `llm_daily_reflection`，显式 Mock provider 标记 `mock_daily_reflection`；缺少来源证明或 fallback 结果不会伪装成真实成功。完成后把日记 / 知识写入长期记忆并轮转该 NPC 当前短期索引。模板降级必须标明来源并保留模型失败日志。该调用会申请 TimeSystem 慢速，且请求发起到应用完成期间 NPC 处于不可打断的深度睡眠锁。

### 其他 AI 辅助

后续接口可复用：

- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`

## 数据流

```text
玩家点击 NPC
  ↓
Godot 收集 NPC 当前状态、地点信息、短期记忆摘要
  ↓
Godot 通过 TimeSystem 注册 LLM 等待慢速请求
  ↓
发送到后端
  ↓
后端拼装 Prompt 并调用模型
  ↓
模型返回 JSON
  ↓
后端校验 JSON
  ↓
Godot 释放 TimeSystem 慢速请求
  ↓
Godot 执行合法结果
  ↓
权威结果写入 MemorySystem 事件系统，并按可见性通过对应地点信息节点即时广播给当前在场 NPC；广场公开信息使用 `location_id == "plaza"` 的本地公开事件
```

## 失败降级

如果 LLM 请求失败，Godot 必须释放该请求的 TimeSystem 慢速登记并返回可处理错误。允许降级的其他业务可使用明确标源的规则 / 模板结果；正式每日计划不降级，它会保持全局暂停，等待真实计划问题被解决。

生产 / 演示路径不得用 mock 内容掩盖真实 provider 失败。Mock 只允许在显式开发模式中使用。允许降级的其他系统必须使用明确 source 并保留原始失败；正式每日计划不得进入该降级路径。

## 时间倍率边界

Godot 不使用后端结果直接决定时间倍率。后端只返回业务 JSON；是否申请慢速、慢速 request id、超时释放和恢复玩家速度，由 Godot 的 LLMBridge / DialogSystem / 计划系统负责。

T0183 起，CombatSystem 在活动敌人存在时注册 `combat_enemy_presence = 1/60` 慢速，使游戏内 1 秒等于现实 1 秒；所有敌人消失后释放。玩家选择 `x4` 时仍保存该选择，战后恢复；战斗中的 LLM / NPC 移动请求也是 `1/60`，不再进一步降低战斗速度。后端和 LLM 仍不直接决定时间倍率。

T0183 起，CombatSystem、DefenseDeviceSystem 与 PietySystem 直接把 `logical_time_tick` 的游戏秒作为战斗秒，不再除以 60。敌人在场慢速保证现实 1 秒只产生 1 游戏秒，攻击权威 elapsed/cycle、敌人移动、塔防冷却、陨石燃烧与动画现实播放时长因此保持同一尺度。工作、日常状态、治疗、建筑修复 / 升级等经营结算也继续直接使用 TimeSystem 游戏秒。

## Godot LLMBridge 当前实现

T0604 已在 Godot 侧新增 `res://scripts/systems/LLMBridge.gd`，挂载于 `Main/Systems/LLMBridge`；T0604A 已将传输层替换为 Godot 原生 `HTTPClient` 状态机。T0109 补齐异步传输退出生命周期：取消 request id 会通过互斥保护的协作标记终止对应 `HTTPClient.poll()` 循环；`_exit_tree()` 先禁止新异步请求、取消全部传输、释放 TimeSystem 慢速与 NPC LLM 活动，再逐线程 `wait_to_finish()`，因此 worker 不会在桥接节点释放后继续投递 deferred 回调。

T0042 将对话顶层 `npc_setting` 的字段选择提取到 `res://scripts/core/NPCPromptProfile.gd`。LLMBridge 与 NPCPanel 人物背景弹窗都调用这个无状态构造器，因此 Prompt 人设与玩家可见档案共用数据和字段合同；UI 只是只读消费者，不依赖后端在线状态，也不产生额外 API 成本。

当前能力：

- `check_health()` 通过原生 HTTP 请求 `GET /health`，并通过 `backend_status_changed(status_text, ok)` 供 HUD 显示后端状态。
- `request_llm_usage()` / `debug_request_llm_usage()` 通过原生 HTTP 请求 `GET /debug/llm_usage`，供 GM 面板查看 provider、token、费用统计、预算上限 / 剩余额度、fallback 次数和失败原因；该查询不申请 TimeSystem 慢速。
- `debug_get_llm_runtime_snapshot()` 只读返回后端状态、当前 pending LLM 慢速请求数、pending request id、NPC 活动请求、异步请求数量、传输关闭标记、最近线程收束结果、TimeSystem 有效倍率、最近倍率变化原因和逐请求慢速注册 / 释放审计，供 GM 面板与自动化验证等待中的 LLM 请求、时间减速及退出诊断状态。
- `build_npc_dialogue_payload(...)` 按 T0603/T1201/T0029/T0030 Schema 收集目标 NPC 设定、守备官/NPC 说话者上下文、对话阶段、应征标记、当前轮次、NPC-NPC 软轮次阈值 / 指导、NPC 状态、短期记忆、长期记忆、地点快照、`interaction_context` 和必要时的 `battlefield_context`。
- `request_npc_dialogue(...)` / `request_npc_dialogue_async(...)` 通过原生 HTTP 请求 `POST /npc/dialogue`，返回后端业务 JSON 或错误字典；开发模式可返回 mock JSON，生产 / 演示模式不得把真实失败替换成 mock 回复。
- `build_plan_revision_judgement_payload(...)` / `request_plan_revision_judgement_async(...)` 通过 `POST /npc/plan_revision_judgement`，按 `trigger_kind` 把本轮完整对话或程序权威失败事实、判别基线计划和共享人物 / 记忆 / 指令 / 现实条件交给范围判别模型，并只接收精确 `revision_hours`；旧 dialogue 命名方法保留为兼容包装。
- `build_npc_daily_plan_payload(...)` 按 T1003 Schema 收集目标 NPC 共享上下文、当前 `current_order`、短期记忆、长期记忆、地点、广场、资源、建筑状态、行动白名单和计划规则。
- `request_npc_daily_plan(...)` 与 `request_npc_daily_plan_async(...)` 请求 `POST /npc/plan_day`；异步路径用于正式开局批量计划。
- `build_npc_plan_revision_payload(...)` / `request_npc_plan_revision_async(...)` 通过 `POST /npc/revise_plan` 处理判别选中小时或其他直接触发范围的计划修订，payload 使用 `revision_scope=selected_hours` 与精确 `revision_hours`。
- `request_npc_battle_judgement_async(...)` 与 `request_npc_daily_reflection_async(...)` 分别处理低血量心理判定和首次睡眠总结。
- 六类正式业务在 `requires_time_slowdown=true` 时注册 `TimeSystem.request_time_slowdown(...)`，成功、失败、取消或超时后调用 `release_time_slowdown(...)`；正式开局批量计划由 `GameStartupSystem` 全局暂停时间并显式关闭重复慢速。
- `build_npc_dialogue_payload(...)` 与共享 NPC 上下文构造会注入目标 NPC 最新 `current_order`；`get_last_npc_context_injection()` 暴露最近注入快照用于 GM / 自动化验证。

当前传输层不再依赖外部命令。health / usage 等只读短请求使用 2 秒响应超时；正式业务只使用 2 秒后端连接保护，连接成功并发出请求后不设置 Godot 响应总时长。后端关闭、供应商连接 / 空闲错误、非法 JSON 或 `ok=false` 都返回可处理错误字典。常规异步请求取消会立即释放慢速、清除 NPC LLM 活动并协作终止后台 HTTP 轮询，完成回调只发出已取消结果；场景退出则在节点释放前 join 全部线程而不再发信号。正式开局批量计划期间 TimeSystem 已暂停，因此计划请求不重复申请慢速。

T0703A/T1002/T1003/T0022 已将 `current_order` 接入共享 NPC 请求上下文、对话顶层 payload、每日计划请求和计划修订请求，由 `LLMBridge` 统一收集。Godot 保持当前指令、事件事实、行动白名单与结算的权威；后端只负责把该上下文传给模型并校验模型输出。计划修订仍使用独立异步修订链路；正式每日计划只应用真实 `llm_plan_day`，真实 provider 失败时记录错误并保持暂停，不落到 Mock 或规则计划。

验证脚本 `tools/verify_llm_bridge.gd` 覆盖后端关闭、health、对话、usage、慢速释放和退出生命周期静态合同；`tools/verify_llm_bridge_shutdown.gd` 使用本地悬挂 TCP 响应覆盖显式取消、退出拒绝新请求、协作终止与线程 join；`tools/verify_llm_time_slowdown_audit.gd` 覆盖六类正式业务的同步 / 异步慢速注册、释放和只读接口不降速；`verify_dialogue_plan_revision_judgement.py` / `_real.py` 覆盖通用判别层 Schema、Prompt、对话 / 行动失败分支与真实 provider；`verify_action_failure_plan_revision_judgement.gd` 覆盖 Godot 失败分支的空判别、精确选中小时、完整第二层上下文和派发屏障。既有对话与计划专项继续覆盖空集合恢复、旧回包丢弃及非工作模式延迟执行。

T0604 遇到的坑：

- Godot 原生 HTTP 的首次尝试在 headless 脚本验证中被信号等待和节点生命周期卡住；后续需要显式请求状态机、完成回调和超时。
- 同步等待异步 HTTP 结果会导致验证脚本挂起；所有成功、失败和超时路径都必须释放 TimeSystem 慢速请求。
- T0109 前取消请求只释放主线程状态，未通知工作线程退出，节点销毁时仍可能有 `HTTPClient.poll()` 持有旧 Callable；任何异步传输都必须支持协作取消，并由拥有线程的节点在 `_exit_tree()` 中 join。
- Windows 命令行直接传中文 JSON、引号和换行容易破坏请求体；T0604 才临时使用 `curl.exe` + 临时 JSON 文件。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端应返回 provider unavailable 或可处理错误；验证脚本如需 mock，必须显式使用 mock 或隔离环境，不能把该路径当成真实 provider 验收。
- 这些问题属于 Godot 传输层和开发验证环境问题，不是 NPC、记忆、Prompt 或前后端职责边界的问题。

## API Key

禁止把 API Key 写入仓库。  
真实供应商 API Key 默认只存在于服务器后端环境变量或后端 `.env`，并确保 `.gitignore` 忽略 `.env`。Godot 客户端不得保存、提交、导出或要求玩家在 Demo 阶段必须提供供应商 API Key。

使用真实 API Key 完成测试后，不要提交 `.env`、日志中的 Key、请求头或供应商密钥片段。生产 / 演示环境应关闭自动 mock fallback；无 Key 时应暴露配置错误，而不是返回 mock 内容。
## T0137 NPC 移动慢速权威边界

- `NPC.gd` 只在真实移动生命周期开始 / 结束处为每名 NPC 注册或释放 `npc_movement:<npc_id>`；它不创建第二套时钟，也不把 `current_action` 文本或表现动画冒充为移动事实。日常、室内、战斗集结 / 战术 / 避战和逃离仍由 NPCSystem / ActorMotionBody 下发同一实体运动。
- 移动请求复用 `TimeSystem.request_time_slowdown(..., -1.0, "npc_movement")`，因此倍率与 LLM 等待共享 `llm_wait_scale=1/60` 及最小值聚合。多 NPC、LLM 慢速和战斗上限可以并存；暂停只把 numeric multiplier 置零，不丢失尚未完成的移动请求。
- 角色物理运动继续消费真实 physics delta，避免慢速后走路再变成原来的 `1/60`；资源生产、建筑 / 制造进度、生活消耗、恢复、波次与其他权威模拟继续只消费 TimeSystem 已缩放的 `logical_time_tick`，所以不需要各自增加移动效率分支。

## T0173 陨石下落时间源边界

- PietySystem 的待落陨石属于短时战斗表现与落地触发器，使用 `_process(real_delta_seconds)` 推进，不消费受 NPC / LLM 慢速影响的 `logical_time_tick`；否则 `1/60` 慢速与战斗秒换算会叠乘，把 2.8 秒下落放大到约 168 秒。
- 现实时间推进前必须只读检查 TimeSystem `is_gameplay_paused()`，保证玩家主动暂停仍冻结陨石；燃烧区继续消费逻辑 tick，权威冲击 / 燃烧伤害继续只调用 CombatSystem。
- GM `debug_advance_effects(game_seconds)` 保留显式确定性推进能力，同时推进待落陨石与燃烧区，仅用于测试和观察，不成为第二套自然运行时钟。
## T0213 友方马匹返厩运动权威

- HorseSystem 继续独占马匹位置、分配与骑乘状态，但不再自行用向量插值移动马匹。脱离骑乘后，它为该马创建无表现的 ActorMotionBody，并只提交返厩意图、数据化步行速度与抵达后的马槽提交；路径、NavigationAgent、RVO、室内出口前缀、速度上限和实体位移仍由 ActorMotionBody 独占。
- 下马帧的骑手和马共享一个物理原点。马匹 Body 保留 world-static 硬碰撞，actor 间使用 RVO 而不让新马体对骑手胶囊做 CharacterBody 解重叠；否则运动层会在首帧制造近一米弹跳。该差异只处理骑乘拆分，不授予穿越静态实体、瞬移或伤害权限。
- 返途中再鸣警由 HorseSystem 取消马的活动 request 并保持物理体，NPCSystem 接收马旁可达点并用其原 ActorMotionBody 前往。HorseSystem 只有在真实到达容差内才提交骑乘，随后释放马匹运动体并通知 CombatSystem 恢复原 rally / combat 目标。
