# Presentation Layer Scripts

本目录保存只消费权威状态的表现层脚本，例如建筑屋顶透明、角色动画、装备挂点、VFX、环境和 UI 表现适配。

T0125 的 `ArtSandbox.gd` 负责导入材质标准化、rim / outline、代表动画和沙盒相机。T0126 的 `buildings/RoofVisibilityController.gd` 与 `BuildingArtView.gd` 已进入 Main 表现节点和建筑包装合同；T0135-P7R 后渐隐壳体采用“透明可见 Mesh + internal shadows-only 同 Mesh 代理”，镜头拉近不再取消太阳 / 月亮实体阴影，代理不进入 authored mesh 计数或玩法系统。T0127 的旧 4×4 铁匠铺只保留兼容。T0128 / T0128A 的 `characters/NPCArtView.gd` 负责格伦骨骼重绑、源朝向归一化、实例本地循环动画库、九状态 AnimationTree、六挂点、锤子显示、路径朝向、暂停和 HP / 昏迷边沿表现。T0129 的 `FormalBlacksmithArtView.gd` 已把垂直切片迁到正式 14×12 m 房体，消费正式 fixture / 碰撞 / 导航并控制三级可见性；`SmithyAmbientFX.gd` 驱动炉火、灯光、烟、火星和风箱，NPCArtView 继续提供血粒子、受击回弹和受控倒地冲量。

T0129A 的 `StationSpatialSandbox.gd` 只读取 `station_spatial_plan.json`，在独立场景生成不规则墙体、分段道路、八方向地块 / 常显名称、最高等级实物占地 / 通道叠层、真实低位河槽、MultiMesh 全幅森林与聚焦视图，并汇总只读验证快照。`StationEnemyStressSimulation.gd` 为第五波 48 人创建 presentation-only 物理包络并跑完整进攻路线；`StationEscapeStressSimulation.gd` 沿后门到地图边缘的 6 点路径核算干预窗口。它们不读写 Main 运行态，不创建地点 / 工位事实，也不调用战斗或离站权威结算。

表现层不得自行决定资源、HP、伤害、建筑等级、地点、工位占用、事件或记忆事实；这些仍由 `scripts/systems/` 中的权威系统维护。

T0135-P1R2 由 `environment/FormalGroundSurfaceArtView.gd` 生成连续深草、浅排水、12 个碎石簇和 58 个短植被簇；首版多环广场与入口贴片保持删除，广场只由既有道路自然拓宽形成。`environment/FormalStationDetailArtView.gd` 另按建筑功能生成 10 个室外生活杂物组，二者均不创建 StaticBody、Area3D 或 NavigationRegion3D。

T0135-P2 新增 `environment/FormalTerrainArtView.gd`：用配置化河流横截面生成断开的东西岸、分层岸坡、低位河床和动态水面；旧直河盒与跨河自然底板退出显示。岸坡岩石只作轮廓破形，河岸完整植被散布留到 P5。

T0135-P3 在同一 `FormalTerrainArtView` 组合近 / 中 / 远三层东侧 RidgeMesh，并用无碰撞低模岩石打破坡面；旧四段山脊盒只保留碰撞权威、退出显示。前后密林与山脚松林继续由 P4/P5 的散布层负责。

T0135-P4R 的 `environment/FormalForestArtView.gd` 使用 369 个 MultiMesh 区块生成 7393 棵高瘦松 / 标准松 / 宽冠冷杉和 4076 丛灌木；围墙近侧疏、远处密，河岸和山体分别降密，原中央空白横带已补齐。阔叶树不再加载，旧 Dense Forest 稀疏程序树退出显示，12 段碰撞权威保留。

T0135-P5 的 `environment/FormalEnvironmentScatterView.gd` 按河岸、山脚、林下、道路边缘和城内空地生成 4375 个低模草 / 蕨 / 灌木 / 岩石实例，并用合并贴地网格完成湿痕、苔藓和泥肩过渡；所有候选统一排除河槽、道路核心、建筑地块、公共地点与正式敌 / 商 / 逃路线，节点保持 presentation-only。

T0135-P6/P7/P7R5/R6 的 `environment/CelestialCycleController.gd` 只读 GameState 绝对时刻，为正式环境根生成日月方向光、唯一动态 WorldEnvironment、ProceduralSky、全局雾及前后林缘 / 河谷 / 东山脚十二个错位椭球 FogVolume；夜雾 `17:30–21:00` 渐入、`04:30–07:30` 渐出，不推进时间或维护累计角度。P7 还只读 RoofVisibilityController，在七座封闭建筑下管理当前七盏有影向下补光；所有环境、雾和补光节点保持 presentation-only。

T0130-P4R2 为动作沙盒增加 `--t0130-capture-ivo-face` 正面近景参数，用实际 D3D12 渲染核对 Deckhand 原生眼睛；该参数只隐藏其他预览角色并重构沙盒相机，不接入 Main 或修改 NPC 状态。

