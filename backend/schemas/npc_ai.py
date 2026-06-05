from __future__ import annotations

from typing import Any, Literal

from pydantic import AliasChoices, BaseModel, Field

from .common import ActionCandidate, CurrentOrderContext, GameTime, ModelRequestMeta, NPCContext, ShortTermMemoryContext


DialogueKind = Literal["player_npc", "npc_npc", "escape_intervention"]
DialogueVisibility = Literal["private", "local_public"]
DialogueIntent = Literal[
    "continue_talk",
    "accept_recruitment",
    "reject_recruitment",
    "request_money",
    "request_equipment",
    "request_rest",
    "request_treatment",
    "share_witness",
    "start_escape",
    "stay_after_intervention",
    "leave_after_intervention",
    "end_talk",
]


class DialogueTurn(BaseModel):
    speaker_id: str
    speaker_name: str | None = None
    listener_id: str | None = None
    listener_name: str | None = None
    text: str
    day: int | None = Field(default=None, ge=1)
    time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}:\d{2}$")
    visibility: DialogueVisibility = "private"


class SpeakerContext(BaseModel):
    speaker_id: str | None = None
    speaker_name: str
    speaker_kind: Literal["guard_officer", "npc"] = "guard_officer"
    appearance: str = ""
    health_status: str = ""
    state: dict[str, Any] = Field(default_factory=dict)


class DialogueState(BaseModel):
    visibility: DialogueVisibility = "private"
    location_id: str = "plaza"
    location_name: str = "广场"
    current_round: int = Field(default=1, ge=1)
    max_rounds: int = Field(default=1, ge=1)
    participants: list[str] = Field(default_factory=list)


class NPCDialogueRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    dialogue_kind: DialogueKind = "player_npc"
    npc_id: str
    npc_name: str
    npc_setting: dict[str, Any] = Field(default_factory=dict)
    speaker_name: str
    speaker_text: str = Field(
        validation_alias=AliasChoices(
            "speaker_text",
            "player_text",
            "npc_text",
            "guard_officer_input",
        )
    )
    speaker_context: SpeakerContext
    is_recruitment_request: bool = Field(
        default=False,
        validation_alias=AliasChoices("is_recruitment_request", "propose_recruitment"),
    )
    current_round: int = Field(default=1, ge=1)
    max_rounds: int = Field(default=1, ge=1)
    npc_state: dict[str, Any] = Field(default_factory=dict)
    current_order: CurrentOrderContext = Field(default_factory=CurrentOrderContext)
    dialogue_state: DialogueState = Field(default_factory=DialogueState)
    short_memory: ShortTermMemoryContext = Field(default_factory=ShortTermMemoryContext)
    long_memory: dict[str, Any] = Field(default_factory=dict)
    location_context: dict[str, Any] = Field(default_factory=dict)
    speaker_npc: NPCContext | None = None
    target_npc: NPCContext | None = None
    conversation_history: list[DialogueTurn] = Field(default_factory=list)
    escape_intervention_round: int | None = Field(default=None, ge=1, le=5)
    allowed_actions: list[ActionCandidate] = Field(default_factory=list)
    constraints: list[str] = Field(default_factory=list)


class NPCDialogueResponse(BaseModel):
    ok: Literal[True] = True
    replyer_id: str
    reply_text: str
    response_kind: Literal["reply_to_player", "reply_to_npc"] = "reply_to_player"
    intent: DialogueIntent = "continue_talk"
    emotion: str = "neutral"
    recruitment_result: Literal["accept", "reject", "none"] = "none"
    should_end_dialogue: bool = False
    suggested_event_type: str = "dialogue_turn"
    debug_reason: str = ""


PlanActionKind = Literal[
    "work",
    "eat",
    "sleep",
    "train",
    "pray",
    "rest",
    "chat",
    "assist_repair",
    "assist_upgrade",
    "assist_heal",
    "seek_guard_officer",
    "avoid_combat",
    "escape",
    "idle",
]


class PlanItem(BaseModel):
    hour: int = Field(ge=0, le=23)
    action_kind: PlanActionKind
    action_id: str
    location_id: str | None = None
    target_id: str | None = None
    priority: int = Field(default=50, ge=0, le=100)
    reason: str = ""


class DailyPlanRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    allowed_actions: list[ActionCandidate]
    current_building_states: dict[str, Any] = Field(default_factory=dict)
    current_resource_states: dict[str, Any] = Field(default_factory=dict)
    planning_rules: list[str] = Field(default_factory=list)


class DailyPlanResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    plan_day: int = Field(ge=1)
    plan: list[PlanItem] = Field(min_length=24, max_length=24)
    summary: str = ""
    debug_reason: str = ""


class PlanRevisionRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    current_plan: list[PlanItem]
    failed_plan_item: PlanItem
    failure_type: Literal[
        "target_unavailable",
        "workstation_occupied",
        "resource_insufficient",
        "dialogue_interrupted",
        "low_hp",
        "low_satiety",
        "high_fatigue",
        "combat_alarm",
        "order_changed",
        "unknown",
    ]
    failure_summary: str
    allowed_actions: list[ActionCandidate]


class PlanRevisionResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    revised_plan: list[PlanItem]
    immediate_action: PlanItem | None = None
    summary: str = ""
    debug_reason: str = ""


BattleTrigger = Literal["combat_started", "low_hp", "escape_check"]
BattleDecision = Literal[
    "join_battle",
    "avoid_battle",
    "continue_fighting",
    "escape_station",
    "inspired",
]


class BattleJudgementRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    trigger: BattleTrigger
    npc: NPCContext
    combat_context: dict[str, Any] = Field(default_factory=dict)
    allowed_decisions: list[BattleDecision]


class BattleJudgementResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    decision: BattleDecision
    emotion: str = "tense"
    morale_delta_intent: int = Field(default=0, ge=-100, le=100)
    should_start_escape: bool = False
    debug_reason: str = ""


class DailyReflectionRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    day_events: list[dict[str, Any]] = Field(default_factory=list)
    existing_diary_entries: list[str] = Field(default_factory=list)


class KnowledgeGraphPatch(BaseModel):
    subject: str
    relation: str
    value: str
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)


class DailyReflectionResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    day: int = Field(ge=1)
    diary_entry: str
    memory_summary: str
    knowledge_graph_updates: list[KnowledgeGraphPatch] = Field(default_factory=list)
    debug_reason: str = ""


class KnowledgeGraphUpdateRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    source_summaries: list[str]


class KnowledgeGraphUpdateResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    updates: list[KnowledgeGraphPatch] = Field(default_factory=list)
    debug_reason: str = ""


class ProactiveIntentionRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    current_plan: list[PlanItem] = Field(default_factory=list)
    possible_topics: list[str] = Field(default_factory=list)


class ProactiveIntentionResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    should_seek_guard_officer: bool
    topic: str = ""
    urgency: int = Field(default=0, ge=0, le=100)
    debug_reason: str = ""


class PlayerStrategyClassificationRequest(BaseModel):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    guard_officer_input: str
    dialogue_history: list[DialogueTurn] = Field(default_factory=list)


class PlayerStrategyClassificationResponse(BaseModel):
    ok: Literal[True] = True
    strategy: Literal[
        "persuade",
        "bribe",
        "threaten",
        "deceive",
        "comfort",
        "trade",
        "command",
        "unknown",
    ]
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    debug_reason: str = ""
