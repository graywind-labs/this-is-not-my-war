# GM_PANEL.md

## T0132-P3 围墙与正后门美术验收

- 建筑分组新增“围墙美术预览（不改权威等级）”六个按钮，命令为 `wall_art_level 1|2|3|4|5|6`；只切换围墙平台与升级装饰，不修改 BuildingSystem 等级 / HP / 升级进度或 DefenseDeviceSystem 部署 / 射程。
- Lv.1 / 2 / 4 / 6 应分别看到第 1 / 2 / 3 / 4 个实体器械台；Lv.3 与 Lv.5 只增加测距杆、标定旗和加固，不应出现新平台。六级平台总数必须为 `1/2/2/3/3/4`。
- P3R 视觉基线为木栅寨墙：连续木墙板、粗立柱、双面束梁、斜撑、木巡逻台 / 垛口与木制器械台；石材只应在墙脚和门塔脚形成低矮基垫，不得看到连续石墙、石塔身或石制器械台。
- P3R2 后四台必须形成正门左右各两台的墙上防御带；门洞、门楣和双守卫塔上不得有器械台。中央两台与门塔之间应看见明确缝隙，部署后的弩床 / 箭塔必须落在同一墙台中心。
- P3R3 后切换任意等级都不应在前墙外侧看到独立灰色长柱、薄长方板、灰色压条或大块悬挂木板；Lv.2 / 4 / 6 只通过新增墙上平台表达扩槽。
- P3R4 后靠铁匠铺的右侧两台平台、Lv.3 横杆和 Lv.5 旗面必须顺着右墙向右上方排列；左侧附件继续顺着左墙。任何一侧都不得再平行于城门横轴而横切脚下墙段。
- “城门快照”或命令 `gate_art_snapshot` 显示正后门净宽、门楼高度、开门比例、附近友军、战斗锁闭和门毁状态。正门应为 `6 m` 且明显高于后门 `5 m`；我方 NPC 接近时门扇打开，离开约 `1.15 s` 后关闭，敌军不触发，后门商队可触发。真实受击仍用 `damage_building front_gate <amount>`，纯表现快照不结算伤害。

## T0132-P2 仓库三级美术验收

- 建筑分组新增“仓库美术预览（不改权威等级）”三级按钮，命令为 `warehouse_art_level 1|2|3`。入口只调用 `WarehouseArt.debug_force_visual_level(...)`，不消耗石料，不修改 BuildingSystem 真实等级 / HP / 升级进度，也不修改 ResourceSystem 容量、库存或 CombatSystem 敌军目标。
- Lv.1 看封闭石基木构货栈、单一连续烟熏灰褐瓦顶 / 一条主屋脊、双扇装卸门、吊运架 / 雨棚 / 车辙与五组基础分类储藏；Lv.2 增加采用同一低饱和屋顶配色的东侧仓、外部高架和角部铁件，分类 fixture 为 6；Lv.3 增加同色单屋脊瓦顶的后部挑高安全仓、军需 / 贵重货物陈设与通风帽，分类 fixture 为 7。三层均保留原生瓦片纹理、保持屋顶不透明、零 NPC 工位，分类货物不代表实时库存数量。
- 受损验收继续用 `damage_building warehouse <amount>` 与 `repair_building warehouse`；容量验收使用仓库面板 / HUD 既有权威显示。纯表现预览与真实升级、容量和受击调试保持分离。

## T0132-P1 主厅六级美术验收

- 建筑分组新增“主厅美术预览（不改权威等级）”六个按钮，命令为 `main_hall_art_level 1|2|3|4|5|6`。它只切换 `MainHallArt` 表现层及对应 fixture 可见 / 碰撞，不消耗材料，不修改 BuildingSystem 真实等级、HP、升级进度或 DefenseDeviceSystem 部署。
- Lv.1 看完整低翼指挥厅、中央门楼、旗帜 / 盾徽与首个平台；Lv.2 看不挡正面窗、与墙基相接的侧后扶壁与基础铁带；Lv.3 看第二平台和屋顶通道；Lv.4 看安装在屋脊石座和铁脚上的酒红燕尾守备旗，不应再出现灰色方块、火盆、发光球或警灯轮廓；Lv.5 看第三平台与西侧侦望扩展；Lv.6 看第四平台，以及具备实体贴图墙身、木构、窗洞和主厅同色瓦顶的门楼指挥塔。主厅不可进入，近景屋顶也不会透明。
- 受损验收继续用既有 `damage_building main_hall <amount>` 和 `repair_building main_hall`：中度损伤出现裂纹 / 破布，重度损伤追加碎石 / 烟尘，修复后消失。这两条是权威调试命令，与纯表现等级预览分开。

## T0131-P9 马厩逐级美术验收

- 建筑分组新增“马厩美术预览（不改权威等级）”三级按钮，命令为 `stable_art_level 1|2|3`。它只调用 `StableArt.debug_force_visual_level(...)`，不消耗升级材料，也不修改 BuildingSystem、HorseSystem、马匹位置、照料位或事件。
- Lv.1 应看到露天夯土马院、七个开放马栏 / 锚点、宽低门、中央牵马通道、两处真实照料位、当前两匹实际在厩马及清扫 / 洗刷 / 基础草料与马具；Lv.2 增加共享草料、鞍具、干草、修蹄、饮水与后排饲料架，但仍只有两处照料位；Lv.3 才增加第三照料栏、第八锚点、产驹 / 恢复和后勤扩展。
- 真实流程继续使用“托马→真实照料 / 停止 / 快照”。美术预览只验外观；要验养马必须继续游戏，待托马实体通过马厩门、到达真实马旁并提交占用后观察周期动作与 HorseSystem 状态。马厩始终露天可点内部 NPC，近景只淡出边缘遮棚。

## T0131-P8 训练场逐级美术验收

- 建筑分组新增“训练场美术预览（不改权威等级）”三级按钮，命令为 `training_ground_art_level 1|2|3`。它只调用 `TrainingGroundArt.debug_force_visual_level(...)`，不消耗升级材料，也不修改 BuildingSystem 的真实等级、HP、教官 / 训练位、技能或事件。
- Lv.1 应看到露天夯土训练院、低石基木栅、低矮自动训练门、一号教官棚 / 指挥旗、两个训练木桩、武器架、箭靶、兵器维护和饮水急救；Lv.2 增加第三训练位、盾墙、挡箭网、护具和器材棚，但仍只有一个教官位；Lv.3 才增加第二教官指挥配套、第四训练位、进阶兵器与入口荣誉旗。
- 真实流程继续使用“艾达→真实执教 / 格伦→真实受训 / 停止 / 快照”与 `formal_training_work`。美术预览只验外观；要验训练必须继续游戏并满足装备 / 入伍条件，待两人分别实体到位后观察真实动作与技能成长。训练场始终露天可点内部 NPC，近景只淡出三个小遮棚。

## T0131-P7 菜园逐级美术验收

- 建筑分组新增“菜园美术预览（不改权威等级）”三级按钮，命令为 `garden_art_level 1|2|3`。它只调用 `GardenArt.debug_force_visual_level(...)`，不消耗升级材料，也不修改 BuildingSystem 的真实等级、HP、粮食、工位、占用或事件。
- Lv.1 应看到两块真实田畦、深色园土、低石基木篱、低矮自动园门、东侧开放农具棚、种子 / 收获角、药草槽和稻草人；Lv.2 增加灌溉水沟 / 堆肥、蓄水与配水、育苗收纳，但仍只有两处耕作位；Lv.3 才增加第三块田畦、第三灌溉支路、作物支架和收获分拣扩展。
- 真实流程继续使用“伊沃→真实耕作 / 停止 / 快照”与 `formal_garden_work`。美术预览只验外观；要验生产必须继续游戏，待伊沃实体到达田畦开放面并提交占用后观察循环锄地与粮食变化。菜园始终露天可点内部 NPC，近景仅农具棚顶淡出。

## T0131-P6 酒窖逐级美术验收

- 建筑分组新增“酒窖美术预览（不改权威等级）”三级按钮，命令为 `tavern_art_level 1|2|3`。它只调用 `TavernArt.debug_force_visual_level(...)`，不消耗升级材料，也不修改 BuildingSystem 的真实 Lv.1、HP、粮食、酒、工位或事件。
- Lv.1 应看到半石砌酒窖、酒红低坡屋顶、两只发酵通风帽、两套发酵桶、共享空桶架 / 验酒桌和基础瓶装 / 清洗 / 制桶陈设；Lv.2 增加熟成架、冷却水槽、铜管、批次板、石砌加固和外部遮阴桶架，但仍只有两处酿酒位；Lv.3 才增加第三发酵桶、第三支管 / 清洗、第三通风帽和装卸架。
- 真实流程继续使用已有“马塞尔→真实酿酒 / 停止 / 快照”与 `formal_tavern_work`。美术预览只验外观；要验生产必须继续游戏并确保有粮食，待马塞尔真实到桶外站位后观察周期动作和库存变化。

## T0129C-A5-P8 正式空间检查点

- 建筑分组新增“保存空间 / 读取空间 / 存档快照”，命令为 `formal_spatial_save save|load|snapshot`，默认文件为 `user://formal_spatial_checkpoint.json`。
- `save` 记录 8 名 NPC 的最后正式坐标 / 地点 / 物理阶段、活动波次存活实体、逃离意图和行商阶段；`load` 先同步生产导航，再安全回滚在途工作 / 工位 / 挂接，最后分别恢复波次、逃离和行商。
- 读取不是行动重放：不会补资源、伪造工位到达或重复广播地点 / 行商事件。可在在途工作、活动第一波、NPC 逃离和马车进场期间保存，然后重新进入 Main 后读取验证。

## T0129C-A5-P7 默认正式世界总切换

- 建筑分组显示“恢复默认正式世界 / 临时旧图兼容 / 布局快照”，命令继续使用 `station_layout preview|legacy|snapshot`。新局已经处于正式世界；`preview` 表示恢复默认正式权属，`legacy` 才是临时开发兼容。
- `legacy` 会中断当前正式行动、保存各 NPC 最后正式坐标、恢复旧坐标 / 旧相机、停用正式 Region / Link，并令行商改用 2 点兼容路线；不回滚资源、事件或建筑状态。`preview` 重新启用正式图，把未逃离 NPC 放回保存点或正式初始锚点并绑定生产 NavigationMap，同时恢复 5 点商路。
- `snapshot` 同时显示布局开关和默认正式居民快照；正常新局应为 8 个 actor、导航启用且地图匹配、坐标 `x>900`。

## T0129C-A5-P6d-3 真实协助治疗

- 行动分组复用治疗者 / 昏迷目标选择器，提供“真实协助治疗 / 停止真实治疗 / 真实治疗快照”；命令为 `formal_heal_assist run <healer_npc_id> <target_npc_id>`、`stop <healer_npc_id>`、`snapshot <healer_npc_id> [target_npc_id]`。
- `run` 要求游戏已继续，只调用 `ActionSystem.debug_assign_heal_assist(...)`。治疗者会真实进入目标信息地点并接近目标 Body；途中不扣首枚第纳尔、不加入 helper、不恢复 HP 或写开始事件。
- `snapshot` 同时显示运行态、formal healing session、双方 NPC、helper、资金和距离；`stop` 走既有中断接口。GM 不传送、不添加 helper、不扣费、不恢复 HP，也不自行选择接近位。

## T0129C-A5-P6d-2 真实升级协助

- 建筑分组复用 NPC / 升级目标选择器，提供“真实升级协助 / 停止真实升级 / 真实升级快照”；命令为 `formal_upgrade_assist run <npc_id> <building_id>`、`stop <npc_id>`、`snapshot <npc_id> [building_id]`。
- `run` 要求游戏已继续，并要求目标已有升级工程；只调用 `ActionSystem.debug_assign_upgrade_assist(...)`。途中 upgrade helper、倍率、经验和 `upgrade_assist_started` 均不得变化。
- `snapshot` 同时显示运行态、formal session、NPC 状态和升级作业；`stop` 走既有中断接口。GM 不补资源、不开始升级工程、不传送、不选择施工槽或推进倒计时。

## T0129C-A5-P6d-1 真实修复目标

- 建筑分组复用 NPC / 修复目标选择器，提供“真实修复目标 / 停止真实修复 / 真实修复快照”；命令为 `formal_repair_assist run <npc_id> <building_id>`、`stop <npc_id>`、`snapshot <npc_id> [building_id]`。
- `run` 要求游戏已继续，只调用 `ActionSystem.debug_assign_repair_assist(...)`。NPC 会从当前室内真实出门并走到建筑外沿独立维修位；途中 helper 数、倍率、经验和 `repair_assist_started` 均不得变化。
- `snapshot` 同时显示行动运行态、formal session、NPC 状态和目标修复作业；`stop` 走既有中断接口。GM 不传送、不添加 helper、不推进修复，也不自行选择槽位。

## T0129C-A5-P6c 真实找人对话

- 行动分组使用上方 NPC 作为发起者，并新增独立目标 NPC 选择器、“真实找人对话 / 停止真实对话 / 真实对话快照”。命令为 `formal_npc_dialogue run <speaker_npc_id> <target_npc_id> [opening_text]`、`stop <speaker_npc_id>`、`snapshot <speaker_npc_id>`。
- `run` 要求游戏已继续，只调用既有 `ActionSystem.assign_npc_dialogue(...)`；发起者会实际跨门并走到目标实体约 `1.35 m` 处。GM 不传送、不接受邀请、不释放目标工位，也不伪造 LLM 回复。
- `snapshot` 同时显示 ActionSystem 运行态、formal dialogue session、双方空间快照和 DialogSystem 会话；`stop` 通过既有行动 / 对话结束接口清理。验证邀请 pending 时目标仍工作且工位仍占用，接受后才释放。

