# MODULE_INDEX.md

## T0061 NPC 背景叙事与知识面板收束索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 保存 8 人稳定根本人设与宽松 `speech_style`；不再保存会限定口吻的 `signature_lines` |
| `scripts/core/NPCPromptProfile.gd` | 统一构造背景弹窗与对话 `npc_setting` 的 9 项人物字段，不再提供“代表性表达” |
| `scripts/systems/LLMBridge.gd`、`backend/schemas/common.py` | 为对话、日计划、修改判别、正式修订、战时心理和首次睡眠反思提供同一宽松身份上下文；六类 payload 均不携带固定样例句 |
| `data/npc_initial_long_memory.json` | 保存 8 人按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜拼接的宏观身世 / 到站群像、未改动的近日微观日常、统一 `role` 的守备官职责和叙事化建筑常识；8 条仓库 `value` 受控迁移为 `central_storage_and_post_breach_attack_target`，其余技术值不变，222 条 `confidence / day / time` 完整保留 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 只把 `speech_style` 视为宽松表达习惯；解释前两篇宏观背景、近日时间边界、职责型守备官种子和实时程序事实优先 |
| `scripts/ui/NPCPanel.gd` | “背景”详情移除代表性表达；“知识”详情只显示中文主体 / 关系 / 值，不显示可信度或更新时间 |
| `scripts/ui/GMPanel.gd` | 不新增入口；既有 `long_memory <npc_id>` 继续显示含 `confidence / day / time` 的完整运行态图谱，用于核对玩家 UI 隐藏而底层保留 |
| `tools/verify_npc_initial_long_memory.py` | 静态校验八人到站时序、前两篇宏观 / 拼图叙事、近日未改、守备官 `role`、建筑叙事化、仓库技术值迁移和 222 条底层元数据保留 |
| `tools/verify_npc_character_profiles.gd`、`tools/verify_npc_initial_long_memory.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_daily_reflection_system.gd`、`tools/verify_gm_panel.gd` | 5 个 Godot 专项校验档案 / 六类身份上下文无 `signature_lines`、运行态种子、反思追加、GM 原始数据与玩家 UI 隐藏边界；最终最大 payload 字符数为 `battle_judgement=32057 / daily_reflection=29242 / dialogue=48330 / plan_day=47118 / plan_revision_judgement=50053 / revise_plan=49952` |
| `tools/verify_npc_initial_long_memory_real.py` | 真实 DeepSeek `deepseek-v4-flash` 完成 3 次记忆路径调用，0 失败，全部 `fallback_used=false` |

## T0060 NPC 初始长期记忆文案重写索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | T0060 当时保存 7 类根本人设；当前已由 T0061 移除固定代表性表达，只保留宽松职业语气与稳定人物内核 |
| `data/npc_initial_long_memory.json` | T0060 确立 24 篇开局前日记、227 条中文 `value_label` 与每人 25 个知识主体；当前前两篇、守备官和建筑中文叙事已由 T0061 进一步收束，近日记录保持不变 |
| `scripts/systems/LLMBridge.gd` | 向六类正式请求注入唯一规范长期记忆，并把结构化日记投影为带“往昔”或“第 N 天 HH:MM:SS”时间标签的 `list[str]` |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | T0060 确立自然中文、种子时间边界与实时事实优先；当前固定台词和守备官种子口径以 T0061 为准 |
| `tools/verify_npc_initial_long_memory.py` | 当前同时覆盖 T0060 的 8 人 / 24 篇日记 / 25 主体与 T0061 的到站时序、守备官单条职责、建筑叙事化和元数据边界 |
| `tools/verify_npc_character_profiles.gd`、`tools/verify_npc_initial_long_memory.gd` | 当前校验宽松档案文案、运行态种子、时间标签、玩家知识显示和六类 payload 的无固定台词 / 去重 / 隐私边界 |
| `tools/verify_npc_initial_long_memory_real.py` | T0060 当时用真实 provider 追问莉娜、欧文、布鲁诺 3 条记忆路径；T0061 当前版本再次完成 3 次真实调用，0 失败且无 fallback |
| `tools/verify_dialogue_prompt.py`、`tools/verify_plan_day_prompt.py`、`tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_plan_revision_prompt.py`、`tools/verify_battle_judgement_prompt.py`、`tools/verify_daily_reflection_prompt.py` | 分别验证六类 Prompt 都保留自然中文、时间边界和程序权威合同 |

## T0059 NPC 初始长期记忆与根本人设索引

| 文件 | 当前职责 |
|---|---|
| `data/npc_profiles.json` | 保存 8 人身份、根本人设、职业语气和权威初始状态；`diary / knowledge_graph` 保持空占位，不复制种子记忆 |
| `data/npc_initial_long_memory.json` | 独立保存 8 人各 3 篇开局前日记，以及覆盖 15 建筑、其余人物、守备官和个人故事主体的 `key_value_replace_v1` 初始图谱 |
| `scripts/systems/NPCSystem.gd` | 在生成 NPC 前校验档案与种子 id / 结构，再把日记和知识图谱深拷贝到运行态 |
| `scripts/systems/LLMBridge.gd` | 向六类业务注入规范长期记忆；避免 NPCContext 重复图谱，并阻止对话 participant 复制或泄露私人长期记忆 |
| `backend/schemas/common.py` | `NPCContext.long_term_memory` 作为当前规范字段；旧 `knowledge_graph` 仅保留兼容，Godot 正式 payload 不再填充 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 区分开局前长期记忆与实时事实，保持守备官关系开放，并禁止反思把种子历史伪写成当天事件 |
| `tools/verify_npc_initial_long_memory.py` | 静态校验 8 人、24 篇日记、15 建筑 / 人物覆盖、中文标签、职业详略、开放守备官与六份 Prompt |
| `tools/verify_npc_initial_long_memory.gd` | 加载真实 Main，验证运行态种子、NPC 面板文本与六类 payload 注入 / 去重 / 隐私边界 |
| `tools/verify_npc_initial_long_memory_real.py` | T0059 当时追问莉娜 / 欧文旧往事；当前已由 T0060 的莉娜 / 欧文 / 布鲁诺 3 条新记忆路径覆盖 |
| `tools/verify_daily_reflection_system.gd`、`tools/verify_gm_panel.gd` | 把旧“初始日记为空”假设改为以种子条数为基线，继续验证追加反思与既有长期记忆入口 |

## T0058 NPC LLM 公开资源与升级常识索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/LLMBridge.gd` | 从 ResourceSystem 实时投影五项公开资源；组装六字段 `station_context`；收窄计划类资源兼容字段 |
| `backend/schemas/common.py`、`backend/schemas/__init__.py` | 定义五项严格资源条目及 `StationSceneContext` 完整性校验 |
| `data/station_context.json` | 保存第六条“升级缓慢、协助可加快”世界内规则，不保存运行态资源或目标 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 解释资源白名单、隐藏库存边界、升级常识与各调用职责 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 复用 `station_context` 只读入口显示公开资源与规则 |
| `tools/station_context_fixture.py`、`tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd` | 构造 / 验证资源 Schema、六类实时 payload、隐藏库存排除和规则 |
| `tools/verify_plan_action_catalog.gd`、`tools/verify_station_context_real.py`、`tools/verify_plan_day_prompt_real.py` | 验证英文技术值 / 中文名称、真实资源理解和真实计划选择升级协助 |

## T0057 建筑升级行动失败链路索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 区分指向升级建筑的 pending / active 依赖行动；先清理移动 / 位置，再写带完整中文上下文的 `*_failed_building_upgrading` |
| `scripts/systems/DailyPlanSystem.gd` | 将 `building_upgrading / building_unavailable` 规范为 `target_unavailable`，复用 T0050 判别与精确修订 |
| `tools/verify_building_upgrade_action_failure.gd` | 可控 provider 覆盖路上 pending、进行中 active、失败上下文、第一层判别与非空后的第二层修订 |
| `docs/GM_PANEL.md` | 记录复用“指定行动 → 升级 → plan_request”的验证方式，不新增伪造失败的按钮 |

## T0055 持续活动 / 周期结算常识索引

| 文件 | 当前职责 |
|---|---|
| `data/station_context.json` | 增加世界内持续参与、周期完成后结算、离岗后不自动产出的第五条规则 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 按各自任务禁止把未完成周期或无人参与活动写成已产出 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py` | 在当前六条规则合同中验证持续活动规则随六类 payload 注入，并用真实对话检查菜园离岗后不会自动产出 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 复用既有 `station_context` 只读入口显示包含该规则的当前规则集，不新增按钮或权威逻辑 |

## T0054 NPC LLM 驿站常识上下文索引

| 文件 | 当前职责 |
|---|---|
| `data/station_context.json` | 数据驱动保存精简驿站简介和当前六条世界内规则，不保存人员、建筑、行为或资源运行态副本 |
| `scripts/systems/LLMBridge.gd` | 从 NPCSystem / BuildingSystem / ActionSystem / ResourceSystem 构造唯一顶层六字段 `station_context`，供六类正式 NPC LLM 请求复用；提供只读 debug 快照 |
| `backend/schemas/common.py`、`backend/schemas/__init__.py` | 定义必填非空的人员、建筑、工作模式行为、五项基础资源和规则合同 |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | 解释完整世界目录、单次候选和程序权威边界，禁止补造名单外成员 / 建筑 |
| `scripts/ui/GMPanel.gd`、`docs/GM_PANEL.md` | 通过按钮 / `station_context` 命令只读观察运行态上下文，不修改世界事实 |
| `tools/station_context_fixture.py` | 从正式配置构造 Python 测试上下文，避免测试维护第二份建筑 / 行为清单 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py`、`tools/verify_gm_panel.gd` | 覆盖 Schema、六类 Godot payload、动态离站名单、目录来源、叙事规则、GM 入口和真实 provider 语义 |

## T0053 跨小时对话失效与上下文统一索引

| 文件 | 当前职责 |
|---|---|
| `scripts/systems/ActionSystem.gd` | 保存日计划对话来源元数据；在逻辑 tick / 计划重试 / 整点派发前校验当前计划，失配时释放预约并写 `talk_to_npc_failed_plan_superseded` 完整上下文 |
| `scripts/systems/DailyPlanSystem.gd` | 日计划对话派发时附加来源项；整点先过期无效等待；行动失败优先使用上下文中的旧 `failed_plan_item` 进入 T0050 两阶段链 |
| `scripts/systems/LLMBridge.gd` | 判别、日计划、正式修订和战时心理共用 NPCContext；长期记忆同时含知识图谱和日记 |
| `backend/schemas/common.py` | `NPCContext.long_term_memory={knowledge_graph, diary}` 及兼容知识图谱字段 |
| `backend/schemas/npc_ai.py` | 判别请求继承 StationAwareNPCRequest、必填 NPCContext / 现实条件并支持 `plan_item_superseded` |
| `data/prompts/plan_revision_judgement_system_prompt.txt` | 结合失败事实与人物 / 记忆 / 指令上下文选择精确修订小时，不制定行动 |
| `data/prompts/plan_revision_system_prompt.txt` | 正式修订延续同一人物与长短期记忆，并区分旧失败项 / 当前项 |
| `data/prompts/battle_judgement_system_prompt.txt` | 低血量参战 / 避战 / 逃离心理读取同一长期记忆与人物上下文 |
| `scripts/ui/GMPanel.gd` | `expire_plan_dialogues` 只扫描既有日计划对话等待并显示真实过期 NPC，不创建或伪造失败 |
| `tools/verify_npc_npc_dialogue_edges.gd` | 回归计划等待续接、跨小时失效、预约释放和失败判别上下文 |
| `tools/verify_action_failure_plan_revision_judgement.gd` | 回归判别 / 正式修订两层失败事实与完整人物上下文 |
| `tools/verify_dynamic_station_context.gd` | 防止日计划 / 修订 / 战时心理丢失共享人设、长短期记忆或地点字段 |
| `tools/verify_gm_panel.gd` | 回归过期扫描命令存在且可安全执行 |

## T0052 计划阶段对话互斥与等待续接索引

| 路径 | 职责 |
|---|---|
| `scripts/systems/NPCSystem.gd` | 公开 `is_npc_plan_llm_active(...)`，以统一 `kind=plan` 识别每日计划、修改判别和计划修订活动 |
| `scripts/systems/DialogSystem.gd` | 玩家草稿 / 首次实际交互拒绝计划中目标；自主邀请启动前返回 `npc_planning`，不取消计划请求 |
| `scripts/systems/ActionSystem.gd` | `talk_to_npc` 目标计划中时保留 pending action、双方预约和开场白，状态清除后延迟续接邀请 |
| `scripts/systems/LLMBridge.gd` | 日计划允许并行计划目标作为稍后对话候选；即时失败修订只提供当前可执行对话目标 |
| `scripts/ui/NPCPanel.gd` | 计划活动期间禁用对话按钮并提示“NPC正在思考”，状态清除后自动恢复 |
| `tools/verify_dialogue_sleep_summary_boundaries.gd` | 玩家入口不取消计划、按钮禁用 / 恢复与既有深睡边界回归 |
| `tools/verify_npc_npc_dialogue_edges.gd` | 自主对话等待期间不请求 / 不失败 / 不释放预约，计划清除后自动邀请 |
| `tools/verify_plan_action_catalog.gd` | 日计划与即时修订对计划中 NPC 的候选差异 |

## T0051 可拖动弹窗与守备官会话生命周期索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/DraggablePanel.gd` | 顶部栏拖动、锚点解除、用户位置保留、视口夹取 |
| `scripts/ui/DialogPanel.gd` | 完成 / 取消 / 挂起 UI、即时消息展示、挂起气泡恢复 |
| `scripts/systems/DialogSystem.gd` | 守备官会话三态权威、整场事件提交、迟到回复丢弃、两小时超时 |
| `scripts/npc/NPC.gd` | 自主对话 / 挂起守备官会话双色头顶气泡 |
| `scripts/ui/NPCPanel.gd` | 对话按钮橙点与挂起会话恢复；主面板 / 记忆详情拖动 |
| `scripts/ui/BuildingPanel.gd` | 建筑面板拖动并与自适应高度共存 |
| `scripts/ui/OrderPanel.gd` | 指令面板拖动；不隐式覆盖活动守备官会话 |
| `scripts/ui/NoticeBoardPanel.gd` | 公告牌窗口拖动 |
| `scripts/ui/MerchantPanel.gd` | 商人窗口拖动 |
| `scripts/ui/HUD.gd` | 装备 / 器械库存详情拖动 |
| `scenes/main/Main.tscn` | 三个会话按钮与 NPC 对话按钮橙点节点 |
| `data/action_defs.json` | 非计划可选运行态 `talk_to_guard_officer` 显示定义 |
| `tools/verify_dialogue_session_lifecycle.gd` | 拖动、即时消息、三态、攻击锁、气泡 / 橙点与超时自动化 |

## T0049/T0050 通用计划判别、精确阶段修订与最新记录定位索引

| 路径 | 职责 |
|---|---|
| `data/prompts/plan_revision_judgement_system_prompt.txt` | 按 `trigger_kind=dialogue|action_failure` 结合权威事实和共享人物 / 长短期记忆 / 指令上下文判断是否需要修改计划，只输出精确 `revision_hours`；空数组表示 0 个阶段 |
| `data/prompts/plan_revision_system_prompt.txt` | 保留既有完整修订上下文，但将输出限制为请求中的 `selected_hours` |
| `backend/schemas/npc_ai.py`、`backend/schemas/__init__.py` | 定义通用 `PlanRevisionJudgementRequest/Response` 及旧对话名兼容别名，并把 `PlanRevisionRequest/Response` 收紧为非空精确小时合同 |
| `backend/app.py`、`backend/services/model_adapter.py` | 提供 `/npc/plan_revision_judgement`（旧对话端点兼容），校验判别 / 修订小时集合，并支持第六类正式 LLM 调用的 Prompt、Mock 与 usage 元数据 |
| `scripts/systems/LLMBridge.gd` | 按触发类型构建含完整共享 NPCContext 的判别 payload、异步调用通用端点；修订 payload 使用同一人物上下文、`revision_scope=selected_hours` 与精确 `revision_hours` |
| `scripts/systems/DialogSystem.gd` | 守备官-NPC 有效会话为目标判别；NPC-NPC 邀请拒绝或正式结束为双方分别判别，并在发起双方请求前登记会话组派发屏障；对话内已提交攻击即使无 NPC 回复也进入同一判别 |
| `scripts/systems/DailyPlanSystem.gd` | 对话与日常行动失败先判别、只合并非空判别选中小时；其他程序触发继续直接受限修订；NPC-NPC 双方链终态后按依赖顺序放行，跨小时玩家对话和行动失败判别终态前延迟旧计划重派；保留真实三次尝试、过期 / epoch 丢弃和单后继队列 |
| `scenes/main/Main.tscn`、`scripts/ui/DialogPanel.gd` | 删除守备官对话“结束后重估计划”开关，由 NPC 判别层统一决定 |
| `scripts/ui/NPCPanel.gd` | 事件库 / 见闻库详情首次打开滚到最底部，打开期间刷新保留玩家阅读位置 |
| `scripts/ui/GMPanel.gd` | 复用既有计划 / LLM 观察入口查看最近判别与精确修订；手动重估只触发当前小时，不增加第二套权威入口 |
| `tools/verify_dialogue_plan_revision_judgement.py`、`tools/verify_dialogue_plan_revision_judgement_real.py` | 对话 / 行动失败通用判别层 Schema / Prompt / endpoint、严格第二层范围与真实 provider 验收 |
| `tools/verify_action_failure_plan_revision_judgement.gd` | Godot 行动失败空 / 非空判别、严格小时合并、完整第二层上下文与计划派发屏障专项 |
| `tools/verify_player_dialogue_plan_resume.gd`、`tools/verify_npc_npc_plan_action.gd`、`tools/verify_plan_revision_remaining_day.gd`、`tools/verify_npc_panel_state.gd` | 空集合恢复、双方独立判别、精确小时合并 / 竞态与详情滚动行为回归；旧文件名保留但合同已改为 selected hours |

## T0047 建筑面板真实点击竞态修复索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 用 fit generation 与每阶段最多 4 帧采样保证透明测量一定收尾；透明阶段递归禁用鼠标，修复 / 升级回调复验面板交互状态 |
| `tools/verify_building_panel_real_click.gd` | Camera3D 投影全部 15 个建筑 ID 的可见点击点，向 Viewport 发送真实鼠标事件，并锁定面板显示与零状态突变 |
| `tools/verify_building_repair_upgrade.gd`、`tools/verify_npc_panel_state.gd` | 按新的有界测量上限等待内容收敛，继续覆盖修复 / 升级与 NPC / 建筑面板互斥 |

