# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.39-godot-native-http-llm-bridge`
状态：已完成 Godot 项目入口、可扩展 Main 场景节点结构、低模驿站 Blockout、基础 HUD、可拖动 GM 调试面板、基础摄像机控制、核心 Autoload 骨架、基础 JSON 数据文件、8 名初始 NPC 数据草案、基础 NPC 生成与点击、NPC 基础状态读取/更新、NPC HP 扣除与昏迷状态、NPC 昏迷自然恢复与自动复苏、其他 NPC 协助治疗昏迷者、昏迷/睡觉期间见闻暂停、NPC 面板、基础 NPC 直线移动与地点进入、地点信息节点与进入快照、进入广场和可进入建筑时的在场 NPC 生命/行动状态快照、广场进入快照当前公告/在场人员补齐、室内地点经由广场的逻辑事件链、广场公开信息即时广播、NPC 当天短期记忆容器、玩家交互事件“守备官”世界内称呼规则、按 `game_design.md` 对齐的工作/吃饭/睡觉最小行动闭环、基础 ResourceSystem、基础 BuildingSystem、基础建筑面板、建筑修复/升级倒计时闭环、建筑点击选择与状态刷新信号拆分、结构化事件底座、精确到秒且支持独立暂停/加速与 LLM 等待减速请求的基础 TimeSystem，Flask 后端骨架、`/health` 健康检查、后端 AI 请求/响应 Pydantic Schema、默认 `mock` provider 的 Model Adapter、`/mock/model` 调试接口、`/npc/dialogue` Mock 业务接口，以及 Godot 侧基于原生 `HTTPClient` 的 `LLMBridge` 请求 `/health` / `/npc/dialogue`、HUD 后端状态显示和 GM 对话 Mock 调试入口；尚未实现真实每日计划、复杂生产效率、敌人战斗、完整诊所治疗系统、Godot 前端对话 UI、对话事件入库和征召状态变更。

## 当前已实现内容

- [x] Godot 项目初始化
- [x] 核心 Autoload 骨架
- [x] Main 标准节点结构
- [x] 基础地图
- [x] HUD 基础界面
- [x] GM 调试面板
- [x] 基础摄像机控制
- [x] NPC 基础实体
- [x] NPC 基础状态与面板
- [x] NPC HP 扣除与昏迷状态
- [x] NPC 基础移动与地点进入
- [x] 地点信息节点与进入快照
- [x] NPC 工作 / 吃饭 / 睡觉最小行动闭环
- [x] 8 名初始 NPC 数据草案
- [x] 建筑基础实体
- [x] 建筑基础面板
- [x] 建筑修复与升级最小逻辑
- [x] 时间系统
- [x] 资源系统
- [ ] 对话系统
- [x] LLM 后端骨架
- [x] 后端 AI Schema
- [x] 后端 NPC 对话 Mock 接口
- [x] Godot LLMBridge
- [ ] 征召系统
- [ ] 战斗系统
- [x] 昏迷自然恢复/复苏
- [x] 治疗昏迷 NPC
- [x] 广场公开信息即时广播
- [x] NPC 短期记忆容器
- [ ] 完整见闻系统
- [x] 结构化事件底座
- [ ] 结算系统
- [x] 基础 JSON 数据文件

## 当前稳定运行流程

```text
启动 Godot
  ↓
加载 EventBus / GameState / ConfigLoader Autoload
  ↓
进入 Main 场景
  ↓
加载 WorldRoot / Station / Systems / UI / CameraRig 标准节点结构
  ↓
显示低模驿站 Blockout、俯视相机、方向光
  ↓
ResourceSystem 从 data/resource_defs.json 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁
  ↓
BuildingSystem 从 data/building_defs.json 初始化建筑基础状态并绑定低模建筑节点；主厅前公告牌不属于建筑定义
  ↓
NPCSystem 从 data/npc_profiles.json 读取 8 名初始 NPC，并在 Station/NPCs 下生成占位实体
  ↓
NPCSystem 可通过 `debug_damage_npc` / GM `attack_npc` 扣除 HP；HP 到 0 时 NPC 原地昏迷，停止移动，行动/移动指派被拒绝，并写入 `damage_taken` / `unconscious_started` 事件；昏迷 NPC 会随 TimeSystem 逻辑时间以每游戏小时 2 HP 的速度自然恢复，达到 Max HP 的 30% 后自动复苏、回到 idle、重新允许行动，并写入 `revived` 事件
  ↓
可通过调试接口让 NPC 前往指定建筑；NPC 实体直线移动，到达后写回 current_location 与 location_context 占位；室内到室内的地点信息与事件链会逻辑上经由广场
  ↓
ActionSystem 可通过调试接口安排 NPC 去工作、吃饭、睡觉或协助治疗昏迷者；若目标建筑/地点不同，会先移动，到达后由 MemorySystem 更新地点 people_present，进入者获得一次地点状态见闻，NPCSystem 生成只记录行动事实的 location_entered / location_exited 事件；若从一个室内地点切到另一个室内地点，事件顺序会插入进入/离开广场，再进入持续行动
  ↓
行动结算由程序随 TimeSystem 逻辑时间执行：工作当前以 1 小时为最小批次，持续结束后消耗/产出资源并结算饱食/疲劳；协助修复/协助升级在广场进行，可按工程熟练度加速正在进行的建筑修复/升级，事件以 `location_id == "plaza"` 的 `local_public` 写入；吃饭消耗粮食或餐食后在 20 分钟内逐步恢复饱食度；睡觉按 6.5 小时消耗 100 点疲劳的基准逐步降低疲劳；其他行动事件以 `local_public` 写入 MemorySystem 的结构化事件库，让同地点当前在场且未昏迷、未睡觉的 NPC 收到见闻
  ↓
显示 HUD 标题、天数、`HH:MM:SS` 时间/阶段、真实资源数值、独立速度按钮、独立暂停/继续按钮、警铃按钮占位和由 LLMBridge health check 刷新的后端状态
  ↓
开发模式下显示半透明可拖动 GM 按钮；点击可打开 GM 面板，通过按钮或命令调试资源、时间、建筑、NPC、NPC 扣血/昏迷/自然恢复、行动、地点快照、广场公告和短期记忆
  ↓
建筑调试标签显示名称、等级和 HP，真实鼠标点击建筑可发出 building_clicked(building_id)
  ↓
NPC 短姓名/HP/当前行动调试标签可见，点击 NPC 可打印并发出 npc_clicked(npc_id)
  ↓
右上角 NPC 面板可显示被点击 NPC 的姓名、HP、力量/智力属性、由熟练度推导的专长、饱食、疲劳、金钱、昏迷、入伍、当前行动、职业熟练度、武器熟练度，以及分开的事件库/见闻库最近摘要；NPC 状态或记忆被系统修改后面板会刷新
  ↓
右上角建筑面板显示被点击建筑的名称、等级、HP、工作位和地点信息占位，可关闭；修复/升级按钮按条件启用并调用 BuildingSystem，资源消耗和执行条件在按钮悬停提示框中显示；修复和升级都显示倒计时进度、剩余时间、速度倍率和协助人数；NPC 面板和建筑面板会随点击对象互斥切换；建筑修复/升级进度等状态刷新不会把已经切到 NPC 的右上角面板抢回建筑面板
  ↓
玩家可用 WASD、鼠标中键拖拽和滚轮在受限边界内查看驿站
```

