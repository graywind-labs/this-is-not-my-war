# VOICE_INPUT_AND_EMOTION.md

> 状态：T1601A / T1601B / T1601C、T1602 与 T1603 已完成；T1604 自动化与真实女声矩阵已完成，玩家实机麦克风、中文男声与真人情绪验收尚待完成。  
> 本文是 M16 语音输入、语音转写、玩家语音情绪和发送字数校验的实现合同。

## 1. 目标

在玩家与 NPC 的现有对话面板中增加可选语音输入。语音只负责产生一段可编辑的普通输入文本，不替代、绕过或改写现有对话发送链路。

完整用户流程：

```text
点击麦克风
  -> Godot 开始本地录音，最长 30 个现实秒
  -> 玩家点击“完成”或 30 秒自动完成
  -> 整段 WAV 上传游戏后端
  -> 后端调用阿里云百炼 qwen3-asr-flash
  -> 校验转写文字与原生情绪枚举
  -> 拼装为“转写文字（情绪地）”
  -> 追加到对话输入框现有草稿末尾
  -> 玩家继续编辑并手动点击原“发送”
  -> 沿用现有 DialogSystem -> LLMBridge -> /npc/dialogue
```

必须满足：

- 输入框右侧增加麦克风图标按钮。
- 录音中在对话框中部显示大号、透明度呼吸闪烁的麦克风图标、“正在录音……”提示、现实秒计时和“完成”按钮。
- 单次录音硬上限为 30 个现实秒；超时自动结束并送去识别。
- 每次都在完成后提交整段录音，不做实时字幕，不边录边上传。
- 识别结果追加到当前草稿末尾，绝不覆盖已有文字，也不自动发送。
- 语音识别失败时保留现有草稿，玩家仍可手动输入。
- 文本框暂存不设字数上限；只有发送时检查上限。
- 本阶段发送上限固定为 300 字。超过 300 字时弹出“输入文字超过上限300字”，保留全文并阻止发送。

## 2. 非目标

- 不修改 NPC 对话 Prompt、对话响应 Schema、记忆结构或对话事件结构。
- 不让语音模型直接请求 NPC 回复、决定征召、鼓舞、战斗策略或任何权威状态。
- 不实现实时语音对话、实时转写、语音唤醒、自动发送、声纹识别或多人说话人分离。
- 不把录音保存进玩家存档、事件库、见闻库、对话记录或长期日志。
- 不为了填满情绪标签而把模型不支持的情绪强行映射成另一种含义。

## 3. Provider 决策

### 3.1 正式 Provider

正式语音 Provider 固定使用阿里云百炼华北 2（北京）地域的非实时 `qwen3-asr-flash`。

选择理由：

- 中国大陆网络可直接访问，不要求玩家使用代理。
- 单次请求同时返回转写文字和原生情绪标签，不需要第二个情绪模型。
- 支持 Base64 WAV；单次上限 10 MB / 5 分钟，本项目另行收紧为 30 秒。
- 按音频秒数计费，华北 2 当前公开价格为 `0.00022 元/秒`，30 秒约 `0.0066 元`。
- 当前新人免费额度为 36,000 秒（10 小时）；价格与额度以后端配置和调用时的官方页面为准，不在客户端写死。

官方资料：

