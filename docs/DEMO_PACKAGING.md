# Windows 试玩版一键打包方案

## 1. 文档状态

- 任务：`T1703 打包导出`
- 当前阶段：P1—P4 完成，P5 流水线与 P5-R1—R6 修复已实现；等待重新输入本包 DeepSeek Key 发布正式修复包
- 目标平台：Windows x86_64
- 引擎基线：Godot `4.6.2-stable`
- 后端基线：Python `3.11`、Flask、Pydantic、Waitress、PyInstaller `onedir`
- 输出目标：一个可由用户自行压缩的完整试玩目录；本方案不负责生成 ZIP

本方案只定义发行流水线，不修改 NPC、资源、建筑、战斗、教程或数值权威。以后只调整 `data/` 中的难度、波次、资源或其他配置时，不需要改打包流程；重新执行一键脚本即可把当前工作区的最新正式运行内容重新导出。

## 2. 最终目标

开发者在项目根目录运行一个 PowerShell 脚本，只手工输入本次试玩包专用的 DeepSeek API Key；脚本自动从本机 `backend/.env` 读取当前已经配置的百炼语音凭据。脚本自动完成：

1. 检查引擎、导出模板、Python 构建环境、项目入口与关键发行配置。
2. 验证输入 Key 能访问固定的 DeepSeek 服务，但不把 Key 输出到终端或构建日志。
3. 从当前工作区创建隔离的临时发行工作区，不修改开发工作区文件。
4. 在临时副本中关闭 GM 面板、Godot MCP 与开发入口，保留真实百炼语音入口，并锁定正式教程启动模式。
5. 把 Python 后端冻结为无需玩家安装 Python 的 Windows 可执行目录。
6. 把 Godot 客户端导出为 Windows release 版本。
7. 生成一个 `启动游戏.exe`，负责后端健康检查、游戏启动和退出清理。
8. 生成版本清单、第三方许可和简短试玩说明。
9. 对成品目录做允许清单、禁止内容、配置、密钥隔离和启动冒烟检查。
10. 成功后原子发布到 `dist/这不是我的战争_Demo_Windows_x64/`；失败时保留旧成品、清理临时 Key 和临时构建目录。

推荐使用方式：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_windows_demo.ps1
```

脚本随后以不回显方式提示：

```text
请输入本试玩包专用的 DeepSeek API Key：
```

自动化环境也可以只设置一个环境变量后执行同一脚本：

```powershell
$env:THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY = "本试玩包专用Key"
powershell -ExecutionPolicy Bypass -File tools/build_windows_demo.ps1
Remove-Item Env:THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY
```

脚本唯一需要手工输入的秘密是 DeepSeek API Key。百炼 `DASHSCOPE_API_KEY / VOICE_WORKSPACE_ID / VOICE_BASE_URL` 从本机已存在的 `backend/.env` 自动读取；缺失或不完整时构建失败，不询问第二组参数，也不自动改用 Mock。Provider、模型、端口、目标平台、启动模式、Mock 策略和输出目录均来自版本化的非秘密发行配置，不要求每次手工填写。

## 3. 成品目录合同

```text
dist/
└─ 这不是我的战争_Demo_Windows_x64/
   ├─ 启动游戏.exe
   ├─ game/
   │  ├─ ThisIsNotMyWar.exe
   │  └─ ThisIsNotMyWar.pck
   ├─ backend/
   │  ├─ ThisIsNotMyWarBackend.exe
   │  └─ _internal/
   ├─ licenses/
   │  └─ THIRD_PARTY_ASSETS.txt
   ├─ README_试玩说明.txt
   └─ BUILD_MANIFEST.json
