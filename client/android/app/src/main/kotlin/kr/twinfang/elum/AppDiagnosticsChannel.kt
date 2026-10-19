package kr.twinfang.elum

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * 의견 보내기 진단용 네이티브 값: 설치 경로, 서명 해시, 카카오톡 버전, 저전력 여부, 남은 저장 공간
 * 값마다 따로 읽고 실패한 값은 null (하나가 실패해도 나머지는 보낸다)
 */
object AppDiagnosticsChannel {
    const val CHANNEL_NAME = "elum/diagnostics"
    private const val KAKAO_TALK_PACKAGE = "com.kakao.talk"

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                if (call.method != "getDiagnostics") result.notImplemented()
                else result.success(readDiagnostics(context))
            }
    }

    private fun readDiagnostics(context: Context): Map<String, Any?> = mapOf(
        "installerPackage" to attempt { readInstallerPackage(context) },
        "signingKeyHashes" to attempt { readSigningKeyHashes(context) },
        "kakaoTalkVersion" to attempt { readKakaoTalkVersion(context) },
        "isPowerSaveMode" to attempt {
            (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isPowerSaveMode
        },
        "freeStorageBytes" to attempt { StatFs(context.filesDir.path).availableBytes },
    )

    private fun <T> attempt(read: () -> T): T? = try { read() } catch (_: Exception) { null }

    // Play 설치는 com.android.vending, 직접 설치(APK 공유, adb)는 빈 값
    private fun readInstallerPackage(context: Context): String {
        val packageName = context.packageName
        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.packageManager.getInstallSourceInfo(packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getInstallerPackageName(packageName)
        }
        return installer ?: ""
    }

    // 서명 인증서 SHA-1 > Base64 (카카오 개발자 콘솔 Android 키 해시와 같은 값)
    private fun readSigningKeyHashes(context: Context): List<String> {
        val packageManager = context.packageManager
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                context.packageName, PackageManager.GET_SIGNING_CERTIFICATES,
            )
            info.signingInfo?.apkContentsSigners?.toList() ?: emptyList()
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
                .signatures?.toList() ?: emptyList()
        }
        return signatures.map {
            Base64.encodeToString(
                MessageDigest.getInstance("SHA-1").digest(it.toByteArray()), Base64.NO_WRAP,
            )
        }
    }

    // 카카오톡 미설치는 빈 값 (매니페스트 queries 에 선언돼 있어야 조회된다)
    private fun readKakaoTalkVersion(context: Context): String = try {
        context.packageManager.getPackageInfo(KAKAO_TALK_PACKAGE, 0).versionName ?: ""
    } catch (_: PackageManager.NameNotFoundException) {
        ""
    }
}