## T0129C-A5-P6b 无工位真实拜访

- 行动分组复用 NPC / 地点选择器，新增“真实拜访 / 停止真实拜访 / 真实拜访快照”，命令为 `formal_visit run <npc_id> <location_id>`、`formal_visit stop <npc_id>`、`formal_visit snapshot <npc_id>`。
- `run` 要求游戏已继续，只调用 `ActionSystem.assign_visit_location(...)`；不传送、不写地点、不申请工位。途中快照应为 pending + formal session，当前地点保持最后已物理提交地点；到达后才显示 active 与目标地点。
- `stop` 中断行动并保留最后已提交地点的正式位置；`snapshot` 同时显示运行态、formal session、空间快照和 NPC 状态。GM 不直接添加 `location_entered / visit_started` 或推进停留时长。

## T0129C-A5-P6a 宿舍真实睡眠

- 建筑分组新增“艾达→真实睡眠 / 停止真实睡眠 / 真实睡眠快照”，命令为 `formal_dormitory_sleep run|stop|snapshot`。入口要求游戏已继续，只派发 `ActionSystem.debug_assign_action("veteran_deputy_01", "sleep_in_dormitory")`。
- `run` 不传送、不占床、不改疲劳；途中快照应为 `pending / dormitory_bed_01 reserved_by=veteran_deputy_01`，且没有 `sleep_started`。真实到床后才显示 occupancy、`occupant_anchor / sleeping_supine` 和 active。
- `snapshot` 同时显示运行态、正式会话、NPC、宿舍工位与首次睡眠窗口；`stop` 中断本次行动并清理床位 / 挂接 / 会话，停止瞬间不额外恢复疲劳。
- T0130-P5 后同一入口也是艾达两头身真实睡眠验收入口：到床后 `character_art` 应为 `ada_veteran_deputy_chibi_v1 / sleeping / Lie_Idle`，并显示 `spatial_attachment_pose=sleeping_supine`、剑盾隐藏；停止后姿态清空且权威剑盾恢复可见。

## T0129C-A5-P5j 食堂真实用餐

- 建筑分组新增“布鲁诺→真实用餐 / 停止真实用餐 / 真实用餐快照”，命令为 `formal_dining_eat run|stop|snapshot`。入口要求游戏已继续，只调用 `ActionSystem.debug_assign_action("cook_01", "eat_at_dining_hall")`；不补资源、不传送、不直接写座位或饱食。
- 无 `meal / grain` 时应在迁移前失败，GM 窗口保持可见；有食物时窗口关闭，途中快照为 pending + reservation，库存与 `eat_started` 不变。到 `dining_seat_01`（或当时首个空席）后应显示 occupancy、`occupant_anchor / sitting`、循环 `seated_eating`，并只扣实际选择的一份食物。
- `snapshot` 同时显示运行态、正式会话、NPC、餐食 / 粮食与全部食堂工位；`stop` 只中断布鲁诺本次行动，释放自身席位、挂接和正式会话。已开始用餐所扣食物不回滚，停止瞬间不额外结算饱食。

## T0129C-A5-P5i 小教堂真实礼拜

- 建筑分组新增“伊沃→真实祈祷 / 马塞尔→真实主持 / 停止礼拜样片 / 礼拜真实快照”，命令为 `formal_chapel_work prayer|leader|stop|snapshot`。入口要求游戏已继续，只调用 ActionSystem，不传送、不直接写席位、模式、事件或虔诚。
- 推荐先让伊沃祈祷：途中只有 reservation / pending 且零虔诚；到长凳提交 `chapel_prayer_seat_01` 后才挂接坐姿并独祷。再派马塞尔主持，祭坛到位后伊沃应在同一席位原地转为参礼，二人共同贡献虔诚。
- `snapshot` 同时显示双方运行态、正式会话、NPC、小教堂工位与 PietySystem；`stop` 先中断主持者，用于观察祈祷者保留进度和席位恢复独祷，再清理两人会话。跨小时计划应显示延后，不能把主持 / 参礼提前中断。
- T0130-P4 后同一入口也是伊沃正式两头身祈祷验收入口：`prayer_character_art` 应显示 `appearance_id=ivo_gardener_chibi_v1 / desired_state=seated_prayer`，长凳挂接期间园锄必须隐藏；坐姿偏移只影响模型，不得改变虔诚或席位事实。

## T0129C-A5-P5h 艾达与格伦真实训练

- 建筑分组新增“艾达→真实执教 / 格伦→真实受训 / 停止训练样片 / 训练真实快照”，命令为 `formal_training_work instructor|student|stop|snapshot`。入口要求游戏已继续，只调用 ActionSystem，不传送、不直接改技能或工位。
- 艾达必须装备主武器或坐骑；格伦还必须已入伍并装备训练项目。推荐先点教官，再点学员；教官在途期间学员可以预留训练位并等待，但双方到位前均不成长。
- `snapshot` 显示双方运行态、正式会话、NPC 档案和训练场工位；`stop` 先让艾达离岗，验证最后教官离开会使格伦立即以 `training_student_failed_instructor_left` 失败，再清理两方会话。
- T0130-P5 后艾达到岗时 `character_art` 应显示 `ada_veteran_deputy_chibi_v1 / training_instructor / Melee_Block_Attack`，权威主武器为剑盾时右手剑 / 左手盾可见；该循环只表现示范，不产生额外技能或攻击事实。

## T0129C-A5-P5g 莉娜真实坐诊与患者病床

- 建筑分组新增“莉娜→真实坐诊 / 布鲁诺→真实病床 / 停止诊所样片 / 诊所真实快照”，命令为 `formal_clinic_work doctor|patient|stop|snapshot`。两个派工入口要求游戏已继续；成功后关闭 GM 窗口，只调用 ActionSystem，不传送、不直接扣血、回血、扣钱或写工位。
- 验证患者前，先用既有 NPC 扣血入口制造真实伤情，并先让至少一名医生在途或在岗。医生 / 患者 pending 时只预留桌 / 床；到位提交占用后医生循环坐诊，患者才躺到床面并开始既有治疗。无患者的医生仍可研读医术。
- `snapshot` 同时显示两人的运行态、正式会话、NPC 状态、诊所工位、资金和团队每小时治疗率。`stop` 先中断医生；若这是最后一名医生，患者应立即失败、下床并释放病床，然后两人均保留正式位置。

## T0129C-A5-P5f 马塞尔真实酒窖生产

- 建筑分组新增“马塞尔→真实酿酒 / 停止真实酿酒 / 真实酿酒快照”，命令为 `formal_tavern_work run|stop|snapshot`。游戏继续且至少有 1 份粮食时可启动；入口不补资源、不卖酒、不改钱，成功派工后关闭 GM 窗口。
- pending 期间只建立正式会话并预留当前等级首个合法 `brew`。马塞尔实体进入酒窖、抵达发酵桶外安全站位并提交占用后才循环工作；途中不扣粮、不产酒，完整周期按既有酿酒、智力和酒窖等级公式原子结算。
- `snapshot` 显示 ActionSystem 运行态、NPCSystem 正式会话、粮食 / 酒和酒窖工位；同一真实日计划原位续作，`stop` 与统一中断释放酒桶并保留正式位置。此入口只选择马塞尔作代表，不限制其他 NPC 正常申请酿酒位。

## T0129C-A5-P5e 伊沃真实菜园生产

- 建筑分组新增“伊沃→真实耕作 / 停止真实耕作 / 真实耕作快照”，命令为 `formal_garden_work run|stop|snapshot`。游戏继续后可启动；成功派工关闭 GM 窗口，不传送、不补资源或伪造产量。
- pending 期间只建立正式会话并预留当前等级首个合法 `farm`。伊沃实体抵达田畦开放工作面并提交占用后才循环耕作；途中不产粮，完整周期继续按既有耕种、力量和菜园等级公式结算。
- `snapshot` 显示 ActionSystem 运行态、NPCSystem 正式会话、菜园工位和粮食；同一真实日计划原位续作，`stop` 和统一中断释放田畦并保留正式位置。
- T0130-P4 后同一入口也是伊沃正式两头身耕作验收入口：途中观察低饱和绿土色劳动者行走，实际提交田畦占用后才显示木柄铁锄并循环 `Digging`。`snapshot.character_art` 可检查工具父级 / 可见性、片段、朝向和色调参数；祈祷、受击与昏迷时园锄必须隐藏。

## T0129C-A5-P5d 布鲁诺真实食堂生产

- 建筑分组新增“布鲁诺→真实烹饪 / 停止真实烹饪 / 真实烹饪快照”，命令为 `formal_dining_work run|stop|snapshot`。游戏继续且至少有 1 份粮食时可启动；入口不自动补资源，成功派工后关闭 GM 窗口。
- pending 期间只建立正式会话并预留首个合法 `dining_kitchen_station`，布鲁诺实体穿门、抵达灶台前安全站位并提交占用后才进入循环烹饪。途中不扣粮，完整周期仍由 ActionSystem 原子执行 `1 粮 -> 2 餐食`。
- `snapshot` 显示 ActionSystem 运行态、NPCSystem 正式会话、食堂工位及粮食 / 餐食；同一真实日计划原位续作，`stop` 和统一中断释放灶台并保留正式位置。
- T0130-P3 后同一入口也是布鲁诺正式两头身验收入口：途中观察暖红白围裙厨师行走，到灶台提交占用后才显示右手木柄铜勺并循环 `Working_C`。`snapshot` 新增 `character_art`，可检查 `appearance_id=bruno_cook_chibi_v1`、工具父级 / 可见性、片段、朝向和共享状态合同；就座进食时勺子必须隐藏。

## T0129C-A5-P5c 欧文真实工械制造

- 制造 / 马匹分组新增“欧文→真实制造 / 停止真实制造 / 真实制造快照”，命令为 `formal_workshop_work run|stop|snapshot`。游戏继续后可直接运行；工械坊没有目标时优先采用 GM 当前合法选择，否则自动选择首个可用工械配方。
- 入口仍要求当前阶段材料足够，不自动补资源。成功派工后 GM 窗口关闭，欧文从正式初始点沿 NavigationMap 穿门，抵达 `workbench_01` 并提交占用后才进入循环工程动作与制造进度；途中只有 reservation / pending，不扣料。
- `snapshot` 同时显示 ActionSystem 运行态、NPCSystem 正式会话与 CraftingSystem 项目。`stop`、换目标或其他中断应释放工程位并保留正式位置；同一真实日计划的连续周期则留在原工程位续作。

## T0129C-A5-P5b 格伦真实打铁

- 制造 / 马匹分组新增“格伦→真实打铁 / 停止真实打铁 / 真实打铁快照”，命令为 `formal_blacksmith_work run|stop|snapshot`。`run` 要求游戏时间已继续；若铁匠铺尚无制造目标，会优先采用 GM 当前合法选择，否则自动选择首个可用铁匠配方。当前阶段材料仍必须足够，入口不会自动补资源，只调用 ActionSystem 真实派工，不传送、不伪造占用或制造进度。
- 派工成功后 GM 窗口会自动关闭，以便直接观察正式场景中的格伦；失败时窗口保持打开并记录具体原因。新局可在点“继续”后直接单击该按钮，不需要先手动设置制造目标。
- 运行时应看到格伦走向铁匠铺、真实跨门、到达 `forge_01`，然后进入循环打铁并把锤子挂到右手。途中快照只有 reservation / pending；到位后快照才是 occupancy / active，CraftingSystem 的 `active_workers` 和小数阶段进度也只在此时出现。
- 一个周期完成后，若当前计划仍是 `work_blacksmith`，格伦应在同一锻造位原位续开；`stop` 或切换制造目标应立即终止旧周期、释放工位并保留正式位置。`snapshot` 同时显示行动运行态、正式会话和制造项目。

## T0129C-A5-P5a 托马真实马厩工作

- 建筑分组在历史“托马→马厩照料位”旁新增“托马→真实照料 / 停止真实照料”，命令为 `formal_stable_work run|stop|snapshot`。`run` 调用 ActionSystem 的真实 `work_stable` 派工，不直接写地点、工位或马匹数值；游戏暂停时明确拒绝且不创建路线 / 预留，需先点主界面“继续”。
- 运行时先看到托马从正式初始点走向马厩；途中快照为 pending、栏位仅 `reserved_by`，HorseSystem 不计入照料劳动力。穿门并到达栏外站位后才变为 active / `occupied_by`，托马播放无铁锤循环工作动作，马匹成长、额外 HP 与繁育概率才按既有养马公式推进。
- 当前小时计划仍为 `work_stable` 时，完整周期应原位续开同一栏位；`stop` 经 ActionSystem 中断并由 NPCSystem 释放正式会话、栏位和行动租约，但保留正式世界位置与生产导航。`snapshot` 同时显示运行行动、正式会话和马厩马匹摘要。
- T0130-P2 后同一入口也是托马正式两头身验收入口：途中观察棕白劳动者行走，实际到照料位后才显示右手马刷式清洁工具并循环 `Working_B`。`snapshot` 新增 `character_art`，可检查 `appearance_id=toma_stableman_chibi_v1`、工具父级 / 可见性、工作片段、朝向和共享状态合同；没有增加新的权威按钮或命令。
- 原 `formal_nav_pilot stable_care` 保留为纯空间回归，最终 `current_action=idle`，不得用它判断养马结算。

