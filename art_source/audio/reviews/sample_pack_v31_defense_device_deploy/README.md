# 防御器械部署完成音效候选

状态：用户已选择 01；01 已接入正式程序与资产清单，其余候选不采用。

- `01_short_dry_wood_thud.wav`：最短、最干净的单次木质“嘭”，反馈清楚但体量较小。
- `02_heavy_object_on_wood.wav`：低沉厚重，像整座木架压到木制平台，优先推荐。
- `03_wooden_object_hard_thud.wav`：木材辨识度更强、冲击更硬，尾音比 02 收得快。
- `04_wooden_crate_drop_clatter.wav`：带木箱 / 构件散响，器械感丰富，但比纯“嘭”略忙。
- `05_heavy_frame_drop_resonant.wav`：低频和箱体共鸣明显，体量最大，可能稍显夸张。

试听文件统一整理为 `48 kHz / 16-bit / mono WAV`，峰值约 `-3 dBFS`；只做单声道、裁切、短淡入淡出和峰值规范化，没有接入时的距离衰减或总线混音。原始 Freesound HQ 试听源保存在 `source/`，来源、许可、裁切区间和 SHA-256 见 `SOURCES.csv`。

正式选择为 `01_short_dry_wood_thud.wav`；T0433 起运行时文件为 `assets/audio/ui/sfx_defense_device_deploy_wood_thud_v01.wav`，以全局 2D、UI 总线和 `+3 dB` 播放。