T0130-P6 为共享 `ChibiCharacterPilot` 增加默认关闭的分离头饰拓扑过滤、Body 木质圣徽与包装级 `mass_leader_clip`；马塞尔开启这些选项，其余角色默认行为不变。`ChibiCharacterSandbox.gd` 现并排驱动七角色，工作 / 生活两组分别显示马塞尔酿酒与主持弥撒，仍不连接权威系统。

T0130-P6R 增加默认关闭的 `show_rounded_tonsure_hair`：按 Head global rest 把单个低分段 SphereMesh 校准为模型空间灰白圆冠，仅马塞尔开启。沙盒支持 `--t0130-capture-marcel-head / --t0130-capture-marcel-side` 与既有状态参数组合做正面、侧面和动作抓图；该附件没有碰撞或状态回写。

T0130-P7 为共享 `ChibiCharacterPilot` 增加第 17 个 `medical_treatment` 状态与 `medical_kit` 附件模式；P7R 再增加第 18 个 `seated_study`，使无病人的正式诊所工作挂接椅子、循环坐姿并显示病历册，有病人时则在真实病床侧显示绷带治疗。药包常驻但全部附件无碰撞；`assist_heal_<target>` 前缀只读已有 active 行动，不能开始治疗。动作沙盒扩为八角色，并增加 `--t0130-capture-lina` 单人抓图。

T0130-P8 为共享 `ChibiCharacterPilot` 增加 `engineering_kit` 附件模式。欧文常驻无碰撞护目镜和工具带，只有真实抵达工械坊工位或修复 / 升级服务位并进入 active 后才显示短扳手、循环 `Working_A`；训练与战斗继续只读既有装备状态。动作沙盒扩为九个对象（8 NPC + 剑盾敌人），并增加 `--t0130-capture-owen` 单人抓图。

T0130-P8R2 将欧文护目镜拆为额头和眼前两套 Head 骨空间姿态。只有真实工械坊制造 active 才缓动戴到眼前；维修 / 升级仍只显示扳手，不改变护目镜姿态。快照暴露当前 `forehead / worn`，便于正式链和视觉回归区分。

T0131-P1 新增 `buildings/FormalWorkshopArtView.gd`。它只为正式 Workshop 生成完整 Quaternius 外壳、室内背景道具和三级结构增量，并把 BuildingSystem 等级投影到现有 FixtureLayout 的视觉与碰撞；路线、NavMesh、制造、容量、地点、事件和点击选择权威仍分别归 StationLayoutController / BuildingSystem / CraftingSystem / NPCSystem。屋顶与 Exterior 使用 `70→58 m` 同步透明，透明后复用 BuildingSystem 的内部 NPC 优先点击合同。

T0131-P4 新增 `buildings/FormalDiningHallArtView.gd`。它只生成正式食堂外壳、后厨排烟、边缘生活陈设和三级结构增量，并把 BuildingSystem 等级投影到既有食堂 fixture 的显示 / 碰撞；灶台、十席、资源和行动权威不变。`StationLayoutController` 仅为两个 `primitive_visual=dining_table` 生成正式厚木公共餐桌，不创建新座位或工位。

T0131-P5 新增 `buildings/FormalDormitoryArtView.gd`。它生成正式宿舍五段长屋、十套个人生活陈设和 Lv.2 壁炉 / 保温 / 修补增量，并把两级表现投影到始终固定的 10 张床；1–8 号归属、9–10 号预留、真实到床、占用和疲劳恢复仍由 BuildingSystem / NPCSystem / ActionSystem / NPCNeedsSystem 决定。屋顶、墙体、二级烟道与顶梁统一透明，自动门不拥有通行事实。

T0131-P6/P6R 新增并丰富 `buildings/FormalTavernArtView.gd`。它生成正式半石砌酒窖、发酵作坊背景、装饰储藏桶 `6→11→14` 和两级熟成 / 扩产增量，并把既有 fixture 按 `4→5→6` 投影；酿酒容量仍由 BuildingSystem 严格控制为 `2→2→3`。装饰桶显式为非工位、非库存表现；真实到桶、扣粮、产酒和出售分别仍归 NPCSystem / ActionSystem / ResourceSystem / MerchantSystem，表现层只负责壳体、透明、自动门和只读等级预览。

T0132-P3/P3R/P3R2/P3R3/P3R4 新增 `buildings/FormalFortificationArtView.gd` 与 `FormalGateArtView.gd`。前者为正式 14 段围墙生成木板幕墙、立柱 / 束梁 / 斜撑、巡逻道、木垛口、六级增量和与 `wall_slot_01–04` 重合的四个木制器械台，石材仅为低基脚；P3R2 将四台移到正门左右墙段，P3R3 删除升级悬挂盒体，P3R4 让左右平台 / 横杆 / 旗面分别吸附 `north_west_a / north_east` 实际墙切线。后者生成大小有别的木制正后门门楼和带碰撞双门叶，只允许我方 NPC / 后门商队触发，敌军过滤且战斗中正门锁闭。两者均不拥有建筑 HP、槽位、射程、攻击、商人到达或逃离权威。