## T0046 长期记忆、动态驿站上下文与公告牌索引

| 路径 | 职责 |
|---|---|
| `backend/schemas/common.py`、`backend/schemas/npc_ai.py` | 建立 `StationAwareNPCRequest` 顶层必填上下文和当前在站人员基础合同；T0054 已扩充建筑、行为与规则字段；反思响应仅含日记和知识更新 |
| `scripts/systems/LLMBridge.gd` | 从运行态动态构建中文在站名单并过滤逃离 / 站外 NPC；T0054 已将同一构造器扩充并覆盖六类业务 payload |
| `data/prompts/dialogue_system_prompt.txt`、`daily_plan_system_prompt.txt`、`plan_revision_system_prompt.txt`、`battle_judgement_system_prompt.txt`、`daily_reflection_system_prompt.txt` | T0046 建立共享场景与反思输出基础；T0054 已扩充共享场景字段与世界内规则 |
| `scripts/systems/DailyReflectionSystem.gd`、`scripts/systems/NPCSystem.gd`、`scripts/ui/NPCPanel.gd` | 仅写入第一人称日记 + 替换式知识图谱，规范化时剔除旧 `memory_summary`，向玩家显示中文知识主体 / 关系 / 值 |
| `data/notice_board_defaults.json` | 守备官口吻的初始通告、10 条通用参考日程和固定“仅供参考、可自行安排”备注 |
| `scripts/systems/MemorySystem.gd` | 权威保存广场当前通告 / 参考日程，校验时段，广播 `plaza_notice_changed` / `plaza_schedule_changed`，提供入场快照并预写初始 NPC 见闻；离站者从地点节点移除且不再接收见闻 |
| `scripts/ui/NoticeBoardPanel.gd`、`scenes/main/Main.tscn` | 提供“通告 / 参考日程”双 Tab 草稿编辑、日程增删改 / 全天重叠提示、发布 / 退出语义与容器尺寸 |
| `tools/verify_station_context_schema.py`、`tools/verify_dynamic_station_context.gd`、`tools/verify_station_context_real.py` | Schema、运行态 8→7 名单和真实 provider 基础场景验收 |
| `tools/verify_notice_board_tabs.gd`、`tools/verify_notice_board_input.gd`、`tools/verify_escape_station_behavior.gd`、`tools/verify_reference_schedule_real_plans.gd` | 草稿取消、双页 UI、日程增删改 / 全天重叠提示、初始 / 广播 / 入场 / 离站见闻和 8 人真实计划采样 |

## T0045 建筑布局、镜头输入与成长文案索引

| 路径 | 职责 |
|---|---|
| `scripts/ui/BuildingPanel.gd` | 按建筑缓存稳定自然高度，在容器排版后再应用修复 / 升级内容尺寸 |
| `scripts/camera/CameraRig.gd` | 事件式跟踪 WASD，按键释放、文本焦点或窗口失焦时清理平移 / 拖拽状态 |
| `scripts/systems/NPCSystem.gd`、`scripts/systems/MemorySystem.gd` | 保持技能点权威结算，把属性成长事件改为 NPC 锻炼体力 / 脑力叙事 |
| `tools/verify_camera_rig_input.gd` | 覆盖 WASD 按下 / 释放、窗口失焦、中键取消和文本输入焦点 |
| `tools/verify_building_repair_upgrade.gd`、`tools/verify_skill_progression.gd` | 覆盖建筑进度面板无满高闪烁与力量 / 智力精确成长文案 |

## T0044 对话恢复与对象面板收敛索引（恢复触发已由 T0049 接管）

| 路径 | 职责 |
|---|---|
| `scripts/systems/DailyPlanSystem.gd` | 校验被打断行动与当前计划一致后，通过专用入口清除该计划阶段签名，并复用正常计划派发 / 校验 |
| `scripts/systems/DialogSystem.gd` | 记录玩家对话是否确实打断运行时行动；T0049 判别为空且仍为工作模式时才请求恢复 |
| `scripts/ui/NPCPanel.gd` | 提供未入伍禁用控件提示、事件 / 见闻玩家详情白名单、首次打开定位最新记录，并避免刷新帧临时撑满高度 |
| `scripts/ui/BuildingPanel.gd` | 精简马厩文案，把修复 / 升级提示移到 UI 覆盖层，并避免刷新帧临时撑满高度 |
| `tools/verify_player_dialogue_plan_resume.gd` | 覆盖实际中断后不重估恢复、空闲对话不重放、重估不恢复和普通同阶段派发仍去重 |
| `tools/verify_npc_panel_state.gd`、`tools/verify_npc_panel_interactions.gd`、`tools/verify_building_panel_workstations.gd`、`tools/verify_building_repair_upgrade.gd` | 覆盖信息白名单、征召提示、马厩文案及对象面板闪框边界 |

## T0043A 服务依赖与弥撒参与索引

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 声明诊疗 / 训练 / 参加弥撒的持续依赖，以及普通祈祷与主持弥撒的互斥 |
| `scripts/systems/ActionSystem.gd` | 验证有效服务者、协调等待、处理中途离岗、弥撒主持与参加者的共同完成 / 失败，并暴露运行态绑定 |
| `scripts/systems/DailyPlanSystem.gd` | 按服务者、普通行动、依赖者、对话顺序派发，并规范化依赖失败类型 |
| `scripts/systems/LLMBridge.gd` | 把依赖 / 互斥和实时可用性投影到计划及对话候选 |
| `scripts/systems/MemorySystem.gd` | 按具体 action id 区分普通祈祷、主持弥撒和参加弥撒事件摘要 |
| `data/prompts/daily_plan_system_prompt.txt`、`data/prompts/plan_revision_system_prompt.txt`、`data/prompts/dialogue_system_prompt.txt` | 约束模型理解服务依赖和三种教堂行动，不越过程序事实 |
| `tools/verify_service_dependency_interruptions.gd` | 覆盖无服务者、服务者离岗、教堂互斥及主持正常 / 异常结束的端到端专项 |
| `tools/verify_plan_action_catalog.gd`、`tools/verify_gm_panel.gd` | 验证 `attend_mass` 候选上下文和通用 GM 行动入口 |

## T0042 NPC 面板人物背景弹窗索引

| 路径 | 职责 |
|---|---|
| `scripts/core/NPCPromptProfile.gd` | 从 NPC 档案构造 Prompt 与玩家背景弹窗共用的 `npc_setting` 字段集合 |
| `scripts/systems/LLMBridge.gd` | 通过共享构造器继续向 LLM 发送 NPC 人设 |
| `scenes/main/Main.tscn`、`scripts/ui/NPCPanel.gd` | 在姓名旁提供“背景”按钮并用共用详情弹窗只读展示同一份人设 |
| `tools/verify_npc_panel_state.gd` | 验证按钮位置、全部人设字段、开关弹窗与切换 NPC 无旧内容残留 |

## T0041 非计划对话行动参考索引

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 行为定义单一数据源；不为对话复制第二份行动 ID 清单 |
| `scripts/systems/LLMBridge.gd` | 用与每日计划相同的动态候选构造器填充所有对话 `allowed_actions` |
| `backend/schemas/npc_ai.py` | 要求 `NPCDialogueRequest.allowed_actions` 至少包含一条候选 |
| `data/prompts/dialogue_system_prompt.txt` | 把候选解释为能力参考而非计划或已执行事实 |
| `tools/verify_dialogue_action_reference.gd` | 覆盖 7 个对话上下文、非空参考和计划 / 对话候选一致性 |
| `tools/verify_dialogue_prompt.py`、`tools/verify_dialogue_prompt_real.py` | fake-provider Prompt 合同与玩家-NPC / NPC-NPC 真实能力认知验收 |

> 本文件用于帮助 Agent 快速找到模块位置。
> 每新增、移动、删除重要代码文件，都必须更新这里。

## T0033 玩家对话剩余日重评估索引（历史方案，已被 T0049 取代）

| 路径 | 职责 |
|---|---|
| `data/npc_profiles.json` | 为马塞尔补充简短“擅长酿酒”人设，不改变神父职业 |
| `scenes/main/Main.tscn`、`scripts/ui/DialogPanel.gd` | 提供“结束后重估计划”开关及守备官 / NPC 发起默认值展示 |
| `scripts/systems/DialogSystem.gd` | 只在开关开启且完成有效回复后请求剩余日重评估；关闭时只恢复本次确实打断且仍匹配当前计划的行动 |
| `scripts/systems/LLMBridge.gd`、`scripts/systems/DailyPlanSystem.gd` | 构建 `remaining_day` 修订上下文，校验并覆盖当前小时至 23 点 |
| `backend/schemas/npc_ai.py`、`backend/app.py` | 声明修订范围并校验剩余小时、即时行动、工作阶段与白名单 |
| `backend/services/model_adapter.py`、`data/prompts/plan_revision_system_prompt.txt` | 按修订范围生成紧凑提示；真实业务校验失败时用同一 provider 做一次纠正请求 |
| `tools/verify_plan_revision_remaining_day.gd` | Godot 剩余日范围、过去小时保留和非法结果拒绝回归 |
| `tools/verify_plan_revision_prompt.py`、`tools/verify_plan_revision_endpoint.py`、`tools/verify_plan_revision_prompt_real.py` | 后端 Prompt / endpoint 与真实 provider 剩余日合同验收 |
| `tools/verify_dialogue_ui.gd`、`tools/verify_dialogue_sleep_summary_boundaries.gd`、`tools/verify_npc_proactive_talk.gd` | 开关默认值、有效轮次、攻击例外与主动交涉回归 |

T0048 历史补充：`remaining_day` 曾从玩家对话专用范围提升为所有正式计划重估的唯一范围。T0049 已取代该方案：对话先判别精确 `revision_hours`，非对话默认只修订当前小时；`tools/verify_plan_revision_remaining_day.gd` 文件名暂保留，但验证合同改为 selected hours。

## T0032 自主对话气泡鼠标拾取修复索引

| 路径 | 职责 |
|---|---|
| `scripts/npc/NPC.gd` | 为可见自主对话气泡写入交互类型、NPC 与会话元数据 |
| `scripts/systems/NPCSystem.gd` | 区分全局射线命中的气泡与 NPC 本体，分别路由到旁听弹窗或 NPC 面板 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | 用 Camera3D 屏幕投影和 Viewport 真实鼠标事件验证气泡点击、重开与本体点击回归 |

## T0031 NPC-NPC 旁听复验与艾达初始剑盾索引

| 路径 | 职责 |
|---|---|
| `data/npc_profiles.json` | 用 `initial_equipment.main_weapon=sword_shield` 声明艾达的开局故事装备 |
| `scripts/systems/EquipmentSystem.gd` | 从正式装备定义装载空的初始槽位，不扣全局库存、不写玩家赠送事件 |
| `tools/verify_equipment_system.gd` | 验证艾达开局剑盾、面板显示、零库存消耗 / 零初始赠送事件及后续正常换装 |
| `tools/verify_unit_type_classification.gd`、`tools/verify_combat_pacing.gd` | 验证艾达开局近战步兵分类与第一波实战节奏 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | 验证进行中关闭后按同一 `dialogue_id` 重开最新状态、自然结束后窗口保留到手动关闭 |

## T0029/T0030 NPC-NPC 邀请与软轮次会话索引

| 路径 | 职责 |
|---|---|
| `backend/schemas/npc_ai.py` | 声明邀请 / 正式会话阶段、无硬上限哨兵、软轮次字段和接受 / 拒绝结果 |
| `backend/app.py` | 校验邀请结果、正式回复、`max_rounds=0`、软轮次字段和阶段一致性 |
| `backend/services/model_adapter.py` | 为显式开发 Mock 提供阶段一致的邀请 / 正式回复和软性收尾行为 |
| `data/prompts/dialogue_system_prompt.txt` | 约束目标先接受 / 拒绝、正式会话无硬上限、事情结束 / 第 6 轮起软性收尾和最后一句语义 |
| `scripts/systems/DialogSystem.gd` | 邀请不提前打断、接受后激活会话、结束标记回复先入库且不追加调用；T0049 起拒绝与正式结束都为双方独立判别计划 |
| `scripts/systems/LLMBridge.gd` | 透传 `dialogue_phase`、当前轮次和软性指导，并维持逐请求慢速 |
| `tools/verify_dialogue_invitation_contract.gd` | Godot 邀请接受 / 拒绝、越过软阈值、任一方结束、无追加调用和差异化计划重评估合同 |
| `tools/verify_npc_npc_dialogue_real.py` | 真实 provider 邀请接受 / 拒绝和第 6 轮软性结束 smoke |

## T0028 NPC-NPC 自主对话旁听索引

| 路径 | 职责 |
|---|---|
| `scripts/core/EventBus.gd` | 广播带 NPC 与会话 ID 的自主对话气泡点击 |
| `scripts/npc/NPC.gd` | 为自主会话双方创建三点气泡、独立点击区与结束清理表现 |
| `scripts/systems/DialogSystem.gd` | 提供只读观察快照、参与者 / 会话校验、待回复展示状态与逐轮慢速选项 |
| `scripts/ui/DialogPanel.gd` | 只读旁听模式、实时轮次 / 历史 / 等待状态与本地关闭边界 |
| `tools/verify_npc_npc_dialogue_observer_ui.gd` | fake provider 双方气泡、旁听交互、关闭不打断、同会话重开、实时更新与结束后手动关闭验证 |
| `tools/verify_npc_npc_dialogue_observer_real.gd` | 真实 provider Godot 气泡、旁听、真实回复与慢速注册 / 释放验证 |
| `tools/verify_llm_time_slowdown_audit.gd` | 六类正式 LLM 慢速审计，并连续验证三轮对话逐轮注册 / 释放 |

## T0025 NPC-NPC 计划行动索引

| 路径 | 职责 |
|---|---|
| `data/action_defs.json` | 配置计划可选的对话、祈祷、主持弥撒、地点拜访、主动找守备官、训练协作、协助行动和特殊逃离意向；普通祈祷不要求神父，主持弥撒使用 `required_ability` 校验 |
| `data/prompts/plan_revision_system_prompt.txt` | 工位占用等行动失败的紧凑真实修订 Prompt |
| `backend/app.py` | 精确候选业务校验、唯一候选冗余 kind 规范化、来源元数据与 NPC-NPC 回复身份 / 类型校验 |
| `scripts/systems/ActionSystem.gd` | 对话接近 / 预定 / 打断、拜访、祈祷、训练协作、治疗失败事件、运行态目标快照与结构化失败上下文 |
| `scripts/systems/DailyPlanSystem.gd` | 目标计划解析、教官 / 普通 / 受训者 / 对话批派发顺序、单时段派发签名、真实异步修订、计划版本、单后继队列和迟到失败上限 |
| `scripts/systems/DialogSystem.gd` | 目标邀请接受 / 拒绝、无硬上限的真实自主 NPC-NPC 对话、双层回复身份校验、玩家只读草稿和结束 / 中断恢复边界 |
| `scripts/systems/LLMBridge.gd` | 全设计行动动态候选、未来计划 / 即时修订目标过滤、建筑 / 资源 / 工位占用者上下文 |
| `tools/verify_plan_action_catalog.gd` | 设计行动目录、目标组合、即时忙碌过滤和路由回归 |
| `tools/verify_plan_extended_actions.gd` | 祈祷 / 拜访从 DailyPlan 执行到计时完成和事件入库 |
| `tools/verify_npc_npc_plan_action.gd` | 工位失败、对话移动 / 释放 / 轮次 / 双方重评估主链路 |
| `tools/verify_npc_npc_dialogue_edges.gd` | 批执行、玩家草稿、取消、昏迷 / 移动等对话竞态 |
| `tools/verify_plan_target_replacement.gd` | 同一 action id 更换 NPC / 地点目标时的当前计划替换回归 |
| `tools/verify_training_plan_coordination.gd` | 同批教官先落地、受训者后落地的训练协作回归 |
| `tools/verify_plan_revision_single_successor.gd`、`tools/verify_plan_revision_late_failure_bound.gd` | 修订单后继队列、迟到落地失败和有界重试回归 |
| `tools/verify_plan_slot_dispatch_once.gd` | 同一计划版本同一时段短行动只派发一次 |
| `tools/verify_daily_plan_system.gd` | 24 小时计划、按声明 hour 纠正数组乱序、重复 / 缺失 / 越界小时拒绝与小时执行回归 |
| `tools/verify_plan_action_contract.py` | 后端行动种类与精确候选组合合同 |
| `tools/verify_npc_npc_dialogue_real.py`、`tools/verify_workstation_dialogue_revision_real.py` | 真实 provider 对话与工位修订验收 |

## 文档入口

| 内容 | 文件 |
|---|---|
| 完整玩法设计源 | `game_design.md` |
| Agent 规则 | `AGENTS.md` |
| 项目简报 | `docs/PROJECT_BRIEF.md` |
| 当前状态 | `docs/CURRENT_STATE.md` |
| 任务列表 | `docs/TASKS.md` |
| 技术架构 | `docs/TECH_ARCHITECTURE.md` |
| Godot 架构 | `docs/GODOT_ARCHITECTURE.md` |
| 代码规范 | `docs/CODING_RULES.md` |
| 数据结构 | `docs/DATA_SCHEMA.md` |
| AI NPC 系统 | `docs/AI_NPC_SYSTEM.md` |
| 记忆与信息节点 | `docs/MEMORY_AND_INFO_SPACE.md` |
| 经济与建筑 | `docs/ECONOMY_AND_BUILDINGS.md` |
| 战斗系统 | `docs/COMBAT_SYSTEM.md` |
| UI | `docs/UI_UX.md` |
| GM 调试面板 | `docs/GM_PANEL.md` |
| Prompt | `docs/PROMPTS.md` |
| API 成本 | `docs/API_BUDGET.md` |
| 长期记忆 | `docs/LONG_TERM_MEMORY.md` |
| 开发日志 | `docs/DEV_LOG.md` |
| 变更记录 | `docs/CHANGELOG.md` |

