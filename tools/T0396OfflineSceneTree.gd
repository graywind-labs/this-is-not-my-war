extends SceneTree

## Base for generated copies of existing NON-LLM regression scripts only.
## Parent _init runs before fixture _init, including tests that instantiate Main
## immediately. Do not use this runner to claim any LLM behavior is validated.
func _init() -> void:
	node_added.connect(_block_test_transport)


func _block_test_transport(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/systems/CombatSystem.gd" and OS.get_cmdline_user_args().has("--baseline-combat"):
		node.set_script(load("res://artifacts/performance/t0396/regression_baseline/CombatSystem.gd"))
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/systems/LLMBridge.gd":
		node.set("_transport_shutdown_requested", true)
		# Also guard any synchronous health/legacy endpoints; no provider traffic.
		node.set("backend_base_url", "http://127.0.0.1:1")
