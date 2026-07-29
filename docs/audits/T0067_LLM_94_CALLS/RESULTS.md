# T0067 可恢复结果总览

本页优先展示可读摘要；完整 JSON 仍以 `direct_matrix_report.json`、`recovered_marker_events.json` 和 `raw_outputs/` 为准。

## 独立定向矩阵：7 次战斗判定

| 场景 | decision | emotion | should_start_escape | debug_reason |
|---|---|---|---:|---|
| battle_single_join_battle | join_battle | resolved | False | 格伦已入伍、有主武器，且守备官命令他拿长杆到主厅与艾达会合。他目睹敌袭，虽非战斗专长但责任感强，认为装备使用者应亲自验证装备在实战中的表现。allowed_decisions只有join_battle，故选择参战。 |
| battle_single_avoid_battle | avoid_battle | tense | False | 马塞尔是非战斗人员，没有武器，已按守备官指令在小教堂避敌。他听到敌袭警报但未亲历伤害，作为神父倾向于留在安全处安抚他人而非逃离。allowed_decisions只有avoid_battle，故选择继续避战。 |
| battle_single_continue_fighting | continue_fighting | resolved | False | 艾达是老兵副官，责任感强，当前伤势虽重但未到守备官划定的撤退界线；两名友军仍在侧翼，敌人也已重伤，局势尚可支撑。她选择继续战斗。 |
| battle_single_escape_station | escape_station | desperate | True | 托马被重创至18HP（低于30%阈值），身边无友军掩护，五名敌人包围。守备官命令不准后退，但托马长期记忆显示守备官前后承诺冲突，且其性格谨慎、不爱逞强，当前处境已无胜算，选择逃离驿站以保全性命。 |
| battle_single_inspired | inspired | resolved | False | 格伦虽首次跌破30%血量，但自制盾牌成功挡住冲击，艾达已到侧翼，最后一名敌人重伤；守备官指令明确且信任其盾牌作用。铁匠的责任感与对装备使用者的保护欲转化为斗志，选择继续战斗。 |
| battle_full_three_way | continue_fighting | resolved | False | 艾达是老兵副官，责任感强，当前仍有24血且持盾剑，守备官命令是‘再守一阵’而非撤退；格伦倒地但托马仍在战斗，敌人仅剩三人且一人重伤，她认为可以继续牵制。 |
| battle_full_two_way | avoid_battle | tense | False | 莉娜是非战斗人员，无主武器，行为模式为避敌。她刚被箭擦伤跌破三成血量，诊所外墙开裂，门外仍有敌人脚步。守备官指令要求她安全时照看伤员、敌人逼近时后撤。作为医生，她优先考虑伤员安全，但当前自身受伤且诊所不再安全，她选择继续避战而非冒险逃离，因为后门路线不明且可能遭遇敌人。 |

## 独立定向矩阵：9 次对话