## T0129C-A5-P4b / T0129B-C4-P1 行商马车

- 时间分组提供“强制进场 / 正式商路 / 强制离场 / 马车快照”，命令为 `merchant_wagon arrival|formal_arrival|departure|snapshot`。P7R2 后 `arrival` 与正常定时到访默认使用 6 点正式商路：旧 `(-40,-120)` 是第 5 个引导点，最终停靠于后门外 `(-28.2,-52.4)`；`formal_arrival` 保留为强制正式路线验收。只有先进入“临时旧图兼容”后，`arrival` 才使用 2 点旧路线。两个入口只驱动同一实体生命周期，不生成第二套交易结算。
- 正常验收可直接把时间设为 `10:00`：先看到马匹、前座车夫和装满木箱 / 桶 / 袋的长方形围板货车斗沿后门固定路线行进，抵达前交易不可用；抵达后车斗上方出现小型羊皮纸钱袋“交易”牌。把时间设为 `16:00`，已打开的交易面板应立即关闭，标识失效，马车反向驶出并在路线边缘释放。
- `snapshot` 显示 `wagon_state=absent|arriving|parked|departing`、`route_mode / route_point_count / route_world_points`、真实坐标、Body / Interaction 分层、Agent 速度、RVO 回调、马匹动画和气泡可见性。正式路线正常速度约 43 秒，不应在抵达前出现交易牌；交易报价、库存和事件仍由 MerchantSystem / ResourceSystem / MemorySystem 权威处理。

## T0129C-A4-P7 / T0129B-C3-P7 五波动态群战

- 战斗区先用既有波次下拉选择 1–5 波，再点“所选波次动态群战”；相邻按钮为“动态群战快照 / 停止动态群战”。
- 命令为 `formal_dynamic_wave run <1-5>`、`formal_dynamic_wave snapshot`、`formal_dynamic_wave stop`。`run` 会清理旧敌人、显示正式 staging 并按所选波次生成全部独立实体。
- 快照中的 `movement_model=dynamic_combat_pressure` 表示没有固定攻击槽；关注 `phase / combat_target_id / motion_target_position / blocked_count / pressure_repath_count / minimum_pair_distance / avoidance_callback_count`。P7R 后逐敌 `motion` 还会显示 `profile_base_speed / navigation_max_speed / maximum_observed_speed / maximum_raw_safe_velocity_speed / maximum_frame_displacement / rvo_speed_clamp_count`，slice 显示 `presentation_max_turn_radians_per_frame`。前排应出现 `attacking_*`，后排可保持 `marching_* / pressing_blocked`，且 `pressing_to_*` 必须可见走路动画；不得出现持续转圈、整个人体尺度的单帧弹出或长期 `navigation_failed`。
- `formal_second_wave_slice` 保留为兼容别名；可见按钮不再把 P6 的整齐前后排当作验收目标。

## T0129C-A4-P6 / T0129B-C3-P6 第二波混编正式实体（历史）

- 可见入口已替换为“第二波混编实体→目标直攻 / 第二波快照 / 停止第二波切片”，命令为 `formal_second_wave_slice run|snapshot|stop`。
- `run` 清理旧敌人，按第二波权威配置生成 12 名剑盾与 4 名长杆正式实体；`snapshot` 显示 `wave_number / unit_type_counts / attack_slot_role_counts` 以及逐敌槽位、物理状态和攻击提交；`stop` 复用统一清敌链。
- 主厅预期为同一来袭侧的剑盾前排和长杆后排。第一波 `formal_first_wave_slice` 保留为隐藏回归命令，不再额外占一排可见按钮。

## T0129C-A4-P5R2 / T0129B-C3-P5R2 第一波同侧紧凑直攻实体（历史隐藏入口）

- “第一波实体→目标直攻”或 `formal_first_wave_slice run`：清理旧敌人并按第一波配置生成 8 个独立正式 Body / Agent；敌人只请求正门、仓库、主厅三个当前权威目标的最短可行路径，不消费表现道路折点。
- “第一波快照”或 `formal_first_wave_slice snapshot`：查看逐敌目标、实际攻击位、真实坐标、运动结果、攻击权威、avoidance 总数和最小中心距。正门与仓库各有 8 个独立攻击位，主厅使用北侧正面 8 位单排紧凑攻击带。
- “停止第一波切片”或 `formal_first_wave_slice stop`：复用 CombatSystem 清敌与战斗结束链，移除全部正式实体。
- 旧 `formal_enemy_attack_slice / formal_enemy_warehouse_slice / formal_enemy_main_hall_slice` 继续保留单敌历史回归，不再占用可见按钮。

## T0129C-A4-P4 / T0129B-C3-P4 活动敌军推进主厅

- 战斗区显示“活动敌军→正门→仓库→主厅 / 主厅切片快照 / 停止主厅切片”，命令为 `formal_enemy_main_hall_slice run|snapshot|stop`。旧 P2 / P3 命令和 API 只留隐藏兼容。
- `run` 生成第一波的一名真实活动敌人。每抵达一个建筑后可用 `step_enemies 3600` 快速摧毁；实体自动继续下一段，到主厅前不会扣主厅 HP。实际抵达后用 `step_enemies 60` 观察首次 4 点伤害，继续摧毁会显示既有失败面板。
- `snapshot` 显示三个建筑各自的权威提交标记、当前攻击目标、十阶段到达、实时运动与战斗实例。`stop` 统一清敌；失败状态属于 GameState，不由停止按钮回滚。

## T0129C-A2a 独立实体运动沙盒

- 建筑分组新增“运行运动沙盒（F8 返回）”，命令为 `motion_sandbox`。入口切换到 `res://scenes/debug/ActorMotionSandbox.tscn`，不把沙盒节点挂进 Main。
- 场景自动并行运行 5 个 NPC 尺度 CharacterBody：蓝色绕静态建筑，黄 / 紫在 `2.4 m` 通道对向会车，红色撞上未纳入 NavMesh 的物理墙并有界重寻路，绿色前往导航岛外目标；蓝色还会在途中暂停 / 恢复。左上角显示完成数、最小会车中心距、绕障侧移和暂停位移。
- 完成后按 `R` 重跑，按 `F8` 重新加载 Main。切换场景会重新创建 Main 当前运行态，因此不要把它当作保持存档内临时状态的弹窗。
- 沙盒只验证 `CharacterBody3D + NavigationAgent3D + InteractionArea` 运动层，不调用 BuildingSystem / NPCSystem / MemorySystem / CombatSystem，不提交地点、工位、伤害或逃离完成。当前正式 NPC / 敌人仍是旧 Area3D；该入口不能证明 Main 已完成迁移。

## T0130-P1–P5 正式两头身角色

- 建筑分组中的 P0 临时 Main 开关已替换为“T0130 正式两头身角色”：格伦真实打铁、生成第一波剑盾敌军、独立动作沙盒、正式角色快照；命令为 `character_pilot glen|enemy|sandbox|snapshot`。P5 后独立沙盒并排显示格伦、托马、布鲁诺、伊沃、艾达和剑盾敌人；五名 NPC 继续复用既有真实生产、礼拜、训练与睡眠入口，不堆叠重复按钮。
- `glen` 复用既有正式制造入口，自动准备默认配方并由 ActionSystem 派格伦真实走入铁匠铺、提交工位后循环打铁；暂停中仍会明确拒绝，不由 GM 伪造地点或工作事实。
- `enemy` 调用 CombatSystem `debug_spawn_wave(1)`，生成 8 个有 CharacterBody / NavigationAgent / 实体碰撞的正式剑盾敌人；它们正常索敌和攻击，不是临时展示模型。重复生成前应先用既有“清空敌人”入口清场。
- `snapshot` 只读格伦、托马、布鲁诺、伊沃、艾达正式外观以及当前活动敌人的 `art_family / appearance_id / state / equipment`；不修改 HP、行动、工位、敌人或事件。
- `sandbox` 继续切换到 `ChibiCharacterSandbox.tscn`，用于逐动作近景检查；切场景会重新创建 Main，不能保留当前未存运行态。

## T0129B-C2a / T0129C-A1–A3b12R 正式空间与生产导航预览

- 建筑分组现为“恢复默认正式世界 / 临时旧图兼容 / 布局快照”；命令仍为 `station_layout preview|legacy|snapshot`。Main 默认显示和运行正式地图；本节其余 C2 内容保留为历史结构验收说明。
- `preview` 只调用 `StationLayoutController.debug_set_preview_enabled(true)`：把 CameraRig 临时移到 `(1000,0,0)` staging 根，使用新布局 `20–70 m`、FOV 62°和目标平移边界，并临时启用该远端根专属的生产 NavigationMap、Region 与 12 个门链接。78 个结构阻挡、1 个烘焙地面、全 12 座建筑的 107 件配置物 / 131 个 fixture 碰撞部件和 24 个自然阻挡始终留在远端隔离区，总计 234 个 StaticBody；入口不暂停时间、不隐藏或移动旧玩法根、不重绑 BuildingSystem / NPCSystem，也不写 NPC、地点、工位占用、战斗、商人或逃离事实。
- `legacy` 恢复进入预览前保存的 CameraRig 位置、相机局部位置 / 旋转 / FOV、缩放范围和平移边界。它不回滚任何玩法状态，因为预览本身不修改这些状态。
- `snapshot` 读取 `debug_get_layout_snapshot()`，除原地形 / 建筑 / 道路 / 镜头字段外，还显示 12 套空间合同、61 工位、4 主厅器械槽、8 个 NPC 初始点、2 个公共点、`11303` 格合同 AStar、107 个配置物 / 61 个安全站位 / 34 个床、椅或祈祷锚点 / 8 个 HorseAnchor、234 个 StaticBody / CollisionShape、生产 NavMesh 的 `0.25 m / 788 vertex / 754 polygon / 12 door links` 快照、135 个权威 Marker、1311 个生成 Mesh、117 个 Label 和配置错误。该入口不是空间权威切换开关。
- 预览时可直接检查：绿色小块是每座建筑的进出路线点，蓝色半透明矩形是建筑工位占地，红色半透明矩形是主厅器械槽，青色小块是 NPC 初始位置。A3b9R 教堂应可见五排长凳与完整圣坛；A3b10R 工械坊应可见三类工作台；A3b11R 主厅应可见横向砖石正立面、中央门厅 / 屋顶和四角平台；A3b12R 仓库应可见木网格外壳、双开装卸门、雨棚 / 滑轮、分类货架与货运车，拉近镜头后屋顶降至 0.08 透明度。静态碰撞需通过编辑器“可见碰撞形状”或 A1 / A3b1–A3b13 自动化观察；普通游戏 Mesh 不冒充碰撞可视化。它们尚未绑定旧 NPC / 敌人的运行移动。
- 预览期间旧模拟仍可能继续运行，只是镜头移到了远端；需要静止检查时应先用正常暂停按钮。返回 `legacy` 后生产 Region 与门链接再次禁用。A3b / C2b / C3 / C4 完成并正式交接前不得把预览称为已经切换正式玩法地图。

## T0129 铁匠铺美术等级预览

- 建筑分组新增“铁匠铺美术预览（不改权威等级）”的等级 1 / 2 / 3 按钮；命令为 `smithy_art_level <1|2|3>`。
- 入口优先调用正式地图 `FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt.debug_force_visual_level(...)`，仅在正式节点不可用时回退旧 4×4 兼容样板；切换 Level2 / Level3 表现组并回显环境、导航和工位快照，不修改 BuildingSystem 等级、HP、升级进度、效率、容量、资源、地点或工位占用。
- 主观验收时先用三档比较烟囱 / 武器架 / 第三工位 / 雨棚，再恢复等级 1。真实升级闭环仍必须使用 `upgrade_building blacksmith`、资源与时间推进验证。

## T0131-P1 工械坊美术等级预览

- 建筑分组新增“工械坊美术预览（不改权威等级）”等级 1 / 2 / 3 按钮；命令为 `workshop_art_level <1|2|3>`。
- 入口只调用 `FormalStationLayout/BuildingRoots/Workshop/WorkshopArt.debug_force_visual_level(...)`，用于比较 `3→6→7` 件 fixture、Lv.2 吊装 / 测量强化和 Lv.3 第三总装台 / 侧雨棚；快照同时回显可见与启用碰撞数量。
- 预览不修改 BuildingSystem 等级、`2→2→3` 工位数组、HP、升级状态、资源、制造目标 / 阶段、地点或工位占用。真实升级仍使用 `upgrade_building workshop`；主观验收后建议恢复等级 1。

## T0127A 暂停时移动提示

- “移动到地点”和 `move_npc <npc_id> <building_id>` 在 TimeSystem 暂停时不再调用移动权威入口，而是明确输出：“游戏当前暂停；请点击主界面左上‘继续’后重试，未写入移动状态。”
- 暂停拒绝不改 `current_action / movement_target`，不创建铁匠铺路线或工位预留，也不写地点事件。GM 不自动恢复时间，避免一次空间调试命令意外推进计划、需求、建筑作业或战斗。
- 若命令是在运行中成功发出，之后玩家再暂停，现有移动仍会冻结并在恢复后续接；这是正常暂停语义，不属于幽灵 moving。
- 正式开局若后端 health check 失败会按真实 LLM 规则保持暂停。此时应先查看 HUD 后端状态：正式体验需启动 / 修复后端后重新开局；只验证 GM 移动时可点击“继续”后重试。

## T0127 铁匠铺空间快照

