import io
import wave
from pathlib import Path

from flask import Flask, jsonify, request
from dotenv import load_dotenv
from pydantic import ValidationError

try:
    from backend.schemas import (
        APIErrorResponse,
        BattleJudgementRequest,
        BattleJudgementResponse,
        DailyPlanRequest,
        DailyPlanResponse,
        DailyReflectionRequest,
        DailyReflectionResponse,
        DialogueIntentRevalidationRequest,
        DialogueIntentRevalidationResponse,
        EscapeInterventionDialogueResponse,
        GameEpilogueRequest,
        GameEpilogueResponse,
        NPCNPCDialogueResponse,
        NPCDialogueRequest,
        PlayerNPCDialogueResponse,
        PlanRevisionJudgementRequest,
        PlanRevisionJudgementResponse,
        PlanRevisionRequest,
        PlanRevisionResponse,
        VoiceAnalyzeErrorResponse,
        VoiceAnalyzeRequest,
        VoiceAnalyzeResponse,
    )
    from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
    from backend.services.voice_model_adapter import (
        VoiceModelAdapter,
        load_dialogue_input_config,
    )
except ModuleNotFoundError:
    from schemas import (
        APIErrorResponse,
        BattleJudgementRequest,
        BattleJudgementResponse,
        DailyPlanRequest,
        DailyPlanResponse,
        DailyReflectionRequest,
        DailyReflectionResponse,
        DialogueIntentRevalidationRequest,
        DialogueIntentRevalidationResponse,
        EscapeInterventionDialogueResponse,
        GameEpilogueRequest,
        GameEpilogueResponse,
        NPCNPCDialogueResponse,
        NPCDialogueRequest,
        PlayerNPCDialogueResponse,
        PlanRevisionJudgementRequest,
        PlanRevisionJudgementResponse,
        PlanRevisionRequest,
        PlanRevisionResponse,
        VoiceAnalyzeErrorResponse,
        VoiceAnalyzeRequest,
        VoiceAnalyzeResponse,
    )
    from services.model_adapter import ModelAdapter, ModelAdapterConfig
    from services.voice_model_adapter import VoiceModelAdapter, load_dialogue_input_config


SERVICE_NAME = "war-not-mine-backend"

DIALOGUE_EMOTION_IDS = {
    "none", "happy", "relieved", "angry", "sad", "afraid",
    "surprised", "confused", "determined",
}
DIALOGUE_EMOTION_ALIASES = {
    "": "none", "neutral": "none", "calm": "none", "steady": "none",
    "wary": "none", "平静": "none", "谨慎": "none", "无": "none",
    "无明显情绪": "none", "开心": "happy", "高兴": "happy",
    "joyful": "happy", "pleased": "happy", "放松": "relieved",
    "释然": "relieved", "relaxed": "relieved", "愤怒": "angry",
    "生气": "angry", "hostile": "angry", "难过": "sad",
    "悲伤": "sad", "upset": "sad", "害怕": "afraid",
    "恐惧": "afraid", "fearful": "afraid", "shaken": "afraid",
    "tense": "afraid", "惊讶": "surprised", "震惊": "surprised",
    "shocked": "surprised", "困惑": "confused", "疑惑": "confused",
    "uncertain": "confused", "坚定": "determined", "坚决": "determined",
    "resolved": "determined", "resolute": "determined",
}


def normalize_dialogue_emotion(raw_value) -> str:
    clean_value = str(raw_value or "").strip().lower()
    if clean_value in DIALOGUE_EMOTION_IDS:
        return clean_value
    return DIALOGUE_EMOTION_ALIASES.get(clean_value, "none")