低模驿站当前包含主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌视觉占位和调试标签。2026-05-19 已扩大地面与围墙范围，并重新拉开建筑间距，让中央广场、生活区、生产区、防务区和后门入口更易辨认；随后补齐围墙四角闭合，并把公告牌缩小移动到主厅正面。2026-05-24 起公告牌不再属于建筑数据，不具备 HP、等级、工作位、修复或升级；公告输入后的文本归广场当前状态保存并广播。HUD 当前显示 `ResourceSystem` 初始化后的五类基础资源数值：第纳尔、粮食、木材、石料、铁；餐食、酒、武器、盔甲、工程器械和马匹整备作为派生资源用于行动结算，暂不显示在 HUD 中；时间显示为 `HH:MM:SS`，会随 `TimeSystem` 每个游戏秒刷新；速度按钮只在 `x1`、`x2`、`x4` 之间循环，暂停/继续由独立按钮控制，也可按空格切换，空格不再触发加速；TimeSystem 当前不改变 Godot 全局速度或 NPC 移动速度，只提供逻辑时间倍率、`logical_time_tick`、`gameplay_pause_changed` 和 LLM 等待慢速请求接口。暂停时逻辑时间停止、NPC 移动停止，尚未到达目标地点的行动保持 pending，已经开始的工作/吃饭/睡觉保持 active，不会在暂停中继续消耗/产出资源或改变饱食/疲劳，恢复后继续按逻辑时间结算；建筑修复/升级倒计时也遵循同一逻辑时间与暂停语义。警铃按钮仍不触发真实逻辑；后端状态由 `LLMBridge` health check 刷新。建筑当前由 `BuildingSystem` 读取 `data/building_defs.json` 绑定到低模节点，标签显示名称、等级和 HP，运行时点击区可识别建筑 ID 并发出 `building_clicked`；`NoticeBoard` 不被 `BuildingSystem` 绑定。2026-05-20 已修正 HUD 背板拦截问题，真实鼠标点击建筑会通过相机射线拾取打开 `BuildingPanel`。`BuildingPanel` 监听该事件并显示建筑名称、等级、HP、工作位和地点信息占位；修复/升级按钮会调用 `BuildingSystem`，资源消耗和条件只在按钮悬停提示框中显示；升级与修复一样是倒计时作业，受损、正在修复或正在升级时不能开始升级。NPC 当前由 `NPCSystem` 读取 `data/npc_profiles.json`，在 `Main/WorldRoot/Station/NPCs` 下生成 8 个低模占位实体，主场景头顶标签只显示短姓名、HP 和当前行动；`NPCPanel` 按姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、熟练度的顺序展示，其中属性来自 `stats.strength` / 力量和 `stats.intelligence` / 智力，专长由固定熟练度推导，熟练度按职业熟练度、武器熟练度两组展示完整 13 维。点击 NPC 会打印 ID、发出 `npc_clicked(npc_id)` 并打开 `NPCPanel`。`NPCSystem` 提供 NPC 状态读取、更新和调试移动接口，`debug_move_npc_to_building(npc_id, building_id)` 可让 NPC 直线移动到建筑入口；到达后会通过 `MemorySystem.move_npc_between_locations(...)` 更新地点信息节点的 `people_present`，并写入 `current_location`、`current_location_name`、`location_context`，同时生成只保留行动事实的 `location_entered` / `location_exited`；进入者需要的完整地点状态只作为一次性 `location_entry_snapshot` 见闻写入。地点信息节点当前覆盖广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊；主厅、围墙、城门、后门、仓库不作为常规进入空间。所有建筑的可传播外部状态只包含等级和完好/受损/正在修复/正在升级；HP 与剩余修复/升级时长仍可在建筑系统和 UI 中查看，但不会作为信息节点传播条件。可进入建筑额外有内部状态（在场 NPC、每个工位占用/空闲状态），工位数量本身不作为传播条件；不可进入建筑不暴露内部 NPC 或工位。广场没有自身建筑 HP，但通过 `building_external_states` / `key_entities` 保存所有建筑可传播外部状态。`local_public` 事件会即时广播给该地点当前在场 NPC 并写入接收者见闻库，地点节点不保存事件历史；广场事件就是 `location_id == "plaza"` 的 `local_public`。`ActionSystem` 当前读取 `data/action_defs.json`，提供调试指派工作、协助修复、协助升级、吃饭和睡觉接口：菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺产出武器/盔甲、工械坊产出工程器械、马厩产出马匹整备占位；协助修复和协助升级通过带建筑参数的调试接口加速已有作业；工作当前持续 1 小时后结算一批投入/产出，吃饭持续 20 分钟并逐步恢复饱食度，睡觉持续 6.5 小时并逐步降低疲劳；工作、吃饭、睡觉开始/完成/失败会以 `local_public` 写入 `MemorySystem` 的结构化事件库；协助修复/协助升级开始也以 `local_public` 写入广场，目标建筑保存在 `payload.building_id`；事件包含 `subject_npc_id`、`location_id`、`visibility`、`target_ids` 和类型化 `payload`，对应地点当前在场 NPC 会收到对应见闻。`LLMBridge` 当前可请求 `/npc/dialogue` Mock；尚未实现真实日程计划、复杂职业效率、对话 UI、对话事件入库、征召结算或战斗。

