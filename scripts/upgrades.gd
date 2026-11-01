extends RefCounted
## Eighteen one-point nodes; twelve campaign points cannot buy everything.
const MAX_RANK := 6
const TITLES := ["BOOTS", "BLOWER", "BATTERY"]
const NAMES := [
	["Trail soles", "Sure footing", "Light steps", "Quick stride", "Deep grip", "Fleet feet"],
	["Torque fan", "Flow guide", "Wide nozzle", "High output", "Air shaper", "Storm fan"],
	["Smart cell", "Larger pack", "Fast charge", "Light casing", "Reserve cell", "Long haul"],
]
const STRATEGIES := ["Move faster and resist leaf-pile drag.", "More lift and reach, with more weight and energy use.", "Longer bursts and faster charging, with a little extra weight."]
static func description(branch: int, rank: int) -> String:
	if branch == 0:
		return "Rank %d: running speed +%d%%; maximum pile slowdown %d%%. A light-footed kit helps you carry a heavy fan." % [rank, rank * 5, roundi((0.32 - rank * 0.025) * 100)]
	if branch == 1:
		return "Rank %d: blower force +%d%% and a wider cone. Fan weight +%d%%; energy draw +%d%%. Trade agility for control." % [rank, rank * 15, rank * 5, roundi(rank * 7.5)]
	return "Rank %d: capacity +%d%%, energy draw −%d%%, and faster recharge. Pack weight +%d%%. Keep the wind running longer." % [rank, rank * 10, roundi(rank * 4.5), roundi(rank * 0.5)]
