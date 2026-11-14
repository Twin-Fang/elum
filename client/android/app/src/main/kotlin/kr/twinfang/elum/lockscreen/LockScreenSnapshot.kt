package kr.twinfang.elum.lockscreen

import org.json.JSONObject

/**
 * 오늘 일과 요약 (서비스·알림이 읽는 부분만): 날짜, 끝낸 수/전체 수, 이룸이 카드 띄울 시간대
 * 원본 JSON 은 Dart LockScreenSnapshot.toJson (키 이름 같게)
 */
data class LockScreenSnapshot(
    val dateKey: String,
    val doneCount: Int,
    val totalCount: Int,
    // 이룸이 카드 띄울 시간대 목록 (epoch 밀리초 [시작, 끝])
    val activeWindows: List<LongRange>,
    val hasElumiCard: Boolean,
) {
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
                    hasElumiCard = root.optJSONObject("elumiCard") != null,
                )
            } catch (_: Exception) {
                null
            }
        }
    }
}
