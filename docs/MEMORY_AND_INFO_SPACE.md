# MEMORY_AND_INFO_SPACE.md

## T0131-P1 工械坊建筑表现的信息边界

- 墙体、屋顶透明、订单图板、工具 / 吊装 / 测量装饰和逐级外观都只是表现，不写事件、见闻、地点状态或制造事实；GM `workshop_art_level` 也只切换画面。
- 工械坊 `people_present` 仍只在 NPC 实体真实跨过门内 / 门外边界后改变，工程位只有抵达并将 `reserved_by` 提交为 `occupied_by` 后才形成室内状态差量。透明后能点击欧文只改变 UI 选择目标，不改变 `current_location`。
- Lv.2 不增加权威工位，因此信息节点仍只公开两个工程位；Lv.3 BuildingSystem 真正升级完成并新增 `workbench_03` 后，才按既有 `building_state_changed / location_status_changed` 链进入室内状态。本步未新增事件 Schema、Prompt、记忆字段或 LLM 请求。

## T0129C-A5-P6d-3 协助治疗事件边界

- 预留治疗名额、目标正式投影、跨门移动和接近站位都不是治疗事实；实体进入合法距离并成功扣除首枚第纳尔后，才写既有 `healing_started`。
- active 治疗仍写既有 `healing_completed / healing_failed`；复苏导致的同步状态变化延迟清理，保证一次逻辑完成只生成既有私有治疗者、私有目标和公开载体三条投影，不重复写第二组完成事实。
- 途中目标复苏 / 失效只写结构化失败并零收费，不把未发生的治疗传播给目标地点。事件类型、payload Schema、传播范围、Prompt 与记忆容器均未改变。

## T0129C-A5-P6b 拜访与地点事件边界

- 路线派发、门外移动和导航标签都不是地点事实。实体真实跨过来源 / 目标门路时，才分别写既有 `location_exited / location_entered`；抵达停留点后才写唯一 `visit_started`。
- 建筑间移动只提交一次来源离开和一次目标进入；完成或停止时的兼容世界交接不补造离开 / 重新进入。途中目标替换、建筑失效或不可达不为未抵达目标写地点或拜访事件。
- `visit_completed` 仍沿既有 3600 秒 active 生命周期写入；本步没有新增事件类型、改变传播范围或修改记忆 / Prompt Schema。

## T0129C-A5-P6a 睡眠事件与首次反思边界

- 固定床 reservation、去宿舍的移动和床边到达都不是睡眠事实；只有床位 occupancy 与 `sleeping_supine` 挂接成功后才写 `sleep_started`，完成时写既有 `sleep_ended`。
- DailyReflectionSystem 仍只累计 NPC `current_action=sleep_in_dormitory` 的 active 时间。同一 21:00 窗口的跨中断累计、1 小时门槛、深睡锁、成功去重和短期记忆水位均未改变；途中不会创建窗口或触发模型请求。
- 停止 / 对话打断不补发疲劳恢复，也不把空间姿态写成记忆。本步未修改事件 Schema、反思 Prompt 或 API。

## T0129C-A5-P5i 礼拜事件边界

- 祭坛 / 祈祷席 reservation、物理赶路和长凳姿态不是祈祷事实；实体到位并提交 occupancy 后，既有 `prayer_started / prayer_joined_mass / prayer_resumed_alone / prayer_completed` 生命周期才可发生。
- 独祷↔参礼转换保留同一席位和累计秒数，不生成失败或重新进入地点；主持正常完成与异常离岗仍使用既有不同 trigger / summary。
- `mass_leader / seated_prayer` 动画不写事件、见闻或虔诚。本步未修改事件 Schema、记忆投影、Prompt 或 LLM 请求。

## T0129C-A5-P5h 训练事件边界

- `work_started` 只在教官 / 学员实体到位并提交工位后写入；pending 路线不写技能成长事实。
- `training_solo / training_coaching / training_student` 仍通过统一 `skill_improved` 管线入库。训练挥剑是表现循环，不写命中、受击或伤害事件。
- 最后一名教官离岗沿用 `training_student_failed_instructor_left` 与 `required_active_action_id=work_training_instructor` 失败上下文，随后释放训练位并恢复旧空间。

## T0129C-A5-P5g 正式诊所服务的信息边界

诊疗桌 / 病床预留、空间路线和床面躺姿仍不是治疗完成事实。实体穿门后才提交地点；工位实际占用后才进入对应正式行动。治疗 HP、资金消耗、医术成长、满血完成和医生离岗失败继续写既有 ActionSystem / MemorySystem 事件，不因动画或 GM 快照额外造事件。患者解除挂接只反映服务已结束，不自行推断康复原因；本步未修改事件 Schema、Prompt 或 LLM 请求。

## T0129C-A5-P1 避战与正式逃离的信息边界

全员战时空间迁移、NavMesh 投影、avoidance 回调和物理坐标变化不新增见闻；非战斗人员仍只在既有规则真正进入 / 结束避战时写 `avoidance_started / avoidance_ended`。空间迁移本身不能被叙述成征召、参战、到达安全地点或离站。

`escape_started.payload.exit_position` 与运行态 `escape_intent.exit_position` 现在记录 NPC 当前坐标世界实际使用的出口：正式战斗中为后门生产导航边界，非正式路径保持旧出口。事件类型和 Schema 未改变，只有实体到达后才继续写既有 `escaped`；对话暂停、复苏和快照不会生成新的逃离事实。本轮不修改 Prompt、LLM 请求或 API。

## T0129C-A4-P4 主厅伤害与失败兼容

仓库到主厅的物理路线和到达解锁不写见闻；只有 BuildingSystem 实际扣除主厅 HP 才产生既有 `building_damaged / payload.building_id=main_hall`。主厅清零继续由既有 GameState `game_over_changed(failure, main_hall_destroyed)` 驱动 HUD 与时间停止，没有新增事件 Schema、记忆事实、Prompt 或 LLM 调用。

## T0129C-A4-P3 仓库伤害事件兼容

破门后四段物理路线、门洞链接、阶段到达与仓库攻击解锁仍是运行调试状态，不写见闻。只有敌人实际抵达仓库并由 BuildingSystem 扣血后，才沿既有 `building_damaged` 写入 `payload.building_id=warehouse`；没有新增事件类型、记忆事实、Prompt 或 LLM 上下文。

## T0129C-A4-P2 正式单敌事件兼容

正式活动敌人出生仍使用既有 `combat_started`，抵门后的实际攻击仍由 BuildingSystem 产生 `building_damaged`，清敌 / 击败仍由 CombatSystem 产生 `combat_ended`。物理路线阶段、NavigationAgent 到达和 `attack_unlocked` 都是运行调试状态，不新增事件类型、不进入 NPC 记忆；因此不会把“正在赶路”误记成“已经攻击”。

## T0129C-A2b-P2–P5 家具挂接正式路线的信息边界

莉娜沿正式路线移动时，诊疗桌 / 病床的预留、床边到达和床面表现都不是地点事实。只有 CharacterBody 真正穿过诊所门内点，NPCSystem 才复用既有地点事务提交 `current_location=clinic` 与 `people_present`；BuildingSystem 的工位占用仍在实际到站后独立提交。

病床 `occupant_anchor / lying_supine` 是提交占用后的表现投影，不写新的事件、见闻、治疗状态或 HP 变化。停止、不可达、建筑失效和昏迷释放占用 / 挂接时，MemorySystem 只接收既有地点与工位状态的真实变化，不根据模型姿态推断“已治疗”。本切片没有修改事件 Schema、Prompt 或 LLM 上下文结构。

P3 对宿舍采用相同边界：艾达真实跨门后才提交 `current_location=dormitory`，床边抵达后才提交 `dormitory_bed_01` 占用，随后显示 `sleeping_supine`。固定床归属、床面姿态与 `current_action=idle` 不会生成“艾达已经睡眠”事件，也不会暂停见闻、恢复疲劳或推进时间；只有未来 ActionSystem 正式睡眠行动才能产生这些事实。本轮未修改 Prompt、模型请求或 API。

P4 对食堂继续采用相同边界：布鲁诺真实跨门后才提交 `current_location=dining_hall`，椅边抵达后才提交具体用餐席占用，随后显示 `sitting`。首个空闲座位和椅面姿态不会生成“布鲁诺已经进食”事件，也不会扣除食物、恢复饱食或改变见闻接收；只有 ActionSystem 正式进食行动才能产生这些事实。本轮未修改 Prompt、模型请求或 API。

P5 对小教堂继续采用相同边界：马塞尔真实跨门后才提交 `current_location=chapel`，长凳边抵达后才提交首个空闲 `chapel_prayer_seat` 占用，随后显示 `seated_prayer`。座位与姿态不会生成“马塞尔正在祈祷”事件、改变见闻或增加虔诚；只有 ActionSystem / PietySystem 的正式祈祷链可以产生这些事实。本轮未修改 Prompt、模型请求或 API。

## T0127 铁匠铺跨门地点与工位见闻

铁匠铺 `people_present` 只在 NPC 真正穿过门内 / 门外边界时变化。门外接近和工位预留不会生成 `location_entered`，穿门后才由既有 `move_npc_between_locations(...)` 写一次离开广场 / 进入铁匠铺事实；离开时直到穿过出口才写相反事实。NPC-NPC 同地点判断、`local_public` 路由、进入者地点快照和 LLM 地点上下文都继续读取这份已提交事实，不读取世界坐标。

工位状态差量现在区分 `reserved_by` 与 `occupied_by`：预留摘要表达“已为某人预留”，抵达后转换为“某人占用中”；二者变化均沿既有 `location_status_changed` 字段级差量进入当时在铁匠铺且可接收见闻的 NPC 信息空间。门外 NPC 不会因为自己的预留收到室内状态快照。升级、失败、中断和昏迷释放预留 / 占用时也产生真实差量，不保留幽灵位置。

昏迷者不会因为行动被终止而被瞬移出地点：若其已经穿门，`current_location=blacksmith` 与 `people_present` 保持，仍遵守昏迷期间不接收见闻、复苏后恢复的原规则。其他建筑尚未迁移，仍按入口抵达时切换地点。

## T0120 初始长期记忆中文润色

已完整检查 8 人的 24 篇初始日记及全部知识图谱 `value_label`。原有主体、关系、置信度、事实、时间、内部 value、职业联系和建筑规则均未改变；只将省略成分、指代不清或搭配生硬的句子改为自然、完整的中文，同时保留各人物第一人称日记和主观知识标签的口吻差异。

守备官开局前关系仍同时表达“平日尽责和睦”“战时尚未经检验”“以后依据实际行为或结果判断”三层含义；每人仍有 3 篇种子日记，知识图谱结构和建筑稳定知识不变。

## T0119 征募与逃离的信息空间边界

`data/npc_initial_long_memory.json` 中 8 名 NPC 对守备官的 `pre_game_relationship` 继续只描述开局前三年的尽责与总体和睦，并新增明确边界：战时征募、装备分配和命令风格尚未经检验，开局后的实际对话、建设、资源、人员、装备、指令、攻击、承诺与战况才决定后续判断。这不是负面开局关系，也不是预写好的信任变化。

公开人物档案和初始关系种子只给玩家可探索线索，不写概率、隐藏难度、需要满足的条件数量、完整说服答案或逃离排序。拒绝回复、日记和知识图谱同样只能表达人格化顾虑与已知经历，不得泄露 Prompt 内部校准规则。

