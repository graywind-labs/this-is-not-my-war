# CODING_RULES.md

## 总原则

代码必须服务于最小可运行闭环。  
优先清晰、稳定、可调试，而不是炫技。

## Godot / GDScript 规则

1. 一个脚本只负责一个明确模块。
2. 系统之间通过 EventBus 或显式接口通信。
3. 不在 `_process` 里做高成本逻辑，除非必要。
4. 需要定时的逻辑尽量由 TimeSystem 驱动。
5. 外部配置必须可缺省、可校验、出错可提示。
6. 所有 JSON 字段读取要有默认值，避免空字段崩溃。
7. 对 LLM 返回 JSON 必须做合法性检查。
8. 重要状态变化必须写入事件日志。
9. UI 不直接决定权威结果，只触发系统请求。
10. 不把 API Key、私密配置、模型地址硬编码进脚本。
11. 结构化事件必须通过 MemorySystem 统一写入；不要让各系统各自维护互不兼容的事件数组。
12. 事件库和见闻库分开保存：亲历事件写入 NPC 事件库；公开事件、状态广播和公告由地点/广场节点即时转发给当前在场 NPC 后写入接收者见闻库。地点/建筑节点不保存事件历史，NPC 进入地点不继承过去事件。
13. 事件 summary 必须按事件类型模板确定性生成，不调用 LLM，也不要试图用通用主宾语规则生成所有事件句子。

## Python 后端规则

1. 所有接口返回 JSON。
2. 所有 LLM 输出都要校验。
3. 模型供应商通过 Model Adapter 隔离。
4. Prompt 模板放在 `data/prompts/` 或后端模板目录，不要散落在业务代码中。
5. 必须记录 token 和调用用途。
6. 请求失败必须返回可处理错误，不让 Godot 卡死。
7. 所有外部 Key 使用环境变量。
8. 不把用户游戏存档和开发配置混在一起。
9. Mock provider 只能作为开发期显式配置或调试接口使用；成品 / Demo 真实 provider 失败时不得自动返回 mock 内容伪装成功。
10. 模型调用失败必须记录真实原因、request id、call_type、provider、model、HTTP 状态或异常类型；日志不得包含 API Key。
11. 规则 / 模板降级可以用于维持游戏流程，但必须以明确 source / error 字段暴露，不能写成模型成功。

## 数据配置规则

NPC、建筑、行动、武器、敌人波次必须配置化：

- `data/npc_profiles.json`
- `data/building_defs.json`
- `data/action_defs.json`
- `data/weapon_defs.json`
- `data/enemy_waves.json`

## 文档规则

每次改代码后检查是否需要更新：

- `CURRENT_STATE.md`
- `TASKS.md`
- `MODULE_INDEX.md`
- 对应模块文档
- `DEV_LOG.md`
- `CHANGELOG.md`

## 注释规则

注释解释“为什么”，不要重复“代码做了什么”。

好：

```gdscript
# 昏迷不等于死亡，保留 NPC 后续记忆和剧情反噬。
npc.unconscious = true
```

不好：

```gdscript
# 设置 unconscious 为 true
npc.unconscious = true
```
