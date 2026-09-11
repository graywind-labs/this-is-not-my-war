from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402
from tools.verify_dialogue_prompt_real import _base_payload  # noqa: E402
from tools.verify_plan_revision_prompt import _payload as _base_revision_payload  # noqa: E402


UPGRADE_CANDIDATE = {
    "action_id": "assist_upgrade",
    "name": "协助升级工械坊",
    "action_kind": "assist_upgrade",
    "location_id": "plaza",
    "target_id": "workshop",
    "target_kind": "building",
    "target_name": "工械坊",
    "tags": ["work", "assist_upgrade", "engineering"],
    "context": {
        "eligible": True,
        "available_now": True,
        "execution_location": "plaza",
        "requires_building_entry": False,
        "counts_as_work_phase": True,
        "effect": "在建筑外协助正在进行的升级，加快工程进度",
    },
}


def _dialogue_payload() -> dict:
    payload = _base_payload(
        "verify_upgrade_assist_real_dialogue",
        "工械坊正在升级，门锁着不能进去。但你能不能在建筑外帮忙升级、让工程更快？请明确回答。",
    )
    payload["station_context"] = build_station_context([
        {"npc_id": "engineer_01", "name": "欧文", "identity": "工程师"}
    ])
    payload["npc_id"] = "engineer_01"
    payload["npc_name"] = "欧文"
    payload["npc_setting"].update({
        "background_job": "工程师",
        "personality": ["谨慎", "务实"],
        "desires": ["让工械坊尽快恢复运转"],
    })
    payload["npc_state"].update({
        "current_action": "idle",
        "current_location": "plaza",
        "current_location_name": "广场",
    })
    payload["location_context"] = {
        "id": "plaza",
        "name": "广场",
        "people_present": ["engineer_01"],
    }
    payload["allowed_actions"] = [
        {
            "action_id": "work_workshop",
            "name": "推进工械坊制造",
            "action_kind": "work",
            "location_id": "workshop",
            "target_id": None,
            "target_kind": None,
            "target_name": None,
            "tags": ["work"],
            "context": {
                "eligible": True,
                "available_now": False,
                "unavailable_reason": "建筑当前不可进入或使用",
            },
        },
        UPGRADE_CANDIDATE,
        {
            "action_id": "idle",
            "name": "等待",
            "action_kind": "idle",
            "location_id": None,
            "target_id": None,
            "tags": ["idle"],
            "context": {},
        },
    ]
    return payload


def _revision_payload() -> dict:
    payload = _base_revision_payload()
    payload["meta"]["request_id"] = "verify_upgrade_assist_real_revision"
    payload["station_context"] = build_station_context([
        {"npc_id": "engineer_01", "name": "欧文", "identity": "工程师"}
    ])
    payload["npc"]["identity"].update({
        "npc_id": "engineer_01",
        "name": "欧文",
        "background_job": "工程师",
        "personality": ["谨慎", "务实"],
        "desires": ["让工械坊尽快恢复运转"],
    })
    payload["npc"]["state"].update({
        "current_location": "plaza",
        "current_location_name": "广场",
        "skills": {"工程": 80},
    })
    for item in payload["current_plan"]:
        item.update({
            "action_kind": "work",
            "action_id": "work_workshop",
            "location_id": "workshop",
            "target_id": None,
            "reason": "推进工械坊制造",
        })
    payload["failed_plan_item"] = dict(payload["current_plan"][8])
    payload["revision_hours"] = [8]
    payload["current_work_phase_count"] = 24
    payload["past_work_phase_count"] = 8
    payload["failure_type"] = "target_unavailable"
    payload["failure_summary"] = "到达工械坊入口后发现建筑正在升级，无法进入执行制造工作。"
    payload["failure_context"] = {
        "action_id": "work_workshop",
        "building_id": "workshop",
        "building_name": "工械坊",
        "condition": "upgrading",
        "failure_reason": "building_upgrading",
        "interrupted_phase": "pending",
        "arrival_check_failed": True,
    }
    payload["current_building_states"] = {
        "workshop": {
            "name": "工械坊",
            "level": 1,
            "hp": 120,
            "max_hp": 120,
            "is_upgrading": True,
            "is_repairing": False,
            "repair_job": {},
            "upgrade_job": {
                "active": True,
                "total_duration": "2小时0分00秒",
                "remaining_time": "1小时35分00秒",
                "progress_percent": 21,
                "helper_count": 0,
            },
            "workstations": [],
        },
    }
    payload["allowed_actions"] = [
        UPGRADE_CANDIDATE,
        {
            "action_id": "work_blacksmith",
            "name": "推进铁匠铺制造",
            "action_kind": "work",
            "location_id": "blacksmith",
            "target_id": None,
            "target_kind": None,
            "target_name": None,
            "tags": ["work"],
            "context": {
                "eligible": True,
                "available_now": True,
            },
        },
        {
            "action_id": "idle",
            "name": "等待",
            "action_kind": "idle",
            "location_id": None,
            "target_id": None,
            "tags": ["idle"],
            "context": {},
        },
    ]
    return payload


