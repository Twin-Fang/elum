package kr.twinfang.elum.widget

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import kr.twinfang.elum.R
import kr.twinfang.elum.lockscreen.LockScreenElumiCard

/**
 * 지금 할 카드 위젯 (2x2 기본, 4x4 까지): 카드 그림 + 카드 글 + 일과 제목 + n/m > 누르면 그 일과
 * 카드 없으면 오늘 루미와 같은 상태 화면 > 누르면 홈
 * 크기 3단계: 소(그림 위 · 글 아래), 중(그림 왼쪽), 대(큰 그림 + 큰 글)
 */
class ElumNowCardWidget : ElumWidgetProvider() {
    override val sourceName: String = "now_card"

    override val sizeSteps: List<SizeF> = listOf(SMALL_SIZE, MEDIUM_SIZE, LARGE_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews {
        val card = state.nowCard
            ?: return ElumWidgetViews.buildTodayViews(context, state, isMedium = sizeStepIndex >= MEDIUM_STEP_INDEX)
        val layout = when (sizeStepIndex) {
            SMALL_STEP_INDEX -> R.layout.widget_now_small
            MEDIUM_STEP_INDEX -> R.layout.widget_now_medium
            else -> R.layout.widget_now_large
        }
        val views = RemoteViews(context.packageName, layout)
        bindCard(context, views, state, card)
        // 소 레이아웃은 일과 제목 칸 없음 (좁아서 카드 글만)
        if (sizeStepIndex != SMALL_STEP_INDEX) views.setTextViewText(R.id.widget_routine_title, card.routineTitle)
        return views
    }

    override fun routeOf(state: ElumWidgetState): String =
        state.nowCard?.let { ElumWidgetRoutes.routineRoute(it.routineId) } ?: ElumWidgetRoutes.ROUTE_HOME

    // 카드 그림 (파일 > 루미가 카드 든 그림), 카드 글, n/m 칩
    private fun bindCard(context: Context, views: RemoteViews, state: ElumWidgetState, card: LockScreenElumiCard) {
        val picture = state.nowCardPicture
        if (picture != null) {
            views.setImageViewBitmap(R.id.widget_card_image, picture)
        } else {
            views.setImageViewResource(R.id.widget_card_image, R.drawable.lumi_holding_card)
        }
        views.setTextViewText(R.id.widget_card_text, card.cardText)
        views.setTextViewText(
            R.id.widget_count_chip,
            context.getString(R.string.widget_progress_count, state.doneCount, state.totalCount),
        )
    }

    companion object {
        // 크기 단계 최소 크기 (dp): 소 2x2, 중 4x2, 대 4x4
        val SMALL_SIZE = SizeF(110f, 110f)
        val MEDIUM_SIZE = SizeF(220f, 110f)
        val LARGE_SIZE = SizeF(220f, 220f)
        private const val SMALL_STEP_INDEX = 0
        private const val MEDIUM_STEP_INDEX = 1
    }
}
