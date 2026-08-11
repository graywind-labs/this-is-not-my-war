# ART_PIPELINE.md

> 本文件规定 Quaternius 美术资产从获取、审计、筛选、导入到 Godot 场景包装的流程。任何第三方美术资产进入正式场景前都必须经过本流程。

## 1. 已确认的主要资产家族

| 用途 | 资产包 | 官方来源 |
|---|---|---|
| 模块化建筑与室内墙体 | Medieval Village MegaKit | https://quaternius.com/packs/medievalvillagemegakit.html |
| 家具、工具、食物、武器与室内道具 | Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html |
| 男女基础人形、发型和面部基础 | Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html |
| 中世纪职业与幻想服装模块 | Modular Character Outfits - Fantasy | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html |
| 移动、工作、战斗等共享动画 | Universal Animation Library 2 | https://quaternius.com/packs/universalanimationlibrary2.html |
| 树、草、花、岩石与环境装饰 | Stylized Nature MegaKit | https://quaternius.com/packs/stylizednaturemegakit.html |

当前决策：先使用作者官方免费 / Standard 版本完成 T0124–T0129。Pro / Source 版本包含的额外模型、Godot 工程、源 `.blend`、自定义 Shader 或碰撞是否值得购买，必须等免费版导入验证后再向用户单独说明并确认。

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
- 大型二进制是否纳入 Git LFS 在 T0124 根据实际体积和本机工具可用性决定；未确认前不修改 `.gitattributes`。
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

T0125 必须实际测量并记录：

- 1 Godot 单位对应的世界米制。
- 普通 NPC 目标身高。
- 门宽、门高、楼层高度和模块网格尺寸。
- 角色模型正面方向。
- 武器、工具、坐骑和家具的缩放基准。
- 建筑、角色和 VFX 的原点 / Pivot 约定。

在这些基准确认前，不允许每个场景用随意 `scale` 修补视觉大小。

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
执行 T0129  完成铁匠铺垂直切片并等待用户确认
执行 T0130  批量制作 8 名 NPC
执行 T0131  批量制作可进入建筑
执行 T0132  制作不可进入建筑与城防
执行 T0133  完成战斗表现与布娃娃
执行 T0134  完成正式 UI 美术化
执行 T0135  完成环境、灯光和音效
执行 T0136  全量整合与最终验收
```
