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