熟睡反思仅处理事实已进入目标 NPC 信息空间的变化。建设 / 资源 / 人员 / 装备 / 指令 / 攻击 / 战况必须能从当前上下文或亲历 / 见闻确认；承诺区分提出、兑现和违背；钱酒只记录赠予行为及人物主观意义，不自动等价为忠诚。未经证实的守备官声称不能成为已完成建设或已兑现承诺。

## T0116 制造失败记忆事实

制造 `work_failed` 的权威 payload 不再用缺失的自由文本 `message` 推断原因。阶段材料不足固定记录 `reason=当前制造阶段材料不足 / failure_reason=insufficient_stage_resources / crafting_error=insufficient_stage_resources`，并携带 `required_resources` 与紧凑 `crafting_project`；缺目标才使用“未选择制造目标”。这些字段会被现有全量紧凑记忆投影保留，熟睡总结无需从含糊 reason 反推阶段或资源。

`crafting_project.completed_stages` 是已完成数量，`current_stage_index` 是从 1 开始的当前阶段序号，两者不得互换。计划对话执行前复核读取当前权威资源 / 制造项目来校验旧意图；旧 `work_failed` 或日记只是历史证据，不能覆盖当前状态。

## T0106 权威记忆与 LLM 紧凑投影

MemorySystem 继续保存完整、可追溯的事件对象：`event_id / actor_ids / target_ids / location_id / visibility / payload` 均不因 Prompt 优化而删除。LLMBridge 只在每次正式 NPC LLM 调用时，从熟睡总结轮转后仍在目标 NPC 当前索引中的全部 `event_log / witness_log` 构造紧凑投影；不做最近 N 条、重要度或相关性截断。

模型侧每条记忆结构为：

```json
{
  "type": "plan_revised",
  "summary": "格伦重新评估了当前计划：因铁料不足先去照料菜园。",
  "importance": 80,
  "day": 3,
  "time": "14:00:00",
  "details": {
    "reason": "铁料不足，无法继续当前制造工序",
    "resource_gap": {"resource_id": "iron", "available": 0, "required": 2},
    "plan_segments": [
      {"from_hour": 14, "to_hour": 16, "action_id": "work_garden", "location_id": "garden"}
    ]
  }
}
```

`summary` 是 MemorySystem 的确定性事实表达；`details` 仅补充摘要没完整表达的原因、资源、数量、前后值、目标与其他决策事实。完整 24 项计划按连续相同行为压成 `plan_segments`；完整地点 / 建筑快照、人员 / 敌我阵容、内部 ID、重复公告 / 日程 / 对话正文及其他已由 summary 表达的大结构不再复制。供应商 Model Adapter 再用外层字段白名单清洗一次，因此旧客户端即使发送 `payload / event_id` 也不会让它们进入模型。

当前七类正式调用（含 T0116 执行前复核）共用这套合同。非反思调用以 `short_memory` 或 `npc.short_term_memory` 保存亲历 / 见闻两个数组；熟睡总结以带 `memory_kind=experienced|witnessed` 的 `day_events` 作为本次快照唯一短期记忆副本，供应商投影删除等价的 `npc.short_term_memory`。反思成功后的快照水位轮转规则不变。

## T0101 守备官开局前知识边界

`guard_officer` 初始主体从 T0061 的单一职责关系扩展为四条：`role`、`arrival_at_station`、`past_before_station`、`pre_game_relationship`。其中“过去未知”必须作为明确键值存在，不能靠缺字段表达；这让六类 LLM 都能区分“没有提供的信息”与“可以自由补全的叙事空白”。

`pre_game_relationship` 只保存开局前的总体印象：在该 NPC 认识守备官以来，守备官一向尽责并与驿站成员相处和睦。它不保存具体三年旧事。开局后真实对话、攻击、赠予、承诺、命令和见闻仍按现有短期记忆与熟睡反思形成新的 `impression / trust / promise / order_style` 等关系；不得反向覆盖或编造开局前三年的事件。

玩家后来明确自述姓名、出身或过去时，只对实际听见 / 得知的 NPC 生效。反思应建立单独的“守备官自称……”关系，而不是把自述写成所有人共享的客观事实；单纯询问“我是谁”不属于自述。

## T0099 对话记录展示与攻击确认边界

NPC 面板“记录”继续读取全局 append-only 事件档案中的已完成守备官会话，底层事件日期、时间、完整 `dialogue_text`、战斗事件与会话 payload 均不修改。T0099 只把玩家展示分组收敛为 `【第X天】`，不再依据 `combat_started / combat_ended` 派生波次阶段标题。

首次攻击确认是 `DialogPanel` 每次打开期间的临时防误触状态，不写事件、见闻或会话 payload。取消确认不会生成 `damage_taken` 或对话行；确认后仍由既有攻击路径先权威扣 HP / 写惩戒事件，再按普通对话或逃离挽留规则处理回复、完整会话和计划判别。

## T0095 熟睡总结快照水位与日记归属

短期记忆轮转使用请求快照水位，不再在异步反思完成时整批清空。`get_npc_short_term_memory_snapshot(...)` 一次返回事件 / 见闻正文及稳定 ID；`clear_npc_short_term_memory_snapshot(...)` 只移除这些 ID，当请求在飞期间出现新事件时，新 ID 保持在当前索引。全局事件库仍 append-only。每次成功总结把本次请求的 `reflection_period.end` 记为下一次起点；失败、没睡够或并发等待都不推进水位。

日记归属与自然触发日期分开：21:00 窗口 `night_<anchor_day>_2100` 产生 `record_label=接到守备命令的第N天`，N 使用锚点日；`trigger_day / trigger_time` 记录真实请求时刻，`reflection_period.start / end` 记录正文允许覆盖的区间。凌晨与深夜在同一自然日完成时可分别归前后两个 N；漏掉一晚时下一篇允许跨日，但不会补造不存在的日记。“接到守备命令”只指公告牌公开传达“我们奉命守住此地”。

## T0094 对话档案、私有打断上下文与夜间窗口

NPC 面板“记录”读取 MemorySystem 的全局事件档案，而不是已经会在熟睡总结后轮转的单人 `event_log` 索引。它只筛选目标 NPC 与守备官已经落库的 `player_npc / escape_intervention` 会话，保留每场 `dialogue_text` 全文；NPC-NPC 对话不混入。显示按事件自身 `day / time` 排序；T0099 起只按日期分组，不再显示波次阶段。

`interrupted_activity_context` 是守备官第一条有效消息打断目标 NPC 时生成的临时、目标私有运行时上下文。它只解释打断前活动、当前计划和计划不变时的暂定恢复项，不调用 `MemorySystem.add_event(...)`，不进入事件库、见闻库、全局事件档案、日记或知识图谱，也不得传播给其他 NPC。会话完成后，真正说过的话仍按既有单条 `dialogue_turn` 规则入库；临时上下文本身不成为一条“守备官打断了你”的虚构事件。

熟睡总结按 `night_<anchor_day>_2100` 窗口去重：窗口从锚点日 21:00 延续到次日 21:00，同窗内实际睡眠秒数可跨多次 `sleep_started / sleep_ended` 累计。达到 1 游戏小时后发起总结，只有长期记忆成功写入并按请求快照轮转短期索引才登记该窗口完成；失败保持可重试。反思记录的 `day / record_label` 使用窗口锚点，实际触发日与时间保存在独立字段中。

## T0092 记忆上下文去重边界

provider 请求只删除同值副本，不删除记忆事实。`npc.long_term_memory.knowledge_graph` 与旧 `npc.knowledge_graph` 完全相同时只保留前者；每日反思的 `existing_diary_entries` 与 `npc.long_term_memory.diary` 完全相同时只保留后者。两份内容不一致时继续同时保留，避免把兼容字段中的独有事实误删。

对话的说话者人物副本和重复轮次字段被移除，但实际说出口的 `speaker_text / dialogue_history`、目标 NPC 自己的长短期记忆、现场上下文和公开信息仍在。反思输出的日记正文、知识图谱值、中文标签与可信度继续由模型生成并按原规则入库；仅 NPC ID 和日期由请求确定性补齐。

## T0088 建筑作业总工期传播边界

建筑开始修复 / 升级时，可传播外部状态除 `condition` 外同时包含 `active_job` 与 `job_total_duration_text`。广场及合法建筑地点的状态差量会形成“本次修复 / 升级预计需要 X 小时 X 分 X 秒”的确定性摘要，使 NPC 后续制定或修订计划时知道工程量级。

只有总工期属于这次状态变化的稳定事实。`remaining_seconds / remaining_text / progress_percent` 不进入逐 tick 事件或见闻广播，避免短期记忆随正常速度倒计时刷屏；它们只在构造当前 LLM 请求时从 BuildingSystem 实时投影。作业完成后外部状态恢复完好 / 受损并清空 active job，不伪造模型完成事件。

## T0087 对话结构化结果入库边界

拆分输出合同不改变对话文本或传播规则，只删除重复决定字段。守备官会话仍可把 `recruitment_result=accept|reject` 绑定到对应 NPC turn；NPC-NPC 邀请 / 正式事件仍记录 `invitation_result / should_end_dialogue`；逃离事件记录 `intervention_result=stay|leave`。事件 payload 不再保存对话通用 `intent`，也不会从 `reply_text` 猜测结构化结果。攻击导致继续逃离时记录程序来源的 `intervention_result=guard_attack_no_reply`，不生成 NPC 选择或回复。

## T0083 对话标题与应征结果边界

完成守备官会话的确定性 summary 标题统一为“守备官与 XX 对话”，不再显示“的完整对话”；标题下仍按 `dialogue_text` 顺序转写所有有效 `speaker_name / text`。

NPC turn 可携带 `recruitment_result=accept|reject`，用于把 UI 结果提示绑定到具体回复。该枚举可以随完整历史保存在事件 payload 中，但“✓ XX接受……” / “× XX拒绝……”表现文案不进入 turn `text`，也不进入事件 summary、短期记忆正文或 NPC 说过的话。

## T0082 完整守备官会话摘要与应征锁

守备官-NPC 完成会话仍只提交一条 `dialogue_turn`，不改为逐轮创建多条事件。此前 `payload.dialogue_text` 已保存整场历史，但 `summary` 只读取最后一条守备官发言与最后一条 NPC 回复，导致 NPC 面板事件库以及使用 summary 的短期记忆表面上只剩最后一轮。现在 `session_completed=true` 时，MemorySystem 按 `dialogue_text` 原顺序确定性展开每个说话者和正文；事件计数、公开广播次数和 payload 结构不变。

守备官第一次在“提出应征”开启时发送消息后，`session_had_recruitment_request=true` 成为本场会话不可撤销的生命周期事实。随后关闭 toggle 只影响后续消息是否继续带应征标记，不允许取消并抹去先前已提出的应征；挂起超时按完成提交完整会话。该锁不新增独立事件类型，最终仍由同一 `dialogue_turn.is_recruitment_request` 表达本场曾提出应征。

## T0078 主动交涉的入库边界

NPC 主动找守备官交涉不能以“取消”丢弃：完成会保存有效会话并进入计划判别；挂起满 2 个游戏小时也按完成收口，因此已说出的主动诉求不会因超时从人物经历中消失。未达到正式会话、问号等待无人响应的既有路径仍不伪造 `dialogue_turn`，只按原规则修改当前计划。

守备官主动发起、尚未攻击且未发送应征消息的普通会话仍可取消，取消后不写 `dialogue_turn`、不广播见闻、不触发判别。是否需要修改当前小时只影响计划范围，不改变事件可见性、亲历 / 见闻路由或长期记忆权威。

## T0071 对话中的人物信息空间隔离

