extends RefCounted
## Cosmetic choices derive from the persisted campaign ID, never the gameplay RNG.
## The fixed weekly moods keep both opening weeks and the finale in daylight.
const DAYS := [
	["Sunlit clearing", "day", "sun", 0.0, 0.08, 0.25],
	["Breezy afternoon", "day", "sun", 0.0, 0.05, 0.65],
	["Silver skies", "day", "cloud", 0.0, 0.18, 0.45],
	["Amber evening", "dusk", "clear", 0.0, 0.16, 0.28],
	["Rain on the valley", "day", "rain", 0.55, 0.36, 0.48],
	["Moonlit hush", "night", "clear", 0.0, 0.18, 0.22],
	["A golden break", "day", "sun", 0.0, 0.10, 0.42],
	["Distant night storm", "night", "storm", 0.85, 0.38, 0.78],
	["Mist in the meadow", "day", "fog", 0.0, 0.70, 0.20],
	["Copper twilight", "dusk", "clear", 0.0, 0.22, 0.48],
	["November rain", "day", "rain", 0.70, 0.42, 0.65],
	["Last autumn sunlight", "day", "sun", 0.0, 0.20, 0.55],
	["The North Wind", "day", "storm", 0.30, 0.42, 1.0],
]
static func choose(campaign_id: String, week: int) -> Dictionary:
	var stage:=clampi(week,1,13)
	var day:Array=DAYS[stage-1]
	var rng:=RandomNumberGenerator.new()
	rng.seed=(campaign_id+":world:"+str(stage)).sha256_text().substr(0,8).hex_to_int()
	var phase:=rng.randi_range(0,7)
	return {"week":stage,"name":day[0],"time":day[1],"weather":day[2],"rain":day[3],"fog":day[4],"wind":day[5],
		"moon":phase,"moon_turn":rng.randf_range(-0.35,0.35),"rare":day[1]=="night" and phase==0,
		"sun":Vector2(rng.randf_range(35,115) if stage%2 else rng.randf_range(240,310),rng.randf_range(80,125)),
		"seed":rng.seed}
