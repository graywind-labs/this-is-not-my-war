# ART_PIPELINE.md

> 本文件规定项目美术资产从获取、审计、筛选、导入到 Godot 场景包装的流程。建筑 / 道具 / 环境继续以 Quaternius 为主；任何角色或其他第三方美术资产进入正式场景前也必须经过本流程。

T0132-P4b 资产审计：已导入 Quaternius 建筑 / 道具目录中没有 arrow tower、watch tower weapon 或可直接替代的同尺度成品。正式箭塔沿用 P4a 方法，以已登记的 WoodTrim / MetalOrnaments / RoundTiles BaseColor、Normal、Roughness 组合项目原生低模结构；所有程序 Mesh 必须有正式材质、可审计包络和实际渲染结果。主厅器械台也使用独立正式场景替换旧石平台 GLB，避免在 StationLayoutController 内继续叠加灰色装饰盒。

T0132-P4a 资产审计：当前隔离源目录和已导入 Quaternius Medieval Village / Fantasy Props 中均未发现 ballista、siege crossbow、catapult 或可直接替代的成品模型。正式弩床因此不引入新授权来源，也不使用 AI 位图伪装 3D 结构；它只复用已登记的 Quaternius WoodTrim / MetalOrnaments PBR 贴图，以项目原生 MeshInstance3D 组合可审计低模结构。程序网格仍必须带正式贴图材质、服从平台包络并通过 D3D12 实际渲染，不能因“程序生成”降低到纯色灰盒标准。

## 1. 已确认的主要资产家族

| 用途 | 资产包 | 官方来源 |
|---|---|---|
| 模块化建筑与室内墙体 | Medieval Village MegaKit | https://quaternius.com/packs/medievalvillagemegakit.html |
| 家具、工具、食物、武器与室内道具 | Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html |
| 男女基础人形、发型和面部基础 | Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html |
| 中世纪职业与幻想服装模块 | Modular Character Outfits - Fantasy | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html |
| 移动、工作、战斗等共享动画 | Universal Animation Library 2 | https://quaternius.com/packs/universalanimationlibrary2.html |
| 树、草、花、岩石与环境装饰 | Stylized Nature MegaKit | https://quaternius.com/packs/stylizednaturemegakit.html |

T0130 角色换型已采用 Synty `POLYGON MINI - Fantasy Characters` 可见模型与 KayKit Character Animations 共享动作。前者是用户合法购买的付费许可资产，原始包只放隔离源目录，不能由仓库代发或提交未授权源文件；本流程只做确定性导入、骨骼重定向、材质实例、挂点和场景配置，不让模型源文件进入生成式建模流程。后者为 CC0，已保存官方来源、版本、许可快照与哈希。建筑 / 室内 / 环境继续使用 Quaternius，不随角色换型变更。

P4R 补充角色色板 / 工具验收规则：主题图集可能把服装、头巾等大片 UV 统一替色，不能只看“整体色调符合”就放行；必须确认皮肤、头发、头饰和服装仍能分辨。长柄工具也不能只检查挂点父节点，至少应覆盖一个完整工作循环，验证工具工作端位于人物前方、柄身进入双手工作区且落点方向符合工位语义。

P4R2 / P5R2 补充 Synty 面部材质规则：部分 Mini 人物的眉眼依赖导入 BaseMaterial3D 的 `vertex_color_use_as_albedo` 与 `_A` Albedo，不能把 `_C` 配色层直接当最终贴图，也不能用忽略顶点色的共享 Shader 覆盖。职业换色若会丢失作者面部，优先复制原导入材质并选择同系列 `_A`；必须用实际渲染近景验证，而不是只检查资源路径。

当前决策：先使用作者官方免费 / Standard 版本完成 T0124–T0129。Pro / Source 版本包含的额外模型、Godot 工程、源 `.blend`、自定义 Shader 或碰撞是否值得购买，必须等免费版导入验证后再向用户单独说明并确认。

### 1.1 T0124 免费包实测结论

2026-08-11 已从上述官方页面对应的 itch.io 免费入口取得六个 Standard 包，并完成哈希、CC0 许可与隔离解包。机器清单见 `art_source/manifests/quaternius_free_standard_inventory.json`，人工结论见 `docs/QUATERNIUS_ASSET_INVENTORY.md`。