def create_app() -> Flask:
    # Resolve the local backend configuration independently of the shell's cwd.
    # Existing process environment variables keep precedence (override=False).
    load_dotenv(Path(__file__).resolve().parent / ".env", override=False)

    app = Flask(__name__)
    app.config["MODEL_ADAPTER"] = ModelAdapter()
    app.config["VOICE_MODEL_ADAPTER"] = VoiceModelAdapter()
    app.config["DIALOGUE_INPUT_CONFIG"] = load_dialogue_input_config()

    def model_adapter() -> ModelAdapter:
        return app.config["MODEL_ADAPTER"]

    def voice_model_adapter() -> VoiceModelAdapter:
        return app.config["VOICE_MODEL_ADAPTER"]

    def model_output_invalid_response(call_type: str, payload: dict, result, schema_name: str, exc: ValidationError):
        failure_reason = "Model output did not match %s." % schema_name
        usage = model_adapter().record_model_output_invalid(
            call_type,
            payload,
            failure_reason,
            result.usage,
            model_output=result.content,
            validation_details=exc.errors(),
        )
        return jsonify({
            "ok": False,
            "error_code": "model_output_invalid",
            "message": failure_reason,
            "fallback_used": False,
            "details": exc.errors(),
            "usage": usage,
        }), 502

    def model_output_business_invalid_response(call_type: str, payload: dict, result, failure_reason: str, details: list[str]):
        usage = model_adapter().record_model_output_invalid(
            call_type,
            payload,
            failure_reason,
            result.usage,
            model_output=result.content,
            validation_details=details,
        )
        return jsonify({
            "ok": False,
            "error_code": "model_output_invalid",
            "message": failure_reason,
            "fallback_used": False,
            "details": details,
            "usage": usage,
        }), 502

    def model_success_payload(response_model, result, normalizations: list[dict] | None = None) -> dict:
        """Attach one authoritative provenance shape to every successful LLM route."""
        response_payload = response_model.model_dump()
        response_payload["model_provider"] = result.provider
        response_payload["model_name"] = str(result.usage.get("model", ""))
        response_payload["model_fallback_used"] = bool(result.usage.get("fallback_used", False))
        response_payload["model_normalizations"] = list(normalizations or [])
        return response_payload

    def model_request_payload(request_model) -> dict:
        """Remove fields that are not choices for target-driven plan actions."""
        payload = request_model.model_dump()
        if not bool(payload.get("is_combat_strategy_request", False)):
            payload.pop("combat_strategy_context", None)
        for candidate in payload.get("allowed_actions", []):
            if (
                isinstance(candidate, dict)
                and candidate.get("action_id") == "talk_to_npc"
            ):
                candidate.pop("location_id", None)
        return payload

    def matching_allowed_candidates(item, candidates):
        item_target = (item.target_id or "").strip()
        item_location = (item.location_id or "").strip()
        return [
            candidate
            for candidate in candidates
            if candidate.action_id == item.action_id
            and (candidate.target_id or "").strip() == item_target
            and (
                item.action_id == "talk_to_npc"
                or (candidate.location_id or "").strip() == item_location
            )
        ]

    def plan_item_matches_allowed_candidate(item, candidates) -> bool:
        if item.action_id == "idle":
            return (
                not (item.target_id or "").strip()
                and not (item.location_id or "").strip()
            )
        return bool(matching_allowed_candidates(item, candidates))

    def infer_candidate_action_kind(candidate) -> str | None:
        if candidate.action_kind:
            return candidate.action_kind
        action_id = candidate.action_id
        special_kinds = {
            "idle": "idle",
            "talk_to_npc": "chat",
            "drink_wine": "drink",
            "visit_location": "visit",
            "assist_repair": "assist_repair",
            "assist_upgrade": "assist_upgrade",
            "assist_heal": "assist_heal",
            "seek_guard_officer": "seek_guard_officer",
            "escaping_station": "escape",
        }
        if action_id in special_kinds:
            return special_kinds[action_id]
        tags = set(candidate.tags)
        if tags.intersection({"work", "clinic_doctor"}):
            return "work"
        if "eat" in tags:
            return "eat"
        if "drink" in tags:
            return "drink"
        if "sleep" in tags:
            return "sleep"
        if tags.intersection({"training_instructor", "training_student"}):
            return "train"
        if "clinic_patient" in tags:
            return "assist_heal"
        if "pray" in tags:
            return "pray"
        return None

    def validate_plan_item_candidate(item, candidates, npc_id: str) -> list[str]:
        details: list[str] = []
        if not plan_item_matches_allowed_candidate(item, candidates):
            required_selector = {
                "visit_location": "location_id",
                "talk_to_npc": "target_npc_id",
                "assist_heal": "target_npc_id",
                "assist_repair": "building_id",
                "assist_upgrade": "building_id",
            }.get(item.action_id, "")
            if required_selector:
                details.append(
                    "%s requires a valid %s decision from allowed_actions; "
                    "compiled target_id='%s', location_id='%s'."
                    % (
                        item.action_id,
                        required_selector,
                        item.target_id or "",
                        item.location_id or "",
                    )
                )
            else:
                details.append(
                    "action/target/location combination is not in allowed_actions: "
                    "action_id='%s', target_id='%s', location_id='%s'."
                    % (item.action_id, item.target_id or "", item.location_id or "")
                )
        matching_candidates = (
            [] if item.action_id == "idle" else matching_allowed_candidates(item, candidates)
        )
        expected_kinds = {
            expected_kind
            for expected_kind in (
                infer_candidate_action_kind(candidate) for candidate in matching_candidates
            )
            if expected_kind
        }
        if item.action_id == "idle":
            expected_kinds = {"idle"}
        if expected_kinds and item.action_kind not in expected_kinds:
            details.append(
                "action_kind '%s' does not match action_id '%s'; expected one of %s."
                % (item.action_kind, item.action_id, sorted(expected_kinds))
            )
        if item.action_id == "talk_to_npc" and (item.target_id or "").strip() == npc_id:
            details.append("talk_to_npc target_id cannot be the acting NPC.")
        if item.action_id == "talk_to_npc" and not item.dialogue_goal.strip():
            details.append("talk_to_npc requires a non-empty dialogue_goal.")
        return details

    def validate_dialogue_business_rules(
        dialogue_request: NPCDialogueRequest,
        response_model: (
            PlayerNPCDialogueResponse
            | NPCNPCDialogueResponse
            | EscapeInterventionDialogueResponse
        ),
    ) -> list[str]:
        details: list[str] = []
        if response_model.replyer_id != dialogue_request.npc_id:
            details.append("replyer_id did not match request npc_id.")

        is_escape_dialogue = dialogue_request.dialogue_kind == "escape_intervention"
        is_escape_context = dialogue_request.interaction_context == "escape_intervention"
        if is_escape_dialogue != is_escape_context:
            details.append(
                "dialogue_kind=escape_intervention and interaction_context=escape_intervention must appear together."
            )
        if dialogue_request.current_round != dialogue_request.dialogue_state.current_round:
            details.append("dialogue current_round must match dialogue_state.current_round.")
        if dialogue_request.max_rounds != dialogue_request.dialogue_state.max_rounds:
            details.append("dialogue max_rounds must match dialogue_state.max_rounds.")

        if dialogue_request.dialogue_kind == "npc_npc":
            if not isinstance(response_model, NPCNPCDialogueResponse):
                details.append("npc_npc dialogue requires NPCNPCDialogueResponse.")
                return details
            if dialogue_request.max_rounds != 0 or dialogue_request.dialogue_state.max_rounds != 0:
                details.append("npc_npc max_rounds must be 0 because formal dialogue has no hard round limit.")
            if dialogue_request.soft_round_threshold != dialogue_request.dialogue_state.soft_round_threshold:
                details.append("dialogue soft_round_threshold must match dialogue_state.soft_round_threshold.")
            if not dialogue_request.soft_round_guidance.strip():
                details.append("npc_npc dialogue requires non-empty soft_round_guidance.")
            if dialogue_request.soft_round_guidance != dialogue_request.dialogue_state.soft_round_guidance:
                details.append("dialogue soft_round_guidance must match dialogue_state.soft_round_guidance.")
            if dialogue_request.dialogue_phase == "invitation":
                if dialogue_request.current_round != 0:
                    details.append("npc_npc invitation current_round must be 0.")
                if response_model.invitation_result not in {"accept", "reject"}:
                    details.append("npc_npc invitation requires invitation_result accept or reject.")
                if response_model.invitation_result == "accept" and response_model.should_end_dialogue:
                    details.append("accepted npc_npc invitation cannot end before formal conversation starts.")
                if response_model.invitation_result == "reject":
                    if not response_model.should_end_dialogue:
                        details.append("rejected npc_npc invitation must set should_end_dialogue=true.")
            else:
                if dialogue_request.current_round < 1:
                    details.append("npc_npc conversation current_round must be at least 1.")
                if response_model.invitation_result != "not_applicable":
                    details.append("npc_npc conversation reply must use invitation_result=not_applicable.")

            if dialogue_request.is_recruitment_request:
                details.append("npc_npc dialogue cannot be a recruitment request.")
            if dialogue_request.is_morale_encouragement_request:
                details.append("npc_npc dialogue cannot be a morale encouragement request.")
            if dialogue_request.is_combat_strategy_request:
                details.append("npc_npc dialogue cannot be a combat strategy request.")
            if dialogue_request.is_work_encouragement_request:
                details.append("npc_npc dialogue cannot be a work encouragement request.")
            if dialogue_request.escape_intervention_round is not None:
                details.append("escape_intervention_round is only valid for escape_intervention.")
            return details

        if dialogue_request.dialogue_kind == "escape_intervention":
            if not isinstance(response_model, EscapeInterventionDialogueResponse):
                details.append(
                    "escape_intervention dialogue requires EscapeInterventionDialogueResponse."
                )
                return details
            if dialogue_request.current_round < 1 or dialogue_request.dialogue_state.current_round < 1:
                details.append("non npc_npc dialogue current_round must be at least 1.")
            if dialogue_request.max_rounds < 1 or dialogue_request.dialogue_state.max_rounds < 1:
                details.append("non npc_npc dialogue max_rounds must be at least 1.")
            if dialogue_request.is_recruitment_request:
                details.append("escape_intervention cannot be a recruitment request.")
            if dialogue_request.is_morale_encouragement_request:
                details.append("escape_intervention cannot be a morale encouragement request.")
            if dialogue_request.is_combat_strategy_request:
                details.append("escape_intervention cannot be a combat strategy request.")
            if dialogue_request.is_work_encouragement_request:
                details.append("escape_intervention cannot be a work encouragement request.")
            if dialogue_request.escape_intervention_round is None:
                details.append("escape_intervention requires escape_intervention_round.")
            elif dialogue_request.escape_intervention_round != dialogue_request.current_round:
                details.append("escape_intervention_round must match current_round.")
            return details

        if not isinstance(response_model, PlayerNPCDialogueResponse):
            details.append("player_npc dialogue requires PlayerNPCDialogueResponse.")
            return details
        if dialogue_request.current_round < 1 or dialogue_request.dialogue_state.current_round < 1:
            details.append("non npc_npc dialogue current_round must be at least 1.")
        if dialogue_request.max_rounds < 1 or dialogue_request.dialogue_state.max_rounds < 1:
            details.append("non npc_npc dialogue max_rounds must be at least 1.")
        if dialogue_request.escape_intervention_round is not None:
            details.append("escape_intervention_round is only valid for escape_intervention.")
        if dialogue_request.is_recruitment_request:
            if response_model.recruitment_result not in {"accept", "reject", "none"}:
                details.append("recruitment request requires recruitment_result accept, reject or none.")
        elif response_model.recruitment_result != "none":
            details.append(
                "dialogue without a recruitment request must use recruitment_result=none."
            )

        interaction_context = dialogue_request.interaction_context
        special_request_count = sum((
            dialogue_request.is_recruitment_request,
            dialogue_request.is_morale_encouragement_request,
            dialogue_request.is_combat_strategy_request,
            dialogue_request.is_work_encouragement_request,
        ))
        if special_request_count > 1:
            details.append("recruitment, morale, combat strategy and work encouragement requests are mutually exclusive.")
        if not dialogue_request.is_morale_encouragement_request:
            if response_model.wartime_reaction != "none":
                details.append(
                    "dialogue without morale encouragement enabled must use wartime_reaction=none."
                )
        elif interaction_context not in {"rally", "combat"}:
            details.append("morale encouragement is only valid in rally/combat dialogue.")
        else:
            npc_state = dialogue_request.npc_state
            equipment = npc_state.get("equipment", {})
            main_weapon = equipment.get("main_weapon") if isinstance(equipment, dict) else None
            combat_eligible = bool(npc_state.get("recruited", False)) and bool(main_weapon)
            if not combat_eligible:
                details.append(
                    "morale encouragement requires recruited status and a main weapon."
                )
            morale_boost = npc_state.get("morale_boost", {})
            if isinstance(morale_boost, dict) and bool(morale_boost.get("active", False)):
                details.append("morale encouragement cannot be requested while its buff is active.")

        strategy_context = dialogue_request.combat_strategy_context
        strategy_decision = response_model.combat_strategy_decision
        if not dialogue_request.is_combat_strategy_request:
            if strategy_context is not None:
                details.append("combat_strategy_context requires combat strategy request enabled.")
            if strategy_decision is not None:
                details.append("dialogue without combat strategy enabled must not return a strategy decision.")
        elif interaction_context not in {"rally", "combat"}:
            details.append("combat strategy adjustment is only valid in rally/combat dialogue.")
        else:
            npc_state = dialogue_request.npc_state
            equipment = npc_state.get("equipment", {})
            main_weapon = equipment.get("main_weapon") if isinstance(equipment, dict) else None
            if not bool(npc_state.get("recruited", False)) or not bool(main_weapon):
                details.append("combat strategy adjustment requires recruited status and a main weapon.")
            if strategy_context is None:
                details.append("combat strategy request requires combat_strategy_context.")
            elif strategy_decision is None:
                details.append("combat strategy request requires combat_strategy_decision.")
            else:
                current_id = strategy_context.current_strategy.id
                available_ids = {option.id for option in strategy_context.available_strategies}
                if strategy_decision.strategy_id not in available_ids:
                    details.append("combat strategy decision must select an available strategy id.")
                if strategy_decision.decision == "keep" and strategy_decision.strategy_id != current_id:
                    details.append("keep decision must return the current strategy id.")
                if strategy_decision.decision == "change" and strategy_decision.strategy_id == current_id:
                    details.append("change decision must select a different strategy id.")

        work_reaction = response_model.work_encouragement_reaction
        if not dialogue_request.is_work_encouragement_request:
            if work_reaction != "none":
                details.append(
                    "dialogue without work encouragement enabled must use work_encouragement_reaction=none."
                )
        elif interaction_context != "work":
            details.append("work encouragement is only valid in work dialogue.")
        else:
            npc_state = dialogue_request.npc_state
            if str(npc_state.get("behavior_mode", "work")) != "work":
                details.append("work encouragement requires the NPC to be in work behavior mode.")
            if bool(npc_state.get("unconscious", False)):
                details.append("work encouragement cannot target an unconscious NPC.")
            if bool(npc_state.get("escaped", False)):
                details.append("work encouragement cannot target an escaped NPC.")
            escape_state = npc_state.get("escape_state", {})
            if isinstance(escape_state, dict) and bool(escape_state.get("active", False)):
                details.append("work encouragement cannot target an escaping NPC.")
            work_boost = npc_state.get("work_encouragement_boost", {})
            if isinstance(work_boost, dict) and bool(work_boost.get("active", False)):
                details.append("work encouragement cannot be requested while its buff is active.")
        return details

    def validate_daily_plan_business_rules(plan_request: DailyPlanRequest, response_model: DailyPlanResponse) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != plan_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")

        hours = [item.hour for item in response_model.plan]
        if sorted(hours) != list(range(24)):
            details.append("plan must contain each hour from 0 to 23 exactly once.")

        for item in response_model.plan:
            details.extend(validate_plan_item_candidate(
                item,
                plan_request.allowed_actions,
                plan_request.npc.identity.npc_id,
            ))

        drink_phase_count = sum(1 for item in response_model.plan if item.action_id == "drink_wine")
        if drink_phase_count > plan_request.npc.state.wine:
            details.append(
                "drink_wine phases cannot exceed NPC-owned wine; got %d phases with %d wine."
                % (drink_phase_count, plan_request.npc.state.wine)
            )
        return details

    def validate_dialogue_intent_revalidation_business_rules(
        intent_request: DialogueIntentRevalidationRequest,
        response_model: DialogueIntentRevalidationResponse,
    ) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != intent_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")
        dialogue_goal = response_model.dialogue_goal.strip()
        original_goal = intent_request.planned_intent.plan_item.dialogue_goal.strip()
        if response_model.decision == "modify":
            if not dialogue_goal:
                details.append("modify decision requires non-empty dialogue_goal.")
            elif dialogue_goal == original_goal:
                details.append("modify decision dialogue_goal must differ from the original.")
            elif len(dialogue_goal) > 120:
                details.append("modify decision dialogue_goal must not exceed 120 characters.")
        elif dialogue_goal:
            details.append(
                "continue and cancel_and_replan decisions require empty dialogue_goal."
            )
        return details

    def validate_plan_revision_judgement_business_rules(
        judgement_request: PlanRevisionJudgementRequest,
        response_model: PlanRevisionJudgementResponse,
    ) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != judgement_request.npc_id:
            details.append("npc_id did not match request npc identity.")
        revision_hours = response_model.revision_hours
        if revision_hours != sorted(set(revision_hours)):
            details.append("revision_hours must be unique and sorted ascending.")
        if any(hour < judgement_request.game_time.hour for hour in revision_hours):
            details.append("revision_hours cannot contain hours before game_time.hour.")
        missing_required_hours = sorted(
            set(judgement_request.required_revision_hours) - set(revision_hours)
        )
        if missing_required_hours:
            details.append(
                "revision_hours must include every required_revision_hours value; missing %s."
                % missing_required_hours
            )
        if response_model.needs_revision != bool(revision_hours):
            details.append(
                "needs_revision must be true exactly when revision_hours is non-empty."
            )
        return details

    def validate_plan_revision_business_rules(
        revision_request: PlanRevisionRequest,
        response_model: PlanRevisionResponse,
    ) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != revision_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")
        revised_hours = [item.hour for item in response_model.revised_plan]
        if revised_hours != revision_request.revision_hours:
            details.append(
                "selected_hours revised_plan hours must exactly match revision_hours in ascending order."
            )
        for item in response_model.revised_plan:
            details.extend(validate_plan_item_candidate(
                item,
                revision_request.allowed_actions,
                revision_request.npc.identity.npc_id,
            ))
        current_hour_selected = revision_request.game_time.hour in revision_request.revision_hours
        if current_hour_selected and response_model.immediate_action is None:
            details.append("immediate_action must not be null when revision_hours contains game_time.hour.")
        elif not current_hour_selected and response_model.immediate_action is not None:
            details.append("immediate_action must be null when revision_hours excludes game_time.hour.")
        elif response_model.immediate_action is not None:
            if response_model.immediate_action.hour != revision_request.game_time.hour:
                details.append("immediate_action hour must match game_time.hour.")
            details.extend(validate_plan_item_candidate(
                response_model.immediate_action,
                revision_request.allowed_actions,
                revision_request.npc.identity.npc_id,
            ))
            current_hour_item = next(
                (item for item in response_model.revised_plan if item.hour == revision_request.game_time.hour),
                None,
            )
            if current_hour_item is None or current_hour_item.model_dump() != response_model.immediate_action.model_dump():
                details.append(
                    "selected_hours immediate_action must exactly match the revised_plan item at game_time.hour."
                )
        merged_by_hour = {item.hour: item for item in revision_request.current_plan}
        for item in response_model.revised_plan:
            merged_by_hour[item.hour] = item
        remaining_drink_phases = sum(
            1
            for hour, item in merged_by_hour.items()
            if hour >= revision_request.game_time.hour and item.action_id == "drink_wine"
        )
        if remaining_drink_phases > revision_request.npc.state.wine:
            details.append(
                "remaining drink_wine phases cannot exceed NPC-owned wine; got %d phases with %d wine."
                % (remaining_drink_phases, revision_request.npc.state.wine)
            )
        return details

    def validate_battle_judgement_business_rules(judgement_request: BattleJudgementRequest, response_model: BattleJudgementResponse) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != judgement_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")
        if response_model.decision not in judgement_request.allowed_decisions:
            details.append("decision '%s' is not in allowed_decisions." % response_model.decision)
        expected_escape = response_model.decision == "escape_station"
        if response_model.should_start_escape != expected_escape:
            details.append("should_start_escape must be true only when decision is escape_station.")
        return details

    def validate_daily_reflection_business_rules(reflection_request: DailyReflectionRequest, response_model: DailyReflectionResponse) -> list[str]:
        def contains_chinese(text: str) -> bool:
            return any("\u3400" <= character <= "\u9fff" for character in text)

        details: list[str] = []
        if response_model.npc_id != reflection_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")
        if response_model.day != reflection_request.game_time.day:
            details.append("day did not match request game_time.day.")
        if not response_model.diary_entry.strip():
            details.append("diary_entry must not be empty.")
        world_text_values = [response_model.diary_entry, response_model.debug_reason]
        for update in response_model.knowledge_graph_updates:
            if not update.subject.strip():
                details.append("knowledge_graph update subject must not be empty.")
            if not update.relation.strip():
                details.append("knowledge_graph update relation must not be empty.")
            if not update.value.strip():
                details.append("knowledge_graph update value must not be empty.")
            for field_name, field_value in (
                ("subject_label", update.subject_label),
                ("relation_label", update.relation_label),
                ("value_label", update.value_label),
            ):
                if not field_value.strip() or not contains_chinese(field_value):
                    details.append(
                        "knowledge_graph update %s must be a non-empty Chinese player-facing label."
                        % field_name
                    )
            world_text_values.extend([
                update.subject,
                update.relation,
                update.value,
                update.subject_label,
                update.relation_label,
                update.value_label,
            ])
        if any("玩家" in value for value in world_text_values):
            details.append("world-facing reflection output must use 守备官 instead of 玩家.")
        return details

    def validate_game_epilogue_business_rules(
        epilogue_request: GameEpilogueRequest,
        response_model: GameEpilogueResponse,
    ) -> list[str]:
        details: list[str] = []
        if response_model.result != epilogue_request.result:
            details.append("result must match the authoritative settlement result.")
        expected_by_id = {npc.npc_id: npc for npc in epilogue_request.npcs}
        ending_ids = [ending.npc_id for ending in response_model.npc_endings]
        if len(ending_ids) != len(set(ending_ids)):
            details.append("npc_endings contains duplicate npc_id values.")
        if set(ending_ids) != set(expected_by_id):
            details.append("npc_endings must exactly cover the requested npc ids.")
        global_fact_ids = {fact.fact_id for fact in epilogue_request.global_facts}
        victory_tones = {"hopeful", "hopeful_bittersweet", "reconciled"}
        failure_tones = {"sorrowful", "sorrowful_resilient", "unresolved"}
        forbidden_death_terms = ("阵亡", "死亡", "死去", "身亡", "尸体", "墓碑")
        forbidden_meta_terms = ("玩家", "根据资料", "根据提供", "NPC id", "fact_id")
        forbidden_modern_terms = (
            "手机", "互联网", "公司", "工厂", "火车", "汽车", "电报", "记者", "媒体", "大学",
        )
        opening_keys: dict[str, list[str]] = {}
        closing_keys: dict[str, list[str]] = {}
        for ending in response_model.npc_endings:
            expected = expected_by_id.get(ending.npc_id)
            if expected is None:
                continue
            if ending.opening_status != expected.opening_status:
                details.append(f"{ending.npc_id}: opening_status changed authoritative state.")
            allowed_fact_ids = global_fact_ids | {fact.fact_id for fact in expected.key_facts}
            invalid_refs = [fact_id for fact_id in ending.fact_refs if fact_id not in allowed_fact_ids]
            if invalid_refs:
                details.append(f"{ending.npc_id}: fact_refs contains unavailable facts {invalid_refs}.")
            expected_tones = victory_tones if epilogue_request.result == "victory" else failure_tones
            if ending.tone not in expected_tones:
                details.append(f"{ending.npc_id}: tone is incompatible with settlement result.")
            combined_text = " ".join((ending.ending_title, ending.final_opinion, ending.fate_story))
            for term in forbidden_death_terms:
                if term in combined_text:
                    details.append(f"{ending.npc_id}: forbidden NPC death wording '{term}'.")
            for term in forbidden_meta_terms:
                if term in combined_text:
                    details.append(f"{ending.npc_id}: forbidden meta wording '{term}'.")
            for term in forbidden_modern_terms:
                if term in combined_text:
                    details.append(f"{ending.npc_id}: setting-incompatible modern wording '{term}'.")
            compact_story = "".join(ending.fate_story.split())
            opening_keys.setdefault(compact_story[:18], []).append(ending.npc_id)
            closing_keys.setdefault(compact_story[-18:], []).append(ending.npc_id)
        for fragment, npc_ids in opening_keys.items():
            if fragment and len(npc_ids) > 1:
                details.append(f"repeated epilogue opening across npc ids {npc_ids}.")
        for fragment, npc_ids in closing_keys.items():
            if fragment and len(npc_ids) > 1:
                details.append(f"repeated epilogue closing across npc ids {npc_ids}.")
        all_text = " ".join(
            [response_model.ending_title, response_model.station_coda]
            + [ending.fate_story for ending in response_model.npc_endings]
        )
        for term in forbidden_death_terms:
            if term in all_text:
                details.append(f"epilogue contains forbidden initial-NPC death wording '{term}'.")
        return list(dict.fromkeys(details))

    def model_adapter_error_status(error_code: str) -> int:
        if error_code == "budget_exceeded":
            return 429
        return 503

    @app.get("/health")
    def health():
        return jsonify({
            "ok": True,
            "service": SERVICE_NAME,
            "model_adapter": model_adapter().get_runtime_config_snapshot(),
            "voice_model_adapter": voice_model_adapter().get_runtime_config_snapshot(),
            "dialogue_input": app.config["DIALOGUE_INPUT_CONFIG"].model_dump(),
        })

    @app.get("/debug/llm_usage")
    def llm_usage():
        adapter = model_adapter()
        voice_adapter = voice_model_adapter()
        return jsonify({
            "ok": True,
            "model_adapter": adapter.get_runtime_config_snapshot(),
            "summary": adapter.get_usage_summary(),
            "records": adapter.get_usage_records(),
            "voice": {
                "model_adapter": voice_adapter.get_runtime_config_snapshot(),
                "summary": voice_adapter.get_usage_summary(),
                "records": voice_adapter.get_usage_records(),
            },
        })

    @app.post("/voice/analyze")
    def voice_analyze():
        voice_adapter = voice_model_adapter()
        raw_meta = {
            "request_id": request.form.get("request_id", ""),
            "npc_id": request.form.get("npc_id", ""),
            "dialogue_id": request.form.get("dialogue_id", ""),
            "locale": request.form.get("locale", "zh"),
        }
        try:
            voice_request = VoiceAnalyzeRequest.model_validate(raw_meta)
        except ValidationError as exc:
            request_id = str(raw_meta.get("request_id", ""))
            usage = voice_adapter.record_validation_failure(
                request_id=request_id,
                npc_id=str(raw_meta.get("npc_id", "")),
                dialogue_id=str(raw_meta.get("dialogue_id", "")),
                error_code="validation_error",
                failure_reason="VoiceAnalyzeRequest validation failed.",
            )
            return jsonify(VoiceAnalyzeErrorResponse(
                request_id=request_id,
                error_code="validation_error",
                message="VoiceAnalyzeRequest validation failed.",
                details=exc.errors(include_context=False),
                usage=usage,
            ).model_dump()), 400

        def voice_error(error_code: str, message: str, status: int, duration: float = 0.0):
            usage = voice_adapter.record_validation_failure(
                request_id=voice_request.request_id,
                npc_id=voice_request.npc_id,
                dialogue_id=voice_request.dialogue_id,
                error_code=error_code,
                failure_reason=message,
                duration_seconds=duration,
            )
            return jsonify(VoiceAnalyzeErrorResponse(
                request_id=voice_request.request_id,
                error_code=error_code,
                message=message,
                usage=usage,
            ).model_dump()), status

        upload = request.files.get("audio")
        if upload is None:
            return voice_error("recording_empty", "No audio recording was uploaded.", 400)

        limits = app.config["DIALOGUE_INPUT_CONFIG"]
        audio_bytes = upload.stream.read(limits.voice_upload_max_bytes + 1)
        if not audio_bytes:
            return voice_error("recording_empty", "The uploaded recording is empty.", 400)
        if len(audio_bytes) > limits.voice_upload_max_bytes:
            return voice_error(
                "audio_too_large",
                "The uploaded recording exceeds the configured byte limit.",
                413,
            )

        try:
            with wave.open(io.BytesIO(audio_bytes), "rb") as wav_file:
                frame_rate = wav_file.getframerate()
                frame_count = wav_file.getnframes()
                if wav_file.getcomptype() != "NONE" or frame_rate <= 0:
                    raise wave.Error("Only uncompressed PCM WAV is supported.")
                duration_seconds = frame_count / float(frame_rate)
        except (EOFError, wave.Error):
            return voice_error("audio_invalid", "The uploaded WAV is invalid or unsupported.", 400)

        if duration_seconds <= 0.0:
            return voice_error("recording_empty", "The uploaded recording has no frames.", 400)
        if duration_seconds > limits.voice_recording_max_seconds:
            return voice_error(
                "audio_too_long",
                "The uploaded recording exceeds the 30-second limit.",
                413,
                duration_seconds,
            )

        result = voice_adapter.analyze(
            request_id=voice_request.request_id,
            npc_id=voice_request.npc_id,
            dialogue_id=voice_request.dialogue_id,
            duration_seconds=duration_seconds,
            audio_bytes=audio_bytes,
            locale=voice_request.locale,
        )
        if not result.ok:
            voice_error_statuses = {
                "voice_budget_exceeded": 429,
                "voice_provider_rate_limited": 429,
                "voice_provider_timeout": 504,
                "voice_provider_auth_failed": 502,
                "voice_provider_transport_error": 502,
                "voice_provider_http_error": 502,
                "voice_provider_invalid_response": 502,
                "voice_provider_unavailable": 503,
            }
            return jsonify(VoiceAnalyzeErrorResponse(
                request_id=voice_request.request_id,
                error_code=result.error_code,
                message=result.message,
                usage=result.usage,
            ).model_dump()), voice_error_statuses.get(result.error_code, 503)

        return jsonify(VoiceAnalyzeResponse(
            request_id=voice_request.request_id,
            dialogue_id=voice_request.dialogue_id,
            transcript=result.transcript,
            emotion=result.emotion,
            emotion_label=result.emotion_label,
            emotion_applied=result.emotion_applied,
            duration_seconds=round(duration_seconds, 3),
            model_provider=result.provider,
            model_name=result.model,
            usage=result.usage,
        ).model_dump())

    @app.post("/mock/model")
    def mock_model():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify({
                "ok": False,
                "error_code": "invalid_json",
                "message": "Request body must be a JSON object.",
                "fallback_used": False,
            }), 400

        call_type = str(body.get("call_type", "generic"))
        payload = body.get("payload", {})
        if not isinstance(payload, dict):
            return jsonify({
                "ok": False,
                "error_code": "invalid_payload",
                "message": "payload must be a JSON object.",
                "fallback_used": False,
            }), 400

        runtime_config = model_adapter().config
        result = ModelAdapter(ModelAdapterConfig(
            provider="mock",
            api_key=None,
            audit_log_enabled=runtime_config.audit_log_enabled,
            audit_log_path=runtime_config.audit_log_path,
            audit_log_include_payloads=runtime_config.audit_log_include_payloads,
        )).generate(call_type, payload)
        response = {
            "ok": result.ok,
            "provider": result.provider,
            "call_type": result.call_type,
            "content": result.content,
            "usage": result.usage,
        }
        if not result.ok:
            response["error_code"] = result.error_code
            response["message"] = result.message
            return jsonify(response), model_adapter_error_status(result.error_code)
        return jsonify(response)

    @app.post("/npc/dialogue")
    def npc_dialogue():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            dialogue_request = NPCDialogueRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "NPCDialogueRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(include_context=False),
            }), 400

        dialogue_payload = model_request_payload(dialogue_request)
        result = model_adapter().generate("dialogue", dialogue_payload)
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        response_model_type = {
            "player_npc": PlayerNPCDialogueResponse,
            "npc_npc": NPCNPCDialogueResponse,
            "escape_intervention": EscapeInterventionDialogueResponse,
        }[dialogue_request.dialogue_kind]
        response_model_name = response_model_type.__name__
        dialogue_output = dict(result.content)
        dialogue_normalizations: list[dict] = []
        for field_name, default_value in (
            ("emotion", "none"),
            ("suggested_event_type", "dialogue_turn"),
            ("debug_reason", ""),
        ):
            if field_name in dialogue_output and dialogue_output[field_name] is None:
                dialogue_output[field_name] = default_value
                dialogue_normalizations.append({
                    "path": field_name,
                    "from": None,
                    "to": default_value,
                    "source": "nullable_non_authoritative_metadata_default",
                })
        raw_emotion = dialogue_output.get("emotion", "none")
        normalized_emotion = normalize_dialogue_emotion(raw_emotion)
        if raw_emotion != normalized_emotion:
            dialogue_output["emotion"] = normalized_emotion
            dialogue_normalizations.append({
                "path": "emotion",
                "from": raw_emotion,
                "to": normalized_emotion,
                "source": "dialogue_emotion_alias_or_unknown_default",
            })
        try:
            response_model = response_model_type.model_validate(dialogue_output)
        except ValidationError as exc:
            return model_output_invalid_response(
                "dialogue",
                dialogue_payload,
                result,
                response_model_name,
                exc,
            )

        business_errors = validate_dialogue_business_rules(dialogue_request, response_model)
        if business_errors:
            return model_output_business_invalid_response(
                "dialogue",
                dialogue_payload,
                result,
                "%s failed business validation." % response_model_name,
                business_errors,
            )

        response_payload = model_success_payload(response_model, result, dialogue_normalizations)
        if not dialogue_request.is_combat_strategy_request:
            response_payload.pop("combat_strategy_decision", None)
        if not dialogue_request.is_work_encouragement_request:
            response_payload.pop("work_encouragement_reaction", None)
        return jsonify(response_payload)

    @app.post("/npc/dialogue_plan_revision_judgement")
    @app.post("/npc/plan_revision_judgement")
    def npc_plan_revision_judgement():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            judgement_request = PlanRevisionJudgementRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "PlanRevisionJudgementRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(include_context=False),
            }), 400

        request_payload = model_request_payload(judgement_request)
        result = model_adapter().generate(
            "plan_revision_judgement",
            request_payload,
        )
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = PlanRevisionJudgementResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response(
                "plan_revision_judgement",
                request_payload,
                result,
                "PlanRevisionJudgementResponse",
                exc,
            )

        normalizations: list[dict] = []
        missing_required_hours = sorted(
            set(judgement_request.required_revision_hours)
            - set(response_model.revision_hours)
        )
        if missing_required_hours:
            original_revision_hours = list(response_model.revision_hours)
            normalized_revision_hours = sorted({
                *original_revision_hours,
                *judgement_request.required_revision_hours,
            })
            response_model = response_model.model_copy(update={
                "needs_revision": True,
                "revision_hours": normalized_revision_hours,
            })
            normalizations.append({
                "field": "revision_hours",
                "reason": "required_revision_hours_authoritative_union",
                "from": original_revision_hours,
                "to": normalized_revision_hours,
            })

        business_errors = validate_plan_revision_judgement_business_rules(
            judgement_request,
            response_model,
        )
        if business_errors:
            return model_output_business_invalid_response(
                "plan_revision_judgement",
                request_payload,
                result,
                "PlanRevisionJudgementResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result, normalizations))

    @app.post("/npc/dialogue_intent_revalidation")
    def npc_dialogue_intent_revalidation():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            intent_request = DialogueIntentRevalidationRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "DialogueIntentRevalidationRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(include_context=False),
            }), 400

        request_payload = model_request_payload(intent_request)
        result = model_adapter().generate(
            "dialogue_intent_revalidation",
            request_payload,
        )
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = DialogueIntentRevalidationResponse.model_validate(
                result.content
            )
        except ValidationError as exc:
            return model_output_invalid_response(
                "dialogue_intent_revalidation",
                request_payload,
                result,
                "DialogueIntentRevalidationResponse",
                exc,
            )

        business_errors = validate_dialogue_intent_revalidation_business_rules(
            intent_request,
            response_model,
        )
        if business_errors:
            model_adapter().record_model_output_invalid(
                "dialogue_intent_revalidation",
                request_payload,
                "DialogueIntentRevalidationResponse failed business validation before correction retry: %s"
                % "; ".join(business_errors),
                result.usage,
                model_output=result.content,
                validation_details=business_errors,
            )
            retry_payload = model_request_payload(intent_request)
            retry_payload["business_validation_feedback"] = business_errors
            retry_meta = retry_payload.get("meta", {})
            retry_meta["request_id"] = "%s_business_retry" % retry_meta.get(
                "request_id",
                "dialogue_intent_revalidation",
            )
            retry_payload["meta"] = retry_meta
            retry_result = model_adapter().generate(
                "dialogue_intent_revalidation",
                retry_payload,
            )
            if not retry_result.ok:
                return jsonify({
                    "ok": False,
                    "error_code": retry_result.error_code,
                    "message": retry_result.message,
                    "fallback_used": False,
                    "usage": retry_result.usage,
                }), model_adapter_error_status(retry_result.error_code)
            try:
                retry_response_model = (
                    DialogueIntentRevalidationResponse.model_validate(
                        retry_result.content
                    )
                )
            except ValidationError as exc:
                return model_output_invalid_response(
                    "dialogue_intent_revalidation",
                    retry_payload,
                    retry_result,
                    "DialogueIntentRevalidationResponse",
                    exc,
                )
            retry_business_errors = (
                validate_dialogue_intent_revalidation_business_rules(
                    intent_request,
                    retry_response_model,
                )
            )
            result = retry_result
            response_model = retry_response_model
            business_errors = retry_business_errors
        if business_errors:
            return model_output_business_invalid_response(
                "dialogue_intent_revalidation",
                request_payload,
                result,
                "DialogueIntentRevalidationResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result))

    @app.post("/npc/plan_day")
    def npc_plan_day():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            plan_request = DailyPlanRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "DailyPlanRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(),
            }), 400

        request_payload = model_request_payload(plan_request)
        result = model_adapter().generate("plan_day", request_payload)
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = DailyPlanResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response("plan_day", request_payload, result, "DailyPlanResponse", exc)

        business_errors = validate_daily_plan_business_rules(plan_request, response_model)
        if business_errors:
            return model_output_business_invalid_response(
                "plan_day",
                request_payload,
                result,
                "DailyPlanResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result))

    @app.post("/npc/revise_plan")
    def npc_revise_plan():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            revision_request = PlanRevisionRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "PlanRevisionRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(include_context=False),
            }), 400

        request_payload = model_request_payload(revision_request)
        result = model_adapter().generate("revise_plan", request_payload)
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        def parse_revision_response(adapter_result):
            try:
                parsed_response = PlanRevisionResponse.model_validate(adapter_result.content)
            except ValidationError as exc:
                return None, [], exc
            return parsed_response, [], None

        response_model, normalizations, parse_error = parse_revision_response(result)
        if parse_error is not None:
            return model_output_invalid_response("revise_plan", request_payload, result, "PlanRevisionResponse", parse_error)

        business_errors = validate_plan_revision_business_rules(revision_request, response_model)
        if business_errors:
            model_adapter().record_model_output_invalid(
                "revise_plan",
                request_payload,
                "PlanRevisionResponse failed business validation before real-model correction retry: %s"
                % "; ".join(business_errors),
                result.usage,
                model_output=result.content,
                validation_details=business_errors,
            )
            retry_payload = model_request_payload(revision_request)
            retry_payload["business_validation_feedback"] = business_errors
            retry_meta = retry_payload.get("meta", {})
            retry_meta["request_id"] = "%s_business_retry" % retry_meta.get("request_id", "revise_plan")
            retry_payload["meta"] = retry_meta
            retry_result = model_adapter().generate("revise_plan", retry_payload)
            if not retry_result.ok:
                return jsonify({
                    "ok": False,
                    "error_code": retry_result.error_code,
                    "message": retry_result.message,
                    "fallback_used": False,
                    "usage": retry_result.usage,
                }), model_adapter_error_status(retry_result.error_code)
            retry_response_model, retry_normalizations, retry_parse_error = parse_revision_response(retry_result)
            if retry_parse_error is not None:
                return model_output_invalid_response(
                    "revise_plan",
                    retry_payload,
                    retry_result,
                    "PlanRevisionResponse",
                    retry_parse_error,
                )
            retry_business_errors = validate_plan_revision_business_rules(
                revision_request,
                retry_response_model,
            )
            result = retry_result
            response_model = retry_response_model
            normalizations = retry_normalizations
            business_errors = retry_business_errors
        if business_errors:
            return model_output_business_invalid_response(
                "revise_plan",
                request_payload,
                result,
                "PlanRevisionResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result, normalizations))

    @app.post("/npc/battle_judgement")
    def npc_battle_judgement():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            judgement_request = BattleJudgementRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "BattleJudgementRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(),
            }), 400

        result = model_adapter().generate("battle_judgement", judgement_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = BattleJudgementResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response("battle_judgement", judgement_request.model_dump(), result, "BattleJudgementResponse", exc)

        business_errors = validate_battle_judgement_business_rules(judgement_request, response_model)
        if business_errors:
            return model_output_business_invalid_response(
                "battle_judgement",
                judgement_request.model_dump(),
                result,
                "BattleJudgementResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result))

    @app.post("/npc/daily_reflection")
    def npc_daily_reflection():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            reflection_request = DailyReflectionRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "DailyReflectionRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(),
            }), 400

        result = model_adapter().generate("daily_reflection", reflection_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = DailyReflectionResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response("daily_reflection", reflection_request.model_dump(), result, "DailyReflectionResponse", exc)

        business_errors = validate_daily_reflection_business_rules(reflection_request, response_model)
        if business_errors:
            return model_output_business_invalid_response(
                "daily_reflection",
                reflection_request.model_dump(),
                result,
                "DailyReflectionResponse failed business validation.",
                business_errors,
            )

        return jsonify(model_success_payload(response_model, result))

    @app.post("/game/epilogue")
    def game_epilogue():
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(APIErrorResponse(
                error_code="invalid_json",
                message="Request body must be a JSON object.",
            ).model_dump()), 400

        try:
            epilogue_request = GameEpilogueRequest.model_validate(body)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "validation_error",
                "message": "GameEpilogueRequest validation failed.",
                "fallback_used": False,
                "details": exc.errors(),
            }), 400

        request_payload = epilogue_request.model_dump()
        result = model_adapter().generate("game_epilogue", request_payload)
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        validation_details: list = []
        response_model = None
        try:
            response_model = GameEpilogueResponse.model_validate(result.content)
        except ValidationError as exc:
            validation_details = exc.errors()
        if response_model is not None:
            validation_details = validate_game_epilogue_business_rules(epilogue_request, response_model)

        correction_used = False
        if validation_details and result.provider != "mock":
            model_adapter().record_model_output_invalid(
                "game_epilogue",
                request_payload,
                "Initial GameEpilogueResponse failed validation; one correction requested.",
                result.usage,
                model_output=result.content,
                validation_details=validation_details,
            )
            correction_payload = dict(request_payload)
            correction_payload["correction_context"] = {
                "instruction": "Correct the response without changing any authoritative input fact.",
                "validation_errors": validation_details,
                "previous_output": result.content,
            }
            result = model_adapter().generate("game_epilogue", correction_payload)
            correction_used = True
            if not result.ok:
                return jsonify({
                    "ok": False,
                    "error_code": result.error_code,
                    "message": result.message,
                    "fallback_used": False,
                    "usage": result.usage,
                }), model_adapter_error_status(result.error_code)
            try:
                response_model = GameEpilogueResponse.model_validate(result.content)
                validation_details = validate_game_epilogue_business_rules(epilogue_request, response_model)
            except ValidationError as exc:
                response_model = None
                validation_details = exc.errors()

        if response_model is None or validation_details:
            return model_output_business_invalid_response(
                "game_epilogue",
                request_payload,
                result,
                "GameEpilogueResponse failed schema or continuity validation.",
                validation_details,
            )
        return jsonify(model_success_payload(
            response_model,
            result,
            [{"kind": "epilogue_correction", "applied": True}] if correction_used else [],
        ))

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