2026-05-25 起，地点/广场信息节点的建筑状态已经降噪到只计算可传播字段：所有建筑可传播外部状态只计算等级和完好/受损/正在修复/正在升级；HP、Max HP、剩余修复/升级时长不参与信息节点状态比较，也不会因自身变化触发传播。广场和可进入建筑的进入快照都会计算在场 NPC 的生命/行动状态；可进入建筑还计算每个工位的占用/空闲状态，工位数量不触发传播。NPC 生命状态分为健康、受伤、昏迷；昏迷者如有治疗者会写明治疗者。行动状态由 `current_action` 翻译为精简中文。广场没有自身建筑 HP，但通过 `building_external_states` / `key_entities` 保存所有建筑可传播外部状态；NPC 进入广场会获得当前广场在场 NPC、这些 NPC 的生命/行动状态、当前公告文本和所有建筑外部状态见闻，进入某个可进入建筑会获得该建筑外部 + 内部状态见闻。任一建筑可传播外部状态变化会同步给广场并广播给当时在广场的 NPC；某个可进入建筑内部状态变化当前仍会广播给该建筑内 NPC。状态见闻 summary 会写明具体建筑名称和具体事实，不加“建筑状态更新”这类空泛前缀。

T0407/T0408/T0409 已实现：NPC 进入可进入建筑时，`location_entered` 事件库记录只保留“进入某地”的行动事实；建筑外部状态、建筑内 NPC、建筑内 NPC 生命/行动状态和工位占用状态只作为进入者的一次性 `location_entry_snapshot` 见闻写入。NPC 进入广场时，进入快照会写入当前广场在场 NPC、广场在场 NPC 的生命/行动状态、当前公告文本和所有建筑外部状态。已经在地点内的 NPC 只收到进入/离开事件，不再额外收到完整建筑状态、完整 `people_present` 或完整 `people_statuses`。NPC 离开地点时会生成 `location_exited`，事件地点为其离开的地点，并广播给仍在该地点的 NPC。室内信息地点切换到另一个室内信息地点时，事件与地点信息层会插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链；当前物理移动仍是直线占位。后续建筑/地点状态变化只传递 `changed_fields` / `changed_workstations` 变化字段。协助修复/协助升级都是广场行为；NPC 在室内时会先前往广场，协助开始事件写入 `location_id == "plaza"` 的 `local_public`。

T0501/T0502/T0502A/T0503 已实现：`NPCSystem.apply_damage_to_npc(...)` 是当前 NPC HP 扣除权威入口；GM `attack_npc` / `damage_npc` 命令调用该接口。HP 降到 0 后 NPC 设置为昏迷，不死亡，停止移动并显示 `current_action=unconscious`；`ActionSystem` 会清除该 NPC 的 pending / active 行动，后续行动指派和移动调试都会被拒绝。系统会写入 `damage_taken` 和 `unconscious_started` 事件，其中昏迷事件以 `local_public` 广播到 NPC 当前信息地点，同地点 NPC 会收到见闻。昏迷 NPC 会随 `TimeSystem.logical_time_tick` 以每游戏小时 2 HP 的速度自然恢复；HP 达到 Max HP 的 30% 后自动复苏、回到 `idle`、重新允许移动/行动，并写入 `revived` 本地公开事件。昏迷期间 `MemorySystem.add_witness_event(...)` 会拒绝给该 NPC 写入见闻，因此地点/广场广播、状态变化、公告和进入快照都不会进入其见闻库；复苏后自动恢复接收。2026-06-03 起，该接收规则也覆盖睡觉：`current_action == "sleep_in_dormitory"` 的 NPC 不接收同地点/同建筑 public 见闻，睡醒回到可行动状态后恢复接收，不补收睡觉期间错过的信息。GM `recover_npc <npc_id> <game_seconds>` 可用同一套自然恢复规则推进指定 NPC 的恢复。`ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 可让可行动 NPC 前往昏迷目标所在信息地点协助治疗；每名昏迷目标最多 2 名治疗者，治疗开始和持续过程中消耗第纳尔，医术熟练度越高恢复越快，资源不足会失败或中止；治疗开始/完成写入治疗者和目标的结构化事件，并写入同地点其他在场、未昏迷且未睡觉 NPC 的见闻库，事件信息不暴露医术熟练度。当前仍不实现敌人战斗或 T0808 的完整诊所治疗系统。

摄像机当前绑定 `res://scripts/camera/CameraRig.gd`，支持 WASD 平移、鼠标中键拖拽平移和滚轮缩放；移动限制在驿站地面附近，缩放保持现有高机位俯视角，不提供角色控制或第一人称自由视角。

