package kr.twinfang.elum.widget

import android.content.Context
import android.graphics.Bitmap
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kr.twinfang.elum.R
import kr.twinfang.elum.lockscreen.LockScreenElumiCard
import kr.twinfang.elum.lockscreen.LockScreenSnapshot

/**
 * 루미 상태 8종 (설계 #1465 표, 위에서부터 먼저 맞는 것): 그림·한마디가 정해짐
 * iOS 위젯과 같은 규칙
 */
enum class LumiState { STALE, EMPTY, DONE, NIGHT, EVENING, MORNING, READY, PROGRESS }

/**
 * 위젯 한 번 그릴 때 쓰는 상태: 요약 + 루미 상태 + 기기 역할 > 그림·문구·진행·지금 할 카드
 * 상태 계산은 이 파일 한 곳 (기기 현지 시각 기준)
 */
class ElumWidgetState private constructor(
    val snapshot: LockScreenSnapshot?,
    val lumiState: LumiState,
    // 위젯에서 체크한 카드 id·마지막 체크 시각·지금 시각 (#1465 2단계)
    private val checkedCardIds: Set<String> = emptySet(),
    private val lastCheckAtMillis: Long = 0L,
    private val nowMillis: Long = System.currentTimeMillis(),
) {
    // 요약 없으면 보호자 문구 (역할을 모름)
    val isElumiDevice: Boolean
        get() = snapshot?.isElumiMode == true

    val doneCount: Int
        get() = snapshot?.doneCount ?: 0

    val totalCount: Int
        get() = snapshot?.totalCount ?: 0

    // 진행 막대·n/m 보일 상태 (요약 없음·일과 0개는 숨김)
    val shouldShowProgress: Boolean
        get() = lumiState != LumiState.STALE && lumiState != LumiState.EMPTY

    val streakDays: Int
        get() = snapshot?.streakDays ?: 0

    val starCount: Int
        get() = snapshot?.starCount ?: 0

    // 오늘 요약 + 다 하지 않았을 때만 다음 일과 제목
    val nextRoutineTitle: String?
        get() = snapshot?.nextRoutineTitle?.takeIf { shouldShowProgress && lumiState != LumiState.DONE }

    // 오늘 요약 + 카드 있음 + 다 하지 않음 > 지금 할 카드 (그 밖은 루미 상태 화면)
    val nowCard: LockScreenElumiCard?
        get() = snapshot?.elumiCard?.takeIf { shouldShowProgress && lumiState != LumiState.DONE }

    // 위젯 체크 가능: 이룸이 기기 + 오늘 요약 (보호자 기기·지난 요약은 버튼 없음)
    private val canCheckFromWidget: Boolean
        get() = isElumiDevice && lumiState != LumiState.STALE

    // 지금 할 카드 체크 상태 (보여 줄 카드·버튼 동작, 카드 없으면 null)
    val nowCardCheck: ElumWidgetCardCheck? by lazy {
        nowCard?.let { ElumWidgetCardCheck.of(it, canCheckFromWidget, checkedCardIds) }
    }

    // 지금 할 카드 그림 (크기 단계마다 다시 읽지 않게 한 번만, 없으면 null)
    val nowCardPicture: Bitmap? by lazy { ElumWidgetCardPicture.decode(nowCardCheck?.displayCard?.imageFilePath) }

    // 체크 뒤 10분 동안 루미 cheer + "잘했어요!" (체크 가능할 때만)
    val shouldShowCheckPraise: Boolean
        get() {
            if (!canCheckFromWidget || lastCheckAtMillis <= 0L) return false
            val elapsedMillis = nowMillis - lastCheckAtMillis
            return elapsedMillis in 0L until CHECK_PRAISE_DURATION_MILLIS
        }

    val lumiDrawableRes: Int
        get() = when (lumiState) {
            LumiState.STALE -> R.drawable.lumi_hello
            LumiState.EMPTY -> if (isElumiDevice) R.drawable.lumi_resting else R.drawable.lumi_new_routine
            LumiState.DONE -> R.drawable.lumi_celebrate_star
            LumiState.NIGHT -> R.drawable.lumi_sleepy
            LumiState.EVENING -> R.drawable.lumi_waiting
            LumiState.MORNING -> R.drawable.lumi_hello
            LumiState.READY -> R.drawable.lumi_holding_card
            LumiState.PROGRESS -> R.drawable.lumi_cheer
        }

    /** 루미 한마디 (보호자·이룸이 기기 문구 다름, 이름 없는 문구) */
    fun messageOf(context: Context): String {
        val isElumi = isElumiDevice
        return when (lumiState) {
            LumiState.STALE -> context.getString(
                if (isElumi) R.string.widget_message_stale_elumi else R.string.widget_message_stale_guardian,
            )
            LumiState.EMPTY -> context.getString(
                if (isElumi) R.string.widget_message_empty_elumi else R.string.widget_message_empty_guardian,
            )
            LumiState.DONE -> context.getString(
                if (isElumi) R.string.widget_message_done_elumi else R.string.widget_message_done_guardian,
            )
            LumiState.NIGHT -> context.getString(R.string.widget_message_night)
            LumiState.EVENING -> context.getString(R.string.widget_message_evening)
            LumiState.MORNING -> context.getString(
                if (isElumi) R.string.widget_message_morning_elumi else R.string.widget_message_morning_guardian,
                totalCount,
            )
            LumiState.READY -> context.getString(
                if (isElumi) R.string.widget_message_ready_elumi else R.string.widget_message_ready_guardian,
                totalCount,
            )
            LumiState.PROGRESS -> context.getString(
                if (isElumi) R.string.widget_message_progress_elumi else R.string.widget_message_progress_guardian,
                doneCount,
                totalCount,
            )
        }
    }

    companion object {
        // 시간대 경계 (현지 시, 24시간제)
        private const val NIGHT_START_HOUR = 21
        private const val EVENING_START_HOUR = 18
        private const val MORNING_END_HOUR = 12
        // Dart LockScreenSnapshot.dateKeyOf 와 같은 모양
        private const val DATE_KEY_PATTERN = "yyyy-MM-dd"
        // 체크 칭찬 보이는 시간 (10분)
        private const val CHECK_PRAISE_DURATION_MILLIS = 10 * 60 * 1000L

        fun load(context: Context, now: Calendar = Calendar.getInstance()): ElumWidgetState {
            val preferences = ElumWidgetPreferences(context)
            val snapshot = preferences.snapshot
            return ElumWidgetState(
                snapshot = snapshot,
                lumiState = lumiStateOf(snapshot, now),
                checkedCardIds = preferences.checkedCardIds,
                lastCheckAtMillis = preferences.lastCheckAtMillis,
                nowMillis = now.timeInMillis,
            )
        }

        /** 표 순서: stale > empty > done > night > evening > morning > ready > progress */
        fun lumiStateOf(snapshot: LockScreenSnapshot?, now: Calendar): LumiState {
            if (snapshot == null || snapshot.dateKey != dateKeyOf(now)) return LumiState.STALE
            if (snapshot.totalCount <= 0) return LumiState.EMPTY
            if (snapshot.doneCount >= snapshot.totalCount) return LumiState.DONE
            val hour = now.get(Calendar.HOUR_OF_DAY)
            val hasNotStarted = snapshot.doneCount <= 0
            return when {
                hour >= NIGHT_START_HOUR -> LumiState.NIGHT
                hour >= EVENING_START_HOUR && hasNotStarted -> LumiState.EVENING
                hour < MORNING_END_HOUR && hasNotStarted -> LumiState.MORNING
                hasNotStarted -> LumiState.READY
                else -> LumiState.PROGRESS
            }
        }

        private fun dateKeyOf(now: Calendar): String =
            SimpleDateFormat(DATE_KEY_PATTERN, Locale.US).format(now.time)
    }
}