def _completion_revision_payload() -> dict:
    payload = _base_revision_payload()
    payload["meta"]["request_id"] = "verify_upgrade_completion_real_revision"
    payload["station_context"] = build_station_context([
        {"npc_id": "doctor_01", "name": "莉娜", "identity": "医生"}
    ])
    payload["npc"]["identity"].update({
        "npc_id": "doctor_01",
        "name": "莉娜",
        "background_job": "医生",
        "personality": ["冷静", "务实"],
        "desires": ["维持诊所运转并照料伤员"],
    })
    payload["npc"]["state"].update({
        "current_location": "plaza",
        "current_location_name": "广场",
        "satiety": 90,
        "fatigue": 20,
        "skills": {"医术": 80},
    })
    for item in payload["current_plan"]:
        item.update({
            "action_kind": "idle",
            "action_id": "idle",
            "location_id": None,
            "target_id": None,
            "reason": "等待",
        })
    payload["current_plan"][8].update({
        "action_kind": "assist_upgrade",
        "action_id": "assist_upgrade",
        "location_id": "plaza",
        "target_id": "clinic",
        "reason": "协助诊所升级",
    })
    payload["failed_plan_item"] = dict(payload["current_plan"][8])
    payload["revision_hours"] = [8]
    payload["current_work_phase_count"] = 1
    payload["past_work_phase_count"] = 0
    payload["minimum_remaining_work_phase_count"] = 6
    payload["replacement_work_phase_required_if_non_work"] = False
    payload["failure_type"] = "target_unavailable"
    payload["failure_summary"] = "小诊所的升级作业已经结束，协助升级目标已不可用。"
    payload["failure_context"] = {
        "action_id": "assist_upgrade",
        "building_id": "clinic",
        "building_name": "小诊所",
        "condition": "target_resolved_or_inactive",
        "failure_reason": "no_active_upgrade",
    }
    payload["current_building_states"] = {
        "clinic": {
            "name": "小诊所",
            "level": 2,
            "hp": 120,
            "max_hp": 120,
            "is_upgrading": False,
            "is_repairing": False,
            "repair_job": {},
            "upgrade_job": {},
            "workstations": [{
                "workstation_id": "doctor_desk_01",
                "workstation_type": "clinic_doctor_station",
                "status": "free",
                "occupied_by": None,
            }],
        },
    }
    payload["allowed_actions"] = [
        {
            "action_id": "work_clinic_doctor",
            "name": "坐诊",
            "action_kind": "work",
            "location_id": "clinic",
            "target_id": None,
            "target_kind": None,
            "target_name": None,
            "tags": ["clinic_doctor"],
            "context": {
                "eligible": True,
                "available_now": True,
                "workstation_type": "clinic_doctor_station",
            },
        },
        {
            "action_id": "idle",
            "name": "等待",
            "action_kind": "idle",
            "location_id": None,
            "target_id": None,
            "tags": ["idle"],
            "context": {},
        },
    ]
    return payload


