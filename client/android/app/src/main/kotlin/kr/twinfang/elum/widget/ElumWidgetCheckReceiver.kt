package kr.twinfang.elum.widget

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 위젯 "다 했어요" 누름 처리: 연속 누름 막기 > 대기열 기록 > 위젯 전부 갱신 > 떠 있는 앱에 알림
 * 서버 전송은 하지 않음 (진행 기록 원본은 앱 ChildRoutineNotifier, 앱이 takeWidgetChecks 로 꺼냄)
 */
class ElumWidgetCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_CHECK) return
        val check = checkOf(intent) ?: run {
            Log.w(ElumWidgets.LOG_TAG, "[widget check] rejected : missing extras")
            return
        }
        val preferences = ElumWidgetPreferences(context)
        if (isDebounced(preferences.lastCheckAtMillis, check.checkedAtMillis)) {
            Log.i(ElumWidgets.LOG_TAG, "[widget check] ignored : within debounce")
            return
        }
        preferences.recordCheck(check)
        Log.i(ElumWidgets.LOG_TAG, "[widget check] queued : outbox ${preferences.checkOutbox.size}")
        ElumWidgets.updateAll(context)
        ElumWidgetChannel.notifyWidgetChecksAdded()
    }

    // extra 3개(routineId, cardId, dateKey) 모두 있어야 기록
    private fun checkOf(intent: Intent): ElumWidgetCheck? {
        val routineId = intent.getStringExtra(EXTRA_ROUTINE_ID)?.takeIf { it.isNotEmpty() } ?: return null
        val cardId = intent.getStringExtra(EXTRA_CARD_ID)?.takeIf { it.isNotEmpty() } ?: return null
        val dateKey = intent.getStringExtra(EXTRA_DATE_KEY)?.takeIf { it.isNotEmpty() } ?: return null
        return ElumWidgetCheck(routineId, cardId, dateKey, System.currentTimeMillis())
    }

    // 마지막 체크 1.5초 안 누름 무시 (같은 손가락이 다음 카드까지 끝내지 않게, 시계가 뒤로 가면 통과)
    private fun isDebounced(lastCheckAtMillis: Long, nowMillis: Long): Boolean {
        val elapsedMillis = nowMillis - lastCheckAtMillis
        return lastCheckAtMillis > 0L && elapsedMillis in 0L until DEBOUNCE_MILLIS
    }

    companion object {
        private const val ACTION_CHECK = "kr.twinfang.elum.widget.ACTION_CHECK_CARD"
        private const val EXTRA_ROUTINE_ID = "routineId"
        private const val EXTRA_CARD_ID = "cardId"
        private const val EXTRA_DATE_KEY = "dateKey"
        // 연속 누름 막는 시간 (1.5초)
        private const val DEBOUNCE_MILLIS = 1500L

        /** 버튼 PendingIntent (카드마다 요청 코드 달리 > 카드별 extra 유지) */
        fun pendingIntentOf(context: Context, routineId: String, cardId: String, dateKey: String): PendingIntent {
            val intent = Intent(context, ElumWidgetCheckReceiver::class.java)
                .setAction(ACTION_CHECK)
                .putExtra(EXTRA_ROUTINE_ID, routineId)
                .putExtra(EXTRA_CARD_ID, cardId)
                .putExtra(EXTRA_DATE_KEY, dateKey)
            return PendingIntent.getBroadcast(
                context,
                cardId.hashCode(),
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}
