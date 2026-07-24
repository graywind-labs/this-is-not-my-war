# Backend Schemas

T0601 creates Pydantic models for backend AI request and response payloads. These schemas are data contracts only; they do not call a real model and do not perform game authority changes.

Current schema groups:

- `common.py`: shared game time, request metadata, NPC context, memory summaries and action candidates.
- `npc_ai.py`: dialogue, dialogue/action-failure plan-revision judgement, daily plan, selected-hour plan revision, battle judgement, daily reflection, knowledge graph update, proactive intention and player strategy classification payloads.
- `StationSceneContext` is the single top-level world-context block for station-aware requests. It requires a setting summary plus non-empty resident, building, work-mode action, five-item public basic-resource and station-rule lists. Public resources are exactly grain, meal, wood, stone and iron; per-request allowed actions/decisions and runtime systems remain authoritative.

T0025 plan contracts:

- `PlanActionKind` is shared from `common.py`; current plan-capable kinds include work, eat, sleep, train, pray, visit, chat, targeted assists, seek-guard intent, avoid / escape intent and idle.
- `ActionCandidate.action_kind` identifies the exact kind allowed for that candidate. Plan responses must preserve the candidate's action, kind, target and location combination. After Schema validation, the HTTP layer may canonicalize only a redundant kind from one uniquely matching non-idle candidate (or the fixed idle contract) and reports it in `model_normalizations`; it never changes action, target or location.
- `PlanItem.dialogue_goal` carries a short opening request for `talk_to_npc` and `seek_guard_officer`.
- `PlanRevisionJudgementRequest` branches on `trigger_kind` and inherits the same station-aware character context used by planning and revision. Both branches carry `station_context`, `npc` (including current order, short-term memory and `long_term_memory={knowledge_graph, diary}`), allowed actions, current building/resource states and baseline `current_plan`; `dialogue` adds the completed conversation and session metadata, while `action_failure` adds the authoritative failed item, type/summary/context and work-count constraints. `plan_item_superseded` represents a pending daily-plan action replaced by the current stage. `PlanRevisionJudgementResponse.revision_hours` may be empty; empty means zero stages need revision, while `needs_revision` must match whether the array is non-empty. The old `DialoguePlanRevisionJudgement*` names remain compatibility aliases.
- `PlanRevisionRequest` carries structured failure context, work-count constraints, `revision_scope=selected_hours`, a non-empty sorted `revision_hours` array, past work count and the remaining-work minimum. `PlanRevisionResponse.revised_items` must cover exactly those requested hours—no omissions, additions or duplicates.
- For `dialogue_kind=npc_npc`, business validation requires `replyer_id` to equal the requested target NPC and `response_kind=reply_to_npc`; player and escape-intervention requests require `reply_to_player`.

T0603 dialogue contract:

- `NPCDialogueRequest` is centered on the target NPC: `npc_id`, `npc_name`, `npc_setting`, `npc_state`, `short_memory`, `long_memory` and `location_context`.
- T0041 requires a non-empty `allowed_actions` list on every dialogue request. Godot builds it with the same dynamic candidate function used by daily planning; dialogue treats it only as the target NPC's capability boundary and never as an executed plan.
- `NPCIdentity` and dialogue `npc_setting` carry the broad `speech_style` together with personality, desires, fears, and boundaries. T0061 removed fixed `signature_lines` examples from profiles, schemas, and formal payloads so later dialogue is not constrained to a small set of sample sentences.
- The current speaker is described separately with `speaker_name`, `speaker_text` and `speaker_context`; the guard officer's display name is always `守备官`.
- `dialogue_state.visibility` is `private` or `local_public`; this only guides Godot event routing and does not let the backend write memory. T1201 adds `interaction_context` and `battlefield_context` for wartime dialogue.
- T0029 adds `dialogue_phase`: an NPC-NPC `invitation` uses `current_round=0` and asks the target to accept or reject before Godot interrupts either participant. T0030 makes `conversation` start at round 1 without a hard cap: `max_rounds=0` is the no-limit sentinel, while `soft_round_threshold` and non-empty `soft_round_guidance` tell the model when to end naturally.
- `NPCDialogueResponse` returns `replyer_id`, `reply_text`, `response_kind`, `invitation_result`, `recruitment_result`, `wartime_reaction` and `should_end_dialogue`. Invitation responses must choose `accept` or `reject`; all non-invitation responses use `not_applicable`.

Authority boundary:

- Godot remains responsible for HP, resources, movement, building state, combat damage and event writes.
- Backend schemas describe NPC intent, text, subjective judgement, plan suggestions and memory/reflection output.
- Any text visible to NPCs should refer to the player as `守备官`; stable IDs may use `guard_officer`.