- NPC 分组新增“空间快照”，命令为 `spatial <npc_id>`；未显式提供 ID 时按钮读取当前选中 NPC。
- 快照直接调用 `NPCSystem.debug_get_spatial_migration_snapshot(...)`，显示 `logical_location_id`、世界坐标、`spatial_route_phase`、`physical_location_phase`、当前路线步、预留建筑 / 工位、当前工位和 BuildingSystem 实际占用者。
- 推荐先设置铁匠铺制造目标，再用既有“指定行动”派发 `work_blacksmith`，在门外、门内、工位、改派和升级清退阶段重复查看。GMPanel 不移动 NPC、不提交地点、不预留 / 占用工位，也不开始或结算制造。

## T0126 屋顶可见性只读快照

- 建筑分组新增“屋顶快照”，命令为 `roof_visibility`；通用 `snapshot` 也会包含该项。
- 快照直接读取 `Main/Presentation/RoofVisibilityController.debug_get_snapshot()`，显示相机是否可用、相机距离、`18–42 m` 归一化值、注册建筑数量，以及每座建筑的 near / far / minimum / 当前 alpha、阴影、Mesh 数和碰撞 / 点击 / 室内触发状态。
- T0126 完成时 Main 尚无正式 `BuildingArtView`；T0127 已接入铁匠铺，因此当前 `registered_view_count` 至少包含该实例。GM 不设置距离、不改材质、不移动 NPC，也不提交地点 / 工位事实。

## T0121 全局数值验证入口

本轮不新增重复 GM 按钮。既有资源、建筑损伤 / 修复、制造目标 / 单阶段、时间、波次生成 / 跳波、警铃、敌人快照、虔诚填满 / 推进和器械部署入口已经能观察全部权威变化。配置 / 公式由 `tools/verify_t0121_game_balance.gd` 验证，第七天第五波构筑由 `tools/verify_t0121_fifth_wave_build.gd` 验证。`tools/verify_no_available_combatants_failure.gd` 保留历史文件名，但 T0121 后改为断言零可战人员时不失败、战斗继续且 HUD 不显示结算；唯一失败结局仍由主厅摧毁专项验证。

## T0116 对话意图复核观察

- 后端 / LLMBridge 区新增“对话意图复核”按钮，读取所选 NPC 的 pending request、一次性批准和最近 continue / modify / cancel 结果。
- 命令：`intent_revalidation <npc_id>`。
- 触发仍使用既有 `plan_execute <npc_id>`：当当前计划项为带非空 `dialogue_goal` 的 `talk_to_npc / seek_guard_officer` 时，会先进入复核。面板不伪造模型响应、不修改计划或启动对话。

T0114 在战斗调试区增加“填满虔诚”“虔诚快照”和“推进陨石 1 秒”，并支持 `piety_fill`、`piety_set <0-100>`、`piety_snapshot`、`piety_step <战斗动作秒>`。这些入口只调用 PietySystem 的 `debug_*` 接口：填满 / 设值用于进入 HUD 选点，快照显示累计来源、pending 陨石、燃烧区和最近施放结果，推进用于不等待实时 tick 验证落地与燃烧。GMPanel 不自行生成伤害、扣除虔诚或改敌人 / NPC / 建筑 / 器械 HP；无友伤必须从 PietySystem → CombatSystem 的真实路径验证。

T0106 用现有“短期记忆”按钮替换为“短期记忆 / LLM”，不堆叠新入口。点击后同时显示目标 NPC 权威原始事件 / 见闻计数，以及 `LLMBridge` 为正式调用构造的全部紧凑投影；可以直接确认第 8 条以前的关键事件仍存在，且模型侧没有 `event_id / payload / items / snapshot / roster`。该入口只读，不修改 MemorySystem、总结水位或 Prompt，也不自行压缩事件。

T0105B 不新增 GM 命令或按钮。复用计划查看 / 执行、推进逻辑时间、当前行动、位置占用和事件列表即可验证：让马塞尔主持、其他 NPC 参礼，并把下一小时改为其他行动；跨过整点后双方仍应主持 / 参礼，个人祈祷计时先满也不能离席。等弥撒自身结束后，应先看到“弥撒结束”、参礼者恢复独祷及必要的祈祷完成，再执行当时当前小时计划。普通工作的不同小时计划仍立即切换；在主持期间用对话打断，仍应显示“因主持中断而结束”。GMPanel 不写延迟标记、不伪造结束原因或转换事件。

T0105A 不新增 GM 命令或按钮。复用通用“指定行动”、推进逻辑时间、NPC 对话、当前行动和事件列表即可验证：让其他 NPC 祈祷、马塞尔主持后，弥撒自身按时完成应看到“弥撒结束”；在主持期间用对话等方式打断马塞尔，仍应看到“因主持中断而结束”。两条路径都应让未完成祈祷者原地恢复独自祈祷，GMPanel 不伪造结束原因或转换事件。

T0098 不新增 GM 命令或按钮。通用“指定行动”下拉只保留 `pray_at_chapel / lead_mass`：先给 NPC 指派祈祷，再让神父主持弥撒，可从 NPC 最近行动结果、运行态快照和事件列表观察 `prayer_mode` 从独自祈祷转为参礼；正常结束或中断主持后应恢复独自祈祷。整个过程中祈祷席、累计时间和当前计划不变，`plan_request` 不应出现教堂失败重估。GMPanel 不直接写模式、不伪造转换事件，也不代替 ActionSystem 判断主持者。

T0097 不新增 GM 命令或按钮。既有“当前计划”、`plan_request`、后端持久化 LLM 日志、通用“指定行动”、拜访 / 对话 / 三类协助目标和最近行动结果已经能对照观察“provider 最小决策 → 后端完整 PlanItem → ActionSystem 执行”；合并后的祈祷继续复用相同入口。GMPanel 不填写 `action_kind / priority / internal target`，不替模型选择 `location_id / target_npc_id / building_id`，也不维护第二套计划编译器。

T0095 / T0096 不新增 GM 命令或按钮。pending 生命周期继续用既有“暂停 / 继续”“指定行动”“立即进入地点”、NPC 最近行动结果、当前计划和运行态快照验证；GMPanel 不直接提交 active、占工位或伪造到达。`reflection_result` 继续读取 DailyReflectionSystem 快照，现在额外包含逐 NPC 上次成功 `reflection_period.end`；`long_memory <npc_id>` 可看到日记的 `record_label / summary_window_key / trigger_day / trigger_time / reflection_period`，短期事件查询可确认请求快照后新增记录仍保留。GMPanel 不自行移动记忆水位或生成“接到守备命令的第N天”。

T0094 不新增 GM 命令或按钮。宿舍 `床位X：空闲 / XX占用中` 与 NPC 面板右侧“记录”可直接在 `Main.tscn` 验证；“记录”读取全局事件档案并按历史日期、时间和波次分组，不需要 GM 复制对话。教堂继续复用通用“指定行动”、当前计划、最近行动结果、`plan_request` 与 LLM 日志，GMPanel 不伪造到达、对话承诺或修订选择；其旧祈祷失败链已由 T0098 模式转换替代。既有 `reflection_result` 继续调用 `DailyReflectionSystem.get_async_reflection_snapshot()`，现在额外显示 21:00 锚点、逐 NPC 当前睡眠窗口累计 / 剩余 / 状态及已完成窗口；它只读观察，不推进睡眠、不标记窗口完成，也不新增总结权威。

T0092 不新增 GM 命令或按钮。既有 `plan_request`、`npc_talk`、当前计划、最近行动结果、后端 LLM 日志、用量顶栏和 `llm_usage` 已能确认完整 Godot 响应、provider 实际 payload 与 token usage。GMPanel 不执行 provider projection、不补齐模型字段，也不维护第二套响应合同。

T0091 不新增 GM 命令或按钮。既有 `npc_talk`、通用“指定行动”、当前计划、最近行动结果、`plan_request` 与后端 LLM 日志足以验证目标驱动对话：模型计划只需选择目标 NPC，ActionSystem 会按目标实时地点接近；目标移动时仍按既有规则追踪。GMPanel 不填写计划地点、不传送双方，也不伪造工位占用或修订结果。

T0089 的教堂双向失败验证入口已由 T0098 废止。当前“指定行动”下拉不再包含独立参加弥撒；GM 只用祈祷与主持弥撒构造真实转换条件。

T0087 不新增 GM 命令或按钮。玩家应征、普通对话和结构化结果可直接在 `Main.tscn` 对话窗验证；NPC-NPC 可复用 `npc_talk`，逃离挽留可复用既有 `escape_npc` 与 NPC 面板对话入口。事件查询、后端 LLM 日志和用量快照足以确认实际 `dialogue_kind`、响应字段、provider 与失败原因。GMPanel 不构造第二份响应 Schema、不伪造 `recruitment_result / invitation_result / escape_intervention_result`，也不自行决定入伍、会话结束或逃离结算。

T0093/T0086 不新增 GM 命令或按钮。既有通用“指定行动”、协助修复 / 升级 / 治疗、建筑修复 / 升级、NPC 受伤 / 状态、推进时间、执行 / 查看 / 重估计划、`plan_request` 和后端 LLM 日志足以构造并观察完成后重排：让当前起连续几小时计划为同一协助 / 病床 / 饮酒，再推进到目标完成，应看到 `failure_type=action_completed / revision_hours=[当前小时, ...连续同任务小时]`，首个不同任务小时不应被包含，修订后当前行动立即变化；只有一个相同阶段时数组仍只有当前小时，在整点前完成并跨小时则不应产生旧小时请求。HUD `1 / 2 / 3` 可直接在 Main 前端验证。GMPanel 不伪造完成结果、不代替 LLM 选择后续行动，也不新增权威结算。

T0085 不新增 GM 命令或按钮。既有建筑“升级”、通用“协助升级”、计划生成 / 查看 / 执行 / 手动重估、推进时间、最近行动结果、`plan_request` 与后端 LLM 日志已经可以复现并观察完整链路：升级完成后旧协助项应产生 `no_active_upgrade`，一次正式修订后改为新行动，即使合并计划少于 6 个工作阶段也应接受。GMPanel 不伪造工程完成、失败上下文、计划计数或模型响应。

T0083 不新增 GM 命令或按钮：接受 / 拒绝结果行可在 `Main.tscn` 对话窗直接看到，精简标题可在 NPC 事件库直接确认；既有事件查询足够辅助检查 summary 和 `dialogue_text`。GMPanel 不生成应征结果、不修改 history turn，也不拼接 UI 文案。

T0082 不新增 GM 命令或按钮：完整多轮会话摘要、应征 toggle 保持和取消按钮禁用都可在 `Main.tscn` 对话 / NPC 事件库直接验证。既有事件查询可确认完成后仍只有一条 `dialogue_turn` 且 summary 包含全文；既有“推进 1 小时”可连续两次验证应征锁定挂起会话按完成收口。GMPanel 不创建对话历史、不修改 toggle，也不绕过 DialogSystem 取消锁。

T0081 不新增 GM 按钮或命令。既有“指定行动”、`eat / sleep / train_* / assist_repair / assist_upgrade / assist_heal`、立即进入地点、推进逻辑时间、NPC 状态、建筑修复 / 升级、警铃 / 避战 / 逃离与敌人快照已经能构造所有生活消耗档位；在 NPC 面板观察饱食 / 疲劳和经验即可。暂停后推进不应变化，恢复后按 TimeSystem 有效逻辑时间变化。GMPanel 不自行选择 `needs_profile`、计算小数余量或授予经验；T0098 后 24 项穷尽分类和三类协助有效工时由 `verify_activity_needs_framework.gd` / `verify_assist_timed_experience.gd` 验证。

T0080 不新增 GM 按钮或命令。用“指定行动”为 NPC 安排依赖某建筑的工作，在 NPC 仍位于别处并正在前往时，用建筑分组“升级”启动目标建筑升级：最近行动结果和 `plan_request` 此时不应出现失败；待 NPC 真实抵达入口后，应看到 `<action_id>_failed_building_upgrading`、`interrupted_phase=pending / arrival_check_failed=true` 及随后判别 / 按需修订。若先用“立即进入地点”让 NPC 在建筑内开始行动，再升级同一建筑，应立即看到 `interrupted_phase=active` 失败和广场清退。既有“协助升级”目标入口、驿站上下文、当前计划和后端 LLM 日志足够观察室外候选与模型选择；GMPanel 不伪造到达、失败、候选或升级结算。

T0078 不新增 GM 按钮或命令。既有 `start_proactive` / `proactive` 可以为指定 NPC 构造主动交涉问号，点击 NPC 后直接在 `Main.tscn` 验证取消按钮、tooltip、完成 / 挂起；既有“推进 1 小时”、`plan_request`、当前计划和最近行动结果足以观察超时收口、required 当前小时及新行为立即开始。GMPanel 不自行结束会话、归并判别小时或执行计划。

T0077 在 GM 面板标题下方新增常驻用量顶栏：打开面板立即异步读取一次 `/debug/llm_usage`，面板保持可见时每 3 秒刷新，格式为“运行：入 / 出 / 总 tokens｜估算人民币　今日：金额 / ¥20.00”。`session` 按本次后端进程的每个正式供应商 HTTP 尝试累计，`daily` 从上海自然日持久化账本重放；自动重试会计入多次。查询通过 `LLMBridge.debug_request_llm_usage_async()` 工作线程完成，不阻塞游戏、不申请慢速、不调用模型。既有“成本统计”按钮和 `llm_usage` 命令继续输出完整 runtime / budget / audit 快照；GMPanel 只显示后端值，不在客户端计算价格、扣预算或修改账本。