- 建筑 / 道具 / 自然分别实际提供 176 / 94 / 68 份 glTF；六包均未发现命名碰撞资源或 Godot 工程。
- 基础角色与服装使用相同的 65 关节骨骼；免费服装主要只有男女农民 / 游侠。
- 动画库免费包实际为 43 个唯一片段，root motion 与非 root motion 两套共 86 轨，不等同于宣传页完整 130+ 范围。
- 当前内容足以进入 T0125 的最小导入和比例验证，但碰撞、职业动作和职业服装仍是明确缺口；T0129 垂直切片前不购买付费档位。

## 2. 目录职责

```text
art_source/                         原始下载、解包、DCC 源文件和许可证；含 .gdignore，不被 Godot 导入
├─ downloads/                      原始压缩包，本地获取后按任务决定是否纳入版本管理
├─ quaternius/                     按资产包保存解包后的原始内容
├─ licenses/                       原始许可证与来源快照
└─ working/                        Blender 等 DCC 工作文件

assets/                            Godot 运行时可导入资产
├─ 3d/quaternius/                  经筛选的 GLB、纹理和动画库来源
├─ 2d/                             UI 图标、头像、贴花和纹理
├─ materials/                      运行时共享材质与 Shader 资源
├─ vfx/                            VFX 使用的 Mesh、纹理和贴花
├─ audio/                          音效与环境音
└─ THIRD_PARTY_ASSETS.md           实际使用资产与许可台账

scenes/
├─ art/                            ArtSandbox 与纯美术验证场景
├─ buildings/                      建筑正式包装场景
├─ characters/                     共享人形与 8 名 NPC 外观场景
├─ environment/                    地面、自然物与环境组合场景
└─ vfx/                            粒子、贴花、命中和建筑反馈场景

resources/
├─ materials/                      Godot .tres 材质与 Shader 参数
└─ themes/                         项目级 UI Theme、StyleBox、字体和图标映射

scripts/presentation/              只读权威状态的表现层脚本
data/presentation/                 表现配置，例如屋顶阈值、材质映射、角色外观和 VFX 预算
```

`art_source/` 中的 `.gdignore` 必须保留。正式运行时只引用 `assets/`、`scenes/` 和 `resources/`，不得直接引用下载压缩包或 DCC 临时路径。

表现配置继续遵守数据 / 代码分离：可调阈值、外观映射和预算进入 `data/presentation/`，不得散落硬编码在建筑或 NPC 脚本中；这些配置只影响显示，不保存权威玩法数值。

## 3. 每个资产包的处理顺序

1. 从作者官方页面下载。
2. 在 `art_source/licenses/` 保存许可证和来源说明。
3. 计算下载文件摘要，记录下载日期、版本、免费 / Pro / Source 档位。
4. 解包到 `art_source/quaternius/<pack_id>/`。
5. 清点 GLB / glTF / FBX / OBJ / Blend、纹理、骨骼、动画、碰撞和示例工程。
6. 在 DCC 或独立查看器中筛选实际需要的资产。
7. 只把选中的 GLB、纹理或动画复制 / 导出到 `assets/3d/quaternius/<category>/`。
8. 在 `ArtSandbox.tscn` 验证比例、朝向、材质、阴影、骨骼和动画。
9. 用 Godot 继承场景包装碰撞、挂点、导航和表现脚本；不直接修改导入生成的只读场景。
10. 在 `assets/THIRD_PARTY_ASSETS.md` 登记最终实际使用文件。

## 4. 格式与版本管理

- Godot 运行时首选二进制 glTF `.glb`。
- `.blend`、导出脚本和尚未清理的源文件放在 `art_source/working/`，不由正式场景直接引用。
- FBX 只作为必要中间来源，不作为项目首选运行时格式。
- 不同时保留同一模型的 OBJ、FBX、glTF 和 GLB 四份运行时副本。
- 六个原始 Standard ZIP 合计约 818 MB，解包内容还包含 glTF / FBX / OBJ 重复格式；原始压缩包、完整解包副本和网页快照只保留在本机隔离区并由 `.gitignore` 排除，仓库跟踪哈希清单、许可和人工盘点。
- 本机 Git LFS 可用；T1705 起统一管理真正进入 `assets/` 的运行时 GLB、FBX、PNG、JPG、WebP、WAV 与 OGG，不为原始下载包、重复格式、候选废稿或 DCC 工作文件建立 LFS 副本。
- `pack_gltf_to_glb.py --external-images` 只把网格 / 骨骼装入 GLB，并把贴图按目标 GLB 前缀稳定外置；这避免 Godot 从内嵌 GLB 再抽取一份同内容 PNG。Godot `.import` 配置使用普通 Git，`.godot/` 导入缓存不提交；新设备克隆后通过 `git lfs pull` 取得运行时二进制并让 Godot 重建缓存。
- 仓库只跟踪 `art_source/licenses/`、`art_source/manifests/` 和目录说明；完整源包、`working/`、`runtime_rejected/`、视觉 QA 产物与日志保留在独立本地 / 云端素材库，不得因跨设备同步而把付费素材完整源文件提交到项目仓库。
- 当前运行时 PNG 保留原始文件供可逆重导入，但 Godot `.import` 的 `process/size_limit=2048`；所有 3D 贴图生成 mipmap并使用 VRAM 压缩。
- 不提交缓存、自动生成的 Godot `.godot/imported` 内容或无用示例工程。