```

约束：

- 顶层只提供一个玩家启动入口 `启动游戏.exe`。
- 玩家不需要安装 Godot、Python、VSCode、Godot MCP 或项目依赖。
- `game/` 只包含 Godot 导出运行时。
- `backend/` 只包含冻结后的本机服务，不包含 Python 源码树、测试、`.env` 或独立 Key 文件。
- `BUILD_MANIFEST.json` 只记录项目版本、Git HEAD、工作区是否有未提交内容、构建时间、目标平台、引擎版本、后端版本、发行配置摘要、文件哈希和 Key 指纹；不得记录 Key 正文。
- 脚本不生成压缩包，由开发者检查目录后自行压缩。

## 4. 唯一变量与固定发行配置

### 4.1 唯一手工输入与自动语音凭据

`THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY`

输入要求：

- 非空，去除首尾空白后使用。
- 必须是专门为该试玩包准备、可限额、可吊销的 Key。
- 若与本机 `backend/.env` 中的开发 Key 相同，构建默认失败，防止误发开发凭据。
- 不进入 PowerShell 普通参数历史；交互模式使用安全输入，CI 才使用临时进程环境变量。
- 不写入仓库、`backend/.env`、Godot PCK、说明文件或构建日志。

语音凭据要求：

- 使用本机 `backend/.env` 当前配置的 `DASHSCOPE_API_KEY`；2026-09-14 盘点确认 Key、Workspace ID、Base URL、Provider 与模型字段均已配置，未读取或记录具体值。
- 同时读取与该 Key 配套的 `VOICE_WORKSPACE_ID` 和 `VOICE_BASE_URL`；不得用猜测或默认地域替换已有正式配置。
- `VOICE_PROVIDER` 在发行 profile 中强制为 `qwen3_asr_flash`，不沿用 `.env` 中可能残留的 Mock 值。
- 只解析语音所需白名单字段，不复制整个 `.env`，不继承其他开发开关或开发 DeepSeek Key。
- 语音 Key 是用户本轮明确授权随试玩包使用的现有 Key，因此允许进入冻结后端；它仍不得进入独立文本、PCK、日志或 manifest 正文。

### 4.2 版本化发行配置

后续实现将在 `tools/release/demo_build_config.json` 保存以下非秘密常量：

```json
{
  "schema_version": 1,
  "target": "windows_x86_64",
  "godot_version": "4.6.2-stable",
  "godot_export_preset": "Windows Desktop Demo",
  "output_directory": "dist/这不是我的战争_Demo_Windows_x64",
  "backend_host": "127.0.0.1",
  "backend_port": 5000,
  "llm_provider": "deepseek",
  "llm_base_url": "https://api.deepseek.com",
  "llm_model": "deepseek-v4-pro",
  "llm_provider_total_timeout_seconds": 120,
  "llm_fallback_to_mock": false,
  "voice_provider": "qwen3_asr_flash",
  "startup_mode": 2,
  "default_display_mode": "fullscreen",
  "audio_manifest_source": "assets/audio/manifests/audio_asset_manifest.csv",
  "audio_manifest_runtime": "assets/audio/manifests/audio_asset_manifest.runtime.txt",
  "gm_enabled": false,
  "godot_mcp_enabled": false,
  "backend_profile": "demo"
}
```

冻结后端必须把 `llm_provider_total_timeout_seconds` 显式写成 `LLM_PROVIDER_TOTAL_TIMEOUT_SECONDS`，不能只依赖源码默认值或继承玩家机器环境。当前试玩值为 120 秒；DeepSeek 持续发送 keep-alive 但没有开始输出时，到达该墙钟上限会返回可见的排队超时，而不会无限等待。

模型或服务地址将来如需变更，应通过一次受审查的发行配置提交完成；普通打包仍只输入 Key，避免每次构建临时选错 Provider 或模型。

## 5. 开发工作区零污染原则

一键脚本必须支持当前工作区有未提交修改，并明确打包“当前磁盘内容”，不能强制 `git clean`、`git reset` 或切换分支。

脚本不得直接修改：

- `project.godot`
- `scenes/main/Main.tscn`
- `scripts/ui/MainMenu.gd`
- `scripts/ui/GMPanel.gd`
- `backend/.env`
- 开发者 `user://` 配置、存档和 DPAPI 自定义 Key

构建流程先把运行时允许清单复制到 `%TEMP%/ThisIsNotMyWarDemoBuild/<build_id>/project/`，所有发行替换只发生在临时副本。开始前记录开发工作区关键文件 SHA-256，结束后再次校验字节未变。

成功或失败都必须清理临时发行副本、PyInstaller workpath、生成的 Key 注入模块和进程环境变量。现有 `dist/这不是我的战争_Demo_Windows_x64/` 在新包全部验收通过前保持不动；发布时若已有旧包，先改名为带时间戳的可恢复备份，再原子移动新目录。

