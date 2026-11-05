extends SceneTree
func _initialize() -> void:
	var decoded: Dictionary = JSON.parse_string('{"schemaVersion":1,"profileSchema":2,"files":{}}')
	print("METRIC AMD_WIRE schema_type=%d profile_type=%d equality=%s array_membership=%s files_dictionary=%s" % [typeof(decoded["schemaVersion"]),typeof(decoded["profileSchema"]),str(decoded["profileSchema"] == 2),str(decoded["profileSchema"] in [1,2]),str(decoded["files"] is Dictionary)])
	quit()
