pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // play-services-measurement 24.x 가 Kotlin metadata 2.4 로 컴파일됨 > 2.3 이상 필요 (#1038)
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
    // FCM 설정 파일(google-services.json)을 리소스로 변환
    id("com.google.gms.google-services") version "4.4.2" apply false
    // 크래시 수집(Crashlytics) 빌드 ID 주입·매핑 업로드 (업로드는 app/build.gradle.kts 에서 기본 끔)
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}

include(":app")