T0076 用只读命令 `dialogue_carryover` 替换旧 `expire_plan_dialogues`。它调用 `DailyPlanSystem.get_dialogue_carryover_snapshot()`，显示当前日 / 小时、仍在接近或等待的日计划对话、已进入邀请 / 正式阶段的跨小时会话，以及被延迟执行当前计划的 NPC；不推进时间、不结束对话、不修改计划、不释放预约。可先让自然日计划产生 `talk_to_npc`，在赶路 / 等待 / 交谈时用既有“推进 1 小时”，再执行该命令观察旧行动仍在且发起者 / 参与者进入 deferred；对话结束后通过 `plan_request` 和最近行动结果观察发起者判别必选当前小时、组屏障释放及新行为立即开始。

T0075 不新增 GM 按钮或命令。既有“指定行动”“执行当前计划”“推进 1 小时”、制造目标 / 单阶段和最近事件入口已经可以构造并观察连续生产：为 NPC 安排工作并推进到周期完成，可看到旧 `work_completed` 后立即出现下一次 `work_started`；跨小时前后计划相同应保留活动进度，不同则中断切换。吃饭 / 饮酒等单次行为可用现有行动与计划入口观察同小时不重放。GMPanel 只调用 ActionSystem、DailyPlanSystem、TimeSystem 与 CraftingSystem 的既有接口，不自行判断 `completion_policy`、清除派发记录或结算周期；穷尽分类由 `verify_plan_action_completion_policy.gd` 验证。

T0071 不新增 GM 按钮或命令。既有 `npc_talk <speaker_npc_id> <target_npc_id> [opening_text]` 可触发正式 NPC-NPC 对话；NPC 事件 / 见闻查询可确认某条事实只属于说话者，后端持久化 LLM 日志可核对实际 payload 不含 `speaker_npc`。确定性回归由 `verify_dialogue_private_context_boundary.gd` 完成，GMPanel 不复制私有记忆、拼装 Prompt 或建立第二套对话入口。

T0069 复用既有“成本统计”按钮和 `llm_usage` 命令，不新增按钮或权威接口。`GET /debug/llm_usage.model_adapter.audit_log` 现在显示持久化日志是否启用、JSONL schema 版本、路径、是否保存正文及最近写盘错误 / 时间；GMPanel 继续用 `_compact(...)` 显示完整后端快照。该入口只观察配置，不读取或回传日志正文，完整 Prompt、私人记忆和模型原始文本只能在后端受控文件中查看。

T0063 不新增 GM 命令或按钮。赠酒与个人持酒可直接在 `Main.tscn` 的 NPC 面板观察；既有资源增减入口可补充驿站 `wine`，通用“指定行动”下拉会从 `data/action_defs.json` 自动出现 `drink_wine`。先给目标 NPC 酒再指定饮酒，可通过 NPC 面板个人酒、最近行动结果和事件 / 见闻查询观察实际扣 1 与 `wine_consumed`；无酒时指定同一行动应得到资源失败。GMPanel 只调用现有系统，不创建第二套赠酒、饮酒或情绪结算。

T0061 不新增 GM 命令或按钮。玩家可直接在 `Main.tscn` 的 NPC 面板“背景 / 日记 / 知识”查看移除代表性表达后的 9 项档案、八人相互拼接的身世 / 到站日记，以及叙事化建筑认识；“知识”详情只显示主体、关系和值。既有 `long_memory <npc_id>` 继续显示同一份完整运行态长期记忆，保留每条知识的 `confidence / day / time`，可用于核对玩家 UI 只是隐藏可信度与更新时间而没有删除底层字段，也可核对每人的守备官种子只有一条职位职责。GMPanel 不复制档案或记忆文案、不改写知识记录，也不创建第二套玩家显示规则。

T0101 不新增 GM 命令或按钮。NPC【知识】已经直接显示守备官“职务 / 到站时间 / 来站前经历 / 过往相处”四条关系，对话可直接验证身份未知和三年旧事转题；既有 `long_memory <npc_id>` 可辅助核对四条技术键、技术值及元数据。上段 T0061 的“只有一条职位职责”是当时状态，当前已由 T0101 的四关系种子取代。GMPanel 不写入玩家身份、不生成旧事，也不提供绕过真实对话 Prompt 的专用回答按钮。

T0060 不新增 GM 命令或按钮。其 8 人档案、3 篇种子日记和知识图谱继续由 NPC 面板与 `long_memory <npc_id>` 复用同一运行态来源；T0061 已取代当时的固定代表性表达、前两篇微观写法、守备官开放评估措辞和知识面板元数据展示。六类 payload 的日记时间标签仍由 LLMBridge 投影，GMPanel 不创建第二套时间事实。

T0059 不新增 GM 命令或按钮。NPC 面板“日记 / 知识”从 `Main.tscn` 开局即可直接阅读初始长期记忆；既有 `long_memory <npc_id>` 也会立即显示该 NPC 的 3 篇种子日记和当前 `key_value_replace_v1` 图谱。`reflect_npc <npc_id> force` 仍调用 DailyReflectionSystem，在种子基线上追加一篇真实 / 明确降级来源的反思并替换知识键；GMPanel 不自行生成、覆盖或结算记忆。

T0058 复用既有“驿站上下文”按钮与 `station_context` 命令，不新增入口。输出新增“公开基础资源（5）”，直接显示 LLMBridge 从 ResourceSystem 当前读取的粮食、餐食、木材、石料和铁；“精简驿站规则（6）”可看到升级缓慢推进、成员可协助加快的规则。该入口只读，不修改资源、启动升级、指派 NPC 或结算加速。

T0057 不新增 GM 入口；其原“路上立即失败”验证口径已由 T0080 修正。现在用“指定行动”安排依赖建筑的行动后，途中启动升级应继续移动且暂不产生失败；抵达入口后才通过最近行动结果与 `plan_request` 观察 `<action_id>_failed_building_upgrading`、`trigger_kind=action_failure`、门口中文摘要和判别 / 按需修订。已在建筑内的 active 行动仍在升级开始时立即失败。该组合只调用 ActionSystem、BuildingSystem 与 DailyPlanSystem 既有权威入口，GMPanel 不直接写失败原因或伪造重估。

T0056 不新增 GM 入口：基础 HP / 照料额外 HP、成长、逐马繁育概率与冷却都可在 `Main.tscn` 马厩面板直接观察；既有马匹查看、生态推进与强制繁育命令继续调用 HorseSystem，可辅助验证概率重置和冷却，但 GMPanel 不自行写繁育概率或冷却。

T0055 不新增 GM 入口：既有“驿站上下文”按钮与 `station_context` 命令会直接读取更新后的 `data/station_context.json`，现在应在“精简驿站规则（5）”中看到持续参与、周期完成后结算、离岗后不自行产出的规则。该入口仍为只读，不推进周期、不添加资源、不修改活动进度。

T0054 在“后端 / LLMBridge”分组新增只读“驿站上下文”按钮与 `station_context` 命令，调用 `LLMBridge.debug_build_station_context()` 显示当前正式请求会共用的 `setting_summary`、动态在站 `resident_roster`、完整 `building_roster`、配置化 `work_mode_actions` 和精简 `station_rules`。该入口只观察由 NPCSystem / BuildingSystem / ActionSystem 与 `data/station_context.json` 组合出的上下文，不新增或修改 NPC、建筑、行动、士气、逃离或战斗事实。

T0053 原 `expire_plan_dialogues` 命令已由 T0076 移除，因为普通同日跨小时不再使已开始的对话等待失效。同小时计划被修订替代、跨日或目标 / 行为模式权威失效仍由运行系统自然产生结构化失败，可用“最近行动结果”和 `plan_request` 观察；GM 不提供伪造该失败的入口。

T0052 未新增专用 GM 命令或按钮。前端按钮状态可直接在 `Main.tscn` 观察；需要构造内部时序时，先用既有 `plan_revise <target_npc_id> [reason]` 让目标进入 `kind=plan`，再立即执行 `npc_talk <speaker_npc_id> <target_npc_id> [opening_text]`，用 `llm_state <target_npc_id>` 与“最近行动结果”观察目标思考期间没有邀请 / 失败、计划结束后自动进入原邀请流程。GMPanel 仍只调用 DailyPlanSystem / ActionSystem / NPCSystem 的既有接口，不新增等待或对话权威。

T0051 未新增专用 GM 命令：弹窗拖动、三种会话按钮、橙点与头顶气泡都可在 `Main.tscn` 前端直接验证；既有“推进 1 小时”时间入口可连续触发两次，用于观察挂起会话的 2 游戏小时超时。GM 面板自身继续使用既有 GM 按钮拖动，不改为通用窗口 handle，也不增加第二套会话权威。

> 本文件记录 GM 调试面板的用途、入口、命令和维护规则。每次更新 GM 面板都必须同步更新本文档。

## T0129C-A2b-P1–P6 正式导航试运行

- 建筑分组现有“格伦→铁匠铺”“莉娜→诊疗位”“莉娜→病床”“艾达→固定床”“布鲁诺→用餐席”“马塞尔→祈祷席”“托马→马厩照料位”“试运行快照”“停止并还原”；统一命令为 `formal_nav_pilot [glen|clinic_doctor|clinic_bed|dormitory_bed|dining_seat|chapel_prayer_seat|stable_care|stop|snapshot]`。旧 `glen_nav_pilot` 仅保留隐藏兼容别名，不再写入帮助。
- 七种运行模式都经 NPCSystem 数据驱动试点登记表启用远端正式布局与专属 NavigationMap，把目标 NPC 从旧世界临时放到正式初始点，预留对应工位并沿正式门路执行 CharacterBody3D / NavigationAgent3D 运动。游戏时间必须处于运行状态；暂停时明确拒绝，且不写移动、地点或工位状态。
- 格伦模式预留 `forge_01`；莉娜诊疗模式预留 `doctor_desk_01` 并在桌前站立；莉娜病床模式预留 `treatment_bed_01`，先抵达床边，BuildingSystem 成功提交占用后才挂到床面 `occupant_anchor` 并切换 `lying_supine`。
- 艾达模式按 BuildingSystem 固定归属预留 `dormitory_bed_01`；先抵达床边并提交 `occupied_by=veteran_deputy_01`，随后才挂到床面并切换 `sleeping_supine`。该模式的 `current_action` 应保持 `idle`，不代表已经执行睡眠行动。
- 布鲁诺模式按 BuildingSystem 的首个空闲规则选择 `dining_seat`；先抵达椅边并提交占用，随后才挂到椅面并切换 `sitting`。空场应选择 1 号席，1 号席被占时应选择 2 号席；`current_action` 保持 `idle`，不代表已经进食。
- 马塞尔模式按 BuildingSystem 的首个空闲规则选择 `chapel_prayer_seat`；先抵达长凳边并提交占用，随后才挂到座位锚点并切换 `seated_prayer`。空场应选择 1 号席，1 号席被占时应选择 2 号席；`current_action` 保持 `idle`，不代表已经祈祷或增加虔诚。
- 托马模式按 BuildingSystem 的首个空闲规则选择 `horse_care`；实际穿门并停在栏外 NPCStand 后才提交占用，不挂到 HorseAnchor。空场应选择 `stall_01`，1 号位被占时选择 `stall_02`；最终阶段为 `workstation_arrived`，Body 碰撞保持开启。`current_action` 仍为 `idle`，不代表已经开始养马工作或 HorseSystem 结算。
- `snapshot` 同时显示七种登记试点的路线来源、物理阶段、逻辑地点、Body / InteractionArea 分层、NavigationAgent 到达 / avoidance 计数、工位预留 / 占用与挂接状态。床 / 椅 / 长凳最终应为 `occupant_attached`、Body 碰撞关闭；马厩站立位最终应为 `workstation_arrived`、Body 碰撞开启。两者都保持 InteractionArea 可用、`reserved_by=null` 且 `occupied_by` 为对应 NPC。
- `stop` 取消全部正式试运行，释放预留 / 占用、解除锚点、恢复 Body 与旧世界位置 / 逻辑地点。“返回玩法地图”会先执行同样清理，避免只切镜头而留下远端 NPC。
- 该入口只验证 A2b-P1–P6 空间事务，不代表默认 NPC、其余建筑或敌人已经迁移；它不开始制造、诊疗、睡眠、进食、祈祷或养马，不结算资源、费用、HP、疲劳、饱食、虔诚、马匹成长 / 繁育或时间，也不绕过 BuildingSystem / MemorySystem 的权威提交。

T0046 不新增 GM 入口：公告牌双 Tab、通告草稿取消、参考日程增删改 / 发布、日记只保留第一人称文本和知识图谱中文显示都可在 `Main.tscn` 直接手动验证。广场公告、地点快照、短期 / 长期记忆的旧 GM 查询继续复用同一底层接口，不创建第二个公告牌或长期记忆事实源。

T0049/T0050 不新增“强制判别”按钮。实际对话必须经 DialogSystem 自然结束、日常行动失败必须经 ActionSystem / DailyPlanSystem 权威失败链触发通用判别；GM 只通过既有 `npc_talk` 或“指定行动”构造真实场景，通过 `plan_request` 观察最近判别和修订结果。`plan_revise` 保留为非对话手动触发，固定修订当前小时，不能指定判别范围或伪造对话 / 失败事实。

T0043A 复用“指定行动”通用下拉，不增加重复专用按钮。T0098 后下拉只包含 `pray_at_chapel` 与 `lead_mass` 两个教堂行为：先给其他 NPC 指派祈祷，再让具备资格的 NPC 主持，可观察祈祷者原地参礼；改派或中断主持者后应原地恢复独自祈祷，位置与进度不变。诊疗 / 训练仍可先启动医生 / 教官和承载者，再改派服务者验证真实依赖中断。

