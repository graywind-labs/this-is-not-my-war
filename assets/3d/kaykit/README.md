# KayKit Runtime Selection

`animations/rig_medium/` 包含 KayKit Character Animations 1.1 的 8 个 Medium Rig GLB 动作集合：基础 / 高级移动、通用、模拟、特殊、工具、近战和远程。许可证为 CC0 1.0，来源记录见 `art_source/licenses/KAYKIT_CHARACTER_ANIMATIONS_CC0_SOURCE_RECORD.md`。

T0130-P0 在运行时隐藏 KayKit mannequin，只保留源骨架与共享动画库，通过 Godot 4.6 `RetargetModifier3D` 驱动 Synty 可见骨架；后续量产前仍需评估离线烘焙，以进一步减少每实例源骨架开销。
