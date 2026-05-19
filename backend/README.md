# Backend README

本目录用于 Python 后端，负责：

- LLM API 调用
- Prompt 拼装
- JSON 校验
- NPC 对话
- 每日计划
- 战斗心理判定
- 睡前总结
- 知识图谱更新
- API 额度统计

禁止在仓库中提交真实 API Key。

推荐本地环境变量：

```bash
LLM_PROVIDER=deepseek
LLM_API_KEY=your_local_key
```

初始接口建议：

- `GET /health`
- `POST /npc/dialogue`
- `POST /npc/plan_day`
- `POST /npc/battle_judgement`
- `POST /npc/daily_reflection`
