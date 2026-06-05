from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


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
    event_id: str | None = None
    type: str
    summary: str
    importance: int = Field(default=50, ge=0, le=100)
    day: int | None = Field(default=None, ge=1)
    time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}:\d{2}$")
    payload: dict[str, Any] = Field(default_factory=dict)


class ShortTermMemoryContext(BaseModel):
    experienced_events: list[EventSummary] = Field(default_factory=list)
    witnessed_events: list[EventSummary] = Field(default_factory=list)


class NPCIdentity(BaseModel):
    npc_id: str
    name: str
    gender: str | None = None
    background_job: str | None = None
    personality: list[str] = Field(default_factory=list)
    desires: list[str] = Field(default_factory=list)
    fears: list[str] = Field(default_factory=list)
    boundaries: list[str] = Field(default_factory=list)


class NPCStateContext(BaseModel):
    hp: int = Field(ge=0)
    max_hp: int = Field(gt=0)
    satiety: int = Field(ge=0, le=100)
    fatigue: int = Field(ge=0, le=100)
    current_action: str = "idle"
    current_location: str = "plaza"
    current_location_name: str = "广场"
    recruited: bool = False
    unconscious: bool = False
    escaped: bool = False
    equipment: dict[str, Any] = Field(default_factory=dict)
    skills: dict[str, int] = Field(default_factory=dict)
    stats: dict[str, int] = Field(default_factory=dict)


class CurrentOrderContext(BaseModel):
    text: str = ""
    issued_by: str = "guard_officer"
    issued_day: int = Field(default=0, ge=0)
    issued_time: str = ""
    revision: int = Field(default=0, ge=0)


class NPCContext(BaseModel):
    identity: NPCIdentity
    state: NPCStateContext
    current_order: CurrentOrderContext = Field(default_factory=CurrentOrderContext)
    short_term_memory: ShortTermMemoryContext = Field(default_factory=ShortTermMemoryContext)
    knowledge_graph: dict[str, Any] = Field(default_factory=dict)
    location_context: dict[str, Any] = Field(default_factory=dict)
    plaza_context: dict[str, Any] = Field(default_factory=dict)


class ActionCandidate(BaseModel):
    action_id: str
    name: str
    location_id: str | None = None
    target_id: str | None = None
    tags: list[str] = Field(default_factory=list)


class APIErrorResponse(BaseModel):
    ok: Literal[False] = False
    error_code: str
    message: str
    fallback_used: bool = False
