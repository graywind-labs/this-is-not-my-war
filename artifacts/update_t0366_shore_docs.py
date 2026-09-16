from pathlib import Path
record='2026-09-05：按用户反馈修订 T0366：原先虽沿下游移动但横向排列的水纹，已改为沿河道延伸的纵向细流痕；新增七处 / 21 块大小错落的低模水岸石，部分伸入水面打破岸线。石组按原河道 profile 取样，中心位于水线两侧 0.4m 内，底部埋至水面下 0.4m，顶部露出；中央至少 40% 水道保持净空。Shader 以这 21 块石头的水线轮廓定位白色泡沫，迎水侧 / 两侧较明显，下游留短而断续的尾流，与纵向流痕共用动画时钟。泡沫只画在原水体上，无新增泡沫平面或碰撞。120 个原水体顶点和 52 个旧河岸 / 岸石 Mesh / Transform 仍不变，树木仍为 7,393 棵。headless、D3D12 四镜头昼夜十六图与两个流动相位、MCP A/B / 接地 / 水道净空断言通过。当前样片已打开近看 B，状态 Partial 待评价，未正式接入；正式河道、水位、碰撞导航、人物和建筑工位未改，无 LLM、无需 GM、版本不变。当前图与快照：`artifacts/visual_qa/t0366/shore_revision/`。'
def edit(name, fn):
    p=Path(name); p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8',newline='\n')
def current(s):
    a=s.index('2026-09-05：T0366 独立河流样片')
    b=s.index('预览入口：',a)
    return s[:a]+record+'\n\n'+s[b:]
edit('docs/CURRENT_STATE.md',current)
edit('docs/TASKS.md',lambda s:s.replace('状态：In Progress（按用户反馈改为纵向流痕，并加入水岸石组与绕石白沫）','状态：Partial（纵向流痕 / 水岸石组 / 白沫修订已展示，待评价）',1).replace('### T0367 已认可样片的风格统一与整合评审',record+'\n\n### T0367 已认可样片的风格统一与整合评审',1))
edit('docs/MODULE_INDEX.md',lambda s:s.replace('基于横河 / 顺河坐标的深浅水色与断续流纹，无顶点位移','基于横河 / 顺河坐标的深浅水色、纵向流痕、按石头水线轮廓生成的绕石白沫，无顶点位移',1).replace('水 / 石色板、水纹速度与强度、四组镜头','水 / 石色板、纵向水纹速度与强度、七处水岸石组 / 半径 / 种子、白沫强度与四组镜头',1).replace('`artifacts/visual_qa/t0366/` | 本机忽略的十六张 A/B 图、两张水纹相位图和 snapshot.json','`artifacts/visual_qa/t0366/shore_revision/` | 本机忽略的当前修订十六张 A/B 图、两张水纹相位图和 snapshot.json',1))
edit('docs/GODOT_ARCHITECTURE.md',lambda s:s.replace('## T0366 河流独立样片\n','## T0366 河流独立样片\n\n最新用户修订：水纹改为横河方向窄、纵向长且沿下游移动的流痕。CandidateWaterlineRocks 新建七处 / 21 块纯表现低模石，按原 profile 的水线定位；原河岸岩石仍不动。石体水线椭圆写入 water shader 的至多 32 个 rock_footprints，生成迎水侧 / 两侧白沫和断续下游尾流，统一 flow_time 驱动，白沫仅在水面绘制。断言石组贴近水线、底部入水、中央净空及泡沫足迹数量与石体一致；不增加物理 / 导航权威。\n',1))
edit('docs/ART_DIRECTION.md',lambda s:s.replace('## T0366 河流候选待评价\n','## T0366 河流候选待评价\n\n用户明确要求水纹沿河道纵向延伸，不能横着像栅栏。当前修订已改为纵向细流痕，水岸局部增加七处半浸水石组，使水线有凸出和绕流变化；泡沫为白色，集中在迎水侧与绕石边缘，下游留少量碎尾流，不把整条河岸铺成白带。原河道 / 水位保持，旧岸石不移动，新石组属于候选表现。\n',1))
edit('docs/DEV_LOG.md',lambda s:s.replace('# DEV_LOG.md\n','# DEV_LOG.md\n\n## 2026-09-05 — T0366 纵向水纹、水岸石与绕流白沫修订\n\n'+record+'\n\n- CURRENT_STATE / TASKS / MODULE_INDEX / ART_DIRECTION / GODOT_ARCHITECTURE 已回写；GM_PANEL 无需更新。\n',1))
