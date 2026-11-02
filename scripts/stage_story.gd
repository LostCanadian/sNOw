extends RefCounted
## Brief, suggestive interludes. The tree's role is never explained outright.
const DURATION := 3.1
const CHAPTERS := [
	["The First Leaf", "One leaf lets go.\nYou have other plans.", "Autumn holds.\nA colder breeze finds the lane."],
	["An Uneasy Rustle", "The branches rustle.\nThere is no wind.", "The valley stays awake.\nTonight, the windows mist over."],
	["Borrowed Warmth", "The valley wears a frost.\nThis patch of grass does not.", "A little warmth remains.\nIt will need watching."],
	["Knots in the Grain", "Old marks show in the bark.\nNobody remembers carving them.", "Another frost kept at bay.\nSomething stirs beyond the ridge."],
	["A Longer Shadow", "The houses fall into shade.\nOne shadow points the other way.", "The light lingers.\nThe evenings are getting shorter."],
	["What the Roots Remember", "The roots reach beneath the road.\nThe road is much younger.", "The lane stays clear.\nThe hills have turned white."],
	["The Last Cricket", "A cricket sings under the roots.\nJust one.", "The cricket still sings.\nThe branches answer after dark."],
	["Porch Lights", "Porch lights blink on early.\nYou keep working.", "Another week of amber.\nThe clouds stop moving east."],
	["A Quiet Bargain", "You leave a scarf by the trunk.\nBy morning, it is warm.", "Winter waits outside.\nThe wind begins to whisper."],
	["The Narrowing Sky", "Clouds gather over the ridge.\nNot a leaf moves.", "Another week stolen from the cold.\nKeep the path open."],
	["Before the Hush", "The village is quiet.\nSomething is listening.", "The windows still glow.\nBeyond them, a pale shape waits."],
	["One Last Week", "The last warm colours hold.\nSo do you.", "Twelve weeks kept.\nThe North Wind wants an answer."],
	["The North Wind", "It followed the falling leaves.\nNow it is here.", "The first flower opens.\nNobody asks why."],
]
static func chapter(week: int) -> Array:
	return CHAPTERS[clampi(week - 1, 0, CHAPTERS.size() - 1)]