## Godot 模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 主场景 | `res://scenes/main/Main.tscn` | 游戏入口 |
| 驿站地图 | `res://scenes/world/Station.tscn` | 低模驿站 |
| NPC 场景 | `res://scenes/npc/NPC.tscn` | 通用 NPC 实体 |
| 敌人场景 | `res://scenes/enemy/Enemy.tscn` | 通用敌人实体 |
| 建筑场景 | `res://scenes/buildings/Building.tscn` | 通用建筑实体 |
| UI 主界面 | `res://scenes/ui/HUD.tscn` | 资源、时间、按钮 |
| 对话 UI | `res://scripts/ui/DialogPanel.gd`（节点内嵌于 `Main.tscn`） | NPC 对话 |
| 指令 UI | `res://scripts/ui/OrderPanel.gd`（节点内嵌于 `Main.tscn`） | 已入伍 NPC 自然语言指令 |
| NPC 面板 | `res://scenes/ui/NPCPanel.tscn` | 状态、装备、按钮 |
| 建筑面板 | `res://scenes/ui/BuildingPanel.tscn` | 建筑信息 |
| GM 调试面板 | `res://scripts/ui/GMPanel.gd` | 开发验证入口 |
| 公告牌交互 | `res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd` | 主厅前公告点击、预览与“通告 / 参考日程”草稿编辑、发布 |
| 商人交易系统 | `res://scripts/systems/MerchantSystem.gd`、`res://scripts/ui/MerchantPanel.gd` | 后门定时到访、资源买卖与交易事件 |
| 分阶段制造系统 | `res://scripts/systems/CraftingSystem.gd` | 铁匠铺 / 工械坊配方、项目目标、阶段推进、具体成品入库与特殊状态 |
| 真实马匹系统 | `res://scripts/systems/HorseSystem.gd` | 马匹生态、成长 / 生育、个体状态、分配、战时骑乘与马厩特殊状态 |
| 工程器械系统 | `res://scripts/systems/DefenseDeviceSystem.gd` | 围墙槽位、库存消耗、弩床 / 箭塔权威自动攻击与事件 |
| 工程器械表现 | `res://scripts/world/DefenseDevicePresenter.gd`、`res://scenes/defense_devices/DefenseDeviceView.tscn` | 低模占位、`ModelMount` 与正式模型替换契约 |
| 每日计划系统 | `res://scripts/systems/DailyPlanSystem.gd` | 正式真实 LLM 8 路并发计划、显式调试计划、按小时执行与异常重评估 |
| 游戏启动编排 | `res://scripts/systems/GameStartupSystem.gd` | 静止调试、正式循环与新手引导占位三状态开关 |
| 首次睡眠总结系统 | `res://scripts/systems/DailyReflectionSystem.gd` | 每日首次睡眠满 1 游戏小时后的第一人称日记、替换式知识图谱键值更新、短期记忆清空与深度睡眠锁 |

## Godot 当前已创建

路径：`project.godot`
用途：Godot 项目配置，当前启动场景为 `res://scenes/main/Main.tscn`，并注册 `MCPGameBridge`、`EventBus`、`GameState`、`ConfigLoader` Autoload。
依赖：Godot 4.6，`addons/godot_mcp` 自动加载配置。
当前状态：T0101 已验证可打开并运行，核心 Autoload 加载无报错。

路径：`addons/godot_mcp/`
用途：Godot MCP 编辑器插件与运行桥接，供 Codex / MCP server 查看场景、节点、资源、截图、运行状态和编辑器状态。
依赖：Node 侧 `@satelliteoflove/godot-mcp`；插件监听 `127.0.0.1:6550`。
当前状态：2026-06-17 已升级到 `4.0.1`，与本机 npm server `4.0.1` 对齐；新增/保留运行态采样、输入名解析、执行保护和网格校验相关脚本。`MCPGameBridge` 显式预加载 `mcp_runtime_state_sampler.gd`、`key_names.gd`、`joy_names.gd` 和 `mcp_exec_guard.gd`，避免换机或 `.godot` 缓存未刷新时 Autoload 解析失败。Codex MCP 已通过 `godot_project.addon_status` / `godot_editor.get_state` 复验连接正常。换环境恢复时先按 `docs/CURRENT_STATE.md` 的“换环境恢复 Godot MCP 清单”和 `docs/TASKS.md` 的 T0007 / T0009 / T0017 记录检查 server/addon/config 版本一致性和运行桥接脚本状态。

路径：`res://scenes/main/Main.tscn`
用途：最小可运行主场景，包含 `WorldRoot/Station/Ground`、`WorldRoot/Station/Buildings`、`WorldRoot/Station/NPCs`、`WorldRoot/Station/Enemies`、`WorldRoot/Station/DefenseDevices`、`WorldRoot/Station/Props`、`Systems/*`、`UI/HUD`、`UI/NPCPanel`、`UI/BuildingPanel`、`UI/DialogPanel`、`UI/OrderPanel`、`UI/NoticeBoardPanel`、`UI/MerchantPanel`、`UI/GMPanel`、`CameraRig/Camera3D`、`SunLight`。`Systems` 下已包含 `LLMBridge`、`MerchantSystem`、`CraftingSystem`、`HorseSystem` 与 `DefenseDeviceSystem`。`Buildings` 下已有主厅、宿舍、食堂、仓库、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、围墙、城门、后门等低模建筑/门墙占位；主厅前 `NoticeBoard` 已有独立点击和公告预览，但不绑定建筑定义、不具备 HP / 等级 / 工作位。`DefenseDevices` 由 presenter 生成已部署器械表现；`Props` 下已有广场、正门道路、后门道路和商人入口，商人标记在到访时段可点击；`UI/HUD` 下已有标题、天数、`HH:MM:SS` 时间/阶段、资源占位、速度按钮、暂停按钮、可触发警铃集结的警铃按钮和后端状态；`UI/NPCPanel` 和 `UI/BuildingPanel` 已接入右上角信息面板；`UI/OrderPanel` 已接入自然语言指令编辑；`UI/NoticeBoardPanel` 与 `UI/MerchantPanel` 已接入公告和交易；`UI/GMPanel` 已接入可拖动半透明 GM 调试按钮和面板；`CameraRig` 已挂载基础俯视摄像机控制。
依赖：绑定 `res://scripts/systems/TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`CraftingSystem.gd`、`HorseSystem.gd`、`MemorySystem.gd`、`MerchantSystem.gd`、`DefenseDeviceSystem.gd`、`CombatSystem.gd`、`EquipmentSystem.gd`、`LLMBridge.gd`、`DialogSystem.gd`、`DailyPlanSystem.gd`、`GameStartupSystem.gd`、`DailyReflectionSystem.gd` 作为系统脚本，绑定 `res://scripts/ui/HUD.gd`、`NoticeBoardPanel.gd`、`MerchantPanel.gd` 和 `GMPanel.gd` 作为 UI 脚本，并给主厅前公告牌绑定 `res://scripts/world/NoticeBoard.gd`、给器械表现容器绑定 `DefenseDevicePresenter.gd`，相机继续使用 `res://scripts/camera/CameraRig.gd`。
当前状态：T0403/T0409 已完成地点信息节点与进入快照；T0401 已完成基础 TimeSystem，HUD 时间以 `HH:MM:SS` 推进，速度按钮可切换 `x1` / `x2` / `x4`，暂停按钮和空格可暂停/继续，空格不触发加速；T0012 后 HUD 主栏按资源定义顺序显示非聚合资源库存，并提供装备/器械详情按钮，详情面板贴近各自按钮左下且夹在屏幕内；T1301 后 HUD 显示下一波倒计时，T1302-T1305 后 HUD 可显示主厅摧毁、无可战斗人员失败、第 5 波胜利和 NPC 结局总结，结局明细使用滚动区；T0305 已完成 NPC 工作 / 吃饭 / 睡觉最小行动闭环，并按 `game_design.md` 补齐酒窖、铁匠铺、工械坊、马厩、协助修复和协助升级的最小效果；T1506 后主厅公告牌可点击输入并显示当前广场公告；T1507 后后门商队每天 10:00-16:00 可买基础资源、卖酒并写入结构化公开事件。低模驿站、HUD 信息、建筑调试标签和 NPC 调试标签可见，可用 WASD/鼠标中键/滚轮查看驿站；T1101 后正门外地面和正门道路已扩大，`WorldRoot/Station/Enemies` 可由 CombatSystem 生成正门外低模敌人占位；T1103 后 HUD 警铃可触发入伍持武器 NPC 前往城门外防线集结，近战 / 骑兵在前、弓弩 / 骑射在后，集结 / 接敌时显示方向标记和坐骑表现；T1105 后已入伍持武器 NPC 可在 NPC 面板选择当前兵种可用战斗策略，T1105A 后战斗内避战够远时保持等待；T1106 后敌人波次开始 / 结束会写入广场公开事件并维护本场受伤、昏迷和击退统计；T1304/T1305 后包含第 5 波的战斗清敌会进入胜利结算，记录资源 / 建筑和 NPC 结局快照并停止继续刷波；建筑节点运行时具备点击区并可发出 `building_clicked`，右上角建筑面板可显示被点击建筑的基础信息、建筑状态、精确运作效率，以及按配置顺序逐项列出的具体位置名称与占用情况，并触发倒计时修复/升级；NPC 点击可发出 `npc_clicked` 并打开 NPC 面板；可通过调试接口让 NPC 直线移动到指定建筑、战斗集结世界坐标或策略移动目标，或安排工作、协助修复、协助升级、训练、吃饭、睡觉，到达后更新地点 `people_present`、写入只含行动事实的 `location_entered` / `location_exited`，并给进入者写入一次地点快照见闻；室内到室内切换会在事件与地点信息层经由广场，再进入持续行动。吃饭、睡觉、工作和训练通过 `logical_time_tick` 推进，完成后结算资源/状态并写入结构化事件。T0035/T0036 后，铁匠铺 / 工械坊按 11 个分阶段配方产出具体 `item_*` 库存，制造工作必须先选目标，一个周期提交一个阶段，建筑面板显示阶段进度并在非零进度切换目标时确认；T0037/T0038/T0056 后，马厩由 HorseSystem 维护两匹初始 60% 刚成年马与后续小马的生态、成长、拆分 HP、累积繁育概率 / 冷却、分配和战时骑乘，NPC 面板只为已入伍且有主武器者提供成年马分配；EquipmentSystem / DefenseDeviceSystem 逐件消费具体库存，四类旧聚合 id 仅兼容保留；T0903 后，训练场可通过教官位和训练位提升当前装备对应的武器熟练度 / 骑术，并让教官提升“教练”；T0904 后，工作 / 诊所 / 训练的熟练度提升同步增加经验、产生未分配技能点；T0015 后 NPC 面板把经验显示在 HP 右侧，并只在有未分配技能点时显示属性旁 `+1`，GM 可把选中 NPC 设为入伍并由玩家分配力量或智力。暂停期间 NPC 移动与行动结算停止，未开始行动保持 pending，已开始行动保持 active，恢复后继续；建筑修复和升级进度也随逻辑时间暂停/加速。未实现复杂生产平衡、正式工程器械美术或命中/格挡；T1508 部署闭环已完成。
T0035-T0038/T0056 当前补充：`Main/Systems` 已挂载 CraftingSystem 与 HorseSystem。铁匠铺 / 工械坊由 11 个分阶段配方产出具体 `item_*` 库存，建筑面板提供目标下拉、阶段进度和非零进度切换确认；马厩初始化两匹 60% 刚成年马并逐个显示基础 / 照料额外 HP、成长、繁育概率 / 冷却等生态状态，HorseSystem 处理成长、繁育、喂食、恢复、分配和 `rally` / `combat` 战时离厩。装备 / 部署已逐件消耗具体库存，旧 `weapons` / `armor` / `defense_devices` / `horse_readiness` 仅兼容保留且不得正式消耗。依赖补充：`Main.tscn` 绑定 `res://scripts/systems/CraftingSystem.gd` 与 `res://scripts/systems/HorseSystem.gd`，ActionSystem、BuildingPanel、NPCPanel、HUD、EquipmentSystem、MemorySystem、CombatSystem 和 DefenseDeviceSystem 通过窄接口消费其权威状态。
T1204A 补充：逃离 NPC 会显示头顶 `!` 和 HUD 警告，点击后先打开 NPC 面板；玩家通过【对话】按钮进入强制公开的逃离挽留对话，最多 5 轮。挽留面板打开时 CombatSystem 暂停逃离移动，未满 5 轮关闭后恢复移动且可再次打开，5 轮用完后 NPC 面板【对话】置灰。LLM / Mock 只返回留下或继续逃离意向，CombatSystem 负责停止或继续逃离；守备官给钱会减速，逃离挽留中的攻击会加速、计 1 轮、关闭面板且不请求 NPC LLM 回复，攻击昏迷只暂停逃离并在复苏后继续。
T1001-T1003/T0022 补充：`Main.tscn` 已挂载 `DailyPlanSystem`，规则计划只作为显式调试；正式开局和新一天的 `/npc/plan_day` 使用真实 provider 、8 路并发和 `llm_plan_day` 来源，失败不使用 Mock 或规则降级。行动异常 / 指令变化后的计划重评估仍是独立修订链路。
T0019 补充：`Main.tscn` 已挂载 `GameStartupSystem`。默认正式模式会暂停时间，让 8 名 NPC 在第 1 天 06:00 记录起床并进入“制定计划”；全部 24 小时计划完成后才统一执行当前项并恢复时间。静止调试模式不生成计划，新手引导模式当前只保留占位快照。
T1004/T1005/T1405 补充：`Main.tscn` 已挂载 `DailyReflectionSystem`，NPC 每天首次睡觉并持续睡眠满 1 游戏小时后会生成首次睡眠总结，增量追加长期日记、按 `subject + relation` 替换式更新知识图谱当前键值，并清空该 NPC 当天短期事件/见闻索引；总结请求和应用期间 NPC 进入不可打断的深度睡眠锁。

T0043 覆盖上段主场景中的旧分组显示口径：BuildingPanel 现在按配置顺序逐位置显示“名称：空闲 / 姓名占用中”；Main 的既有 BuildingSystem、NPCSystem、ActionSystem、MemorySystem 和 LLMBridge 共同承担升级封闭、自动占位、团队效率和资格 / 可用性候选上下文，无需新增权威系统节点。

路径：`res://scenes/world/`, `res://scenes/npc/`, `res://scenes/enemy/`, `res://scenes/buildings/`, `res://scenes/ui/`
用途：后续世界、NPC、敌人、建筑和 UI 场景目录。
依赖：暂无。
当前状态：目录已创建，具体场景待后续任务实现。

路径：`res://scripts/core/`, `res://scripts/systems/`
用途：后续核心单例与系统脚本目录。
依赖：暂无。
当前状态：T0101 已创建核心 Autoload 脚本与部分系统占位脚本。

路径：`res://scripts/core/EventBus.gd`
用途：全局事件总线，声明基础跨系统信号。
依赖：作为 Autoload 注册于 `project.godot`。
当前状态：T0703 后已包含资源、时间、建筑、NPC、记忆与地点信号，以及 `recruitment_changed`、`npc_order_changed`、`npc_plan_reevaluation_requested`；`DailyPlanSystem` 监听指令变化、行动失败和对话结束等统一计划重评估请求。T1302 后新增 `game_over_changed(result, reason)`，用于主厅失败等结算状态广播。T0028 新增 `npc_dialogue_bubble_clicked(npc_id, dialogue_id)`，只转发 3D 自主对话气泡点击给旁听 UI。

路径：`res://scripts/core/GameState.gd`
用途：全局运行状态，保存当前天数、小时、分钟、秒和是否处于战斗中。
依赖：作为 Autoload 注册于 `project.godot`；需要广播时通过 `/root/EventBus` 查找事件总线。
当前状态：T0101 已创建；保存当前天、时、分、秒和战斗状态。T1102 新增 `game_over`、`game_result`、`failure_reason` 和 `set_game_over(...)`；T1302 后会记录 `game_over_day/hour/minute/second` 并通过 `EventBus.game_over_changed` 广播主厅被摧毁后的失败状态，供 TimeSystem 停止推进和 HUD 显示失败界面。T1304 后新增通用 `game_over_reason` 与 `settlement_snapshot`；失败仍写 `failure_reason`，胜利写 `game_result="victory"`、`game_over_reason="five_waves_survived"` 并保存资源 / 建筑 / NPC 结算快照。T1305 后 `set_game_over(...)` 会规范化胜负 `settlement_snapshot` 并补齐 NPC 结局明细，包括最终状态、入伍状态、最后位置、Mock 最终看法、Mock 后续命运和记忆依据。

路径：`res://scripts/core/ConfigLoader.gd`
用途：统一 JSON 配置读取入口。
依赖：作为 Autoload 注册于 `project.godot`；使用 Godot `FileAccess` 和 `JSON`。
当前状态：T0101 已创建；文件缺失、打开失败、解析失败时会 `push_error` 并返回默认值。

路径：`res://scripts/systems/TimeSystem.gd`
用途：基础逻辑时间系统，负责 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速和数值倍率出口。
依赖：读取 `/root/GameState`，通过 `/root/EventBus.time_changed`、`time_scale_changed`、`logical_time_tick`、`hour_started` 与 `day_started` 广播时间变化；监听 `/root/EventBus.game_over_changed` 在失败 / 结算时暂停；由 `HUD.gd` 的 `SpeedButton` 调用 `cycle_speed()`，由 `PauseButton` 和空格调用 `toggle_paused()`；后续 LLMBridge / DialogSystem 调用 `request_time_slowdown(...)` 与 `release_time_slowdown(...)`。
当前状态：T0401 已实现；默认现实 1 秒 = 游戏内 1 分钟，HUD 显示 `HH:MM:SS` 并随游戏秒刷新，支持 `x1` / `x2` / `x4` 速度切换和独立暂停/继续；空格只切换暂停，不改变速度倍率；已提供 LLM 等待时 `1/60` 有效逻辑倍率与 `get_numeric_delta_multiplier()` / `get_game_delta_seconds(...)` 接口；T0020 后对话、常规每日计划、计划修订、低血量心理判定和首次睡眠总结均接入慢速申请 / 释放，T0019 后正式开局的批量每日计划改由 `GameStartupSystem` 直接 `set_paused(true)`，整批完成后恢复，不为每个请求重复登记慢速；T1104A 新增 `request_time_scale_cap(...)` / `release_time_scale_cap(...)` / `get_time_scale_snapshot()`，CombatSystem 可在敌人在场时注册 `combat_enemy_presence` 上限，把有效倍率最高压到 `x1`；T1406 后 `get_time_scale_snapshot()` 暴露 `last_time_scale_reason`，供 GM / LLMBridge 调试当前有效倍率和最近慢速 / 上限原因；T1104B 后战斗攻速由 CombatSystem 内部把游戏秒折算为战斗动作秒，TimeSystem 不承担攻速倍率结算；T1302 后 `GameState.game_over` 为真时不再推进逻辑时间。