T0025 提供命令级验证入口 `npc_talk <speaker_npc_id> <target_npc_id> [opening_text]`：它只调用 ActionSystem 的自主对话公开入口。T0029/T0030/T0049 后，该命令便于构造“发起者追踪目标 → 目标先用真实 LLM 接受 / 拒绝 → 接受后才打断双方普通工作并释放工位 → 无硬轮次上限且由任一方结束标记收尾 → 拒绝或正式结束后双方各自判别计划 → 非空才修订精确小时”的链路，不在 GMPanel 内写对话、行动或判别事实。邀请等待或拒绝时不显示气泡；接受后双方显示可点击三点气泡，关闭旁听不会打断会话。因此无需新增重复 GM 按钮或命令。

## 目标

GM 面板用于把“已经实现但用户难以在主界面直接验证”的关键系统能力暴露到 `Main.tscn` 前端。它只调用已有系统接口或 `debug_*` 接口，不作为新的权威结算系统。

当前重点覆盖 M1-M4 已完成内容中原本主要靠脚本验证的能力：

- 资源增减、扣除失败和负数保护。
- 建筑选中、受损、倒计时修复、倒计时升级和全建筑外部状态广播。
- A2b-P1–P6 格伦→铁匠铺、莉娜→诊疗位 / 病床、艾达→固定床、布鲁诺→用餐席、马塞尔→祈祷席、托马→马厩照料位正式导航试点，阶段 / 挂接快照与原子清理 / 还原。
- NPC 选中、状态修改、移动到建筑、立即进入地点。
- NPC 扣血、HP 清零昏迷、昏迷后行动阻断、昏迷自然恢复和复苏。
- 昏迷或睡觉期间见闻暂停；睡觉 NPC 不会接收同地点/同建筑 public 见闻，睡醒后恢复。
- 通过“指定行动”下拉统一指派工作、训练场教官/受训者、诊疗位/病床、祈祷、主持弥撒、吃饭、饮酒、睡觉等普通行动，并保留协助修复、协助升级、协助治疗昏迷者等带目标参数的行动调试入口；参加弥撒由祈祷运行态自动切换。
- TimeSystem 设定时间、推进模拟小时、LLM 等待减速请求、有效倍率 / 慢速请求 / 时间上限请求快照。
- LLMBridge 后端 health check、开发期 NPC 对话 Mock、提出应征 Mock、正式请求共享驿站上下文快照，以及后端 LLM usage / 成本统计 / 预算状态 / 失败原因 / Godot LLM 等待运行态与逐请求慢速注册 / 释放查询。
- 地点快照、广场公告、广场公开事件、守备官给钱/攻击等记忆事件。
- NPC 短期记忆容器，区分事件库和见闻库。
- 已入伍 NPC 当前自然语言指令、修订号、最近计划重评估请求 / 应用结果、最近一次通用计划修改判别（含触发类型）和最近一次 NPC LLM 指令注入。
- 每日计划与 T1002/T1003/T0022/T0023/T0049/T0050 修订：通过真实 LLM 生成 24 小时计划，失败显示真实错误且不自动降级；另有明确分离的纯规则日计划调试入口。也可执行当前小时计划、查看当前计划、手动触发当前 NPC 的真实 LLM 当前小时修订。`plan_revise` 不产生 Mock 或规则修订，也不模拟对话 / 行动失败判别。
- 首次睡眠总结与长期记忆：触发当前 NPC 首次睡眠总结、查看长期日记 / 知识图谱当前键值、最近一次总结结果和当前 LLM 活动状态。
- NPC 主动找守备官交涉的调试触发、问号气泡状态，以及实际对话后的计划修改判别或无人响应超时后的当前小时修订。
- 具体装备系统：为已入伍 NPC 按具体物品库存装备主武器和盔甲，通过 HorseSystem 分配 / 取消分配具体马，并查看当前兵种判定快照。
- T0035-T0038 制造与马匹调试：设置铁匠铺 / 工械坊目标、提交单个阶段、查看项目 / 具体库存，以及查看、伤害、推进、强制繁育和分配逐匹马。
- T0904 成长系统：查看 NPC 总经验、未分配技能点，并由玩家把技能点分配到力量或智力。
- T0015 调试征召：可将当前选中 NPC 设为入伍，便于验证指令、装备和训练入口。
- T1101-T1304/T0107 敌人波次、统一战斗属性、目标优先级、双方攻击、工程器械、战斗动作秒、警铃集结、非战斗人员避战、兵种策略、骑兵冲锋 / 僵直、敌人在场时间上限、战斗开始 / 结束、逃离、波次日程、失败条件和第 5 波胜利调试：生成第一波或指定波次敌人，按已触发记录跳到下一波，触发警铃集结，通过敌人快照查看我方最终属性、器械、敌人抬手 / 僵直、骑兵冲锋阶段及既有战斗状态。所选波次设为 5 后可人工观察 A5-P2 的 48 敌 + 8 NPC 正式压力；精确帧时、净距、补位和清理仍以专项脚本为准。正式策略选择仍在 NPC 面板，围墙 / 主厅部署可直接通过 Main 世界 `+` 验证；GM 不另设第二套权威策略或部署按钮。

GM 命令仍可使用 `give_money` / `attack_npc` 这类开发语义；写入 NPC 事件库、见闻库和事件 summary 时，玩家身份必须显示为“守备官”。

## 开关

GM 面板脚本位于：

```text
res://scripts/ui/GMPanel.gd
```

顶部常量控制是否启用：

```gdscript
const GM_ENABLED := true
```

- 开发验证时设为 `true`。
- 上线、正式录屏或不希望显示 GM 时设为 `false`。
- 不要删除 GM 节点和文档；后续开发仍需要它作为不可见功能的验证入口。

## 界面

运行 `res://scenes/main/Main.tscn` 后，屏幕左侧会出现半透明 `GM` 按钮。

- 拖动 `GM` 按钮可改变位置。
- 点击 `GM` 按钮会在按钮附近打开或关闭 GM 面板；面板会随按钮位置重定位，并夹在可用屏幕范围内，避免固定覆盖左上角 HUD。
- 面板顶部有命令输入框和执行按钮。
- 面板中部分组提供常用按钮和输入框。
- 面板底部显示最近执行结果。

## 分组

资源：

- 选择资源 ID 和数量。
- 选择器会列出 11 个 `item_*` 具体成品库存；旧 `weapons / armor / defense_devices / horse_readiness` 聚合键不再出现，避免创建第二权威库存。
- 增加资源。
- 扣除资源。
- 查看资源快照。

时间：

- 设置天、时、分、秒。
- 推进模拟 1 小时：调用 `TimeSystem.debug_advance_hour()`，即使当前暂停也会按真实逻辑时间发出一次 `logical_time_tick(3600.0, 1.0)`，让建筑升级、行动周期、NPC 状态等订阅系统同步推进；单次调试推进上限为 1 游戏小时，避免跨过中间结算。
- 注册一次 GM 手动 LLM 减速。
- 清空所有减速请求。
- 查看时间倍率快照，包括玩家选择倍率、实际有效倍率、LLM 慢速请求和 TimeSystem 上限请求；T1104A 后生成敌人时可观察 `combat_enemy_presence` 上限，清敌后应消失。

建筑：

- 选择建筑。
- 打开建筑面板。
- 造成建筑受损。
- 调用修复；修复会先扣资源并创建倒计时作业，建筑快照可观察剩余时间、进度、协助人数和加速倍率。
- 调用升级；升级会先扣资源并创建倒计时作业。T0043 后开始升级会立即封闭建筑、清退室内 NPC 并释放位置，完成后可从建筑快照观察新增位置、效率和 Max HP。
- 查看建筑快照；T0127 后快照包含逐位置 `name/type/reserved_by/occupied_by/status`、`is_enterable`、condition、精确损伤 / 活动效率和逐级升级效果。
- 用“造成建筑受损”配合建筑面板和“推进模拟 1 小时”验证受损降效、修复跨效率分档、升级封闭和周期变化；GMPanel 只调用 BuildingSystem / TimeSystem，不自行改效率或位置。

制造 / 马匹：

- 制造行可选铁匠铺 / 工械坊与该建筑合法配方；“设置目标”保留换目标确认拒绝，“强制换目标”显式传入 `force=true`。
- “完成阶段”读取当前 `project_revision` 并调用 `CraftingSystem.complete_stage(...)`；材料不足、revision 过期、成品入库与项目重置仍由 CraftingSystem / ResourceSystem 结算。
- “制造快照”显示目标、revision、已完成 / 总阶段、当前阶段、部分进度、活动工人与具体成品库存。
- 马匹行按具体 horse ID 查看快照、扣 HP，按游戏秒推进马匹生态，或强制生成一匹小马；分配 / 取消分配同时使用当前 NPC 和马匹选项。
- 马匹入伍 / 主武器资格、成年状态、在厩位置、唯一分配、受伤、生态和繁育全由 `HorseSystem` 公开 / `debug_*` 接口处理；GMPanel 不直接写马匹字典。

NPC：

- 选择 NPC。
- 打开 NPC 面板。
- 移动到指定建筑入口。
- 立即进入地点信息节点。
- 设置 NPC 状态字段。
- 扣除 NPC HP；HP 清零后由 `NPCSystem` 触发昏迷；战斗中 HP 首次跌破 30% 且仍大于 0 时由正式低血量判定链路处理。
- 用自然恢复规则推进指定 NPC 的昏迷恢复，便于快速验证复苏。
- 查看 NPC 快照。
- 为已入伍 NPC 发布自然语言指令、查看当前指令，并查看最近一次计划重评估请求、对话后判别及其应用结果；未入伍 NPC 发布会被 `NPCSystem` 拒绝。
- 为当前选中 NPC 生成真实 LLM 24 小时计划、生成纯规则调试计划、执行当前小时计划、查看计划或立即触发计划修订；计划入口调用 `DailyPlanSystem`，不在 GMPanel 中自行决定行动结算。T0049/T0050 后 `plan_revise` 是非对话调试触发，固定以 `revision_hours=[current_hour]` 修订当前阶段；对话或行动失败的范围必须由真实会话 / 权威行动失败触发后的 LLM 判别产生。T0022 后 `plan_generate` 要求已配置的非 Mock provider，成功来源为 `llm_plan_day`；失败只显示真实错误，不规则降级。`plan_generate_rule` 仍是独立的显式纯规则调试入口，不会被正式开局或新一天调用。
- 为当前选中 NPC 触发熟睡总结、查看长期记忆、最近一次反思结果和 LLM 状态；总结入口调用 `DailyReflectionSystem`，不在 GMPanel 中自行写日记、清短期记忆或更新知识图谱。T0024 后 `reflection_result` 同时输出反思批次并发快照；T0094 后该快照还包含 21:00 窗口锚点、逐 NPC 累计 / 剩余睡眠、请求状态和已完成窗口。`llm_state` 继续只读取单个 NPC 当前活动与睡眠锁状态。
- 将当前选中 NPC 设为入伍；该入口只调用 `NPCSystem.set_npc_recruited(...)`，用于调试验证，正式征召仍由对话同意结果驱动。
- 触发当前选中 NPC 主动找守备官交涉，并查看该 NPC 的主动交涉状态；触发后 NPC 头顶出现 `?`，点击后进入既有对话面板。
- 通过 `npc_talk` 指定发起者、目标和可选开场目的，直接触发已有 NPC-NPC 自主对话行动；目标合法性、移动、邀请接受 / 拒绝、双方预定、接受后的工作打断、软性轮次指导和结束标记仍由 ActionSystem / DialogSystem 校验。
- 选择武器类型和盔甲部位，为当前选中且已入伍 NPC 装备武器或盔甲；装备入口调用 `EquipmentSystem`，只消耗该定义的具体 `item_*` 库存。坐骑不再使用通用“装备坐骑”入口，改由“制造 / 马匹”分组调用 HorseSystem 分配具体马。
- 查看当前选中 NPC 的兵种判定快照，包括主武器类型、武器 class、是否有坐骑和装备槽内容。
- 为当前选中 NPC 分配技能点到力量或智力；该入口只调用 `NPCSystem.assign_npc_attribute_point(...)`，无未分配技能点或属性已达上限时会失败。技能点由玩家分配，AI 只可作为后续建议来源。

行动：

