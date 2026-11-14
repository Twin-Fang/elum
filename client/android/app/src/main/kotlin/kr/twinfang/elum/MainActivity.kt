package kr.twinfang.elum

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import android.util.AtomicFile
import java.io.File
import java.util.UUID
import kr.twinfang.elum.lockscreen.LockScreenChannel
import kr.twinfang.elum.lockscreen.LockScreenRoutes

// 네이버 SDK가 요구하는 FragmentActivity를 유지한다.
class MainActivity : FlutterFragmentActivity() {
    // 잠금화면 채널: 새 intent 의 이동 경로를 Dart 에 바로 전달할 때 씀
    private var lockScreenChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 엔진 준비 전에 받아 둠 > Dart 시작 후 takePendingRoute 로 꺼냄
        rememberLockScreenRoute(intent)
        super.onCreate(savedInstanceState)
    }

    // 이미 떠 있을 때 잠금화면·알림에서 열림 > 경로를 Dart 로 바로 보냄
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra(LockScreenRoutes.EXTRA_ROUTE) ?: return
        intent.removeExtra(LockScreenRoutes.EXTRA_ROUTE)
        lockScreenChannel?.invokeMethod(LockScreenChannel.METHOD_OPEN_ROUTE, route)
            ?: run { LockScreenRoutes.pendingRoute = route }
    }

    private fun rememberLockScreenRoute(intent: Intent?) {
        val route = intent?.getStringExtra(LockScreenRoutes.EXTRA_ROUTE) ?: return
        intent.removeExtra(LockScreenRoutes.EXTRA_ROUTE)
        LockScreenRoutes.pendingRoute = route
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 하단 한 줄 광고 띠 팩토리 (#743). Dart NativeAd 의 factoryId 가 이 이름을 찾는다
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            StripNativeAdFactory.FACTORY_ID,
            StripNativeAdFactory(this),
        )
        AppDiagnosticsChannel.register(flutterEngine, this)
        lockScreenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LockScreenChannel.CHANNEL_NAME)
            .apply { setMethodCallHandler(LockScreenChannel(applicationContext) { this@MainActivity }) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elum/installation")
            .setMethodCallHandler { call, result ->
                if (call.method != "getInstallationId") { result.notImplemented() }
                else try {
                    // 백업 복원으로 이전 설치가 살아나지 않도록 백업 제외 경로를 쓴다.
                    val file = AtomicFile(File(noBackupFilesDir, "elum-installation-id"))
                    val id = if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) {
                        file.openRead().bufferedReader().use { it.readText() }.also { UUID.fromString(it) }
                    } else {
                        val created = UUID.randomUUID().toString()
                        val stream = file.startWrite()
                        try {
                            stream.write(created.toByteArray(Charsets.UTF_8))
                            file.finishWrite(stream)
                        } catch (error: Exception) { file.failWrite(stream); throw error }
                        created
                    }
                    result.success(id)
                } catch (error: Exception) {
                    result.error("E-INSTALL", "Installation marker unavailable", null)
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        lockScreenChannel?.setMethodCallHandler(null)
        lockScreenChannel = null
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, StripNativeAdFactory.FACTORY_ID)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