路径：`res://scripts/systems/ResourceSystem.gd`
用途：基础资源与具体物品库存事实源。
依赖：通过 `/root/ConfigLoader` 读取 `data/resource_defs.json`，通过 `/root/EventBus.resource_changed` 广播资源变化，供 HUD 刷新。
当前状态：T0202 已实现基础资源读写；T0036 后同一接口权威保存剑盾、长杆、弓、弩、四个盔甲部位、箭束、弩床和箭塔 11 种具体 `item_*` 库存。`weapons` / `armor` / `defense_devices` / `horse_readiness` 仅为旧测试 / 存档兼容项，定义标记 `deprecated=true`、`formal_consumption_allowed=false` 且正式 HUD 隐藏；EquipmentSystem、DefenseDeviceSystem 与 CraftingSystem 不再把它们用于正式结算。

路径：`res://scripts/systems/BuildingSystem.gd`
用途：基础建筑系统，负责建筑配置读取、场景节点绑定、点击识别和基础状态查询。
依赖：通过 `/root/ConfigLoader` 读取 `data/building_defs.json`，绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，并通过 `/root/EventBus.building_clicked` 广播点击选择、通过 `/root/EventBus.building_state_changed` 广播状态刷新。
当前状态：T0304 已实现基础建筑数据读取、场景节点绑定、运行时点击区、调试标签状态显示、`get_building(...)` 等查询接口、建筑入口坐标查询 `get_building_entry_position(...)`、地点当前状态占位 `get_building_location_context(...)` 和最小修复/升级逻辑；2026-05-20 已补充 `_unhandled_input` 相机射线拾取，真实鼠标点击建筑可稳定触发 `building_clicked`。T0006 后建筑受损、修复进度、协助者变化、修复完成和升级只触发 `building_state_changed`，不再伪装为建筑点击。T0801 新增 `claim_workstation(...)` / `release_workstation(...)`，作为工作位占用和释放的权威接口；工位变化仍通过 `building_state_changed` 交给 MemorySystem 广播地点内部状态差量。修复/升级消耗由 `ResourceSystem` 结算，资源不足时不会改变建筑状态；修复和升级都会创建随 `logical_time_tick` 推进的倒计时作业，并可被多个 NPC 按工程熟练度协助加速；建筑受损、正在修复或正在升级时不能开始升级，只有完好建筑可升级；协助者离开对应建筑或被改派时会从作业中移除；T1102 新增 `apply_damage_to_building(...)` 供 CombatSystem 结算敌方建筑伤害，并写入 `building_damaged` 结构化事件；建筑/地点节点后续只保存当前状态并负责广播，不保存事件历史。 T0035/T0037 后新增 `get_building_special_state(...)`、`get_building_special_state_section(...)`、`set_building_special_state_section(...)`，作为 CraftingSystem / HorseSystem 写入内部特殊状态的唯一建筑接口；BuildingSystem 不自行结算制造或马匹生态。

T0043 补充：BuildingSystem 现在还权威维护逐位置 `id/type/name/occupied_by/status`、统一可进入 / 可用状态、受损效率、固定位置类型与 `upgrade.level_effects`。升级可配置成本、时长、Max HP、位置和效率增量；施工期间封闭建筑、拒绝占位并清退使用者，完成后一次应用奖励。`claim_workstation(...)` 仍由程序自动分配同类型第一个空位。

路径：`res://scripts/systems/NPCSystem.gd`
用途：基础 NPC 系统，负责读取 NPC 档案、生成 NPC 占位实体和转发 NPC 点击事件。
依赖：通过 `/root/ConfigLoader` 读取 `data/npc_profiles.json`，实例化 `res://scenes/npc/NPC.tscn` 到 `Main/WorldRoot/Station/NPCs`，并通过 `/root/EventBus.npc_clicked` 广播点击事件。
当前状态：T0403/T0409 后，移动到达会通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present` 并写入进入快照；室内信息地点切换到另一个室内信息地点时，会在事件与地点信息层插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链，物理表现仍是直线移动占位。T0501/T0502/T0503 已实现 HP 扣除、昏迷恢复和协助治疗；T0808 已实现诊所病床治疗和研读医术。T0702 新增征召权威更新入口；T0703 新增 `get_current_order(...)`、`publish_npc_order(...)` 和最近计划重评估请求快照，只有已入伍 NPC 的指令文本变化时才写入私有事件并发出请求。T1001 新增 `get_npc_plan(...)` / `set_npc_plan(...)` 和 `stop_npc_movement_for_system(...)`，供每日计划系统保存计划并在小时计划切换时安全中断移动。T1004 新增 `get_npc_long_memory(...)` 与 `apply_daily_reflection(...)`，用于写入长期日记并合并知识图谱更新；T1405 后知识图谱更新为替换式键值结构，不再写 append-only `patches`。T0704 新增 `give_money_to_npc(...)`；T0013 后旧占位武器兼容入口已移除，正式装备统一通过 T0901 `EquipmentSystem`。T0901 新增 `get_npc_equipment(...)` / `set_npc_equipment_slot(...)`，NPCSystem 只负责保存装备槽和刷新 NPC 状态，不负责库存扣除或兵种判定；T1103C 起，如果避战中的已入伍 NPC 获得主武器，会交给 CombatSystem 按当前敌军分流到战斗。T0904 新增 `increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，统一熟练度经验、未分配技能点和玩家分配力量 / 智力。T0705 新增 `debug_start_proactive_talk(...)`、`get_proactive_talk(...)` 和 `handle_npc_clicked(...)`，可让 NPC 进入主动找守备官交涉状态、显示问号气泡、点击后打开既有对话面板，并在超时或对话结束后请求计划重评估。T1204A 后，`handle_npc_clicked(...)` 对正在逃离的 NPC 返回未接管，让点击路径打开 NPC 面板而不是直接进入挽留对话；NPCPanel 再通过【对话】按钮进入逃离挽留。T1102 新增只读 `get_npc_world_position(...)` 供 CombatSystem 做附近单位目标选择；敌人对 NPC 的伤害复用既有 `apply_damage_to_npc(...)` 昏迷链路。T1202 后，`apply_damage_to_npc(...)` 的权威扣血结果会延迟通知 CombatSystem 进行战时低血量判定。T1103 新增 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 将入伍持武器 NPC 移动到城门外集结点或暂停逃离挽留移动。T1103A 新增 `set_npc_behavior_mode(...)`、`get_npc_behavior_mode_snapshot(...)`、`debug_get_behavior_mode_snapshot(...)` 和睡觉判定接口，统一保存 `behavior_mode`、进入原因和进入时间，并继续兼容 `combat_mode`。T1103B/T1103C 后，避战快照包含 `avoidance_target_id` / `avoidance_target_name` / `avoidance_target_position`，`set_npc_recruited(...)` 会在 NPC 避战中应征成功时交给 CombatSystem 分流：无主武器继续避战，有主武器且仍有敌军进入 `combat`，无敌军回到 `work`。T1105 后，NPCSystem 运行时状态会保存 `states.combat_strategy` 和 `combat_strategy_move_target_*` 策略移动目标，并在行为模式快照中暴露这些字段。T1204A 后，守备官给钱或攻击逃离 NPC 会通知 CombatSystem 调整逃离速度，逃离挽留攻击不触发 NPC LLM 回复，攻击导致昏迷时逃离暂停并在复苏后继续。模式切换可强制中断普通行动、移动、可取消 LLM 和当前对话；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 不写入 `npc_mode_changed`，其他需要留痕的模式变化仍可记录。仍不实现复杂避障。

路径：`res://scripts/systems/EquipmentSystem.gd`
用途：正式装备系统，负责具体武器 / 盔甲库存与 NPC 装备槽交换、真实马匹分配桥接和兵种判定。
依赖：读取 `data/weapon_defs.json`、`data/armor_defs.json` 和 `data/mount_defs.json`；调用 ResourceSystem 逐件结算定义中的 `source_resource_id`，调用 NPCSystem 写入槽位，调用 HorseSystem 分配 / 取消真实马匹，并通过 MemorySystem 写入 `equipment_given` / `equipment_changed`。
当前状态：T0036 后主武器与四个盔甲部位只消耗各自具体 `item_*`，换装先消耗新物品再返还旧物品，卸装返还原物品；旧聚合库存不参与。T0038 后坐骑公开入口委托 HorseSystem，`equipment.mount` 只保存 `horse_id` / `horse_name` 和通用骑乘参数的兼容投影；收回主武器会自动取消马匹分配。T0031 的艾达故事初始剑盾仍不扣库存、不写守备官赠送事件。兵种、战斗数值读取和策略归一化继续沿用既有 T0902/T1103-T1105 接口；EquipmentSystem 不结算马匹生态、耐久、完整外观或战斗伤害。

路径：`res://scripts/systems/CraftingSystem.gd`
用途：铁匠铺 / 工械坊制造项目、配方阶段和具体成品入库的唯一权威。
依赖：读取 `data/crafting_recipes.json`；调用 ResourceSystem 结算阶段材料 / 成品，调用 BuildingSystem 写入 `special_state.production`，由 ActionSystem 提交周期进度 / 阶段完成，由 BuildingPanel 提交目标选择并只读显示。
当前状态：T0035 已实现 11 个冻结配方、未选目标阻止工作、1 个工作周期完成 1 个阶段、中断只清除当前周期小数进度、已提交阶段保留、切换目标中断制造并清零原项目、非零进度需要确认、全部阶段完成后对应 `item_*` 入库并从同一项目第 1 阶段继续。对 NPC 信息空间只发布目标与整数阶段，不发布小数进度。

路径：`res://scripts/systems/HorseSystem.gd`
用途：真实马匹个体生态、马厩数量、成长 / 生育、分配与战时骑乘的唯一权威。
依赖：读取 `data/horse_defs.json`；监听 TimeSystem / NPC 状态，读取 ActionSystem 的 active `work_stable` 养马人，调用 ResourceSystem 结算进食粮食、BuildingSystem 写入 `special_state.horses`、EquipmentSystem 同步坐骑投影。
当前状态：T0056 后栗风、灰鬃以 60% 成长刚成年开局；每匹马独立保存总 HP、可派生展示的基础 HP、照料额外 HP / 上限、饱食、成长、繁育概率 / 冷却、进食、位置、分配和骑乘。马厩内可进食且慢速掉饱食，离厩加速消耗且不能进食；受损后消耗饱食缓慢恢复到自然上限。有效养马人按养马能力推进成长、照料额外 HP 和逐马繁育概率；至少两匹不在冷却的成年在厩马才累积并判定，每多一匹成年候选每分钟多一次判定，成功后候选归零并冷却 1 游戏日。成年、未分配、物理在厩的马可分配给已入伍且有主武器 NPC；日常仍在厩，`rally` / `combat` 时离厩，结束 / 昏迷回厩，失去资格或逃离自动解除。

路径：`res://scripts/npc/NPC.gd`
用途：通用 NPC 占位实体脚本，保存 `npc_id` 和档案快照，刷新短姓名/HP/当前行动标签，并处理点击。
依赖：绑定到 `res://scenes/npc/NPC.tscn`，通过 `/root/EventBus.npc_clicked` 发出点击事件。
当前状态：T0304 已创建；普通点击 NPC 会打印 ID 并发出 `npc_clicked(npc_id)`；头顶标签只显示短姓名、HP 和当前行动摘要；T0705 后若 NPC 有主动交涉状态，点击会优先交给 `NPCSystem.handle_npc_clicked(...)` 打开对话，不再先弹出 NPC 面板，并在运行时显示 `ProactiveTalkBubble` 问号气泡；T0028/T0029 后受邀者接受自主 NPC-NPC 会话后，双方运行时才显示浅色 `AutonomousDialogueBubble` 三点气泡与独立点击区；点击只发出带 `dialogue_id` 的旁听请求，结束 / 失败 / 中断后隐藏并禁用点击。邀请等待 / 拒绝阶段不显示正式对话气泡，已接受的自主对话期间气泡替代重复的通用三点 LLM 标记。T1103 后运行时创建 `CombatMountVisual` 和 `CombatFacingMarker`，T1103A 起优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结/接敌方向标记，兼容旧 `combat_mode`，且只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动中的 NPC 头顶行动摘要显示“战术移动”；T1204A 后逃离中的 NPC 头顶显示 `!` 警告标记，行动摘要显示“逃离”，逃离移动会读取 `escape_intent.speed_multiplier`；支持 `move_to_location(...)` 直线移动，到达后发出 `movement_arrived` 给 `NPCSystem` 写回地点状态。

路径：`res://scenes/npc/NPC.tscn`
用途：通用 NPC 低模占位场景。
依赖：绑定 `res://scripts/npc/NPC.gd`，由 `NPCSystem` 实例化。
当前状态：T0303 已创建；当前包含 `Area3D` 点击区、低模胶囊身体、头部和 `Label3D` 短姓名/HP/当前行动调试标签。T0705 后问号气泡由 `NPC.gd` 运行时创建，T1204A 后逃离警告 `!` 标记也由 `NPC.gd` 运行时创建，不需要手改场景资源。

路径：`res://scripts/systems/MemorySystem.gd`
用途：事件、见闻与地点/广场信息节点系统。
依赖：由 ActionSystem、NPCSystem、DialogSystem、CombatSystem、BuildingSystem 等系统写入事件；读取 GameState / TimeSystem 的游戏时间；通过 EventBus 广播 `event_recorded`、`npc_memory_changed`、`location_info_changed` 和 `public_event_added`。
当前状态：T0405 已实现 NPC 短期记忆容器查询；支持 `get_npc_short_term_memory(...)`、`get_npc_short_term_memory_ids(...)`、`clear_npc_short_term_memory(...)`、`record_player_interaction(...)`、`debug_record_player_money_given(...)`、`debug_record_player_attack_npc(...)`、`debug_get_npc_witness_events(...)`、`debug_get_npc_short_term_memory(...)` 和 `debug_clear_npc_short_term_memory(...)`。T0404/T0408/T0409 已实现广场信息即时广播并统一为 `location_id == "plaza"` 的 `local_public`；支持 `move_npc_between_locations(...)`、`get_location_snapshot(...)`、`get_location_people_present(...)`、`is_enterable_location(...)`、`set_plaza_notice(...)`、`broadcast_plaza_event(...)`、`broadcast_plaza_state_change(...)`、`notify_key_entity_state_changed(...)` 及对应调试接口。MemorySystem 监听 `building_state_changed`：任一建筑可传播外部状态会同步进广场 `building_external_states` / `key_entities` 并生成带具体建筑名和具体事实的 `plaza_status_changed`；可进入建筑的外部或内部可传播状态会生成 `location_status_changed` 本地见闻。可传播外部状态计算等级、`condition`、`is_enterable` 与 `operational_efficiency` 分档；精确 HP、精确效率和剩余修复/升级时长不触发广播。广场和可进入建筑进入快照都会生成 `people_statuses`，把当前在场 NPC 的生命状态写为健康/受伤/昏迷，昏迷时可列出治疗者，并把 `current_action` 翻译成精简中文；T1103 后行动状态摘要会把集结 / 接敌状态显示为“前往城门外防线 / 在城门外集结 / 准备接敌”，T1105 后会把策略移动显示为“进行战术移动”，T1203/T1204A 后会把逃离显示为“正朝后门逃离 / 已离开驿站”；可进入建筑还会提供逐位置 `id/type/name/occupied_by/status`，位置按 ID 比较，新增、移除、改名、改类型和占用变化会触发本地差量见闻。NPC 进入广场会获得当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑会获得该建筑外部 + 内部状态。T0407 已实现：`location_entered` / `location_exited` 事件库只保留进出行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化改为字段级差量见闻。T0402 已升级为结构化事件事实源；支持 `add_event(...)`、`get_event_log()` / `get_all_events()`、`get_npc_daily_events(...)`、`get_npc_witness_events(...)`、`get_plaza_events(...)`、`add_witness_event(...)` 和调试查询接口。T0502A 后，`add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，复苏后自动恢复。事件会规范化为包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload` 的结构，并首先写入对应 NPC 当天事件库；`local_public` 会转发给事件地点当前在场且未昏迷 NPC 的见闻库，广场事件通过同一机制转发给广场当前在场且未昏迷 NPC 并可被广场查询返回。玩家非对话交互写入时 actor id 使用 `guard_officer`，summary 使用“守备官”。T0705/T0051 后，主动交涉发起仍写 `proactive_talk_started`，预设开场问题随完成会话的单条 `dialogue_turn` 入库；`proactive_talk_message` 仅作旧事件兼容。守备官-NPC 对话取消不写事件或见闻，NPC-NPC 仍按完成轮次写入。T1103 新增 `combat_alarm_rang`、`combat_rally_started` 和 `combat_rally_encountered_enemy` 事件模板，记录听到警铃、前往城门外集结和集结途中接敌；T1105 新增 `combat_strategy_selected`，记录守备官为入伍持武器 NPC 设置当前战斗策略；T1202 新增 / 完善 `low_hp_triggered`、`battle_psychology_result` 和低血来源的 `morale_boost_started` 摘要，支持“继续参战 / 继续避战 / 逃离 / 斗志激昂”的公开事件表达；T1203 新增 `escape_started` / `escaped` 摘要；T1204A 新增 `escape_intervention_result` 与 `escape_speed_changed` 摘要，记录挽留后留下 / 继续逃离和给钱 / 攻击造成的逃离速度变化。公告变更写入 `plaza_notice_changed`，建筑状态变更写入 `plaza_status_changed` 或 `location_status_changed`。MemorySystem 不提供按地点查询事件的长期接口，地点/广场节点也不保存事件历史；T1004/T1005 首次睡眠总结只清空指定 NPC 的当天事件/见闻索引，不删除全局事件档案。T0035/T0037 后增加建筑内部特殊状态白名单：铁匠铺 / 工械坊只保留 `production.target_item_id`、`target_name`、`completed_stages`、`total_stages`、`current_stage_index`、`current_stage_name`；马厩只保留物理在厩 `horses.total`、`adult`、`foal`。进入者通过一次地点快照获得完整白名单状态，后续只给当时仍在该建筑且可接收的 NPC 写字段级 `location_status_changed` 差量；不广播到广场，不传播制造小数进度或马匹个体详情。

T0043 当前口径：精确 HP、精确效率和剩余时长仍不传播；外部传播 `condition / is_enterable / operational_efficiency` 分档，室内逐位置状态按 ID 比较并传播新增、移除、改名、改类型和占用变化。

