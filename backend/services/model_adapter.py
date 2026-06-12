import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any


@dataclass(frozen=True)
class ModelAdapterConfig:
    provider: str
    api_key: str | None


@dataclass(frozen=True)
class ModelUsageRecord:
    timestamp: str
    provider: str
    call_type: str
    request_id: str | None
    npc_id: str | None
    related_event_id: str | None
    input_tokens: int
    output_tokens: int
    estimated_cost: float
    success: bool
    failure_reason: str = ""


@dataclass(frozen=True)
class ModelAdapterResult:
    ok: bool
    provider: str
    call_type: str
    content: dict[str, Any]
    usage: dict[str, Any]
    error_code: str = ""
    message: str = ""


class ModelAdapter:
    """Provider boundary with a deterministic mock backend for local development."""

    SKILL_TO_WORK_ACTION = {
        "养马": "work_stable",
        "厨艺": "work_dining_hall",
        "耕种": "work_garden",
        "打铁": "work_blacksmith",
        "教练": "work_garden",
        "酿酒": "work_tavern",
        "医术": "work_clinic_doctor",
        "工程": "work_workshop",
    }

    def __init__(self, config: ModelAdapterConfig | None = None) -> None:
        raw_config = config or ModelAdapterConfig(
            provider=os.getenv("LLM_PROVIDER", "mock"),
            api_key=os.getenv("LLM_API_KEY"),
        )
        provider = raw_config.provider.strip().lower() or "mock"
        self.config = ModelAdapterConfig(provider=provider, api_key=raw_config.api_key)
        self._usage_records: list[ModelUsageRecord] = []

    def is_configured(self) -> bool:
        if self.config.provider == "mock":
            return True
        return bool(self.config.api_key)

    def generate(self, call_type: str, payload: dict[str, Any] | None = None) -> ModelAdapterResult:
        payload = payload or {}
        input_tokens = self._estimate_tokens(payload)
        request_id = self._read_request_id(payload)
        npc_id = self._read_npc_id(payload)
        related_event_id = self._read_related_event_id(payload)

        if self.config.provider != "mock":
            message = "Only the mock provider is implemented in this task."
            if not self.config.api_key:
                message = "LLM_API_KEY is required for non-mock providers."
            usage = self._record_usage(
                call_type=call_type,
                request_id=request_id,
                npc_id=npc_id,
                related_event_id=related_event_id,
                input_tokens=input_tokens,
                output_tokens=0,
                success=False,
                failure_reason=message,
            )
            return ModelAdapterResult(
                ok=False,
                provider=self.config.provider,
                call_type=call_type,
                content={},
                usage=usage,
                error_code="provider_unavailable",
                message=message,
            )

        content = self._mock_content(call_type, payload)
        output_tokens = self._estimate_tokens(content)
        usage = self._record_usage(
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            success=True,
        )
        return ModelAdapterResult(
            ok=True,
            provider=self.config.provider,
            call_type=call_type,
            content=content,
            usage=usage,
        )

    def get_usage_records(self) -> list[dict[str, Any]]:
        return [asdict(record) for record in self._usage_records]

    def _mock_content(self, call_type: str, payload: dict[str, Any]) -> dict[str, Any]:
        npc_id = self._read_npc_id(payload) or "unknown_npc"
        day = self._read_game_day(payload)
        order_suffix = self._current_order_debug_suffix(payload)

        if call_type == "dialogue":
            text = self._read_dialogue_text(payload)
            is_recruitment_request = bool(
                payload.get("is_recruitment_request", payload.get("propose_recruitment", False))
            )
            dialogue_kind = str(payload.get("dialogue_kind", "player_npc"))
            current_round, max_rounds = self._read_dialogue_rounds(payload)
            rounds_left = max_rounds - current_round
            is_npc_reply = dialogue_kind == "npc_npc"
            accepts = is_recruitment_request and any(word in text for word in ["守住", "保护", "应征", "帮忙", "一起", "救"])
            rejects = is_recruitment_request and not accepts
            should_end = is_npc_reply and rounds_left <= 1
            if is_npc_reply:
                reply_text = "我听明白了。先到这里吧，别让这段谈话耽误手上的事。"
                if rounds_left > 1:
                    reply_text = "我会记住你说的话。现在先把能做的事做稳。"
            else:
                reply_text = "守备官，我会先把能做的事做好。若真到了门口，我也不会装作没听见。"
                if rejects:
                    reply_text = "守备官，我听见了，但我还不能答应把自己交给这场仗。"
            return {
                "ok": True,
                "replyer_id": npc_id,
                "reply_text": reply_text,
                "response_kind": "reply_to_npc" if is_npc_reply else "reply_to_player",
                "intent": "accept_recruitment" if accepts else "reject_recruitment" if rejects else "end_talk" if should_end else "continue_talk",
                "emotion": "wary",
                "recruitment_result": "accept" if accepts else "reject" if rejects else "none",
                "should_end_dialogue": should_end,
                "suggested_event_type": "dialogue_turn",
                "debug_reason": f"mock_dialogue_by_keywords_and_round_limit{order_suffix}",
            }

        if call_type == "plan_day":
            work_action_id = self._first_allowed_work_action(payload)
            plan = []
            for hour in range(24):
                if 0 <= hour <= 5:
                    item = self._plan_item(hour, "sleep", "sleep_in_dormitory", "dormitory", "夜里先恢复体力。")
                elif hour in [6, 12, 18]:
                    item = self._plan_item(hour, "eat", "eat_at_dining_hall", "dining_hall", "按时吃饭才能继续撑住。")
                elif 8 <= hour <= 13:
                    item = self._plan_item(hour, "work", work_action_id, self._location_for_allowed_action(payload, work_action_id), "白天优先完成本职工作。")
                elif 14 <= hour <= 16:
                    item = self._plan_item(hour, "idle", "idle", "plaza", "留在广场观察驿站情况。")
                elif 17 <= hour <= 20:
                    item = self._plan_item(hour, "work", work_action_id, self._location_for_allowed_action(payload, work_action_id), "傍晚继续补上驿站需要的工作。")
                elif hour >= 22:
                    item = self._plan_item(hour, "sleep", "sleep_in_dormitory", "dormitory", "夜深后休息，避免明天无力做事。")
                else:
                    item = self._plan_item(hour, "idle", "idle", "plaza", "等待新的安排。")
                plan.append(item)
            return {
                "ok": True,
                "npc_id": npc_id,
                "plan_day": day,
                "plan": plan,
                "summary": "Mock 生成了 24 小时稳定日程。",
                "debug_reason": f"mock_24_hour_template{order_suffix}",
            }

        if call_type == "revise_plan":
            immediate = self._plan_item(
                self._read_game_hour(payload),
                "idle",
                "idle",
                "plaza",
                "原计划失败，先回到广场等待守备官安排。",
            )
            return {
                "ok": True,
                "npc_id": npc_id,
                "revised_plan": [immediate],
                "immediate_action": immediate,
                "summary": "Mock 将异常计划修订为等待状态。",
                "debug_reason": f"mock_safe_fallback_revision{order_suffix}",
            }

        if call_type == "battle_judgement":
            allowed = payload.get("allowed_decisions", [])
            decision = "join_battle" if "join_battle" in allowed else allowed[0] if allowed else "avoid_battle"
            return {
                "ok": True,
                "npc_id": npc_id,
                "decision": decision,
                "emotion": "tense",
                "morale_delta_intent": 0,
                "should_start_escape": decision == "escape_station",
                "debug_reason": f"mock_first_safe_allowed_decision{order_suffix}",
            }

        if call_type == "daily_reflection":
            return {
                "ok": True,
                "npc_id": npc_id,
                "day": day,
                "diary_entry": "今天驿站仍然紧绷。我记下了守备官的安排，也记下了大家脸上的疲惫。",
                "memory_summary": "Mock 总结：记录当天关键事件，等待真实模型替换。",
                "knowledge_graph_updates": [
                    {
                        "subject": npc_id,
                        "relation": "noticed",
                        "value": "驿站压力正在上升",
                        "confidence": 0.6,
                    }
                ],
                "debug_reason": f"mock_reflection_template{order_suffix}",
            }

        if call_type == "knowledge_graph_update":
            return {
                "ok": True,
                "npc_id": npc_id,
                "updates": [],
                "debug_reason": f"mock_noop_knowledge_graph{order_suffix}",
            }

        if call_type == "proactive_intention":
            return {
                "ok": True,
                "npc_id": npc_id,
                "should_seek_guard_officer": False,
                "topic": "",
                "urgency": 0,
                "debug_reason": f"mock_no_proactive_interrupt{order_suffix}",
            }

        if call_type == "player_strategy_classification":
            return {
                "ok": True,
                "strategy": "unknown",
                "confidence": 0.25,
                "debug_reason": "mock_default_classification",
            }

        return {
            "ok": True,
            "call_type": call_type,
            "message": "Mock provider returned a generic stable JSON payload.",
            "debug_reason": "mock_generic_response",
        }

    def _record_usage(
        self,
        call_type: str,
        request_id: str | None,
        npc_id: str | None,
        related_event_id: str | None,
        input_tokens: int,
        output_tokens: int,
        success: bool,
        failure_reason: str = "",
    ) -> dict[str, Any]:
        record = ModelUsageRecord(
            timestamp=datetime.now(timezone.utc).isoformat(),
            provider=self.config.provider,
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost=0.0,
            success=success,
            failure_reason=failure_reason,
        )
        self._usage_records.append(record)
        return asdict(record)

    def _estimate_tokens(self, value: Any) -> int:
        text = str(value)
        return max(1, (len(text) + 3) // 4)

    def _read_request_id(self, payload: dict[str, Any]) -> str | None:
        meta = payload.get("meta", {})
        if isinstance(meta, dict):
            return meta.get("request_id")
        return None

    def _read_related_event_id(self, payload: dict[str, Any]) -> str | None:
        meta = payload.get("meta", {})
        if isinstance(meta, dict):
            return meta.get("related_event_id")
        return None

    def _read_npc_id(self, payload: dict[str, Any]) -> str | None:
        if isinstance(payload.get("npc_id"), str):
            return payload["npc_id"]
        for key in ["npc", "speaker_npc"]:
            npc = payload.get(key, {})
            if isinstance(npc, dict):
                identity = npc.get("identity", {})
                if isinstance(identity, dict) and identity.get("npc_id"):
                    return identity["npc_id"]
        return None

    def _read_dialogue_text(self, payload: dict[str, Any]) -> str:
        for key in ["speaker_text", "player_text", "npc_text", "guard_officer_input"]:
            if payload.get(key) is not None:
                return str(payload.get(key, ""))
        return ""

    def _read_dialogue_rounds(self, payload: dict[str, Any]) -> tuple[int, int]:
        current_round = payload.get("current_round")
        max_rounds = payload.get("max_rounds")
        dialogue_state = payload.get("dialogue_state", {})
        if isinstance(dialogue_state, dict):
            current_round = current_round or dialogue_state.get("current_round")
            max_rounds = max_rounds or dialogue_state.get("max_rounds")
        return int(current_round or 1), int(max_rounds or 1)

    def _current_order_debug_suffix(self, payload: dict[str, Any]) -> str:
        current_order = payload.get("current_order", {})
        if not isinstance(current_order, dict) or not str(current_order.get("text", "")).strip():
            npc = payload.get("npc", {})
            current_order = npc.get("current_order", {}) if isinstance(npc, dict) else {}
        if isinstance(current_order, dict) and str(current_order.get("text", "")).strip():
            return "_with_current_order_as_reference"
        return "_without_current_order"

    def _read_game_day(self, payload: dict[str, Any]) -> int:
        game_time = payload.get("game_time", {})
        if isinstance(game_time, dict):
            return int(game_time.get("day", 1))
        return 1

    def _read_game_hour(self, payload: dict[str, Any]) -> int:
        game_time = payload.get("game_time", {})
        if isinstance(game_time, dict):
            return int(game_time.get("hour", 0))
        return 0

    def _first_allowed_work_action(self, payload: dict[str, Any]) -> str:
        actions = payload.get("allowed_actions", [])
        allowed_ids: set[str] = set()
        if isinstance(actions, list):
            for action in actions:
                if isinstance(action, dict):
                    allowed_ids.add(str(action.get("action_id", "")))
        skilled_action = self._best_skill_work_action(payload)
        if skilled_action in allowed_ids:
            return skilled_action
        if isinstance(actions, list):
            for action in actions:
                if not isinstance(action, dict):
                    continue
                tags = action.get("tags", [])
                action_id = str(action.get("action_id", ""))
                if "work" in tags or action_id.startswith("work_"):
                    return action_id
            if actions and isinstance(actions[0], dict):
                return str(actions[0].get("action_id", "idle"))
        return "work_garden"

    def _best_skill_work_action(self, payload: dict[str, Any]) -> str:
        npc = payload.get("npc", {})
        state = npc.get("state", {}) if isinstance(npc, dict) else {}
        skills = state.get("skills", {}) if isinstance(state, dict) else {}
        if not isinstance(skills, dict):
            return ""
        best_skill = ""
        best_value = -1
        for skill_name, action_id in self.SKILL_TO_WORK_ACTION.items():
            value = int(skills.get(skill_name, 0) or 0)
            if value > best_value:
                best_skill = skill_name
                best_value = value
        return self.SKILL_TO_WORK_ACTION.get(best_skill, "")

    def _location_for_allowed_action(self, payload: dict[str, Any], action_id: str) -> str | None:
        actions = payload.get("allowed_actions", [])
        if isinstance(actions, list):
            for action in actions:
                if not isinstance(action, dict):
                    continue
                if str(action.get("action_id", "")) == action_id:
                    location_id = action.get("location_id")
                    return str(location_id) if location_id else None
        return None

    def _plan_item(
        self,
        hour: int,
        action_kind: str,
        action_id: str,
        location_id: str | None,
        reason: str,
    ) -> dict[str, Any]:
        return {
            "hour": hour,
            "action_kind": action_kind,
            "action_id": action_id,
            "location_id": location_id,
            "target_id": None,
            "priority": 50,
            "reason": reason,
        }