## 5. 命名规范

运行时文件使用英文小写 `snake_case`：

```text
assets/3d/quaternius/buildings/wall_timber_window_a.glb
assets/3d/quaternius/props/anvil_a.glb
assets/3d/quaternius/characters/base_male_regular.glb
assets/3d/quaternius/animations/work_blacksmith_hammer.glb
scenes/buildings/BlacksmithArtView.tscn
scenes/characters/NPCArtView.tscn
resources/themes/game_theme.tres
```

第三方原始文件名可以在 `art_source/` 保留；复制到运行时目录时必须进入清单并按项目命名统一。

## 6. 统一尺寸与朝向

T0125 已实测确认：

- 1 Godot 单位对应 1 米；导入 `scale=1.0`。
- `+Y` 向上、人形正面 `-Z`，脚底 / 建筑地面以局部 `Y=0` 落地。
- 普通 NPC 参考身高 1.82 m，可接受基础体范围 1.72–1.92 m。
- 建筑模块网格 2.0 m、层高 3.125 m、墙厚 0.406 m。
- 圆门参考门扇 1.12 × 2.318 m，导航净宽最低 0.90 m；真实入口在 T0127 复核。
- 小型道具 Pivot 放在落地中心或逻辑抓握点，大型自然物 Pivot 放在树干 / 岩石落地点；异常 Pivot 必须在包装层增加中间节点，不改导入 scale。

机器配置见 `data/presentation/art_scale_baseline.json`，完整样本 AABB、色板和保留 / 淘汰清单见 `docs/ART_BASELINE.md`。不允许每个场景用随意 `scale` 修补视觉大小。

## 7. 建筑包装合同

建议的公共结构：

```text
BuildingArtView
├─ Exterior
├─ Roof
├─ Interior
│  ├─ Floor
│  ├─ Furniture
│  └─ WorkstationMarkers
├─ UpgradeVisuals
├─ EntryMarker
├─ ExitMarker
├─ InteriorTrigger
├─ NavigationRegion3D
├─ StaticCollision
├─ ClickArea
└─ DamageFXMounts
```

- `Roof` 只接受统一屋顶透明系统控制。
- `WorkstationMarkers` 使用和配置 `workstations[].id` 相同的 ID。
- `UpgradeVisuals` 按等级只投影 BuildingSystem 已确认的等级。
- `InteriorTrigger` 负责物理跨门边界，不负责资源或行动结算。
- 碰撞、导航和视觉可以来自 Source 包的现成内容，也可以由项目包装场景补齐。
- 制作任何建筑前，先从 `docs/SCENE_SPACE_AND_VISUAL_PLAN.md` 读取该建筑的最大等级预留地块、最高位置数和逐级增量；必须先在最高等级灰盒中放下全部设备、Marker、通道和 NPC 动作净空，再制作 Lv.1 外壳。
- 每次导出记录房体 / 屋檐实际 AABB；可见功能设备与 Marker 使用同一稳定 ID。只提高 HP / 效率的等级不得增加设备 ID，增加容量的等级必须同步增加设备、Marker、碰撞和导航净空。
- 进入正式精修前先查询本地 Quaternius 清单：存在合适主体资产时直接筛选、打包和实例化，项目代码只负责组合、局部补件、材质适配及碰撞；不存在时才登记程序几何或新资产需求。批量建筑制作必须拆成单建筑视觉评审，前一座未通过近景功能阅读、最高等级排布和导航回归前，不开始下一座。

