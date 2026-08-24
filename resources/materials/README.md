# Godot Materials

共享 `.tres` 材质、ShaderMaterial 和调色参数。T0125 已加入环境哑光、2 m 沙盒网格、角色 rim 和选中 outline；T0128 的角色 rim 增加 per-instance `selection_strength`，未选中仍保留弱轮廓、选中时增强。第三方导入场景通过继承场景或材质覆盖引用这里的资源，不直接修改导入生成物。
