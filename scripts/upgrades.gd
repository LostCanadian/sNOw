extends RefCounted
## Eighteen one-point nodes; twelve campaign points cannot buy everything.
const MAX_RANK := 6
const TITLES := ["BOOTS", "BLOWER", "BATTERY"]
const NAMES := [
	["Trail soles", "Sure footing", "Light steps", "Quick stride", "Deep grip", "Fleet feet"],
	["Torque fan", "Leaflift surge", "Wide nozzle", "High output", "Air shaper", "Storm fan"],
	["Smart cell", "Larger pack", "Quick recovery", "Cell buffer", "Surge cell", "Long haul"],
]
const STRATEGIES := ["Move faster and resist leaf-pile drag.", "More lift and reach, with more weight and energy use.", "Longer bursts and faster charging, with a little extra weight."]
static func description(branch: int, rank: int) -> String:
	if branch == 0:
		return "Rank %d: running speed +%d%%; maximum pile slowdown %d%%. A light-footed kit helps you carry a heavy fan." % [rank, rank * 5, roundi((0.32 - rank * 0.025) * 100)]
	if branch == 1:
		var detail := "Rank %d: force +%d%%, wider cone. Fan weight +%d%%; draw +%d%%." % [rank, rank * 15, rank * 5, roundi(rank * 7.5)]
		return detail + ("\nLeaflift Surge (E): airborne tumble lifts ground/air leaves. 36s recharge." if rank >= 2 else "\nRank 2 unlocks Leaflift Surge.")
	var detail := "Rank %d: capacity +%d%%, draw −%d%%, faster charging. Pack weight +%d%%." % [rank, rank * 10, roundi(rank * 4.5), roundi(rank * 0.5)]
	return detail + ("\nSurge recharge: 26s." if rank >= 5 else ("\nSurge recharge: 31s." if rank >= 3 else "\nRanks 3 and 5 shorten Surge recharge."))
