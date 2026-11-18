package kr.twinfang.elum.widget

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * 채널 elum/home_widget 처리 (iOS 와 같은 이름·메서드): 요약 저장 > 위젯 전부 갱신, 위젯이 연 경로 꺼내기, 위젯 체크 대기열 꺼내기
 * 네이티브 > Dart: openRoute {route} (앱이 떠 있을 때 위젯을 누름), widgetChecksAdded (앱이 떠 있을 때 위젯 체크)
 */
class ElumWidgetChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val preferences = ElumWidgetPreferences(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateSnapshot" -> {
                preferences.snapshotJson = call.argument<String>("json")
                // 새 요약이 기준 > 위젯 표시용 체크 비움 (lastCheckAtMillis 는 칭찬·연속 누름용으로 유지)
                preferences.clearCheckedCardIds()
                ElumWidgets.updateAll(context)
                result.success(null)
            }
            "takePendingRoute" -> result.success(ElumWidgetRoutes.takePendingRoute())
            "takeWidgetChecks" -> result.success(preferences.takeCheckOutboxJson())
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "elum/home_widget"
        const val METHOD_OPEN_ROUTE = "openRoute"
        const val ARGUMENT_ROUTE = "route"
        private const val METHOD_WIDGET_CHECKS_ADDED = "widgetChecksAdded"

        // MainActivity 가 등록한 채널 (앱이 떠 있을 때만, 액티비티 누수 막으려 약한 참조)
        @Volatile
        private var liveChannelReference: WeakReference<MethodChannel>? = null

        fun attachLiveChannel(channel: MethodChannel) {
            liveChannelReference = WeakReference(channel)
        }

        fun detachLiveChannel(channel: MethodChannel?) {
            if (liveChannelReference?.get() === channel) liveChannelReference = null
        }

        /** 떠 있는 앱에 위젯 체크 알림 (앱 꺼져 있으면 다음 실행 때 takeWidgetChecks 로 받음, 메인 스레드에서 부름) */
        fun notifyWidgetChecksAdded() {
            val channel = liveChannelReference?.get() ?: return
            try {
                channel.invokeMethod(METHOD_WIDGET_CHECKS_ADDED, null)
            } catch (error: Exception) {
                Log.w(ElumWidgets.LOG_TAG, "[widget check] notify failed : ${error.javaClass.simpleName}")
            }
        }

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
