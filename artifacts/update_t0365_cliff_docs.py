from pathlib import Path

record = '2026-09-05：按用户“山再高一点、更有悬崖峭壁感觉”的最新要求，T0365 样片改为真正抬高候选视觉山体，状态 Partial（待评价），尚未正式接入。三个原山层生成独立候选 Mesh 副本，保持山脚和 XZ 足迹，抬升山脊并把主要爬升集中为陡直岩壁；近 / 中 / 远层最高 35.7 / 64.7 / 105.4m。旧版原网格 / Transform / 顶点 hash 仍保留，A 显示完整原山体，B 显示高岩壁副本及七组岩台；不再要求候选视觉顶点保持原高度。3,036 个山地树木 / 散布实例在 B 中按真实候选三角面调整接地 Y，A 恢复原 Transform；7,393 棵树的总数、XZ、尺度 / 朝向不变。旧岩块复用并在候选坡面重新接地，新增岩台底边仍埋入 0.12m。headless 加载、D3D12 四镜头昼夜十六图、原资源 hash、候选高度、实际 GPU A/B Transform、隔离断言通过。MCP 已打开修订样片；无新增碰撞 / 导航 / Main 或 LLM。正式地形、碰撞、通行、人物、建筑和工位均未改，版本不变。图与快照：`artifacts/visual_qa/t0365/`。正式整合与高岩壁遮挡 / 碰撞一致性尚未验收。'

def edit(path, fn):
    p=Path(path)
    p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8',newline='\n')

def current(s):
    a=s.index('2026-09-05：T0365 独立山地样片')
    b=s.index('2026-09-05：T0364 / T0364-I', a)
    return s[:a]+record+'\n\n预览：`scenes/art/MountainArtTrial.tscn` 按 F6，支持 A/B、整体 / 近看 / 侧看 / 远看、昼夜比较。\n\n'+s[b:]
edit('docs/CURRENT_STATE.md',current)
edit('docs/TASKS.md',lambda s:s.replace('状态：In Progress（用户要求继续抬高山体、强化悬崖峭壁）','状态：Partial（高岩壁版已完成，待用户评价）',1).replace('### T0366 河流与河岸表现试验',record+'\n\n### T0366 河流与河岸表现试验',1))
edit('docs/MODULE_INDEX.md',lambda s:s.replace('正式环境只读预览、材质切换、真实三角面取样的装饰岩台、四镜头昼夜、隔离 / 原网格 hash 断言','原山体 / 抬高候选副本切换、真实三角面接地与实例 Y 恢复、装饰岩台、四镜头昼夜、隔离 / 原网格 hash 断言',1).replace('岩色、层距 / 强度、装饰岩组中心 / 高宽范围和镜头','岩色、层距 / 强度、三层山高倍率、装饰岩组中心 / 高宽范围和镜头',1))
def arch(s):
    a=s.index('## T0365 山地样片边界')
    b=s.index('## T0364 ',a)
    block='## T0365 高岩壁样片边界\n\n`MountainArtTrial → FormalGroundSurfaceArtView 只读预览实例 + CandidateCliffMountain`。用户最新要求允许抬高候选视觉山体：从原三层顶点构造独立 ArrayMesh，通过按横向坡段改变高度倍率形成陡壁 / 高台，保持山脚与 XZ 足迹。原 60 个资源 / Transform / 顶点 hash 不改，A 显示原山体，B 显示候选副本；山上 MultiMesh 实例仅修改候选 Y 并可恢复原 Transform。旧岩石网格复用、重新贴坡，装饰岩台继续使用候选真实三角面取样，不引入任何物理或玩法权威。\n\nShader 仍仅负责色板 / 断续岩层 / 山脚草土过渡；高度变化在候选 Mesh 构建阶段发生，无每帧地形重建。近 / 中 / 远峰高 35.7 / 64.7 / 105.4m，D3D12 验证实际实例切换、总树数与 XZ / Basis 不变。Main 和正式配置不引用样片；正式接入前仍需检查视觉高度与原自然碰撞 / 遮挡的一致性。本次不属于正式导航或战斗验收，无需 GM。\n\n'
    return s[:a]+block+s[b:]
edit('docs/GODOT_ARCHITECTURE.md',arch)
def art(s):
    a=s.index('## T0365 山地修订待评价')
    b=s.index('## T0361',a)
    return s[:a]+'## T0365 高岩壁修订待评价\n\n用户要求从灰土坡进一步提升为更高的悬崖峭壁，当前允许候选山体抬高：三层错落山脊与陡直主岩壁，近层约 36m、中层约 65m、远层约 105m，保留低模切面与克制断续岩层。山脚沿用原位置并衔接已认可草土色板，七组岩台作局部体积补充。候选树林只调整接地高度，原 XZ / 数量 / 尺度保留。旧“视觉山体顶点完全不变”仅为前轮历史，正式地形和碰撞源仍不改；此高岩壁样片尚未认可或接入正式基线。\n\n'+s[b:]
edit('docs/ART_DIRECTION.md',art)
edit('docs/DEV_LOG.md',lambda s:s.replace('# DEV_LOG.md\n','# DEV_LOG.md\n\n## 2026-09-05 — T0365 抬高视觉山体、形成陡壁\n\n'+record+'\n\n- CURRENT_STATE / TASKS / MODULE_INDEX / ART_DIRECTION / GODOT_ARCHITECTURE 已回写，明确最新用户要求放宽候选视觉高度限制；GM_PANEL 无需更新。\n',1))