路径：`res://scripts/systems/MerchantSystem.gd`
用途：后门商人到访和交易权威系统。
依赖：读取 `data/merchant_defs.json`；监听 EventBus 时间信号；调用 ResourceSystem 结算；调用 MemorySystem 广播结构化事件；控制 `MerchantEntranceMarker` 点击区和显示。
当前状态：T1507 已实现每日配置时段到访、粮食/木材/石料/铁买入与酒卖出。成功交易记录方向、资源、数量、单价、总价和资源/金钱差量；商人未到、数量非法、报价不存在、余额或库存不足时不改变资源且不记录成功事件。

路径：`res://scripts/systems/DefenseDeviceSystem.gd`
用途：权威维护工程器械定义、围墙槽位、部署运行态、库存消耗、弩床 / 箭塔自动攻击和结构化事件。
依赖：读取 ConfigLoader、ResourceSystem、BuildingSystem、CombatSystem、MemorySystem 与 TimeSystem；不依赖 NPCSystem 或表现节点。
当前状态：T1508 修订后已绑定 `Main/Systems/DefenseDeviceSystem`；T0036 后弩床只消耗 `item_wall_ballista`，箭塔只消耗 `item_wall_arrow_tower`，旧 `defense_devices` 不参与正式部署。`deploy_device(device_id, slot_id)` 不需要部署者，失败部署无资源副作用。

路径：`res://scripts/systems/ActionSystem.gd`
用途：日常行动权威系统，负责工作、吃饭、睡觉、训练、诊所、祈祷、地点拜访、NPC-NPC 对话接近，以及带目标协助行动的移动、占位、结算、中断和失败事实。
依赖：通过 `/root/ConfigLoader` 读取 `data/action_defs.json`，调用 `NPCSystem` 移动与状态接口、`ResourceSystem` 资源结算接口，并写入 `MemorySystem` 结构化事件。
当前状态：T0402 已在 T0305 工作 / 吃饭 / 睡觉最小行动闭环上接入结构化事件；提供 `debug_assign_work(...)`、`debug_assign_repair_assist(...)`、`debug_assign_upgrade_assist(...)`、`debug_assign_heal_assist(...)`、`debug_assign_eat(...)`、`debug_assign_sleep(...)`、`debug_assign_action(...)` 和只读 `get_healing_helpers_for_target(...)`。T1001 新增 `get_pending_action_id(...)`、`get_active_action_id(...)`、`get_runtime_action_id(...)` 和 `interrupt_npc_action(...)`，供计划系统判断与中断行动。T0801 后，工作支持真实位置占用/释放和统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；T0803 后，配置了 `output_scaling` 的工作可按熟练度、属性和建筑等级提高实际产出，当前菜园产粮使用该规则。T0035 后，`work_blacksmith` / `work_workshop` 要求制造目标，调用 CraftingSystem 校验项目 revision / 阶段材料、同步当前周期进度并在完整周期结束时提交一个阶段；中断或切换目标会清除未完成周期，已提交阶段由 CraftingSystem 保留。T0037 后，`work_stable` 不再产出匿名库存，其 active 状态供 HorseSystem 选择有效养马人并按养马能力推进马匹成长 / 生育。训练场使用 `training_instructor_station` 教官位和 `training_practice_slot` 训练位：无武器且无坐骑不能当教官或受训者；受训者需要至少一名在岗教官；全部在岗教官按人数和技能形成团队贡献，统一提高全部在位受训者的效率。诊所同样由全部 `clinic_doctor_station` 在岗人员按医术形成团队贡献，提高所有 `clinic_patient_bed` 占用者的恢复效率。当前工作支持菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺 / 工械坊推进具体制造项目，以及马厩养马人照料真实马匹。建筑修复和升级由 `BuildingSystem` 创建倒计时作业，NPC 行动只负责在广场协助正在进行的修复/升级并加速倒计时。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者会前往目标所在信息地点，最多 2 人协助同一目标，按医术熟练度调用 `NPCSystem` 加速昏迷恢复，并按逻辑时间消耗第纳尔。工作、训练、吃饭、睡觉会以 `local_public` 写入事件，让同地点当前在场 NPC 收到见闻；协助修复/协助升级同样以 `local_public` 写入 `repair_assist_started` / `upgrade_assist_started`，事件地点为 `plaza`；协助治疗写入 `healing_started` / `healing_completed`，进入治疗者和目标事件库，并写入同地点其他在场 NPC 的见闻库，事件信息不暴露医术熟练度。T0401 暂停语义修正后，暂停期间不会执行行动结算；吃饭、睡觉、工作和训练到达地点后进入 active 行动并随 `logical_time_tick` 推进。行动系统自身不实现 LLM 日程、战斗、器械部署或其他职业特殊生产平衡；T1508 部署由独立 DefenseDeviceSystem 负责。T0025 后新增 `assign_npc_dialogue(...)`、祈祷与地点拜访执行，`get_runtime_action_snapshot(...)` 暴露 pending/active 的 action、target、location、耗时和实际位置；治疗中途缺钱或离开地点写 `healing_failed`，不再伪装完成。对话接近会预定双方，开始前打断普通工作并释放位置；吃饭、睡觉、祈祷、弥撒、诊疗和训练都会自动申请同类型空位，满位或建筑封闭时返回结构化失败并触发计划重估。普通祈祷不依赖神父；`lead_mass` 对所有 NPC 可见，但只有具备“主持弥撒”能力者可执行。

T0043 当前口径：训练使用 `training_instructor_station` / `training_practice_slot`，诊所使用 `clinic_doctor_station` / `clinic_patient_bed`；全部在岗教官 / 医生形成团队贡献。吃饭、睡觉、祈祷和弥撒也申请具体位置。普通祈祷始终可用，只有 `lead_mass` 需要“主持弥撒”能力；封闭、满位和摧毁失败均进入计划重估。

路径：`res://scripts/systems/DailyPlanSystem.gd`
用途：每日计划系统，负责正式真实 LLM 和显式调试用 24 小时 NPC 计划、写入计划事件，并按小时打点调用行动系统；T0049/T0050 后还负责对话 / 日常行动失败计划修改判别、精确阶段修订和其他直接受限修订。
依赖：读取 `NPCSystem` 的 NPC、熟练度和计划字段；调用 `LLMBridge.request_npc_daily_plan_async(...)`、`request_plan_revision_judgement_async(...)` / `request_npc_plan_revision_async(...)` 获取后端结果；调用 `ActionSystem` 执行计划项并安全中断旧行动；调用 `MemorySystem.add_event(...)` 写入 `wake_up` / `plan_created` / `plan_revised`。
当前状态：T1001 已实现规则计划调试、保存和按小时执行。T0025 后以 `(day, hour, plan_version, action_id, target_id, dialogue_goal)` 保证同一版本同一时段只派发一次；批量执行按教官、其他非对话、受训者、对话顺序落地。T0022 后，正式 `/npc/plan_day` 先检查非 Mock 真实 provider，默认 8 路并发，将成功项标记为 `llm_plan_day`，每名 NPC 最多尝试 3 次真实请求。开局和 `day_started` 只在整批全部成功后恢复时间并执行；否则保持暂停与 `planning_day`。T0049/T0050 后，实际对话（包括已提交攻击轮）与明确的日常计划行动失败都先请求通用判别，空 `revision_hours` 不修订，非空才通过 `/npc/revise_plan` 精确合并所选小时；指令变化、战斗结束 / 复苏和 GM 等其他来源继续直接受限修订。双目标 NPC-NPC 会话等待双方判别 / 修订终态后按依赖顺序放行，跨小时玩家对话和行动失败判别也会延迟旧计划重派到链路终态。成功项标记 `llm_plan_revision`，失败最多 3 次真实请求并保留原计划；请求日 / 小时 / 计划版本 / 对话 epoch、单后继队列和连续迟到落地失败上限共同防止旧结果覆盖与无限循环。
T0024 补充：正式批次快照新增 `max_observed_concurrent`，用于区分“配置为 8”与“实际同时在飞达到 8”；真实开局和 `day_started` 均已完成实际峰值 8 的验收。

路径：`res://scripts/systems/GameStartupSystem.gd`
用途：游戏启动编排系统，集中提供静止调试、正式循环（无新手引导）和正式循环（新手引导占位）三个启动状态。
依赖：读取 `NPCSystem.get_npc_ids()`；调用 `DailyPlanSystem.begin_new_day_planning_for_npc(...)`、异步计划批次、统一当前项执行和自动执行开关；调用 `TimeSystem.set_paused(...)`。
当前状态：T0019/T0022 已实现并挂载到 `Main/Systems/GameStartupSystem`。正式模式先暂停时间与自动执行，让 8 名 NPC 进入计划制定状态，再发起 8 路并发真实计划。收到整批成功信号并确认每人都有 24 小时 `llm_plan_day` 后，才统一执行第 1 天 06:00 项并恢复时间；失败保持暂停。静止模式不生成计划；教程模式只记录占位状态。

路径：`res://scripts/systems/DailyReflectionSystem.gd`
用途：首次睡眠总结系统，负责监听睡觉开始 / 结束和逻辑时间、在每日首次睡眠满 1 游戏小时后生成反思、写入长期日记、替换式更新知识图谱当前键值并清空当天短期记忆。
依赖：监听 `EventBus.event_recorded` 的 `sleep_started`；读取 `MemorySystem.get_npc_short_term_memory(...)`；调用 `LLMBridge.request_npc_daily_reflection_async(...)` 请求 `/npc/daily_reflection`；调用 `NPCSystem.apply_daily_reflection(...)` 写入长期记忆；调用 `MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天短期索引。
当前状态：T1004/T1005/T1405 已实现；每名 NPC 每天首次睡眠满 1 游戏小时后自动异步生成一次，发起到完成期间不可被对话、指令或行动改派打断，后端不可用时使用模板降级，知识图谱按 `subject + relation` 替换当前值，日记按条追加，GM 可通过 `debug_generate_reflection(...)` 强制触发。
T0024 补充：最多 8 路首次睡眠总结同时在飞，`get_async_reflection_snapshot()` 暴露当前活动数、实际峰值、启动 / 完成计数和逐 NPC 结果。真实 provider 成功写为 `llm_daily_reflection`，显式 Mock provider 写为 `mock_daily_reflection`；缺少来源证明或模型 fallback 不会被猜成真实成功。

路径：`res://scripts/systems/CombatSystem.gd`
用途：敌人波次读取、调试生成、目标选择、基础移动、双方基础攻击、战斗动作秒换算、不同兵种战斗策略和战斗调试快照系统，后续继续承接正式战斗流程。
依赖：通过 `/root/ConfigLoader` 读取 `data/enemy_waves.json`；在 `Main/WorldRoot/Station/Enemies` 下生成运行时敌人节点。
当前状态：T1101 已实现 5 波敌人配置读取、波次查询、`spawn_wave(...)`、`debug_spawn_wave(...)`、`debug_clear_enemies(...)` 和 `debug_get_combat_snapshot(...)`。T1301 后新增 `get_wave_schedule_snapshot()` / `debug_get_wave_schedule_snapshot()` / `debug_trigger_next_wave()`，按 TimeSystem `logical_time_tick` 与波次触发时间自动生成下一未触发波次，并记录 `triggered_wave_numbers`。生成的敌人是低模 `Area3D` 占位，保存 `enemy_id`、`wave_number`、HP、武器类型、单位类型、攻击、防御、移动速度、目标偏好和位置元数据，头顶显示名称 / HP / 单位类型标签。T1102 后，`CombatSystem` 监听 `logical_time_tick` 推进敌人目标选择、移动和敌方攻击；附近可行动 NPC 优先，否则按城门、仓库、主厅选择仍有 HP 的建筑。T1104C 后，围墙不再作为敌人攻击目标，旧配置中的 `wall` / `front_wall` 会在目标偏好规范化时过滤；城门被攻破后直接转向仓库，后续真实路径阻挡留给碰撞 / 导航任务。T1104 后，CombatSystem 会先推进 `combat` 模式入伍持武器 NPC 的基础自动攻击，再推进敌方攻击；我方攻击读取武器伤害 / 射程 / 攻击间隔、力量、熟练度、疲劳、饱食、坐骑和敌人防御，敌人 HP 清零后移除；敌人攻击 NPC 时读取 NPC 盔甲防御后复用 `NPCSystem.apply_damage_to_npc(...)`，攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)`。T1302 后，主厅清零会写入 `GameState` 失败状态、记录失败时间、广播 game-over、暂停 TimeSystem 并显示 HUD 失败占位界面；T1303 后，活动敌人在场且所有已入伍持主武器战斗人员都昏迷、逃离或正在逃离时，会写入 `failure/no_available_combatants`，并在快照中暴露 `combatant_availability`；T1304 后，包含最终波次的战斗清敌会写入 `victory/five_waves_survived`，保存资源 / 建筑 / NPC 结算快照，并在快照中暴露 `last_victory_result`。

T1104A 后，CombatSystem 不再把玩家 `x2` / `x4` 作为战斗伤害、攻速或战斗移动倍率；活动敌人存在时会通过 TimeSystem 注册 `combat_enemy_presence` `x1` 上限，清敌或最后一个敌人被移除时释放。T1104B 后，CombatSystem 把 `game_delta_seconds / 60` 折算为战斗动作秒推进攻击冷却，并在最近 AI / 我方攻击快照中暴露 `combat_seconds`；第一波敌人已按艾达持剑基准校准为低强度探路战。T1105 新增 `get_combat_strategy_options_for_unit_type(...)`、`get_npc_combat_strategy_options(...)`、`get_npc_combat_strategy(...)`、`set_npc_combat_strategy(...)` 和 `normalize_npc_combat_strategy(...)`，可按兵种提供策略选项、保存玩家手动选择、在换主武器 / 坐骑时重置默认策略，并执行主动进攻、最大化输出、保持距离射击、拉开距离冲击和战斗内避战；T1105A 后，战斗内避战只在最近敌人低于安全阈值时短步长远离，敌人已远离到阈值外时停止移动并保持 `combat_ready`。

T1103 新增 `trigger_combat_alarm(...)` / `debug_trigger_combat_alarm(...)`、`get_active_rallies(...)` 和 `get_last_alarm_result(...)`，警铃会写入全员警铃事件，并让入伍持武器 NPC 按前后排集结。T1103A 后，CombatSystem 通过 NPCSystem 的 `behavior_mode` 接口统一维护集结等待 1 小时超时、工作 / 集结 / 战斗 / 避战切换、敌军清空后的退出和昏迷复苏分流；T1103B/T1103C 后新增 `active_avoidances`、`debug_trigger_npc_avoidance(...)`、`get_active_avoidances(...)` 和避战中应征 / 装备分流，未入伍或已入伍但无主武器 NPC 会按敌方方位短步长四散移动，清敌后回到 `work` 且不请求计划重评估。T1106 后，CombatSystem 会在波次生成时写入广场 `combat_started`，在敌军全灭或 GM 清敌时写入广场 `combat_ended`，并维护本场受伤 / 昏迷 NPC、低血量判定与各 NPC 击退敌人统计；清敌时 `combat` 回 `work` 并请求计划重评估，`avoid_combat` 与未接敌 `rally` 回 `work` 且不强制重评估。

T1201 新增 `build_battlefield_context(...)` 与 `apply_wartime_dialogue_reaction(...)`，战时对话可写入 `battle_psychology_result` 和 2 游戏小时 `morale_boost` 攻击 / 移动加成。T1202 新增 `handle_npc_damage_applied(...)`、低血量判定记录、`low_hp_triggered` 事件写入、`/npc/battle_judgement` 请求应用和规则降级：参战且已入伍持主武器的 `combat` NPC 可继续参战、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战。T1203 新增 `start_npc_escape(...)` / `debug_start_npc_escape(...)` / `handle_npc_escape_completed(...)`，战时逃离意向和 GM 调试会写入 `escape_started`、移动到后门外出口，并在 NPC 离图后记录 `escaped`。T1204A/T1204B 已包含 `apply_escape_intervention_result(...)`、`get_escape_intervention_state(...)`、`pause_escape_for_dialogue(...)`、`resume_escape_after_dialogue(...)`、`handle_escape_money_given(...)`、`handle_escape_guard_attack(...)` 和 `record_escape_attack_intervention_round(...)`：逃离 NPC 最多接受 5 轮挽留，打开对话时暂停移动、关闭时恢复移动，结果只会是留下或继续逃离；给钱会降低逃离速度，逃离挽留攻击会提高逃离速度、计 1 轮并关闭面板但不请求 NPC 回复，也不写 `escape_intervention_result`，昏迷只暂停逃离并在复苏后继续前往后门。T1303 新增 `combatant_availability` 快照和无可战斗人员失败评估。T1304 新增最终波次胜利评估、胜利结算快照和结算后刷波拒绝；T1305 后胜利快照经 `GameState` 补齐 NPC 结局明细。`debug_get_combat_snapshot()` 包含行为模式快照、避战快照、逃离快照、逃离挽留轮次和速度倍率、可战斗人员可用性、战斗策略快照、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量判定结果、最近逃离结果、最近失败结果、最近胜利结果、最近模式切换结果、最近避战结果、最近我方攻击结果和 TimeSystem 倍率快照，`debug_advance_rally_wait(...)` 可供 GM / 自动化推进集结等待。当前仍不实现命中率。

路径：`res://scripts/systems/LLMBridge.gd`
用途：Godot 侧后端桥接脚本，负责请求 `/health`、`/debug/llm_usage`、`/npc/dialogue`、`/npc/plan_revision_judgement`、`/npc/plan_day`、`/npc/revise_plan`、`/npc/battle_judgement` 与 `/npc/daily_reflection`，构造 NPC 中心请求 payload，并管理 LLM 等待期间的 TimeSystem 慢速请求。
依赖：挂载到 `Main/Systems/LLMBridge`；读取 `NPCSystem`、`ActionSystem`、`MemorySystem`、`GameState` 和 `TimeSystem`；使用 Godot 原生 `HTTPClient` 请求游戏后端。
当前状态：T0604/T0604A 已实现原生 HTTP 后端桥接；T1401/T1406 提供 usage、预算和 Godot 运行态快照。T0049/T0050 后，对话、通用计划修改判别、每日计划、计划修订、低血量心理判定和首次睡眠总结六类业务均支持异步请求并发出专用完成信号；2 秒配置只保护后端连接和 health / usage 等只读短请求。开局批量计划由 GameStartupSystem 全局暂停时间，其余影响当前场景状态的请求按 payload 申请慢速，并在成功、失败、取消、连接 / 空闲错误后释放。T0053 起判别、日计划、修订和低血量心理 payload 复用包含人设 / 状态 / 指令 / 长短期记忆 / 地点的 NPCContext；判别另带权威触发事实、原计划、候选和实时条件，修订使用同一上下文、`selected_hours` 和精确 `revision_hours`。运行态快照包含逐请求 call_type 和慢速注册 / 释放审计。LLMBridge 不修改征召、资源、HP、模式或行动权威状态。

