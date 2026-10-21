extends DungeonRoom3D
## This room's structural geometry belongs to greybox_builder. Reuse the original
## room trigger, streaming, spawn validation and runtime state without old content.
func _build_shell() -> void:
	set_meta("shell_owner", "greybox_builder")

func _build_content() -> void:
	set_meta("content_profile", "minimal_prototypes")
