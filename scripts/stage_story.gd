extends RefCounted
## The caretaker keeps this last warm tree alive as winter approaches the valley.
const DURATION := 3.1
const CHAPTERS := [
	["The First Leaf", "The last warm tree sheds a leaf.\nYou lift it back into the branches.", "The leaves hold for another week.\nA colder breeze finds the lane."],
	["An Uneasy Rustle", "A cold draft shakes the branches.\nKeep their colour a little longer.", "The tree still shelters the lane.\nTonight, the windows mist over."],
	["Borrowed Warmth", "Frost has reached the fields.\nGrass stays warm beneath this tree.", "You have kept a little warmth here.\nSomething under the roots stirs."],
	["Knots in the Grain", "Old marks show in the bare bark.\nSomeone stood here before you.", "Another frost kept at bay.\nCold winds gather beyond the ridge."],
	["A Longer Shadow", "The rain carries a sharper chill.\nThe branches need your help again.", "The tree keeps its autumn colours.\nThe evenings are getting shorter."],
	["What the Roots Remember", "The village sleeps in moonlight.\nYou keep watch by the old trunk.", "The lane stays clear of frost.\nThe distant hills have turned white."],
	["The Last Cricket", "One cricket sings beneath the roots.\nKeep a roof of leaves above it.", "The cricket still sings.\nTonight, the branches answer."],
	["Porch Lights", "Storm clouds hide the moon.\nYou work by the village porch lights.", "Another week of shelter won.\nThe cold is closer now."],
	["A Quiet Bargain", "You left a scarf beside the trunk.\nIn the morning, it was warm.", "The tree holds back another frost.\nThe wind whispers your name."],
	["The Narrowing Sky", "Fewer leaves catch the light.\nEach leaf keeps winter waiting.", "Another week stolen from the cold.\nThe path to the village stays open."],
	["Before the Hush", "Rain freezes on the distant fences.\nHere, the last branches still bend.", "The village windows still glow.\nBeyond the ridge, the wind rises."],
	["One Last Week", "One last week of autumn colour.\nKeep the cold from these branches.", "Twelve weeks of warmth kept.\nNow the North Wind wants the tree."],
	["The North Wind", "The North Wind has found the tree.\nHold its last leaves against the cold.", "A flower opens in the frozen grass.\nFor now, the valley can breathe."],
]
static func chapter(week: int) -> Array:
	return CHAPTERS[clampi(week - 1, 0, CHAPTERS.size() - 1)]
