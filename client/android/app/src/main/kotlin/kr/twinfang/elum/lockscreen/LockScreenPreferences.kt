package kr.twinfang.elum.lockscreen

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 잠금화면 카드 설정 원본 (네이티브 SharedPreferences): 켜짐·모드·간격, 표시 기록, 쉬기, 오늘 일과 요약, 소개 노출 기록
 * Dart 는 채널로만 읽고 씀 (앱 엔진·잠금화면 엔진·서비스가 같은 값을 보게)
 */
class LockScreenPreferences(context: Context) {
    private val preferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    var isEnabled: Boolean
        get() = preferences.getBoolean(KEY_IS_ENABLED, false)
        set(value) = preferences.edit().putBoolean(KEY_IS_ENABLED, value).apply()

    // 카드 종류: guardian 보호자 진행 카드, elumi 이룸이 지금 할 카드 (켤 때 기기 역할로 정함)
    var mode: String
        get() = preferences.getString(KEY_MODE, MODE_GUARDIAN) ?: MODE_GUARDIAN
        set(value) = preferences.edit().putString(KEY_MODE, value).apply()

    // 마지막 표시 후 최소 간격 (분, 0 = 화면 켤 때마다)
    var intervalMinutes: Int
        get() = preferences.getInt(KEY_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)
        set(value) = preferences.edit().putInt(KEY_INTERVAL_MINUTES, value).apply()

    var lastShownAtMillis: Long
        get() = preferences.getLong(KEY_LAST_SHOWN_AT, 0L)
        set(value) = preferences.edit().putLong(KEY_LAST_SHOWN_AT, value).apply()

    // 알림 "1시간 쉬기" 끝나는 시각 (epoch 밀리초, 0 = 쉬지 않음)
    var pauseUntilMillis: Long
        get() = preferences.getLong(KEY_PAUSE_UNTIL, 0L)
        set(value) = preferences.edit().putLong(KEY_PAUSE_UNTIL, value).apply()

    // 오늘 일과 요약 JSON (Dart LockScreenSnapshot.toJson, 앱이 홈을 받을 때마다 덮어씀)
    var snapshotJson: String?
        get() = preferences.getString(KEY_SNAPSHOT_JSON, null)
        set(value) = preferences.edit().putString(KEY_SNAPSHOT_JSON, value).apply()

    // 소개 시트 노출 횟수 · 마지막 노출 시각 (처음 1회 + 7일 뒤 1회)
    var introShownCount: Int
        get() = preferences.getInt(KEY_INTRO_SHOWN_COUNT, 0)
        set(value) = preferences.edit().putInt(KEY_INTRO_SHOWN_COUNT, value).apply()

    var introLastShownAtMillis: Long
        get() = preferences.getLong(KEY_INTRO_LAST_SHOWN_AT, 0L)
        set(value) = preferences.edit().putLong(KEY_INTRO_LAST_SHOWN_AT, value).apply()

    val isElumiMode: Boolean
        get() = mode == MODE_ELUMI

    /** 저장된 요약 (없거나 깨졌으면 null) */
    val snapshot: LockScreenSnapshot?
        get() = LockScreenSnapshot.parse(snapshotJson)

    companion object {
        private const val FILE_NAME = "elum_lock_screen"
        private const val KEY_IS_ENABLED = "is_enabled"
        private const val KEY_MODE = "mode"
        private const val KEY_INTERVAL_MINUTES = "interval_minutes"
        private const val KEY_LAST_SHOWN_AT = "last_shown_at"
        private const val KEY_PAUSE_UNTIL = "pause_until"
        private const val KEY_SNAPSHOT_JSON = "snapshot_json"
        private const val KEY_INTRO_SHOWN_COUNT = "intro_shown_count"
        private const val KEY_INTRO_LAST_SHOWN_AT = "intro_last_shown_at"
        const val MODE_GUARDIAN = "guardian"
        const val MODE_ELUMI = "elumi"
        private const val DEFAULT_INTERVAL_MINUTES = 30
        // 요약 날짜 형식 (Dart LockScreenSnapshot.dateKeyOf 와 같은 모양)
        private const val DATE_KEY_PATTERN = "yyyy-MM-dd"

        fun today(): String = SimpleDateFormat(DATE_KEY_PATTERN, Locale.US).format(Date())
    }
}
