package kr.twinfang.elum.lockscreen

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 채널 elum/lock_screen 처리 (앱 엔진·잠금화면 엔진 공통): 권한 조회·설정 열기, 켜기·끄기·설정, 요약 저장·읽기, 소개 기록, 잠금화면 닫기·해제
 * [activityProvider]: 설정 화면을 띄우거나 닫을 활동 (앱 엔진 = MainActivity, 잠금 엔진 = 지금 잠금화면)
 */
class LockScreenChannel(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {
    private val preferences = LockScreenPreferences(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(LockScreenPermissions.toStatusMap(context))
            "openOverlaySettings" -> replyAfter(result) {
                openSettings(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri()))
            }
            "openNotificationSettings" -> replyAfter(result) { openSettings(notificationSettingsIntent()) }
            // Play 정책: 직접 요청 다이얼로그(REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) 대신 목록 화면
            "openBatteryOptimizationSettings" -> replyAfter(result) {
                openSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
            "openSamsungPowerSettings" -> replyAfter(result) { openSamsungPowerSettings() }
            "enable" -> result.success(enable(call))
            "disable" -> replyAfter(result) {
                preferences.isEnabled = false
                LockScreenService.stop(context)
            }
            "updateSettings" -> replyAfter(result) { applySettings(call) }
            "getSettings" -> result.success(
                mapOf(
                    "isEnabled" to preferences.isEnabled,
                    "mode" to preferences.mode,
                    "intervalMinutes" to preferences.intervalMinutes,
                    // 쉬기 끝 시각 (epoch 밀리초, 쉬지 않으면 0)
                    "pauseUntilMillis" to activePauseUntilMillis(),
                ),
            )
            "updateSnapshot" -> replyAfter(result) { updateSnapshot(call.argument<String>("json")) }
            "getSnapshot" -> result.success(preferences.snapshotJson)
            "pauseOneHour" -> replyAfter(result) {
                LockScreenService.sendAction(context, LockScreenService.ACTION_PAUSE_ONE_HOUR)
                activityProvider()?.finish()
            }
            "getIntroRecord" -> result.success(
                mapOf(
                    "shownCount" to preferences.introShownCount,
                    "lastShownAtMillis" to preferences.introLastShownAtMillis,
                ),
            )
            "recordIntroShown" -> replyAfter(result) {
                preferences.introShownCount = preferences.introShownCount + 1
                preferences.introLastShownAtMillis = System.currentTimeMillis()
            }
            "consumePendingShow" -> result.success(LockScreenEngine.consumePendingShow())
            "takePendingRoute" -> result.success(LockScreenRoutes.takePendingRoute())
            "dismiss" -> replyAfter(result) { activityProvider()?.finish() }
            "unlockAndOpen" -> replyAfter(result) {
                val route = call.argument<String>("route") ?: LockScreenRoutes.ROUTE_HOME
                (activityProvider() as? LockScreenActivity)?.unlockAndOpen(route)
            }
            else -> result.notImplemented()
        }
    }

    private inline fun replyAfter(result: MethodChannel.Result, action: () -> Unit) {
        action()
        result.success(null)
    }

    /** 켜기: 모드·간격 저장 > 필수 권한 3개 확인(없으면 false) > 쉬기 해제 > 서비스 시작(알림 즉시 갱신) */
    private fun enable(call: MethodCall): Boolean {
        call.argument<String>("mode")?.let { preferences.mode = it }
        applySettings(call)
        if (!LockScreenPermissions.hasRequiredPermissions(context)) return false
        preferences.isEnabled = true
        preferences.pauseUntilMillis = 0L
        LockScreenService.start(context)
        return true
    }

    private fun applySettings(call: MethodCall) {
        call.argument<Int>("intervalMinutes")?.let { preferences.intervalMinutes = it }
    }

    /** 요약 저장 (null 이면 지움) > 켜져 있으면 알림 본문 갱신 */
    private fun updateSnapshot(json: String?) {
        preferences.snapshotJson = json
        if (preferences.isEnabled && LockScreenService.isRunning) {
            LockScreenNotification.repost(context, preferences)
        }
    }

    // 지난 쉬기 끝 시각은 0 (Dart 가 쉬는 중으로 보지 않게)
    private fun activePauseUntilMillis(): Long {
        val pauseUntilMillis = preferences.pauseUntilMillis
        return if (pauseUntilMillis > System.currentTimeMillis()) pauseUntilMillis else 0L
    }

    private fun packageUri(): Uri = Uri.parse("package:${context.packageName}")

    private fun notificationSettingsIntent(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri())
        }

    /** 삼성 절전 예외 목록 시도 > 배터리 화면 후보 3개 > 모두 실패면 앱 상세 설정 */
    private fun openSamsungPowerSettings() {
        val neverSleepingListIntent = Intent(SAMSUNG_ACTION_OPEN_CHECKABLE_LIST)
            .setPackage(SAMSUNG_DEVICE_CARE_PACKAGE)
            .putExtra(SAMSUNG_EXTRA_ACTIVITY_TYPE, SAMSUNG_ACTIVITY_TYPE_NEVER_SLEEPING)
        if (tryStart(neverSleepingListIntent)) return
        val candidates = listOf(
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
            ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        )
        for (component in candidates) {
            if (tryStart(Intent().setComponent(component))) return
        }
        openSettings(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri()))
    }

    private fun openSettings(intent: Intent) {
        if (!tryStart(intent)) tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri()))
    }

    /** 활동이 있으면 그 위에, 없으면 새 태스크로 시작 (없는 화면이면 false) */
    private fun tryStart(intent: Intent): Boolean {
        val activity = activityProvider()
        return try {
            if (activity != null) {
                activity.startActivity(intent)
            } else {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    companion object {
        const val CHANNEL_NAME = "elum/lock_screen"
        // 네이티브 > Dart 호출: 잠금화면 표시(잠금 엔진), 경로 열기(앱 엔진)
        const val METHOD_ON_SHOWN = "onShown"
        const val METHOD_OPEN_ROUTE = "openRoute"

        // 삼성 디바이스 케어: 앱 체크 목록 화면 액션·패키지, 목록 종류 extra (2 절전 예외 앱)
        private const val SAMSUNG_ACTION_OPEN_CHECKABLE_LIST =
            "com.samsung.android.sm.ACTION_OPEN_CHECKABLE_LISTACTIVITY"
        private const val SAMSUNG_DEVICE_CARE_PACKAGE = "com.samsung.android.lool"
        private const val SAMSUNG_EXTRA_ACTIVITY_TYPE = "activity_type"
        private const val SAMSUNG_ACTIVITY_TYPE_NEVER_SLEEPING = 2
    }
}