后端当前稳定流程：

```text
进入 backend
  ↓
安装 requirements.txt
  ↓
启动 Flask app.py
  ↓
访问 GET /health
  ↓
返回 {"ok": true, "service": "war-not-mine-backend"}
  ↓
无 `.env` 或未设置 LLM_PROVIDER 时，ModelAdapter 默认使用 mock provider
  ↓
POST /mock/model 可按 call_type 返回稳定 JSON，并附带伪 token 与用途记录；非 mock provider 未配置 LLM_API_KEY 时返回明确错误
  ↓
POST /npc/dialogue 可按 T0603 对话 Schema 校验玩家-NPC / NPC-NPC 请求并返回稳定 Mock JSON；提出应征时返回 accept / reject，NPC-NPC 对话接近最大轮次时倾向结束
  ↓
Godot `LLMBridge` 使用原生 `HTTPClient` 请求 `/health` 和 `/npc/dialogue`；玩家发起对话时 `speaker_name == "守备官"`，请求期间会调用 `TimeSystem.request_time_slowdown(...)`，成功、失败或超时后释放慢速请求
```

T0604A 已将 Godot `LLMBridge` 传输层替换为原生 `HTTPClient` 状态机，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件。正式方向锁定为“玩家电脑 Godot 客户端 -> 游戏服务器后端 -> LLM Provider”：供应商 API Key 默认只存在于服务器后端；玩家自行配置 API Key 仅作为未来可选模式，Demo 阶段不要求实现。

后续预期稳定流程：

```text
启动 Godot
  ↓
进入 Main 场景
  ↓
显示驿站地图、时间、资源栏
  ↓
显示至少 1 个 NPC
  ↓
NPC 可移动到建筑并执行简单工作
```

## 当前运行方式

```bash
godot --path .
```

或在 Godot 编辑器中打开 `project.godot` 后运行项目。当前启动场景为：

```text
res://scenes/main/Main.tscn
```

后端已初始化，可用以下方式启动：

```bash
cd backend
python app.py
```

健康检查：

```bash
curl http://127.0.0.1:5000/health
```

## 当前主要文件

