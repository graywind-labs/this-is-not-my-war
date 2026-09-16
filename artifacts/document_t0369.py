from pathlib import Path
record='2026-09-06：T0369 已按用户要求，将驿站内 8 簇现有草一对一替换为普通低模小野花，白色 / 黄色各 4 簇，每簇 3 朵、细茎和少量绿叶。使用独立种子从原草位选取，必须在围墙内、距道路边缘至少 1m、沿用原建筑地块退让，花簇相隔至少 9m。新花网格包围盒严格匹配原草簇，完整沿用原位置 / 尺寸 / 朝向；中央原散布区 922 个位置保持，表现为 914 簇草与 8 簇花，外围 23,812 簇草不改。两种花共用各自 MultiMesh，不增加散布总量，无碰撞 / 导航 / 工位或玩法改动。headless 加载、实际 Main D3D12 逐点比对原 / 新 Transform、原草颜色、花簇尺寸、数量、站内退让和间距通过；前后区域共四处花簇的近景 / 环境与全站昼夜截图已核对，白黄花均为小型点缀。图 / 快照：`artifacts/visual_qa/t0369/` 和 `artifacts/visual_qa/t0369/front_views/`；一次性验证脚本在忽略目录 `artifacts/verify_t0369.gd`。无需 GM、未调用 LLM，本次未复测战斗压力。版本 `0.0.664-t0369-station-wildflowers`。'
p=Path('docs/CURRENT_STATE.md');s=p.read_text(encoding='utf-8').replace('## 当前版本\n\n','## 当前版本\n\n'+record+'\n\n',1).replace('版本：`0.0.663-t0368-building-ground-contact`','版本：`0.0.664-t0369-station-wildflowers`');p.write_text(s,encoding='utf-8')
p=Path('docs/TASKS.md');s=p.read_text(encoding='utf-8');a=s.index('### T0369');b=s.index('### T0367',a);s=s[:a]+s[a:b].replace('状态：In Progress','状态：Done')+record+'\n\n'+s[b:];p.write_text(s,encoding='utf-8')
p=Path('docs/DEV_LOG.md');s=p.read_text(encoding='utf-8').replace('# DEV_LOG.md\n\n','# DEV_LOG.md\n\n## 2026-09-06 — T0369 驿站内少量白黄小野花\n\n'+record+'\n\n- CURRENT_STATE、TASKS、MODULE_INDEX、ART_DIRECTION、GODOT_ARCHITECTURE 已回写；GM_PANEL 无需更新。\n\n',1);p.write_text(s,encoding='utf-8')
p=Path('docs/MODULE_INDEX.md');s=p.read_text(encoding='utf-8').replace('# MODULE_INDEX.md\n\n','''# MODULE_INDEX.md

## T0369 驿站内白黄小野花

| 文件 | 职责 |
|---|---|
| `scripts/presentation/environment/LowPolyWildflowers.gd` | 程序化三朵低模野花 / 茎叶，匹配原草簇包围盒 |
| `scripts/presentation/environment/StylizedGroundArt.gd` | 原草位生成后用独立种子挑选 8 处站内位置，一对一替换；保留其余 Transform / 草色与站外草 |
| `data/presentation/ground_art_trial.json` | wildflowers 开关、数量、间距、种子和白黄花色 |

快照 tufts 仍表示原中央散布位置总数，grass_tufts / wildflowers 分别表示剩余草 / 替换花数量。正式 Main 可直接看见。截图 / 一次性验证保存在本机忽略的 `artifacts/visual_qa/t0369/` / `artifacts/verify_t0369.gd`。

''',1);p.write_text(s,encoding='utf-8')
p=Path('docs/GODOT_ARCHITECTURE.md');s=p.read_text(encoding='utf-8').replace('# GODOT_ARCHITECTURE.md\n\n','''# GODOT_ARCHITECTURE.md

## T0369 小野花替换草簇

StylizedGroundArt 保持既有草位 RNG 流不变；原 points 生成后独立挑选围墙内 8 处、间距至少 9m 的原位置。草 MultiMesh 过滤这些索引，其余实例颜色仍按原索引决定；花 MultiMesh 直接使用被替换草的 Transform，不再另散点。LowPolyWildflowers 生成两色三花小簇，网格尺寸与原草 Mesh AABB 一致，按缩放修正法线。外围草生成器沿用原草网格，未修改其随机流或点位。该模块只管表现；正式原地表 / 建筑接合、道路、碰撞导航不改。

''',1);p.write_text(s,encoding='utf-8')
p=Path('docs/ART_DIRECTION.md');s=p.read_text(encoding='utf-8').replace('# ART_DIRECTION.md\n\n','''# ART_DIRECTION.md

## T0369 驿站内的小野花

按用户要求，用极少量普通白 / 黄野花区分站内与站外：仅替换站内 8 簇原草，白黄各 4 簇。保持与草同样大小，细茎、少量绿叶、小花瓣与花心，不做花坛或成片鲜花，不增加总散布密度，站外仍保持原草地。

''',1);p.write_text(s,encoding='utf-8')
p=Path('project.godot');s=p.read_text(encoding='utf-8').replace('config/version="0.0.663-t0368-building-ground-contact"','config/version="0.0.664-t0369-station-wildflowers"');p.write_text(s,encoding='utf-8')
