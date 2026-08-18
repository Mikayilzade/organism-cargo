extends Control

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")

const CORE_CONTENT_PATHS: Dictionary = {
	&"body_plans": "res://content/body_plans",
	&"campaign": "res://content/campaign",
	&"challenges": "res://content/challenges",
	&"contracts": "res://content/contracts",
	&"hazards": "res://content/hazards",
	&"holds": "res://content/holds",
	&"routes": "res://content/routes",
	&"species": "res://content/species",
	&"supports": "res://content/supports",
	&"traits": "res://content/traits",
}

var _bootstrap_service: AppBootstrapService

func _ready() -> void:
	# Presentation remains non-authoritative. The persistent shell owns only the
	# composition root; deterministic systems and validated content live outside Nodes.
	_bootstrap_service = AppBootstrapServiceScript.new()
	var result: Dictionary = _bootstrap_service.boot(CORE_CONTENT_PATHS)
	if not result["ok"]:
		print("Organism Cargo bootstrap blocked: %s" % String(result["error"]))
		return
	print("Organism Cargo bootstrap ready: content=%s state=%s" % [
		String(result["content_version"]),
		str(_bootstrap_service.state_machine().current_state()),
	])
