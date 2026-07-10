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
        NPCDialogueRequest,
        NPCDialogueResponse,
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
        NPCDialogueRequest,
        NPCDialogueResponse,
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
        )
        return jsonify({
            "ok": False,
            "error_code": "model_output_invalid",
            "message": failure_reason,
            "fallback_used": False,
            "details": details,
            "usage": usage,
        }), 502

    def validate_daily_plan_business_rules(plan_request: DailyPlanRequest, response_model: DailyPlanResponse) -> list[str]:
        details: list[str] = []
        if response_model.npc_id != plan_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")

        hours = [item.hour for item in response_model.plan]
        if sorted(hours) != list(range(24)):
            details.append("plan must contain each hour from 0 to 23 exactly once.")

        allowed_action_ids = {action.action_id for action in plan_request.allowed_actions}
        allowed_action_ids.add("idle")
        for item in response_model.plan:
            if item.action_id not in allowed_action_ids:
                details.append("action_id '%s' is not in allowed_actions." % item.action_id)

        work_action_ids = {
            action.action_id
            for action in plan_request.allowed_actions
            if any(tag in {"work", "clinic_doctor", "training_instructor"} for tag in action.tags)
        }
        work_phase_count = sum(1 for item in response_model.plan if item.action_id in work_action_ids)
        if work_phase_count < 6:
            details.append("plan must include at least 6 work phases; got %d." % work_phase_count)
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
        details: list[str] = []
        if response_model.npc_id != reflection_request.npc.identity.npc_id:
            details.append("npc_id did not match request npc identity.")
        if response_model.day != reflection_request.game_time.day:
            details.append("day did not match request game_time.day.")
        if not response_model.diary_entry.strip():
            details.append("diary_entry must not be empty.")
        if not response_model.memory_summary.strip():
            details.append("memory_summary must not be empty.")
        world_text_values = [response_model.diary_entry, response_model.memory_summary, response_model.debug_reason]
        for update in response_model.knowledge_graph_updates:
            if not update.subject.strip():
                details.append("knowledge_graph update subject must not be empty.")
            if not update.relation.strip():
                details.append("knowledge_graph update relation must not be empty.")
            if not update.value.strip():
                details.append("knowledge_graph update value must not be empty.")
            world_text_values.extend([update.subject, update.relation, update.value])
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

        result = ModelAdapter(ModelAdapterConfig(provider="mock", api_key=None)).generate(call_type, payload)
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
                "details": exc.errors(),
            }), 400

        result = model_adapter().generate("dialogue", dialogue_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = NPCDialogueResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response("dialogue", dialogue_request.model_dump(), result, "NPCDialogueResponse", exc)

        return jsonify(response_model.model_dump())

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

        result = model_adapter().generate("plan_day", plan_request.model_dump())
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
            return model_output_invalid_response("plan_day", plan_request.model_dump(), result, "DailyPlanResponse", exc)

        business_errors = validate_daily_plan_business_rules(plan_request, response_model)
        if business_errors:
            return model_output_business_invalid_response(
                "plan_day",
                plan_request.model_dump(),
                result,
                "DailyPlanResponse failed business validation.",
                business_errors,
            )

        return jsonify(response_model.model_dump())

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
                "details": exc.errors(),
            }), 400

        result = model_adapter().generate("revise_plan", revision_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), model_adapter_error_status(result.error_code)

        try:
            response_model = PlanRevisionResponse.model_validate(result.content)
        except ValidationError as exc:
            return model_output_invalid_response("revise_plan", revision_request.model_dump(), result, "PlanRevisionResponse", exc)

        return jsonify(response_model.model_dump())

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

        return jsonify(response_model.model_dump())

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

        return jsonify(response_model.model_dump())

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