路径：`res://scripts/systems/DialogSystem.gd`
用途：Godot 侧对话会话权威入口，维护参与者、历史、公开性和轮次，调用 LLMBridge 并写入 MemorySystem。
依赖：`NPCSystem`、`LLMBridge`、`MemorySystem`、`Main/UI/DialogPanel`。
当前状态：T0701/T0702/T0051 已实现玩家-NPC 不限轮次对话及“完成 / 取消 / 挂起”生命周期。玩家消息发送即显示；完成时把完整历史作为一条 `dialogue_turn` 入库并为目标 NPC 判别，取消不入库不判别，挂起保持 `talk_to_guard_officer` 且 2 游戏小时后自动取消。攻击立即结算并锁定取消，完成时或攻击后的超时保留攻击历史；完成等待中的会话会取消迟到回复并以玩家最后一句结尾。T0029/T0030 后 NPC-NPC 仍先邀请、接受后进入无硬轮次上限的正式会话，结束标记回复先入库且不追加调用。T0049 后，邀请拒绝或正式会话结束都会为实际参与双方分别请求计划修改判别，并在任一请求发出前预注册同一会话组的派发屏障；玩家会话跨小时则把新小时派发延迟到判别链终态。空 `revision_hours` 不修订，并仅在本次对话确实打断、仍匹配原计划且行为模式允许时恢复行动；非空才把精确小时交给 DailyPlanSystem。自主会话气泡、只读旁听、主动交涉开场、战时公开对话、强制完成与逃离挽留沿用对应生命周期边界。

路径：`res://scripts/ui/DialogPanel.gd`
用途：显示 NPC 名字、对话历史、公开性、轮次、输入框、发送、完成、取消和挂起按钮，并管理可拖动标题栏与会话恢复入口。
依赖：调用 `Main/Systems/DialogSystem`。
当前状态：T0701/T0702 已创建并绑定到 `Main/UI/DialogPanel`；T0028/T0029/T0030 后可切换到自主 NPC-NPC 无硬上限会话只读旁听模式，显示双方、轮次、软性收尾、等待状态、pending 开场与历史，隐藏玩家操作；旁听关闭只隐藏本地 UI，自然结束后保留最终记录。T0049 后普通玩家对话右上角只保留“同地点公开”“提出应征”，删除“结束后重估计划” toggle。普通发送和攻击继续异步；等待中的普通消息被取消后不入库、不判别，攻击一旦提交则保留事实并在结束时进入同一判别。T1201 后战时公开性锁定开启；T1204A 后逃离挽留显示当前 / 最大 5 轮、隐藏应征并保留攻击，关闭 / 达上限 / 攻击的移动与轮次边界不变。

路径：`res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd`
用途：主厅前公告牌点击、当前公告世界预览和自由文本输入。
依赖：通过 EventBus 打开面板；面板调用 MemorySystem 的广场公告接口。公告牌不依赖 BuildingSystem。
当前状态：T1506 已绑定 `Main/WorldRoot/Station/Buildings/NoticeBoard` 与 `Main/UI/NoticeBoardPanel`；支持发布和以空文本清空，相同文本不重复广播。

路径：`res://scripts/ui/MerchantPanel.gd`
用途：商人报价、数量、驿站库存和交易结果界面。
依赖：只读 MerchantSystem / ResourceSystem 状态并提交交易请求，不自行修改库存。
当前状态：T1507 已绑定 `Main/UI/MerchantPanel`；仅在商人到访时可交易，离场会刷新为不可用。

路径：`res://scripts/world/DefenseDevicePresenter.gd`、`res://scripts/world/DefenseDeviceView.gd`、`res://scenes/defense_devices/DefenseDeviceView.tscn`
用途：把权威部署快照转换为场景表现，并响应器械 action 信号。
依赖：只读 DefenseDeviceSystem 与 EventBus；每个 view 固定包含 `ModelMount`。
当前状态：T1508 修订后已绑定 `Main/WorldRoot/Station/DefenseDevices`；当前创建弩床 / 箭塔低模占位，配置 `presentation.model_scene` 可无逻辑迁移地替换正式模型。

路径：`res://scripts/ui/HUD.gd`
用途：HUD 展示脚本，刷新标题区下方的天数、`HH:MM:SS` 时间 / 阶段、主栏资源、具体装备 / 器械详情、速度 / 暂停按钮和后端状态占位。
依赖：读取 GameState，监听时间与资源信号，从 ResourceSystem 读取定义 / 库存，从 EquipmentSystem / NPCSystem / HorseSystem 读取装备详情与真实马匹汇总。
当前状态：T0036/T0038 后按 `show_in_main_hud` 过滤主栏，旧聚合资源不显示；“装备”详情按 `detail_group` 分列具体武器、盔甲、箭束，并显示物理在厩总数 / 成年数 / 小马数和已分配马匹；“器械”详情显示弩床 / 箭塔具体库存。HUD 只读系统状态，不直接修改资源、装备、马匹或器械事实。
当前状态：T0604 后，HUD 后端状态会读取 `LLMBridge.get_last_backend_status()` 并监听 `backend_status_changed`；T0401 已接入真实时间推进、秒级时间显示、速度按钮、暂停按钮和空格暂停；速度按钮显示玩家设定倍率，空格只触发暂停/继续，不触发速度切换；LLM 等待造成的有效逻辑倍率由 TimeSystem 提供给后续调试 UI；T0012 已接入真实资源主栏去重与装备/器械详情定位；2026-05-20 已让 HUD 根节点忽略鼠标，避免全屏背板拦截建筑点击；T1103 后警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")` 触发集结；T1204A 后 HUD 会在任一 NPC 正在逃离或昏迷暂停逃离时显示“警告：某人正在逃离驿站”。

路径：`res://scripts/ui/UIInputFocusManager.gd`
用途：Main UI 层输入焦点管理脚本，统一处理 LineEdit / TextEdit 点击外部失焦。
依赖：挂载到 `Main/UI`，读取当前 GUI 焦点和鼠标悬停 Control，不参与资源、HP、事件或行动结算。
当前状态：T0704 反馈修正已创建；任意文本输入控件获得焦点后，点击输入框外任意位置会释放焦点，NPC 给钱数量框、对话输入框和指令 TextEdit 已纳入验证。

路径：`res://scripts/ui/BuildingPanel.gd`
用途：建筑信息面板脚本，展示基础建筑 / 工位 / 修复升级，以及制造项目和马匹个体状态。
依赖：监听建筑、制造和马匹状态信号；从 BuildingSystem / CraftingSystem / HorseSystem / NPCSystem 读取只读快照，只把制造目标选择交给 CraftingSystem。
当前状态：基础工位、修复 / 升级和面板互斥规则保持不变。T0035 后铁匠铺 / 工械坊显示配方下拉、当前阶段、已完成 / 总阶段、实时进度条和 active 工人；非零进度更换目标先弹 ConfirmationDialog，只有确认才清零并切换。T0037/T0044 后马厩显示“在厩 / 离厩”汇总，并逐匹显示名称、成年 / 小马、HP、自然 / 照料额外上限、饱食、成长、进食、位置和分配对象，不重复标题或骑手字段；修复 / 升级浮动提示位于 UI 覆盖层，响应式刷新不再先撑满屏幕高度。

T0043 补充：通用位置区不再按 type 聚合，而按 `building.workstations` 配置顺序逐项显示“具体位置名：空闲 / NPC 名占用中”；服务人员位置在前、承载位置在后，并显示建筑状态与精确运作效率。UI 不使用“主动 / 被动工位”术语，也不自行分配位置。

路径：`res://scripts/ui/NPCPanel.gd`
用途：NPC 信息面板脚本，监听 NPC 点击和状态变化并展示 NPC 基础状态。
依赖：监听 `/root/EventBus.npc_clicked`、`/root/EventBus.npc_state_changed` 和 `/root/EventBus.building_clicked`，从 `Main/Systems/NPCSystem` 读取 NPC 档案与状态。
T0024 补充：事件库上方改为“当前计划 / 日记 / 知识”三等分按钮，共用详情弹窗读取当前计划、增量日记和替换式知识图谱；不再在面板正文动态创建日记滚动区。
当前状态：T0405 后，`Main/UI/NPCPanel` 会显示 NPC 当天事件库和见闻库，并监听 `npc_memory_changed` 刷新；T0014 后事件库和见闻库使用固定高度滚动区，刷新后自动滚到底部但允许手动上滑查看旧事件；T0018 后点击事件库或见闻库标题 / 正文区域会打开 `NPCMemoryDetailPopup` 大号详情弹窗，T0044 起玩家详情只显示与小框一致的时间和摘要，底层结构化字段继续供系统 / GM 使用，右上角 `×` 可关闭；T0023 后事件库上方新增“当前计划”按钮，详情读取并随 `npc_daily_plan_changed` 覆盖刷新当前 24 小时计划，T0049 起事件 / 见闻详情首次打开自动滚到最底部，已打开时刷新保留玩家当前滚动位置；T1004/T1005/T0046 后，事件库上方使用“当前计划 / 日记 / 知识”三个入口，日记只显示首次睡眠反思追加的第一人称正文，不再显示独立 `memory_summary`；T0061 起知识详情只显示中文主体 / 关系 / 值，不再显示可信度或更新时间，底层字段仍供系统与 GM 使用，背景详情也不再显示固定代表性表达；名字旁仍显示“正在思考 / 正在计划下一步行动 / 正在熟睡”；T0703 后已入伍 NPC 显示可用“指令”按钮并打开 `OrderPanel`，点击“对话”或“指令”不会关闭 NPC 面板，`DialogPanel` 与 `OrderPanel` 互斥不重叠；T0704 后面板新增非对话交互区，可选择 `private` / `local_public` 可见性并给钱，给钱数量输入框紧邻“给钱”按钮；T1006 起攻击入口已移到 DialogPanel，NPCPanel 不再直接扣血；T1204A 后逃离 NPC 点击也打开 NPCPanel，【对话】按钮在剩余挽留轮次大于 0 时可进入逃离挽留，满 5 轮后置灰并提示轮次已用完；T0901 后面板可选择主武器并为已入伍 NPC 调用 `EquipmentSystem` 装备，当前装备显示会列出主武器、盔甲、坐骑和战斗定位；T1105 后“装备武器”旁运行时创建 `NPCCombatStrategySelect` 下拉框，只在已入伍且有主武器、存在当前兵种可选策略时启用，并调用 CombatSystem 设置当前战斗策略；T0044 后未入伍造成的武器 / 盔甲 / 马匹 / 策略禁用统一显示征召提示，面板刷新保留当前高度等待布局，不再闪现最大高度空框；T0015 后面板在 HP 右侧显示 `经验：当前 / 阈值`，力量 / 智力属性旁仅在有未分配技能点时显示 `+1` 按钮调用 NPCSystem 分配；T1103A 后“当前行动”行同时显示行为模式；点击建筑时会隐藏 NPC 面板。 T0036 后面板按具体 `item_*` 库存装备 / 卸下主武器和四个盔甲部位；T0038 后只有已入伍且有主武器的 NPC 可从 HorseSystem 候选中分配成年、未占用、物理在厩的马，也可取消分配。小马、未入伍 / 无主武器 NPC 不可分配；收回主武器时 HorseSystem 自动解除并清空坐骑投影。

路径：`res://scripts/ui/OrderPanel.gd`
用途：已入伍 NPC 自然语言指令撰写与发布面板。
依赖：调用 `NPCSystem.get_current_order(...)` / `publish_npc_order(...)`；内嵌于 `Main/UI/OrderPanel`。
当前状态：T0703 已实现；打开时预填当前指令，发布变化文本时显示修订结果，关闭或相同文本无副作用。

路径：`tools/verify_npc_damage_unconscious.gd`
用途：验证 T0501 NPC HP 扣除、昏迷状态、行动阻断和同地点见闻传播。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem`、`MemorySystem` 和 `NPCPanel`。
当前状态：T0501 已创建；验证致命伤害会把 HP 降到 0、设置昏迷、阻止行动和移动，并让同地点 NPC 收到 `unconscious_started` 见闻。

路径：`tools/verify_npc_unconscious_natural_recovery.gd`
用途：验证 T0502 NPC 昏迷自然恢复、自动复苏、复苏事件和复苏后行动恢复。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`NPCSystem.debug_advance_unconscious_recovery(...)`、`ActionSystem` 和 `MemorySystem`。
当前状态：T0502/T0502A 已创建；验证昏迷 NPC 每游戏小时恢复 2 HP，达到 Max HP 30% 后写入 `revived`、同地点 NPC 收到见闻，并重新允许行动指派；同时验证昏迷期间拒收见闻、复苏后重新接收见闻。

路径：`tools/verify_npc_unconscious_healing.gd`
用途：验证 T0503 NPC 昏迷协助治疗、治疗者上限、治疗消耗、医术加速、治疗事件和资源不足失败。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem.debug_assign_heal_assist(...)`、`ResourceSystem` 和 `MemorySystem`。
当前状态：T0503 已创建；验证其他 NPC 可协助治疗昏迷目标，每个目标最多 2 名治疗者，治疗会持续消耗第纳尔，高医术治疗明显快于自然恢复；治疗事件进入治疗者和目标事件库、同地点其他在场 NPC 见闻库，且不暴露医术熟练度。

路径：`res://scripts/ui/GMPanel.gd`
用途：GM 调试面板脚本，为 M1-M4 已完成但前端不易直接验证的系统能力提供可拖动按钮、命令输入框、调试按钮和结果输出。
依赖：挂载到 `Main/UI/GMPanel`；调用 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem` 和 `CombatSystem` 的已有公开接口或 `debug_*` 接口；使用顶部 `GM_ENABLED` 常量控制开发/上线显示。
当前状态：T0004 已实现；支持资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等调试入口。T1104A 后时间分组新增 TimeSystem 倍率快照，`snapshot` / `time_snapshot` 可查看玩家选择倍率、有效倍率、LLM 慢速请求和 TimeSystem 上限请求。T0014 后行动区普通行动统一通过行动下拉和“指定行动”按钮触发，不再为工作、吃饭、睡觉、训练场教官/受训者保留并列快捷按钮；协助修复、协助升级、协助治疗等需要目标参数的入口继续保留。T0703 新增发布/查看指令和查看最近计划重评估请求入口；支持 `publish_order`、`order`、`plan_request`。T0705 新增主动交涉按钮和 `start_proactive` / `proactive` 命令，调用 `NPCSystem` 调试接口触发和查看问号气泡状态。T0904 新增技能点分配按钮和 `assign_attribute <npc_id> <strength|intelligence>` 命令，调用 NPCSystem 分配力量 / 智力。T0015 新增“设为入伍”按钮和 `recruit_npc <npc_id>` 命令，调用 NPCSystem 入伍权威接口。T1101 新增“战斗 / 敌人”分组、波次下拉、生成第一波 / 所选波次、敌人快照和清空按钮，并支持 `spawn_wave [wave_number]`、`enemy_wave [wave_number]`、`enemies`、`clear_enemies`；T1301 新增“跳到下一波”按钮和 `next_wave` / `jump_wave` 命令，调用 CombatSystem 的下一未触发波次调试入口；T1102 新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令，调用 CombatSystem 推进目标选择、移动和敌方攻击；T1103 新增“警铃集结”按钮和 `alarm` / `rally` 命令，调用 CombatSystem 触发同 HUD 的集结流程；T1103B/T1103C 新增“行为模式快照”“模拟避战”“推进集结等待”按钮和 `behavior_modes` / `avoid_npc <npc_id>` / `advance_rally_wait [game_seconds]` 命令，其中 `avoid_npc` 适用于非战斗人员并会拒绝已入伍且有主武器 NPC；T1203 新增“触发逃离”按钮和 `escape_npc <npc_id>` 命令，调用 CombatSystem 正式逃离入口；T1104 后，`step_enemies` 同时推进我方基础自动攻击并在敌人快照中暴露最近我方攻击结果；T1104A 后，敌人快照会暴露 TimeSystem 上限状态；T1204A 后，敌人快照的 `active_escapes` / `last_escape_result` 可观察逃离挽留轮次、速度倍率、暂停 / 恢复、留下 / 继续结果、逃离攻击无回复和昏迷暂停 / 复苏继续状态；T1301 后敌人快照包含 `wave_schedule`；T1303 后敌人快照包含 `combatant_availability`，可观察无可战斗人员失败原因。T0012 后 GM 面板会跟随 GM 按钮位置打开和重定位，并夹在可用屏幕范围内。GMPanel 不写入新的权威结算逻辑，只转发到已有系统。

路径：`res://scripts/camera/CameraRig.gd`
用途：基础俯视摄像机控制脚本，驱动 `Main/CameraRig` 的平移和 `CameraRig/Camera3D` 的本地距离缩放。
依赖：绑定到 `res://scenes/main/Main.tscn` 的 `CameraRig`，读取键盘 WASD 按下 / 释放事件、鼠标中键拖拽和滚轮输入；查询当前 GUI 文本焦点以避免输入时平移。
当前状态：T0105 已创建并绑定；支持 X/Z 边界限制、缩放距离限制，并保持高机位俯视角；T1101 后 Z 轴正向边界扩展到可查看正门外敌人生成区。不实现角色控制或第一人称自由视角。

