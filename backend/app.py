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

    @app.get("/health")
    def health():
        return jsonify({"ok": True, "service": SERVICE_NAME})

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
            return jsonify(response), 503
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

        result = ModelAdapter().generate("dialogue", dialogue_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), 503

        try:
            response_model = NPCDialogueResponse.model_validate(result.content)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "model_output_invalid",
                "message": "Model output did not match NPCDialogueResponse.",
                "fallback_used": False,
                "details": exc.errors(),
                "usage": result.usage,
            }), 502

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

        result = ModelAdapter().generate("plan_day", plan_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), 503

        try:
            response_model = DailyPlanResponse.model_validate(result.content)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "model_output_invalid",
                "message": "Model output did not match DailyPlanResponse.",
                "fallback_used": False,
                "details": exc.errors(),
                "usage": result.usage,
            }), 502

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

        result = ModelAdapter().generate("revise_plan", revision_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), 503

        try:
            response_model = PlanRevisionResponse.model_validate(result.content)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "model_output_invalid",
                "message": "Model output did not match PlanRevisionResponse.",
                "fallback_used": False,
                "details": exc.errors(),
                "usage": result.usage,
            }), 502

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

        result = ModelAdapter().generate("battle_judgement", judgement_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), 503

        try:
            response_model = BattleJudgementResponse.model_validate(result.content)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "model_output_invalid",
                "message": "Model output did not match BattleJudgementResponse.",
                "fallback_used": False,
                "details": exc.errors(),
                "usage": result.usage,
            }), 502

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

        result = ModelAdapter().generate("daily_reflection", reflection_request.model_dump())
        if not result.ok:
            return jsonify({
                "ok": False,
                "error_code": result.error_code,
                "message": result.message,
                "fallback_used": False,
                "usage": result.usage,
            }), 503

        try:
            response_model = DailyReflectionResponse.model_validate(result.content)
        except ValidationError as exc:
            return jsonify({
                "ok": False,
                "error_code": "model_output_invalid",
                "message": "Model output did not match DailyReflectionResponse.",
                "fallback_used": False,
                "details": exc.errors(),
                "usage": result.usage,
            }), 502

        return jsonify(response_model.model_dump())

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
