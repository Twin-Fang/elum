# R8(릴리스 코드 축소) 규칙.
#
# debug 빌드는 R8을 돌리지 않는다. 그래서 여기 규칙이 없으면 릴리스 빌드에서만
# 터지고, 로컬 debug 빌드로는 절대 재현되지 않는다.

# --- OkHttp (카카오 SDK가 끌고 온다) ---
#
# OkHttp는 Conscrypt·BouncyCastle·OpenJSSE를 "있으면 쓰는" 선택적 의존성으로 참조한다.
# 실제로는 없어도 플랫폼 기본 TLS로 동작하지만, R8은 참조만 보고 클래스 누락으로 판단해
# 빌드를 멈춘다. 경고만 끄면 된다 — OkHttp 공식 권장 규칙이다.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**

# --- 카카오 로그인 SDK ---
#
# 응답 JSON을 리플렉션으로 매핑하므로 모델 필드 이름이 바뀌면 파싱이 조용히 실패한다.
-keep class com.kakao.sdk.**.model.* { <fields>; }
-keep class * extends com.google.gson.TypeAdapter

# --- 네이버 로그인 SDK ---
-keep public class com.navercorp.nid.** { *; }
-dontwarn com.navercorp.nid.**

# --- Retrofit + 코루틴 (네이버 로그인 SDK 가 토큰 교환에 쓴다, #446) ---
#
# 릴리스 빌드에서만 네이버 로그인이 실패했다(2026-09-29 실측). 네이버가 인증 코드를 정상 발급하고
# 앱까지 돌려줘도, SDK 의 토큰 교환(NidOAuthApi.requestAccessToken)이
#   ClassCastException: java.lang.Class cannot be cast to java.lang.reflect.ParameterizedType
# 으로 죽고 화면에는 `E-AUTH-SDK` 가 떴다. Retrofit 은 서비스 메서드의 **제네릭 시그니처**를
# 리플렉션으로 읽는데, R8 풀 모드가 그 정보를 지운다. 코루틴(suspend) 메서드는 반환 타입이
# Continuation 의 타입 인자에 들어 있어 더 취약하다. debug 빌드는 R8 을 돌리지 않아 재현되지 않는다.
#
# 아래는 Retrofit 공식 R8 규칙이다. SDK 가 끌고 온 Retrofit 의 소비자 규칙만으로는 부족했다.
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*
# R8 풀 모드는 Retrofit 인터페이스의 구현(Proxy)을 못 봐서 통째로 지운다 — 인터페이스를 지킨다.
-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface <1>
-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface * extends <1>
# 코루틴 suspend 메서드의 반환 타입은 Continuation 의 타입 인자에 들어 있다.
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
# 반환 타입의 제네릭이 지워지지 않게 한다.
-if interface * { @retrofit2.http.* public *** *(...); }
-keep,allowoptimization,allowshrinking,allowobfuscation class <3>
-keep,allowobfuscation,allowshrinking class retrofit2.Response