## Godot 脚本规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 事件总线 | `res://scripts/core/EventBus.gd` | 全局信号 |
| 游戏状态 | `res://scripts/core/GameState.gd` | 全局状态 |
| 配置加载 | `res://scripts/core/ConfigLoader.gd` | JSON 配置加载 |
| 时间系统 | `res://scripts/systems/TimeSystem.gd` | 天数、阶段、加速 |
| 资源系统 | `res://scripts/systems/ResourceSystem.gd` | 金钱、粮食等 |
| 建筑系统 | `res://scripts/systems/BuildingSystem.gd` | 建筑 HP、等级、逐位置状态、可进入性、损伤效率与升级封闭 |
| NPC 系统 | `res://scripts/systems/NPCSystem.gd` | NPC 生成与管理 |
| NPC 展示脚本 | `res://scripts/npc/NPC.gd` | NPC 占位实体、标签和点击事件 |
| 行动系统 | `res://scripts/systems/ActionSystem.gd` | 工作、吃饭、睡觉、训练 |
| 制造系统 | `res://scripts/systems/CraftingSystem.gd` | 配方目标、阶段、项目进度与具体成品入库 |
| 马匹系统 | `res://scripts/systems/HorseSystem.gd` | 马匹生态、成长 / 生育、分配与战时骑乘 |
| 对话系统 | `res://scripts/systems/DialogSystem.gd` | 与后端对话 |
| 征召系统 | `res://scripts/systems/RecruitmentSystem.gd` | 入伍状态 |
| 记忆系统 | `res://scripts/systems/MemorySystem.gd` | 事件、见闻、短期记忆 |
| 商人系统 | `res://scripts/systems/MerchantSystem.gd` | 到访时段、报价、资源买卖与交易事件 |
| 工程器械系统 | `res://scripts/systems/DefenseDeviceSystem.gd` | 器械配置、槽位、部署和自动效果 |
| 工程器械表现 | `res://scripts/world/DefenseDevicePresenter.gd`、`res://scripts/world/DefenseDeviceView.gd` | 部署快照可视化和模型替换挂点 |
| 游戏启动编排 | `res://scripts/systems/GameStartupSystem.gd` | 三状态启动与 NPC 新一天循环 |
| 战斗系统 | `res://scripts/systems/CombatSystem.gd` | 攻击、策略、波次 |
| 昏迷系统 | `res://scripts/systems/UnconsciousSystem.gd` | 昏迷、治疗、复苏 |
| LLM 桥接 | `res://scripts/systems/LLMBridge.gd` | HTTP 请求后端 |
| HUD 展示 | `res://scripts/ui/HUD.gd` | 时间、资源、按钮和后端状态占位 |
| 建筑面板 | `res://scripts/ui/BuildingPanel.gd` | 建筑状态、精确效率、逐位置占用展示与修复/升级按钮 |
| NPC 面板 | `res://scripts/ui/NPCPanel.gd` | NPC 基础状态展示与刷新 |
| 公告牌 UI | `res://scripts/world/NoticeBoard.gd`、`res://scripts/ui/NoticeBoardPanel.gd` | 公告点击、预览与“通告 / 参考日程”双 Tab 输入 |
| 商人 UI | `res://scripts/ui/MerchantPanel.gd` | 商人报价与交易请求 |
| 摄像机控制 | `res://scripts/camera/CameraRig.gd` | 俯视平移、缩放和边界限制 |

## 数据文件规划

| 内容 | 推荐路径 | 说明 |
|---|---|---|
| 资源定义 | `data/resource_defs.json` | 初始资源、显示顺序和基础分类 |
| 制造配方 | `data/crafting_recipes.json` | 铁匠铺 / 工械坊具体物品与分阶段材料 |
| 马匹定义 | `data/horse_defs.json` | 初始马匹与生态 / 成长 / 生育平衡参数 |
| 商人定义 | `data/merchant_defs.json` | 到访时段、可买卖资源和单价 |
| 工程器械定义 | `data/defense_device_defs.json` | 弩床 / 箭塔、围墙槽位、效果与表现元数据 |
| NPC 档案 | `data/npc_profiles.json` | 8 个初始 NPC |
| NPC 初始长期记忆 | `data/npc_initial_long_memory.json` | 8 人开局前日记与替换式知识图谱种子 |
| 建筑定义 | `data/building_defs.json` | 建筑 HP、逐位置、固定类型、活动效率和逐级升级效果；公告牌不在此表中 |
| 行动定义 | `data/action_defs.json` | 工作、诊疗、训练、吃饭、睡觉、祈祷、主持弥撒及其位置映射 |
| 武器定义 | `data/weapon_defs.json` | 剑盾、长杆、弓、弩 |
| 盔甲定义 | `data/armor_defs.json` | 头盔、胸甲、腕甲、腿甲 |
| 坐骑定义 | `data/mount_defs.json` | HorseSystem 同步装备槽时使用的通用骑乘参数 |
| 敌人波次 | `data/enemy_waves.json` | 5 波 Demo |
| Prompt 模板 | `data/prompts/*.txt` | 计划、对话、判定、总结 |

## 数据文件当前已创建

路径：`data/resource_defs.json`
用途：资源配置，记录资源 id、显示名、分类、初始数量、最小值和 HUD 顺序。
依赖：由 `ResourceSystem` 通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取。
当前状态：除第纳尔、粮食、餐食、酒、木材、石料、铁外，T0036 已加入剑盾、长杆武器、弓、弩、铁盔、锁子甲、铁护腕、铁护腿、箭束、弩床、箭塔 11 种具体 `crafted_item`。具体物品通过 `detail_group` 进入装备 / 器械详情，`show_in_main_hud=false` 不占主栏。`weapons` / `armor` / `defense_devices` / `horse_readiness` 仅为兼容项，已标记弃用、正式结算禁用并从 HUD 隐藏。

路径：`data/crafting_recipes.json`
用途：铁匠铺 / 工械坊具体物品配方、阶段顺序和逐阶段材料成本。
依赖：由 CraftingSystem 读取，ActionSystem 只提交工作周期，BuildingPanel 只读配方和项目快照。
当前状态：T0035 已创建 11 个冻结配方。铁匠铺含铁盔 2 阶段、铁护腕 2、长杆 3、铁护腿 3、剑盾 4、锁子甲 6；工械坊含箭束 1、弓 2、弩 4、弩床 6、箭塔 8。每个阶段单独声明材料，全部阶段完成才产出 1 件对应 `item_*`。

路径：`data/horse_defs.json`
用途：初始马匹与马匹饱食、进食、恢复、成长、生育和照料额外 HP 平衡配置。
依赖：由 HorseSystem 读取；不作为装备匿名库存或战斗伤害定义。
当前状态：T0056 后初始栗风、灰鬃成长均为 0.6；配置马厩 / 离厩饱食消耗、20% 缺口触发进食、进食周期与粮食恢复、自然 HP 恢复、幼马 / 完全成长上限、成年阈值、基础成长时长、逐分钟繁育概率增量 / 上限、1440 分钟产后冷却和养马额外 HP 上限。`stable_level_birth_bonus_per_level=0.1` 只用于繁育概率增量，即马厩每升一级 +10%，不影响成长、进食或自然恢复。

路径：`data/merchant_defs.json`
用途：配置后门商人身份、地点、每日到达/离开时间和买卖报价。
依赖：由 MerchantSystem 通过 ConfigLoader 读取。
当前状态：T1507 已创建；商人每天 10:00 到达、16:00 离开，可向驿站出售粮食/木材/石料/铁并收购酒。价格只在此配置，不写死在 UI。

路径：`data/defense_device_defs.json`
用途：工程器械与围墙部署槽配置，记录成本、建筑要求、自动攻击效果、世界坐标、射界和表现元数据。
依赖：由 DefenseDeviceSystem 通过 ConfigLoader 读取；DefenseDevicePresenter / View 只消费系统规范化快照。
当前状态：T1508 修订后包含 2 个弩床平台和 2 个箭塔位，不再包含拒马类型或槽位；T0036 后 `inventory_cost` 分别固定为 `item_wall_ballista: 1` 与 `item_wall_arrow_tower: 1`。`presentation.model_scene` 默认为空并使用低模占位，后续正式资源可直接替换。

路径：`data/building_defs.json`
用途：建筑配置，记录建筑 id、等级、HP、标签、工作位、输入输出、修复和升级规则。
依赖：由 `BuildingSystem` 通过 `ConfigLoader.load_data_file("building_defs.json")` 读取，并通过 `scene_nodes` 绑定到低模建筑实体。
当前状态：T0206 后为 15 条建筑/门墙定义，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊；所有建筑都有 `upgrade` 最小规则，既有关键建筑保留 `repair` 规则，`repair` 可配置每点缺失 HP 耗时和等级耗时系数。T0043 后不可进入建筑不保留内部位置；小教堂固定 `chapel_altar ×1 + chapel_prayer_seat ×10`，小诊所初始 `clinic_doctor_station ×1 + clinic_patient_bed ×2`，训练场初始 `training_instructor_station ×1 + training_practice_slot ×2`，食堂初始 `dining_kitchen_station ×1 + dining_seat ×10`，宿舍固定 `dormitory_bed ×10`。诊疗位、病床、教官位、训练位和灶台可按逐级配置扩容；祭坛、祈祷席、用餐席和宿舍床位固定。升级配置还可增加效率与 Max HP；公告牌仍独立于建筑定义。

路径：`data/action_defs.json`
用途：行动配置，记录行动 id、类型、地点需求、技能、耗时、资源输入输出和状态变化。
依赖：由 `ActionSystem` 读取并作为 NPC 日程与工作白名单。
当前状态：T0305 已由 `ActionSystem` 读取；包含菜园工作、食堂加工餐食、酒窖酿酒、铁匠铺制造、工械坊制造、马厩照料、小诊所医生坐诊/研读医术、小诊所病床治疗、训练场教官、训练场受训者、吃饭、睡觉和协助治疗昏迷者等最小行动定义。2026-05-25 起优先使用 `duration_seconds` 表达持续时间：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。T0803 后 `work_garden` 配置 `output_scaling`，基础产出 2 份粮食，并由耕种熟练度、力量和菜园等级提高实际产出。T0035 后 `work_blacksmith` / `work_workshop` 保留打铁 + 力量、工程 + 智力和 3600 秒基础周期，但 `input_resources` / `output_resources` 为空并设 `requires_crafting_target=true`，实际阶段材料与具体成品由 CraftingSystem 配方结算。T0037 后 `work_stable` 保留养马 + 力量和 3600 秒周期，但不再直接消耗粮食或产出 `horse_readiness`，其 active 状态作为 HorseSystem 照料资格。T0807 后 `work_tavern` 明确使用酿酒与智力，消耗 1 份粮食并产出酒派生库存，且通过 `output_scaling` 让酿酒、智力和酒窖等级提高实际产出；T1507 后酒由 MerchantSystem 在商人到访时按配置出售，酿酒行动仍不自动换钱。T0808 后 `work_clinic_doctor` 占用诊所医生工位，`receive_clinic_treatment` 占用诊所病床，二者同时满足时推进治疗并消耗第纳尔；医生无病人时缓慢研读医术。T0903 后 `work_training_instructor` 占用训练场教官工位，`receive_weapon_training` 占用训练场受训位，训练项目由 NPC 当前主武器 / 坐骑决定。T1204A 后补充 `escaping_station` 与 `escape_intervention_dialogue` 系统显示行动，用于地点快照和 UI 文案格式化，不作为普通行动下拉的可执行工作。协助治疗是需要目标 NPC 的 `targeted_heal` 行动，普通 `assign_action` 不直接执行，必须走 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`。协助修复和协助升级不在该文件中按建筑写死，而由 `ActionSystem` 作为带建筑参数的运行时行为处理。

T0043 补充：诊所 / 训练位置类型已替换为 `clinic_doctor_station`、`clinic_patient_bed`、`training_instructor_station`、`training_practice_slot`；吃饭、睡觉、普通祈祷和主持弥撒分别映射 `dining_seat`、`dormitory_bed`、`chapel_prayer_seat`、`chapel_altar`。`lead_mass` 对所有 NPC 可见但要求“主持弥撒”能力。NPC 不选择编号，满位 / 封闭失败由程序返回并触发计划重估。

路径：`data/weapon_defs.json`
用途：主武器配置，记录武器类型、装备槽、库存来源、射程、伤害、攻击间隔、技能需求和兵种分类辅助字段。
依赖：由 `EquipmentSystem` 读取；后续战斗系统可继续读取其中的数值字段。
当前状态：T0013 后只包含剑盾、长杆武器、弓和弩四类正式主武器；T0036 后 `source_resource_id` 分别为 `item_sword_shield`、`item_polearm`、`item_bow`、`item_crossbow`，不能再互换消耗聚合武器库存。不实现耐久或品质。T1104B 起 `attack_interval` 以战斗动作秒解释，CombatSystem 以 `60` 游戏秒 = `1` 战斗动作秒推进冷却。

路径：`data/armor_defs.json`
用途：盔甲配置，记录头盔、胸甲、腕甲、腿甲等装备槽、库存来源、护甲值和重量占位。
依赖：由 `EquipmentSystem` 读取。
当前状态：包含铁盔、锁子甲、铁护腕和铁护腿；T0036 后四个定义分别指向 `item_iron_helmet`、`item_mail_chest`、`item_iron_bracers`、`item_iron_greaves`，装备 / 卸装逐件结算，不再消耗可互换的 `armor` 聚合库存。

路径：`data/mount_defs.json`
用途：真实马匹同步到 NPC 坐骑槽时使用的通用骑乘参数模板。
依赖：由 EquipmentSystem 读取定义，由 HorseSystem 注入具体 `horse_id` / `horse_name` 后写入装备槽。
当前状态：T0038 后 `riding_horse` 已改名“已分配马匹”，保留速度加成、骑术需求和标签，不再声明 `source_resource_id`，也不消耗 `horse_readiness`。日常分配马仍在马厩，只有 `rally` / `combat` 显示骑乘并参与兵种判定 / 战斗策略。

路径：`data/enemy_waves.json`
用途：敌人波次配置，记录波次编号、触发时间、正门外生成点、生成位置、生成散布和敌人组数值。
依赖：由 `CombatSystem` 通过 `ConfigLoader.load_data_file("enemy_waves.json")` 读取。
当前状态：T1101 已配置 5 波 Demo 敌人，后续波次在人数、HP、攻击、防御和兵种组合上逐步增强。T1301 后每波的 `trigger_day` / `trigger_hour` 被 CombatSystem 用作自动来袭时间，当前第 1-5 波分别在第 3-7 天 18:00 触发；`trigger_minute` / `trigger_second` 未配置时默认 0。敌人组包含 `enemy_type_id`、`name`、`count`、`unit_type`、`weapon_type`、可选 `mount_type`、`hp`、`max_hp`、`attack_power`、`defense`、`move_speed`、`attack_range`、`attack_interval` 和 `target_preference`。T1102 起驱动敌人目标选择、移动和攻击；T1104 起 `defense` 参与敌人受击减伤，`hp` / `max_hp` 会被我方攻击扣除并在清零后移除。T1104B 起第一波劫掠剑盾手为低强度探路敌人，`attack_interval` 使用战斗动作秒。T1104C 起 `target_preference` 不包含 `wall`，敌人默认按城门、仓库、主厅推进。

路径：`data/npc_initial_long_memory.json`
用途：独立保存 8 名初始 NPC 的开局前日记和知识图谱，不与根本人设或运行时权威状态混写。
依赖：由 `NPCSystem` 与 `npc_profiles.json` 同时读取；两者 NPC id 必须完全一致，验证通过后才生成 NPC。
当前状态：T0059 已配置 8 人 × 3 篇第一人称生命切片；T0061 起前两篇分别承担宏观身世 / 来站原因与按一致时序相互拼接的到站群像，近日篇继续保留 T0060 的微观站内生活。每人图谱覆盖其余 7 人、守备官、全部 15 座配置建筑和至少 2 个个人故事主体；守备官仅保留统一 `role` 职位职责，建筑中文 `relation_label / value_label` 使用世界内叙事。为去除尚未实现的容量 / 丢货语义，8 条仓库技术 `value` 统一迁移为 `central_storage_and_post_breach_attack_target`，其余技术值不变；222 条关系记录的 `confidence / day / time` 完整保留。后续反思在运行态追加 / 替换，不回写本文件。

路径：`data/npc_profiles.json`
用途：NPC 档案配置，记录身份、性格、欲望、恐惧、底线、基础数值、状态、技能、入伍状态、装备、知识图谱和日记。
依赖：由 `NPCSystem` 通过 `ConfigLoader.load_data_file("npc_profiles.json")` 读取并生成 NPC 实体。
当前状态：T0302 已接入运行时 NPC 生成；8 名初始 NPC 的正式 Demo 短档案为托马 / 马夫、布鲁诺 / 厨子、伊沃 / 园丁、格伦 / 铁匠、艾达 / 老兵副官、马塞尔 / 神父、莉娜 / 医生、欧文 / 工程师。每名 NPC 包含基础外观、根本背景、性格、欲望、恐惧、底线、宽松职业语气、能力、状态、技能、装备、计划与空记忆占位；T0061 已移除固定代表性表达。具体开局历史和知识不在此重复，统一来自 `data/npc_initial_long_memory.json`。

路径：`data/prompts/dialogue_system_prompt.txt`
用途：`/npc/dialogue` 真实 provider 的系统 Prompt 模板，覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=dialogue` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T1402 已接入；T0061 起模板只读取宽松 `speech_style` 与其他稳定人设，从目标 NPC 的职业经验、关注点和判断习惯出发回应，不读取或模仿固定样例句。模板继续限制 `recruitment_result`、`wartime_reaction` 与逃离挽留 `intent` 的允许语义。T1501 的 mock / fake real-provider 与 8 人真实 DeepSeek 职业身份对话保留为历史验收；T0061 当前版本的静态、Prompt、Mock / endpoint、Godot 与真实 DeepSeek 复验均已完成。

路径：`data/prompts/daily_plan_system_prompt.txt`
用途：`/npc/plan_day` 真实 provider 的系统 Prompt 模板，覆盖每日 24 小时计划生成。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=plan_day` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T1403 已接入；模板要求输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` / `idle`，并明确 `current_order` 只能作为守备官当前指令参考，不能越过行动白名单、资源、HP、地点、建筑、工位或程序强制层。已通过 fake real-provider 验证和真实 DeepSeek `/npc/plan_day` smoke test。

路径：`data/prompts/plan_revision_judgement_system_prompt.txt`
用途：`/npc/plan_revision_judgement` 的范围判别系统 Prompt，根据完整本轮对话或程序权威行动失败事实、原计划和共享人物 / 记忆 / 指令上下文返回 0 个或若干个需要修改的精确小时。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=plan_revision_judgement` 时读取，并与通用 JSON / Schema guard 拼接。
当前状态：T0049/T0050 已接入；`revision_hours=[]` 明确表示不需要后续修订，非空集合必须升序、去重且不早于当前小时。失败工作阶段改为非工作且原计划处于最低工作数时，判别还需选择最少未来补偿阶段。该 Prompt 不生成新计划、不修改权威状态。

路径：`data/prompts/plan_revision_system_prompt.txt`
用途：`/npc/revise_plan` 真实 provider 的精确阶段计划修订 Prompt，只返回请求 `revision_hours` 中的小时。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=revise_plan` 时读取；后端 `backend/app.py` 在 Schema 后校验响应与请求小时集合完全一致、行动白名单、即时行动一致性和工作阶段。
当前状态：T0049 已把唯一合同改为 `revision_scope=selected_hours`；`revised_plan` 恰好覆盖 `revision_hours`，只有集合包含当前小时时才输出匹配的 `immediate_action`，否则必须为 `null`。既有完整上下文、reason / summary 长度、fake / real provider 与 Godot 异步边界继续保留。