T0126 已把本合同落地为 `scenes/buildings/BuildingArtView.tscn` 与 `scripts/presentation/buildings/BuildingArtView.gd`。`RoofVisibilityController.gd` 是唯一相机距离读取者；包装场景只配置阈值。T0127 为正式铁匠铺补齐 `DoorInsideMarker / InteriorStandingMarker / forge_01 / forge_02`，并以门外 → 门内 → 工位的确定性 Marker 路线完成首个真实进出与权威提交样本。`NavigationRegion3D` 仍是禁用占位，不能用铁匠铺完成状态宣称全站 NavMesh 或其他建筑室内导航已完成。

T0129A 的 `StationSpatialSandbox.tscn` 是进入逐建筑生产前的空间门禁：v0.5 锁定当前 Main 的相对功能布局、中央最大主厅、错位地块、八方向正面、入口接路、弯折道路、分散小泥地、单一深绿草地主色、低位河槽和延伸到地图边缘的自然散布，后续不得回退为任意小角度、中轴对称或棋盘式布局。`station_spatial_plan.json` 只登记最大地块和最高位置数量，黄色提示块不是正式设备、Marker 或可用工位。每座建筑仍必须在自己的最高等级灰盒中完成真实设备、同 ID Marker、通道和动画净空验证。

A3b9R 按上述流程从 Fantasy Props Standard 的 `Bench / BookStand / CandleStick_Triple / Chalice / Book_7` 打包五个教堂专用 GLB。运行时以长凳作为十席主体，以项目包装补单席座垫、靠背 / 跪栏和祭坛结构；没有修改导入缓存，也没有让视觉长凳数量反推 BuildingSystem 容量。

A3b10R 从同包的 `Workbench / Shelf_Simple / Rope_1` 打包 `workshop_workbench / workshop_shelf / workshop_rope` 三个运行时 GLB，并外置 6 张 Furniture / Metal Trim 纹理。项目包装层在工作台上增加制弓、机件和攻城总装三组职责细节，在货架 / 绳卷上补工具墙、吊架与材料区结构。候选 `Workbench_Drawers` 经 Godot 网格检查出现约 7% 退化 UV，已从运行时引用和目录移除并隔离到 `art_source/runtime_rejected/a3b10r_workshop_drawers/`；不得为了“资产更多”把不合格候选留在导出集。

A3b11R 从 Medieval Village Standard 打包 `Wall_UnevenBrick_Window_Wide_Flat / Wall_UnevenBrick_Door_Round / Roof_RoundTiles_8x12 / Roof_Tower_RoundTiles / Stairs_Exterior_Platform / Prop_Support / Floor_UnevenBrick`，从 Fantasy Props Standard 打包 `Banner_1 / Lantern_Wall`；运行时命名统一为 `main_hall_*`。建筑素材复用 `wall_plaster_door_round` 共享前缀，新增 Brick / UnevenBrick / MetalOrnaments 8 张纹理；道具复用 `chapel` 前缀，新增 Cloth 3 张纹理。项目包装只负责组合立面、屋顶、平台和等级装饰，实体碰撞继续读取 `building_fixture_layout_v1`，槽位 / HP / 失败条件继续由权威系统决定。

A3b12R 从 Medieval Village Standard 打包 `Wall_Plaster_WoodGrid / Roof_Wooden_2x1 / Prop_Wagon`，从 Fantasy Props Standard 打包 `Shelf_Arch / Bag / Crate_Metal / Barrel_Apples / Chest_Wood`，运行时统一使用 `warehouse_*` 名称。八件资产全部按字节复用既有 `wall_plaster_door_round` 或 `chapel` 外置纹理，没有新增 PNG。仓库包装组合外壳、装卸门 / 雨棚 / 滑轮、近景渐隐屋顶和类别货堆；货运车使用与可见 AABB 相符的独立 BoxShape，库存数量、等级容量和敌人目标仍由权威系统决定。当前运行时筛选集为 54 GLB / 75 PNG。

## 8. 角色包装合同

```text
NPCArtView
├─ CharacterModel
├─ Skeleton3D
├─ AnimationPlayer
├─ AnimationTree
├─ EquipmentSockets
├─ PhysicalBoneSimulator3D
├─ SelectionArea
└─ VFXMounts
```

- 所有 NPC 共享基础骨骼、动画参数名和装备挂点合同。
- 角色差异通过体型、材质、发型、服装、附件和职业工具组合，不复制八套逻辑脚本。
- 动画和布娃娃只消费权威状态；CombatSystem、NPCSystem、ActionSystem 继续决定事实。