def _contiguous_completion_revision_payload() -> dict:
    payload = _completion_revision_payload()
    payload["meta"]["request_id"] = "verify_contiguous_completion_real_revision"
    for hour in [8, 9, 10]:
        payload["current_plan"][hour].update({
            "action_kind": "assist_upgrade",
            "action_id": "assist_upgrade",
            "location_id": "plaza",
            "target_id": "clinic",
            "reason": "协助诊所升级",
        })
    payload["failed_plan_item"] = dict(payload["current_plan"][8])
    payload["revision_hours"] = [8, 9, 10]
    payload["current_work_phase_count"] = 3
    payload["failure_type"] = "action_completed"
    payload["failure_summary"] = "协助升级已经完成，需重新安排当前起连续的3个相同计划阶段。"
    payload["failure_context"] = {
        "condition": "successful_plan_action_completion",
        "completed_action_id": "assist_upgrade",
        "completed_action_name": "协助升级建筑",
        "completion_result": "completed_assist_upgrade_clinic",
        "completed_plan_item": dict(payload["current_plan"][8]),
        "requires_different_current_activity": True,
        "contiguous_revision_hours": [8, 9, 10],
    }
    return payload


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print("verify_upgrade_assist_real: skipped (real provider configuration required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    client = create_app().test_client()

    dialogue_response = client.post("/npc/dialogue", json=_dialogue_payload())
    assert dialogue_response.status_code == 200, dialogue_response.get_data(as_text=True)
    dialogue_body = dialogue_response.get_json()
    reply = str(dialogue_body["reply_text"]).replace(" ", "")
    assert any(fragment in reply for fragment in ["可以", "能", "会去", "愿意"]), reply
    assert "工械坊" in reply, reply
    assert any(fragment in reply for fragment in ["建筑外", "外面", "门外", "广场"]), reply
    assert dialogue_body["model_provider"] == provider
    assert dialogue_body["model_fallback_used"] is False

    revision_response = client.post("/npc/revise_plan", json=_revision_payload())
    assert revision_response.status_code == 200, revision_response.get_data(as_text=True)
    revision_body = revision_response.get_json()
    immediate = revision_body["immediate_action"]
    assert immediate["action_id"] == "assist_upgrade", immediate
    assert immediate["target_id"] == "workshop", immediate
    assert immediate["location_id"] == "plaza", immediate
    assert revision_body["model_provider"] == provider
    assert revision_body["model_fallback_used"] is False

    completion_response = client.post(
        "/npc/revise_plan",
        json=_completion_revision_payload(),
    )
    assert completion_response.status_code == 200, completion_response.get_data(as_text=True)
    completion_body = completion_response.get_json()
    completion_immediate = completion_body["immediate_action"]
    assert completion_immediate["action_id"] == "work_clinic_doctor", completion_immediate
    assert completion_immediate["location_id"] == "clinic", completion_immediate
    assert completion_body["model_provider"] == provider
    assert completion_body["model_fallback_used"] is False

    contiguous_response = client.post(
        "/npc/revise_plan",
        json=_contiguous_completion_revision_payload(),
    )
    assert contiguous_response.status_code == 200, contiguous_response.get_data(as_text=True)
    contiguous_body = contiguous_response.get_json()
    assert [item["hour"] for item in contiguous_body["revised_plan"]] == [8, 9, 10]
    assert all(
        item["action_id"] != "assist_upgrade"
        for item in contiguous_body["revised_plan"]
    ), contiguous_body["revised_plan"]
    assert contiguous_body["immediate_action"]["hour"] == 8
    assert contiguous_body["model_provider"] == provider
    assert contiguous_body["model_fallback_used"] is False
    print(
        "verify_upgrade_assist_real: ok "
        "(dialogue_request=verify_upgrade_assist_real_dialogue, "
        "revision_request=verify_upgrade_assist_real_revision, "
        "completion_request=verify_upgrade_completion_real_revision, "
        "contiguous_request=verify_contiguous_completion_real_revision)"
    )


if __name__ == "__main__":
    main()
