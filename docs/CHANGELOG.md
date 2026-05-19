# CHANGELOG.md

## 0.0.0-seed

- 初始化项目管理文档结构。
- 建立 Agent 协作规则。
- 建立任务、状态、模块索引、架构、NPC、记忆、战斗、UI、Prompt、API 成本等基础文档。
- 确定 Demo 核心方向：边境驿站压力锅。

## Unreleased

- 完成 T0001：初始化 Godot 项目结构，新增最小可运行 `res://scenes/main/Main.tscn` 并设置为项目启动场景。
- 补齐 Godot 基础目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 稳定 Godot MCP 启动流程，将 Codex 端切换为 `proxy -> broker -> Godot`，避免多会话直接争抢编辑器连接。
- 修复 `tools/check_godot_mcp.ps1`，可用于快速自检 Godot 插件监听与当前 MCP 连接状态。
