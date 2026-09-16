from pathlib import Path

def edit(name, transform):
    p = Path(name)
    p.write_text(transform(p.read_text(encoding='utf-8')), encoding='utf-8', newline='\n')

completed = '完成记录（2026-09-05）：用户重启后 MCP 恢复，沿用已有授权完成正式接入。`FormalForestArtView → StylizedTreeMeshes` 共享已认可六种树形，`environment_art.json.approved_forest` 默认启用；保留原版分区、树位、尺寸 / 朝向随机流和近林阴影范围。实际 Main D3D12 逐实例比较 7,393 棵原树的完整 Transform 全部通过，前林 3,086 / 后林 3,355 / 侧林 952，原道路 / 出生 / 山地 / 河岸退让不变。六种实例为阔叶成 / 幼 2,419 / 903，浅皮成 / 幼 1,168 / 456，针叶成 / 幼 1,750 / 697；新增碰撞 / 导航 / 交互为零。P4 森林、T0129C-A3a 生产导航、P7R4 室内光回归通过，保留 12 段自然树林阻挡；共享构造后的局部 A/B 仍各 823 棵，十六图及隔离 / 原树位断言通过。正式站区 / 城门 / 前后林 / 河岸 / 山脚 / 全图昼夜十四图与快照在 `artifacts/visual_qa/t0364_integration/`。RTX 4060 Ti、1280×720、关闭垂直同步，同一静态 Main 镜头各 120 帧：全站旧 / 新平均 14.338 / 13.774 ms，前林 5.573 / 3.118 ms，全图 23.025 / 16.974 ms（draw calls 9,796 → 7,374）；这是静态渲染 A/B，不代表战斗压力结论。人物、正式场景结构、建筑 / 工位、权威碰撞 / 导航与玩法源未改；无需 GM，未调用 LLM。版本 `0.0.659-t0364-forest-integration`。'

def tasks(s):
    s = s.replace('状态：In Progress（用户重启后 MCP 已恢复，继续已授权的接入）', '状态：Done（2026-09-05 已接入正式 Main）', 1)
    s = s.replace('阻塞记录：`godot_project.get_info`', '已解决的阻塞记录：`godot_project.get_info`', 1)
    s = s.replace('最新修订完成（2026-09-05，待视觉评价）', '最新修订完成（2026-09-05，用户已认可）', 1)
    return s.replace('### T0365 山地与地形表面试验', completed+'\n\n### T0365 山地与地形表面试验', 1)
edit('docs/TASKS.md', tasks)

def current(s):
    start = s.index('2026-09-05：用户已认可 T0364')
    end = s.index('2026-09-05：T0362 已获用户认可', start)
    text = '2026-09-05：T0364 / T0364-I 已完成，已认可树形正式接入 Main。MCP 重启恢复后继续既有授权；共用 `StylizedTreeMeshes` 六种阔叶 / 浅皮 / 针叶幼成树，保留全图 7,393 棵原树的逐点位置、尺寸、朝向、疏密区域与近林阴影范围，未做额外加密或减树。完整 GPU Transform 比较、P4 森林、T0129C-A3a 生产导航、P7R4 室内灯回归通过，12 段自然树林阻挡不变。人物、正式场景结构、建筑 / 工位、碰撞 / 导航与玩法源未改。实际 Main 七镜头昼夜十四图与快照：`artifacts/visual_qa/t0364_integration/`。运行正式游戏即可观察，无需 GM，未调用 LLM。\n\nRTX 4060 Ti / 1280×720 / 无垂直同步，同一静态 Main 原树 / 新树各 120 帧：全站平均 14.338 / 13.774 ms，前林 5.573 / 3.118 ms，全图 23.025 / 16.974 ms，全图绘制调用 9,796 / 7,374。本轮只验证静态渲染成本，未重跑战斗压力。局部 ForestArtTrial 仍保留原版 A / 已认可 B，重跑十六图及逐点断言通过（各 823 棵），共享构造不改变已认可模型。T0363 五组稀疏植被样片已认可，尚未正式接入。\n\n'
    return (s[:start]+text+s[end:]).replace('版本：`0.0.658-t0362-ground-integration`','版本：`0.0.659-t0364-forest-integration`',1)
