# Backend Schemas

T0601 creates Pydantic models for backend AI request and response payloads. These schemas are data contracts only; they do not call a real model and do not perform game authority changes.

Current schema groups:

- `common.py`: shared game time, request metadata, NPC context, memory summaries and action candidates.
- `npc_ai.py`: dialogue, daily plan, plan revision, battle judgement, daily reflection, knowledge graph update, proactive intention and player strategy classification payloads.

T0603 dialogue contract:

- `NPCDialogueRequest` is centered on the target NPC: `npc_id`, `npc_name`, `npc_setting`, `npc_state`, `short_memory`, `long_memory` and `location_context`.
- The current speaker is described separately with `speaker_name`, `speaker_text` and `speaker_context`; the guard officer's display name is always `守备官`.
- `dialogue_state.visibility` is `private` or `local_public`; this only guides Godot event routing and does not let the backend write memory.
- `NPCDialogueResponse` returns `replyer_id`, `reply_text`, `response_kind`, `recruitment_result` and `should_end_dialogue`.

Authority boundary:

- Godot remains responsible for HP, resources, movement, building state, combat damage and event writes.
- Backend schemas describe NPC intent, text, subjective judgement, plan suggestions and memory/reflection output.
- Any text visible to NPCs should refer to the player as `守备官`; stable IDs may use `guard_officer`.
