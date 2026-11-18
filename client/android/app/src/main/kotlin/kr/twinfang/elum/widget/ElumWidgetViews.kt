package kr.twinfang.elum.widget

import android.content.Context
import android.view.View
import android.widget.RemoteViews
import kr.twinfang.elum.R

/**
 * 위젯 레이아웃 공통 칸 채우기: 머리 이름, 루미 그림·한마디, 진행 막대·n/m, 다음 일과
 * 없는 칸 id 를 부르면 위젯 전체가 안 그려짐 > 레이아웃에 있는 칸만 부름
 */
object ElumWidgetViews {
    /** 머리: 이룸이 이름 (없으면 앱 이름) */
    fun bindHeader(context: Context, views: RemoteViews, state: ElumWidgetState) {
        val name = state.snapshot?.elumiName ?: context.getString(R.string.app_name)
        views.setTextViewText(R.id.widget_header, name)
    }

    fun bindLumi(context: Context, views: RemoteViews, state: ElumWidgetState) {
        views.setImageViewResource(R.id.widget_lumi_image, state.lumiDrawableRes)
        views.setTextViewText(R.id.widget_message, state.messageOf(context))
    }

    /** 진행 막대 + n/m (요약 없음·일과 0개면 줄째 숨김) */
    fun bindProgress(context: Context, views: RemoteViews, state: ElumWidgetState) {
        if (!state.shouldShowProgress) {
            views.setViewVisibility(R.id.widget_progress_row, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_progress_row, View.VISIBLE)
        views.setProgressBar(R.id.widget_progress, state.totalCount, state.doneCount, false)
        views.setTextViewText(
            R.id.widget_progress_text,
            context.getString(R.string.widget_progress_count, state.doneCount, state.totalCount),
        )
    }

    fun bindNextRoutine(context: Context, views: RemoteViews, state: ElumWidgetState) {
        val title = state.nextRoutineTitle
        if (title == null) {
            views.setViewVisibility(R.id.widget_next_text, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_next_text, View.VISIBLE)
        views.setTextViewText(R.id.widget_next_text, context.getString(R.string.widget_next_routine, title))
    }

    /** 오늘 루미 화면 (Today 위젯 · 카드 없을 때 Now 위젯): 소 레이아웃은 머리·다음 일과 칸 없음 · 대는 루미 가운데 크게 */
    fun buildTodayViews(context: Context, state: ElumWidgetState, isMedium: Boolean, isLarge: Boolean = false): RemoteViews {
        val layout = when {
            isLarge -> R.layout.widget_today_large
            isMedium -> R.layout.widget_today_medium
            else -> R.layout.widget_today_small
        }
        val views = RemoteViews(context.packageName, layout)
        bindLumi(context, views, state)
        bindProgress(context, views, state)
        if (isMedium || isLarge) {
            bindHeader(context, views, state)
            bindNextRoutine(context, views, state)
        }
        return views
    }
}
