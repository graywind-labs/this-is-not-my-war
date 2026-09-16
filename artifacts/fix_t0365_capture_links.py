from pathlib import Path
for file in ['docs/CURRENT_STATE.md', 'docs/TASKS.md', 'docs/DEV_LOG.md']:
    p = Path(file)
    s = p.read_text(encoding='utf-8').replace('图与快照：`artifacts/visual_qa/t0365/`。正式整合', '图与快照：`artifacts/visual_qa/t0365/cliff_revision/`。正式整合')
    p.write_text(s, encoding='utf-8', newline='\n')
p = Path('docs/MODULE_INDEX.md')
s = p.read_text(encoding='utf-8').replace('| `artifacts/visual_qa/t0365/` | 本机忽略的十六张 A/B 图与 snapshot.json |', '| `artifacts/visual_qa/t0365/cliff_revision/` | 本机忽略的高岩壁版十六张 A/B 图与 snapshot.json；每张保存返回值验证 |', 1)
p.write_text(s, encoding='utf-8', newline='\n')