NPC A 向 NPC B 说话时，B 的 LLM 请求只能读取 B 自己的事件库、见闻库、日记、知识图谱、地点上下文和当前指令。A 的私有信息不会因为 A 是当前说话者而自动进入 B 的信息空间；只有 `speaker_text / conversation_history` 中实际说出口的内容，以及当场可观察的外表 / 健康可以被 B 使用。

`local_public` 仍只决定对话轮次完成后的事件广播，不会在模型请求前提前复制双方记忆。行动候选中的程序路由字段也不是见闻来源；`talk_to_npc` 候选已经移除目标实时地点、行动和入伍状态。T0071 不改变 MemorySystem 的存储或传播：格伦合法收到的铁匠铺制造差量继续只保存在格伦及其他合法接收者记忆中，伊沃必须亲历、见闻或在对话中真正听到后才能在后续请求中使用。

## T0070 名册事实与职业知识边界

`station_context.resident_roster` 是每次请求从 NPCSystem 投影的全员当前事实，不是事件、见闻或长期记忆。全体登记成员即使离站也保留在名单中，并用 `recruited / in_station` 区分入伍与在站状态；模型回答“谁入伍、谁仍在站”时应优先读取这两个标签。状态变化本身仍按原有权威事件与见闻路径传播，不能因为请求里出现标签就伪造人物亲历。

初始知识图谱当前共有 226 条关系。新增的训练场教官成长、诊所医生研习、马匹分配 / 随骑手离厩和成餐更耐饱四条关系，以及 8 条升级仓库容量关系，都是已经实现的稳定规则认知；它们不替代当前行动、资源、建筑等级或人物状态。仓库受击丢货仍未实现，因此不进入知识种子。

## T0067 迟到判定与逃离提交的事件边界

低血量 LLM 回复只有在当前战斗实例、NPC 生命状态、HP 阈值、行为模式和战斗资格都仍与请求时一致时，才写入 `battle_psychology_result` 及后续士气 / 逃离事件。被标记为 `discarded` 的迟到结果只保存在 CombatSystem 调试快照中，不进入事件库、见闻库或长期记忆；同一 `wave_id` 重新开始也会因 `started_event_id` 不同被丢弃。

`escape_started` 现在只在 NPCSystem 已原子提交逃离模式并成功启动出口移动后写入。移动预检 / 启动失败、复苏后续逃失败以及会话结束重入均不得伪造逃离开始或心理结果。复苏续逃失败会留下 `escape_intent.status=resume_failed` 的权威诊断状态，再由正常模式分流继续；它不是 NPC 已成功离站的见闻。

真实 Main 对话验收确认：挽留留下写入一次 `escape_intervention_result` 并停止逃离；五轮继续离开各按有效 LLM 回复记录，达到上限后仍保持 `escaping`。避战对话无论是否应征都不写战时心理结果，接受应征和装备后的模式切换继续由征召、装备、避战结束与战斗事件表达。

## T0061 开局历史层级与知识展示边界

开局三篇 `day=0` 日记仍是同一 8 字段记录，不新增历史专用 Schema。“往昔·来站前”保存宏观身世、离开原处的原因和到站时间；“往昔·初到驿站”保存接手的工作与最初遇见的人，并按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜的固定到站顺序互相印证；“往昔·近日”仍是敌情传达前的微观生活。前三篇是开局前既有记忆，不进入第 1 天事件 / 见闻，也不因加载而产生广播。

T0061 当时守备官种子知识只有一条技术键为 `role` 的职责事实；T0101 已在同一主体增加三年前到站、来站前经历未知和开局前尽责和睦三条关系，但仍不预设具体身份、旧事或无条件信任。建筑记录的技术 `value` 继续承载稳定规则语义，中文 `relation_label / value_label` 改为 NPC 在工作和生活中会说出的叙事化常识。T0061 当时仓库容量 / 受击丢货尚未落地，因而只保留集中登记与受袭次序；T0070 已把实现后的按等级容量重新写入知识，受击丢货仍排除。`confidence / day / time` 仍参与初始校验、替换式更新、后端传输与 GM 排查，但 `NPCPanel` 的玩家【知识】弹窗不显示可信度和更新时间。底层元数据与玩家可见文本是两个层次，禁止为了隐藏 UI 而删除字段。

## T0060 日记时间投影与开局前边界

运行态种子日记继续兼容原 8 字段；正式熟睡总结在其上增加 `record_label / summary_window_key / window_anchor_day / trigger_day / trigger_time / reflection_period`。`LLMBridge._build_existing_diary_entries(...)` 是统一文本投影入口：`day=0` 种子形成“往昔·…：正文”，新正式记录形成“接到守备命令的第N天 HH:MM:SS：正文”，旧正式记录仍兼容“第N天 HH:MM:SS”。旧纯字符串和缺元数据记录无需迁移。

六类 LLM 上下文据此前缀理解先后；“往昔·近日”属于守备官收到并传达敌情之前的普通驿站生活，不是当天事件，也不是人物已知敌袭、征召或备战的证据。T0101 后守备官种子条目记录职责、三年前到站、过去未知和开局前尽责和睦；具体身份、旧事及开局后人物看法只能由真实自述、对话、见闻和程序事件形成。知识图谱对 15 座建筑的认识仍是人物已有常识，本职建筑更详细、其他建筑更概括，但都不能覆盖当前 HP、资源、占用、行动资格或结算事实。

## T0059 初始长期记忆与当天事实边界

`npc_initial_long_memory.json` 表达第 1 天开始前已经形成的长期内容，不是新游戏启动时发生的一批事件。三篇 `day=0` 日记保留第一人称感受、语气与人生切片；`updated_day=0 / updated_time=开局前` 的知识图谱保留相对客观的当前认知。它们不进入当天 `event_log / witness_log`，也不会因为装载而广播人物、建筑或关系事件。

T0108 只迁移这份开局前图谱中的稳定建筑认知：删除“器械只能部署围墙 / 围墙升级永不增加位置”的旧事实，改为围墙与主厅都拥有弩床 / 箭塔通用位置，围墙六级为 `1 / 2 / 2 / 3 / 3 / 4`、主厅为 `1 / 1 / 2 / 2 / 3 / 4`，每次升级最多增加一个，主厅位置提供 `2.0x` 射程。装载边界不变：不生成事件、不广播、不写短期记忆，也不新增器械升级事件类型。

初始图谱中的人物印象允许带 NPC 自身视角；守备官条目固定防务职责、三年前到站、来站前经历未知和开局前低细节尽责和睦背景，不伪造具体旧事、承诺、伤害、信任或敌意。建筑条目只是 NPC 对既有规则的理解；实时 HP、资源、建筑状态、工位、装备、入伍、移动和行动结果仍以 Godot 权威系统为准。

首次睡眠反思以当天真实事件 / 见闻为新证据：日记在 3 篇种子之后继续追加；知识图谱只替换被今天事实改变或强化的 `subject + relation`。已有种子本身不是 `day_events`，不得为了“总结今天”无意义复述、改写或覆盖。UI 与 GM 都读取加载后的同一运行态长期记忆，不另建展示副本。

## T0058 公开资源不是事件或个人见闻

`basic_resource_reserves` 是每次 LLM 请求读取的驿站公共基础事实，不写入 NPC 事件库或见闻库，也不通过地点节点广播逐次数值变化。反思可以用当前五项数量理解压力，但不能把当前库存伪造成目标 NPC 亲历的生产 / 消耗事件；真实变化仍必须来自结构化事件或程序状态。升级常识同样不是“某建筑已升级”事实，只有实际行动 / 建筑事件才能进入记忆。

## T0055 未完成活动不生成完成事实

持续活动 / 周期结算规则可以帮助对话和首次睡眠反思理解活动因果，但不能成为新的事件来源。NPC 仅仅记得自己上午在菜园、铁匠铺、诊所或训练场活动，不代表对应周期已经完成，也不代表产出、制造阶段、恢复或成长已经结算。只有正式结构化事件、资源 / 项目状态或其他程序事实确认完成后，日记和知识图谱才能把结果写成已经发生。

离岗或中断后的未完成进度是否保留由具体系统决定，记忆层不自行归零，也不自行延续；尤其不得把“曾经开始”改写为“无人参与时仍在自动产出”。

## T0054 背景规则与记忆事实边界

首次睡眠反思会读取扩充后的 `station_context`，因此 NPC 知道驿站有哪些人、建筑、日常行为，以及敌袭和低士气风险。但 `station_rules` 只是共同世界常识，不能直接生成亲历 / 见闻：例如“士气低落时任何人可能离开”不能被日记或知识图谱写成某人已经逃离。已发生的征召、装备、敌袭、避战、逃离和临阵脱逃仍必须来自 NPC state、短期事件、地点见闻或其他结构化上下文。

建筑与行为目录同样不是广场广播，也不进入事件库。反思可用它们理解已有记忆中的名称和因果，但不得补造名单外建筑、角色或程序未发生的行为。逃离完成者从动态人员目录消失的规则不变；历史记忆可以保留其曾在站和离开的真实事件。

## T0053 计划与战时判定的记忆注入

共享 `NPCContext` 现在显式同时携带 `short_term_memory` 和 `long_term_memory`。短期记忆保持亲历 `experienced_events` 与见闻 `witnessed_events` 的权重区别；长期记忆为 `{ knowledge_graph, diary }`，同时提供结构化当前认知与第一人称经历 / 口吻连续性。旧顶层 `npc.knowledge_graph` 暂时保留为兼容镜像，但新计划、计划修改范围判别、正式修订和低血量战时心理 Prompt 都以 `npc.long_term_memory` 为完整长期记忆入口。对话合同继续使用等价的顶层 `short_memory / long_memory`，目标 NPC 仍由同一运行态资料构造。

记忆是判断与人格连续性的上下文，不改变权威边界：行动失败中的 `failure_type / failure_summary / failure_context / failed_plan_item`、本次低血量事实和 `battlefield_context` 优先作为程序确认事实；模型不能用日记或知识图谱否认失败、伤害、工位、资源、目标状态或战局。判别层只选择需要修订的小时，正式修订只选择合法行动，战时心理层只从 `allowed_decisions` 选择意向。

## T0051 守备官会话的提交 / 丢弃边界

守备官-NPC 对话不再在每次模型回复后立刻生成 `dialogue_turn`。会话历史先保存在 DialogSystem 运行态；玩家选择“完成对话”时，把全文一次性提交为一个 `dialogue_turn`，payload 额外记录 `session_completed`、`ended_while_waiting`、`attack_committed`、完成回复计数和 `interaction_kind`。若最后一条是尚未获回复的守备官消息，`reply_text` 为空但 `dialogue_text` 保留该消息，仍是有效完成会话。

“取消对话”不会调用 `MemorySystem.add_event(...)`，因此目标 NPC 事件库、同地点第三者见闻库和广场公开流都没有本次会话内容；战时 / 逃离结构化结果仍在完成前保持暂存。T0072 后，NPC 已经明确返回的合法应征接受会立即提交 `recruited` 权威状态。T0082 起，任何已发送应征消息的会话都不再允许取消，因此不会出现“已经提出应征却把会话记录丢弃”的分裂状态。完整 `dialogue_turn` 仍只有完成会话时才入库。攻击的 `damage_taken` 是对话外先行权威事实，所以攻击后取消被禁用；逃离挽留无回复攻击会自动完成一条会话事件，同时保留原伤害、逃离加速与轮次事件。NPC-NPC 自主会话仍按既有每轮 `dialogue_turn` 写入，未改成整场提交。

