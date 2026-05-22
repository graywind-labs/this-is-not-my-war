# UI_UX.md

## 主界面

俯视 3D 驿站地图。

当前实现（T0104 / T0202 / T0204 / T0205 / T0303）：

- `Main/UI` 使用 `CanvasLayer`。
- `Main/UI/HUD` 使用 `res://scripts/ui/HUD.gd`，在左上角显示基础信息，避免遮挡主要驿站视角。
- `HUD.gd` 会把 HUD 根节点设为鼠标忽略，避免全屏 HUD 背板拦截 3D 建筑点击；具体按钮仍保留自身交互能力。
- `Main/UI/HUD/TitleLabel` 显示游戏标题。
- `Main/UI/HUD/DayLabel`、`TimeLabel`、`PhaseLabel` 显示当前天数、`HH:MM:SS` 时间和阶段；当前随 `TimeSystem` 推进并监听 `EventBus.time_changed` / `hour_started` / `day_started` 刷新。
- `Main/UI/HUD/ResourceStrip` 下的 `GoldLabel`、`FoodLabel`、`WoodLabel`、`StoneLabel`、`IronLabel` 显示 `ResourceSystem` 的当前资源数值。
- `HUD.gd` 监听 `EventBus.resource_changed`，资源变化后自动刷新资源栏。
- `Main/UI/HUD/SpeedButton` 已接入 `TimeSystem`，点击后按 `x1` / `x2` / `x4` 循环切换流速。
- `Main/UI/HUD/PauseButton` 控制暂停/继续，空格键绑定到同一套暂停/继续逻辑；空格不触发速度切换。
- `AlarmButton` 仍是警铃占位，当前不触发真实逻辑。
- `Main/UI/HUD/BackendStatusLabel` 显示后端连接状态占位，当前固定为未连接。
- 后续 API / 调试面板需要显示当前模型调用状态、等待中的 LLM 请求数量、TimeSystem 有效逻辑倍率和最近一次慢速原因；当前 HUD 只显示玩家设定的速度倍率。
- `Main/UI/BuildingPanel` 绑定 `res://scripts/ui/BuildingPanel.gd`，点击建筑后显示建筑名称、等级、HP / Max HP、工作位、地点信息占位，以及修复/升级消耗摘要。
- `BuildingPanel` 内的修复、升级按钮会调用 `BuildingSystem`；按钮根据当前 HP、等级、配置和资源是否足够自动启用或禁用。
- `Main/UI/NPCPanel` 绑定 `res://scripts/ui/NPCPanel.gd`，点击 NPC 后显示 NPC 基础状态、力量/智力属性和专长；状态变化会随 `npc_state_changed` 刷新。
- `NPCPanel` 和 `BuildingPanel` 会随 `npc_clicked` / `building_clicked` 互斥切换，右上角只显示当前点击对象的面板。
- `Main/UI/DialogPanel` 已作为隐藏占位节点存在。
- 暂未实现警铃、后端连接、对话面板或生产细节。

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
- HP
- 属性：力量、智力
- 专长，由最高熟练度推导
- 当前行动
- 饱食、疲劳、士气
- 是否昏迷
- 职业熟练度与武器熟练度
- 当前装备
- 当前记忆摘要，后续应区分亲历事件库和见闻库
- 对玩家态度
- 对话按钮
- 赠予金钱按钮
- 给予/更换装备按钮
- 攻击按钮
- 指派按钮，若已入伍

当前实现（T0303）：

- 点击 NPC 会打开右上角 `NPCPanel`。
- 当前按姓名、HP / Max HP、属性、专长、饱食度、疲劳度、金钱、是否昏迷、是否已入伍、当前行动占位、职业熟练度和武器熟练度显示。
- 属性显示力量和智力，对应 `game_design.md` 中体力相关产出/生命/移动/载重，以及智力相关产出/熟练度成长系数。
- 专长不是写死职业，而是从 NPC 最高的固定熟练度维度推导。
- 面板可通过关闭按钮隐藏。
- `NPCSystem.update_npc_state(...)` 修改状态后会发出 `npc_state_changed`，打开中的 NPC 面板会刷新。
- 当前不实现对话、赠予金钱、装备、攻击、指派按钮或记忆摘要。

## 建筑面板

点击建筑显示：

- 建筑名称
- 等级
- HP
- 当前工作位
- 当前地点信息占位
- 修复按钮，资源足够且建筑受损时可用
- 升级按钮，资源足够且未达最高等级时可用

当前实现（T0204 / T0205）：

- 点击 `BuildingSystem` 绑定过的低模建筑后，`EventBus.building_clicked` 会驱动 `BuildingPanel` 显示对应建筑信息。
- 面板位于屏幕右上角，可通过关闭按钮隐藏。
- 2026-05-20 已修正真实鼠标点击无法打开面板的问题：HUD 根节点不再吃掉地图点击，`BuildingSystem` 也会在 `_unhandled_input` 中用相机射线拾取建筑点击区。
- 当前显示修复/升级石料消耗摘要，并可触发最小修复/升级结算；资源不足或条件不满足时按钮禁用。
- 当前不显示真实产出、储存或完整升级树。

后续需要补充：

- 当前产出
- 储存或消耗
- 升级条件
- 当前地点信息

地点信息后续应来自 `MemorySystem` 的地点信息空间，而不是 UI 自行拼接。建筑面板需要显示当前人员、工位/床位占用、近期公开事件；广场面板或调试信息需要额外显示主厅、围墙、城门等不可进入实体状态。

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

战斗信息中的公开事件应来自广场信息空间。UI 只展示事件摘要，不决定事件是否公开。
