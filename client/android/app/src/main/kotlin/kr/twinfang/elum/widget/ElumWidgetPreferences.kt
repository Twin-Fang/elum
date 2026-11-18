package kr.twinfang.elum.widget

import android.content.Context
import kr.twinfang.elum.lockscreen.LockScreenSnapshot

/**
 * 홈 위젯 전용 저장소: 오늘 일과 요약 JSON (채널 elum/home_widget 이 씀, 위젯이 읽음)
 * 잠금화면 저장소와 분리 (잠금화면은 Android 출시 전이라 Dart 가 그쪽으로 보내지 않음, #1420)
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

    companion object {
        private const val FILE_NAME = "elum_widget"
        private const val KEY_SNAPSHOT_JSON = "snapshotJson"
    }
}