## 6. Godot 客户端发行策略

### 6.1 临时工作区允许清单

临时 Godot 项目只复制：

- `project.godot`
- `assets/branding/this_is_not_my_war_icon_1024.png` 与六档 `this_is_not_my_war.ico`；分别用于 Godot 通用图标和 Windows EXE / 任务栏图标
- `default_bus_layout.tres`
- `assets/`
- `data/`
- `resources/`
- `scenes/`
- `scripts/`
- `shaders/`
- `ui/`

如以后新增运行时根目录，必须先更新本清单、`docs/MODULE_INDEX.md` 和构建专项，不能让脚本静默漏包。

明确不复制：

- `.git/`、`.godot/`、`.vscode/`
- `addons/godot_mcp/`
- `backend/`
- `tools/`
- `docs/`
- `analysis/`
- `artifacts/`
- `art_source/`
- `scratch/`
- `backend/.env`、日志、缓存、测试输出
- 原始下载包、DCC 工程、候选音频、美术废稿和宣传材料

Godot 官方命令行 release 导出要求存在导出预设和匹配的导出模板：

- https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html

### 6.2 临时发行覆盖

构建脚本在临时副本中执行确定性修改并逐项断言：

- 移除 `MCPGameBridge` Autoload。
- 移除 `res://addons/godot_mcp/plugin.cfg` 编辑器插件启用项。
- 不复制 `addons/godot_mcp/`。
- 把 `GMPanel.gd` 的 `GM_ENABLED` 设为 `false`；不删除 GM 代码和文档。
- 保持 `run/main_scene="res://scenes/frontend/MainMenu.tscn"`。
- 确保主菜单开始游戏与 Main 默认启动均为 `startup_mode=2`，进入正式序章教程。
- 使用独立试玩版 `user://` 目录名，避免本机开发设置、存档或自定义 AI 配置污染发行验收。
- 保留语音录制入口，并断言冻结后端使用从本机白名单读取的真实百炼 `qwen3_asr_flash` 配置；缺 Key、Workspace ID 或 Base URL 时停止构建，不允许切到 Mock。
- 增加 `demo` 自定义 feature，供必要的运行时发行分支显式识别；不能依赖 `debug` feature 猜测产品模式。
- 使用 release preset，不启用调试远程部署、PCK 加密密钥或编辑器凭据。

### 6.3 导出模板与缓存

脚本自动检测 Godot 控制台程序版本，必须与 `4.6.2-stable` 一致。首次构建如果缺少 Windows 模板：

1. 从固定的官方 Godot 4.6.2 发布地址下载模板到用户级构建缓存。
2. 按仓库记录的 SHA-256 校验。
3. 安装到 Godot 认可的用户模板目录。
4. 后续构建复用缓存。

下载失败、哈希不符或版本不匹配时立即停止；不得改用其他版本模板凑合导出。

## 7. Python 后端发行策略

### 7.1 生产入口

新增独立生产入口，使用 Waitress 监听 `127.0.0.1:5000`，不得使用 Flask `debug=True` 开发服务器。后端必须支持：

- `APP_PROFILE=demo`
- `PARENT_PROCESS_ID=<launcher pid>`，启动器消失后自动退出
- 关闭 reload、debugger 和开发错误页
- 收到正常终止信号后停止接收新请求并退出
- 日志、AI 服务设置与成本账本写入 `%LOCALAPPDATA%/ThisIsNotMyWarDemo/`，不写入安装目录

### 7.2 Demo 路由边界

Demo 保留：

- `GET /health`
- `GET/PUT /config/ai-service`
- `POST /config/ai-service/test`
- 正式 NPC、计划、战斗、反思、结局等业务接口
- `POST /voice/analyze`，使用真实 `qwen3_asr_flash`；鉴权、地域、Workspace、限流、超时和供应商失败保留真实错误，不能生成 Mock 文本

Demo 不注册或不可访问：

- `POST /mock/model`
- 开发用 usage/debug 接口
- 测试夹具、调试文件读取、日志正文下载接口

`GET /health` 必须增加非秘密的 `app_profile=demo`、构建 ID 和服务名，以便启动器识别端口上的进程确实属于当前包。

### 7.3 固定 LLM 运行配置

