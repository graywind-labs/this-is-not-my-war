extends Node

signal resource_changed(resource_id: String, amount: int)
signal hour_started(day: int, hour: int)
signal building_clicked(building_id: String)
signal npc_clicked(npc_id: String)
signal npc_state_changed(npc_id: String)
signal public_event_added(event: Dictionary)
