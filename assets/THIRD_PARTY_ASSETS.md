# THIRD_PARTY_ASSETS.md

> 本文件记录正式进入项目的第三方美术和音频资产。即使许可证不要求署名，也必须保留来源、许可证和使用范围，便于参赛提交、重新下载和后续审计。

## 登记字段

| 资产包 | 作者 | 官方来源 | 获取日期 | 版本 / 档位 | 许可证 | 本地许可证 | 实际使用文件 / 范围 | 修改说明 |
|---|---|---|---|---|---|---|---|---|
| Medieval Village MegaKit | Quaternius | https://quaternius.com/packs/medievalvillagemegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | `art_source/licenses/QUATERNIUS_CC0_SOURCE_RECORD.md` | `assets/3d/quaternius/buildings/` 下 15 GLB / 26 PNG；A3b12R 新增木网格墙、木屋顶与货运车 | glTF 网格打包为 GLB；仓库三件来自 `Wall_Plaster_WoodGrid / Roof_Wooden_2x1 / Prop_Wagon`，按字节复用既有 WoodTrim / Plaster 纹理，Godot 导入上限 2K |
| Fantasy Props MegaKit | Quaternius | https://quaternius.com/packs/fantasypropsmegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | 同上 | `assets/3d/quaternius/props/` 下源自本包的 34 GLB / 33 PNG；A3b12R 新增 `warehouse_{shelf_arch,bag,metal_crate,apple_barrel,chest}.glb` | 铁匠铺、诊所、食堂、酒窖、菜园、训练场、教堂、工械坊、主厅、仓库与单敌剑盾样片；仓库五件来自 `Shelf_Arch / Bag / Crate_Metal / Barrel_Apples / Chest_Wood`，按字节复用既有共享纹理 |
| Universal Base Characters | Quaternius | https://quaternius.com/packs/universalbasecharacters.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | 同上 | `assets/3d/quaternius/characters/{base_male,hair_buzzed}.glb` 及 `base_male_*` 7 PNG | 修复包内两处 `_png.png` URI 后打包；短发复用已有 Hair 贴图，两者已装配为格伦正式基础体 / 发型 |
| Modular Character Outfits - Fantasy | Quaternius | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | 同上 | `assets/3d/quaternius/characters/male_peasant_outfit.glb` 及同前缀 6 PNG | 男性农民模块服装，已装配为格伦 T0128 正式服装 |
| Universal Animation Library 2 | Quaternius | https://quaternius.com/packs/universalanimationlibrary2.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | 同上 | `assets/3d/quaternius/animations/ual2_standard.glb` | 原始非 root-motion GLB；43 段动画作为格伦 rig / 状态机来源，mannequin 隐藏不作可见角色；run / forge / fall 使用已登记适配别名 |
| Stylized Nature MegaKit | Quaternius | https://quaternius.com/packs/stylizednaturemegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0 | 同上 | `assets/3d/quaternius/nature/common_tree_a.glb` 及同前缀 3 PNG；`assets/3d/quaternius/nature/ground_detail/` 下 5 GLB / 3 PNG | CommonTree_1 重命名打包；T0135-P1 新增 `Pebble_Round_1 / Pebble_Square_1 / Grass_Common_Short / Grass_Wispy_Short / Clover_1`；P2 复用前两者作为放大灰褐岸坡岩石。全部只作无碰撞自然表现 |
| Ultimate Animated Animal Pack | Quaternius | https://quaternius.com/packs/ultimateanimatedanimals.html | 2026-08-18 | 官方免费完整包 | CC0 1.0 | `art_source/quaternius/ultimate-animated-animals/License.txt` | `assets/3d/quaternius/animals/merchant_horse.glb` | 从官方 Google Drive 包筛选 Horse glTF 并打包 GLB；运行时使用约 `0.46 × 0.36 × 0.42` 的比例适配及 Walk / Idle 作为行商挽马 |
| POLYGON Mini Fantasy Characters | Synty Studios | 用户购买账户取得的官方 Source Files | 2026-08-19 | Source Files v2 / Unity 2022.3 v1.7.1 | Synty 商业资产许可，发行前按购买账户复核 | `art_source/licenses/SYNTY_POLYGON_MINI_FANTASY_CHARACTERS_SOURCE_RECORD.md` | `assets/3d/synty/t0130_pilot/` 下 9 个角色 FBX、4 个道具 FBX、18 张调色板 PNG | T0130-P0–P8 用于 8 名初始 NPC 与剑盾敌人确定性导入、调色板绑定、骨骼名 / Skin 绑定同步及职业 / 装备道具装配；马塞尔圣徽、布鲁诺铜勺、伊沃园锄、莉娜医疗附件及欧文工程附件均为项目 PrimitiveMesh，未使用生成式 AI 派生 Synty 纹理或整个人物网格 |
| KayKit Character Animations | Kay Lousberg | https://kaylousberg.itch.io/kaykit-animations | 2026-08-19 | 1.1 / Rig Medium | CC0 1.0 | `art_source/licenses/KAYKIT_CHARACTER_ANIMATIONS_CC0_SOURCE_RECORD.md` | `assets/3d/kaykit/animations/rig_medium/` 下 8 个 GLB 动作集合 | Godot 4.6 `RetargetModifier3D + SkeletonProfileHumanoid` 实时试片；161 段候选动作按实例共享，KayKit mannequin 不渲染 |