- `AGENTS.md`：AI Agent 项目协作规则
- `game_design.md`：完整游戏设计源
- `docs/PROJECT_BRIEF.md`：项目简报
- `docs/TASKS.md`：任务列表
- `docs/MODULE_INDEX.md`：模块索引
- `backend/app.py`：Flask 后端入口，提供 `GET /health`、`POST /mock/model` 和 `POST /npc/dialogue`
- `backend/services/model_adapter.py`：模型适配器边界，当前默认 `mock` provider，支持按调用类型返回稳定 JSON、记录伪 token / 用途信息，并对未配置的非 mock provider 返回明确错误
- `backend/schemas/common.py`：后端 AI 接口共享上下文 Schema，包含游戏时间、请求元信息、NPC 状态、短期记忆摘要和行动候选
- `backend/schemas/npc_ai.py`：NPC 对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉和玩家话术分类 Schema
- `tools/verify_backend_schemas.py`：后端 Schema 导入与关键模型实例化验证脚本
- `tools/verify_mock_model_adapter.py`：Mock Model Adapter 与 `/mock/model` HTTP 调试接口验证脚本
- `tools/verify_dialogue_mock_endpoint.py`：`/npc/dialogue` Mock 业务接口验证脚本
- `tools/verify_llm_bridge.gd`：Godot 侧 LLMBridge、HUD 后端状态、对话 Mock 和慢速释放验证脚本
- `backend/requirements.txt`：Python 后端依赖
- `project.godot`：Godot 项目配置，当前入口为 `res://scenes/main/Main.tscn`
- `scenes/main/Main.tscn`：最小可运行主场景，包含标准 WorldRoot、Systems、UI、CameraRig 节点结构、低模驿站 Blockout 和基础 HUD
- `scripts/ui/HUD.gd`：HUD 展示脚本，读取 `GameState` 的天/时/分/秒，监听 `time_changed` / `resource_changed` 并刷新时间、资源显示、速度/暂停按钮和后端状态占位
- `scripts/systems/LLMBridge.gd`：Godot 侧后端桥接，支持后端地址配置、`/health`、`/npc/dialogue` Mock 请求、T0603 对话 payload 构造和 LLM 等待慢速请求注册/释放
- `scripts/ui/BuildingPanel.gd`：建筑面板脚本，监听 `building_clicked` 打开建筑、监听 `building_state_changed` 刷新当前可见建筑，并展示建筑基础信息，可触发建筑修复/升级
- `scripts/ui/NPCPanel.gd`：NPC 面板脚本，监听 `npc_clicked`、`npc_state_changed` 和 `npc_memory_changed`，按姓名/HP/属性/专长/基础状态/熟练度/事件库/见闻库顺序展示 NPC 数据，并与建筑面板互斥切换
- `scripts/ui/GMPanel.gd`：GM 调试面板脚本，提供可拖动半透明 GM 按钮、命令输入框和资源/时间/建筑/NPC/行动/记忆调试入口；行动分组内有“修复目标”“升级目标”和“治疗目标”下拉用于测试协助修复/协助升级/协助治疗；顶部 `GM_ENABLED` 常量可切换开发/上线显示
- `scenes/npc/NPC.tscn`：通用 NPC 占位场景，当前为可点击低模实体和短姓名/HP/当前行动标签
- `scripts/npc/NPC.gd`：NPC 展示脚本，保存唯一 ID，刷新调试标签，在点击时发出 `npc_clicked`，并支持直线移动到指定地点
- `scripts/camera/CameraRig.gd`：基础俯视摄像机控制，支持 WASD/鼠标中键平移、滚轮缩放和边界限制
- `scripts/core/EventBus.gd`：全局事件总线，声明基础跨系统信号；`building_clicked` 表示玩家/调试选择建筑，`building_state_changed` 表示建筑数据刷新
- `scripts/core/GameState.gd`：全局运行状态，保存天数、小时、分钟、秒和战斗状态
- `scripts/core/ConfigLoader.gd`：JSON 配置读取入口，提供缺失/解析错误提示
- `scripts/systems/ResourceSystem.gd`：基础资源系统，从 `data/resource_defs.json` 初始化资源，提供读取、增加、扣除和负数保护接口，并通过 `resource_changed` 通知 HUD
- `scripts/systems/BuildingSystem.gd`：基础建筑系统，从 `data/building_defs.json` 初始化建筑状态，绑定低模建筑节点，创建运行时点击区，选择建筑时发出 `building_clicked`，建筑受损/修复/升级等数据变化时发出 `building_state_changed`，并提供倒计时修复、倒计时升级、协助者加速、建筑入口坐标和当前地点快照接口
- `scripts/systems/NPCSystem.gd`：基础 NPC 系统，从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体，并提供查询、状态更新、调试选择、调试移动和即时进入地点调试接口
- `scripts/systems/ActionSystem.gd`：简单行动系统，读取 `data/action_defs.json`，支持调试指派工作、协助修复、协助升级、协助治疗昏迷 NPC、吃饭、睡觉；行动到达地点后随 `logical_time_tick` 持续推进，暂停时 pending / active 行动都不继续结算，恢复后继续，并写入结构化行动事件
- `scripts/systems/MemorySystem.gd`：结构化事件事实源与地点信息节点系统，维护全局事件索引、NPC 当天事件库、NPC 见闻库、短期记忆容器查询、地点当前在场人员/快照和广场事件查询；建筑可传播外部状态只包含等级和完好/受损/正在修复/正在升级，内部状态包含在场 NPC、在场 NPC 的生命/行动状态与工位占用；不提供按地点查询事件的长期接口，地点/广场节点不保存事件历史
- `scripts/systems/TimeSystem.gd`：基础逻辑时间系统，支持 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速请求、`logical_time_tick` 和 `time_changed` / `time_scale_changed` / `hour_started` / `day_started` 信号
- `scripts/systems/CombatSystem.gd`、`DialogSystem.gd`：后续系统的空脚本占位
- `data/resource_defs.json`：资源定义，包含第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁
- `data/building_defs.json`：建筑定义，当前覆盖 15 个低模建筑/门墙实体，并包含等级、HP、标签、工作位、资源输入输出、场景节点绑定，以及所有建筑的修复/升级配置；公告牌不在建筑定义中
- `data/action_defs.json`：行动定义，当前包含菜园、食堂、酒窖、铁匠铺、工械坊、马厩、吃饭、睡觉和需要目标 NPC 的协助治疗定义；协助修复/协助升级由 `ActionSystem` 作为带建筑参数的运行时行为处理，协助治疗由 `ActionSystem` 作为带昏迷 NPC 目标的运行时行为处理
- `data/weapon_defs.json`：武器定义最小样例，当前包含短剑
- `data/enemy_waves.json`：敌人波次最小样例，当前包含第一波占位
- `data/npc_profiles.json`：NPC 档案配置，当前包含 8 名初始 NPC：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文；老兵副官开局 `recruited=true`，其他 NPC 初始不可指派

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。
- Godot 侧 LLMBridge 已使用原生 HTTP；后续 M7 对话 UI 可以在该桥接层上推进，但仍不得让客户端保存供应商 API Key 或直连模型供应商。
- 真实 LLM 并发、成本、限流和 API Key 管理必须放在后端；不要把客户端直连模型或玩家必须自带 Key 当作 Demo 默认方向。
- 当前 `backend/app.py` 已是后端应用入口，但仍是本地开发形态；正式给玩家使用前需要执行 T1407，用生产 WSGI 服务、部署文档、环境变量、日志、限流和健康检查把后端部署到服务器。

## 最近一次变更

