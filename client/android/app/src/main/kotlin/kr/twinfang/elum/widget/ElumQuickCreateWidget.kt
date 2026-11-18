package kr.twinfang.elum.widget

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import kr.twinfang.elum.R

/**
 * 빠른 만들기 위젯 (2x2 기본, 2x1 까지): 새 일과 루미 + "새 일과 만들기" 알약 > 누르면 일과 입력 화면
 * 이룸이 기기에서도 그대로 보이되 누르면 홈 (상태와 무관한 고정 화면)
 */
class ElumQuickCreateWidget : ElumWidgetProvider() {
    override val sourceName: String = "quick_create"

    override val sizeSteps: List<SizeF> = listOf(COMPACT_SIZE, TALL_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews {
        val layout = if (sizeStepIndex >= TALL_STEP_INDEX) R.layout.widget_quick_create_tall else R.layout.widget_quick_create_compact
        return RemoteViews(context.packageName, layout)
    }

    override fun routeOf(state: ElumWidgetState): String =
        if (state.isElumiDevice) ElumWidgetRoutes.ROUTE_HOME else ElumWidgetRoutes.ROUTE_CREATE

    companion object {
        // 크기 단계 최소 크기 (dp): 2x1, 2x2
        val COMPACT_SIZE = SizeF(110f, 40f)
        val TALL_SIZE = SizeF(110f, 110f)
        private const val TALL_STEP_INDEX = 1
    }
}
