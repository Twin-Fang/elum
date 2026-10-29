plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties file
import java.util.Properties
import java.io.FileInputStream
import java.io.InputStreamReader
import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 소셜 로그인 키를 .env에서 읽는다.
//
// 카카오 리다이렉트 스킴과 네이버 SDK 설정은 **빌드 타임에 필요해서**
// flutter_dotenv로는 주입할 수 없다. 그렇다고 strings.xml에 적으면 시크릿이
// 저장소에 커밋된다. .env(커밋 제외)를 읽어 resValue·manifestPlaceholders로 넣는다.
//
// UTF-8로 읽어야 한글 서비스명이 깨지지 않는다(Properties 기본은 ISO-8859-1).
val envFile = rootProject.file("../.env")
val envProps = Properties()
if (envFile.exists()) {
    InputStreamReader(FileInputStream(envFile), Charsets.UTF_8).use { envProps.load(it) }
}
fun env(key: String): String = envProps.getProperty(key)?.trim() ?: ""


// Kotlin 2.3 부터 kotlinOptions.jvmTarget 문자열 지정이 오류 > compilerOptions DSL (#1038)
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

android {

    // Signing Configurations
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    namespace = "kr.twinfang.elum"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 예약 알림이 java.time 을 쓴다 — 옛 안드로이드용 desugaring (#777)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 네이버 SDK는 AndroidManifest의 meta-data로 설정을 읽는다.
        // 값을 여기서 리소스로 만들어 넣으면 저장소에는 남지 않는다.
        resValue("string", "naver_client_id", env("ELUM_NAVER_CLIENT_ID"))
        resValue("string", "naver_client_secret", env("ELUM_NAVER_CLIENT_SECRET"))
        resValue("string", "naver_client_name", env("ELUM_NAVER_CLIENT_NAME"))

        // 카카오톡에서 돌아올 때 쓰는 커스텀 스킴. "kakao" + 네이티브 앱 키다.
        manifestPlaceholders["kakaoScheme"] = "kakao" + env("ELUM_KAKAO_NATIVE_APP_KEY")

        // AdMob 앱 ID. 비면 SDK가 시작하다 죽으므로 Google 테스트 앱 ID를 기본값으로 둔다.
        manifestPlaceholders["admobAppId"] =
            env("ELUM_ADMOB_ANDROID_APP_ID").ifEmpty { "ca-app-pub-3940256099942544~3347511713" }

        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.twinfang.elum"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 릴리스 빌드는 R8로 코드를 축소한다. 소셜 로그인 SDK가 끌고 오는
            // OkHttp가 선택적 의존성을 참조해 규칙 없이는 빌드가 실패한다.
            // debug 빌드로는 재현되지 않으므로 여기를 비워두면 배포에서만 터진다.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Crashlytics R8 매핑 업로드: 기본 끔, -PelumCrashlyticsMappingUpload=true 일 때만 (#659)
            // 운영 수집이 꺼져 있고, 업로드 실패(네트워크·Firebase 설정 없음)로 배포 빌드가 깨지지 않게
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled =
                    project.findProperty("elumCrashlyticsMappingUpload")?.toString() == "true"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
