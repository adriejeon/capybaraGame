# 카카오 SDK 난독화 방지 규칙
-keep class com.kakao.sdk.** { *; }
-keep interface com.kakao.sdk.** { *; }
-dontwarn com.kakao.sdk.**

# OkHttp (카카오 SDK 의존성)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit (카카오 SDK가 사용할 수 있음)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# Gson (JSON 파싱용)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 공유 기능 관련
-keep class * extends android.content.ContentProvider
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