冻结后端启动前必须得到以下环境：

```text
LLM_PROVIDER=deepseek
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-pro
LLM_FALLBACK_TO_MOCK=false
LLM_FORCE_JSON_RESPONSE=true
LLM_THINKING_MODE=disabled
LLM_BUDGET_MAX_CALLS=0
LLM_BUDGET_MAX_INPUT_TOKENS=0
LLM_BUDGET_MAX_OUTPUT_TOKENS=0
LLM_BUDGET_MAX_TOTAL_TOKENS=0
LLM_BUDGET_MAX_COST=0
LLM_DAILY_BUDGET_MAX_CNY=0
VOICE_PROVIDER=qwen3_asr_flash
DASHSCOPE_API_KEY=<从本机 backend/.env 白名单读取并注入>
VOICE_WORKSPACE_ID=<从本机 backend/.env 白名单读取并注入>
VOICE_BASE_URL=<从本机 backend/.env 白名单读取并注入>
```

试玩包不伪造游戏内额度，真实余额、鉴权、限流和供应商错误继续按 T0410 合同显示。发行日志保留 request id、call type、provider、model、HTTP/异常和降级来源，但默认不保存完整玩家对话 payload，并继续执行凭据脱敏。

### 7.4 Key 注入

构建脚本不得复制 `backend/.env`。它只从该文件读取百炼语音白名单字段，并在隔离的临时目录生成一次性后端启动模块，把本次试玩 DeepSeek Key 及当前百炼 Key / Workspace / Base URL 注入进程环境后才导入 `backend.app`；该模块随 PyInstaller 冻结进后端包，随后连同 PyInstaller 工作目录一起删除。成品目录不出现 `.env`、`trial.env`、JSON Key 文件或明文说明。

必须承认：本机可执行程序中携带的 DeepSeek 和百炼 Key 无法做到密码学意义上的保密，熟悉逆向的用户仍可能提取。该模式只适合受控、限时、限额的比赛试玩包；面向公众长期分发时必须改用远程后端。把 Key 编进 EXE 只是减少误传和明文暴露，不等于秘密不会泄漏。

构建清单分别记录 DeepSeek 与百炼 Key 的 SHA-256 指纹前 12 位。若检测到输入的 DeepSeek Key 与 `backend/.env` 的开发 DeepSeek Key 相同，默认拒绝构建；百炼 Key 按本轮明确决策使用当前值，不触发该同值拒绝，但必须通过存在性和真实 Provider 配置检查。

### 7.5 PyInstaller 形态

后端使用 `onedir`，不使用 `onefile`：

- 启动速度更稳定。
- Flask、Pydantic、Waitress 与数据文件更容易审计。
- `data/prompts/`、语音输入配置和后端运行所需数据可显式加入。
- 玩家仍只通过顶层启动器启动，不需要理解 `_internal/`。

PyInstaller 官方 `onedir` 与 `--add-data` 说明：

- https://www.pyinstaller.org/en/stable/usage.html

构建依赖安装到专用缓存虚拟环境，不修改项目运行虚拟环境或全局 Python。依赖版本写入锁定的 build requirements，不能每次静默升级到最新版本。

## 8. 启动器合同

`启动游戏.exe` 是一个独立、无控制台窗口的轻量启动器，职责仅限进程编排，不拥有任何游戏数值或 AI 业务权威。

启动顺序：

1. 解析自身目录，禁止依赖当前工作目录。
2. 检查 `game/ThisIsNotMyWar.exe` 与 `backend/ThisIsNotMyWarBackend.exe`。
3. 检查 `127.0.0.1:5000`。
4. 若端口被未知进程或不同构建占用，显示中文错误并退出，不杀死未知进程。
5. 启动隐藏窗口的后端，传入自身 PID 和当前构建 ID。
6. 在限定时间内轮询 `/health`，确认服务名、`app_profile=demo`、构建 ID、文本 Provider / 模型 / fallback 与语音 Provider 配置。
7. 健康检查通过后启动 Godot 客户端。
8. 等待游戏退出。
9. 请求后端正常退出；超时后只终止自己启动的后端进程。
10. 启动器异常退出时，后端通过父进程监视自行退出。

