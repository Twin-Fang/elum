package kr.twinfang.elum.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import kr.twinfang.elum.MainActivity
import kr.twinfang.elum.R
import kr.twinfang.elum.lockscreen.LockScreenRoutineRow

/**
 * 오늘 일과 목록 위젯 (4x2 기본, 4x4 까지): 머리(루미 상태 · 오늘 일과 · 전체 n/m) + 일과 줄(제목 · 진행 막대 · k/t · 다 하면 체크)
 * 크기 2단계: 중 3줄, 대 4줄. 줄 누르면 이룸이 기기 routine:<id> · 보호자 홈, 그 밖은 홈
 */
class ElumRoutineListWidget : ElumWidgetProvider() {
    override val sourceName: String = "routine_list"

    override val sizeSteps: List<SizeF> = listOf(MEDIUM_SIZE, LARGE_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews {
        val isLarge = sizeStepIndex >= LARGE_STEP_INDEX
        val layout = if (isLarge) R.layout.widget_routine_list_large else R.layout.widget_routine_list_medium
        val rowSlots = if (isLarge) LARGE_ROW_SLOTS else MEDIUM_ROW_SLOTS
        val views = RemoteViews(context.packageName, layout)
        bindHeader(context, views, state)
        val routines = state.todayRoutines
        if (routines.isEmpty()) {
            bindEmpty(context, views, state)
            return views
        }
        views.setViewVisibility(R.id.widget_routine_rows, View.VISIBLE)
        views.setViewVisibility(R.id.widget_routine_empty, View.GONE)
        // 칸 수만큼만 채우고 남는 칸은 숨김 (레이아웃에 없는 칸 id 는 부르지 않음)
        rowSlots.forEachIndexed { slotIndex, slot ->
            val routine = routines.getOrNull(slotIndex)
            if (routine == null) {
                views.setViewVisibility(slot.rowId, View.GONE)
            } else {
                bindRow(context, views, state, slot, slotIndex, routine)
            }
        }
        return views
    }

    // 머리: 루미 상태 그림 + 전체 n/m 칩 (요약 없음·일과 0개면 칩 숨김)
    private fun bindHeader(context: Context, views: RemoteViews, state: ElumWidgetState) {
        views.setImageViewResource(R.id.widget_lumi_image, state.lumiDrawableRes)
        if (!state.shouldShowProgress) {
            views.setViewVisibility(R.id.widget_count_chip, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_count_chip, View.VISIBLE)
        views.setTextViewText(
            R.id.widget_count_chip,
            context.getString(R.string.widget_progress_count, state.doneCount, state.totalCount),
        )
    }

    // 빈 상태: 루미 상태 그림·한마디 (일과 없음 > 보호자 새 일과 · 이룸이 쉬는 날, 지난 요약 > 앱 열어 보기)
    private fun bindEmpty(context: Context, views: RemoteViews, state: ElumWidgetState) {
        views.setViewVisibility(R.id.widget_routine_rows, View.GONE)
        views.setViewVisibility(R.id.widget_routine_empty, View.VISIBLE)
        views.setImageViewResource(R.id.widget_routine_empty_image, state.lumiDrawableRes)
        views.setTextViewText(R.id.widget_message, state.messageOf(context))
    }

    // 한 줄: 제목 · 진행 막대 · k/t · 다 하면 체크 · 이룸이 기기면 그 일과 열기
    private fun bindRow(
        context: Context,
        views: RemoteViews,
        state: ElumWidgetState,
        slot: RowSlot,
        slotIndex: Int,
        routine: LockScreenRoutineRow,
    ) {
        views.setViewVisibility(slot.rowId, View.VISIBLE)
        views.setTextViewText(slot.titleId, routine.title)
        // 카드 0개 일과도 빈 막대로 (max 0 이면 막대가 꽉 찬 것처럼 보이는 런처 있음)
        views.setProgressBar(slot.progressId, routine.totalCards.coerceAtLeast(1), routine.doneCards, false)
        views.setTextViewText(
            slot.countId,
            context.getString(R.string.widget_progress_count, routine.doneCards, routine.totalCards),
        )
        views.setViewVisibility(slot.checkId, if (routine.isDone) View.VISIBLE else View.GONE)
        // 보호자 기기는 줄 탭 없음 > 위젯 판 탭(홈)으로 감
        if (state.isElumiDevice) {
            views.setOnClickPendingIntent(slot.rowId, openRoutineIntentOf(context, slotIndex, routine.id))
        }
    }

    // routine:<일과 id> 열기 (줄마다 action·요청 코드 따로: 위젯 판 탭 intent 와 겹치지 않게)
    private fun openRoutineIntentOf(context: Context, slotIndex: Int, routineId: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION_OPEN_ROUTINE_ROW_PREFIX + slotIndex)
            .putExtra(ElumWidgetRoutes.EXTRA_ROUTE, ElumWidgetRoutes.routineRoute(routineId))
            .putExtra(ElumWidgetRoutes.EXTRA_SOURCE, sourceName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            ROW_REQUEST_CODE_BASE + slotIndex,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /** 레이아웃 줄 칸 하나의 view id 묶음 */
    private class RowSlot(val rowId: Int, val titleId: Int, val progressId: Int, val countId: Int, val checkId: Int)

    companion object {
        // 크기 단계 최소 크기 (dp): 중 4x2, 대 4x4
        val MEDIUM_SIZE = SizeF(220f, 110f)
        val LARGE_SIZE = SizeF(220f, 220f)
        private const val LARGE_STEP_INDEX = 1
        private const val ACTION_OPEN_ROUTINE_ROW_PREFIX = "kr.twinfang.elum.widget.ACTION_OPEN_ROUTINE_ROW_"
        // 줄 탭 요청 코드 시작값 (위젯 id 기반 판 탭 요청 코드와 겹치지 않는 큰 값)
        private const val ROW_REQUEST_CODE_BASE = 1_465_000

        private val ALL_ROW_SLOTS = listOf(
            RowSlot(
                R.id.widget_routine_row_1, R.id.widget_routine_row_1_title, R.id.widget_routine_row_1_progress,
                R.id.widget_routine_row_1_count, R.id.widget_routine_row_1_check,
            ),
            RowSlot(
                R.id.widget_routine_row_2, R.id.widget_routine_row_2_title, R.id.widget_routine_row_2_progress,
                R.id.widget_routine_row_2_count, R.id.widget_routine_row_2_check,
            ),
            RowSlot(
                R.id.widget_routine_row_3, R.id.widget_routine_row_3_title, R.id.widget_routine_row_3_progress,
                R.id.widget_routine_row_3_count, R.id.widget_routine_row_3_check,
            ),
            RowSlot(
                R.id.widget_routine_row_4, R.id.widget_routine_row_4_title, R.id.widget_routine_row_4_progress,
                R.id.widget_routine_row_4_count, R.id.widget_routine_row_4_check,
            ),
        )
        // 중 레이아웃 3칸 · 대 레이아웃 4칸 (widget_routine_list_medium/large.xml 과 같이 바꿈)
        private val MEDIUM_ROW_SLOTS = ALL_ROW_SLOTS.take(3)
        private val LARGE_ROW_SLOTS = ALL_ROW_SLOTS
    }
}