路径：`data/prompts/battle_judgement_system_prompt.txt`
用途：`/npc/battle_judgement` 真实 provider 的系统 Prompt 模板，覆盖战时低血量自身心理判定。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=battle_judgement` 时读取，并与通用 JSON / Schema guard 拼接；后端 `backend/app.py` 会在响应 Schema 校验后继续做业务约束校验。
当前状态：T1404 已接入；模板要求引用 NPC 亲历事件、公开见闻、`battlefield_context` 和 `current_order`，但只能从请求的 `allowed_decisions` 中选择，且 `current_order` 不能强制参战或强制逃离。后端会拒绝越界 `decision` 和逃离布尔不一致结果。已通过 fake real-provider 验证和真实 DeepSeek `/npc/battle_judgement` smoke test。

路径：`data/prompts/daily_reflection_system_prompt.txt`
用途：`/npc/daily_reflection` 真实 provider 的系统 Prompt 模板，覆盖首次睡眠总结、第一人称日记和知识图谱替换式更新。
依赖：由 `backend/services/model_adapter.py` 在 `call_type=daily_reflection` 时读取，并与通用 JSON / Schema guard 拼接；后端 `backend/app.py` 会在响应 Schema 校验后继续做业务约束校验。
当前状态：T1405 已接入；模板要求区分亲历事件与见闻，输出符合 NPC 语气的 `diary_entry`，并把 `knowledge_graph_updates` 作为 `subject + relation -> value` 的当前状态更新，不能把知识图谱写成增量日记。后端会拒绝 NPC / 日期不匹配、空字段和世界内文本使用“玩家”的结果。已通过 fake real-provider 验证和真实 DeepSeek `/npc/daily_reflection` smoke test。

## 后端模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 后端入口 | `backend/app.py` | Flask/FastAPI 入口 |
| 模型适配器 | `backend/services/model_adapter.py` | DeepSeek/MiniMax 等统一接口 |
| 对话服务 | `backend/services/dialog_service.py` | NPC 对话 |
| 计划服务 | `backend/services/planning_service.py` | 每日计划 |
| 判定服务 | `backend/services/judgement_service.py` | 战斗/逃离判定 |
| 记忆服务 | `backend/services/memory_service.py` | 总结、知识图谱 |
| 成本统计 | `backend/services/budget_service.py` | token 与费用 |
| 数据模型 | `backend/schemas/*.py` | Pydantic 或 dataclass |

## 后端当前已创建

路径：`backend/app.py`
用途：Flask 后端入口，当前提供 `GET /health`、`GET /debug/llm_usage`、`POST /mock/model`，以及 `/npc/dialogue`、`/npc/plan_revision_judgement`、`/npc/plan_day`、`/npc/revise_plan`、`/npc/battle_judgement`、`/npc/daily_reflection` 六类正式业务接口；旧对话判别 URL 保留兼容。
依赖：`flask`, `python-dotenv`。
当前状态：业务接口复用同一个 `ModelAdapter` 实例保留 usage；`GET /health` 返回非敏感运行配置。所有业务先校验请求 / 响应 Schema；`/npc/plan_revision_judgement` 还校验触发类型所需事实、NPC id、`needs_revision` 与小时集合一致性及时间边界；`/npc/plan_day` 校验 24 小时覆盖、白名单和工作阶段；`/npc/revise_plan` 校验 NPC id、响应与请求 `revision_hours` 完全一致、白名单、工作阶段和即时行动一致性。六个正式 LLM 成功接口统一通过 `model_success_payload(...)` 附加 provider 元数据。不合法结果记录 `model_output_invalid`；预算超限返回 HTTP 429，生产 / Demo 默认不自动 mock fallback。

路径：`backend/requirements.txt`
用途：记录 Python 后端依赖。
依赖：至少包含 `flask`, `python-dotenv`, `pydantic`, `requests`。
当前状态：T0002 已确认可用于安装后端最小依赖。

路径：`backend/.env.example`
用途：本地 `.env` 配置模板。
依赖：无。
当前状态：默认 `LLM_PROVIDER=mock` 服务本地开发；真实 provider 配置包含 `LLM_THINKING_MODE=disabled`、温度、JSON 模式、成本和累计预算变量，不包含客户端单次输出 token 上限。真实 API Key 只放本地 `backend/.env` 或服务器环境。

路径：`backend/services/model_adapter.py`
用途：模型供应商适配器边界，后续由对话、计划、判定服务复用。
依赖：环境变量 `LLM_PROVIDER`, `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`, `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS`, `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS`, `LLM_FALLBACK_TO_MOCK`, `LLM_THINKING_MODE`、成本与累计预算变量。
当前状态：支持 mock、DeepSeek 和 OpenAI-compatible provider，生产自动 mock fallback 默认关闭。六类正式 call_type 使用流式 SSE，不发送客户端单次输出 token 上限、不设置生成总时长，并在 JSON 为空、截断或非法时按业务紧凑重试一次。`plan_revision_judgement` 与 `revise_plan` 分别读取人物上下文一致的范围判别和精确修订 Prompt；旧 dialogue call type 映射到通用 Prompt。Usage 记录 provider/model、request/NPC、token、费用、`finish_reason`、响应长度、尝试次数、HTTP / 异常、Schema / 预算错误和降级来源。

路径：`backend/schemas/common.py`
用途：后端 AI 接口共享 Schema，定义游戏时间、请求元信息、事件摘要、短期记忆、NPC 身份/状态/上下文、行动候选和通用错误响应。
依赖：`pydantic`。
当前状态：T0601 已创建；T0703A 新增 `CurrentOrderContext` 并接入共享 `NPCContext`，让所有复用该上下文的 NPC 中心请求携带最新指令。T0061 后 `NPCIdentity` 只保留宽松 `speech_style`，已删除固定 `signature_lines` 字段；Schema 只提供数据模型，不调用 LLM，也不改变游戏权威状态。

路径：`backend/schemas/npc_ai.py`
用途：NPC AI 请求/响应 Schema，覆盖玩家-NPC / NPC-NPC / 逃离挽留对话、对话 / 行动失败通用计划修改判别、每日计划、精确小时计划修订、战斗判定、首次睡眠总结、知识图谱更新、主动交涉和玩家话术分类。
依赖：`pydantic`，复用 `backend/schemas/common.py`。
当前状态：T0603 后，对话 Schema 已按当前任务重整为显式输入；T0703A 新增对话顶层 `current_order`，并让每日计划、修订、战斗判定、首次睡眠总结等通过共享 `NPCContext.current_order` 复用最新指令。T0049/T0050 定义 `PlanRevisionJudgementRequest/Response`，通过 `trigger_kind` 选择完整对话或权威行动失败事实、原计划和可为空的精确 `revision_hours`；旧 `DialoguePlanRevisionJudgement*` 名为兼容别名，`PlanRevisionRequest` 只接受 `selected_hours` 与非空精确小时。T1202 后，`BattleJudgementRequest` 包含 `combat_context`、`battlefield_context` 和 Godot 提供的 `allowed_decisions`，用于低血量自身心理判定。T1204A 后，`InteractionContext` 包含 `escape_intervention`，逃离挽留中的玩家消息可携带 `dialogue_kind="escape_intervention"` 与 `escape_intervention_round`，`NPCDialogueResponse.intent` 可表达 `stay_after_intervention` / `leave_after_intervention`；逃离挽留攻击不走对话 Schema。响应使用 `replyer_id`、`reply_text`、`response_kind`、`recruitment_result` 和 `should_end_dialogue`；战斗判定响应使用 `BattleJudgementResponse.decision` 表达允许集合内的意向。

路径：`backend/schemas/__init__.py`
用途：统一导出后端 Schema 类型。
依赖：`backend/schemas/common.py`、`backend/schemas/npc_ai.py`。
当前状态：T0601 已创建。

路径：`backend/schemas/README.md`
用途：记录后端 Schema 分组和权威边界。
依赖：无。
当前状态：T0601 已创建。

路径：`backend/services/`, `backend/data/`
用途：后端服务层和后端本地数据目录。
依赖：暂时无。
当前状态：T0002 创建目录骨架，用 `.gitkeep` 保留空目录。

## 更新规则

新增任何实际文件后，在本文件加入：

```text
路径：
用途：
依赖：
当前状态：
```
## Tools

| 内容 | 文件 |
|---|---|
| Godot MCP 连接与拓扑自检 | `tools/check_godot_mcp.ps1` |
| Godot MCP 多会话 proxy / 单 broker 拓扑验证 | `tools/verify_godot_mcp_topology.mjs` |
| 建筑修复/升级验证 | `tools/verify_building_repair_upgrade.gd` |
| 建筑面板工位显示验证 | `tools/verify_building_panel_workstations.gd` |
| 五建筑位置、资格、团队效率、升级封闭与损伤效率综合验证 | `tools/verify_building_service_positions.gd` |
| NPC 面板与状态验证 | `tools/verify_npc_panel_state.gd` |
| NPC 移动与地点验证 | `tools/verify_npc_movement_location.gd` |
| NPC 熟练度 schema 验证 | `tools/verify_npc_skill_schema.gd` |
| NPC 姓名、人设、职业语气与 LLM 上下文验证 | `tools/verify_npc_character_profiles.gd` |
| 简单行动系统验证 | `tools/verify_action_system_basic.gd` |
| 职业工作产出框架验证 | `tools/verify_work_output_framework.gd` |
| 食堂粮食加工餐食验证 | `tools/verify_dining_hall_meals.gd` |
| 菜园粮食产出验证 | `tools/verify_garden_grain_output.gd` |
| 旧 T0804-T0806 聚合生产历史回归 | `tools/verify_blacksmith_metal_gear.gd`、`tools/verify_workshop_ranged_devices.gd`、`tools/verify_stable_horse_care.gd` |
| 具体配方与分阶段制造闭环验证 | `tools/verify_crafting_pipeline.gd` |
| 真实马匹生态、分配与战时生命周期验证 | `tools/verify_horse_ecology_assignment.gd` |
| 马匹基础 / 额外 HP、初始成长、累积繁育概率、冷却与 UI 验证 | `tools/verify_horse_care_feedback.gd` |
| 酒窖酿酒与出售边界验证 | `tools/verify_tavern_wine_trade.gd` |
| 公告牌输入与广场广播验证 | `tools/verify_notice_board_input.gd` |
| 商人时段、买卖与事件验证 | `tools/verify_merchant_trade_system.gd` |
| 具体弩床 / 箭塔库存、部署、战斗效果、事件与模型挂点验证 | `tools/verify_defense_device_deployment.gd` |
| 小诊所治疗验证 | `tools/verify_clinic_treatment.gd` |
| 训练场熟练度验证 | `tools/verify_training_system.gd` |
| 熟练度经验与技能点验证 | `tools/verify_skill_progression.gd` |
| 三状态启动与正式游戏循环验证 | `tools/verify_game_startup_modes.gd` |
| 真实 8 NPC 并发开局与 `llm_plan_day` 来源验证 | `tools/verify_game_startup_real_async.gd` |
| 真实 8 NPC 并发首次睡眠总结、来源与长期记忆验证 | `tools/verify_daily_reflection_real_async.gd` |
| 正式计划拒绝 Mock provider 验证 | `tools/verify_formal_plan_real_only.gd` |
| 规则版每日计划验证 | `tools/verify_daily_plan_system.gd` |
| 真实失败不降级与显式开发 Mock 计划验证 | `tools/verify_daily_plan_llm.gd` |
| 行动异常与计划重评估验证 | `tools/verify_daily_plan_reevaluation.gd` |
| 首次睡眠总结系统验证 | `tools/verify_daily_reflection_system.gd` |
| 对话懒打断、异步取消、对话窗攻击与首次睡眠总结边界验证 | `tools/verify_dialogue_sleep_summary_boundaries.gd` |
| 后端每日计划端点验证 | `tools/verify_plan_day_endpoint.py` |
| 后端计划修订端点验证 | `tools/verify_plan_revision_endpoint.py` |
| 后端首次睡眠总结端点验证 | `tools/verify_daily_reflection_endpoint.py` |
| 具体武器 / 盔甲库存与真实马匹分配装备验证 | `tools/verify_equipment_system.gd` |
| 兵种判定验证 | `tools/verify_unit_type_classification.gd` |
| 敌人波次与生成验证 | `tools/verify_enemy_wave_generation.gd` |
| 敌人波次倒计时与自动来袭验证 | `tools/verify_enemy_wave_schedule.gd` |
| 主厅失败条件验证 | `tools/verify_main_hall_failure.gd` |
| 无可战斗人员失败验证 | `tools/verify_no_available_combatants_failure.gd` |
| 第 5 波胜利条件验证 | `tools/verify_five_wave_victory.gd` |
| 敌人目标优先级验证 | `tools/verify_enemy_target_priority.gd` |
| 基础攻击与伤害验证 | `tools/verify_combat_damage.gd` |
| 战斗时间上限验证 | `tools/verify_combat_time_cap.gd` |
| 战斗节奏验证 | `tools/verify_combat_pacing.gd` |
| 兵种战斗策略与避战距离验证 | `tools/verify_combat_strategies.gd` |
| 战斗开始 / 结束流程验证 | `tools/verify_combat_flow.gd` |
| 战时公开对话心理结果验证 | `tools/verify_wartime_dialogue.gd` |
| 低血量自身心理判定验证 | `tools/verify_low_hp_battle_judgement.gd` |
| 战场公开信息综合验证 | `tools/verify_battlefield_public_info.gd` |
| 逃离驿站行为验证 | `tools/verify_escape_station_behavior.gd` |
| 逃离挽留入口、暂停与攻击规则验证 | `tools/verify_escape_intervention_dialogue.gd` |
| 警铃与集结验证 | `tools/verify_combat_alarm_rally.gd` |
| NPC 行为模式状态机验证 | `tools/verify_behavior_mode_state_machine.gd` |
| 非战斗人员避战模式验证 | `tools/verify_avoid_combat_mode.gd` |
| HUD 具体物品分组、旧聚合隐藏与真实马匹汇总验证 | `tools/verify_hud_resources.gd` |
| 时间系统验证 | `tools/verify_time_system.gd` |
| 结构化事件底座验证 | `tools/verify_structured_memory_events.gd` |
| 地点信息节点验证 | `tools/verify_location_info_nodes.gd` |
| 广场本地公开广播验证 | `tools/verify_plaza_local_public_broadcast.gd` |
| NPC 短期记忆容器验证 | `tools/verify_npc_short_term_memory_container.gd` |
| 行动事件本地公开广播验证 | `tools/verify_action_local_public_broadcast.gd` |
| NPC 扣血与昏迷验证 | `tools/verify_npc_damage_unconscious.gd` |
| NPC 昏迷自然恢复验证 | `tools/verify_npc_unconscious_natural_recovery.gd` |
| NPC 昏迷协助治疗验证 | `tools/verify_npc_unconscious_healing.gd` |
| NPC 面板非对话交互验证 | `tools/verify_npc_panel_interactions.gd`，T1006 起确认攻击入口已移出 NPC 面板 |
| NPC 主动交涉验证 | `tools/verify_npc_proactive_talk.gd` |
| GM 调试面板验证 | `tools/verify_gm_panel.gd` |
| 后端 Schema 验证 | `tools/verify_backend_schemas.py` |
| Mock / Real Model Adapter 验证 | `tools/verify_mock_model_adapter.py`；开发期 mock / fallback 验证不等于真实 API 验收 |
| `/npc/dialogue` Mock 接口验证 | `tools/verify_dialogue_mock_endpoint.py` |
| NPC 对话 Prompt fake real-provider 验证 | `tools/verify_dialogue_prompt.py` |
| NPC 对话 Prompt 真实 provider smoke 验证 | `tools/verify_dialogue_prompt_real.py` |
| 对话 / 行动失败通用计划修改判别 fake / endpoint 验证 | `tools/verify_dialogue_plan_revision_judgement.py` |
| 对话 / 行动失败通用计划修改判别真实 provider 验证 | `tools/verify_dialogue_plan_revision_judgement_real.py` |
| Godot 行动失败两段式判别 / 修订验证 | `tools/verify_action_failure_plan_revision_judgement.gd` |
| 8 名 NPC 职业身份对话真实 provider 验证 | `tools/verify_npc_character_dialogue_real.py` |
| 每日计划 Prompt fake real-provider 验证 | `tools/verify_plan_day_prompt.py` |
| 每日计划 Prompt 真实 provider smoke 验证 | `tools/verify_plan_day_prompt_real.py` |
| 战时 / 低血量心理 Prompt fake real-provider 验证 | `tools/verify_battle_judgement_prompt.py` |
| 战时 / 低血量心理 Prompt 真实 provider smoke 验证 | `tools/verify_battle_judgement_prompt_real.py` |
| 首次睡眠总结 Prompt fake real-provider 验证 | `tools/verify_daily_reflection_prompt.py` |
| 首次睡眠总结 Prompt 真实 provider smoke 验证 | `tools/verify_daily_reflection_prompt_real.py` |
| API 额度与调试信息验证 | `tools/verify_api_budget_debug.py` |
| LLM 正式 call_type 输出限制审计 | `tools/verify_llm_call_audit.py`，覆盖六类正式调用不发送 `max_tokens`、截断重试和运行配置快照 |
| Godot LLMBridge 验证 | `tools/verify_llm_bridge.gd`，T0604A 起包含不依赖 `curl.exe` / `OS.execute` 的静态检查；T1401 起覆盖 usage 查询不遗留慢速请求 |
| Godot LLM 时间降速审计 | `tools/verify_llm_time_slowdown_audit.gd`，覆盖六类正式同步 / 异步请求的慢速注册、释放、开局全局暂停边界与只读接口不降速 |
| 对话 UI、轮次与对话事件验证 | `tools/verify_dialogue_ui.gd` |
| NPC-NPC 自主对话气泡与只读旁听验证 | `tools/verify_npc_npc_dialogue_observer_ui.gd` |
| NPC-NPC 自主对话真实 provider 旁听与慢速验证 | `tools/verify_npc_npc_dialogue_observer_real.gd` |
| NPC-NPC 邀请、软轮次、单方结束与双方独立计划判别合同验证 | `tools/verify_dialogue_invitation_contract.gd` |
| 入伍 NPC 自然语言指令验证 | `tools/verify_npc_order.gd` |
