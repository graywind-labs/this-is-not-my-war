from pathlib import Path

record = '2026-09-05：T0365 独立山地样片已实现，状态 Partial（修订后待用户评价），尚未正式接入。原山体与岩块共 60 个网格 / Transform 保持原样，三个山层共 3,600 个原顶点未动；仅预览材质覆盖和七组 / 21 个装饰岩体。首轮浅色缓坡被用户指出像灰土坡，已改为灰岩色板、折线岩层、竖向岩壁与三级岩台；主岩体突出原坡面约 4.5–7.5m，改变的是装饰轮廓，原地形高度与通行边界不变。岩台底边 147 个顶点按真实原三角面重心插值埋入 0.12m，山脚共用已认可草土色板并渐退。A/B 共用正式地表、全部 7,393 棵已认可树及昼夜光照。headless 加载、D3D12 四镜头昼夜十六图与 MCP 运行检查通过；原网格顶点 hash / Transform 一致，无碰撞、导航、Main 或 LLM。截图和快照：`artifacts/visual_qa/t0365/`。人物、建筑、工位、正式环境配置与生成器源未改，版本保持 0.0.659；直接在独立样片观察，无需 GM。本轮不是正式场景整合、导航回归或战斗性能验收。'

def edit(path, fn):
    p=Path(path)
    p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8',newline='\n')

edit('docs/TASKS.md',lambda s:s.replace('状态：In Progress（2026-09-05 用户授权执行下一项）','状态：Partial（岩壁 / 岩台修订已展示，待用户视觉评价）',1).replace('### T0366 河流与河岸表现试验',record+'\n\n### T0366 河流与河岸表现试验',1))
edit('docs/CURRENT_STATE.md',lambda s:s.replace('## 当前版本\n','## 当前版本\n\n'+record+'\n\n预览：打开 `scenes/art/MountainArtTrial.tscn` 按 F6，使用原版 A / 试案 B、整体 / 近看 / 侧看 / 远看与昼夜按钮。当前评审增加岩体的体积感，不抬升原整座山体。\n',1))
edit('docs/MODULE_INDEX.md',lambda s:s.replace('# MODULE_INDEX.md\n','# MODULE_INDEX.md\n\n## T0365 山地表面样片\n\n| 文件 | 职责 |\n|---|---|\n| `scenes/art/MountainArtTrial.tscn` | 独立 F6 山地 A/B 入口，正式场景未引用 |\n| `scripts/presentation/MountainArtTrial.gd` | 正式环境只读预览、材质切换、真实三角面取样的装饰岩台、四镜头昼夜、隔离 / 原网格 hash 断言 |\n| `shaders/environment/mountain_art_trial.gdshader` | 无位移程序岩层、灰岩色阶与山脚草土过渡，无外部纹理 |\n| `data/presentation/mountain_art_trial.json` | 岩色、层距 / 强度、装饰岩组中心 / 高宽范围和镜头 |\n| `artifacts/visual_qa/t0365/` | 本机忽略的十六张 A/B 图与 snapshot.json |\n\n复现：`godot --path . --scene res://scenes/art/MountainArtTrial.tscn -- --capture-mountain-trial`。只读环境表现，不实例化 Main / LLM；不修改正式山体或森林。\n',1))
edit('docs/GODOT_ARCHITECTURE.md',lambda s:s.replace('# GODOT_ARCHITECTURE.md\n','# GODOT_ARCHITECTURE.md\n\n## T0365 山地样片边界\n\n`MountainArtTrial → FormalGroundSurfaceArtView 只读预览实例`，共用已认可地表 / 全图树林 / 昼夜表现。A 保持原山体材质，B 仅切换预览 mountain 节点材质覆盖并显示 CandidateOutcrops；Main 与正式配置无新引用。Shader 无顶点位移、无贴图，山脚色板只读 ground_art_trial.json。装饰岩体底边取样已有山体真正三角面，未用粗略 profile 猜高度；为回应“太矮、像灰土坡”，装饰改为七组竖向主岩壁与两级岩台，原可行走高度不变。60 个原 Mesh / Transform / 顶点 hash 验证不变；新节点只有 MeshInstance3D，无碰撞、导航或模拟权威。该独立视觉入口不需要 GM，正式接入和性能另行验收。\n',1))
edit('docs/ART_DIRECTION.md',lambda s:s.replace('## T0361 主菜单外围林缘','## T0365 山地修订待评价\n\n用户否决只有灰色缓坡的首轮方向：需要有高度、断面和石头的体积感。当前样片以折线状岩层 / 灰岩色阶保持低模语汇，七组竖向岩壁搭配逐级降低的岩台；山脚草土色板接续已认可平地。原山体顶点和林木不动，提升局部装饰岩体轮廓；这仍是未认可的新样片，不是正式美术基线。不用写实岩石贴图或密集碎石覆盖问题。\n\n## T0361 主菜单外围林缘',1))
edit('docs/DEV_LOG.md',lambda s:s.replace('# DEV_LOG.md\n','# DEV_LOG.md\n\n## 2026-09-05 — T0365 山地岩壁样片与用户反馈修订\n\n'+record+'\n\n- 已同步 CURRENT_STATE / TASKS / MODULE_INDEX / ART_DIRECTION / GODOT_ARCHITECTURE；GM_PANEL 无需改动。首轮浅灰 / 圆斑效果已被当前折线岩层与立体岩台替代；截图目录仅保存当前修订。\n',1))
