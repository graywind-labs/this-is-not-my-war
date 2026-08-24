# Presentation Configuration

保存屋顶透明阈值、材质映射、角色外观组合、VFX / 布娃娃预算、音画质量档等表现配置。T0125 的 `art_scale_baseline.json` 已固化统一单位、朝向、角色 / 建筑尺度、过滤、阴影、色板、继承与沙盒性能软上限。

本目录配置只影响显示和性能降级，不得保存资源、HP、伤害、建筑等级、地点、工位、事件或记忆等权威玩法事实。

T0128 新增 `character_appearances.json`（`character_appearance_v1`），只把 NPC ID 映射到正式外观场景、appearance ID、显示名和职业标签；T0130-P8 后欧文映射为 `owen_engineer_chibi_v1`，8/8 名初始 NPC 均已使用 Synty 两头身包装。诊疗、治疗、酿酒、主持、祈祷、制造、修复、升级、训练、睡眠和装备显隐仍由运行时权威状态投影，不写入该配置。这些字段不能替代 `npc_profiles.json` 身份，也不能保存实时装备或动画状态。

T0126 的全局相机范围目前由 `RoofVisibilityController` export 配置，逐建筑 near / far / minimum opacity 由 `BuildingArtView` 场景实例配置；它们都是表现参数。等 T0129 铁匠铺切片通过用户视觉验收后，再判断是否需要抽成统一 JSON，避免在单个样本阶段提前固化所有建筑尺寸。

`station_spatial_plan.json` 是 T0129A 的 `station_spatial_plan_v7` 目标配置，供独立 `StationSpatialSandbox` 和专项校验读取：包含 `700 × 720 m` 单一深绿材质承底、低位河槽、不规则墙门、41 段道路、12 个八方向最大等级地块、80 个最高等级实物 / 升级占地、21:9 镜头压力参数、全幅自然散布，以及第五波 48 人队形 / 路线和长逃离节奏参数。它目前不是 Main 的权威坐标源；修改它不会自动迁移 BuildingSystem、NPCSystem、CombatSystem 或正式导航。

`environment_art.json` 是 T0135 的 `environment_art_v1` 纯表现配置。P1R2 已启用城内地表 / 杂物，P2/P3 新增河谷 / 山脉，P4R 保存前后侧森林 bounds、统一针叶树密度、围墙渐变、河岸 / 山体降密、出生净空及敌 / 商路线排除；P5 的 `natural_scatter` 保存五类分区 seed、目标密度、接触层颜色和排除距离；P6/P7 的 `celestial_cycle` 保存日月轨道、白昼 / 黄金 / 夜晚环境锚点、薄雾和七座封闭建筑的室内补光参数。它不得改变道路、碰撞、导航、时间、火源或建筑状态。
