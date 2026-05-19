# UI_UX.md

## 主界面

俯视 3D 驿站地图。

当前实现（T0104）：

- `Main/UI` 使用 `CanvasLayer`。
- `Main/UI/HUD` 使用 `res://scripts/ui/HUD.gd`，在左上角显示基础信息，避免遮挡主要驿站视角。
- `Main/UI/HUD/TitleLabel` 显示游戏标题。
- `Main/UI/HUD/DayLabel`、`TimeLabel`、`PhaseLabel` 显示当前天数、小时和阶段；当前从 `GameState` 读取初始时间。
- `Main/UI/HUD/ResourceStrip` 下的 `GoldLabel`、`FoodLabel`、`WoodLabel`、`StoneLabel`、`IronLabel` 显示资源占位，当前值为 `--`，不代表真实资源系统。
- `Main/UI/HUD/SpeedButton` 和 `AlarmButton` 是加速与警铃按钮占位，当前不触发真实逻辑。
- `Main/UI/HUD/BackendStatusLabel` 显示后端连接状态占位，当前固定为未连接。
- `Main/UI/NPCPanel`、`Main/UI/BuildingPanel`、`Main/UI/DialogPanel` 已作为隐藏占位节点存在。
- 暂未实现真实资源变化、加速、警铃、后端连接、面板内容或交互逻辑。

当前摄像机操作（T0105）：

- `Main/CameraRig` 绑定 `res://scripts/camera/CameraRig.gd`。
- WASD 用于俯视平移。
- 鼠标中键拖拽用于俯视平移。
- 鼠标滚轮用于缩放。
- 摄像机移动和缩放有边界限制，始终保持高机位俯视管理视角。
- 暂不支持角色控制、自由第一人称视角或镜头旋转。

需要显示：

- 时间与天数
- 当前波次倒计时
- 资源栏
- 建筑状态提示
- NPC 头像/状态简表
- NPC 主动交涉问号气泡
- 当前模型调用状态，开发调试用
- 加速按钮
- 警铃按钮

## NPC 面板

点击 NPC 显示：

- 姓名
- 职业背景
- 当前行动
- HP、饱食、疲劳、士气
- 是否昏迷
- 主要熟练度
- 当前装备
- 当前记忆摘要
- 对玩家态度
- 对话按钮
- 赠予金钱按钮
- 给予/更换装备按钮
- 攻击按钮
- 指派按钮，若已入伍

## 建筑面板

点击建筑显示：

- 等级
- HP
- 当前工作位
- 当前产出
- 储存或消耗
- 升级条件
- 修复按钮
- 当前地点信息

## 对话界面

对话界面突出：

- NPC 名字
- NPC 表情或情绪
- 历史对话
- 玩家输入框
- 发送按钮

可选按钮：

- 提出应征
- 赠予金钱
- 结束对话

核心输入应支持自由文本，以突出 AI 玩法。

## 主动交涉气泡

当 NPC 计划中选择主动找玩家交涉时：

- NPC 头顶出现问号气泡。
- 玩家点击后打开对话界面。
- 对话结束后 NPC 重新评估计划。

## 战斗信息

战斗时需要显示：

- 当前波次
- 敌人数量概览
- 我方参战人数概览
- 关键战场公开事件
- 昏迷 NPC 提示
- 建筑受损提示
