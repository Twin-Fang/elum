package kr.twinfang.elum.widget

import android.content.Intent
import android.util.Log

/**
 * 홈 위젯 > 앱 이동 경로: MainActivity intent extra 키와 값 (값은 잠금화면과 같은 home, routine:<일과 id>, check:<일과 id>:<카드 id>, 위젯 전용 create)
 * 앱이 꺼져 있으면 pendingRoute 에 두고 Dart takePendingRoute 가 꺼냄
 */
object ElumWidgetRoutes {
    const val EXTRA_ROUTE = "elum_widget_route"
    // 누른 위젯 이름 (로그용: today, now_card, streak, routine_list, quick_create)
    const val EXTRA_SOURCE = "elum_widget_source"
    const val ROUTE_HOME = "home"
    // 보호자 일과 입력 화면 (Dart 가 이룸이 기기에서는 홈으로 처리)
    const val ROUTE_CREATE = "create"
    private const val ROUTE_ROUTINE_PREFIX = "routine:"
    // 마지막 카드 체크: 앱이 그 카드를 체크하고 일과 화면을 엶 (Dart LockScreenRoutes 와 같은 모양)
    private const val ROUTE_CHECK_PREFIX = "check:"
    private const val ROUTE_SEPARATOR = ":"

    @Volatile
    var pendingRoute: String? = null

    fun routineRoute(routineId: String): String = ROUTE_ROUTINE_PREFIX + routineId

    fun checkRoute(routineId: String, cardId: String): String =
        ROUTE_CHECK_PREFIX + routineId + ROUTE_SEPARATOR + cardId

    fun takePendingRoute(): String? {
        val route = pendingRoute
        pendingRoute = null
        return route
    }

    /** intent 의 위젯 경로 꺼내기 (꺼내면 extra 지움, 다시 열릴 때 중복 이동 막음) + 로그 */
    fun consumeRoute(intent: Intent?): String? {
        val route = intent?.getStringExtra(EXTRA_ROUTE) ?: return null
        val source = intent.getStringExtra(EXTRA_SOURCE) ?: "unknown"
        intent.removeExtra(EXTRA_ROUTE)
        intent.removeExtra(EXTRA_SOURCE)
        Log.i(ElumWidgets.LOG_TAG, "[widget] open route : $route from $source")
        return route
    }
}