第 8—9 步不区分退出入口：点击 Windows 标题栏右上角 X、主菜单确认“退出游戏”、游戏内“退出到桌面”或客户端异常退出，都会表现为游戏子进程结束并进入同一 `finally` 清理。正常完成后后端和启动器均不得残留。

玩家可见错误至少区分：文件缺失、端口占用、后端启动失败、健康检查超时、发行配置错误和游戏进程启动失败。错误消息不得显示 Key、请求头或完整环境变量。

## 9. 一键脚本阶段

`tools/build_windows_demo.ps1` 按固定阶段执行：

```text
00 AcquireSecret
01 Preflight
02 PrepareBuildTools
03 CreateIsolatedStaging
04 ApplyAndVerifyReleaseProfile
05 BuildBackend
06 ExportGodotClient
07 BuildLauncher
08 AssemblePackage
09 AuditPackage
10 SmokeTest
11 AtomicPublish
12 Cleanup
```

各阶段产生结构化状态；任何失败都返回非零退出码、指出阶段和可操作原因，同时执行 `finally` 清理。日志只保存非秘密摘要，所有可能包含 Key 的命令参数、环境快照和 Provider 响应头都禁止写盘。

脚本必须可重复执行：数值或资源变更后再次执行会重建全部客户端和后端，不复用旧 PCK；工具下载缓存可以复用，但成品不能增量混入旧文件。

## 10. 成品内容审计

### 10.1 必须不存在

- `.git`、`.godot`、`.vscode`
- `AGENTS.md`、`game_design.md`、`docs/`
- `tools/`、测试脚本、分析脚本、验收截图、PPT、宣传图
- `art_source/`、原始下载包、候选/废稿素材
- `backend/.env` 或任意 `.env`
- Python `.py` / `.pyc` 源码散文件、`__pycache__`
- Godot MCP 插件、Autoload 或端口配置
- GM 可见入口
- Mock 自动 fallback 或可调用 `/mock/model`
- 未获授权的开发 DeepSeek Key、Authorization/Bearer 日志，以及任何独立明文百炼 Key 文件
- Flask debug/reloader

### 10.2 必须存在并正确

- 顶层 `启动游戏.exe`
- Godot release 客户端与 PCK
- Waitress 承载的冻结后端
- `provider=deepseek`
- `model=deepseek-v4-pro`
- `fallback=false`
- `voice_provider=qwen3_asr_flash`
- MainMenu 正式入口与 `startup_mode=2`
- 项目首帧与全新用户默认 `fullscreen`，但保留玩家已有的合法显示偏好
- GM 不可见、MCP 不启动
- 正式运行 JSON、Prompt、场景、美术、音频和字体可加载
- 第三方许可、试玩说明和构建清单

### 10.3 密钥审计

- 构建日志扫描开发 DeepSeek Key、输入 DeepSeek Key、当前百炼 Key 及常见 `sk-`/Bearer 片段；任何日志命中即失败并删除日志。
- 成品允许两套已授权 Key 只存在于冻结后端载荷，不允许出现在 PCK、独立文本、JSON、说明、manifest 或启动器参数中。
- 若能读取本机开发 DeepSeek Key，必须扫描成品并确认该开发 Key 完全不存在；当前百炼 Key 是本轮明确授权的例外，只允许存在于冻结后端载荷。
- `BUILD_MANIFEST.json` 只存两套 Key 的指纹，不存 Key。

## 11. 验证层级

### 11.1 每次一键构建自动执行

- JSON / 配置语法检查。
- 后端 Schema、发行 profile 与禁用调试路由专项。
- Godot headless 项目解析和关键发行配置专项。
- 将正式音频 CSV 逐字节映射为发行 `.runtime.txt`；从唯一 CSV 自动派生预期条数，导出后启动真实 EXE，要求清单 / 分类 / 全部音频流均等于该数量且菜单音乐资源可加载。
- PyInstaller 数据完整性检查。
- 导出包允许清单 / 禁止清单。
- 启动冻结后端并检查 `/health`。
- 用输入 Key 执行 `/config/ai-service/test`，确认 DeepSeek 鉴权和模型可见；该步骤不生成 NPC 内容。
- 检查冻结后端的语音 Provider、Workspace 与 Base URL 配置完整且不是 Mock；每次普通重建不上传录音，避免无意义语音费用。
- 启动导出客户端到主菜单冒烟，确认进程没有立即崩溃。
- 关闭启动器后检查无残留后端进程。
- 结束后核对开发工作区关键文件哈希未变。

