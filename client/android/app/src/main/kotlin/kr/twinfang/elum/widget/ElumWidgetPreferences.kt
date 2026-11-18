package kr.twinfang.elum.widget

import android.content.Context
import android.util.Log
import kr.twinfang.elum.lockscreen.LockScreenSnapshot
import org.json.JSONArray
import org.json.JSONObject

/**
 * 홈 위젯 전용 저장소: 오늘 일과 요약 JSON, 위젯 체크 대기열·체크한 카드·마지막 체크 시각 (#1465)
 * 잠금화면 저장소와 분리 (잠금화면은 Android 출시 전이라 Dart 가 그쪽으로 보내지 않음, #1420)
 * 키 이름은 iOS App Group 과 같음 (설계 2026-11-18-widget-card-check)
 */
class ElumWidgetPreferences(context: Context) {
    private val preferences =
        context.applicationContext.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    // Dart LockScreenSnapshot.toJsonString (null 이면 지움)
    var snapshotJson: String?
        get() = preferences.getString(KEY_SNAPSHOT_JSON, null)
        set(value) {
            // commit: 바로 뒤 위젯 갱신이 새 값을 읽게
            val editor = preferences.edit()
            if (value == null) editor.remove(KEY_SNAPSHOT_JSON) else editor.putString(KEY_SNAPSHOT_JSON, value)
            editor.commit()
        }

    /** 저장된 요약 (없거나 깨졌으면 null) */
    val snapshot: LockScreenSnapshot?
        get() = LockScreenSnapshot.parse(snapshotJson)

    /** 체크 대기열 (앱이 takeWidgetChecks 로 꺼냄, 깨졌으면 비우고 빈 목록) */
    val checkOutbox: List<ElumWidgetCheck>
        get() {
            val json = preferences.getString(KEY_CHECK_OUTBOX, null) ?: return emptyList()
            return try {
                val array = JSONArray(json)
                (0 until array.length()).mapNotNull { ElumWidgetCheck.fromJson(array.optJSONObject(it)) }
            } catch (error: Exception) {
                Log.w(ElumWidgets.LOG_TAG, "[widget check] outbox cleared : corrupt json ${error.javaClass.simpleName}")
                preferences.edit().remove(KEY_CHECK_OUTBOX).commit()
                emptyList()
            }
        }

    /** 위젯 표시용 체크한 카드 id (앱이 새 요약을 보내면 비움, 깨졌으면 비우고 빈 집합) */
    val checkedCardIds: Set<String>
        get() {
            val json = preferences.getString(KEY_CHECKED_CARD_IDS, null) ?: return emptySet()
            return try {
                val array = JSONArray(json)
                (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotEmpty) }.toSet()
            } catch (error: Exception) {
                Log.w(ElumWidgets.LOG_TAG, "[widget check] checked ids cleared : corrupt json ${error.javaClass.simpleName}")
                clearCheckedCardIds()
                emptySet()
            }
        }

    // 마지막 위젯 체크 시각 (epoch 밀리초, 없으면 0)
    val lastCheckAtMillis: Long
        get() = preferences.getLong(KEY_LAST_CHECK_AT_MILLIS, 0L)

    /** 체크 1건 기록: 대기열 추가(같은 일과+카드는 한 번) + 체크한 카드 + 마지막 시각 (한 번에 commit) */
    fun recordCheck(check: ElumWidgetCheck) {
        val outbox = checkOutbox
        val isDuplicate = outbox.any { it.routineId == check.routineId && it.cardId == check.cardId }
        val nextOutbox = if (isDuplicate) outbox else outbox + check
        val nextCheckedCardIds = checkedCardIds + check.cardId
        preferences.edit()
            .putString(KEY_CHECK_OUTBOX, JSONArray(nextOutbox.map { it.toJson() }).toString())
            .putString(KEY_CHECKED_CARD_IDS, JSONArray(nextCheckedCardIds.toList()).toString())
            .putLong(KEY_LAST_CHECK_AT_MILLIS, check.checkedAtMillis)
            .commit()
    }

    /** 대기열 꺼내고 비우기 > JSON 배열 문자열 (없으면 "[]") */
    fun takeCheckOutboxJson(): String {
        val outbox = checkOutbox
        preferences.edit().remove(KEY_CHECK_OUTBOX).commit()
        return JSONArray(outbox.map { it.toJson() }).toString()
    }

    fun clearCheckedCardIds() {
        preferences.edit().remove(KEY_CHECKED_CARD_IDS).commit()
    }

    companion object {
        private const val FILE_NAME = "elum_widget"
        private const val KEY_SNAPSHOT_JSON = "snapshotJson"
        // JSON 배열 [{routineId, cardId, dateKey, checkedAtMillis}]
        private const val KEY_CHECK_OUTBOX = "elum.widget.checkOutbox"
        // JSON 배열 ["cardId", ...]
        private const val KEY_CHECKED_CARD_IDS = "elum.widget.checkedCardIds"
        private const val KEY_LAST_CHECK_AT_MILLIS = "elum.widget.lastCheckAtMillis"
    }
}

/** 위젯에서 체크한 카드 1건 (대기열 항목, 키 이름은 Dart·iOS 와 같음) */
data class ElumWidgetCheck(
    val routineId: String,
    val cardId: String,
    // yyyy-MM-dd (앱이 오늘 아니면 버림)
    val dateKey: String,
    val checkedAtMillis: Long,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("routineId", routineId)
        .put("cardId", cardId)
        .put("dateKey", dateKey)
        .put("checkedAtMillis", checkedAtMillis)

    companion object {
        // 필수값 없으면 null (항목 하나만 버림)
        fun fromJson(json: JSONObject?): ElumWidgetCheck? {
            if (json == null) return null
            val routineId = json.optString("routineId").takeIf { it.isNotEmpty() } ?: return null
            val cardId = json.optString("cardId").takeIf { it.isNotEmpty() } ?: return null
            return ElumWidgetCheck(
                routineId = routineId,
                cardId = cardId,
                dateKey = json.optString("dateKey"),
                checkedAtMillis = json.optLong("checkedAtMillis", 0L),
            )
        }
    }
}
