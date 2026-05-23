# TECH_ARCHITECTURE.md

## 总体架构

项目采用 Godot 前端 + Python 后端 + LLM API 的架构。

```text
Godot 4.6
  ↓ HTTP / Localhost
Python Backend
  ↓
Model Adapter
  ↓
DeepSeek / MiniMax / Qwen / Zhipu 等模型
```

当前后端实现状态：

- 使用 Flask 作为 Python Backend 的最小 Web 框架。
- `backend/app.py` 提供 `GET /health`，用于 Godot 或开发者确认本地服务可用。
- `backend/services/model_adapter.py` 是模型供应商隔离层的最小占位，只读取环境配置，不执行真实 LLM 调用。
- 真实 API Key 必须通过本地 `backend/.env` 或环境变量提供；仓库只保留 `.env.example` 模板。

## 职责划分

### Godot 负责

- 场景渲染
- 角色移动
- 建筑点击
- UI 展示
- 资源数值
- 逻辑时间流逝与倍率
- LLM 等待期间的 TimeSystem 慢速请求注册/释放
- 工作产出
- 战斗执行
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件权威写入、地点/建筑信息节点当前状态维护、即时广播、NPC 事件库与见闻库维护
- 与后端通信

### Python 后端负责

- Prompt 拼装
- LLM 调用
- 结构化 JSON 校验
- 对话生成
- 每日计划生成
- 战斗/逃离心理判定
- 睡前总结
- 知识图谱更新
- API 成本统计
- 模型供应商切换

### LLM 负责

- NPC 如何理解事件
- NPC 如何说话
- NPC 是否愿意征召
- NPC 是否想参战、逃离、斗志激昂
- NPC 是否主动找玩家交涉
- NPC 的主观日记与反思

### 事件与记忆边界

Godot 是事件事实源。资源、HP、建筑、移动、战斗、工作、对话收发等权威结果先由 Godot 侧系统结算，再写入 `MemorySystem`：

```text
程序系统结算权威结果
  ↓
MemorySystem.add_event(...)
  ↓
写入 subject_npc_id 的 NPC 事件库
  ↓
按 visibility 发送到地点/建筑信息节点或广场信息节点
  ↓
信息节点即时广播给当前在场 NPC；接收者写入见闻库
  ↓
NPC 进入地点时，只读取当前状态快照，不继承过去事件
  ↓
LLM 调用前从事件库 + 见闻库生成摘要
```

后端和 LLM 可以根据事件库、见闻库和知识图谱生成解释、对话、计划、日记和知识图谱增量，但不能直接新增会改变权威数值的事实。对话全文作为对话事件 `payload` 的一部分保存，不单独建立谈话库。

### LLM 不负责

- 资源扣除
- HP 扣除
- 伤害计算
- 建筑摧毁
- 寻路
- 战斗命中
- 工作产出
- 是否真的拥有某件装备
- 是否真的能执行某行动

## 推荐通信接口

### 健康检查

`GET /health`

返回：

```json
{
  "ok": true,
  "service": "war-not-mine-backend"
}
```

### NPC 对话

`POST /npc/dialogue`

输入：

```json

```

输出：

```json

```

### 每日计划

`POST /npc/plan_day`

输出 24 阶段计划。

### 战斗判定

`POST /npc/battle_judgement`

输出：

```json

```

### 睡前总结

`POST /npc/daily_reflection`

输出知识图谱更新和第一人称日记。

## 数据流

```text
玩家点击 NPC
  ↓
Godot 收集 NPC 当前状态、地点信息、短期记忆摘要
  ↓
Godot 通过 TimeSystem 注册 LLM 等待慢速请求
  ↓
发送到后端
  ↓
后端拼装 Prompt 并调用模型
  ↓
模型返回 JSON
  ↓
后端校验 JSON
  ↓
Godot 释放 TimeSystem 慢速请求
  ↓
Godot 执行合法结果
  ↓
权威结果写入 MemorySystem 事件系统，并按可见性通过地点/广场信息节点即时广播给当前在场 NPC
```

## 失败降级

如果 LLM 请求失败，Godot 必须释放 TimeSystem 慢速请求，并使用 Mock / 规则 / 模板结果降级，不能让游戏长期停留在慢速逻辑时间。

## 时间倍率边界

Godot 不使用后端结果直接决定时间倍率。后端只返回业务 JSON；是否申请慢速、慢速 request id、超时释放和恢复玩家速度，由 Godot 的 LLMBridge / DialogSystem / 计划系统负责。

## API Key

禁止把 API Key 写入仓库。  
使用环境变量或本地 `.env`，并确保 `.gitignore` 忽略 `.env`。
