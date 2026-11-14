package kr.twinfang.elum.lockscreen

/**
 * 잠금화면 > 앱 이동 경로: MainActivity intent extra 키와 값 (Dart lock_screen_routes.dart 와 같은 값)
 * 값 3종: home, routine:<일과 id>, settings_lock_screen
 */
object LockScreenRoutes {
    const val EXTRA_ROUTE = "elum_lock_screen_route"
    const val ROUTE_HOME = "home"

    // 앱 엔진이 아직 안 받은 경로 (Dart takePendingRoute 가 꺼내 감, 꺼내면 비움)
    @Volatile
    var pendingRoute: String? = null

    fun takePendingRoute(): String? {
        val route = pendingRoute
        pendingRoute = null
        return route
    }
}