## 已获取的完整隔离源（仅上表子集进入运行时）

| 资产包 | 作者 | 官方来源 | 获取日期 | 档位 | 许可证 / 本地证据 | 隔离源范围 |
|---|---|---|---|---|---|---|
| Medieval Village MegaKit | Quaternius | https://quaternius.com/packs/medievalvillagemegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0；`art_source/licenses/QUATERNIUS_CC0_SOURCE_RECORD.md` | 176 份 glTF / FBX / OBJ 模块；15 个筛选 GLB 进入运行时，其中 A3b12R 新增 3 件 |
| Fantasy Props MegaKit | Quaternius | https://quaternius.com/packs/fantasypropsmegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0；同上 | 94 份 glTF / FBX / OBJ 道具；上表 34 个筛选道具进入运行时；`Workbench_Drawers` 因退化 UV 仅保留在 `art_source/runtime_rejected/` |
| Universal Base Characters | Quaternius | https://quaternius.com/packs/universalbasecharacters.html | 2026-08-11 | Standard 免费版 | CC0 1.0；同上 | 男女基础体、头发 / 眉毛完整来源；上表男性基础体和短发进入运行时 |
| Modular Character Outfits - Fantasy | Quaternius | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | 2026-08-11 | Standard 免费版 | CC0 1.0；同上 | 24 份农民 / 游侠服装 glTF；仅上表男性农民组合进入运行时 |
| Universal Animation Library 2 | Quaternius | https://quaternius.com/packs/universalanimationlibrary2.html | 2026-08-11 | Standard 免费版 | CC0 1.0；同上 | 43 个唯一动画、RM / 非 RM 两套；仅上表非 RM GLB 进入运行时 |
| Stylized Nature MegaKit | Quaternius | https://quaternius.com/packs/stylizednaturemegakit.html | 2026-08-11 | Standard 免费版 | CC0 1.0；同上 | 68 份自然模型；当前 CommonTree_1 与 T0135-P1 的 5 个地表细节模型进入运行时，其余继续隔离 |
| Ultimate Animated Animal Pack | Quaternius | https://quaternius.com/packs/ultimateanimatedanimals.html | 2026-08-18 | 官方免费完整包 | CC0 1.0；`art_source/quaternius/ultimate-animated-animals/License.txt` | 12 种动物的 Blend / FBX / OBJ / glTF 与预览；仅 Horse FBX 进入运行时 |
| POLYGON Mini Fantasy Characters | Synty Studios | 用户购买账户取得的官方 Source Files | 2026-08-19 | Source Files v2 | 商业资产；`art_source/licenses/SYNTY_POLYGON_MINI_FANTASY_CHARACTERS_SOURCE_RECORD.md` | 60 个常规角色 FBX、60 个 Unreal 变体、28 个道具 FBX / OBJ、18 张纹理；当前仅上表 13 FBX / 18 PNG 进入 P0–P8 运行时 |
| KayKit Character Animations | Kay Lousberg | https://kaylousberg.itch.io/kaykit-animations | 2026-08-19 | 1.1 | CC0 1.0；`art_source/licenses/KAYKIT_CHARACTER_ANIMATIONS_CC0_SOURCE_RECORD.md` | Large / Medium 动作的 16 FBX + 16 GLB；仅 Medium 的 8 GLB 进入 P0 运行时 |

逐包 ZIP 字节数、SHA-256、格式、骨骼、动画和缺口见 `docs/QUATERNIUS_ASSET_INVENTORY.md` 与 `art_source/manifests/quaternius_free_standard_inventory.json`。完整源表不能替代上方“正式运行时使用”登记；后续每次复制新文件仍须登记精确路径。

## 规则

- 只登记实际进入 `assets/`、`scenes/`、`resources/` 或导出包的内容。
- 原始下载与未采用候选记录在 `art_source/` 清单，不伪装为已使用资产。
- 不使用来源不明、无许可证、仅允许非商业使用或不允许再分发到游戏包中的资产。
- 对外发布前复核本表与实际文件，确保没有漏记或遗留测试资产。
