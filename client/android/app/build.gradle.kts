plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties file
import java.util.Properties
import java.io.FileInputStream
import java.io.InputStreamReader
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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 네이버 SDK는 AndroidManifest의 meta-data로 설정을 읽는다.
        // 값을 여기서 리소스로 만들어 넣으면 저장소에는 남지 않는다.
        resValue("string", "naver_client_id", env("ELUM_NAVER_CLIENT_ID"))
        resValue("string", "naver_client_secret", env("ELUM_NAVER_CLIENT_SECRET"))
        resValue("string", "naver_client_name", env("ELUM_NAVER_CLIENT_NAME"))

        // 카카오톡에서 돌아올 때 쓰는 커스텀 스킴. "kakao" + 네이티브 앱 키다.
        manifestPlaceholders["kakaoScheme"] = "kakao" + env("ELUM_KAKAO_NATIVE_APP_KEY")

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
        }
    }
}

flutter {
    source = "../.."
}