### 11.2 T1703 最终验收额外执行一次

- 从冻结后端发出一次真实 NPC 业务请求，确认 `deepseek / deepseek-v4-pro / fallback=false`，并记录脱敏 usage。
- 使用不含隐私的项目验收 WAV 向冻结后端发出一次真实 `/voice/analyze`，确认 `qwen3_asr_flash / fallback=false`，并记录脱敏 usage；真人麦克风仍按用户主动操作验收。
- 在未安装 Python、Godot 和 VSCode 的干净 Windows 用户环境运行成品目录。
- 双击启动器进入主菜单，再由“开始游戏”进入序章教程。
- 验证 AI 对话、日计划、错误提示、存档目录和退出清理。
- 验证无 Key、错误 Key、断网、Provider 限流时只显示真实错误或明确规则/模板降级，不出现 Mock 成功。
- 至少完成一次 30 分钟试玩稳定性检查；完整胜利/失败流程仍属于前置 `T1701` 的最终稳定性门禁。

## 12. 失败与恢复策略

- 缺 Godot、版本错误、模板哈希错误、Python 构建失败、Key 无效、端口占用、测试失败或内容审计失败时，不发布半成品。
- 临时工作区始终位于已验证的专用构建目录；清理前再次解析绝对路径，禁止递归操作工作区根目录、用户目录或未校验路径。
- 新成品通过全部自动门禁前，旧成品不移动。
- 发布阶段不直接移动刚执行过、可能仍被 Windows 临时锁定的源 package。先复制到 `dist/.t1703-publishing-*`，对复制件重新执行内容 / 密钥审计及 BUILD_MANIFEST 逐文件大小 / SHA-256 校验；全部一致后才把旧成品改名为时间戳备份，并在同一 `dist` 内重试改名候选目录。若改名失败则恢复旧目录。
- 脚本不运行 `git reset`、`git clean`、`git checkout` 或任何会丢失开发修改的命令。

## 13. 已知风险与明确取舍

1. **本地 Key 可被逆向**：DeepSeek 使用独立、低额度、限时、可吊销的比赛 Key；当前百炼 Key 也应在发包前设置额度/告警并准备赛后吊销。公开发行改用远程后端。
2. **PyInstaller 误报**：未签名可执行程序可能被 SmartScreen 或杀毒软件提示；最终提交前应在干净机测试，条件允许时增加代码签名，但签名不作为首版流水线阻塞项。
3. **端口冲突**：首版保持客户端现有 `127.0.0.1:5000` 合同；启动器发现冲突即明确失败，不擅自杀进程。动态端口可作为后续增强，不在首版扩大范围。
4. **语音输入**：按用户确认保留现有百炼语音 Key，脚本自动从 `backend/.env` 白名单读取，仍不使用 Mock；这不会增加第二个手工输入变量，但会让当前百炼凭据随包承担可提取风险。
5. **当前工作区很脏**：允许打包当前磁盘内容，但 manifest 必须记录 `git_dirty=true` 和 HEAD，便于追溯；不把未提交状态当成阻塞。
6. **数值继续调整**：只要运行时目录与配置 Schema 不变，重新运行脚本即可。新增顶层运行目录、改后端端口、改 Provider、改主场景或改启动协议时才需要同步更新本方案与专项。

## 14. 实施任务拆分

### T1703-P0 发行方案与任务基线

- 状态：Done（2026-09-14）
- 产物：本文件、`docs/TASKS.md` 子任务、架构与模块索引摘要。
- 完成条件：目录合同、唯一变量、零污染、发行配置、密钥风险、分阶段门禁和任务依赖明确。

### T1703-P1 隔离发行工作区与配置覆盖

- 状态：Done（2026-09-14）
- 前置：T1703-P0
- 实现运行时允许清单复制、临时项目覆盖、GM/MCP 关闭、真实语音入口保留、正式启动模式、独立 `user://`、开发文件哈希保护和发行 profile 专项。

### T1703-P2 生产后端与冻结构建

