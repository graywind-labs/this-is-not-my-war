import os
from dataclasses import dataclass


@dataclass(frozen=True)
class ModelAdapterConfig:
    provider: str
    api_key: str | None


class ModelAdapter:
    """Minimal provider boundary; concrete LLM calls will be added in later tasks."""

    def __init__(self, config: ModelAdapterConfig | None = None) -> None:
        self.config = config or ModelAdapterConfig(
            provider=os.getenv("LLM_PROVIDER", "deepseek"),
            api_key=os.getenv("LLM_API_KEY"),
        )

    def is_configured(self) -> bool:
        return bool(self.config.api_key)
