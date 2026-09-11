# Art Source Workspace

本目录保存原始下载、许可证、解包后的第三方源文件和 Blender 等 DCC 工作文件。根目录的 `.gdignore` 用于阻止 Godot 扫描和导入这里的大量源文件。

建议布局：

```text
art_source/
├─ downloads/       原始压缩包
├─ quaternius/      按资产包解包的原始内容
├─ licenses/        许可证和来源说明
└─ working/         Blender、导出脚本和中间文件
```

正式场景不得引用本目录。选中的运行时 GLB、纹理和动画应经过 T0124/T0125 审计后进入 `assets/`。

