package kr.twinfang.elum.widget

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews

/**
 * 오늘 루미 위젯 (2x2 기본, 4x2 까지): 루미 상태 그림 + 한마디 + 진행 막대 + 다음 일과 > 누르면 홈
 * 크기 2단계: 소(세로 배치), 중(루미 왼쪽 · 글 오른쪽)
 */
class ElumTodayWidget : ElumWidgetProvider() {
    override val sourceName: String = "today"

    override val sizeSteps: List<SizeF> = listOf(SMALL_SIZE, MEDIUM_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews =
        ElumWidgetViews.buildTodayViews(context, state, isMedium = sizeStepIndex >= MEDIUM_STEP_INDEX)

    companion object {
        // 크기 단계 최소 크기 (dp): 소 2x2, 중 4x2 (런처 셀 약 57~73dp)
        val SMALL_SIZE = SizeF(110f, 110f)
        val MEDIUM_SIZE = SizeF(220f, 110f)
        private const val MEDIUM_STEP_INDEX = 1
    }
}
