# Quaternius 免费 Standard 资产清单

> 盘点日期：2026-08-11。来源限定为 Quaternius 官方页面链接到的 itch.io 免费 Standard 上传；未购买或下载 Pro / Source 档位。本清单描述本机隔离源文件，不表示资产已经进入 Godot 运行时。

## 1. 获取与版本口径

Quaternius 这些包没有提供语义版本号，因此使用“官方发布日期月份 + Standard 档位 + 获取日期”标识版本。原始压缩包保存在 `art_source/downloads/quaternius/`，解包内容保存在 `art_source/quaternius/<pack_id>/standard/`；两处均受根 `.gitignore` 与 `art_source/.gdignore` 隔离。可复核机器清单位于 `art_source/manifests/quaternius_free_standard_inventory.json`。

| 资产包 | 官方发布日期 | 原始 ZIP 字节 | SHA-256 |
|---|---:|---:|---|
| Medieval Village MegaKit Standard | 2025-01 | 161,003,471 | `E60DEA67C10F30DCCCCFBFF92A7933F5EA5CFE99BE0E2A0FA5118CCEABEEC5C4` |
| Fantasy Props MegaKit Standard | 2025-06 | 150,213,360 | `8B6F7E806D222E585478F0E1BDC6B271BBC7BC6F84DD6AF8CA703A7C64F0CB1E` |
| Universal Base Characters Standard | 2025-08 | 128,968,391 | `FDBF1804C90DFC1EA03E992BFF7DA2DFD1A79318E13270A660180F9308455F40` |
| Modular Character Outfits - Fantasy Standard | 2025-11 | 294,347,394 | `C3468B18871CC8C8F05AB14DF7712BAF22CB9F389CBD870BABF130E595187F70` |
| Universal Animation Library 2 Standard | 2026-01 | 18,735,003 | `4008EA208A604773A2B2177D965F0F5D3195498B5BF838C3F5785D68E95F2A68` |
| Stylized Nature MegaKit Standard | 2024-07 | 104,088,529 | `298F6732B872E4CF7B30E6E7ABF9641C7F6DC6B326DF37AC089533ED7E3D58C9` |

## 2. 实际内容盘点

| 资产包 | 免费包实际内容 | 骨骼 / 动画 | 碰撞 / Godot 工程 | 本项目候选用途 |
|---|---|---|---|---|
| Medieval Village | 176 份 glTF、176 FBX、176 OBJ，54 PNG；模块为墙、门窗、地板、楼梯、屋顶和少量外部道具 | 无骨骼、无动画 | 未发现命名碰撞资源或 `project.godot` | 组装建筑外壳、真实地板 / 门洞、独立 `Roof` 层 |
| Fantasy Props | 94 份 glTF / FBX / OBJ，43 PNG；含床、桌椅、书架、砧、工作台、食物、容器、武器等 | 木箱包含 1 套 3 关节皮肤和 4 个开合片段 | 未发现命名碰撞资源或 Godot 工程 | 室内陈设、职业工位、装备与可读功能道具 |
| Universal Base Characters | 18 份 glTF、26 FBX、48 PNG；含男女全身基础体、眉毛、发型和胡须 | glTF 共 10 套皮肤，统一 65 关节；不含动画 | 未发现碰撞或 Godot 工程 | 8 名 NPC 的共享人形、头部和发型基础 |
| Modular Outfits - Fantasy | 24 份 glTF、24 FBX、46 PNG；免费内容集中在男女农民 / 游侠成套服装及拆分件 | 24 套 65 关节皮肤；带 1 个 `Jog_Fwd_Loop` 示例 | 未发现碰撞或 Godot 工程 | 农民 / 游侠基础服装，重配色并加职业附件形成 NPC 原型 |
| Animation Library 2 | 3 GLB、3 FBX、1 Blend；包含有 / 无 root motion 两套男性库及女性 mannequin | 65 关节；43 个唯一动画，RM / 非 RM 两套共 86 轨 | 未发现碰撞或 Godot 工程；包内有 Godot 导入设置图 | 待机、搬运、农活、砍树、近战、盾击、受击等初始动画 |
| Stylized Nature | 68 份 glTF、68 OBJ、136 FBX（含 Unity 变体），40 PNG；许可证明确为完整 116 模型中的 68 个 | 无骨骼、无动画 | 未发现碰撞或 Godot 工程 | 树木、灌木、草花、蘑菇、石块和道路边缘装饰 |