## T0049/T0050 通用判别输入与详情阅读位置

对话分支使用本轮已实际发生的完整对话历史和 NPC 原 24 小时计划，不另建谈话库；行动失败分支使用 ActionSystem / DailyPlanSystem 已结算的权威失败计划项、失败类型 / 摘要 / 必要上下文和原计划，不从记忆中猜测是否失败。两类判别结果都不是世界事件，不写入事件库或见闻库。只打开 / 关闭窗口、未完成的 NPC 回复不进入对话判别；已完成的 NPC-NPC 邀请交换、正式回复和守备官-NPC 回合均可作为输入。`revision_hours=[]` 表示不写 `plan_revised`、不改原计划；只有非空集合进入修订并在真实结果成功应用后写入 `plan_revised`。

NPCPanel 的事件库 / 见闻库详情首次打开时，必须等待文本和滚动容器完成排版后定位到最底部，让最新记录默认可见。弹窗已打开时，新事件 / 见闻造成的增量刷新仍保存刷新前滚动位置，不把正在阅读旧记录的玩家强制拉回底部。

## T0046 日记、中文知识图谱与公告牌广场状态

首次睡眠反思的长期输出只有第一人称日记和替换式知识图谱；不再生成、保存、显示或回注与日记并列的 `memory_summary`。知识图谱保留稳定技术 `subject / relation / value`，同时存储中文 `subject_label / relation_label / value_label`；玩家 UI 一律显示中文，旧数据或异常技术值也只显示中文映射 / 保底。T0061 后【知识】弹窗只显示“主体—关系—中文内容”，不显示记录的 `confidence / day / time`；GM 和后端仍可读取完整原始记录。

广场当前状态新增 `reference_schedule` 和 `schedule_advisory_note`，与 `current_notice` 一起属于公告牌内容。守备官发布实际变化的通告 / 日程时，分别以 `plaza_notice_changed` / `plaza_schedule_changed` 向全站可接收信息的 NPC 广播一次，不受当前地点影响；只变化一页时不广播另一页，相同内容不重复广播。后来进入广场者的 `location_entry_snapshot` 不再携带这三项，避免同一公告牌内容重复进入见闻。日程见闻始终附带“这是通用的建议日程，仅用作参考，不必严格按照这个日程；如有特殊事务，可以自行安排。”。新游戏的初始通告与日程会预先写入全部初始在站 NPC 见闻库；逃离完成者立即从地点人员节点移除，且接收资格会拒绝 `escaped / outside_station`，不会继续收到公告牌内容。

## T0045 属性成长事件叙事

`attribute_improved` 仍是玩家通过属性 `+1` 入口触发的程序权威结算，但记忆中记录已结算的人物成长事实：actor 为 NPC 自身，力量 summary 使用“{NPC}通过锻炼体力，力量从{before}提高到{after}。”，智力使用对应的“锻炼脑力”文案。payload 保留 `attribute` / `attribute_label` / `before` / `after` / `training_kind`，不再保留与新叙事冲突的 `assigned_by`。

## T0044 玩家事件 / 见闻详情白名单

NPCPanel 的事件库和见闻库小框、大号详情统一只向玩家展示 `time + summary`。事件的 `event_id`、`type`、`location_id`、`visibility`、`importance`、actor / target ID 与 `payload` 仍保存在 MemorySystem 权威结构中，继续供广播、短期记忆、LLM 上下文、存档和 GM 调试使用；本次只收敛玩家 UI，不删除或改写底层事实。

## T0105B 跨小时参礼结束事件顺序

整点本身不再产生弥撒结束、祈祷恢复或行动失败事件。主持者和参礼者继续原 active 状态，直到弥撒自然完成或发生外部权威中断。

参礼者个人祈祷时长已经到期时，最终顺序固定为：

1. 主持自然完成；
2. 参礼者写 `prayer_resumed_alone(trigger=mass_completed)`，摘要为“弥撒结束”；
3. 该祈祷写 `prayer_completed` 并释放祈祷席；
4. DailyPlanSystem 才执行积压的当前小时计划。

未到期祈祷也必须先写恢复独祷事件，之后才允许新小时不同计划中断 / 替换它。计划延迟标记不是事件、见闻或模型记忆，不对 NPC 广播；真正开始的新行动继续使用各自既有事件规则。

## T0105A 弥撒结束与中断的事件语义

`prayer_resumed_alone` 的结构化 trigger 是摘要的唯一判据：

- 主持弥撒自然计时完成：`trigger=mass_completed`，摘要写“弥撒结束”。T0105B 后普通计划小时边界只延迟新计划，不再直接结束弥撒。
- 对话、改派、建筑失效等外部原因停止主持：`trigger=mass_leader_stopped`，同时保留实际 `provider_stop_reason`，摘要写“因主持中断而结束”。

DailyPlanSystem 不构造结束事件；普通计划小时边界只延迟新计划，由 ActionSystem 在弥撒真正完成或被外力中断时生成结构化事实。MemorySystem 不读取自由文本 reason 猜测正常 / 中断。两类 `prayer_resumed_alone` 都继续进入祈祷者事件库并按小教堂 `local_public` 广播，且不改变祈祷席、进度或计划身份。

## T0098 祈祷模式转换事件

`prayer_started` 继续表示 `pray_at_chapel` 真正开始，并在 payload 中携带初始 `prayer_mode`。若到达时弥撒已经开始，摘要直接说明 NPC 正在参加弥撒；行动本身仍是祈祷。

弥撒期间的模式转换使用两个稳定事件：

- `prayer_joined_mass`：祈祷者从独自祈祷转为参礼；payload 包含 `action_id / leader_npc_id / trigger / from_mode / to_mode`。
- `prayer_resumed_alone`：主持正常结束或异常退出后，尚未完成的祈祷者恢复独自祈祷；payload 另可包含 `provider_stop_reason`。

两类事件进入祈祷者本人事件库，并按 `location_id=chapel / visibility=local_public` 广播给当时同地点且可接收见闻的 NPC。摘要由 MemorySystem 根据结构化字段确定性生成；模型不补写模式事实。主持者被有效替换时只重绑定，不伪造“弥撒结束 / 恢复独祷”事件。

## T0043A 服务中断与教堂事件语义（教堂部分已由 T0098 替代）

诊所 / 训练依赖失败继续使用各自工作失败事件，并携带 action id、服务者 action id、失败原因及实际释放的位置；“开始时无人服务”和“周期内服务者全部离岗”是不同 failure id。教堂只保留祈祷和主持弥撒两个 action，继续使用 `prayer_started / prayer_completed / prayer_failed` 事件族；参加弥撒是祈祷的内部模式。

弥撒开始、正常结束和异常离岗不再产生祈祷失败；它们使用 T0098 模式转换事件。事件只反映 ActionSystem 已结算结果，LLM 不推断或补写主持 / 参与状态。

## T0043 建筑位置与可用性传播

功能位置的 `id / type / name / occupied_by / status`、位置容量、建筑 `condition / is_enterable` 和运行效率分档都属于建筑状态。NPC 进入室内时获得当前完整位置清单；已经在场且能接收见闻的 NPC 只收到按位置 ID 计算的新增、移除、改名、改类型或占用变化。位置移除用 `removed=true` 表达。室内精确容量与占用不广播到广场，广场仍只接收建筑外部状态。

升级开始时外部状态变为 `upgrading`、`is_enterable=false`、运行效率为停止档；建筑内人员被权威系统退出到广场。升级完成后的等级、重新开放、效率分档和新增位置分别作为字段级变化传播。受损只传播单调效率分档，精确 HP、精确倍率和逐秒升级进度留在 BuildingSystem / UI，避免刷屏。

位置摘要使用玩家可读 `name`，例如“病床2被马塞尔占用”，不再向 NPC 暴露 `treatment_bed_02` 等内部 ID，也不使用“主动 / 被动工位”分类词。

## T0025 行动与自主对话事件

NPC-NPC 自主对话只为真实完成的邀请交换与正式 LLM 回复写 `dialogue_turn`；事件同时进入两名参与者事件库，并按 `private` / `local_public` 与当前地点传播。T0029/T0030 后邀请事件带 `dialogue_phase=invitation`、`invitation_result=accept|reject` 且 `current_round=0`；接受后的正式事件带 `dialogue_phase=conversation`、`max_rounds=0`、软性轮次字段和本轮 `should_end_dialogue`。正式会话无程序硬轮次上限；任一回复带结束标记时，该回复作为最后一句先入库，程序随后结束且不会再发给另一名 NPC。自动续聊不会把上一轮最后一句再次复制进下一事件。T0049 后，已完成的正式会话和邀请拒绝都让两名参与者分别用完整对话与自己的原计划判别 `revision_hours`；未完成的 LLM 请求不写事件，也不伪造对话判别输入。计划行动事件 `prayer_started / prayer_completed / prayer_failed / prayer_joined_mass / prayer_resumed_alone` 与 `visit_started / visit_completed` 分别记录行动、模式转换、地点、工位和持续时间。地点状态快照会把动态 `visit_location_<location_id>` 显示为“停留在某地点”，不再作为未知 action id 报警。

## 模块目标

记忆系统用于让 NPC 记住自身经历、玩家行为、地点见闻、战斗事件和他人公开遭遇，并在后续计划、对话、征召、逃离、战斗判定、首次睡眠反思中产生影响。

本模块的底层不是“给 LLM 拼一段记忆文本”，而是一套类似埋点系统的事件触发、记录和传播架构。游戏中的事实先被程序记录为事件，再按规则进入 NPC 事件库；公开事件会即时广播到地点/建筑信息节点，由节点转发给当时在场的 NPC，并写入接收者的 NPC 见闻库和后续长期记忆。地点/建筑信息节点不是事件仓库。

世界内称呼规则：所有写入 NPC 事件库、见闻库、Prompt 摘要、首次睡眠总结输入、公告/教学信件等 NPC 可见或 LLM 会当作世界内事实理解的文本，均把玩家称为“守备官”。“玩家”只能用于开发文档和调试命令说明；事件 summary 不得输出以“玩家”为主语的出戏表述。

## 核心原则