- [Qwen-ASR 模型与音频规格](https://help.aliyun.com/zh/model-studio/asr-model/)
- [Qwen-ASR API 参考](https://help.aliyun.com/zh/model-studio/qwen-asr-api-reference)
- [非实时语音识别与情感字段](https://help.aliyun.com/zh/model-studio/non-realtime-speech-recognition-user-guide)
- [阿里云百炼模型价格](https://help.aliyun.com/zh/model-studio/model-pricing)

### 3.2 调用方式

- Godot 不直连阿里云，不保存百炼 API Key。
- Godot 使用 `multipart/form-data` 把 WAV 上传到游戏后端 `POST /voice/analyze`。
- 后端检查格式、大小和时长后，把 WAV 编码为 Base64 Data URI。
- 后端使用百炼 OpenAI 兼容 HTTP 接口调用 `qwen3-asr-flash`，请求地址由北京地域 `VOICE_BASE_URL` 和 `VOICE_WORKSPACE_ID` 组成。
- Provider Key 只从服务器环境变量 `DASHSCOPE_API_KEY` 读取。
- 不复用 `LLM_PROVIDER=deepseek` 作为语音 Provider，也不把百炼 Key 交给 Godot 客户端。

### 3.3 原生情绪范围

`qwen3-asr-flash` 原生返回以下七类情绪：

| Provider 枚举 | 玩家文本后缀 |
|---|---|
| `neutral` | `（平静地）` |
| `happy` | `（愉快地）` |
| `sad` | `（悲伤地）` |
| `disgusted` | `（厌恶地）` |
| `angry` | `（愤怒地）` |
| `fearful` | `（恐惧地）` |
| `surprised` | `（惊讶地）` |

第一版不宣称识别“低沉、急促、嘲讽”：

- 不把 `sad` 冒充为“低沉”。
- 不从语速自行伪造“急促”。
- 不从词义自行伪造“嘲讽”。
- Provider 没有返回情绪、返回空值或未知枚举时，只追加转写文字，不追加括号。
- 如果以后确实需要这三类，另立后续任务评估声学特征或第二模型，不扩张本轮范围。

## 4. 前后端合同

### 4.1 Godot 到游戏后端

```http
POST /voice/analyze
Content-Type: multipart/form-data
```

表单字段：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `audio` | WAV 文件 | 是 | Godot 本次完整录音 |
| `request_id` | string | 是 | 客户端生成的唯一请求 ID |
| `npc_id` | string | 是 | 仅用于审计定位，不改变 NPC 状态 |
| `dialogue_id` | string | 是 | 用于丢弃关闭会话的迟到结果 |
| `locale` | string | 否 | 第一版固定 `zh` |

客户端限制：

- WAV。
- 最长 30 秒。
- 最多 6 MiB（6,291,456 bytes）原始上传体，可容纳约 30 秒的 48 kHz 双声道 16-bit PCM WAV，并为 Base64 / JSON 封装和 Provider 10 MB 限制留出余量。
- 同一 `DialogPanel` 同时最多 1 个录音或识别请求。

服务端必须再次校验，不能信任客户端时长和 MIME 声明。WAV 时长使用文件头读取；超过 30 秒、文件损坏、空文件或格式不支持时，不调用 Provider。

### 4.2 成功响应

```json
{
  "ok": true,
  "request_id": "voice_...",
  "dialogue_id": "dialogue_...",
  "transcript": "我需要你保卫驿站。",
  "emotion": "angry",
  "emotion_label": "愤怒地",
  "emotion_applied": true,
  "duration_seconds": 8.43,
  "model_provider": "alibaba_dashscope",
  "model_name": "qwen3-asr-flash",
  "model_fallback_used": false
}
```

说明：

- `transcript` 必须去除首尾空白，但不得改写玩家措辞。
- `emotion` 只允许七个正式枚举或 `none`。
- `emotion_applied=false` 时，客户端忽略 `emotion_label`。
- 后端不直接返回最终对话回复，也不写 NPC 事件。

### 4.3 失败响应

```json
{
  "ok": false,
  "request_id": "voice_...",
  "error_code": "voice_provider_timeout",
  "message": "语音识别超时，请重试或继续手动输入。",
  "fallback_used": false,
  "details": [],
  "usage": {}
}
```

至少区分：

- `microphone_unavailable`：客户端无可用输入设备或没有权限。
- `recording_empty`：没有得到有效录音。
- `audio_invalid`：WAV 损坏或不支持。
- `audio_too_long`：超过 30 秒。
- `audio_too_large`：超过上传上限。
- `voice_provider_unavailable`：Key、Workspace 或 Provider 配置缺失。
- `voice_provider_timeout`：Provider 超时。
- `voice_provider_http_error`：Provider HTTP 错误。
- `voice_provider_invalid_response`：返回非 JSON、缺少可用转写正文或响应结构无法解析。情绪枚举非法但转写可用时不让整次失败，而是归一化为 `none` 并记录异常。
- `voice_budget_exceeded`：API 日预算不足。

任何失败都不能生成 Mock 文字或 Mock 情绪冒充成功。

## 5. Godot 录音实现

T1601B 已按本节接入：工程音频输入、静音 `MicRecord`、唯一 `AudioEffectRecord`、`AudioStreamMicrophone`、30 秒现实 Timer、临时 WAV 与生命周期清理均已落地。T1601C 已让文件保持到请求完成，并在成功、失败或取消后精确清理。

### 5.1 音频接线

- 录音接线遵循 [Godot 4 麦克风录音指南](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html)。
- 在 `project.godot` 开启 `audio/driver/enable_input=true`。
- 在 `default_bus_layout.tres` 增加专用 `MicRecord` 总线。
- `MicRecord` 挂载 `AudioEffectRecord` 并静音输出，避免麦克风声音回放到扬声器。
- 对话面板的录音控制器使用 `AudioStreamPlayer + AudioStreamMicrophone`，播放器输出到 `MicRecord`。
- 正式游戏的 Music / SFX / Ambience / UI / Voice 音量滑杆不改变麦克风采集增益。

### 5.2 状态机

```text
IDLE
  -> RECORDING
  -> ANALYZING
  -> IDLE（成功追加或失败提示）
```

约束：

- `IDLE`：麦克风按钮可用。
- `RECORDING`：启动 30 秒 `Timer`，Timer 忽略游戏逻辑倍率；显示闪烁麦克风、“正在录音……x/30秒”和“完成”。
- `ANALYZING`：停止录音；大图标停止闪烁，提示改为“正在识别语音与情绪……”，“完成”按钮隐藏或禁用。
- 录音和识别期间禁用输入框、麦克风、发送和攻击，避免草稿与迟到结果交错；已有文字不清空。
- 完成、取消、挂起或关闭对话时，如果仍在录音或识别，先终止本地状态并使当前请求失效。
- 识别响应只有在 `dialogue_id` 和 `request_id` 仍匹配当前活动请求时才能应用；迟到结果直接丢弃。
- 语音预处理不是 NPC 请求，不申请 TimeSystem 的 LLM 慢速；30 秒和 UI 呼吸动画均使用现实时间。

### 5.3 临时文件

- 录音结束后保存到 `user://voice_input/<request_id>.wav`。
- 上传完成、失败、取消或场景退出后都删除该临时文件。
- 不把 WAV 写入项目目录，不加入 Git，不写入玩家存档。
- 启动新的录音前可清理上次异常退出遗留的本模块临时文件，但只能清理精确的 `user://voice_input/` 子目录。

## 6. 对话面板 UI

`InputRow` 顺序固定为：

```text
DialogInputEdit | DialogVoiceButton | DialogSendButton | DialogAttackButton
```

麦克风按钮：

- 使用项目风格的本地 SVG，不使用 Emoji 或依赖系统字体的麦克风字符。
- 推荐最小尺寸 `36x36px`，与发送按钮同高。
- Tooltip 为“语音输入（最长30秒）”。
- 玩家控制的活动对话中显示；NPC-NPC 旁听模式隐藏。
- 没有活动会话、已经在识别或麦克风不可用时禁用。

录音覆盖层：

- 覆盖对话历史区域中央，不改变页眉、输入行和底部三种会话按钮的永久布局。
- 使用透明背景；大号麦克风图标在约 `35% -> 100%` alpha 之间循环呼吸闪烁。
- 图标下显示“正在录音……x/30秒”。
- 提示下方显示独立“完成”按钮，不能与底部“完成对话”混淆。
- 进入识别状态后显示“正在识别语音与情绪……”，不再显示录音完成按钮。
- 底部完成 / 取消 / 挂起对话仍可结束当前会话，但必须先安全取消录音或使识别请求失效。

## 7. 识别结果拼装与追加

拼装规则：

```text
recognized_segment = transcript.strip_edges()
if emotion_applied:
    recognized_segment += "（" + emotion_label + "）"
```

追加规则：

- 输入框为空：直接写入 `recognized_segment`。
- 输入框非空且末尾已经是空白：直接追加。
- 输入框非空且末尾不是空白：先追加一个半角空格，再追加识别段，防止与原文字粘连。
- 设置输入光标到最终文字末尾，并恢复输入焦点。
- 不自动点击发送，不自动触发应征、鼓舞、策略或攻击。
- 不自动为转写补标点，也不修改 Provider 返回的正文。

示例：

```text
已有草稿：敌人马上就到了，
转写文字：我需要你保卫驿站。
情绪：angry
最终草稿：敌人马上就到了， 我需要你保卫驿站。（愤怒地）
```

最终拼装结果作为普通 `speaker_text` 进入现有对话链。NPC 看到括号中的语气说明后可自然参考，但系统不增加新的对话字段或 Prompt 分支。

## 8. 文本暂存与发送上限

### 8.1 单一配置源

新增 `data/dialogue_input_config.json`：

```json
{
  "schema_version": 1,
  "player_message_max_characters": 300,
  "voice_recording_max_seconds": 30,
  "voice_upload_max_bytes": 6291456
}
```

- `DialogInputEdit.max_length` 保持 `0`，允许无限暂存和编辑。
- UI 与 DialogSystem 从同一配置读取 200，不各写一份常量。
- 语音识别结果即使让草稿超过 300 字也仍完整追加；只在玩家尝试发送时拦截。

### 8.2 发送校验

发送按钮和 Enter 提交必须进入同一个校验函数：

1. 读取当前文本并仅去除首尾空白。
2. 空文本沿用现有提示。
3. 使用 Godot `String.length()` 计算最终提交字符数；汉字、标点、空格和情绪后缀都计入。
4. `length <= 300` 才允许进入 `DialogSystem.send_player_message(...)`。
5. `length > 300` 时显示 `AcceptDialog`：`输入文字超过上限300字`。
6. 超限时不清空输入框、不追加历史、不启动后端请求、不锁定公开性、不触发特殊 toggle，也不产生冷却或事件。

`DialogSystem` 仍做第二层相同校验，防止其他调用者绕过 UI。UI 负责弹窗，系统只返回明确错误码和上限。

当前 `_send_current_text()` 在调用系统前清空草稿。实现时调整为：只有 `DialogSystem` 接受本次发送后才清空；超限、系统拒绝或同步失败时保留全文。

## 9. 后端职责与安全

建议新增独立 `VoiceModelAdapter`，不要把音频逻辑塞进现有文本 `ModelAdapter`：

- `VOICE_PROVIDER=mock|qwen3_asr_flash`，本地开发默认可显式使用 `mock`。
- `VOICE_MODEL=qwen3-asr-flash`。
- `VOICE_BASE_URL`、`VOICE_WORKSPACE_ID`、`VOICE_TIMEOUT_SECONDS`。
- `DASHSCOPE_API_KEY` 只存在于 `backend/.env` 或服务器环境变量。
- `mock` 只用于 Schema、传输、UI 和自动化；真实模式失败不得自动 fallback 到 mock。
- 后端请求日志不得记录 Base64 音频、原始 WAV、Authorization header 或 API Key。
- 生产端点必须使用 HTTPS，并结合 T1407 的服务器限流；客户端不得直接拿到供应商凭据。

usage / 审计至少记录：

- `request_id`
- `call_type=voice_transcription_emotion`
- `provider=alibaba_dashscope`
- `model=qwen3-asr-flash`
- `npc_id`、`dialogue_id`
- `duration_seconds`
- `estimated_cost_cny`
- HTTP 状态或异常类型
- 失败原因
- `fallback_used=false`

语音费用计入现有每日人民币预算。预算不足时语音功能返回可处理错误，但文本对话仍可继续；不因为语音预算不足禁止玩家手动发送文字。

## 10. 失败与边界行为

| 场景 | 预期结果 |
|---|---|
| 玩家拒绝麦克风权限 | 提示无权限，草稿不变，可手动输入 |
| 没有输入设备 | 提示麦克风不可用，草稿不变 |
| 点击完成 | 立即停止并提交本次完整录音 |
| 达到 30 秒 | 自动执行与“完成”完全相同的提交路径，只触发一次 |
| 空音频或 Provider 无转写 | 不追加文字，提示重试或手动输入 |
| 转写成功、情绪缺失 | 只追加转写文字 |
| 情绪为未知枚举 | 后端归一化为 `none`，只追加文字并记录响应异常 |
| 后端断开 / 超时 | 保留草稿，关闭覆盖层，允许再次录音或手动输入 |
| 识别中关闭 / 挂起 /完成 / 取消对话 | 请求失效，迟到结果不得写入其他会话 |
| 草稿因语音追加超过 300 字 | 允许继续编辑；发送时弹窗并拦截 |
| 恰好 300 字 | 允许发送 |
| 301 字 | 弹窗、保留全文、不产生请求 |

## 11. 验证矩阵

### 11.1 本地自动化 / 显式 Mock

- 麦克风按钮节点、顺序、图标、Tooltip、旁听模式隐藏。
- `IDLE -> RECORDING -> ANALYZING -> IDLE` 状态切换。
- 手动完成与 30 秒自动完成共用单一提交路径，不双发。
- 大图标 alpha 呼吸、录音文案、完成按钮、识别文案。
- 对话关闭、取消、挂起和场景退出清理录音、Timer、请求与临时文件。
- 空草稿和已有草稿的追加；已有草稿不覆盖。
- 合法情绪七类的中文后缀；缺失 / 非法情绪只追加文字。
- Mock 成功、400、401/403、429、500、超时、非 JSON、缺字段。
- 输入 299 / 300 / 301 字；语音后缀把草稿推过 300 字；按钮和 Enter 行为一致。
- 超限不清空、不入历史、不调用 `/npc/dialogue`、不改变特殊 toggle 状态。
- 现有对话、攻击、应征、工作鼓励、士气、策略、逃离挽留、NPC-NPC 旁听回归不变。

### 11.2 真实 Provider

在基础 Mock 通过、用户授权且本机 / 服务器已有真实 Key 后执行：

- 显式 `VOICE_PROVIDER=qwen3_asr_flash`，关闭所有 Mock fallback。
- 普通话男女声、轻噪声、短句、接近 30 秒长句。
- 七类情绪至少各准备若干真实录音；无法稳定演出的类别记录实际误差，不改测试答案迎合模型。
- 驿站、守备官、NPC 姓名等游戏词汇转写检查。
- `GET /debug/llm_usage` 或后续统一 usage 入口能定位真实 request id、时长、Provider、模型、费用和 `fallback_used=false`。
- 实测国内网络、上传延迟和 30 秒文件大小。
- 真实 API 未验收时，T1602 / T1604 只能为 Partial 或 Blocked，不能标 Done。

### 11.3 用户前端验收

- F5 进入 Main，与任意 NPC 打开玩家对话。
- 确认麦克风位于输入框右侧。
- 输入一段已有文字后录音，确认识别段追加而非覆盖。
- 点击“完成”和等待 30 秒两种方式各验证一次。
- 确认识别后不会自动发送；玩家可以继续编辑。
- 将最终草稿改为 301 字，确认弹出“输入文字超过上限300字”且全文仍在。
- 将草稿缩短到 300 字，确认可沿用原按钮发送并得到 NPC 回复。

该功能直接在 Main 前端可见并可完整触发、观察，不新增 GM 权威入口。后端错误与成本继续通过日志 / usage 入口诊断。

## 12. 分步实施任务

以下顺序以 `docs/TASKS.md` 为正式状态源：

1. `T1601A`：配置、Voice Schema、显式 Mock endpoint 与费用记录骨架。
2. `T1601B`：Godot 麦克风录制、30 秒 Timer 和录音覆盖层。已完成。
3. `T1601C`：Godot 到 Mock 后端闭环、结果拼装、追加和会话失效保护。已完成。
4. `T1603`：无限暂存、300 字发送时双层校验和弹窗。已完成。
5. `T1602`：接入真实 `qwen3-asr-flash`、七类情绪归一化和真实失败日志。已完成，并通过真实北京地域 API 验收。
6. `T1604`：完整自动化、现有对话回归、国内真实 API 与 Main 前端验收。

每一步完成后都按 AGENTS.md 回写 CURRENT_STATE、TASKS、MODULE_INDEX、对应模块文档和 DEV_LOG；没有用户确认不得提前执行下一实现阶段。
