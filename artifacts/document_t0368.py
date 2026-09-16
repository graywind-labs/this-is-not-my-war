from pathlib import Path
record='2026-09-06：T0368 建筑与围墙地表接合已完成并接入正式 Main。新增 BuildingGroundContactArt，在既有建筑生成完成后读取 12 座主要建筑、2 座附属小屋和 14 段围墙的真实基座 Mesh AABB / Transform，而非规划地块；将其边缘投影到原地面材质，形成贴脚暗土、压实土渐变与克制细粒积尘。12 处建筑入口按 building_spatial.entry_route 接续原道路；正 / 后门仅在门柱附近补充接地色，不跨门洞画硬边。站内原地面与站外原平台共用一张 1024×1024 RGBA8 静态遮罩，逐像素地表噪声打散土边；无需覆盖平面、外部贴图、额外模型或逐帧 CPU 更新。修订中撤掉了第一版过亮的浅色描边，最终土色沿用已认可道路色板并略压暗。新增网格 / 碰撞 / 导航为零，人物、建筑 / 围墙 / 门结构、基座资源与位置、地板、工位、道路和玩法源不改。headless / D3D12 几何保留与旋转基座遮罩对齐断言、主厅 / 铁匠铺 / 围墙内外 / 正门 / 菜园 / 全站七镜头昼夜 A/B 共 28 图通过；生产导航保留 239 个静态源和 11 个门连接，室内灯回归通过。RTX 4060 Ti、720p、关闭垂直同步、同一静态全站各 120 帧，A / B 平均 13.740 / 12.882ms，draw calls 均为 6,945；该测量不代表确定的性能增益，战斗压力未重测。图 / 快照 / 测量：`artifacts/visual_qa/t0368/earth_revision/`。直接在 Main 看建筑脚部和围墙两侧，无需 GM、未调用 LLM；版本 `0.0.663-t0368-building-ground-contact`。'
p=Path('docs/CURRENT_STATE.md');s=p.read_text(encoding='utf-8').replace('## 当前版本\n\n','## 当前版本\n\n'+record+'\n\n',1).replace('版本：`0.0.662-t0366-natural-river`','版本：`0.0.663-t0368-building-ground-contact`');p.write_text(s,encoding='utf-8')
p=Path('docs/TASKS.md');s=p.read_text(encoding='utf-8');a=s.index('### T0368');b=s.index('### T0367',a);s=s[:a]+s[a:b].replace('状态：In Progress','状态：Done')+record+'\n\n'+s[b:];p.write_text(s,encoding='utf-8')
p=Path('docs/DEV_LOG.md');s=p.read_text(encoding='utf-8').replace('# DEV_LOG.md\n\n','# DEV_LOG.md\n\n## 2026-09-06 — T0368 建筑 / 围墙与地表接合\n\n'+record+'\n\n- CURRENT_STATE、TASKS、MODULE_INDEX、ART_DIRECTION、GODOT_ARCHITECTURE 已回写；GM_PANEL 无需更新。\n\n',1);p.write_text(s,encoding='utf-8')
p=Path('docs/MODULE_INDEX.md');s=p.read_text(encoding='utf-8').replace('# MODULE_INDEX.md\n\n','''# MODULE_INDEX.md

## T0368 建筑与围墙地表接合

| 文件 | 职责 |
|---|---|
| `scripts/presentation/environment/BuildingGroundContactArt.gd` | 只读实际建筑 / 围墙基座，烘焙地表压实土 / 接触暗部 / 入口磨损遮罩，保留与对齐断言 |
| `data/presentation/building_ground_contact.json` | 启用开关、遮罩范围 / 分辨率、土边宽度、实际基座节点识别名 |
| `scripts/presentation/environment/FormalGroundSurfaceArtView.gd` | 地面材质准备后延迟安装接地遮罩，等待实际建筑生成；排除已被重建替代的材质 |
| `shaders/environment/ground_art_trial.gdshader` | 原地表按遮罩混合压实土与贴脚暗部，外围噪声过渡；默认关闭用于旧样片 |
| `tools/verify_t0368_building_ground_contact.gd` | 实际 Main 静态验证、七镜头昼夜 A/B 二十八图，--measure-contact 可选静态渲染测量 |

复现：`godot --path . --script res://tools/verify_t0368_building_ground_contact.gd -- --measure-contact`；结果在 `artifacts/visual_qa/t0368/earth_revision/`。无 LLM、无新增 GM。

''',1);p.write_text(s,encoding='utf-8')
p=Path('docs/GODOT_ARCHITECTURE.md');s=p.read_text(encoding='utf-8').replace('# GODOT_ARCHITECTURE.md\n\n','''# GODOT_ARCHITECTURE.md

## T0368 地表与建筑接合

FormalGroundSurfaceArtView 安装已认可地面材质后 deferred 创建 BuildingGroundContactArt；此时 StationLayoutController 已生成 BuildingRoots 与 WallsAndGates。用当前地面 material_override 身份排除被后续重建替代的延迟请求。独立旧美术预览若没有实际 BuildingRoots 则跳过，不把规划 lot 当作接地尺寸。

BuildingGroundContactArt 只读指定实际基座 Mesh 的 AABB 和 global_transform，四角转为环境局部 XZ；围墙使用 LowStoneFooting 的真实 1.38m 宽基座。12 处入口读取 building_spatial.entry_route，门柱按既有 gate 配置定位。一次性 CPU 栅格化有限站区的 1024×1024 RGBA8 ImageTexture：R 压实土范围、G 贴脚暗部、B 入口磨损。原地面 shader 单次纹理采样并用既有噪声打散边缘，站内原地面和站外原平台共用材质；不新增贴片 / 几何、不修改建筑或地板材质、不拥有权威。

verify_contract 单独检查 14 处建筑基座、14 段围墙、12 处入口、源 Mesh / Transform 保留、旋转基座各边中点的遮罩命中和范围外为零。正式工具还检查内外地面同材质；生产导航 / 室内光回归通过。set_enabled 仅为表现 A/B；直接可见，无需 GM。

''',1);p.write_text(s,encoding='utf-8')
p=Path('docs/ART_DIRECTION.md');s=p.read_text(encoding='utf-8').replace('# ART_DIRECTION.md\n\n','''# ART_DIRECTION.md

## T0368 建筑与地面衔接

用户指出建筑与围墙像直接摆在无关草地上。地面现在按真实基座形成暗土、压实痕迹与零星积尘，向外不规则渐退到草色；入口与原道路自然接续，围墙内外一致。土色沿用地表家族并略压暗，避免浅色光圈、整块矩形地垫或黑色描边。保留建筑结构、人物、地板、工位、道路与围墙 / 门的原尺寸和布局。该修订已按本次要求接入正式 Main。

''',1);p.write_text(s,encoding='utf-8')
p=Path('project.godot');s=p.read_text(encoding='utf-8').replace('config/version="0.0.662-t0366-natural-river"','config/version="0.0.663-t0368-building-ground-contact"');p.write_text(s,encoding='utf-8')
