# Character Art Scenes

共享人形包装、8 名 NPC 外观组合、敌人外观和装备挂点场景。逻辑状态仍由 NPCSystem / CombatSystem / EquipmentSystem 维护。

T0128 的 `GlenArtView.tscn` 是首个正式实例：Quaternius 基础体、农民服装、短发与 UAL2 rig，加上 AnimationTree、六个 BoneAttachment3D、低模锤子、选择 / VFX / ragdoll 接口。T0129 又补上血粒子、受击回弹和带物理冲量的受控倒地，并复用同一包装作为每波第一名剑盾敌人样片；A5-P5a–P5h 已在同一包装上落地其余 7 名初始 NPC 的独立配色 / 无锤外观。A5-P5i 再增加站立主持与长凳坐姿祈祷两个只读循环；Standard 动画包没有原生坐姿祈祷片段，当前以 Rail idle 与局部姿态偏移组成低配占位，不承担礼拜或虔诚权威。

T0130-P0 新增 `GlenChibiPilot.tscn` 与 `EnemySwordShieldChibiPilot.tscn`：Synty 迷你人物作为可见模型，KayKit Medium Rig 作为隐藏动画源，通过 Godot 4.6 人形重定向复用共享状态合同；该试片已于 2026-08-20 获用户通过，P7R 后合同增至 18 状态。

T0130-P1 新增不带独立碰撞的 `GlenChibiArtView.tscn` 与 `EnemySwordShieldChibiArtView.tscn`，分别接入正式格伦与步行剑盾敌人。碰撞、点击、导航和权威状态仍属于父级 NPC / ActorMotionBody；其余 NPC 与敌种继续使用 Quaternius 回退，等待逐个迁移。

T0130-P1R 确认当前 Synty 可见模型以本地 `+Z` 为正面，而项目运行时合同使用角色根本地 `-Z` 指向目标。共享 `ChibiCharacterPilot.gd` 在 VisualRoot 层固定补偿 `180°`；后续包装不得把该差异写入父级导航、碰撞、工位或攻击朝向。

T0130-P2 新增 `TomaChibiArtView.tscn`：Adventure Peasant 棕白劳动者模型、`Working_B` 循环与右手马刷式清洁工具。生产包装不带碰撞，只有正式 `work_stable` 到岗后显示工具；交谈、受击、昏迷 / 起身和未来 `vehicle_seated` 继续复用共享状态合同。

T0130-P3 新增 `BrunoChibiArtView.tscn`：Adventure ShopKeeper 暖红白围裙厨师模型、`Working_C` 循环与右手木柄铜勺。生产包装不带碰撞，只有正式 `work_dining_hall` 到岗后显示厨具；真实 `seated_eating`、移动、受击和昏迷均隐藏厨具。

T0130-P4 新增 `IvoChibiArtView.tscn`：Pirates Deckhand 瘦削户外劳动者模型、低饱和绿土配色、`Digging` 循环与程序化木柄铁锄。生产包装不带碰撞，只有正式 `work_garden` 到岗后显示园锄；真实长凳祈祷、移动、交谈、受击和昏迷均隐藏园锄。

T0130-P4R 将伊沃从会把整块头巾染绿的主题图集切到中性土色基础图集，并按完整 `Digging` 周期重校园锄轴向；锄柄进入双手工作区，锄刃保持在人物前方。专项不再只验证 RightHand 父节点。

T0130-P4R2 将伊沃改为复制 Deckhand 原导入 BaseMaterial3D，绑定 `PolygonMinis_Texture_01_A.png` 并保留 `vertex_color_use_as_albedo`，恢复作者原生双眼和棕土头巾；既有园锄、动作、碰撞与权威链不变。

T0130-P5 新增 `AdaChibiArtView.tscn`：Vikings ShieldMaiden 女性轻装老兵轮廓、冷灰蓝低饱和色板、权威主武器驱动的右手剑 / 左手盾与循环 `Melee_Block_Attack` 执教。共享合同增至 16 状态，真实固定床挂接使用 `sleeping -> Lie_Idle` 并收起武器；换装、战斗、昏迷和复苏仍只读父级权威。

T0130-P5R2 已撤销被用户否决的程序化面部。艾达复制 ShieldMaiden 原导入 BaseMaterial3D，保留 `vertex_color_use_as_albedo` 和原生眉眼 / 嘴部，只把 Albedo 切到 `PolygonMinis_Texture_Blue_A.png` 并压暗；不得再在 Head 上叠加自制眼睛或嘴部遮盖。

T0130-P6 新增 `MarcelChibiArtView.tscn`：Fantasy Wizard 的年长原生脸、灰白胡须和完整长袍，包装按连通拓扑移除分离尖帽 114 个三角面，以 `Purple_A` 作者材质和 Body 木质圣徽收束为边境神父。`Working_A / Ranged_Magic_Spellcasting_Long / Sit_Chair_Idle` 分别只投影真实酒窖、祭坛和长凳行动；场景不带碰撞、选择体或其他职业工具。

T0130-P6R 为马塞尔单独开启默认关闭的 Head 灰白低模圆冠，补齐尖帽移除后暴露的平顶。圆冠按目标骨架模型空间校准并随 Head 动作，正面不遮眉眼、侧面与原长发相交；只有一个表现 Mesh，不带碰撞、Area、选择面或玩法状态。

T0130-P7 新增 `LinaChibiArtView.tscn`：Pirates GovDaughter 的束发、原生眉眼、冷蓝长外衣与浅色围裙形成医生轮廓；`medical_kit` 常驻 Body 药包，真实诊所值班以 `Working_B` 显示病历册，真实协助治疗以新增 `medical_treatment / Working_A` 显示绷带。三个附件均无碰撞，生产场景继续复用父级 NPC 实体、交互与导航。

T0130-P8 新增 `OwenChibiArtView.tscn`：Pirates Firstmate 的短壮工头轮廓、原生眉眼 / 胡须与压暗土色工装；`engineering_kit` 常驻 Head 铜框护目镜及 Body 工具带，真实工械装配、外沿修复或升级到位后才以 `Working_A` 显示 RightHand 短扳手。正式剑盾装备继续只读 EquipmentSystem 显隐；场景不带碰撞、选择体、导航或工程结算。
