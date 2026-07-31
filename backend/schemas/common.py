from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


PlanActionKind = Literal[
    "work",
    "eat",
    "drink",
    "sleep",
    "train",
    "pray",
    "rest",
    "visit",
    "chat",
    "assist_repair",
    "assist_upgrade",
    "assist_heal",
    "seek_guard_officer",
    "avoid_combat",
    "escape",
    "idle",
]


class GameTime(BaseModel):
    day: int = Field(ge=1)
    time: str = Field(pattern=r"^\d{2}:\d{2}:\d{2}$")
    hour: int = Field(ge=0, le=23)


class ModelRequestMeta(BaseModel):
    request_id: str
    call_type: str
    source: Literal["godot", "backend_test"] = "godot"
    requires_time_slowdown: bool = False
    related_event_id: str | None = None


class EventSummary(BaseModel):
    # event_id remains accepted for compatibility with older fixtures and audit
    # inputs, but current Godot prompt projections omit it because the model
    # cannot use an internal storage identifier to make a better decision.
    event_id: str | None = None
    type: str
    summary: str
    importance: int = Field(default=50, ge=0, le=100)
    day: int | None = Field(default=None, ge=1)
    time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}:\d{2}$")
    details: dict[str, Any] = Field(default_factory=dict)


class ShortTermMemoryContext(BaseModel):
    experienced_events: list[EventSummary] = Field(default_factory=list)
    witnessed_events: list[EventSummary] = Field(default_factory=list)


class LongTermMemoryContext(BaseModel):
    knowledge_graph: dict[str, Any] = Field(default_factory=dict)
    diary: list[str] = Field(default_factory=list)


class NPCIdentity(BaseModel):
    npc_id: str
    name: str
    gender: str | None = None
    background_job: str | None = None
    religion: str = ""
    background_story: str = ""
    personality: list[str] = Field(default_factory=list)
    desires: list[str] = Field(default_factory=list)
    fears: list[str] = Field(default_factory=list)
    boundaries: list[str] = Field(default_factory=list)
    speech_style: str = ""


class NPCStateContext(BaseModel):
    hp: int = Field(ge=0)
    max_hp: int = Field(gt=0)
    satiety: int = Field(ge=0, le=100)
    fatigue: int = Field(ge=0, le=100)
    current_action: str = "idle"
    behavior_mode: str = "work"
    combat_mode: str = ""
    combat_strategy: dict[str, Any] = Field(default_factory=dict)
    morale_boost: dict[str, Any] = Field(default_factory=dict)
    escape_intent: dict[str, Any] = Field(default_factory=dict)
    current_location: str = "plaza"
    current_location_name: str = "广场"
    recruited: bool = False
    unconscious: bool = False
    escaped: bool = False
    equipment: dict[str, Any] = Field(default_factory=dict)
    skills: dict[str, int] = Field(default_factory=dict)
    stats: dict[str, int] = Field(default_factory=dict)
    money: int = Field(default=0, ge=0)
    wine: int = Field(default=0, ge=0)


class CurrentOrderContext(BaseModel):
    text: str = ""
    issued_by: str = "guard_officer"
    issued_day: int = Field(default=0, ge=0)
    issued_time: str = ""
    revision: int = Field(default=0, ge=0)


class StationResidentContext(BaseModel):
    npc_id: str
    name: str
    identity: str
    recruited: bool
    in_station: bool


class StationBuildingContext(BaseModel):
    building_id: str
    name: str


class StationWorkModeActionContext(BaseModel):
    action_id: str
    name: str
    action_kind: PlanActionKind
    description: str = ""


class StationBasicResourceReserveContext(BaseModel):
    resource_id: Literal["grain", "meal", "wood", "stone", "iron"]
    name: str = Field(min_length=1)
    amount: int = Field(ge=0)


class StationSceneContext(BaseModel):
    setting_summary: str = Field(min_length=1)
    resident_roster: list[StationResidentContext] = Field(min_length=1)
    building_roster: list[StationBuildingContext] = Field(min_length=1)
    work_mode_actions: list[StationWorkModeActionContext] = Field(min_length=1)
    basic_resource_reserves: list[StationBasicResourceReserveContext] = Field(
        min_length=5,
        max_length=5,
    )
    station_rules: list[str] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_basic_resource_reserves(self):
        expected_ids = ["grain", "meal", "wood", "stone", "iron"]
        actual_ids = [item.resource_id for item in self.basic_resource_reserves]
        if actual_ids != expected_ids:
            raise ValueError(
                "basic_resource_reserves must contain grain, meal, wood, stone and iron "
                "exactly once in that order."
            )
        return self


class NPCContext(BaseModel):
    identity: NPCIdentity
    state: NPCStateContext
    current_order: CurrentOrderContext = Field(default_factory=CurrentOrderContext)
    short_term_memory: ShortTermMemoryContext = Field(default_factory=ShortTermMemoryContext)
    long_term_memory: LongTermMemoryContext = Field(default_factory=LongTermMemoryContext)
    # Legacy fixtures may still send this field. LLMBridge no longer populates the
    # duplicate mirror; every current prompt reads long_term_memory instead.
    knowledge_graph: dict[str, Any] = Field(default_factory=dict)
    location_context: dict[str, Any] = Field(default_factory=dict)
    plaza_context: dict[str, Any] = Field(default_factory=dict)


class ActionCandidate(BaseModel):
    action_id: str
    name: str
    action_kind: PlanActionKind | None = None
    location_id: str | None = None
    target_id: str | None = None
    target_kind: str | None = None
    target_name: str | None = None
    tags: list[str] = Field(default_factory=list)
    context: dict[str, Any] = Field(default_factory=dict)


class APIErrorResponse(BaseModel):
    ok: Literal[False] = False
    error_code: str
    message: str
    fallback_used: bool = False
