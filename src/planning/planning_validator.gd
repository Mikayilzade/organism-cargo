class_name PlanningValidator
extends RefCounted

const PLACEMENT_REASON_ORDER: Array[String] = [
	"overlap",
	"blocked",
	"outside hold",
	"forbidden orientation",
	"wrong zone",
	"fixture required",
	"unsupported link",
	"exceeded support resource",
]

static func validate(structural_facts: Dictionary) -> Dictionary:
	var mandatory_manifest_placed: bool = bool(structural_facts.get("mandatory_manifest_placed", false))
	var overlap_free: bool = bool(structural_facts.get("overlap_free", false))
	var blocked_free: bool = bool(structural_facts.get("blocked_free", false))
	var in_bounds: bool = bool(structural_facts.get("in_bounds", false))
	var orientations_valid: bool = bool(structural_facts.get("orientations_valid", false))
	var zones_valid: bool = bool(structural_facts.get("zones_valid", false))
	var fixtures_valid: bool = bool(structural_facts.get("fixtures_valid", false))
	var links_valid: bool = bool(structural_facts.get("links_valid", false))
	var support_resources_valid: bool = bool(structural_facts.get("support_resources_valid", false))
	var structural_prerequisites_met: bool = bool(structural_facts.get("structural_prerequisites_met", false))

	var reasons: Array[String] = []
	if not overlap_free:
		reasons.append("overlap")
	if not blocked_free:
		reasons.append("blocked")
	if not in_bounds:
		reasons.append("outside hold")
	if not orientations_valid:
		reasons.append("forbidden orientation")
	if not zones_valid:
		reasons.append("wrong zone")
	if not fixtures_valid:
		reasons.append("fixture required")
	if not links_valid:
		reasons.append("unsupported link")
	if not support_resources_valid:
		reasons.append("exceeded support resource")

	var structural_legal: bool = (
		mandatory_manifest_placed
		and overlap_free
		and blocked_free
		and in_bounds
		and orientations_valid
		and zones_valid
		and fixtures_valid
		and links_valid
		and support_resources_valid
		and structural_prerequisites_met
	)
	return {
		"structural_legal": structural_legal,
		"reasons": reasons,
		"mandatory_manifest_placed": mandatory_manifest_placed,
		"structural_prerequisites_met": structural_prerequisites_met,
	}
