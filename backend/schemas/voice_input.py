from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator


VoiceEmotion = Literal[
    "neutral",
    "happy",
    "sad",
    "disgusted",
    "angry",
    "fearful",
    "surprised",
    "none",
]

QWEN_NATIVE_VOICE_EMOTIONS = {
    "neutral": "平静地",
    "happy": "愉快地",
    "sad": "悲伤地",
    "disgusted": "厌恶地",
    "angry": "愤怒地",
    "fearful": "恐惧地",
    "surprised": "惊讶地",
}


class DialogueInputConfig(BaseModel):
    schema_version: int = Field(default=1, ge=1)
    player_message_max_characters: int = Field(default=300, gt=0)
    voice_recording_max_seconds: float = Field(default=30.0, gt=0)
    voice_upload_max_bytes: int = Field(default=6_291_456, gt=0)


class VoiceAnalyzeRequest(BaseModel):
    request_id: str = Field(min_length=1, max_length=128)
    npc_id: str = Field(min_length=1, max_length=128)
    dialogue_id: str = Field(min_length=1, max_length=128)
    locale: str = Field(default="zh", min_length=1, max_length=32)

    @field_validator("request_id", "npc_id", "dialogue_id", "locale")
    @classmethod
    def strip_non_empty_values(cls, value: str) -> str:
        clean_value = value.strip()
        if not clean_value:
            raise ValueError("value must contain non-whitespace characters")
        return clean_value


class VoiceAnalyzeResponse(BaseModel):
    ok: Literal[True] = True
    request_id: str
    dialogue_id: str
    transcript: str = Field(min_length=1)
    emotion: VoiceEmotion
    emotion_label: str = ""
    emotion_applied: bool
    duration_seconds: float = Field(ge=0)
    model_provider: str
    model_name: str
    model_fallback_used: Literal[False] = False
    usage: dict

    @field_validator("transcript")
    @classmethod
    def strip_transcript(cls, value: str) -> str:
        clean_value = value.strip()
        if not clean_value:
            raise ValueError("transcript must contain non-whitespace characters")
        return clean_value

    @model_validator(mode="after")
    def validate_emotion_projection(self):
        expected_label = QWEN_NATIVE_VOICE_EMOTIONS.get(self.emotion, "")
        if self.emotion_label != expected_label:
            raise ValueError("emotion_label must match the native emotion mapping")
        if self.emotion_applied != bool(expected_label):
            raise ValueError("emotion_applied must match whether a native emotion exists")
        return self


class VoiceAnalyzeErrorResponse(BaseModel):
    ok: Literal[False] = False
    request_id: str = ""
    error_code: str
    message: str
    fallback_used: Literal[False] = False
    details: list = Field(default_factory=list)
    usage: dict | None = None
