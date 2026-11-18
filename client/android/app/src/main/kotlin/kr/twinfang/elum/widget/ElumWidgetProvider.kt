package kr.twinfang.elum.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.widget.RemoteViews
import kr.twinfang.elum.MainActivity

/**
 * 위젯 3종 공통: 갱신 시점(주기·크기 변경·요약 저장) > 상태 읽기 > 크기별 레이아웃 > 누르면 앱 경로
 * API 31+ 는 크기별 RemoteViews 묶음(런처가 고름), 그 아래는 지금 크기로 하나 고름
 */
abstract class ElumWidgetProvider : AppWidgetProvider() {
    // 로그·탭 출처 이름 (today, now_card, streak)
    abstract val sourceName: String

    // 크기 단계별 최소 크기 (dp, 작은 것부터)
    protected abstract val sizeSteps: List<SizeF>

    /** 크기 단계 하나의 RemoteViews (단계 번호는 sizeSteps 순서) */
    protected abstract fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        updateWidgets(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    fun updateWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val state = ElumWidgetState.load(context)
        for (widgetId in widgetIds) {
            // 한 위젯 실패가 나머지 갱신을 막지 않게 (실패 시 런처가 이전 화면 유지)
            try {
                manager.updateAppWidget(widgetId, responsiveViews(context, manager, widgetId, state))
            } catch (error: Exception) {
                Log.e(ElumWidgets.LOG_TAG, "[widget] update failed : $sourceName ${error.javaClass.simpleName}")
            }
        }
    }

    private fun responsiveViews(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        state: ElumWidgetState,
    ): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val viewsBySize = sizeSteps.mapIndexed { index, size ->
                size to buildViews(context, state, index).withTapIntent(context, widgetId, state)
            }.toMap()
            return RemoteViews(viewsBySize)
        }
        return buildViews(context, state, sizeStepIndexOf(manager.getAppWidgetOptions(widgetId)))
            .withTapIntent(context, widgetId, state)
    }

    // API 30 이하: 세로 화면 기준 너비(최소)·높이(최대)로 들어가는 가장 큰 단계
    private fun sizeStepIndexOf(options: Bundle?): Int {
        val widthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val heightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        val fittingIndex = sizeSteps.indexOfLast { widthDp >= it.width && heightDp >= it.height }
        return fittingIndex.coerceAtLeast(0)
    }

    /** 이 위젯이 열 경로 (기본 홈) */
    protected open fun routeOf(state: ElumWidgetState): String = ElumWidgetRoutes.ROUTE_HOME

    private fun RemoteViews.withTapIntent(context: Context, widgetId: Int, state: ElumWidgetState): RemoteViews {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(ElumWidgetRoutes.EXTRA_ROUTE, routeOf(state))
            .putExtra(ElumWidgetRoutes.EXTRA_SOURCE, sourceName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        // 위젯 id 별 요청 코드: 위젯마다 다른 경로를 들고 있게
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        setOnClickPendingIntent(android.R.id.background, pendingIntent)
        return this
    }
}
