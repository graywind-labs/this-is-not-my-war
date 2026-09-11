extends RefCounted
## Keep the approved cover entry point and hierarchy stable.

const ShellFinish := preload("res://scripts/presentation/buildings/MainHallShellFinish.gd")

static func install(hall: Node3D) -> void:
	ShellFinish.install(hall)