- 每个事件必须关联一个 `subject_npc_id`，并首先写入该 NPC 的事件库，表示“这件事发生在他身上”。
- 每个事件必须有 `location_id`。室外事件统一归入 `plaza`。
- 事件库和见闻库分开：事件库记录亲历，见闻库记录 NPC 当场接收到的公开事件广播、状态广播、公告和公开消息；NPC 不会因为进入地点而继承该地点过去发生的事件。
- 昏迷 NPC 不接收地点/广场公开广播、状态变化广播、公告或进入快照；其见闻库在昏迷期间暂停更新，直到复苏。亲历事件库不受影响，仍记录受伤、昏迷和复苏等发生在自己身上的事件。
- 睡觉 NPC 与昏迷 NPC 一样不接收见闻；当某 NPC 的 `current_action` 为 `sleep_in_dormitory` 时，同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照都不会写入该 NPC 的见闻库。睡醒并回到可行动状态后，从后续广播开始重新接收见闻，不补收睡觉期间错过的信息。亲历事件库仍记录自己的 `sleep_started` / `sleep_ended`。
- 进入/离开地点的事件库记录只表达行动事实；完整地点状态只作为进入者的一次性见闻，且不再重复写进进入事件。
- 进入地点时，进入者的一次性快照必须包含该地点当前在场 NPC 状态；广场也按地点处理。该状态分为生命状态和行动状态两个平行类别：生命状态只表达健康、受伤、昏迷；昏迷者如有治疗者，写明治疗者是谁。行动状态解析 `current_action` 并翻译成精简中文。
- 除进入者的一次性地点状态快照外，建筑和地点状态见闻只传递变化字段，不重复传递未变化的完整快照。
- 当天事件库 + 当天见闻库共同构成 NPC 的短期记忆。
- 对话全文作为对话事件的属性保存，不单独建立谈话库；A 与 B 的对话轮次首先进入 A 和 B 的事件库，而不是彼此的见闻库。只有 `visibility == "local_public"` 的对话事件，才按地点公开规则广播给同一地点当前在场且可接收见闻的第三者。
- 已入伍 NPC 的当前指令 `current_order` 是 NPC 信息中的持续状态，不属于地点状态。指令内容变化时生成 `private` 的 `order_assigned` 事件，只进入目标 NPC 事件库，不广播到地点或广场；当前指令还应独立注入后续 NPC LLM 请求，不能只依赖事件摘要保留。
- LLM 只解释和回应事件，不负责资源、HP、建筑、战斗等权威结算。
- Mock 只用于开发期验证 LLM 请求 / 响应结构。真实 provider 失败时，不得把 mock 文本写成已经发生的对话、计划、日记或心理结果；只有实际应用的规则 / 模板降级结果才能按明确来源写入事件或长期记忆，原始模型失败留在 usage / 技术日志中。
- 面向 NPC / LLM 的玩家相关事件摘要必须使用“守备官”作为称呼；底层可保留稳定技术 ID，但不把“玩家”作为世界内人物名输出。

## 事件结构

事件通用字段：

| 字段 | 说明 |
|---|---|
| `event_id` | 唯一事件 ID |
| `day` / `time` | 游戏日与发生时间 |
| `type` | 事件类型 |
| `subject_npc_id` | 事件所属 NPC，必填 |
| `actor_ids` | 主动参与者，包含 NPC / 守备官 / 敌人 / 系统 |
| `target_ids` | 事件关联目标索引，包含 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人等 ID |
| `location_id` | 发生地点；室外统一为 `plaza` |
| `visibility` | `private`、`local_public` |
| `importance` | 重要度，用于摘要、筛选和长期记忆压缩 |
| `summary` | 给 UI、调试和短期记忆使用的确定性文本；完成的守备官会话为保留语义而展开完整逐句历史 |
| `payload` | 类型专属结构化属性 |

`target_ids` 不是自然语言里的“宾语”字段。它是程序索引字段，用来支持查询“哪些事件关联了某个 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人”。例如 `location_entered` 的目标可以是地点 ID，`work_started` 的目标可以同时包含建筑 ID 和行动 ID，`resource_changed` 的目标可以包含资源 ID。

`visibility` 规则：

- `private`：只进入 `subject_npc_id` 的事件库。
- `local_public`：进入 `subject_npc_id` 事件库，并即时广播到所属地点/建筑信息节点；节点转发给当时已经在场的 NPC 后不保存该事件。广场是普通地点，因此广场公开信息统一使用 `location_id == "plaza"` 的 `local_public`。

## Summary 生成规则

`summary` 必须由确定性模板生成，不使用 LLM 总结，也不依赖通用主语/宾语规则自动拼句。

每种事件类型必须定义：

- summary 模板。
- 模板需要读取的 `payload` 字段。
- 可选的 ID 展开规则，例如 NPC id 展开为姓名和职业背景，地点 id 展开为显示名，资源 id 展开为中文名。

示例：