| 场景 | intent | recruitment_result | wartime_reaction | reply_text | debug_reason |
|---|---|---|---|---|---|
| dialogue_wartime_none | continue_talk | none | none | 伤势不重，左臂被划了一下，不影响握盾。阵位在主厅门前，距城门大约三十步。部署照旧，我守在这里，不会让任何人绕过我。 | 守备官要求报告伤势、阵位和距离，艾达按现状、风险、方案顺序回答，符合务实性格和当前 combat 上下文。 |
| dialogue_wartime_escape | continue_talk | none | escape | 守备官，我伤得太重，马也全跑了。一个人守不住这道门，硬顶只会白送命。 | 托马重伤（17/100），马匹已散，敌人五名合围，当前指令要求死守但实际无法执行，性格谨慎不爱逞强，选择表达逃离意向。 |
| dialogue_wartime_morale | continue_talk | none | morale_boost | 盾没白打就好。缺口我守着，不追。 | combat context, shield just saved two, enemy weakened, order not to pursue, morale high |
| dialogue_avoid_none | continue_talk | none | none | 宿舍里只有我一个人，守备官。没人受伤，我按你说的待在墙角，没靠近窗户。 | 伊沃如实回答守备官询问，符合其安静细致的性格和当前避敌状态。 |
| dialogue_avoid_accept | accept_recruitment | accept | none | 行，守备官。我应征。伤员和热饭我盯着，窄门那边你们自己操心。 | 布鲁诺信任守备官此前兑现了食物优先承诺，且应征后只需留在食堂后间护住伤员和热饭，不直接接战，符合其底线与当前能力。 |
| dialogue_avoid_reject | reject_recruitment | reject | none | 守备官，我理解你的意思，但这两个伤员刚止血，我一旦松手他们几分钟内就会失血而死。我没有武器，也没有战斗训练，空手去城门只会多一具尸体。我不能丢下他们。 | 医生莉娜以病人安全为首位，当前两名重伤员无法离开她；她无武器无战斗技能，应征只会送死，符合人设和边界。 |
| dialogue_escape_stay | stay_after_intervention | none | none | 守备官，我信你上次的承诺。艾达确实封住了路，马也在内栏。我留下照料马匹，不回城门。 | 托马因守备官兑现撤退承诺、艾达封住通道、马匹安全而选择留下；符合其重视责任、不爱逞强的人设。 |
| dialogue_escape_leave | leave_after_intervention | none | none | 守备官，我身上有伤，工械坊的梁柱已经开裂，没有木材根本撑不住。我留下也做不了什么，只会被砸死。抱歉，我必须走。 | 欧文已受伤，工械坊结构危险且无修复材料，连续警告被忽视，当前行为模式为逃离，选择继续逃离。 |
| dialogue_escape_final_round_leave | leave_after_intervention | none | none | 守备官，第五轮了，你仍然没有支撑材料，也没有承诺修复。我负伤了，工械坊随时可能再塌。处罚也好，逃兵也罢，我不能死在一座我警告过四次的危房里。再见。 | 第五轮且是最后一轮，守备官仍无支撑材料或修复承诺；欧文已负伤且结构警告被连续忽视，符合人设中'不在明知结构不安全时认可施工'的底线，选择继续逃离。 |

## Main 场景：从原始函数输出恢复的结果摘要