edit('docs/CURRENT_STATE.md', current)

def module(s):
    s = s.replace('## T0364 树木与林缘样片', '## T0364 树木样片与正式接入', 1)
    s = s.replace('| `data/presentation/forest_art_trial.json`', '| `scripts/presentation/environment/StylizedTreeMeshes.gd` | 正式 / 样片共用六种 ArrayMesh、独立树种随机流与分区 MultiMesh，不创建碰撞 / 导航 |\n| `scripts/presentation/environment/FormalForestArtView.gd` | approved_forest 启用时只替换树形，保留原布树 / 退让 / Transform / 阴影预算；快照区分旧采样计数与六种可见计数 |\n| `tools/verify_t0364_formal_forest.gd` | 实际 Main 全图原树 Transform 对照、十四张昼夜截图，--measure-forest 运行静态渲染 A/B |\n| `artifacts/visual_qa/t0364_integration/` | 本机忽略的正式昼夜截图、snapshot.json、performance.json |\n| `data/presentation/forest_art_trial.json`', 1)
    s = s.replace('不实例化 Main 或调用 LLM；正式森林生成器、地图与碰撞源不变。', '样片不实例化 Main 或调用 LLM；正式树形接入共用构造，原地图与碰撞源不变。\n\n正式验收：`godot --path . --script res://tools/verify_t0364_formal_forest.gd -- --measure-forest`，startup_mode=0；GPU Transform 读回在 D3D12 执行。', 1)
    return s
edit('docs/MODULE_INDEX.md', module)

def arch(s):
    s = s.replace('其正式源与环境配置不变。', '预览配置副本关闭 approved_forest，确保 A 保持旧树，不重复叠加正式新树。', 1)
    paragraph = '## T0364-I 正式树形接入\n\n`FormalForestArtView → StylizedTreeMeshes → forest_art_trial.json`，由 `environment_art.json.approved_forest` 启用。六种已认可网格和树种选择与预览共享；原森林分区、允许点位、数量 / 密度、原 Transform 随机数消耗完整保留，树种选择使用另一路随机流。仅把原 placement 分入六种 MultiMesh；沿用原近林分区投影、远林不投影策略，不生成任何权威节点。旧三种 tree_variant_counts 是 legacy_source_sampling，当前可见树种数量由 approved_forest.variant_counts 表达，P4 同步验证六类总数。\n\n正式验收脚本逐个撤销旧树干部件局部 Transform 后比较全图 7,393 个树根位置 / Basis，兼查原区域退让和碰撞隔离；startup_mode=0 避免启动 AI。十四张实际 Main 昼夜图与同镜头静态渲染 A/B 不等同于战斗压力验收。原版 A 的局部样片继续可用，Main 不引用样片场景。\n\n'
    return s.replace('## T0362 正式地表与 T0363 样片边界', paragraph+'## T0362 正式地表与 T0363 样片边界', 1)
edit('docs/GODOT_ARCHITECTURE.md', arch)
edit('docs/ART_DIRECTION.md', lambda s:s.replace('T0364 树模型已认可、密度修订待评价：','T0364 原版密度版已获认可，并通过 T0364-I 成为正式树木基线：',1).replace('T0364 当前逐点保留原树位','T0364-I 正式全图 7,393 棵逐点保留原树位',1))
edit('docs/DEV_LOG.md', lambda s:s.replace('# DEV_LOG.md\n', '# DEV_LOG.md\n\n## 2026-09-05 — T0364-I 已认可树形正式接入\n\n'+completed+'\n\n- CURRENT_STATE、TASKS、MODULE_INDEX、ART_DIRECTION、GODOT_ARCHITECTURE 已同步；新增共用树形构造与正式验证脚本，预览配置隔离保留。GM_PANEL 无需更新：美术直接可见。此前 MCP 阻塞已解除。\n',1))
edit('project.godot',lambda s:s.replace('0.0.658-t0362-ground-integration','0.0.659-t0364-forest-integration',1))