- T0604A LLMBridge 原生 HTTP：`scripts/systems/LLMBridge.gd` 已用 Godot 原生 `HTTPClient` 状态机替换 T0604 的 `curl.exe` / 临时 JSON 文件传输层，保留 payload 构造、错误字典、`backend_status_changed` 和 TimeSystem 慢速注册/释放边界；`tools/verify_llm_bridge.gd` 新增防回退静态检查，确认脚本不含 `curl.exe` / `OS.execute`。验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。
- T1407 文档任务登记：新增“部署游戏后端到服务器”为 P0 任务，明确服务器运行入口仍是 `backend/app.py`，本地可用 `python backend/app.py`，正式部署必须使用生产 WSGI 服务并补齐 `backend/README.md`、环境变量、日志、限流、预算、健康检查和 Godot 后端地址配置说明。
- T0604A 文档任务登记：新增“替换 LLMBridge 传输层并锁定正式前后端架构”为 P0 任务，明确 T0604 的 `curl.exe` 只是临时本地开发实现；正式方向是玩家电脑运行 Godot 客户端，请求游戏服务器后端，由后端调用 LLM Provider、持有 API Key、控制并发和成本；玩家自行配置 API Key 仅作为未来可选模式。同步把 T0701 前置改为 T0604A，并在架构/API/AI 文档记录 T0604 踩坑。
- T0604 Godot LLMBridge：新增 `scripts/systems/LLMBridge.gd` 并挂载到 `Main/Systems/LLMBridge`，支持后端地址配置、`/health`、`/npc/dialogue`、T0603 对话 payload 收集、请求失败返回错误、请求期间 TimeSystem 慢速注册/释放；HUD 后端状态改为读取 LLMBridge；GM 面板新增 health / 对话 Mock / 应征 Mock 调试入口；新增 `tools/verify_llm_bridge.gd`。验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。
- T0603 `/npc/dialogue` Mock 接口：`backend/app.py` 新增正式 `POST /npc/dialogue`，请求和输出分别校验为 T0603 版 `NPCDialogueRequest` / `NPCDialogueResponse`；`backend/services/model_adapter.py` 的 dialogue mock 支持玩家-NPC 应征 accept/reject 和 NPC-NPC 轮次结束倾向；新增 `tools/verify_dialogue_mock_endpoint.py`。验证通过：`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、Python 编译检查。
- T0602 Mock Model Adapter：`backend/services/model_adapter.py` 默认 provider 改为 `mock`，新增 `generate(...)`、按调用类型分支的稳定 JSON、伪 token / 用途记录和非 mock 未配置 Key 的明确失败；`backend/app.py` 新增 `POST /mock/model` 调试接口；新增 `tools/verify_mock_model_adapter.py`。验证通过：`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、Python 编译检查。
- T0601 后端 Schema：新增 `backend/schemas/common.py`、`backend/schemas/npc_ai.py`、`backend/schemas/__init__.py` 和 `backend/schemas/README.md`，覆盖对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉和玩家话术分类请求/响应；新增 `tools/verify_backend_schemas.py`。验证通过：`python tools/verify_backend_schemas.py`、Python 编译检查、Flask `/health` test client。
- T0502A 睡觉期间停止接收见闻：`MemorySystem.add_witness_event(...)` 的见闻接收判定扩展为拒绝昏迷或 `current_action == "sleep_in_dormitory"` 的 NPC；睡觉者不会收到同地点/同建筑 `local_public` 事件、状态广播、公告或进入快照，睡醒后从后续广播开始恢复接收。验证通过：`verify_action_local_public_broadcast.gd`。
- T0409 广场 NPC 状态快照补齐：`MemorySystem.get_location_snapshot("plaza")` 也会生成 `people_statuses`，进入广场的 NPC 能在 `location_context` 和 `location_entry_snapshot` 见闻 summary 中看到广场上 NPC 的生命状态与行动状态。验证通过：`verify_location_info_nodes.gd`。
- T0407/T0503 建筑内 NPC 状态快照补齐：`MemorySystem` 的可进入建筑快照新增 `people_statuses`，进入者的 `location_entry_snapshot` 见闻现在能看到建筑内 NPC 的生命状态（健康/受伤/昏迷，昏迷时可包含治疗者）与行动状态（由 `current_action` 翻译成精简中文）。`ActionSystem` 新增只读 `get_healing_helpers_for_target(...)` 供信息节点查询当前治疗者。验证通过：`verify_location_info_nodes.gd`、`verify_npc_unconscious_healing.gd`。
- T0503 治疗昏迷 NPC：`ActionSystem` 新增 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`，治疗者会前往昏迷目标所在信息地点，每个目标最多 2 名治疗者；治疗按逻辑时间扣第纳尔并调用 `NPCSystem.assist_unconscious_recovery(...)` 加速 HP 恢复，医术低几乎无加成，高医术恢复明显更快；`MemorySystem` 支持 `healing_started` / `healing_completed` summary 与 payload 校验；治疗事件进入治疗者和被治疗者事件库，同地点其他在场 NPC 获得见闻，事件信息不暴露医术熟练度；GM 新增治疗目标下拉和 `assist_heal <healer_npc_id> <target_npc_id>` 命令。验证通过：`verify_npc_unconscious_healing.gd`、`verify_gm_panel.gd`、`verify_npc_unconscious_natural_recovery.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_structured_memory_events.gd`、`verify_npc_short_term_memory_container.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。
- T0502 昏迷自然恢复：`NPCSystem` 监听 `logical_time_tick`，昏迷 NPC 以每游戏小时 2 HP 自然恢复，达到 Max HP 30% 后自动复苏并发出 `npc_revived`；`MemorySystem` 支持 `revived` summary 与 payload 校验；GM 新增 `recover_npc <npc_id> <game_seconds>` 调试命令。验证通过：`verify_npc_unconscious_natural_recovery.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_location_info_nodes.gd`、`godot --headless --path . --quit-after 1`。
- T0502A 昏迷期间停止接收见闻：`MemorySystem.add_witness_event(...)` 现在会拒绝给昏迷 NPC 写入见闻，覆盖地点/广场公开广播、状态广播、公告和进入快照；复苏后见闻接收自动恢复。验证已补入 `verify_npc_unconscious_natural_recovery.gd`。
- T0501 NPC HP 扣除与昏迷状态：`NPCSystem` 新增权威扣血接口和昏迷判定，`ActionSystem` 阻止昏迷 NPC 移动/行动，`MemorySystem` 支持 `damage_taken` / `unconscious_started` summary 与 payload 校验，GM `attack_npc` / `damage_npc` 可直接扣 HP 并触发同地点 `local_public` 昏迷见闻。验证通过：`verify_npc_damage_unconscious.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。
- T0409 广场进入快照与室内经由广场移动链：`MemorySystem` 的广场进入快照 summary 补齐当前在场 NPC 与公告牌文本；`NPCSystem` 在室内到室内切换时按逻辑事件链插入广场中转，物理移动仍保持低模直线占位。验证通过：`verify_location_info_nodes.gd`、`verify_npc_movement_location.gd`、`verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_action_system_basic.gd`、`verify_structured_memory_events.gd`、`verify_gm_panel.gd` 和 `godot --headless --path . --quit-after 1`。
- T0408 广场公开类型收敛：事件可见性只保留 `private` / `local_public`；广场事件使用 `location_id == "plaza"` 的 `local_public`，协助修复/升级、公告和建筑外部状态广播都走同一地点广播路径。验证通过：`verify_plaza_local_public_broadcast.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1`。
- T0407 地点事件与建筑状态见闻精简：`location_entered` / `location_exited` 只保留进出行动事实，进入者获得一次 `location_entry_snapshot` 状态见闻，已在场 NPC 只收进出事件；建筑/地点状态变化改为 `changed_fields` / `changed_workstations` 字段级差量见闻。验证通过：`verify_location_info_nodes.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1`。
- T0006 建筑修复进度不再抢占右上角面板：`EventBus` 新增 `building_state_changed(building_id)`，`BuildingSystem` 把修复进度、协助者变化、受损、修复完成和升级改为发状态刷新信号，不再复用 `building_clicked`；`BuildingPanel` 只在当前可见且显示同一建筑时响应状态刷新，因此玩家在修复过程中点击 NPC 后会保持 NPC 面板。验证：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --quit-after 1` 通过。
- T0005 Godot MCP proxy 自恢复：给 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs` 增加同父进程旧 proxy 全量清理与 lock 文件接管逻辑，避免同一个 Codex 会话残留多个 proxy；`tools/check_godot_mcp.ps1` 同步增加“多 proxy / broker 缺失”提示。
- T0205/T0305 建筑修复流程修订：`BuildingSystem.repair_building(...)` 现在在点击时一次性扣除资源并创建倒计时修复作业，HP 随 `TimeSystem.logical_time_tick` 逐步恢复；修复时长按缺失 HP、建筑等级和建筑配置计算。`ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`，NPC 可在修复期间按工程熟练度加速倒计时，多个 NPC 可叠加；若 NPC 离开对应建筑或被改派其他行动，协助人数和倍率会被移除。GM 命令新增 `assist_repair <npc_id> <building_id>`。
- T0406 统一玩家交互事件世界内称呼：玩家非对话交互写入 NPC 事件库 / 见闻库时，actor id 使用 `guard_officer`，summary 使用“守备官”，避免 NPC 记忆和后续 LLM 输入出现以“玩家”为主语的出戏文本。
- T0403 行动事件本地公开广播修复：`ActionSystem` 工作、吃饭、睡觉事件改为 `local_public`，同地点当前在场 NPC 会收到对应见闻；新增 `tools/verify_action_local_public_broadcast.gd` 回归验证。
- T0206 将公告牌移出建筑数据结构：`data/building_defs.json` 删除 `notice_board`，建筑定义调整为 15 个；`NoticeBoard` 只保留为主厅前视觉占位和后续公告输入/显示接口，公告文本继续归广场状态保存并广播。
- T0004 GM 调试面板：新增 `Main/UI/GMPanel` 和 `scripts/ui/GMPanel.gd`，把 M1-M4 已完成但前端不易直接验证的资源、时间、建筑、NPC、行动、记忆/见闻和广场公告能力暴露到可拖动 GM 面板；新增 `docs/GM_PANEL.md` 和 `tools/verify_gm_panel.gd`，并将“不可见功能需补 GM 入口”的规则写入 `AGENTS.md` 工作流。

## Godot MCP

- 项目内已安装并启用 `addons/godot_mcp`。
- Codex 端改为 `proxy -> broker -> Godot` 结构，避免多个 Codex 会话直接争抢 Godot 连接。
- `godot-mcp-proxy.mjs` 现已增加 `%USERPROFILE%\.codex\godot-mcp-proxy.lock` 接管逻辑：如果同一个 Codex 父进程下残留旧 proxy，新 proxy 会枚举并清理其余旧实例后再继续，减少“只剩孤立 proxy / MCP 间歇失联”的复发概率。
- 连接自检命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1
```

