package kr.twinfang.elum.widget

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 채널 elum/home_widget 처리 (iOS 와 같은 이름·메서드): 요약 저장 > 위젯 전부 갱신, 위젯이 연 경로 꺼내기
 * 네이티브 > Dart: openRoute {route} (앱이 떠 있을 때 위젯을 누름, MainActivity 가 부름)
 */
class ElumWidgetChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val preferences = ElumWidgetPreferences(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateSnapshot" -> {
                preferences.snapshotJson = call.argument<String>("json")
                ElumWidgets.updateAll(context)
                result.success(null)
            }
            "takePendingRoute" -> result.success(ElumWidgetRoutes.takePendingRoute())
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "elum/home_widget"
        const val METHOD_OPEN_ROUTE = "openRoute"
        const val ARGUMENT_ROUTE = "route"

        /** 떠 있는 앱에 경로 전달 (채널 없으면 pending 으로 남김) */
        fun openRoute(channel: MethodChannel?, route: String) {
            if (channel == null) {
                ElumWidgetRoutes.pendingRoute = route
                return
            }
            try {
                channel.invokeMethod(METHOD_OPEN_ROUTE, mapOf(ARGUMENT_ROUTE to route))
            } catch (error: Exception) {
                Log.w(ElumWidgets.LOG_TAG, "[widget] open route failed : ${error.javaClass.simpleName}")
                ElumWidgetRoutes.pendingRoute = route
            }
        }
    }
}
