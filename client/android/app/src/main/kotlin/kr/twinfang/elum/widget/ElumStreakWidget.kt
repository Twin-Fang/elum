package kr.twinfang.elum.widget

import android.content.Context
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import kr.twinfang.elum.R

/**
 * 별과 연속 위젯 (2x1 기본, 2x2 까지): 루미 불꽃 + n일 연속 + 별 k개 > 누르면 홈
 * 연속 2일 미만이면 쉬는 루미 + 별만 (끊김·겁주기 문구 없음)
 */
class ElumStreakWidget : ElumWidgetProvider() {
    override val sourceName: String = "streak"

    override val sizeSteps: List<SizeF> = listOf(COMPACT_SIZE, TALL_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews {
        val layout = if (sizeStepIndex >= TALL_STEP_INDEX) R.layout.widget_streak_tall else R.layout.widget_streak_compact
        val views = RemoteViews(context.packageName, layout)
        val starText = context.getString(R.string.widget_star_count, state.starCount)
        if (state.streakDays >= MINIMUM_SHOWN_STREAK_DAYS) {
            views.setImageViewResource(R.id.widget_lumi_image, R.drawable.lumi_streak_flame)
            views.setTextViewText(R.id.widget_streak_text, context.getString(R.string.widget_streak_days, state.streakDays))
            views.setViewVisibility(R.id.widget_star_text, View.VISIBLE)
            views.setTextViewText(R.id.widget_star_text, starText)
        } else {
            views.setImageViewResource(R.id.widget_lumi_image, R.drawable.lumi_idle)
            views.setTextViewText(R.id.widget_streak_text, starText)
            views.setViewVisibility(R.id.widget_star_text, View.GONE)
        }
        return views
    }

    companion object {
        // 크기 단계 최소 크기 (dp): 2x1, 2x2
        val COMPACT_SIZE = SizeF(110f, 40f)
        val TALL_SIZE = SizeF(110f, 110f)
        private const val TALL_STEP_INDEX = 1
        // 연속 표시 시작 일수 (1일은 연속이 아님)
        private const val MINIMUM_SHOWN_STREAK_DAYS = 2
    }
}
