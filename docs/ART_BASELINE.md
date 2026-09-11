# Quaternius 导入与统一风格基线

> T0125 于 2026-08-11 在 Godot 4.6.2 / Forward Plus 下完成。本文件记录已实测的比例、导入、材质、保留资产和性能边界；权威数值仍由既有玩法系统决定。

## 1. 统一单位与朝向

- `1 Godot unit = 1 meter`，所有代表资产使用 `scale = 1.0`，不允许在每个包装场景用随意缩放掩盖比例问题。
- 世界坐标为 `+Y` 向上，人形正面为 `-Z`；模型脚底 / 建筑地面以局部 `Y = 0` 为落地基准。
- 普通 NPC 参考身高为 `1.82 m`，可接受基础体范围为 `1.72–1.92 m`。
- 建筑模块网格为 `2.0 m`，标准层高为 `3.125 m`，当前墙体厚度为 `0.406 m`。
- 圆顶门参考门扇宽 `1.12 m`、高 `2.318 m`；真实导航净宽不得低于 `0.90 m`，最终门内外 Marker 和避障宽度由 T0127 实景验收。
- 统一机器配置位于 `data/presentation/art_scale_baseline.json`。

## 2. Godot 实测尺寸

| 样本 | Godot 运行时 AABB | 结论 |
|---|---|---|
| `wall_plaster_door_round.glb` | `2.000 × 3.123 × 0.406 m` | 保留；直接确认 2 m 模块与层高基线 |
| `anvil.glb` | `1.082 × 0.556 × 0.402 m` | 保留；适合作为铁匠铺功能道具 |
| `base_male.glb` | `1.859 × 1.820 × 0.291 m` | 保留；横向尺寸含 T Pose 手臂，身高符合 1.82 m 基线 |
| `male_peasant_outfit.glb` | `1.799 × 1.563 × 0.352 m` | 保留为模块服装样本；不含完整头脚，T0128 必须装配到共享基础体 |
| `ual2_standard.glb` mannequin | `1.944 × 1.829 × 0.370 m` | 保留动画与重定向来源，不把黄色 mannequin 当正式 NPC |
| `common_tree_a.glb` | `4.311 × 7.265 × 4.578 m` | 保留；作为大型环境轮廓，不进入 NPC 导航通道 |

## 3. 导入与材质合同

- 正式运行时只保留筛选后的 GLB 与外置 PNG。`tools/pack_gltf_to_glb.py --external-images` 把网格 / 骨骼写入 GLB，并给外置贴图生成稳定文件名，避免 Godot 再抽取一份内嵌贴图。
- 六个 GLB 共 `10,066,124` 字节；28 张保留的原始 PNG 共 `92,785,707` 字节。两者都由 Git LFS 管理；完整源包、FBX、OBJ 和未选 glTF 继续留在 `art_source/` 隔离区。
- PNG 的 Godot 导入上限统一为 `2048`，生成 mipmap并使用 VRAM 压缩；隔离源文件仍保留原始分辨率，后续可以无损重做导入策略。
- 运行时包装把所有导入的 `BaseMaterial3D` 复制为 surface override，并统一使用 `LINEAR_WITH_MIPMAPS_ANISOTROPIC` 与逐像素着色；所有样本开启阴影。
- `environment_matte.tres` 是哑光环境基材；`character_rim.tres` 是角色边缘光 overlay；`selection_outline.tres` 是选中轮廓 overlay；`art_sandbox_grid.tres` 使用 2 m 网格辅助比例检查。
- 调色板固定为泥灰绿地面、暖灰泥墙、深褐木料、暗红褐屋顶、冷灰金属、暖金选中和浅蓝角色边缘光，精确值见表现配置。
- 第三方导入场景视为只读源。碰撞、导航、入口、屋顶、升级部件、挂点和表现脚本必须放在项目维护的包装 / 继承场景；不得修改导入缓存或让美术节点结算权威事实。

## 4. 保留、延后与淘汰

### 保留到后续任务

- Medieval Village：圆门灰泥墙模块，以及 T0126 新增的直墙、圆瓦 4 × 4 屋顶和深色木地板；共同组成首个建筑包装比例基线。
- Fantasy Props：铁砧，用于 T0129 铁匠铺垂直切片。
- Universal Base Characters：男性基础体与短发已在 T0128 组合为格伦共享人形基线。
- Modular Outfits - Fantasy：男性农民服装已在 T0128 重绑到共享动画骨架并用于格伦。
- Universal Animation Library 2：非 root-motion Standard 库的 43 个片段已驱动格伦九状态 AnimationTree；临时状态别名见第 7 节。
- Stylized Nature：CommonTree_1，用于环境尺寸、叶片和阴影基线。

