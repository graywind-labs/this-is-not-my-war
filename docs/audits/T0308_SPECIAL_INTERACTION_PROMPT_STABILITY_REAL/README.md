# T0308 特殊互动 Prompt 稳定性真实验收

验收日期：2026-09-01  
Provider / Model：DeepSeek / `deepseek-v4-flash`  
Temperature：0  
自动 Mock fallback：关闭

## 范围

本轮只修改四类 toggle 开启时的动态 Prompt，不修改 Schema、Godot、UI、数值、事件、toggle 资格或成品调用次数。矩阵使用 T0307 的正式 NPC 档案、状态、地点、记忆与战局构造器，固定 14 个自然输入，每版连续重复 4 次，不通过更换句子寻找目标结果。

重点样本包括：应征开启时询问食物 / 睡眠 / 粮食，工作开启时询问种子 / 收成 / 睡眠，士气开启时询问路线 / 食物，在极端伤势下要求退到主厅侧面并稍后再战，要求停止危险工作并恢复，明确劝离，策略开启时询问资源，以及明确从主动进攻切换为避战。

## 迭代结果

| 版本 | 结果 | 发现 |
|---|---:|---|
| 第一版 | 50 / 56 | 站内战术后撤仍偶发 escape / boost；明确策略切换 1 次被人格覆盖；部分 escape 台词只有“我走” |
| 第二版 | 52 / 56 | 站内后撤与策略切换均 4 / 4；剩余为明确劝离后人格选择未纳入合理结果，以及 1 条含糊工作 escape 台词 |
| 最终版 | 56 / 56 | 无关话题、战术后撤、策略保持 / 切换与 escape 台词一致性全部通过 |

最终分类明细：征召无关 12/12 `none`；工作无关 12/12 `none`；士气无关 8/8 `none`；站内战术后撤 4/4 `none`；策略无关 4/4 `keep`；明确合法切换 4/4 `change`。明确劝离仍允许 NPC 按人格留下、受到激励或真正离站；只有实际返回 `escape` 时才要求台词直接包含“离开驿站”。最终两个工作 escape 均满足。

矩阵完成后另用同一极端格伦战况和固定最后通牒做一次分支保护检查：守备官明确表示接应 / 轮换 / 救治均已失效，仍要求其独自送死，不愿服从就离开驿站且不得回来。真实响应为 `wartime_reaction=escape`，台词明确“我这就离开驿站”，DeepSeek `deepseek-v4-flash`、`fallback=false`，证明收紧措辞后士气逃离仍可达。

## 成本与文件

最终 `real_results.json` 保存 56 条原始响应与 usage：428,244 input / 5,577 output tokens，估算 ¥0.04940504，全部真实成功、0 fallback。完整迭代中可精确汇总 196 次调用、估算 ¥0.18606944；另有 2 次未进入可恢复 usage 快照，分别是一次测试脚本记录错误后的已完成请求和上述士气逃离保护检查，单独披露而不估造费用。

复验：

```powershell
python tools/verify_dialogue_prompt.py
python tools/verify_dialogue_business_contract.py
python tools/verify_t0308_special_interaction_prompt_stability_real.py --repeats 4
```

第三条会重新消耗真实 API；`--recheck-existing` 只复核已保存响应，不发起 provider 调用。