- 指派指定行动；该下拉列出 `data/action_defs.json` 中的普通行动，包括工作、诊所、训练、吃饭、睡觉、祈祷和主持弥撒等入口，不包含需要额外目标参数的协助行动，也不再包含独立参加弥撒。
- 工作类行动会占用目标可进入建筑的真实工位，并按 NPC 对应熟练度、力量 / 智力属性和建筑等级缩短单位周期。T0035 后铁匠铺 / 工械坊必须先有合法目标，每个完整周期只向 CraftingSystem 提交一个阶段，阶段材料与具体成品由系统原子结算。T0037 后 `work_stable` 提供养马照料劳动，不再消耗粮食产出抽象马匹整备；马匹进食由 HorseSystem 按持续周期扣粮。菜园、酒窖等其他工作继续使用各自现有结算。工位占满、无目标或资源不足时由行动 / 权威系统返回失败。
- “指派行动”下拉可直接选择 `work_clinic_doctor` 和 `receive_clinic_treatment` 验证小诊所：医生自动占诊疗位、伤员自动占病床；多名在岗医生共同提高全部病床恢复，治疗随逻辑时间扣第纳尔。无病人时医生研读医学著作。
- 通过行动分组内的“修复目标”建筑下拉选择目标，再指派 NPC 协助该建筑的修复；协助修复是一个统一行为，建筑由该下拉或命令参数决定。
- 通过行动分组内的“升级目标”建筑下拉选择目标，再指派 NPC 协助该建筑的升级；协助升级同样是带建筑参数的统一行为。
- 通过行动分组内的“治疗目标”NPC 下拉选择昏迷目标，再指派当前选中 NPC 协助治疗；协助治疗是带目标 NPC 参数的统一行为，目标必须昏迷，每个昏迷目标最多 2 名治疗者。
- 训练、吃饭、睡觉、祈祷和主持弥撒都通过行动下拉指派；`train_instructor`、`train_student`、`eat`、`sleep` 等命令继续保留。多名在岗教官共同提高全部训练位成长；吃饭 / 睡觉分别申请用餐席 / 宿舍床位；祈祷申请祈祷席且不依赖神父，弥撒开始后自动参礼、结束后继续独自祈祷；`lead_mass` 申请祭坛并验证“主持弥撒”能力。满位、封闭、无装备或无教官等真实日常计划行动失败仍由 ActionSystem 写入，并先触发通用计划修改判别，非空才修订所选阶段。

战斗 / 敌人：

- 选择敌人波次。
- “生成第一波敌人”固定调用 `CombatSystem.debug_spawn_wave(1)`；P7b 后会启用正式地图 / 镜头，在 `FormalEnemies` 生成 8 个动态实体，并把当前可战斗 NPC Body 迁入同一生产 NavigationMap。
- “生成所选波次”按波次下拉调用 `CombatSystem.debug_spawn_wave(...)`；已有默认正式战斗时允许追加后续波次，不创建旧 `Station/Enemies` Area3D。
- “跳到下一波”调用 `CombatSystem.debug_trigger_next_wave()`，按 `CombatSystem` 已记录的 `triggered_wave_numbers` 触发下一未触发波次，用于快速验证 T1301 自动波次日程；该入口不修改时间、不自行写战斗事件。
- “警铃集结”调用 `CombatSystem.debug_trigger_combat_alarm()`，触发与 HUD 警铃相同的集结流程：所有 NPC 写入警铃事件，入伍且有主武器的可行动 NPC 前往城门外防线。
- “敌人快照”读取 `CombatSystem.debug_get_combat_snapshot()`，显示当前活动敌人数量、波次、波次日程、敌人目标、当前行动、NPC 集结状态、非战斗人员避战目标、逃离目标、逃离挽留轮次、逃离速度倍率、可战斗人员可用性 `combatant_availability`、入伍持武器 NPC 战斗策略、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量自身心理判定结果、最近逃离结果、行为模式快照、最近警铃结果、最近生成结果、最近 AI 推进结果、最近我方攻击结果、最近失败结果、最近胜利结果、最近模式切换结果、最近避战结果和 TimeSystem 倍率快照；T0107 后还包含 `friendly_combat_stats` 的基础 / 成长 / 装备 / 最终值、`defense_devices` 的 HP / 防御 / 穿透 / 有效射程、敌人的 `penetration / attack_speed / attack_windup_remaining / stagger_remaining`，以及战斗策略中的冲锋阶段和最近冲撞结果。该快照可确认统一穿透结算、主厅射程翻倍、敌人抬手被僵直打断与骑兵冲锋循环；既有 T1104C-T1304 验证边界不变。
- “推进敌人AI”调用 `CombatSystem.debug_step_enemy_ai(60.0)`，用于手动推进 60 游戏秒的目标选择、移动、我方基础自动攻击和敌方攻击；T1104B 后这约等于 1 秒战斗动作。命名保留为兼容旧入口。
- “清空敌人”调用 `CombatSystem.debug_clear_enemies()`，删除当前正式敌人并让 NPC 原地恢复正式日常运动模式；默认正式地图镜头保持不变。
- “行为模式快照”调用 `NPCSystem.debug_get_behavior_mode_snapshot()`，查看每名 NPC 的 `behavior_mode`、进入原因、进入时间、当前行动和兼容 `combat_mode`。
- “模拟避战”调用 `CombatSystem.debug_trigger_npc_avoidance(selected_npc_id)`，用于让当前选中的非战斗人员（未入伍，或已入伍但无主武器）在已有活动敌人时进入避战，并按敌方方位生成短步长四散移动目标；已入伍且有主武器的 NPC 会被拒绝，按战斗逻辑处理。
- “触发逃离”调用 `CombatSystem.debug_start_npc_escape(selected_npc_id)`。默认正式世界中无论是否正在战斗，选中且未昏迷、未逃离的 NPC 都沿 6 点 / `261.302 m` 后路前往地图边缘 `(-54,-305)`；只有临时旧图兼容使用短路线。入口只触发逃离系统，`escape_started` / `escaped` 事件和 `escaped=true` 标记仍由系统结算。可在主界面点击途中 NPC 进入五轮挽留，也可用 `give_money` 或逃离挽留面板里的攻击按钮验证速度变化；清空敌人不会中断尚未完成的正式长逃离。
- “推进集结等待”调用 `CombatSystem.debug_advance_rally_wait(3600.0)`，用于快速验证 NPC 到达集合点后等待 1 游戏小时仍未接敌会返回工作模式且不触发计划重评估。
- 该分组不自行结算伤害、集结结果、逃离结果或时间倍率，只调用 CombatSystem / NPCSystem / TimeSystem 的公开 / `debug_*` 接口；警铃集结会经 CombatSystem 调用 ActionSystem / NPCSystem / MemorySystem。T0110 后 NPC、敌人和器械统一按 `max(0, defense - penetration)` 得到有效防御，再按 `20 / (20 + effective_defense)` 得到伤害倍率，由 CombatSystem / DefenseDeviceSystem 的窄接口扣除各自权威 HP；GM 不读取“只看盔甲”的旧口径，也不自行生成冲锋、抬手或僵直结果。既有时间上限、战斗事件、心理、逃离与胜负职责不变。

行为模式后续调试入口：

- T1103B/T1103C 已可查看每名 NPC 的 `behavior_mode`、模式进入原因和模式进入时间，并可推进集结等待时间；敌人快照可查看 `active_avoidances`，`avoid_npc <npc_id>` 可手动触发非战斗人员避战。
- 后续仍需补充可视化：当前敌人接触范围判定、斗志 buff 剩余时间的专用 UI。
- 手动触发 / 验证：战时心理结果、斗志 buff、低血量自身心理判定、逃离驿站和逃离挽留都可通过正式入口与敌人快照验证；低血量判定可用敌人在场时的 NPC 扣血入口触发，逃离可用 `escape_npc <npc_id>` 触发，挽留可在主界面点击逃离 NPC 打开 NPC 面板后点击【对话】触发。
- 查看最近一次战时对话的 `wartime_reaction`、`battle_psychology_result`、`morale_boost` / `escape_intent` 状态，最近一次低血量自身心理判定的 `last_low_hp_judgement_result`、`active_battle.low_hp_judgements`，以及逃离流程的 `active_escapes` / `last_escape_result`，其中 T1204A 会显示挽留轮次、速度倍率和暂停 / 继续状态。
- 这些入口只能调用 CombatSystem / NPCSystem / DialogSystem / LLMBridge 的公开或 `debug_*` 接口，不在 GMPanel 内自行决定模式、buff、逃离或战斗伤害。

后端 / LLMBridge：

- 后端健康检查，调用 `LLMBridge.check_health()` 并刷新 HUD 后端状态。
- 面板顶栏通过 `LLMBridge.debug_request_llm_usage_async()` 显示本次后端运行的正式 provider 尝试输入 / 输出 / 总 token、人民币估算和上海自然日持久化金额 / 上限；面板隐藏时停止轮询。
- 查看完整后端 LLM usage / 成本统计 / 预算状态，调用 `LLMBridge.debug_request_llm_usage()` 读取 `GET /debug/llm_usage`，显示 provider、model、业务调用记录、每次 provider 尝试 token / 人民币、今日持久化金额、fallback 次数、两层预算上限 / 已用 / 剩余、最近预算错误、最近失败、HTTP 状态或异常类型、Schema 失败和降级来源；同时读取 `LLMBridge.debug_get_llm_runtime_snapshot()`，显示当前等待中的 LLM 请求数、pending slowdown request id、NPC 活动请求、异步请求数量、传输退出标记、最近线程收束结果、有效逻辑倍率、最近一次 TimeSystem 倍率变化原因，以及每个请求的 call_type、慢速是否注册 / 释放和时间戳。该入口只读，不申请 TimeSystem 慢速。T0109 不增加“关闭 LLMBridge”按钮，因为退出收束发生后节点已离开场景，强行在正式运行中触发会破坏后续请求；悬挂传输与线程 join 由 `verify_llm_bridge_shutdown.gd` 验证。
- 对当前选中 NPC 发送 `/npc/dialogue` 开发期 Mock 请求。
- 对当前选中 NPC 发送带 `is_recruitment_request=true` 的开发期应征 Mock 请求。
- 查看最近一次共享 NPC LLM 上下文注入的目标、调用类型和 `current_order`；`station_context` 显示当前在站成员、建筑、行为目录、五项公开基础资源和六条规则；`plan_request` 还显示最近一次通用 `plan_revision_judgement` 的 `trigger_kind`、结果及 `revision_hours`。
- 该分组只显示后端返回，不写入对话事件、不修改入伍状态。`dialogue_mock` / `dialogue_recruit` 只用于开发和 Schema 验证，不作为真实 API 验收；真实 provider 失败应通过 usage / 日志查看原因，不用 mock 回复伪装成功。

记忆 / 见闻 / 广场：

- 写入广场公告。
- 查看地点快照；广场快照包含当前在场 NPC 的 `people_statuses`、当前公告和所有建筑外部状态，可进入建筑快照包含该建筑外部 + 内部状态，`people_statuses` 可观察在场 NPC 的生命状态、行动状态和昏迷治疗者。
- 查看 NPC 短期记忆。
- 写入守备官给钱事件。
- 写入守备官攻击 NPC 事件。
- 广场公开广播事件。
- 查看全局事件列表。

上述玩家交互事件写入后，summary 应显示为“守备官给了……”或“守备官攻击了……”，不显示以“玩家”为主语的旧式文本。

## 命令

命令输入框支持以下命令：

```text
help
refresh
snapshot
events
plaza_events
add_resource <resource_id> <amount>
spend_resource <resource_id> <amount>
set_time <day> <hour> <minute> <second>
advance_hour
time_snapshot
slowdown [request_id] [scale] [reason]
release_slowdown <request_id>
clear_slowdowns
select_npc <npc_id>
select_building <building_id>
move_npc <npc_id> <building_id>
enter_location <npc_id> <location_id>
set_npc_state <npc_id> <key> <value>
recruit_npc <npc_id>
assign_attribute <npc_id> <strength|intelligence>
publish_order <npc_id> <text>
order <npc_id>
plan_request
plan_generate [npc_id|all]
plan_generate_rule [npc_id|all]
plan_execute [npc_id|all]
plan <npc_id>
plan_revise <npc_id> [reason]
reflect_npc <npc_id> [force]
long_memory <npc_id>
reflection_result
llm_state <npc_id>
start_proactive <npc_id> <text>
proactive <npc_id>
npc_talk <speaker_npc_id> <target_npc_id> [opening_text]
equip_weapon <npc_id> <weapon_id> [visibility]
equip_armor <npc_id> <slot> [visibility]
unit_type <npc_id>
craft_target <blacksmith|workshop> <recipe_id|none> [force]
craft_stage <blacksmith|workshop> [npc_id]
craft_snapshot [blacksmith|workshop]
horse_snapshot [horse_id]
horse_damage <horse_id> <amount>
horse_advance <game_seconds>
horse_birth
horse_assign <npc_id> <horse_id> [visibility]
horse_unassign <npc_id> [visibility]
spawn_wave [wave_number]
enemy_wave [wave_number]
next_wave
jump_wave
enemies
alarm
rally
step_enemies [game_seconds]
clear_enemies
behavior_modes
avoid_npc <npc_id>
advance_rally_wait [game_seconds]
escape_npc <npc_id>
assign_action <npc_id> <action_id>
work <npc_id> <building_id>
train_instructor <npc_id>
train_student <npc_id>
assist_repair <npc_id> <building_id>
assist_upgrade <npc_id> <building_id>
assist_heal <healer_npc_id> <target_npc_id>
eat <npc_id>
sleep <npc_id>
damage_building <building_id> <amount>
repair_building <building_id>
upgrade_building <building_id>
plaza_notice <text>
give_money <npc_id> <amount> [visibility]
attack_npc <npc_id> <damage> [visibility]
damage_npc <npc_id> <damage> [visibility]
recover_npc <npc_id> <game_seconds>
backend_health
llm_usage
dialogue_mock <npc_id> <text>
dialogue_recruit <npc_id> <text>
last_order_injection
memory <npc_id>
location <location_id>
```

`craft_target` 不带 `force` 时保留 CraftingSystem 的 `confirmation_required` 返回；只有显式追加 `force` 才放弃已完成 / 部分阶段。`craft_stage` 从当前项目快照取 revision 后调用权威接口，不自行扣材料或加库存。

`horse_damage / horse_advance / horse_birth` 分别调用 `HorseSystem.debug_damage / debug_advance / debug_force_birth`；`horse_assign / horse_unassign` 调用正式分配接口，不绕过入伍、主武器、成年、在厩和唯一分配校验。

常用示例：

