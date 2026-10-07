package kr.twinfang.elum

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.AtomicFile
import java.io.File
import java.util.UUID

// 네이버 SDK가 요구하는 FragmentActivity를 유지한다.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
