# CHANGELOG.md

## 0.0.0-seed

- 初始化项目管理文档结构。
- 建立 Agent 协作规则。
- 建立任务、状态、模块索引、架构、NPC、记忆、战斗、UI、Prompt、API 成本等基础文档。
- 确定 Demo 核心方向：边境驿站压力锅。

## Unreleased

- 完成 T0002：初始化 Flask 后端骨架，新增 `backend/app.py` 与 `GET /health` 健康检查接口。
- 新增后端基础目录 `backend/schemas/`、`backend/services/`、`backend/data/` 和最小 `backend/services/model_adapter.py`。
- 新增 `backend/.env.example` 配置模板，并通过 `.gitignore` 忽略本地 `backend/.env`。
- 完成 T0001：初始化 Godot 项目结构，新增最小可运行 `res://scenes/main/Main.tscn` 并设置为项目启动场景。
- 补齐 Godot 基础目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 稳定 Godot MCP 启动流程，将 Codex 端切换为 `proxy -> broker -> Godot`，避免多会话直接争抢编辑器连接。
- 修复 `tools/check_godot_mcp.ps1`，可用于快速自检 Godot 插件监听与当前 MCP 连接状态。
- 完成 T0101：新增 `EventBus`、`GameState`、`ConfigLoader` 核心 Autoload，并创建 Time、Resource、Building、NPC、Memory 系统脚本占位。
- 完成 T0102：整理 `Main.tscn` 标准节点结构，补齐 Systems 与 UI 面板占位，并新增 Action、Combat、Dialog 系统脚本占位。
- 完成 T0103：在 `Main.tscn` 中创建低模驿站 Blockout，补齐主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌等几何占位和调试标签。
- 调整 T0103 低模驿站尺度：扩大地面、围墙和相机视野，拉开建筑间距，降低拥挤感。
- 修正 T0103 低模驿站布局：闭合围墙四角，并将公告牌缩小移动到主厅正面。
- 完成 T0104：建立基础 HUD，显示标题、天数、小时/阶段、五类资源占位、加速/警铃按钮占位和后端状态占位，并新增 `scripts/ui/HUD.gd`。
- 完成 T0201：新增基础 JSON 数据文件，覆盖资源、建筑、行动、武器、敌人波次和 NPC 档案最小样例，并同步 `DATA_SCHEMA.md` 与 `MODULE_INDEX.md`。
- 完成 T0105：新增并绑定 `scripts/camera/CameraRig.gd`，支持 WASD/鼠标中键平移、滚轮缩放、边界限制和高机位俯视相机控制。
