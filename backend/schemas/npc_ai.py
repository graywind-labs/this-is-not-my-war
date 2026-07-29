from __future__ import annotations

from typing import Annotated, Any, Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, model_validator

from .common import (
    ActionCandidate,
    CurrentOrderContext,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    PlanActionKind,
    ShortTermMemoryContext,
    StationSceneContext,
)


DialogueKind = Literal["player_npc", "npc_npc", "escape_intervention"]
PlanRevisionJudgementTriggerKind = Literal["dialogue", "action_failure"]
DialoguePhase = Literal["conversation", "invitation"]
DialogueVisibility = Literal["private", "local_public"]
InteractionContext = Literal["work", "rally", "combat", "avoid_combat", "escape_intervention"]
WartimeReaction = Literal["none", "escape", "morale_boost"]
PlanHour = Annotated[int, Field(ge=0, le=23)]


class StationAwareNPCRequest(BaseModel):
    # One request-level copy avoids repeating the same roster in nested speaker/target NPC contexts.
    station_context: StationSceneContext


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

    @model_validator(mode="after")
    def validate_observable_only(self):
        if self.state:
            raise ValueError(
                "speaker_context.state must remain empty; only appearance, health_status "
                "and the spoken text are observable by the replying NPC."
            )
        return self


class DialogueState(BaseModel):
    visibility: DialogueVisibility = "private"
    location_id: str = "plaza"
    location_name: str = "广场"
    current_round: int = Field(default=1, ge=0)
    max_rounds: int = Field(default=0, ge=0)
    soft_round_threshold: int = Field(default=5, ge=1)
    soft_round_guidance: str = ""
    participants: list[str] = Field(default_factory=list)


class DialogueActivityContext(BaseModel):
    action_id: str
    action_name: str
    phase: Literal["pending", "active", "external_active", "planned"]
    day: int | None = Field(default=None, ge=1)
    hour: int | None = Field(default=None, ge=0, le=23)
    location_id: str = ""
    location_name: str = ""
    target_id: str = ""
    workstation_id: str = ""
    elapsed_seconds: float | None = Field(default=None, ge=0.0)
    duration_seconds: float | None = Field(default=None, ge=0.0)


class DialogueInterruptionContext(BaseModel):
    # This is ephemeral target-private runtime context, not a memory/event record.
    interrupted_by_guard_officer: Literal[True]
    private_to_target_npc: Literal[True] = True
    activity_before_interruption: DialogueActivityContext
    current_plan_activity: DialogueActivityContext | None = None
    expected_activity_after_dialogue: DialogueActivityContext | None = None
    resume_policy: Literal[
        "resume_interrupted_activity_if_plan_unchanged",
        "follow_current_plan_after_dialogue_resolution",
    ]
    resume_expected_if_plan_unchanged: bool = False


class NPCDialogueRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    dialogue_kind: DialogueKind = "player_npc"
    dialogue_phase: DialoguePhase = "conversation"
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
    current_round: int = Field(default=1, ge=0)
    max_rounds: int = Field(default=0, ge=0)
    soft_round_threshold: int = Field(default=5, ge=1)
    soft_round_guidance: str = ""
    npc_state: dict[str, Any] = Field(default_factory=dict)
    current_order: CurrentOrderContext = Field(default_factory=CurrentOrderContext)
    dialogue_state: DialogueState = Field(default_factory=DialogueState)
    interrupted_activity_context: DialogueInterruptionContext | None = None
    interaction_context: InteractionContext = "work"
    battlefield_context: dict[str, Any] = Field(default_factory=dict)
    short_memory: ShortTermMemoryContext = Field(default_factory=ShortTermMemoryContext)
    long_memory: dict[str, Any] = Field(default_factory=dict)
    location_context: dict[str, Any] = Field(default_factory=dict)
    # Legacy clients may still serialize null. A non-null NPCContext would expose
    # the other participant's private memory/order/location to the replying NPC.
    speaker_npc: None = None
    target_npc: NPCContext | None = None
    conversation_history: list[DialogueTurn] = Field(default_factory=list)
    escape_intervention_round: int | None = Field(default=None, ge=1, le=5)
    allowed_actions: list[ActionCandidate] = Field(min_length=1)
    constraints: list[str] = Field(default_factory=list)


class DialogueResponseBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ok: Literal[True] = True
    replyer_id: str
    reply_text: str
    emotion: str = "neutral"
    suggested_event_type: str = "dialogue_turn"
    debug_reason: str = ""


class PlayerNPCDialogueResponse(DialogueResponseBase):
    response_kind: Literal["reply_to_player"] = "reply_to_player"
    recruitment_result: Literal["accept", "reject", "none"] = "none"
    wartime_reaction: WartimeReaction = "none"