T0125 已在 Godot 实测确认：`1 unit = 1 m`、`+Y / -Z`、男性基础体 1.82 m、墙模块 2.0 × 3.123 × 0.406 m、圆门参考 1.12 × 2.318 m；完整 AABB 与 Pivot / 包装规则见 `docs/ART_BASELINE.md`。仍不允许靠每个场景独立缩放掩盖差异。

## 3. 动画可用范围

免费动画库实际有 43 个唯一片段，包含 `Farm_Harvest`、`Farm_PlantSeed`、`Farm_Watering`、`TreeChopping_Loop`、`Walk_Carry_Loop`、多组剑击 / 盾击、`Hit_Knockback`、投掷、进食和若干待机。它没有覆盖本项目最低动作合同中的普通完整 locomotion、铁匠锻打、烹饪、治疗、祈祷、工程施工、弓弩射击、倒地昏迷与复苏全套动作；T0128 必须通过动画重定向、片段改造或补充来源解决，不能把宣传页的“130+”当作免费包实际内容。

## 4. 免费版缺口与购买边界

- 六个 Standard 包都没有提供可直接采用的建筑 / 家具 / 自然物碰撞，也没有附带 Godot 工程；T0125–T0129 需要在 Godot 包装场景中生成或手工配置碰撞、导航和点击区。
- Medieval Village 是模块库，不是已经布置好室内、入口和屋顶透明分组的完整驿站建筑；仍需项目自行组装建筑并建立 `Exterior / Roof / Interior` 合同。
- 免费服装只有农民和游侠主线，无法直接区分铁匠、厨子、医生、神父、工程师、马夫、园丁和老兵副官；优先用配色、发型、围裙 / 兜帽和职业道具验证垂直切片，再判断是否值得购买 Source 的完整服装与拆分件。
- 免费动画库的 43 个唯一片段不足以覆盖全部职业动作和昏迷 / 布娃娃过渡；布娃娃本身仍须在 Godot 建立 PhysicalBone 配置。
- 目前免费内容足以执行 T0125 风格 / 比例基线，并能开始 T0129 铁匠铺垂直切片；在切片证明“缺碰撞工程 / 完整服装 / 源 Blender 文件”造成显著返工前，不购买 Pro / Source。

## 5. 许可与运行时状态

六包内置许可证均声明 `CC0 1.0 Universal`。公共法律文本保存在 `art_source/licenses/CC0-1.0-legalcode.txt`，逐包来源与包内许可证位置记录在 `art_source/licenses/QUATERNIUS_CC0_SOURCE_RECORD.md`，官方页面快照保留在本机 `art_source/licenses/source_pages/`。

当前 `runtime_imported=true`，运行时筛选范围截至 T0129C-A3b12R 为 54 个 GLB / 75 张外置 PNG。A3b12R 新增 3 个 Medieval Village 仓库模块（木网格墙、木屋顶、货运车）和 5 个 Fantasy Props 储藏道具（拱形货架、麻袋、金属箱、苹果桶、木钱箱）；全部按字节复用既有 `wall_plaster_door_round / chapel` 共享纹理，因此没有新增 PNG。候选 `Workbench_Drawers` 因 Godot 网格检查发现约 7% 退化 UV 未进入运行时，隔离在 `art_source/runtime_rejected/a3b10r_workshop_drawers/`。本轮网格检查没有仓库新增问题；既有主厅圆瓦屋顶、塔顶、复用盾牌、铁砧和 mannequin 退化 UV 告警继续登记为第三方技术债。