- 当前验证结果：脚本可正常返回 `Godot MCP connected`。
- 若再次异常，先看 `tools/check_godot_mcp.ps1` 输出：它现在会额外提示“multiple proxy processes are alive”或“Proxy is alive, but broker is missing”，优先按这个方向排查。
- 2026-06-02 复盘：这次 `godot_mcp` 工具返回 `Transport closed`，但 `tools/check_godot_mcp.ps1` 一度仍显示 `Godot MCP connected`，说明 Godot 插件和 `broker -> Godot` 连接没有先坏，坏的是当前 Codex 会话内已经关闭的 stdio MCP transport。清理残留 headless Godot 进程并重启 broker 后，外部自检可恢复；但已经关闭的 Codex MCP transport 不能在同一会话内热接回，需重启/刷新 Codex。重启后 `project.addon_status` 与 `editor.get_state` 均恢复正常。
- 历史上已经出现过类似工具链问题：2026-05-19 记录过重复直连 Godot `6550` 导致连接互相顶替；2026-05-25 记录过同一 Codex 父进程下残留多个 proxy、其中孤立 proxy 无 broker 子进程。本次教训是先区分三层状态：Godot 插件是否监听、broker 是否能健康响应、Codex 暴露的 MCP 工具 transport 是否仍活着；不要只凭 `Transport closed` 判断 Godot 插件已掉线。
- 2026-05-19 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图可见标题与基础地面。
- 2026-05-19 T0101 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，Autoload 加载正常，游戏日志无报错。
- 2026-05-19 T0102 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 标题与基础地面仍可见。
- 2026-05-19 T0103 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认低模驿站、HUD 标题和调试标签可见。
- 2026-05-19 T0104 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示标题、时间、资源占位、按钮占位和后端状态占位，且未遮挡主要驿站视角。
- 2026-05-19 T0105 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，`CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd` 并暴露平移、缩放和边界参数。
- 2026-05-19 T0202 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`；使用临时测试场景验证资源增加、扣除和超额扣除失败逻辑。
- 2026-05-19 T0203 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；当时临时 Godot 验证脚本确认 `BuildingSystem` 加载 16 个建筑定义、可查询主厅数据、可选中仓库、主厅 ClickArea 已创建；2026-05-24 T0206 后建筑定义调整为 15 个并移除公告牌建筑定义。通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- 2026-05-19 T0204 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过临时 Godot 验证脚本确认选择主厅会打开建筑面板、切换仓库会刷新数据、关闭按钮会隐藏面板；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。
- 2026-05-20 T0204 修正验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_panel_mouse_click.gd` 临时验证真实鼠标点击路径，主厅点击可打开建筑面板；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0205 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 验证建筑受损后可修复、修复/升级会扣除石料、升级会提升等级/Max HP/工作位、资源不足时升级失败且不扣资源；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0302 验证：通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 验证 8 个 NPC 生成和 `npc_clicked` 信号；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错，MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下存在 8 个 NPC `Area3D` 节点。
- 2026-05-20 T0303 验证：通过 `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 验证 NPC 面板打开、状态修改后刷新、NPC/建筑面板互斥切换和关闭按钮；通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 回归验证 NPC 生成与点击；通过 Godot MCP 运行主场景，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。
- 2026-05-21 T0304 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 验证 NPC 可通过调试接口依次前往食堂、宿舍、仓库，并在到达后更新地点和地点信息占位；通过 `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-21 T0305 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 验证 NPC 可被调试安排吃饭、睡觉、菜园工作、酒窖酿酒、铁匠铺制造、工械坊制造和建筑协助修复，资源/派生资源/建筑修复进度与饱食/疲劳会正确结算，行动事件写入 EventLog 占位；通过 `verify_npc_movement_location.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-23 T0402 验证：通过 `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 验证结构化事件字段、NPC 当天事件库、全局事件索引、广场公开查询和 payload schema；通过 `verify_action_system_basic.gd` 回归行动闭环；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；Godot MCP `get_state` 正常返回。
- 2026-05-24 T0403 验证：通过 `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 验证地点 `people_present` 进出更新、`location_entered` 进入快照、广场主厅/围墙/城门/仓库状态聚合和 `local_public` 见闻广播；通过 `verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-24 T0404 验证：通过 `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 验证广场 `local_public` 广播、公告变更广播、关键实体状态变更广播和广场快照字段；通过 `verify_location_info_nodes.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-26 T0407 验证：通过 `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 验证 `location_entered` 不带完整快照、进入者只获得一次当前状态见闻、已有 NPC 只收进入/离开事件、`location_exited.location_id` 使用离开地点；通过 `verify_plaza_local_public_broadcast.gd` 验证建筑状态见闻使用变化字段且不复制完整广场/建筑快照；通过 `verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0406 验证：通过 `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 验证给钱/攻击交互 summary 使用“守备官”且不包含“玩家”，actor id 使用 `guard_officer`；通过 `godot --headless --path . --script res://tools/verify_gm_panel.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0405 验证：通过 `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 验证 NPC 当天 `event_log` / `witness_log` 短期记忆容器、守备官给钱/攻击调试交互的事件写入和广播，以及 NPC 面板区分显示事件库与见闻库；通过 `verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_npc_panel_state.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0004 验证：通过 `godot --headless --path . --script res://tools/verify_gm_panel.gd` 验证 GM 面板加载、窗口打开、资源命令、建筑受损、设置时间、NPC 进入地点、给钱事件、广场公告和结果输出；通过 `verify_time_system.gd`、`verify_building_repair_upgrade.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd` 和 `godot --headless --path . --quit-after 1` 回归；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，清空旧日志后游戏日志无报错，截图可见 GM 按钮与面板。