### 延后、未进入运行时

- 工作台、岩石等额外源模型：不是 T0125 / T0126 验收所必需；当前工作台由项目低模 primitive 占位，后续在对应建筑 / 环境任务中按需筛选。
- 农民 / 游侠其他拆分件：格伦合同已确认，仍等 T0130 按其他 7 人的实际外观组合逐件导入，避免保存未使用资产。
- UAL2 root-motion 版本：项目移动仍由程序路径权威驱动；T0128 正式采用非 root-motion，不引入 RM。

### 淘汰原则

- 同模型的 FBX / OBJ / glTF 重复格式不进入运行时。
- 黄色 UAL2 mannequin 只用于动画诊断，不作为正式 NPC 美术。
- Superhero 基础体贴图只能作为服装下的身体、面部和身高基线，不得脱离中世纪服装 / 发型单独代表成品角色。
- 不引入其他作者的核心建筑 / 人形资产；若未来确有缺口，必须先做比例、材质和轮廓适配，再决定是否保留。

## 5. 验证证据与已知告警

- `tools/verify_t0125_art_sandbox.gd` 通过：12 个 MeshInstance3D、3 个 Skeleton3D、1 个 AnimationPlayer，`Farm_Harvest` 自动播放。
- Godot MCP 实景确认六个样本的材质、方向、阴影、边缘光、选中轮廓和 2 m 网格可见；编辑器没有导入、纹理或骨骼错误。
- 本机 120 帧采样：约 `180 FPS`、平均 `5.50 ms`、P95 `6.91 ms`、P99 `7.19 ms`、0 spike、95 draw calls、67,969 primitives；2K 上限后纹理内存约 `149.7 MB`，仍需在 T0129 垂直切片和 T0136 第五波压力场景继续压缩 / 合批。
- Mesh 完整性检查报告三类源数据告警：树叶双面卡片存在混合 winding；UAL2 黄色 mannequin 的无贴图表面和铁砧一个表面含退化 UV。当前截图、灯光旋转和动画播放未出现缺面或黑面；树叶材质本身关闭背面剔除。它们被“带告警保留”，若 T0128 / T0129 近景出现切线或法线异常，应从源 glTF 修 UV / winding，不用调灯光掩盖。
- `ArtSandbox.tscn` 可独立运行，支持滚轮缩放和中键旋转，不修改 `Main.tscn`；因此本任务不需要 GM 面板入口。

## 6. T0126 追加验证

- 运行时新增 Medieval Village 的直墙、圆瓦屋顶、深色木地板 3 GLB 与 3 张圆瓦独有 PNG；共享灰泥 / 木料纹理按字节一致复用，没有重复拷贝。
- 两座 `BuildingArtView` 共享一个控制器，近 / 远 / 近回放的 alpha 为 `0.06 / 0.12 → 1.0 / 1.0 → 0.06 / 0.12`；静态碰撞、点击区和室内触发 shape 全程不变。
- 两座包装场景性能采样约 `180 FPS`、平均 `5.57 ms`、P95 `10.73 ms`、P99 `11.59 ms`、173 draw calls、80,676 primitives；13 个大于双倍中位数的帧仍未超过 16.7 ms 的 60 FPS 预算。
- 圆瓦屋顶一个表面约 6% 三角形存在退化 UV；当前透明、阴影和多角度实景未见黑面 / 缺面，按源数据告警保留。若后续正式铁匠铺近景出现切线异常，修源 glTF / UV，不用灯光掩盖。

## 7. T0128 角色装配追加验证

- 新增 `hair_buzzed.glb`，复用 T0125 已登记的两张 Hair 贴图；基础体 3 Mesh、服装 4 Mesh、头发 1 Mesh 共 8 个可见 skinned mesh 重绑到 UAL2 65 骨骼，黄色 mannequin 保持隐藏。
- 状态合同覆盖 `idle / walk / run / talk / work / attack / hit_react / unconscious / get_up`，挂点覆盖双手、背部、头、身体和坐骑。免费库缺口明确以加速 `Walk_Carry`、`Farm_Harvest`、反向 `LayToIdle` 适配，不将状态名误当成新源动画。
- `NPC.tscn` 原 1.6 m 胶囊继续负责格伦点击体；角色包装另留禁用 SelectionArea、VFX Marker 和 PhysicalBoneSimulator 接口。T0128 没有生成真实 ragdoll physical bones。
- 自动化和 MCP 实景确认格伦沿程序路径移动 / 转向，在 `forge_01` active 后拿锤工作，权威昏迷 / 复苏分别触发倒地和起身。可见角色网格没有新增 Mesh 检查告警；隐藏 mannequin 的退化 UV 是既有源数据告警。