| 事件类型 | 模板 | 关键 payload |
|---|---|---|
| `location_entered` | `{actor}进入了{to_location}。` | `to_location_id`, `from_location_id` |
| `location_exited` | `{actor}离开了{from_location}。` | `from_location_id`, `to_location_id` |
| `plan_created` | `{actor}制定了第{day}天的行动计划，包含{work_phase_count}个工作阶段。` | `plan_day`, `items`, `work_phase_count` |
| `plan_revised` | `{actor}重新评估了当前计划：{summary}。` | `plan_day`, `items`, `reason`, `source`, `summary` |
| `work_started` | `{actor}开始在{location}进行{action}。` | `action_id`, `workstation_id` |
| `work_completed` | `{actor}完成了{action}，消耗{inputs}，产出{outputs}。` | `action_id`, `input_resources`, `output_resources` |
| `repair_assist_started` | `{actor}开始协助修复{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `upgrade_assist_started` | `{actor}开始协助升级{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `dialogue_turn` | 完成的守备官会话按 `dialogue_text` 逐句生成 `{speaker}：“{text}”`；其他逐轮对话沿用 `{speaker}对{listener}说：{text}` | `dialogue_id`, `participant_npc_ids`, `dialogue_text`, `speaker_name`, `listener_name`, `speaker_text`, `reply_text`, `visibility`, `current_round`, `max_rounds`, `is_recruitment_request`, `recruitment_result`, `session_completed`；NPC-NPC 邀请额外含 `dialogue_phase`, `invitation_result`，正式回复额外含 `soft_round_threshold`, `soft_round_guidance`, `should_end_dialogue` |
| `order_assigned` | `守备官制定了新的指令。` | `previous_order_text`, `new_order_text`, `order_revision`；T0703 已实现，固定为 `private` |
| `damage_taken` | `{target}受到{actor}造成的{damage}点伤害。` | `damage`, `hp_before`, `hp_after` |
| `combat_alarm_rang` | `{actor}听到了警铃，守备官正在召集所有人。` | `source`, `npc_count`, `active_enemy_count`；T1103 已实现 |
| `combat_rally_started` | `{actor}作为{unit_type_label}前往{rally_location_name}集结，面向敌人来袭方向。` | `unit_type`, `unit_type_label`, `rally_location_id`, `rally_location_name`, `formation_row`, `formation_index`, `has_mount`；T1103 已实现 |
| `combat_rally_encountered_enemy` | `{actor}在集结途中遭遇{enemy_name}，放弃集结并准备接敌。` | `enemy_id`, `enemy_name`, `distance`, `has_mount`；T1103 已实现 |
| `combat_started` | `敌军来袭：第{wave_number}波，{enemy_count}名敌人逼近驿站。` | `wave_number`, `enemy_count`, `enemy_roster`, `friendly_combatant_count`, `friendly_roster`；T1106 已实现 |
| `combat_ended` | `敌人已经全被消灭，第{wave_number}波战斗结束。受伤：{injured_npcs}。昏迷：{unconscious_npcs}。击退敌人：{defeated_by_npc}。` | `wave_number`, `enemy_count`, `injured_npcs`, `unconscious_npcs`, `low_hp_judgements`, `defeated_by_npc`, `reason`；T1106 已实现，T1202 起可包含低血量判定记录 |
| `npc_mode_changed` | `{actor}从{from_mode_label}切换到{to_mode_label}，原因：{reason}。` | `npc_id`, `from_mode`, `from_mode_label`, `to_mode`, `to_mode_label`, `reason`；T1103A 已实现，T1103D 起不覆盖 `work <-> combat` 与 `work <-> avoid_combat` |
| `avoidance_started` | `{actor}发现{enemy_name}接近，正朝{target_name}避战。` | `enemy_id`, `enemy_name`, `distance`, `reason`, `target_id`, `target_name`, `target_position`；T1103B/T1103C 已实现 |
| `avoidance_ended` | `{actor}不再避战，回到驿站日常安排。` | `reason`, `active_enemy_count`, `target_id`, `target_name`；T1103B/T1103C 已实现 |
| `escape_started` | `{actor}开始朝{exit_target_name}逃离驿站。` | `npc_id`, `source_event_id`, `trigger`, `interaction_context`, `from_mode`, `exit_target_id`, `exit_target_name`, `exit_position`；T1203 已实现 |
| `escaped` | `{actor}已经从{exit_target_name}离开了驿站。` | `npc_id`, `exit_target_id`, `exit_target_name`, `source_event_id`, `trigger`, `reason`；T1203 已实现 |
| `escape_intervention_result` | `{actor}被守备官挽留下来，停止逃离驿站。` / `{actor}听完守备官的话后，仍继续逃离驿站。` | `npc_id`, `decision`, `intervention_result`, `current_round`, `max_rounds`, `rounds_left`, `dialogue_id`, `dialogue_event_id`, `reply_text`, `speed_multiplier`；T0087 后不再含通用 `intent` |
| `escape_speed_changed` | `{actor}收下守备官给的钱，逃离脚步慢了下来。` / `{actor}被守备官攻击后，逃离脚步更急了。` | `npc_id`, `trigger`, `speed_multiplier_before`, `speed_multiplier_after`, `amount`, `damage`, `source_event_id`；T1204A 已实现 |
| `low_hp_triggered` | `{actor}被打到残血，HP 从{hp_before}降到{hp_after}。` | `hp_before`, `hp_after`, `max_hp`, `damage`, `damage_source`, `damage_event_id`, `behavior_mode`, `combatant_decisions_allowed`；T1202 已实现 |
| `morale_boost_started` | `{actor}被守备官的话激起了斗志，攻击和移动暂时提升。` / `{actor}在残血压力下激起了斗志，攻击和移动暂时提升。` | `source_event_id`, `trigger`, `duration_seconds`, `attack_bonus`, `move_speed_bonus`；T1201 已实现，T1202 起支持低血量来源 |
| `morale_boost_ended` | `{actor}的斗志激昂状态消退了。` | `source_event_id`, `duration_seconds`；T1201 已实现 |
| `battle_psychology_result` | `{actor}在战斗压力下作出了判断：{decision}。` | `trigger`, `decision`, `source_event_id`, `low_hp_event_id`, `battlefield_context_summary`；T1201 已实现战时对话来源，T1202 已实现低血量来源 |
| `healing_started` | `{healer}开始在{location}协助治疗{target}。` | `healer_npc_id`, `target_npc_id`, `money_spent` |
| `healing_completed` | `{healer}结束了对{target}的治疗。` | `healer_npc_id`, `target_npc_id`, `money_spent` |
| `healing_failed` | `{healer}对{target}的治疗因{reason}中止。` | `healer_npc_id`, `target_npc_id`, `money_spent`, `reason` |
| `revived` | `{target}在{location}苏醒了。` | `hp_before`, `hp_after`, `recovery_source` |
| `skill_improved` | `{actor}在{location}训练或工作，{skill}略有长进。` | `skill_name`, `amount`, `reason`；T0904 后 payload 还包含 `experience_gained`、`total_experience`、`skill_points_gained`、`unspent_skill_points` |
| `attribute_improved` | `{actor}通过锻炼体力 / 脑力，{attribute}从{before}提高到{after}。` | `attribute`, `attribute_label`, `before`, `after`, `training_kind`；技能点仍由玩家通过权威入口分配，不由 AI 自动消耗 |
| `merchant_arrived` | `{merchant_name}在{arrival_time}抵达后门，将停留到{departure_time}。` | `merchant_id`, `merchant_name`, `arrival_time`, `departure_time`, `visit_day`；T1507 已实现 |
| `merchant_departed` | `{merchant_name}在{time}离开了后门。` | `merchant_id`, `merchant_name`, `arrival_time`, `departure_time`, `visit_day`；T1507 已实现 |
| `merchant_trade_completed` | `守备官从商人处购买了{amount}份{resource_name}，支付了{total_price}枚第纳尔。` / `守备官向商人出售了{amount}份{resource_name}，获得了{total_price}枚第纳尔。` | `merchant_id`, `direction`, `resource_id`, `resource_name`, `amount`, `unit_price`, `total_price`, `money_delta`, `resource_delta`；T1507 已实现 |
| `defense_device_deployed` | `守备官把{device_name}部署在{slot_name}，消耗了{inventory_cost}份工程器械库存。` | `deployment_id`, `device_id`, `device_name`, `slot_id`, `slot_name`, `building_id`, `inventory_resource_id`, `inventory_cost`；T1508 已实现 |
| `defense_device_triggered` | `守备官部署的{device_name}攻击了{target_enemy_name}，造成{damage}点伤害。` | `deployment_id`, `device_id`, `device_name`, `slot_id`, `target_enemy_id`, `target_enemy_name`, `damage`, `hp_before`, `hp_after`, `defeated`；T1508 已实现弩床 / 箭塔触发 |

`actor_ids`、`target_ids` 和 `location_id` 负责保留稳定事实属性；summary 模板负责 UI、调试日志和 prompt 摘要。不要把事件系统做成试图从任意主宾关系自动生成句子的万能事件句子生成器。

## 必备事件类型

T0402 的底层架构至少应为以下事件类型预留类型常量、payload 扩展和查询能力：

- 日常与计划：`wake_up`、`plan_created`、`plan_revised`、`reflection_started`、`sleep_started`、`sleep_ended`。
- 移动与地点：`location_entered`、`location_exited`。
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`、`wine_consumed`、`prayer_started`、`prayer_completed`、`prayer_failed`、`prayer_joined_mass`、`prayer_resumed_alone`、`visit_started`、`visit_completed`。
- T0051 后，守备官-NPC 对话按完整会话记录：玩家发送的消息立即进入会话缓冲，“完成对话”时把当前完整历史写成一条 `dialogue_turn`；等待中的 NPC 回复会被取消且不补写。取消或无攻击的挂起超时不入库、不广播、不触发判别。NPC-NPC 自主对话仍按实际完成轮次记录。NPC 主动交涉的发起意图写入 `proactive_talk_started`，预设开场问题随完整会话在完成时入库，不再在点击气泡时单独写 `proactive_talk_message`。
- 玩家交互：`money_given`、`wine_given`、`equipment_given`、`equipment_changed`、`order_assigned`。`order_assigned` 固定为 `private`，完整新旧指令写入 payload。正式守备官惩戒攻击写入 `damage_taken`，并在 payload 中保留惩戒语境、攻击者和后续对话关联；`npc_attacked_by_player` 仅作为旧调试 / 兼容事件类型保留。
- 主动交涉：`proactive_talk_started` 记录 NPC 发起交涉及计划中确定的问题，固定为 `private`。`proactive_talk_message` 仅作为旧事件类型兼容保留；当前玩家点击气泡后的开场内容随完成会话的 `dialogue_turn` 入库。
- 成长与状态：`skill_improved`、`attribute_improved`、`npc_recruited`、`npc_left_recruited_state`。
- 战斗与行为模式：`npc_mode_changed`、`combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy`、`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`battle_psychology_result`、`morale_boost_started`、`morale_boost_ended`、`avoidance_started`、`avoidance_ended`、`unconscious_started`、`healing_started`、`healing_completed`、`healing_failed`、`revived`、`escape_started`、`escaped`、`escape_intervention_result`、`escape_speed_changed`。
- 建筑与资源见闻：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`。
- 公告与商人：`plaza_notice_changed`、`merchant_arrived`、`merchant_departed`、`merchant_trade_completed`。
- 工程器械：`defense_device_deployed`、`defense_device_triggered`。

第一版实现可以只接入少量现有行动事件，但接口与数据结构不得把未来事件类型堵死。

## 当前实现状态

T0402 已实现结构化事件底座，T0403 已实现地点信息节点与进入快照，T0404 已实现广场公开信息即时广播，T0405 已实现 NPC 短期记忆容器：

- `MemorySystem` 是当前事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询。地点/广场节点不应成为事件历史存储，MemorySystem 也不提供按地点查询事件的长期接口。
- `add_event(event)` 会规范化事件字段，补齐 `event_id`、`day`、`time`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary` 和 `payload`，并要求事件具备 `subject_npc_id`。
- 每个事件首先写入 `subject_npc_id` 对应 NPC 的当天事件库；`local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库。广场事件也走同一规则，地点为 `plaza`。
- 现有 `ActionSystem` 已写入 `work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`、`sleep_started`、`sleep_ended` 和工作 / 训练 / 诊所成长使用的 `skill_improved`。T0904 后 `skill_improved` payload 同步记录经验和技能点变化；玩家把技能点分配到力量或智力时，`NPCSystem` 写入 `attribute_improved`，固定为 `private`，T0045 后其 actor / summary 按 NPC 自身锻炼成长表达。工作/训练/吃饭/睡觉按 `local_public` 写入，会即时广播给同地点当前在场 NPC 的见闻库；协助修复/协助升级也按 `local_public` 写入，事件地点为 `plaza`，会广播给广场当前在场 NPC。`NPCSystem` 到达地点时写入 `location_entered`。
- T1001 起，`DailyPlanSystem` 生成每日计划时写入 `private` 的 `plan_created` 事件。T0022 后，正式开局和正式新一天只有在真实 LLM 计划成功时才写入该事件，payload 包含 `plan_day`、24 个小时计划项 `items`、`source=llm_plan_day` 和 `work_phase_count`。真实 provider 失败时不写入 `plan_created`，不生成 `rule_plan_fallback`；`rule_default` / `mock_plan_day` 只可来自显式调试入口。该事件只表示 NPC 制定了计划，不代表其中任一行动已经完成。T0049 后，对话判别空结果不写事件；只有真实 provider 恰好返回并成功应用 `revision_hours` 指定项后，才写入 `private` 的 `plan_revised` 事件。payload 记录合并后的 24 小时计划、触发原因、修订小时、`source=llm_plan_revision` 和摘要。Mock、provider 失败或本地校验失败都不写该事件，也不覆盖原计划。该事件仍不代表资源、HP 或工作产出已结算。
- 已提供 `get_all_events()`、`get_npc_daily_events(npc_id)`、`get_npc_witness_events(npc_id)`、`get_npc_short_term_memory(npc_id)`、`get_npc_short_term_memory_ids(npc_id)`、`get_plaza_events()` 和对应调试接口。
- T1004/T1005 起，`clear_npc_short_term_memory(npc_id)` 可整批清空指定 NPC 当天事件库和见闻库索引，现仅保留给显式调试和旧调用兼容。T0095 后正式熟睡总结改用 `get_npc_short_term_memory_snapshot(...)` 与 `clear_npc_short_term_memory_snapshot(...)`，只轮转请求快照内的稳定 ID，异步期间新增的事件 / 见闻留待下一篇；两种清理都不删除 `_events_by_id` 和全局事件列表。
- 玩家非对话交互可通过 `record_player_interaction(...)` 写入目标 NPC 事件库，并按 `private` / `local_public` 可见性即时广播；当前已有 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)` 用于验证给钱与攻击事件。T0704 后，给钱由 `NPCSystem.give_money_to_npc(...)` 扣除全局第纳尔、增加目标 NPC 随身金钱并写入 `money_given`。T0063 后，紧邻入口的给酒由 `give_wine_to_npc(...)` 扣除驿站酒、增加个人持酒并写 `wine_given`；NPC 开始 `drink_wine` 时实际扣除 1 份个人酒并写 `wine_consumed`。该事件摘要可以影响后续语境，但不删除长期记忆或创建情绪数值。T1006/T0051 后，正式玩家攻击入口位于 `DialogPanel`：普通对话里的攻击按钮复用 `NPCSystem.apply_damage_to_npc(...)` 立即写入带惩戒文案的 `damage_taken`，随后请求 NPC 回复；攻击锁定取消，完成时把已有攻击行和已返回回复一起写入会话 `dialogue_turn`，未返回的回复不伪造。逃离挽留攻击只写 HP 伤害、`escape_speed_changed` 和轮次状态，不请求 NPC 回复，但会自动完成并写入以攻击行为结尾的会话 `dialogue_turn`；不写未发生的 NPC 回复或 `escape_intervention_result`。T0901 后，装备武器/盔甲/坐骑由 `EquipmentSystem` 结算库存与槽位，再复用 `record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`。
- T0501 起，NPC 权威扣血由 `NPCSystem.apply_damage_to_npc(...)` 写入 `damage_taken`；HP 清零时额外写入 `unconscious_started`，并按 NPC 当前信息地点以 `local_public` 广播给同地点 NPC。T0502 起，NPC 自然恢复到 Max HP 30% 后写入 `revived`，同样按当前信息地点以 `local_public` 广播给同地点 NPC。T0503/T0025 起，协助治疗写入 `healing_started`，目标完成时写 `healing_completed`；中途第纳尔不足或离开目标地点写 `healing_failed`，不得伪装为完成。三类事件都会同时进入治疗者和目标 NPC 的事件库，并写入同地点其他在场 NPC 的见闻库；治疗事件不在 payload 或 summary 中暴露医术熟练度。昏迷目标自身仍不接收见闻，但其亲历事件库会记录治疗事实。GM `attack_npc` / `damage_npc` 现在调用 NPC 扣血接口；`debug_record_player_attack_npc(...)` 只保留为记忆交互调试入口。
- T1103 起，`CombatSystem.trigger_combat_alarm(...)` 会给所有 NPC 写入 `combat_alarm_rang` 私有事件；只有入伍、持主武器且当前可行动的 NPC 会继续写入 `combat_rally_started`，并被移动到城门外防线。若集结途中遇到敌人，系统写入 `combat_rally_encountered_enemy` 并将 NPC 切到 `combat_ready` 占位。上述事件只记录警铃、集结和接敌事实，不代表战斗已经完成。
- T1104 起，`attack_made` 记录我方 NPC 对敌人完成的一次程序结算攻击，payload 包含攻击者、目标敌人、武器、力量 / 熟练度输入、原始攻击力、防御、实际伤害、敌人 HP 前后值和是否击退敌人。敌人攻击 NPC 仍复用 `damage_taken`，并可在 payload 中保留 `raw_attack_power`、`target_defense` 和 `damage_after_defense`。这些事件只记录程序已应用的 HP 事实，不让 LLM 决定攻击力、防御或扣血。
- T1106 起，敌人波次生成后写入广场 `combat_started`，payload 记录波次、敌军 roster、我方已入伍持主武器战斗人员 roster 和非战斗人员数量；敌军全灭、撤退或 GM 清敌后写入广场 `combat_ended`，payload 记录本场受伤 / 昏迷 NPC、各 NPC 击退敌人数量和结束原因。两类事件都使用确定性 summary，不让 LLM 决定敌人、伤害、HP 或胜负。
- T1103A 起，`npc_mode_changed` 记录需要留痕的程序权威模式切换；事件只记录程序已应用的事实，LLM 输出本身不直接写入权威数值。T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 的互转不再写入 `npc_mode_changed`，也不因该事件向地点广播；具体事实由 `attack_made`、`damage_taken`、`avoidance_started`、`avoidance_ended`、警铃、集结、昏迷和复苏等事件表达。T1103B/T1103C 起，`avoidance_started` / `avoidance_ended` 记录非战斗人员的避战移动阶段、按敌方方位生成的短步长目标、触发敌人和退出原因。T1201 起，战时公开对话的结构化结果写入 `battle_psychology_result`，斗志激昂 buff 的开始和结束写入 `morale_boost_started` / `morale_boost_ended`；T1202 起，低血量事实写入 `low_hp_triggered`，低血量自身心理判定结果写入 `battle_psychology_result`，低血量来源的斗志激昂同样写入 `morale_boost_started(trigger=low_hp)`；T1203 起，逃离开始 / 离站完成分别写入广场公开 `escape_started` / `escaped`；T1204A 起，逃离挽留 stay/continue 结果写入 `escape_intervention_result`，给钱减速和守备官攻击加速写入 `escape_speed_changed`；T1204B 起，逃离攻击只写速度变化，不再额外生成 `escape_intervention_result` 或攻击回复对话事件。
- T1205 起，`tools/verify_battlefield_public_info.gd` 作为战场公开信息综合验收脚本，覆盖广场旁观者见闻、NPC 面板见闻显示、LLMBridge 对话 payload 的 `witnessed_events`、敌我人数、集结 / 避战 / 低血 / 战时心理 / 击退 / 昏迷 / 治疗 / 复苏 / 逃离 / 建筑受损 / 战斗结束事件，并确认 `work <-> combat` 与 `work <-> avoid_combat` 仍按降噪规则不广播 `npc_mode_changed`。
- T0502A/T0046 起，`add_witness_event(...)` 会拒绝给昏迷或已经离站的 NPC 写入见闻，因此昏迷者不会收到地点 / 广场公开广播、状态广播、公告或进入快照，复苏后自动恢复；`escaped / outside_station` 则永久停止接收，逃离完成时同时从全部地点 `people_present` 移除。
- 玩家非对话交互的运行时 actor id 通常使用 `guard_officer`，summary 使用“守备官”，避免把“玩家”写入 NPC 记忆或后续 LLM 参考文本；T0045 的 `attribute_improved` 是成长事实例外，actor 为成长的 NPC 自身。
- T0701/T0051 已由 Godot `DialogSystem` 接入后端对话文本并写入事件库。NPC-NPC 每个实际完成轮次是一条 `dialogue_turn`；守备官-NPC 则在“完成对话”时把完整历史写成一条会话事件。若 `visibility == "local_public"`，事件地点只向同地点非参与者广播一次，避免重复见闻。
- T0705/T0051 已接入 NPC 主动交涉事件：触发主动交涉时，`proactive_talk_started` 以 `private` 写入发起者事件库，payload 保存 `prompt_text` 和持续时间；玩家点击气泡后开场问题只进入会话缓冲，随后随完成会话的 `dialogue_turn` 一并记录，取消则如同未发生对话。
- `NPCPanel` 会分开显示当前 NPC 的事件库和见闻库，并使用固定高度滚动区展示完整记录；大号详情首次打开在排版后滚到最新记录，已打开时的增量刷新保留阅读位置。调试工具可通过 `debug_get_npc_short_term_memory(...)` 区分查看两类记录。
- `MemorySystem` 当前维护广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊的信息节点，保存 `people_present` 和进入快照所需的当前状态；只有广场额外保存公告牌当前通告、参考日程和非强制备注。`move_npc_between_locations(...)` 维护当前在场人员并给进入者写入一次 `location_entry_snapshot` 见闻，`remove_npc_from_all_locations(...)` 在逃离完成时清理离站者。进入广场见闻快照只表达在场 NPC 及其生命 / 行动状态和所有建筑可传播外部状态，明确剔除公告牌三项；广场权威当前状态仍完整保存三项，供公告牌 UI、GM 与只读系统查询。面向单个 NPC 的 `current_order` 不进入地点信息节点。
- 所有建筑都有可传播外部状态：`level`、`condition`（`intact` / `damaged` / `repairing` / `upgrading`）、`is_enterable` 和运行效率分档。HP、Max HP、精确效率及修复/升级剩余时长仍可由建筑系统和 UI 查询，但不直接触发高频见闻。广场和可进入建筑都会在进入快照中暴露当前在场 NPC 的生命状态/行动状态；可进入建筑额外拥有逐位置内部状态，位置容量变化也参与状态比较。不可进入建筑不向地点快照暴露位置或内部 NPC。
- 广场快照没有自身建筑 HP，但通过 `building_external_states` 继承所有建筑的可传播外部状态；`key_entities` 当前作为兼容别名指向同一组外部状态。室外或不可进入实体来源的公开事件默认归入 `location_id == "plaza"` 并使用 `local_public`。
- T0065 后，主厅前公告牌双页分别调用 `MemorySystem.set_plaza_notice(...)` / `set_plaza_reference_schedule(...)`：实际变更会更新广场当前状态，并生成一条 `plaza_notice_changed` / `plaza_schedule_changed`，由 MemorySystem 按事件类型向全站当前可接收见闻的 NPC 广播；相同内容不重复广播。summary 分别使用“守备官更新了通告”与“守备官更新了参考日程”，新内容保留在各自 payload 中。公告牌只是输入 / 显示接口，不是建筑信息节点。任一建筑的可传播外部状态变化仍生成带具体建筑名和具体状态的 `plaza_status_changed` 广场公开状态事件，只由当时在广场的 NPC 接收；summary 不使用“建筑状态更新”这类空泛前缀。
- T1507 后，MerchantSystem 在商人到达、离开和成功交易时分别生成 `merchant_arrived`、`merchant_departed`、`merchant_trade_completed`，均为 `location_id == "plaza"` 的 `local_public` 事件。交易事件只记录 ResourceSystem 已完成的资源事实；余额/库存不足等失败不写成功事件。
- T1508 修订后，DefenseDeviceSystem 成功部署时以 `guard_officer` 为 `subject_npc_id` 写入 `defense_device_deployed`，不绑定部署 NPC，也不进入任何 NPC 的亲历事件库；事件仍按广场 `local_public` 规则广播给当前在场 NPC，失败部署不写成功事件。弩床 / 箭塔实际造成程序伤害后再写 `defense_device_triggered`，payload 只记录 CombatSystem 已结算的敌人 HP 事实。
- `location_entered` / `location_exited` 事件库记录只保留进入 / 离开的行动事实；完整地点状态不再重复塞入亲历事件。进入者通过见闻库获得一次当前状态快照：进入广场时接收广场当前在场 NPC、广场在场 NPC 的生命状态 / 行动状态和所有建筑外部状态，不接收公告牌当前通告、参考日程或非强制备注；进入可进入建筑时接收该建筑完整外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态 / 行动状态和工位占用。已经在场的 NPC 只接收“某人进入 / 离开某地”的 `local_public` 事件，不再额外收到完整在场 NPC 列表或完整人员状态列表。
- 后续地点或建筑状态变化只写入变化字段对应的见闻，不重新广播完整地点快照。例如建筑受损只广播受损，升级只广播等级变化，单个工位占用变化只广播该工位变化；未变化的建筑等级、工位、公告和在场人员不重复进入见闻库。广场建筑状态见闻使用 `changed_fields`，可进入建筑内部工位变化使用 `changed_workstations`。
- T0035/T0037 后，`MemorySystem` 已按白名单读取、缓存和比较 `special_state`，制造整数阶段 / 目标与在厩马匹数量只在对应室内形成进入快照和字段级差量；小数制造进度和逐匹马详情不进入信息节点。
- 主厅、围墙、城门、后门、仓库不作为常规进入空间；NPC 移动到这类实体时，信息节点状态归入广场快照。

## T0035/T0037 建筑内部特殊状态传播（当前实现）

`internal_state.special_state` 是可进入建筑的内部当前状态，不是新的全局公告或建筑外部状态。它必须按建筑类型使用固定白名单：

- 铁匠铺 / 工械坊：`production.target_item_id`、`target_name`、`completed_stages`、`total_stages`、`current_stage_index`、`current_stage_name`。
- 马厩：`horses.total`、`adult`、`foal`；三项只统计物理上仍处于马厩的马。

传播严格复用现有地点信息规则：

1. NPC 进入对应建筑时，在一次 `location_entry_snapshot` 见闻中获得当时完整的白名单 `special_state`，但不会继承此前换项目、阶段完成、马匹出生或离厩的历史事件。
2. 状态变化时，只给当时仍在该建筑、未昏迷且未睡觉的 NPC 写入 `location_status_changed` 字段级见闻；`reason=building_internal_special_state_changed`，差量放在 `changed_special_state`。没有变化的字段不得重复写入。
3. 状态不复制到广场 `building_external_states`，不生成 `plaza_status_changed`，不向建筑外 NPC 实时广播。NPC 离开后只能保留自己已经接收的见闻，不能继续获得该建筑后续实时差量。
4. 制造工作周期的小数进度只供玩家建筑面板显示，不进入 NPC 信息空间，避免逐秒刷写见闻。马名、个体 HP、饱食度、成长、进食状态、分配 NPC 和骑乘者同样不进入马厩信息节点；玩家面板直接读取 HorseSystem。
5. 具体武器、盔甲、箭束和工程器械库存仍由 ResourceSystem / 制造系统权威保存，不作为铁匠铺或工械坊 `special_state` 的附加字段。NPC 只有在其他合法事件、对话或后续专门信息入口中得知库存变化，不能因位于建筑外而自动获得制造项目实时状态。

制造或马匹系统只提交权威当前状态，MemorySystem 负责白名单裁剪、快照、差量比较、接收者资格和中文摘要；UI 不得自行写见闻。昏迷 / 睡觉接收禁令与当前地点广播规则完全一致，不补收错过的差量。

T1004/T1005/T1405 已实现首次睡眠总结、日记写入、知识图谱替换式键值更新和指定 NPC 短期记忆清空；T1506 已实现正式公告输入 UI，T1508 已实现工程器械部署 / 触发事件。独立知识图谱更新服务仍由后续任务推进，旧式“地点继承历史事件”不再作为后续目标。

T0004 后，GM 面板已暴露记忆/见闻相关调试入口，便于在 `Main.tscn` 前端验证此前主要依赖脚本的能力：查看地点快照、写入广场公告、广播广场公开事件、记录守备官给钱/攻击事件、查询 NPC 短期记忆、触发首次睡眠总结、查看长期记忆、LLM 状态和全局事件列表。GM 面板只调用现有系统接口或 `debug_*` 接口，不新增独立记忆事实源。

## 三层信息结构

### 1. NPC Event Log

每个 NPC 拥有当天事件库，记录发生在自己身上的事件。

示例：

- 醒来并开始制定计划。
- 进入食堂。
- 离开宿舍。
- 与守备官或其他 NPC 对话，完整对话内容、说话者名称、听者名称、公开性和轮次信息写入事件 `payload`。
- 开始/结束工作，产出和消耗由程序结算后写入。
- 被给予金钱、装备，或收到/修改守备官指令。
- 受击、昏迷、治疗、复苏、逃离。

### 2. Location / Building Info Node

每个可进入地点拥有信息节点。地点包括广场和建筑内部。信息节点只保存当前状态并负责广播，不保存事件历史。

地点/建筑信息节点保存：

- 当前有哪些 NPC 在场。
- 当前在场 NPC 的状态：广场和可进入建筑都会在进入快照中保存，生命状态与行动状态并列。生命状态分为健康、受伤、昏迷；昏迷状态如有治疗者则写明治疗者。行动状态来自 `current_action`，但在见闻 summary 中写成短中文。
- 建筑外部状态：等级、`condition`（完好/受损/正在修复/正在升级）、`is_enterable` 和运行效率分档。HP、Max HP、精确效率和剩余修复/升级时长不参与 NPC 传播。
- 可进入建筑的内部状态：每个具体位置的稳定 ID、显示名、类型、空闲/占用状态与占用者，以及当前在建筑内的 NPC；位置新增、移除或改名参与传播。
- T0035/T0037 内部特殊状态：仅按白名单保存铁匠铺 / 工械坊制造项目的整数阶段状态，或马厩内马匹总数 / 成年数 / 小马数；不含制造小数进度或马匹个体详情。该字段已经接入进入快照、室内差量与中文摘要。
- 当前公告或公开备注；只有广场状态保存当前公告文本，公告牌只是输入/显示接口。单个 NPC 的 `current_order` 不属于地点信息。
- NPC 进入地点时应写入进入者见闻库的一次性状态快照。

NPC 进入地点时，系统生成 `location_entered` 事件；该事件写入进入者事件库，只表达“某人进入了某地”。进入者随后在见闻库获得一次当前地点状态快照：进入广场时获得广场当前在场 NPC、广场在场 NPC 的生命状态 / 行动状态与所有建筑外部状态，不含公告牌通告、参考日程或备注；进入可进入建筑时获得该建筑外部状态、当前在场 NPC、建筑内 NPC 的生命状态 / 行动状态、工位 / 床位占用，以及该建筑白名单允许的 `special_state`。进入者不会继承该地点过去发生的公开事件。

`location_entered` 是本地公开事件。地点节点会把进入事件转发给进入前已经在场的其他 NPC；他们只收到“某人进入了某地”这条事件见闻，不再额外收到完整建筑状态、在场人员列表或在场人员状态列表。建筑内“现在有谁”由进入/离开事件自然表达。

NPC 离开地点时，系统生成 `location_exited` 事件；事件 `location_id` 使用离开的地点，写入离开者事件库，并以 `local_public` 转发给该地点仍在场的 NPC。该事件只表达“某人离开了某地”，不附带完整地点状态，也不触发建筑内 NPC 列表广播。

NPC 从一个可进入室内地点前往另一个可进入室内地点时，逻辑事件链必须先经过广场：离开原地点、进入广场、离开广场、进入目标地点。当前低模阶段的物理表现仍可使用直线移动占位，但事件库、见闻库和地点 `people_present` 必须按这条逻辑链更新。

当地点内发生 `local_public` 事件时，事件先进入所属 NPC 的事件库，再发送到地点节点。地点节点把事件即时转发给当前在场 NPC，接收者写入自己的见闻库；转发完成后地点节点不保存该事件。

当地点或建筑状态变化时，见闻库只接收变化字段，不接收完整状态快照。例如建筑受损、封闭 / 重新开放、运行效率分档变化、升级完成、公告变化，以及按位置 ID 表达的新增、移除、改名、改类型或占用变化，都分别生成对应字段级见闻。未变化的等级、在场人员、位置、特殊状态和公告不重复广播。人员进出不再作为“完整内部状态变化”广播，统一由 `location_entered` / `location_exited` 事件表达。

### 3. NPC Witness Log

每个 NPC 拥有当天见闻库，记录自己通过地点/广场广播、公告、状态变化或公共事件获得的信息。

见闻库不同于事件库：见闻不表示“这件事发生在我身上”，而表示“我知道了这件事”。后续对话和反思应能区分亲历与听闻。

昏迷或睡觉期间 NPC 不具备接收现场信息的能力，见闻库不更新；这不会删除既有见闻，也不会阻止其事件库记录自身受击、昏迷、治疗、复苏、入睡、醒来等亲历事件。NPC 复苏或睡醒后，从后续广播开始重新接收见闻，不补收昏迷或睡觉期间错过的历史广播。

进入地点时的一次性地点状态快照也属于见闻库，不属于事件库。除这次进入快照外，后续地点/建筑状态见闻必须保持字段级增量，避免同一建筑状态在短期记忆里反复复制。

## 地点与建筑边界

可进入地点：

- 广场
- 宿舍
- 食堂
- 酒窖
- 菜园
- 铁匠铺
- 训练场
- 马厩
- 小教堂
- 小诊所
- 工械坊


不可进入实体：

- 主厅
- 围墙
- 城门
- 后门
- 仓库

不可进入实体不建立常规室内信息节点。它们只有可传播外部状态，不暴露内部 NPC、工位或床位状态；受损、修复、升级等外部状态变化如果公开，则通过广场节点即时广播。NPC 进入广场时，进入者的见闻库应获得广场当前在场 NPC、这些 NPC 的生命状态 / 行动状态和所有建筑的可传播外部状态，不重复获得公告牌两页；`location_entered` 事件本身只记录进入广场的行动事实。

广场没有建筑 HP，但它是所有室外事件广播、公告当前内容、广场战斗状态、室外人员状态和全体建筑可传播外部状态的公共信息中枢。

## 广场公开见闻

会通过广场信息节点公开广播的事件包括：

- 战斗开始与结束。
- NPC 行为模式变化：进入集结、昏迷、逃离等需要留痕的切换；工作 / 战斗与工作 / 避战互转不作为广播事件。
- 非战斗人员开始避战或敌军清空后结束避战。
- 敌我大致人数。
- 广场或室外发生的公开事件。
- 任一建筑的可传播外部状态变化，包括等级、`condition`、`is_enterable` 或运行效率分档变化。HP 原值、精确效率和剩余修复/升级时长变化不广播；HP 变化如果跨越效率分档，只广播新分档。
- 某 NPC 击倒或击杀敌人。
- 某 NPC 因守备官战时对话斗志激昂或决定逃离。
- 某 NPC 昏迷、被治疗、复苏。
- 某 NPC 逃离或试图逃离。
- 玩家在公开攻击、赠予或对话。

NPC 进入广场时只接收广场当前在场 NPC、这些 NPC 的生命状态 / 行动状态和所有建筑外部状态；不会继承过去已经广播过的广场事件，也不会重复接收公告牌通告、参考日程或备注。公告牌两页只在守备官发布实际变更时分别向全站可接收见闻的 NPC 广播一次。

## 短期记忆

NPC 当天短期记忆由两部分组成：

- `event_log`：自己的亲历事件。
- `witness_log`：自己获得的见闻。

当天任意正式 NPC LLM 调用都注入当前短期索引中的全部两类记录，不按用途删事件，也不截断最近 N 条。程序只压缩单条记录的表示：保留确定性摘要与对决策有意义的紧凑 `details`，省略重复或可由摘要表达的大结构。

- 对话、日计划、计划修改范围判别、正式修订和战时心理分别在目标 NPC 的 `short_memory / npc.short_term_memory` 中读取完整亲历与见闻。
- 熟睡总结读取上次成功总结水位之后、截至本次请求快照仍未总结的全部 `day_events`；范围可以跨自然日，并保留亲历 / 见闻分类。
- 当前状态、库存、地点和战场上下文描述“现在”；记忆按 `day / time` 描述“当时”。模型不得用后来状态覆盖较早事件原因。

## 21:00 窗口熟睡总结

新游戏的首次总结从 3 篇 `source=initial_long_memory` 日记和开局前知识图谱继续生长，而不是从空长期记忆开始。

每名 NPC 在当前 21:00 锚定窗口内累计实际睡眠满 1 个游戏小时后，根据尚未轮转的事件库和见闻库生成：

1. 第一人称日记。
2. 知识图谱当前键值更新。

当前实现（T1004/T1005，调度口径由 T0094 修订）：

- `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`。窗口键为 `night_<anchor_day>_2100`，范围是锚点日 21:00 至次日 21:00；同窗睡眠跨中断累计，21:00 边界切换新窗口。只有总结成功应用才写入完成窗口，失败保留达标状态等待重试；GM 可用 force 调试显式绕过去重。
- `LLMBridge.request_npc_daily_reflection_async(...)` 构造 `DailyReflectionRequest`，传入 NPC 上下文、请求快照内的事件 / 见闻、已有日记、`summary_window` 和 `reflection_period`，异步调用后端 `/npc/daily_reflection`。该接口历史名仍为 daily_reflection，当前玩法语义是熟睡总结；请求会触发 TimeSystem 慢速，不设置 Godot 响应总时长，并在成功、失败、取消、连接 / 空闲错误或模板降级后释放。T0024 后同时符合条件的 NPC 最多 8 路并发；`get_async_reflection_snapshot()` 暴露 21:00 锚点、逐 NPC 当前窗口累计 / 剩余 / 请求状态、已完成窗口和上次成功内容终点。
- 总结请求发起到完成期间，NPC 处于不可打断的深度睡眠锁；对话、消息、行动改派和普通中断都会被拒绝。此期间发布的新指令只保存，计划重评估延后到醒来后。
- 后端不可用或输出无效时，Godot 使用确定性模板生成第一人称日记和最小知识图谱更新，保证睡觉流程不被模型阻断；模板来源必须可见，并在 usage / 技术日志中保留真实 provider 失败原因，不得用 mock 结果伪装模型成功。
- `NPCSystem.apply_daily_reflection(...)` 把 `diary_entry` 追加到 `diary`，并把 `knowledge_graph_updates` 按 `subject + relation` 合并到 `knowledge_graph.by_subject` 当前键值结构；同一键后续更新覆盖旧值，不再保存 append-only `patches`。
- 总结成功应用后，`MemorySystem.clear_npc_short_term_memory_snapshot(...)` 只移除本次请求快照中的事件 / 见闻 ID，并把该快照时刻登记为下一篇的内容起点；请求在飞期间新增的记忆不会被旧回调清除。全局事件档案仍保留给 GM、自动化调试和 NPC 面板“记录”查询。
- `NPCPanel` 通过“日记 / 知识”两个详情按钮分别显示增量日记和当前知识图谱，不在面板正文内嵌日记；总结期间仍显示“正在熟睡”。GM 面板可用 `reflect_npc <npc_id> [force]`、`long_memory <npc_id>`、`reflection_result` 和 `llm_state <npc_id>` 验证，其中 `reflection_result` 同时显示 8 路并发快照。

## 结局总结

T1305 起，胜利和失败进入 `GameState.set_game_over(...)` 后会生成 NPC 结局快照。该快照只用于结算 UI 展示，不写回 NPC 事件库或见闻库，也不改变 HP、入伍、逃离、地点、资源或建筑等权威状态。

当前结局总结为确定性占位文本，字段包括：

- 最终状态：只使用可行动 / 昏迷 / 逃离。
- 是否入伍。
- 最后位置。
- 对守备官最终看法。
- 后续命运。
- 记忆依据：优先取最近一条长期日记；没有日记时取最近亲历事件 summary。

结局文本不得使用“阵亡”或“死亡”描述 NPC；HP 清零后的状态仍统一表达为昏迷。后续接入真实 LLM 结局总结时，也必须保持该权威边界：LLM 只生成主观看法和命运文案，不能反向决定最终状态、HP、逃离或入伍事实。

## 记忆注入原则

初始与私人记忆还遵守两条边界：

- 初始长期记忆只提供历史、职业经验与既有认识；当前程序状态和当天事件优先。
- 目标 NPC 的长期记忆每个请求只注入一次；NPC-NPC 对话不得注入说话者的短期记忆、私人日记 / 图谱、指令或地点私有上下文。

每次 LLM 调用不要注入所有历史，只注入：

- NPC 人设核心。
- 当前状态。
- 当前地点状态和 NPC 已接收的地点相关见闻；只有当前所在铁匠铺 / 工械坊 / 马厩的白名单 `special_state`，或该 NPC 此前合法接收并保留在见闻中的差量可以进入上下文，禁止注入全驿站实时内部特殊状态。
- 当天短期记忆摘要。
- 与当前对话对象相关的知识图谱条目。
- 与玩家相关的高重要性记忆。
- 最近日记和高重要度长期事件。
- 当前守备官指令 `current_order`；它作为持续状态独立注入，不因短期事件摘要裁剪而丢失。
