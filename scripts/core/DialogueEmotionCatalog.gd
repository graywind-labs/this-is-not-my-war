class_name DialogueEmotionCatalog
extends RefCounted

const DEFAULT_ID := "none"
const HOLD_SECONDS := 5.0
const FADE_SECONDS := 0.75
const EMOTION_ORDER: Array[String] = [
	"none",
	"happy",
	"relieved",
	"angry",
	"sad",
	"afraid",
	"surprised",
	"confused",
	"determined"
]
const DEFINITIONS := {
	"none": {"label": "无明显情绪", "emoji": "…"},
	"happy": {"label": "开心", "emoji": "😊"},
	"relieved": {"label": "放松", "emoji": "😌"},
	"angry": {"label": "愤怒", "emoji": "😠"},
	"sad": {"label": "难过", "emoji": "😢"},
	"afraid": {"label": "害怕", "emoji": "😨"},
	"surprised": {"label": "惊讶", "emoji": "😮"},
	"confused": {"label": "困惑", "emoji": "😕"},
	"determined": {"label": "坚定", "emoji": "✊"}
}
const ALIASES := {
	"": "none",
	"neutral": "none",
	"calm": "none",
	"steady": "none",
	"wary": "none",
	"平静": "none",
	"谨慎": "none",
	"无": "none",
	"无明显情绪": "none",
	"开心": "happy",
	"高兴": "happy",
	"joyful": "happy",
	"pleased": "happy",
	"放松": "relieved",
	"释然": "relieved",
	"relaxed": "relieved",
	"愤怒": "angry",
	"生气": "angry",
	"hostile": "angry",
	"难过": "sad",
	"悲伤": "sad",
	"upset": "sad",
	"害怕": "afraid",
	"恐惧": "afraid",
	"fearful": "afraid",
	"shaken": "afraid",
	"tense": "afraid",
	"惊讶": "surprised",
	"震惊": "surprised",
	"shocked": "surprised",
	"困惑": "confused",
	"疑惑": "confused",
	"uncertain": "confused",
	"坚定": "determined",
	"坚决": "determined",
	"resolved": "determined",
	"resolute": "determined"
}


static func normalize(raw_emotion: String) -> String:
	var clean_emotion := raw_emotion.strip_edges().to_lower()
	if DEFINITIONS.has(clean_emotion):
		return clean_emotion
	return str(ALIASES.get(clean_emotion, DEFAULT_ID))


static func get_presentation(raw_emotion: String) -> Dictionary:
	var emotion_id := normalize(raw_emotion)
	var definition: Dictionary = DEFINITIONS.get(emotion_id, DEFINITIONS[DEFAULT_ID])
	return {
		"emotion_id": emotion_id,
		"emotion_label": str(definition.get("label", "无明显情绪")),
		"emoji": str(definition.get("emoji", "…")),
		"hold_seconds": HOLD_SECONDS,
		"fade_seconds": FADE_SECONDS
	}


static func get_all_presentations() -> Array[Dictionary]:
	var presentations: Array[Dictionary] = []
	for emotion_id in EMOTION_ORDER:
		presentations.append(get_presentation(emotion_id))
	return presentations