| 类型 | scenario_id | NPC | 预期 | 实际结构化结果 | 回复/计划摘要 | 是否命中 |
|---|---|---|---|---|---|---:|
| combat_scenario | avoid_continue | doctor_01 | avoid_battle | decision=avoid_battle, psychology_decision=avoid_battle, behavior_mode_after=avoid_combat, escape_status_after= |  | True |
| combat_scenario | avoid_escape | stableman_01 | escape_station | decision=escape_station, psychology_decision=escape, behavior_mode_after=escaped, escape_status_after=escaping |  | True |
| combat_scenario | combat_continue | veteran_deputy_01 | continue_fighting | decision=continue_fighting, psychology_decision=continue_fighting, behavior_mode_after=combat, escape_status_after= |  | True |
| combat_scenario | combat_escape | engineer_01 | escape_station | decision=continue_fighting, psychology_decision=continue_fighting, behavior_mode_after=combat, escape_status_after= |  | False |
| combat_scenario | combat_escape_stableman | stableman_01 | escape_station | decision=continue_fighting, psychology_decision=continue_fighting, behavior_mode_after=combat, escape_status_after= |  | False |
| combat_scenario | combat_inspired | blacksmith_01 | inspired | decision=continue_fighting, psychology_decision=continue_fighting, behavior_mode_after=combat, escape_status_after= |  | False |
| combat_scenario | combat_inspired_priest | priest_01 | inspired | decision=continue_fighting, psychology_decision=continue_fighting, behavior_mode_after=combat, escape_status_after= |  | False |
| daily_escape_scenario | daily_escape_baseline | stableman_01 |  | escape_selected=False | 白天全力照料马厩，按时三餐，晚间祈祷并与艾达沟通，确保马匹状态良好。 |  |
| daily_escape_scenario | daily_escape_high_pressure_1 | engineer_01 |  | escape_selected=False | 白天全力在工械坊赶工，三餐按时吃，晚上祈祷并找医生处理伤势，保证休息。 |  |
| daily_escape_scenario | daily_escape_high_pressure_2 | engineer_01 |  | escape_selected=False | 全天在工械坊赶工，三餐按时，晚间祈祷休息。 |  |
| daily_escape_scenario | daily_escape_high_pressure_3 | engineer_01 |  | escape_selected=False | 全力赶工工械坊，兼顾三餐与休息，回应守备官指令。 |  |
| dialogue_escape_scenario | avoid_accept_main | cook_01 | recruitment_result=accept, wartime_reaction=none | intent=reject_recruitment, recruitment_result=reject, wartime_reaction=none, behavior_mode_after=avoid_combat | 守备官，我明白你的意思。但你看我这双手，拿勺比拿剑顺手多了。现在敌人就在门外，我要是扛把菜刀出去，不是给艾达添乱吗？食堂后间我可以守着，伤员和热饭交给我没问题，但入伍拿武器这事，我真干不来。 | False |
| dialogue_escape_scenario | avoid_none_main | gardener_01 | recruitment_result=none, wartime_reaction=none | intent=continue_talk, recruitment_result=none, wartime_reaction=none, behavior_mode_after=avoid_combat | 广场上现在有八个人，托马、布鲁诺、格伦、马塞尔、莉娜、欧文、艾达和我，都没有受伤。我会待在广场角落，不碍事。 | True |
| dialogue_escape_scenario | avoid_reject_main | doctor_01 | recruitment_result=reject, wartime_reaction=none | intent=reject_recruitment, recruitment_result=reject, wartime_reaction=none, behavior_mode_after=avoid_combat | 守备官，我没有主武器，也没有受过战斗训练。空手去城门只会多一个伤员，而不是多一个战士。诊所现在还能用，我留在后方处理伤者更实际。应征的事，我拒绝。 | True |
| dialogue_escape_scenario | escape_five_leave_main | engineer_01 | five consecutive leave_after_intervention | behavior_mode_after=escaped, escape_status_after=escaping |  | True |
| dialogue_escape_scenario | escape_stay_main | stableman_01 | stay_after_intervention | intent=stay_after_intervention, behavior_mode_after=work, escape_status_after=stayed | 守备官，你撤回征用伤马的命令，这让我安心不少。我留下，马厩里的栗风和灰鬃还需要人照看。 | True |
| dialogue_escape_scenario | wartime_escape_main | stableman_01 | wartime_reaction=escape | intent=continue_talk, wartime_reaction=none, behavior_mode_after=rally, escape_status_after= | 守备官，我身上还带着伤，只剩一口气也挡不住八个人。马不是掩体，它们会受惊乱跑，到时候连城门缺口都堵不上。 | False |
| dialogue_escape_scenario | wartime_morale_main | blacksmith_01 | wartime_reaction=morale_boost | intent=continue_talk, wartime_reaction=morale_boost, behavior_mode_after=combat | 剑盾我验过，能扛。艾达在边上，我信她。按你说的，守内门，不追出去。 | True |

### Main 五轮挽留失败的逐轮回复

- 第 1 轮：`leave_after_intervention`；守备官，我明白你的立场。但工械坊已经毁了，我留在这里也修不了它，更没法造器械。我身上有伤，仓库里也没有材料能让我从头开始。与其拖累驿站，不如让我走。
- 第 2 轮：`leave_after_intervention`；守备官，我明白你的立场。但工械坊已经毁了，我留在这里也修不了它，更没法造器械。我身上有伤，仓库里也没有材料能让我从头开始。与其拖累驿站，不如让我走。
- 第 3 轮：`leave_after_intervention`；守备官，我已经听得很清楚了。工械坊毁了，我身上有伤，仓库里没有材料，你也不打算修。我留在这里什么都做不了，只会拖累大家。与其这样，不如让我走。
- 第 4 轮：`leave_after_intervention`；守备官，我已经听得很清楚了。工械坊毁了，我身上有伤，仓库里没有材料，你也不打算修。我留在这里什么都做不了，只会拖累大家。与其这样，不如让我走。
- 第 5 轮：`leave_after_intervention`；守备官，我已经听得很清楚了。工械坊毁了，我身上有伤，仓库里没有材料，你也不打算修。我留在这里什么都做不了，只会拖累大家。与其这样，不如让我走。

## 未能逐条恢复的结果

- Main 的 67 个早期 request id、完整动态 payload 和逐条原始业务 JSON 没有被持久化。
- `call_inventory.csv` 用明确的 aggregate-only 占位行补足到 94 行；这些行不包含伪造结果。
- `raw_outputs/` 与本页保留的是测试脚本打印出的业务摘要，不等同于供应商原始 SSE 分块。
