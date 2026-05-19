# DEV_LOG.md

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

## 2026-05-18

### 初始化文档结构

完成：

- 创建项目管理文档种子。
- 创建 `AGENTS.md` 协作规则。
- 创建核心模块文档。
- 明确文档回写流程。

影响文件：

- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- 其他模块文档

待办：

- 初始化 Godot 项目。
- 初始化后端目录。
- 将现有完整策划案放入 `game_design.md`。

## 2026-05-19

### T0002 初始化后端目录

完成：
- 创建 Flask 后端入口 `backend/app.py`。
- 实现 `GET /health`，返回 `{"ok": true, "service": "war-not-mine-backend"}`。
- 确认 `backend/requirements.txt` 包含 `flask`、`python-dotenv`、`pydantic`、`requests`。
- 新增 `backend/.env.example` 作为本地配置模板；真实 API Key 不写入仓库。
- 创建 `backend/schemas/`、`backend/services/`、`backend/data/`，并使用 `.gitkeep` 保留空目录。
- 新增最小 `backend/services/model_adapter.py`，作为后续 LLM 供应商隔离边界。
- 更新 `.gitignore`，忽略 `backend/.env`。

验证：
- `python -m compileall backend` 通过。
- 安装 `backend/requirements.txt` 后，通过 Flask test client 验证 `GET /health` 返回 HTTP 200 和 `{"ok": true, "service": "war-not-mine-backend"}`。
- 启动 `python backend/app.py` 后，通过 `http://127.0.0.1:5000/health` 验证返回 `{"ok":true,"service":"war-not-mine-backend"}`。

未做：
- 未修改 Godot 场景。
- 未实现 NPC、战斗、资源或 AI 对话。

### T0001 初始化 Godot 项目结构

完成：
- 创建 `res://scenes/main/Main.tscn` 作为最小可运行主场景。
- 主场景包含 `WorldRoot/Station/Ground`、`Systems`、`UI/HUD`、`CameraRig/Camera3D` 和 `SunLight`。
- 补齐 Godot 目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 设置 `project.godot` 的 `run/main_scene` 为 `res://scenes/main/Main.tscn`。
- 通过 Godot MCP 运行主场景，游戏日志无报错，截图可见标题与基础地面。

影响文件：
- `project.godot`
- `scenes/main/Main.tscn`
- `scenes/**/.gitkeep`
- `scripts/**/.gitkeep`
- `ui/.gitkeep`
- `assets/.gitkeep`
- `data/.gitkeep`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- `docs/DEV_LOG.md`
- `docs/CHANGELOG.md`

未做：
- 未实现 NPC、战斗、建筑交互、资源系统、时间系统或后端。

### 稳定 Godot MCP 启动与自检
完成：
- 定位 Godot MCP 频繁断开的根因：同一个 `codex.exe` 下重复拉起 `godot-mcp` 实例，Godot 插件会用 “Replaced by new client” 替换旧连接。
- 修复 `tools/check_godot_mcp.ps1` 解析错误和乱码提示，改为可用的连接自检脚本。
- 将 Codex 全局 `godot-mcp` 启动命令改为 `node C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`。
- 新增 `godot-mcp-broker.mjs`，由单例 broker 负责唯一的 Godot WebSocket 连接；多个 Codex 会话只连接本机 proxy。
- 本机验证 broker 可正常健康检查，并能成功调用 `editor.get_state` 读取 Godot 编辑器状态。

影响文件：
- `tools/check_godot_mcp.ps1`
- `C:\Users\JT\.codex\config.toml`
- `C:\Users\JT\.codex\scripts\godot-mcp-broker.mjs`
- `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`

### T0101 建立核心 Autoload 与系统骨架

完成：
- 新增 `scripts/core/EventBus.gd`，声明资源、时间、建筑点击、NPC 点击和公开事件基础信号。
- 新增 `scripts/core/GameState.gd`，保存当前天数、小时和战斗状态。
- 新增 `scripts/core/ConfigLoader.gd`，提供 JSON 配置读取入口，并在文件缺失或解析失败时给出明确错误。
- 在 `project.godot` 中注册 `EventBus`、`GameState`、`ConfigLoader` Autoload，保留既有 `MCPGameBridge`。
- 新增 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`MemorySystem.gd` 空系统脚本占位。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 清空旧日志后再次运行，游戏日志无报错。

未做：
- 未实现 NPC、建筑点击、资源变化、时间推进、后端连接或战斗逻辑。

### T0102 扩展 Main 场景节点结构

完成：
- 将 `res://scenes/main/Main.tscn` 整理为 `WorldRoot/Station`、`Systems`、`UI`、`CameraRig` 的标准结构。
- 在 `WorldRoot/Station` 下保留 `Ground`，并补齐 `Buildings`、`NPCs`、`Enemies`、`Props` 容器。
- 在 `Systems` 下补齐 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem`、`CombatSystem`、`DialogSystem`。
- 新增 `ActionSystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 空系统脚本占位，并绑定到 Main 场景。
- 在 `UI` 下保留 `HUD/TitleLabel`，并新增隐藏占位 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认当前 HUD 标题与基础地面仍可见。

未做：
- 未实现点击逻辑、NPC、资源数值、战斗或对话 UI。

### T0103 创建低模驿站 Blockout

完成：
- 在 `res://scenes/main/Main.tscn` 中扩展低模驿站空间占位。
- 在 `WorldRoot/Station/Buildings` 下新增主厅、宿舍、食堂、仓库、围墙、城门、后门等几何体占位。
- 在 `WorldRoot/Station/Props` 下新增广场、正门道路、后门道路和商人入口占位。
- 补齐酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌等 T0103 要求的剩余占位区域。
- 为 P0 占位区域添加 `Label3D` 调试标签，便于后续建筑系统和导航接入。
- 扩大地面尺寸并调整俯视相机，让启动后可看到完整驿站布局。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 标题、完整低模驿站和调试标签可见。

追加调整：
- 根据反馈扩大地面和围墙范围，并重新拉开建筑间距。
- 将建筑更明显地分散到中央广场、生活区、生产区、防务区和后门入口周边。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认拥挤感降低。

反馈修正：
- 补齐围墙四角闭合，让驿站院墙更像完整防御边界。
- 将公告牌缩小并移动到主厅正面，符合公共信息挂在主厅前的设想。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现建筑数据、建筑点击、生产、NPC、导航或战斗逻辑。
