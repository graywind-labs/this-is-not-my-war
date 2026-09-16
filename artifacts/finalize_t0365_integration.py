from pathlib import Path

record='2026-09-05：用户认可高岩壁样片并授权接入，T0365 / T0365-I 均 Done。`FormalGroundSurfaceArtView → StylizedMountainArt` 按 approved_mountain 默认启用，正式与样片共用同一套网格、岩层材质、岩台及接地构造。正式三层最高 35.7 / 64.7 / 105.4m，七组 / 21 块岩台，3,036 个山地表现实例只调整接地 Y；全图 7,393 棵树的 XZ / 尺度 / 朝向与原版一致。旧 60 个山体 / 岩块 Mesh 与顶点 hash 保留用于对照，正式显示已认可高岩壁，原岩山碰撞高度与导航源不改。实际生产导航最东 X=59.5、山体最西 X=120，二者相距 60.5m；生产导航回归保留 239 个静态碰撞源（含 4 段岩山 / 12 段密林）、11 个建筑门连接。GPU 全树位回归、P4 森林、P7R4 室内光与正式 Main 六镜头昼夜十二图通过，共享构造后样片十六图和 A/B 隔离 / 接地断言通过。RTX 4060 Ti、1280×720、关闭垂直同步、同一静态 Main 镜头各 120 帧：全站旧 / 新平均 13.997 / 13.488ms，山体 5.714 / 4.030ms，全图 16.993 / 17.038ms（P95 18.200 / 18.018ms）；未重跑战斗压力，不能据此推断实战帧率。人物、正式场景结构、建筑 / 工位与玩法源未改；无需 GM，未调用 LLM。正式图 / 快照 / 性能数据：`artifacts/visual_qa/t0365_integration/`，共享样片：`artifacts/visual_qa/t0365/shared_revision/`。版本 0.0.660-t0365-mountain-integration。'

def edit(name, fn):
    p=Path(name); p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8',newline='\n')

def current(s):
    a=s.index('2026-09-05：按用户“山再高一点')
    b=s.index('2026-09-05：T0364 / T0364-I',a)
    return (s[:a]+record+'\n\n运行正式游戏即可看到东侧高岩壁；MountainArtTrial 的原版 A / 已认可 B 独立入口仍可用。\n\n'+s[b:]).replace('版本：`0.0.659-t0364-forest-integration`','版本：`0.0.660-t0365-mountain-integration`',1)
edit('docs/CURRENT_STATE.md',current)
def tasks(s):
    a=s.index('### T0365-I 已认可高岩壁正式接入')
    b=s.index('### T0366',a)
    section=s[a:b].replace('状态：In Progress','状态：Done',1)
    return s[:a]+section+record+'\n\n'+s[b:]
edit('docs/TASKS.md',tasks)
edit('docs/MODULE_INDEX.md',lambda s:s.replace('## T0365 山地表面样片','## T0365 山地样片与正式接入',1).replace('| `shaders/environment/mountain_art_trial.gdshader`','| `scripts/presentation/environment/StylizedMountainArt.gd` | 正式 / 样片共用高岩壁、材质、岩台与山地实例接地；get_debug_snapshot 为轻量快照，verify_geometry_contract 单独做几何断言 |\n| `tools/verify_t0365_formal_mountain.gd` | 实际 Main 集成、山脚 / 导航间距、十二张昼夜图及 --measure-mountain 静态渲染 A/B |\n| `artifacts/visual_qa/t0365_integration/` | 本机忽略的正式截图、快照与性能数据 |\n| `shaders/environment/mountain_art_trial.gdshader`',1).replace('不修改正式山体或森林。','样片在环境配置副本中关闭 approved_mountain，以独立共享构造保留原版 A；正式环境使用 approved_mountain 接入。',1))
def arch(s):
    a=s.index('## T0365 高岩壁样片边界'); b=s.index('## T0364 ',a)
    block='## T0365-I 高岩壁正式接入\n\n`FormalGroundSurfaceArtView → StylizedMountainArt` 在原地表 / 林木 / 散布生成完成后按 approved_mountain 构造高岩壁，不把预览 UI 或场景接入 Main。原三个山层仅用于构建与对照，正式隐藏旧山体、显示已认可网格；样片关闭正式开关，再独立使用同一个构造器做 A/B。源 Mesh、顶点、碰撞 / 导航数据不改。近 / 中 / 远峰高 35.7 / 64.7 / 105.4m，山脚仍为 X=120。\n\n所有高度取样与网格构建使用环境局部坐标，Shader 通过 environment_origin 去掉正式场景平移，避免样片 / 正式纹理错位。山地 MultiMesh 仅记录并切换 Y，原 XZ / Basis 不变；旧岩块 Mesh 复用并重新接地，七组装饰岩台底边埋入岩面。get_debug_snapshot 提供轻量计数，重型资源 / GPU 断言由 verify_geometry_contract 显式执行。headless Dummy 不读回 MultiMesh Transform，接地实测由 D3D12 覆盖。\n\n实际 Main 导航最东 X=59.5，已认可山脚 X=120，未占用可行走区域；原 4 段岩山 collider 与导航源保留，并非按视觉高岩壁重烘物理山体。十二图、生产导航 / 森林 / 室内灯、7,393 棵树的原 XZ / Basis 及新山面 Y 通过。静态渲染 A/B 不等同于战斗压力验收。美术直接可见，无需 GM。\n\n'
    return s[:a]+block+s[b:]
edit('docs/GODOT_ARCHITECTURE.md',arch)
edit('docs/ART_DIRECTION.md',lambda s:s.replace('## T0365 高岩壁修订待评价','## T0365 已认可高岩壁基线',1).replace('此高岩壁样片尚未认可或接入正式基线。','高岩壁版已获认可，并通过 T0365-I 接入正式 Main；预览与正式共用 StylizedMountainArt。',1))
edit('docs/DEV_LOG.md',lambda s:s.replace('# DEV_LOG.md\n','# DEV_LOG.md\n\n## 2026-09-05 — T0365-I 已认可高岩壁正式接入\n\n'+record+'\n\n- CURRENT_STATE / TASKS / MODULE_INDEX / ART_DIRECTION / GODOT_ARCHITECTURE 已同步，GM_PANEL 无需改动。更新森林回归：XZ 和 Basis 仍逐棵比对原版，山地 Y 对照已认可岩面，不再把已授权的高度调整误判为布树变化。\n',1))
edit('project.godot',lambda s:s.replace('0.0.659-t0364-forest-integration','0.0.660-t0365-mountain-integration',1))
