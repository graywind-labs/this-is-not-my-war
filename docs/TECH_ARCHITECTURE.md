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
- 时间流逝
- 工作产出
- 战斗执行
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件写入
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
发送到后端
  ↓
后端拼装 Prompt 并调用模型
  ↓
模型返回 JSON
  ↓
后端校验 JSON
  ↓
Godot 执行合法结果
  ↓
事件写入 MemorySystem
```

## 失败降级

如果 LLM 请求失败，尝试重连

## API Key

禁止把 API Key 写入仓库。  
使用环境变量或本地 `.env`，并确保 `.gitignore` 忽略 `.env`。