- 状态：Done（2026-09-14）
- 前置：T1703-P1
- 实现 Waitress 入口、demo 路由边界、父进程监视、LocalAppData 日志、固定 DeepSeek / 百炼配置、两套临时 Key 注入、PyInstaller onedir 与冻结后端专项。

### T1703-P3 Godot Windows release 导出

- 状态：Done（2026-09-14）
- 前置：T1703-P1
- 实现 `export_presets.cfg`、模板自动检测/下载/校验、临时发行项目导入、release 导出和 PCK 内容审计。

### T1703-P4 一键启动器与进程生命周期

- 状态：Done（2026-09-14）
- 前置：T1703-P2、T1703-P3
- 实现 `启动游戏.exe`、端口归属检查、健康门禁、游戏启动、正常退出、崩溃清理和中文错误提示。

### T1703-P5 一键编排、成品清单与安全审计

- 状态：Partial（2026-09-14：实现和假凭据全链通过，等待专用 DeepSeek Key 执行正式构建）
- 前置：T1703-P4
- 实现 `tools/build_windows_demo.ps1` 全阶段编排、工具缓存、README/许可/manifest、禁止内容和密钥审计、原子发布及失败回滚。

### T1703-P6 真实包端到端验收

- 状态：Todo
- 前置：T1701、T1703-P5
- 在冻结后端完成一次真实 DeepSeek 业务 smoke，在干净 Windows 用户环境完成一键启动、教程、AI、错误、存档、退出和 30 分钟稳定性验收；通过后将 T1703 标记为 Done。

## 15. 实施顺序

```text
T1703-P0
  → T1703-P1
     ├─ T1703-P2
     └─ T1703-P3
          → T1703-P4
             → T1703-P5
                → T1703-P6（同时等待 T1701）
```

P2 与 P3 在 P1 完成后可以独立开发，但每一步都应先通过自己的专项，不等到最后才一次排查。P6 之前的流水线可以先产出技术预览包；只有 P6 和 T1701 都通过后，才能称为正式可提交试玩版。

## 16. 当前实施结果（2026-09-14）

- 一键入口已落地为 `tools/build_windows_demo.ps1`，无参数运行；DeepSeek Key 可安全交互输入，CI / 隔离自动化也可使用进程级 `THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY`，两种方式均不把 Key放入命令行参数。
- P1-P4 专项全部通过；Godot 官方 Windows 模板已按 1,251,900,388 字节和 SHA-256 `942366dc4e27e7686a99da4d3cfb1b8ae8d3eb9444f6d8217eef16245b599ef2` 校验。
- 假凭据完整构建生成 81 个文件、约 502 MB；冻结后端、Godot EXE / PCK、冻结启动器、manifest、许可和玩家说明均完整，启动器 smoke 返回 0 且退出后 5000 端口释放。
- 假凭据构建故意跳过真实供应商调用；正式脚本会在发布前从冻结后端调用一次 `/config/ai-service/test`，只有 `deepseek / deepseek-v4-pro` 成功才继续。
- 下一步只需要输入与开发 Key 不同的限额 / 可吊销 DeepSeek 打包 Key 并执行正式脚本。此后再进入 P6 的一次真实 NPC / WAV 与干净机稳定性验收。

### 16.1 P5-R1 Windows 源 EXE 发布锁修复

首次真实构建已通过冻结 DeepSeek `/config/ai-service/test` 与启动器 smoke，但在最终直接移动临时 package 时收到 `MoveDirectoryItemIOError / Access denied`。检查显示启动器和后端均已退出，临时目录只剩刚执行过的客户端 EXE，符合 Windows 对源映像文件短暂锁定导致目录移动失败；该次临时包已经过失败清理，不能恢复为成品。

当前发布实现不再移动源 package，而是复制到 `dist` 内的唯一候选目录，随后逐文件验证 manifest 再同盘改名。专项在源 EXE 持续运行、不可安全移动的条件下验证 PowerShell 复制成功、候选目录改名成功，并确认篡改文件会被 SHA-256 门禁拒绝。正式构建需要重新输入 Key；脚本不会保存或复用上次 Key。

### 16.2 P5-R2 正式 Windows 图标