class NPCNPCDialogueResponse(DialogueResponseBase):
    response_kind: Literal["reply_to_npc"] = "reply_to_npc"
    invitation_result: Literal["accept", "reject", "not_applicable"] = "not_applicable"
    should_end_dialogue: bool = False


class EscapeInterventionDialogueResponse(DialogueResponseBase):
    response_kind: Literal["reply_to_player"] = "reply_to_player"
    escape_intervention_result: Literal["stay", "leave"]


class PlanItem(BaseModel):
    hour: int = Field(ge=0, le=23)
    action_kind: PlanActionKind
    action_id: str
    location_id: str | None = None
    target_id: str | None = None
    priority: int = Field(default=50, ge=0, le=100)
    reason: str = ""
    dialogue_goal: str = ""


class DailyPlanRequest(StationAwareNPCRequest):
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


class PlanRevisionJudgementRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    npc_id: str
    npc_name: str = ""
    npc: NPCContext
    trigger_kind: PlanRevisionJudgementTriggerKind = "dialogue"
    dialogue_kind: DialogueKind = "player_npc"
    dialogue_history: list[DialogueTurn] = Field(default_factory=list)
    dialogue_end_reason: str = "dialogue_completed"
    dialogue_context: dict[str, Any] = Field(default_factory=dict)
    failed_plan_item: PlanItem | None = None
    failure_type: Literal[
        "target_unavailable",
        "workstation_occupied",
        "resource_insufficient",
        "dialogue_interrupted",
        "plan_item_superseded",
        "action_completed",
        "low_hp",
        "low_satiety",
        "high_fatigue",
        "combat_alarm",
        "order_changed",
        "unknown",
    ] = "unknown"
    failure_summary: str = ""
    failure_context: dict[str, Any] = Field(default_factory=dict)
    required_revision_hours: list[PlanHour] = Field(default_factory=list, max_length=24)
    allowed_actions: list[ActionCandidate] = Field(default_factory=list)
    current_building_states: dict[str, Any] = Field(default_factory=dict)
    current_resource_states: dict[str, Any] = Field(default_factory=dict)
    current_work_phase_count: int = Field(default=0, ge=0, le=24)
    minimum_work_phase_count: int = Field(default=6, ge=0, le=24)
    replacement_work_phase_required_if_non_work: bool = False
    current_plan: list[PlanItem] = Field(min_length=24, max_length=24)

    @model_validator(mode="after")
    def validate_trigger_context_and_full_current_plan(self):
        if self.npc.identity.npc_id != self.npc_id:
            raise ValueError("npc.identity.npc_id must match npc_id.")
        if sorted(item.hour for item in self.current_plan) != list(range(24)):
            raise ValueError("current_plan must contain each hour from 0 to 23 exactly once.")
        if self.required_revision_hours != sorted(set(self.required_revision_hours)):
            raise ValueError("required_revision_hours must be unique and sorted ascending.")
        if any(hour < self.game_time.hour for hour in self.required_revision_hours):
            raise ValueError(
                "required_revision_hours cannot contain hours before game_time.hour."
            )
        if self.trigger_kind == "dialogue":
            if not self.dialogue_history:
                raise ValueError("dialogue trigger requires non-empty dialogue_history.")
        else:
            if self.failed_plan_item is None:
                raise ValueError("action_failure trigger requires failed_plan_item.")
            if not self.failure_summary.strip():
                raise ValueError("action_failure trigger requires non-empty failure_summary.")
            if self.dialogue_history:
                raise ValueError("action_failure trigger must not include dialogue_history.")
        return self


class PlanRevisionJudgementResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    needs_revision: bool
    revision_hours: list[PlanHour] = Field(default_factory=list, max_length=24)
    summary: str = ""
    debug_reason: str = ""


# Compatibility aliases for T0049 callers. New runtime code uses the generic
# plan revision judgement contract for both dialogue and action-failure facts.
DialoguePlanRevisionJudgementRequest = PlanRevisionJudgementRequest
DialoguePlanRevisionJudgementResponse = PlanRevisionJudgementResponse


class PlanRevisionRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    current_plan: list[PlanItem] = Field(min_length=24, max_length=24)
    failed_plan_item: PlanItem
    revision_scope: Literal["selected_hours"] = "selected_hours"
    revision_hours: list[PlanHour] = Field(min_length=1, max_length=24)
    current_work_phase_count: int = Field(default=0, ge=0, le=24)
    minimum_work_phase_count: int = Field(default=6, ge=0, le=24)
    past_work_phase_count: int = Field(default=0, ge=0, le=24)
    minimum_remaining_work_phase_count: int = Field(default=6, ge=0, le=24)
    replacement_work_phase_required_if_non_work: bool = False
    failure_type: Literal[
        "target_unavailable",
        "workstation_occupied",
        "resource_insufficient",
        "dialogue_interrupted",
        "plan_item_superseded",
        "action_completed",
        "low_hp",
        "low_satiety",
        "high_fatigue",
        "combat_alarm",
        "order_changed",
        "unknown",
    ]
    failure_summary: str
    failure_context: dict[str, Any] = Field(default_factory=dict)
    allowed_actions: list[ActionCandidate]
    current_building_states: dict[str, Any] = Field(default_factory=dict)
    current_resource_states: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_selected_hours(self):
        if sorted(item.hour for item in self.current_plan) != list(range(24)):
            raise ValueError("current_plan must contain each hour from 0 to 23 exactly once.")
        if self.revision_hours != sorted(set(self.revision_hours)):
            raise ValueError("revision_hours must be unique and sorted ascending.")
        if any(hour < self.game_time.hour for hour in self.revision_hours):
            raise ValueError("revision_hours cannot contain hours before game_time.hour.")
        return self


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


class BattleJudgementRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    trigger: BattleTrigger
    npc: NPCContext
    combat_context: dict[str, Any] = Field(default_factory=dict)
    battlefield_context: dict[str, Any] = Field(default_factory=dict)
    allowed_decisions: list[BattleDecision]


class BattleJudgementResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    decision: BattleDecision
    emotion: str = "tense"
    morale_delta_intent: int = Field(default=0, ge=-100, le=100)
    should_start_escape: bool = False
    debug_reason: str = ""


class ReflectionBoundaryContext(BaseModel):
    day: int = Field(ge=1)
    time: str = Field(pattern=r"^\d{2}:\d{2}:\d{2}$")


class ReflectionPeriodContext(BaseModel):
    start: ReflectionBoundaryContext
    end: ReflectionBoundaryContext
    start_inclusive: bool
    start_basis: str = Field(min_length=1)
    end_basis: str = Field(min_length=1)
    snapshot_event_count: int = Field(default=0, ge=0)
    snapshot_witness_count: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def validate_chronology(self):
        def seconds(boundary: ReflectionBoundaryContext) -> int:
            hour, minute, second = (int(part) for part in boundary.time.split(":"))
            return (boundary.day - 1) * 86400 + hour * 3600 + minute * 60 + second

        if seconds(self.end) < seconds(self.start):
            raise ValueError("reflection_period.end must not precede reflection_period.start.")
        return self


class ReflectionSummaryWindowContext(BaseModel):
    window_key: str = Field(min_length=1)
    anchor_day: int = Field(ge=1)
    anchor_time: str = Field(pattern=r"^\d{2}:\d{2}:\d{2}$")
    end_day: int = Field(ge=2)
    end_time: str = Field(pattern=r"^\d{2}:\d{2}:\d{2}$")
    diary_label: str = Field(min_length=1)
    notice_basis: str = Field(min_length=1)

    @model_validator(mode="after")
    def validate_window_semantics(self):
        if self.anchor_time != "21:00:00" or self.end_time != "21:00:00":
            raise ValueError("daily reflection summary windows must be anchored at 21:00:00.")
        if self.end_day != self.anchor_day + 1:
            raise ValueError("summary_window.end_day must equal anchor_day + 1.")
        expected_label = f"接到守备命令的第{self.anchor_day}天"
        if self.diary_label != expected_label:
            raise ValueError(f"summary_window.diary_label must be '{expected_label}'.")
        if "我们奉命守住此地" not in self.notice_basis:
            raise ValueError("summary_window.notice_basis must identify the public guard notice.")
        return self


class DailyReflectionRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    day_events: list[dict[str, Any]] = Field(default_factory=list)
    summary_window: ReflectionSummaryWindowContext
    reflection_period: ReflectionPeriodContext
    existing_diary_entries: list[str] = Field(default_factory=list)


class KnowledgeGraphPatch(BaseModel):
    subject: str
    relation: str
    value: str
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    subject_label: str = ""
    relation_label: str = ""
    value_label: str = ""


class DailyReflectionResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    day: int = Field(ge=1)
    diary_entry: str
    knowledge_graph_updates: list[KnowledgeGraphPatch] = Field(default_factory=list)
    debug_reason: str = ""


class KnowledgeGraphUpdateRequest(StationAwareNPCRequest):
    meta: ModelRequestMeta
    game_time: GameTime
    npc: NPCContext
    source_summaries: list[str]


class KnowledgeGraphUpdateResponse(BaseModel):
    ok: Literal[True] = True
    npc_id: str
    updates: list[KnowledgeGraphPatch] = Field(default_factory=list)
    debug_reason: str = ""


class ProactiveIntentionRequest(StationAwareNPCRequest):
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


class PlayerStrategyClassificationRequest(StationAwareNPCRequest):
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
