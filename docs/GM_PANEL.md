# GM_PANEL.md

> 本文件记录 GM 调试面板的用途、入口、命令和维护规则。每次更新 GM 面板都必须同步更新本文档。

## 目标

GM 面板用于把“已经实现但用户难以在主界面直接验证”的关键系统能力暴露到 `Main.tscn` 前端。它只调用已有系统接口或 `debug_*` 接口，不作为新的权威结算系统。

当前重点覆盖 M1-M4 已完成内容中原本主要靠脚本验证的能力：

- 资源增减、扣除失败和负数保护。
- 建筑选中、受损、倒计时修复、倒计时升级和全建筑外部状态广播。
- NPC 选中、状态修改、移动到建筑、立即进入地点。
- NPC 扣血、HP 清零昏迷、昏迷后行动阻断、昏迷自然恢复和复苏。
- 昏迷或睡觉期间见闻暂停；睡觉 NPC 不会接收同地点/同建筑 public 见闻，睡醒后恢复。
- 工作、协助修复、协助升级、协助治疗昏迷者、吃饭、睡觉等行动调试指派。
- TimeSystem 设定时间、跳小时、LLM 等待减速请求。
- LLMBridge 后端 health check、NPC 对话 Mock 和提出应征 Mock。
- 地点快照、广场公告、广场公开事件、守备官给钱/攻击等记忆事件。
- NPC 短期记忆容器，区分事件库和见闻库。
- 已入伍 NPC 当前自然语言指令、修订号、最近计划重评估请求/降级结果和最近一次 NPC LLM 指令注入。
- NPC 主动找守备官交涉的调试触发、问号气泡状态和超时 / 对话结束后的计划重评估请求。

GM 命令仍可使用 `give_money` / `attack_npc` 这类开发语义；写入 NPC 事件库、见闻库和事件 summary 时，玩家身份必须显示为“守备官”。

## 开关

GM 面板脚本位于：

```text
res://scripts/ui/GMPanel.gd
```

顶部常量控制是否启用：

```gdscript
const GM_ENABLED := true
```

- 开发验证时设为 `true`。
- 上线、正式录屏或不希望显示 GM 时设为 `false`。
- 不要删除 GM 节点和文档；后续开发仍需要它作为不可见功能的验证入口。

## 界面

运行 `res://scenes/main/Main.tscn` 后，屏幕左侧会出现半透明 `GM` 按钮。

- 拖动 `GM` 按钮可改变位置。
- 点击 `GM` 按钮打开或关闭 GM 面板。
- 面板顶部有命令输入框和执行按钮。
- 面板中部分组提供常用按钮和输入框。
- 面板底部显示最近执行结果。

## 分组

资源：

- 选择资源 ID 和数量。
- 增加资源。
- 扣除资源。
- 查看资源快照。

时间：

- 设置天、时、分、秒。
- 跳过 1 小时。
- 注册一次 GM 手动 LLM 减速。
- 清空所有减速请求。

建筑：

- 选择建筑。
- 打开建筑面板。
- 造成建筑受损。
- 调用修复；修复会先扣资源并创建倒计时作业，建筑快照可观察剩余时间、进度、协助人数和加速倍率。
- 调用升级；升级会先扣资源并创建倒计时作业，建筑快照可观察升级状态、进度、剩余时间、协助人数和加速倍率。
- 查看建筑快照。

NPC：

- 选择 NPC。
- 打开 NPC 面板。
- 移动到指定建筑入口。
- 立即进入地点信息节点。
- 设置 NPC 状态字段。
- 扣除 NPC HP；HP 清零后由 `NPCSystem` 触发昏迷。
- 用自然恢复规则推进指定 NPC 的昏迷恢复，便于快速验证复苏。
- 查看 NPC 快照。
- 为已入伍 NPC 发布自然语言指令、查看当前指令，并查看最近一次计划重评估请求及其降级结果；未入伍 NPC 发布会被 `NPCSystem` 拒绝。
- 触发当前选中 NPC 主动找守备官交涉，并查看该 NPC 的主动交涉状态；触发后 NPC 头顶出现 `?`，点击后进入既有对话面板。

行动：

- 指派指定行动；该下拉只列出 `data/action_defs.json` 中的普通行动，不包含按建筑写死的“修补围墙”等固定修复行动。
- 指派工作；T0801 起会占用目标可进入建筑的真实工位，并按 NPC 对应熟练度、力量/智力属性和建筑等级缩短单位周期。T0803 起，菜园工作还会按耕种熟练度、力量和菜园等级提高粮食产出。T0804 起，铁匠铺工作会消耗铁并产出武器/盔甲派生库存，打铁、力量和铁匠铺等级影响制作周期。T0805 起，工械坊工作会消耗木材并产出武器/工程器械派生库存，工程、智力和工械坊等级影响制作周期。T0806 起，马厩工作会消耗粮食并产出马匹整备派生库存，养马、力量和马厩等级影响制作周期与实际产出。T0807 起，酒窖工作会消耗粮食并产出酒库存，酿酒、智力和酒窖等级影响制作周期与实际产出；出售酒换钱仍归后续商人交易系统。工位占满或资源不足时会失败并写入对应结构化事件。
- “指派行动”下拉可直接选择 `work_clinic_doctor` 和 `receive_clinic_treatment` 验证 T0808 小诊所：先让医生进入诊所医生工位，再让受伤且未昏迷 NPC 进入病床，治疗会随逻辑时间扣第纳尔并恢复 HP；若医生在岗但没有病人，会研读医学著作并缓慢提升医术。
- 通过行动分组内的“修复目标”建筑下拉选择目标，再指派 NPC 协助该建筑的修复；协助修复是一个统一行为，建筑由该下拉或命令参数决定。
- 通过行动分组内的“升级目标”建筑下拉选择目标，再指派 NPC 协助该建筑的升级；协助升级同样是带建筑参数的统一行为。
- 通过行动分组内的“治疗目标”NPC 下拉选择昏迷目标，再指派当前选中 NPC 协助治疗；协助治疗是带目标 NPC 参数的统一行为，目标必须昏迷，每个昏迷目标最多 2 名治疗者。
- 指派吃饭。
- 指派睡觉；可配合“查看 NPC 短期记忆”和同地点 public 事件验证睡觉期间见闻库不更新。