- 品牌母版固定为 `assets/branding/this_is_not_my_war_icon_1024.png`：1024×1024、8-bit RGBA。
- Windows ICO 固定为 `assets/branding/this_is_not_my_war.ico`：16、32、48、64、128、256 六档正方形 32 位目录项。
- Godot 的通用项目图标使用 PNG，Windows native / 任务栏和 export preset 使用 ICO；顶层启动器与内部冻结后端通过 PyInstaller `--icon` 使用同一 ICO。
- 一键脚本 preflight 必须先验证这两份资产；品牌路径写入 BUILD_MANIFEST 的非秘密 release profile。旧 Godot 默认 `icon.svg` 保留在开发仓库但不再复制到试玩 staging。
- 已对真实冻结启动器与真实 Godot release EXE 提取关联图标，均显示盾牌麦穗图案；后端重建日志确认图标写入且运行回归通过。

### 16.3 P5-R3 默认全屏与退出清理

- `project.godot` 使用 `window/size/mode=3`，`ClientSettings` 的新用户 / 重置默认值为 `fullscreen`；已有合法 `windowed / borderless` 偏好不会被启动流程覆盖。
- staging 配置、BUILD_MANIFEST 和成品审计都要求 `default_display_mode=fullscreen`，防止开发设置在导出时意外退回小窗口。
- 主菜单确认退出已自动验证会调用 `SceneTree.quit()`；完整 81 文件假包的真实 Godot 窗口已收到 Windows `WM_CLOSE`（等价于点击右上角 X），启动器退出码为 0，5000 端口随后不可连接且无相关进程残留。
- 包内除前台游戏外只由启动器创建一个冻结后端；正常游戏退出由启动器回收，启动器异常退出由后端父进程监视兜底。

### 16.4 P5-R4 发行包音频清单修复

- 用户实测包的 `ThisIsNotMyWarDemo/logs/godot*.log` 显示 AudioManager 无法打开 `.csv` 清单，108 条音频随后全部成为 unknown asset；独立试玩音量配置为非零，排除静音设置。
- Godot 将 CSV 当作翻译资源导入，原文件可在开发目录被 FileAccess 打开，但不能作为 release PCK 的运行时文本合同。
- staging 现在从唯一正式 CSV 逐字节生成 `assets/audio/manifests/audio_asset_manifest.runtime.txt`，只改写隔离副本内的 AudioManager；源工程不保存第二份易漂移清单。
- `export_demo_client.py` 会运行刚导出的 Windows EXE 并读取独立日志，要求 `assets=108 / categorized=108 / streams=108`，逐条加载全部运行音频，同时拒绝清单不可读、未知资产、运行音频缺失或加载失败。真实 Godot 4.6.2 release PCK 验证通过。

### 16.5 P5-R5 近期改动发行漂移审计

- 9 月 14—15 日的数值、玩法、教程与 Bug 修复均位于既有 Godot staging 运行目录；新增结局 Prompt 由冻结后端既有 `data/prompts` 收集规则覆盖，未出现新依赖或新发行根目录。
- T0420 后音频已从当时的 108 条增加到 109 条。发行配置不再手写数量；staging、真实导出 EXE 验证和 BUILD_MANIFEST 均从唯一正式 CSV 自动派生，后续增删音频无需同步多个常量。
- 一键脚本会在创建虚拟环境、冻结后端和导出客户端前检查 5000 端口。若开发后端或另一试玩实例占用，只报告 PID 并停止构建，不会擅自结束进程。
- 当前 Godot 4.6.2 Windows release EXE/PCK 已实际验证 `assets=109 / categorized=109 / streams=109`，PCK 为 362,652,632 字节；本轮不调用 Provider。

### 16.6 P5-R6 Godot CSV 翻译导入副产物隔离

- 开发工程的音频 CSV 会让 Godot 在同目录生成二进制 `.translation` 与 `.csv.import`；这些文件没有试玩运行时消费者，且编辑器并发重写时可能让 staging 复制到中间态，表现为导出阶段 `Invalid unicode codepoint`。
- staging 仍先读取唯一正式音频 CSV、生成逐字节一致的 `.runtime.txt` 并校验派生数量；随后只在临时发行副本删除音频 manifest 目录中的 CSV、`.csv.import` 和 `.translation`，开发源与许可资料不受影响。
- P1 staging 和 P3 真实 Windows release 导出已验证清理后项目可解析、PCK 可生成且 109 条音频全部加载。