T0128 已把合同落地为 `scenes/characters/GlenArtView.tscn` 与 `scripts/presentation/characters/NPCArtView.gd`。实际结构使用隐藏 mannequin 的 UAL2 `RigSource` 提供 65 骨骼 / AnimationPlayer，基础体、服装和头发的 8 个可见 skinned mesh 重新绑定到该骨架；导入 GLB 仍只读。A5-P5a–P5h 曾用同一装配为其余 7 名初始 NPC 建立低配正式外观；T0130-P1–P8 已将 8 名初始 NPC 的生产映射全部迁到 Synty，旧包装只保留兼容回退。

T0128A 在 `CharacterPivot/SourceFacingCorrection` 统一修正 Quaternius 可见源模型 180°朝向差；CharacterPivot 本身继续使用项目 `-Z` 前向。运行时先复制每个 AnimationLibrary，再在实例副本上把持续状态片段设为 `LOOP_LINEAR`，既不改第三方导入缓存，也避免非循环源动画在第一遍后停住。

统一状态合同为 `idle / walk / run / talk / work / attack / hit_react / unconscious / get_up`。T0133-P2 已将生产 Chibi 骨架下的 `PhysicalBoneSimulator3D` 接通为按需 12 骨骼链；非骑乘昏迷模拟后冻结姿态，复苏时渐隐回动画，骑乘与超预算单位继续使用既有受控动画。物理骨骼只消费权威状态，不成为 HP 或碰撞判定来源。

A5 系列在基础合同上增加 `training_instructor / training_practice / mass_leader / seated_prayer / seated_eating / vehicle_seated` 表现态，当前总计 15 个状态。A5-P5j 的 `seated_eating` 复用 UAL2 `Consume` 手到口循环，并由餐椅 `sitting` 锚点和 `(-0.60 m)` 局部下沉形成低配坐姿；该偏移只影响 CharacterPivot，不移动 NPC 根、不提交座位，也不结算餐食或饱食。后续若取得原生坐姿进食片段，应替换 clip / offset，不更改 `seated_eating` 状态名与到座后才 active 的权威合同。

T0130 使用的 Synty Source Files v2 与 KayKit Character Animations 1.1 已在 `art_source/` 完成哈希、许可证与完整源隔离；运行时只筛选当前获准的 8 名初始 NPC / 剑盾敌人、锤 / 马厩工具 / 剑 / 盾、调色板和 KayKit Medium Rig 8 组 GLB。P5–P8 候选只在临时目录同镜头比较；最终额外保留 ShieldMaiden、Wizard 长袍基础、Pirates GovDaughter 与 Pirates Firstmate，其他候选移回隔离工作区。Synty FBX 内仍引用原作者 PSD，因此包装层显式绑定随包 PNG 调色板，不伪造缺失贴图。

双角色包装使用 Godot 4.6 `RetargetModifier3D + SkeletonProfileHumanoid`。目标模型必须先同步 Skin bind name 与标准骨名，再挂到 modifier，避免首次缓存全部未映射；`use_global_pose=false` 保留 Synty 骨长，避免 KayKit / Synty 比例差导致躯干和四肢压缩。KayKit mannequin 网格被移除，只保留驱动骨架；当前导入得到 131 段可用非空片段并构成进程内共享 AnimationLibrary，实例不重复复制。P0 视觉已通过；P1 仅更新格伦与步行剑盾兵生产映射，生产包装删除沙盒选择体并复用父级实体碰撞。旧 Quaternius 角色继续作为尚未逐个完成的职业 / 敌种回退路径。

Synty 当前筛选人物的美术正面是模型本地 `+Z`，项目实体合同则以角色根本地 `-Z` 指向目标。包装必须把 `180°` 差异保留在可见模型层，不能烘进 NavigationAgent、ActorMotionBody、工位或攻击方向；导入新职业 / 敌种时必须同时验证源轴元数据、两个世界移动方向和静态目标面向。

P2 从隔离源新增且只新增 `SK_Adventure_Peasant_01.fbx / Prop_Broom_01.fbx`。托马包装复用现有 `PolygonMinis_Texture_01_C.png`、相同人形骨名同步和 KayKit 共享库；`Working_B` 在共享库创建时一次性标为循环，不为每个托马实例复制 Animation。运行时 Synty 子集现为 3 角色 / 4 道具 / 18 调色板，完整商业源仍不进入仓库或导出包。