```text
add_resource money 20
damage_building wall 15
repair_building wall
assist_repair engineer_01 wall
upgrade_building garden
assist_upgrade engineer_01 garden
damage_npc cook_01 150 local_public
assist_heal doctor_01 cook_01
set_time 2 9 30 0
time_snapshot
enter_location cook_01 dining_hall
work gardener_01 garden
work blacksmith_01 blacksmith
work engineer_01 workshop
work stableman_01 stable
work cook_01 tavern
assign_action doctor_01 work_clinic_doctor
assign_action cook_01 receive_clinic_treatment
train_instructor veteran_deputy_01
train_student stableman_01
eat cook_01
sleep priest_01
plaza_notice 今晚所有人都必须留在广场附近。
give_money cook_01 5 local_public
recover_npc cook_01 54000
backend_health
llm_usage
dialogue_recruit cook_01 守备官需要你一起保护大家。
publish_order veteran_deputy_01 守住城门，但先保证自己安全。
recruit_npc priest_01
order veteran_deputy_01
plan_request
plan_generate gardener_01
plan_generate_rule gardener_01
plan_execute gardener_01
plan gardener_01
plan_revise gardener_01 gm_manual
reflect_npc cook_01 force
long_memory cook_01
reflection_result
llm_state cook_01
start_proactive cook_01 守备官，我想知道我们还能不能守住这里。
proactive cook_01
npc_talk doctor_01 priest_01 诊所工位被占用了，我想和你协调一下。
add_resource item_bow 2
add_resource item_mail_chest 1
equip_weapon veteran_deputy_01 bow local_public
equip_armor veteran_deputy_01 chest local_public
craft_target blacksmith craft_iron_helmet
craft_snapshot blacksmith
craft_stage blacksmith blacksmith_01
craft_target workshop craft_wall_ballista force
horse_snapshot
horse_damage horse_chestnut_wind 10
horse_advance 3600
horse_birth
horse_assign veteran_deputy_01 horse_chestnut_wind local_public
horse_unassign veteran_deputy_01 local_public
unit_type veteran_deputy_01
assign_attribute cook_01 strength
spawn_wave 1
next_wave
alarm
enemies
escape_npc priest_01
step_enemies 60
clear_enemies
memory cook_01
location plaza
events
```

`unit_type` 只读取 `EquipmentSystem.get_unit_type_snapshot(...)`。只有 `horse_assign` 经 HorseSystem 完成具体马分配并同步 `equipment.mount.horse_id` 后，NPC 才可能被判定为骑乘兵种；任何聚合资源数量都不代表已分配马。

## 维护规则

每次完成任务验证时，Agent 必须判断本次功能是否能被用户直接在主界面看见和手动验证。

- 如果不能直接看见，但它是关键状态、数据、事件、AI、资源、建筑、NPC、时间、战斗、后端或 Prompt 调试能力，就必须给 GM 面板新增或替换入口。
- 如果新实现已经覆盖旧调试能力，应替换旧按钮或命令，不保留误导性的旧入口。
- GM 面板入口应该调用系统已有公开方法或 `debug_*` 方法；不要把数值结算、HP 扣除、记忆写入等权威逻辑写在 GMPanel 里。
- 每次更新 GM 面板时，同步更新本文件的“分组”“命令”和“常用示例”。
- 如果新增 GM 验证脚本或重要文件，同步更新 `docs/MODULE_INDEX.md`。

## 验证

T0061/T0059 使用下列专项验证开局种子、中文显示、六类 LLM 上下文和既有 GM 入口；T0061 额外核对 NPC 知识详情不显示可信度 / 更新时间，而 `long_memory` 的原始记录仍保留相关字段，不增加第二套长期记忆权威：

```powershell
godot --headless --path . --script res://tools/verify_npc_initial_long_memory.gd
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

T0022 覆盖下方长段中 T1003 的历史“Mock 计划和规则降级”口径：当前 `plan_generate` 是真实 provider 专用且失败不降级。正式 8 路并发、`llm_plan_day` 来源和 Mock provider 拦截分别由 `verify_game_startup_real_async.gd`、`verify_formal_plan_real_only.gd` 与 `verify_daily_plan_llm.gd` 覆盖。

GM 面板当前有专用验证脚本：

```powershell
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

T0043 的五建筑位置、资格、团队效率、损伤与升级封闭由下列专项脚本验证；它复用 GM 已有的行动、建筑伤害、升级、快照和时间推进接口，不新增第二套结算按钮：

```powershell
godot --headless --path . --script res://tools/verify_building_service_positions.gd
```

该脚本会加载 `Main.tscn`，检查 GM 按钮和窗口，执行命令验证资源、建筑、时间、时间倍率快照、NPC 地点、GM 入伍按钮、自然语言指令、每日计划生成 / 查看 / 执行、手动当前小时计划修订、首次睡眠总结入口、长期记忆查看、计划修订请求 / 结果、最近通用计划修改判别、最近 LLM 指令注入、训练场教官 / 受训者入口、敌人波次生成 / 跳到下一波按钮 / 警铃集结 / 快照 / AI 推进 / 清空、逃离命令、敌人在场 TimeSystem `x1` 上限注册 / 释放、记忆事件和广场公告。T0035-T0038 后还会验证资源选择器包含 11 个具体 `item_*` 且隐藏四个过期聚合键、制造目标 / 单阶段 / 成品入库，以及马匹快照 / 受伤 / 生态推进 / 强制繁育 / 具体分配 / 解除分配。T0904 的成长与技能点分配由 `tools/verify_skill_progression.gd` 覆盖；T1001 的计划执行细节由 `tools/verify_daily_plan_system.gd` 覆盖；T0023/T0050 的资源不足 / 工位占用触发、判别为空 / 非空、精确小时修订、Mock 隔离、真实计划修订和慢速释放由 `tools/verify_daily_plan_reevaluation.gd` 与 `tools/verify_action_failure_plan_revision_judgement.gd` 覆盖；NPC 当前计划入口、事件 / 见闻详情首次定位最新记录与刷新滚动保持由 `tools/verify_npc_panel_state.gd` 覆盖；T0029/T0030/T0049 的邀请接受 / 拒绝、无硬上限、软轮次参考、任一方结束标记，以及拒绝 / 正式结束后的双方独立判别由 `tools/verify_dialogue_invitation_contract.gd` 和对话判别专项覆盖；T1003 的显式开发 Mock 日计划由 `tools/verify_daily_plan_llm.gd` 覆盖；T1004/T1005 的首次睡眠总结、NPC 面板日记、短期记忆清空和对话 / LLM 打断边界由 `tools/verify_daily_reflection_system.gd` 与 `tools/verify_dialogue_sleep_summary_boundaries.gd` 覆盖；T1101 的敌人波次数据、正门外生成位置、GM 入口和清理流程由 `tools/verify_enemy_wave_generation.gd` 覆盖；T1301 的 HUD 倒计时、配置时间自动来袭、重复触发保护和 GM 跳波入口由 `tools/verify_enemy_wave_schedule.gd` 覆盖；T1102/T1104C 的目标优先级、跳过围墙、移动、敌方建筑攻击和主厅失败状态由 `tools/verify_enemy_target_priority.gd` 覆盖；T1103 的 HUD 警铃、GM 命令、阵型、骑乘表现和遭遇敌人切换由 `tools/verify_combat_alarm_rally.gd` 覆盖；T1104 的双方基础伤害、盔甲减伤、攻击间隔、敌人移除、清敌退出和避战不攻击由 `tools/verify_combat_damage.gd` 覆盖；T1104A 的战斗时间上限、LLM 慢速叠加和清敌恢复由 `tools/verify_combat_time_cap.gd` 覆盖；T1104B 的艾达持剑第一波节奏和战斗动作秒换算由 `tools/verify_combat_pacing.gd` 覆盖；T1105 的兵种策略选项、NPC 面板策略下拉框、策略事件、默认策略重置、战斗内避战和保持距离射击由 `tools/verify_combat_strategies.gd` 覆盖；T1106 的战斗开始 / 结束广播、受伤 / 昏迷 / 击退统计和清敌回工作状态由 `tools/verify_combat_flow.gd` 覆盖；T1203 的完整逃离移动、离站标记和事件由 `tools/verify_escape_station_behavior.gd` 覆盖；T1204A 的逃离警告、NPC 面板入口、对话打开暂停、关闭恢复、五轮置灰、给钱减速、逃离攻击无回复计轮、昏迷暂停和复苏继续由 `tools/verify_escape_intervention_dialogue.gd` 覆盖；T1303 的无可战斗人员失败、未集结误判边界和 HUD / 快照原因由 `tools/verify_no_available_combatants_failure.gd` 覆盖；T1304 的第 5 波胜利、结算快照、HUD 胜利占位和结算后拒绝刷波由 `tools/verify_five_wave_victory.gd` 覆盖。T0107 的统一属性、双建筑通用槽、主厅射程、器械 HP、弱敌人潮、远程距离带和骑兵冲锋 / 僵直由 `tools/verify_t0107_combat_foundation.gd` 及塔防、伤害、策略、波次专项共同覆盖；世界 `+` 直接在 Main 前端验收，不新增 GM 部署入口。
## T0131-P2 小教堂逐级美术验收

- 建筑分组新增“小教堂美术预览（不改权威等级）”Lv.1 / Lv.2，命令为 `chapel_art_level <1|2>`。它只调用 `ChapelArt.debug_force_visual_level(...)`，不会消耗升级资源、修改 HP、开放工位或生成虔诚。
- Lv.1 应看到完整中殿外壳、祭坛、五排左右长凳、中央过道和基础礼仪陈设；Lv.2 增加钟架 / 钟棚、彩窗、两侧扶壁、圣坛屋架和更丰富礼仪物，但席位仍为 10。配合滚轮由远到近检查屋顶、四周墙体、彩窗 / 扶壁和屋架同步透明。
- 自动门直接用“马塞尔→真实主持”或“伊沃→真实祈祷”验收：实体接近入口时双扇打开，离开感应区后关闭；礼拜快照仍是工位 / 虔诚权威观察入口。

## T0131-P3 小诊所逐级美术验收

- 建筑分组新增“小诊所美术预览（不改权威等级）”Lv.1 / Lv.2 / Lv.3，命令为 `clinic_art_level <1|2|3>`。它只切换 `ClinicArt` 表现组，不消耗升级资源，不修改建筑等级、HP、效率、资金、诊疗位或病床数组。
- Lv.1 先检查暖象牙灰泥、鼠尾草绿四坡屋顶 / 中央采光气楼、奶油护理雨棚、百叶窗、两侧药草花箱和叶片药臼徽记；轮廓不应再像工械坊。再检查 2 张医生桌、2 张病床和基础药材 / 清洗 / 隐私陈设；Lv.2 应增加第三床病区、药柜、草药晾棚和西通风口；Lv.3 应再增加第四床病区、消毒器械台、发药窗和东通风口。快照中的医生桌始终为 2，病床为 `2→3→4`，fixture / 碰撞为 `6→7→8`。
- 自动门用“莉娜→小诊所真实坐诊”验收；医生无病人时坐桌读书，有病人时离座巡床治疗。配合滚轮检查外壳与升级通风结构同步透明，透明后点击室内 NPC / 空地分别保持 NPCPanel / BuildingPanel 优先级。

## T0131-P4 食堂逐级美术验收

- 建筑分组新增“食堂美术预览（不改权威等级）”Lv.1 / Lv.2 / Lv.3，命令为 `dining_hall_art_level <1|2|3>`。它只切换 `DiningHallArt` 表现组，不消耗升级资源，不修改建筑等级、HP、生产 / 进食效率、粮食、餐食、灶台或座位数组。
- Lv.1 检查横向暖赭公共饭堂、低缓陶瓦屋顶、两组后厨烟囱、汤勺餐盘徽记、两张厚木长桌、十把椅子和两口实际灶台；Lv.2 应增加储粮 / 香料 / 餐具、备餐、燃料棚和双灶排烟强化，但灶台仍为 2；Lv.3 才出现第三灶、第三排烟罩 / 屋顶烟囱和发餐扩展。快照中的灶台为 `2→2→3`，席位固定 `10`，fixture / 碰撞为 `14→14→15`。
- 自动门用“布鲁诺→真实食堂工作”验收；真实进食入口用于检查十席轮转。配合滚轮检查主屋面、烟囱、燃料棚和升级附件同步透明，透明后点击布鲁诺 / 用餐 NPC 优先打开 NPCPanel，点击空地仍打开 BuildingPanel。

## T0131-P5 宿舍逐级美术验收

- 建筑分组新增“宿舍美术预览（不改权威等级）”Lv.1 / Lv.2，命令为 `dormitory_art_level <1|2>`。它只切换 `DormitoryArt` 表现组，不消耗升级资源，不修改建筑等级、HP、睡眠恢复、疲劳、固定床归属或占用。
- Lv.1 检查五段集体长屋、深酒红低坡顶、五个通风帽、月牙枕头徽记，以及两列五排十张床、十套个人脚箱 / 挂衣位、布草、洗漱、值日板和夜灯；Lv.2 应增加后墙壁炉 / 垂直烟道、保温护墙、窗板、修补撑 / 顶梁、备柴与扩充布草，但床位仍为 10，归属仍为 8+2 预留。
- 自动门用“艾达→固定床”或 `formal_dormitory_sleep run` 验收；实体接近门口开门，真实到床并挂接后才算睡眠。配合滚轮检查主屋面、墙体、二级烟道 / 顶梁 / 外部附件同步透明，透明后点击艾达打开 NPCPanel，点击空地仍打开 BuildingPanel。