后端 / LLMBridge：

- 后端健康检查，调用 `LLMBridge.check_health()` 并刷新 HUD 后端状态。
- 对当前选中 NPC 发送 `/npc/dialogue` Mock 请求。
- 对当前选中 NPC 发送带 `is_recruitment_request=true` 的应征 Mock 请求。
- 查看最近一次共享 NPC LLM 上下文注入的目标、调用类型和 `current_order`。
- 该分组只显示后端返回，不写入对话事件、不修改入伍状态。

记忆 / 见闻 / 广场：

- 写入广场公告。
- 查看地点快照；广场快照包含当前在场 NPC 的 `people_statuses`、当前公告和所有建筑外部状态，可进入建筑快照包含该建筑外部 + 内部状态，`people_statuses` 可观察在场 NPC 的生命状态、行动状态和昏迷治疗者。
- 查看 NPC 短期记忆。
- 写入守备官给钱事件。
- 写入守备官攻击 NPC 事件。
- 广场公开广播事件。
- 查看全局事件列表。

上述玩家交互事件写入后，summary 应显示为“守备官给了……”或“守备官攻击了……”，不显示以“玩家”为主语的旧式文本。

## 命令

命令输入框支持以下命令：

```text
help
refresh
snapshot
events
plaza_events
add_resource <resource_id> <amount>
spend_resource <resource_id> <amount>
set_time <day> <hour> <minute> <second>
advance_hour
slowdown [request_id] [scale] [reason]
release_slowdown <request_id>
clear_slowdowns
select_npc <npc_id>
select_building <building_id>
move_npc <npc_id> <building_id>
enter_location <npc_id> <location_id>
set_npc_state <npc_id> <key> <value>
publish_order <npc_id> <text>
order <npc_id>
plan_request
start_proactive <npc_id> <text>
proactive <npc_id>
assign_action <npc_id> <action_id>
work <npc_id> <building_id>
assist_repair <npc_id> <building_id>
assist_upgrade <npc_id> <building_id>
assist_heal <healer_npc_id> <target_npc_id>
eat <npc_id>
sleep <npc_id>
damage_building <building_id> <amount>
repair_building <building_id>
upgrade_building <building_id>
plaza_notice <text>
give_money <npc_id> <amount> [visibility]
attack_npc <npc_id> <damage> [visibility]
damage_npc <npc_id> <damage> [visibility]
recover_npc <npc_id> <game_seconds>
backend_health
dialogue_mock <npc_id> <text>
dialogue_recruit <npc_id> <text>
last_order_injection
memory <npc_id>
location <location_id>
```

常用示例：

```text
add_resource money 20
damage_building wall 15
repair_building wall
assist_repair engineer_01 wall
upgrade_building garden
assist_upgrade engineer_01 garden
damage_npc cook_01 150 local_public
assist_heal doctor_01 cook_01
set_time 2 9 30 0
enter_location cook_01 dining_hall
work gardener_01 garden
work blacksmith_01 blacksmith
work engineer_01 workshop
work stableman_01 stable
work cook_01 tavern
assign_action doctor_01 work_clinic_doctor
assign_action cook_01 receive_clinic_treatment
eat cook_01
sleep priest_01
plaza_notice 今晚所有人都必须留在广场附近。
give_money cook_01 5 local_public
recover_npc cook_01 54000
backend_health
dialogue_recruit cook_01 守备官需要你一起保护大家。
publish_order veteran_deputy_01 守住城门，但先保证自己安全。
order veteran_deputy_01
plan_request
start_proactive cook_01 守备官，我想知道我们还能不能守住这里。
proactive cook_01
memory cook_01
location plaza
events
```

## 维护规则

每次完成任务验证时，Agent 必须判断本次功能是否能被用户直接在主界面看见和手动验证。

- 如果不能直接看见，但它是关键状态、数据、事件、AI、资源、建筑、NPC、时间、战斗、后端或 Prompt 调试能力，就必须给 GM 面板新增或替换入口。
- 如果新实现已经覆盖旧调试能力，应替换旧按钮或命令，不保留误导性的旧入口。
- GM 面板入口应该调用系统已有公开方法或 `debug_*` 方法；不要把数值结算、HP 扣除、记忆写入等权威逻辑写在 GMPanel 里。
- 每次更新 GM 面板时，同步更新本文件的“分组”“命令”和“常用示例”。
- 如果新增 GM 验证脚本或重要文件，同步更新 `docs/MODULE_INDEX.md`。

## 验证

GM 面板当前有专用验证脚本：

```powershell
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

该脚本会加载 `Main.tscn`，检查 GM 按钮和窗口，执行命令验证资源、建筑、时间、NPC 地点、自然语言指令、计划重评估请求/结果、最近 LLM 指令注入、记忆事件和广场公告。