P3 从隔离源只新增 `SK_Adventure_ShopKeeper_01.fbx`；布鲁诺复用既有 `PolygonMinis_Texture_Red_C.png` 与共享 KayKit 库，`Working_C` 已由共享循环清单处理。木柄铜勺由项目包装中的 PrimitiveMesh 确定性组合，不修改或派生 Synty 网格。运行时 Synty 子集现为 4 角色 / 4 源道具 / 18 调色板。

P4 候选对照后只从隔离源新增 `SK_Pirates_Deckhand_01.fbx`；德鲁伊、草帽村民和镇民候选移回 `art_source/working/`，不进入运行时。伊沃复用 `PolygonMinis_Texture_Green_C.png`，包装 shader 只做运行时确定性色调分级，`Digging` 进入共享循环清单。木柄铁锄由项目 PrimitiveMesh 组合，不修改或派生 Synty 网格。运行时 Synty 子集现为 5 角色 / 4 源道具 / 18 调色板。

P5 只从隔离源新增 `SK_Vikings_ShieldMaiden_01.fbx`；P5R2 改用保留作者顶点色面部的 `PolygonMinis_Texture_Blue_A.png`。P6 只新增 `SK_Fantasy_Wizard_01.fbx`，但包装运行时按连通拓扑移除与头脸分离的尖帽岛，并以项目 PrimitiveMesh 添加木质胸前圣徽；P6R 再以默认关闭、仅马塞尔启用的低分段 SphereMesh 补齐原帽下平顶，按 Head global rest 校准挂点，没有修改或导出 Synty 源网格。马塞尔使用 `Purple_A + vertex_color_use_as_albedo`，酿酒与弥撒专属 clip 继续来自共享 KayKit 库。运行时 Synty 子集仍为 7 角色 / 4 源道具 / 18 调色板。

P7 对六名女性候选做相同镜头 / 材质 / 骨骼审计后，只从隔离源新增 `SK_Pirates_GovDaughter_01.fbx` 到运行时；整组候选比较副本归档到 `art_source/working/t0130_p7_candidates_rejected/`，不会被 Godot 运行时扫描。莉娜保留导入 BaseMaterial3D 与 `Blue_A + vertex_color_use_as_albedo`，药包、病历册、绷带均由项目 PrimitiveMesh 确定性组合，不修改或派生 Synty 网格。共享 KayKit 状态合同增至 17 个，运行时 Synty 子集现为 8 角色 / 4 源道具 / 18 调色板。

P8 对 Western TownMan / Samurai VillageMan / Pirates Firstmate / Fantasy Bard / Fantasy Rogue 五名男性候选做同镜头审计后，只保留 `SK_Pirates_Firstmate_01.fbx` 到运行时；其余比较副本归档到 `art_source/working/t0130_p8_candidates_rejected/`。欧文保留导入 BaseMaterial3D、`_01_A + vertex_color_use_as_albedo`；铜框护目镜、工具袋、折尺、木楔和短扳手均由项目 PrimitiveMesh 确定性组合，不修改或派生 Synty 网格。运行时 Synty 子集最终为 9 角色 / 4 源道具 / 18 调色板。

## 9. UI 与 AI 生成图像

- 正式 UI 使用 Godot `Theme`、NinePatch / StyleBox 和统一图标映射，不能用一张整屏位图代替可交互控件。
- AI 图像可用于风格探索、NPC 头像、结算插画、UI 装饰、图标草案、血迹 / 裂痕贴花草案。
- AI 图像不直接替代需要骨骼、碰撞、模块拼接或精确缩放的 3D 资产。
- 任何生成图进入正式项目时，需记录生成日期、用途、提示摘要和人工清理情况，并检查透明边缘、尺寸、风格一致性与可读性。

## 10. 逐步执行入口

```text
执行 T0124  获取并审计免费资产
执行 T0125  验证导入和风格基线
执行 T0126  实现屋顶远近透明
执行 T0127  实现真实室内进入和工位权威迁移
执行 T0128  建立格伦角色与动画基础
执行 T0129  正式地图铁匠铺垂直切片已完成并由用户最终确认
执行 T0129A 确认全站画面与空间规划，并先做独立空间灰盒
执行 T0130  先做偏两头身格伦 + 剑盾敌人双角色试片，再批量制作 8 名 NPC
执行 T0131  批量制作可进入建筑
执行 T0132  制作不可进入建筑与城防
执行 T0133  完成战斗表现与布娃娃
执行 T0134  完成正式 UI 美术化
执行 T0135  完成环境、灯光和音效
执行 T0136  全量整合与最终验收
```
