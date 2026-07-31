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
        NPCNPCDialogueResponse,
        NPCDialogueRequest,
        PlayerNPCDialogueResponse,
        PlanRevisionJudgementRequest,
        PlanRevisionJudgementResponse,
        PlanRevisionRequest,
        PlanRevisionResponse,
    )
    from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
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
        NPCNPCDialogueResponse,
        NPCDialogueRequest,
        PlayerNPCDialogueResponse,
        PlanRevisionJudgementRequest,
        PlanRevisionJudgementResponse,
        PlanRevisionRequest,
        PlanRevisionResponse,
    )
    from services.model_adapter import ModelAdapter, ModelAdapterConfig


SERVICE_NAME = "war-not-mine-backend"


def create_app() -> Flask:
    load_dotenv()

    app = Flask(__name__)
    app.config["MODEL_ADAPTER"] = ModelAdapter()

    def model_adapter() -> ModelAdapter:
        return app.config["MODEL_ADAPTER"]

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
            if response_model.recruitment_result not in {"accept", "reject"}:
                details.append("recruitment request requires recruitment_result accept or reject.")
        elif response_model.recruitment_result != "none":
            details.append(
                "dialogue without a recruitment request must use recruitment_result=none."
            )

        interaction_context = dialogue_request.interaction_context
        if interaction_context in {"work", "avoid_combat"}:
            if response_model.wartime_reaction != "none":
                details.append(
                    "%s dialogue must use wartime_reaction=none." % interaction_context
                )
        elif interaction_context in {"rally", "combat"}:
            npc_state = dialogue_request.npc_state
            equipment = npc_state.get("equipment", {})
            main_weapon = equipment.get("main_weapon") if isinstance(equipment, dict) else None
            combat_eligible = bool(npc_state.get("recruited", False)) and bool(main_weapon)
            if not combat_eligible and response_model.wartime_reaction != "none":
                details.append(
                    "rally/combat dialogue without recruited status and a main weapon must use wartime_reaction=none."
                )
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
        })

    @app.get("/debug/llm_usage")
    def llm_usage():
        adapter = model_adapter()
        return jsonify({
            "ok": True,
            "model_adapter": adapter.get_runtime_config_snapshot(),
            "summary": adapter.get_usage_summary(),
            "records": adapter.get_usage_records(),
        })

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
            ("emotion", "neutral"),
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

        return jsonify(
            model_success_payload(response_model, result, dialogue_normalizations)
        )

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

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
