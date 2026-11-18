package kr.twinfang.elum.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log

/**
 * 홈 위젯 5종 묶음: 전부 다시 그리기 (요약 저장 직후 채널이 부름)
 */
object ElumWidgets {
    const val LOG_TAG = "ElumWidget"

    // 위젯 5종: 새 위젯을 더하면 여기 한 줄
    private val providers: List<ElumWidgetProvider> = listOf(
        ElumTodayWidget(),
        ElumNowCardWidget(),
        ElumStreakWidget(),
        ElumRoutineListWidget(),
        ElumQuickCreateWidget(),
    )

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (provider in providers) {
            val widgetIds = try {
                manager.getAppWidgetIds(ComponentName(context, provider.javaClass))
            } catch (error: Exception) {
                Log.w(LOG_TAG, "[widget] update all skipped : ${provider.sourceName} ${error.javaClass.simpleName}")
                continue
            }
            if (widgetIds.isEmpty()) continue
            provider.updateWidgets(context, manager, widgetIds)
        }
    }
}
