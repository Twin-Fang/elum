package kr.twinfang.elum.lockscreen

import org.json.JSONObject

/**
 * 오늘 일과 요약 (잠금화면 서비스·알림·홈 위젯이 읽는 부분): 날짜, 끝낸 수/전체 수, 이룸이 카드, 시간대, 이름·연속·별
 * 원본 JSON 은 Dart LockScreenSnapshot.toJson (키 이름 같게, 없는 키는 기본값)
 */
data class LockScreenSnapshot(
    val dateKey: String,
    val doneCount: Int,
    val totalCount: Int,
    // 이룸이 카드 띄울 시간대 목록 (epoch 밀리초 [시작, 끝])
    val activeWindows: List<LongRange>,
    // 기기 역할: guardian 보호자, elumi 이룸이 (없으면 guardian)
    val mode: String = LockScreenPreferences.MODE_GUARDIAN,
    val nextRoutineTitle: String? = null,
    val elumiCard: LockScreenElumiCard? = null,
    // 위젯 머리 이름·연속 일수·별 수 (#1465, 옛 요약에는 없음 > null·0)
    val elumiName: String? = null,
    val streakDays: Int = 0,
    val starCount: Int = 0,
) {
    val hasElumiCard: Boolean
        get() = elumiCard != null

    val isElumiMode: Boolean
        get() = mode == LockScreenPreferences.MODE_ELUMI

    val isToday: Boolean
        get() = dateKey == LockScreenPreferences.today()

    /** 지금이 이룸이 카드 시간대 안인가 */
    fun isInActiveWindow(nowMillis: Long): Boolean = activeWindows.any { nowMillis in it }

    companion object {
        fun parse(json: String?): LockScreenSnapshot? {
            if (json.isNullOrEmpty()) return null
            return try {
                val root = JSONObject(json)
                val windowArray = root.optJSONArray("activeWindows")
                val windows = mutableListOf<LongRange>()
                if (windowArray != null) {
                    for (index in 0 until windowArray.length()) {
                        val window = windowArray.optJSONArray(index) ?: continue
                        if (window.length() < 2) continue
                        windows.add(window.optLong(0)..window.optLong(1))
                    }
                }
                LockScreenSnapshot(
                    dateKey = root.optString("dateKey"),
                    doneCount = root.optInt("doneCount"),
                    totalCount = root.optInt("totalCount"),
                    activeWindows = windows,
                    mode = root.optStringOrNull("mode") ?: LockScreenPreferences.MODE_GUARDIAN,
                    nextRoutineTitle = root.optStringOrNull("nextRoutineTitle"),
                    elumiCard = LockScreenElumiCard.parse(root.optJSONObject("elumiCard")),
                    elumiName = root.optStringOrNull("elumiName"),
                    streakDays = root.optInt("streakDays", 0).coerceAtLeast(0),
                    starCount = root.optInt("starCount", 0).coerceAtLeast(0),
                )
            } catch (_: Exception) {
                null
            }
        }
    }
}

/**
 * 이룸이 지금 할 카드 한 장 (Dart LockScreenElumiCard, routineId 없으면 카드 없음으로 봄)
 * 위젯 체크용 cardId·남은 수·다음 카드 (#1465 2단계, 옛 요약에는 없음 > 빈 값·0·빈 목록)
 */
data class LockScreenElumiCard(
    val routineId: String,
    val routineTitle: String,
    val cardText: String,
    // 기기에 받아 둔 카드 그림 파일 절대 경로 (없으면 null)
    val imageFilePath: String?,
    val cardId: String = "",
    // 이 일과에서 남은 카드 수 (지금 카드 포함, 0 이면 모름)
    val remainingCount: Int = 0,
    // 지금 카드 다음 카드 (최대 2장)
    val upcomingCards: List<LockScreenUpcomingCard> = emptyList(),
) {
    companion object {
        // 요약에 담기는 다음 카드 최대 장수 (Dart 와 같음)
        private const val MAX_UPCOMING_CARD_COUNT = 2

        fun parse(json: JSONObject?): LockScreenElumiCard? {
            if (json == null) return null
            val routineId = json.optStringOrNull("routineId") ?: return null
            return LockScreenElumiCard(
                routineId = routineId,
                routineTitle = json.optStringOrNull("routineTitle").orEmpty(),
                cardText = json.optStringOrNull("cardText").orEmpty(),
                imageFilePath = json.optStringOrNull("imageFilePath"),
                cardId = json.optStringOrNull("cardId").orEmpty(),
                remainingCount = json.optInt("remainingCount", 0).coerceAtLeast(0),
                upcomingCards = parseUpcomingCards(json),
            )
        }

        // cardId 없는 항목은 건너뜀
        private fun parseUpcomingCards(json: JSONObject): List<LockScreenUpcomingCard> {
            val array = json.optJSONArray("upcomingCards") ?: return emptyList()
            val cards = mutableListOf<LockScreenUpcomingCard>()
            for (index in 0 until array.length()) {
                val cardJson = array.optJSONObject(index) ?: continue
                val cardId = cardJson.optStringOrNull("cardId") ?: continue
                cards.add(
                    LockScreenUpcomingCard(
                        cardId = cardId,
                        cardText = cardJson.optStringOrNull("cardText").orEmpty(),
                        imageFilePath = cardJson.optStringOrNull("imageFilePath"),
                    ),
                )
                if (cards.size >= MAX_UPCOMING_CARD_COUNT) break
            }
            return cards
        }
    }
}

/** 지금 카드 다음 카드 한 장 (위젯이 앱 없이 넘겨 보여 줌, 그림 id 는 Android 에서 안 씀) */
data class LockScreenUpcomingCard(
    val cardId: String,
    val cardText: String,
    val imageFilePath: String?,
)

// JSON null·빈 문자열 > null (optString 은 null 을 "null" 문자열로 돌려줌)
private fun JSONObject.optStringOrNull(key: String): String? {
    if (isNull(key)) return null
    return optString(key).takeIf { it.isNotEmpty() }
}
