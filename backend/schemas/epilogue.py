from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .common import ModelRequestMeta


GameResult = Literal["victory", "failure"]
OpeningStatus = Literal["active", "unconscious", "escaped"]
EscapeCircumstance = Literal[
    "none",
    "before_fall_voluntary",
    "after_fall_forced",
    "before_settlement_voluntary",
]
EpilogueTone = Literal[
    "hopeful",
    "hopeful_bittersweet",
    "reconciled",
    "sorrowful",
    "sorrowful_resilient",
    "unresolved",
]


class EpilogueFact(BaseModel):
    model_config = ConfigDict(extra="forbid")

    fact_id: str = Field(min_length=1, max_length=96)
    category: str = Field(min_length=1, max_length=64)
    summary: str = Field(min_length=1, max_length=500)


class EpilogueNPCInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    npc_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    profession: str = Field(min_length=1)
    background_story: str = ""
    personality: list[str] = Field(default_factory=list)
    desires: list[str] = Field(default_factory=list)
    fears: list[str] = Field(default_factory=list)
    recruited: bool
    opening_status: OpeningStatus
    escape_circumstance: EscapeCircumstance = "none"
    hp: int = Field(ge=0)
    max_hp: int = Field(ge=1)
    final_location: str = Field(min_length=1)
    current_order: dict[str, Any] = Field(default_factory=dict)
    diary: list[str] = Field(default_factory=list, max_length=8)
    knowledge: list[str] = Field(default_factory=list, max_length=16)
    key_facts: list[EpilogueFact] = Field(default_factory=list, max_length=16)

    @model_validator(mode="after")
    def validate_hp(self):
        if self.hp > self.max_hp:
            raise ValueError("hp must not exceed max_hp.")
        return self


class GameEpilogueRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    meta: ModelRequestMeta
    settlement_id: str = Field(min_length=1, max_length=160)
    fact_snapshot_version: Literal[1] = 1
    result: GameResult
    reason: str = Field(min_length=1)
    game_time: dict[str, Any]
    station_summary: dict[str, Any] = Field(default_factory=dict)
    global_facts: list[EpilogueFact] = Field(default_factory=list, max_length=20)
    npcs: list[EpilogueNPCInput] = Field(min_length=1, max_length=16)

    @model_validator(mode="after")
    def validate_npc_ids(self):
        npc_ids = [npc.npc_id for npc in self.npcs]
        if len(npc_ids) != len(set(npc_ids)):
            raise ValueError("npcs must contain unique npc_id values.")
        fact_ids = [fact.fact_id for fact in self.global_facts]
        for npc in self.npcs:
            fact_ids.extend(fact.fact_id for fact in npc.key_facts)
        if len(fact_ids) != len(set(fact_ids)):
            raise ValueError("all fact_id values must be unique within one settlement.")
        return self


class NPCEpilogue(BaseModel):
    model_config = ConfigDict(extra="forbid")

    npc_id: str = Field(min_length=1)
    ending_title: str = Field(min_length=2, max_length=24)
    opening_status: OpeningStatus
    final_opinion: str = Field(min_length=20, max_length=180)
    fate_story: str = Field(min_length=140, max_length=420)
    tone: EpilogueTone
    fact_refs: list[str] = Field(min_length=1, max_length=3)


class GameEpilogueResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ok: Literal[True] = True
    result: GameResult
    ending_title: str = Field(min_length=2, max_length=32)
    station_coda: str = Field(min_length=60, max_length=360)
    npc_endings: list[NPCEpilogue] = Field(min_length=1, max_length=16)
    debug_reason: str = ""
