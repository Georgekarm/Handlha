# Flutter wrapper & engine rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes *Annotation*

# Keep native JNI & method channel bridges
-keepclasseswithmembernames class * {
    native <methods>;
}

# flutter_local_notifications receivers & Gson models
-keep class com.dexterous.** { *; }

# speech_to_text & flutter_tts
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }

# RevenueCat / Play Billing
-keep class com.revenuecat.purchases.** { *; }
-keep class com.android.billingclient.** { *; }

# Secure storage, Tink / Security Crypto & enums
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class com.google.crypto.tink.** { *; }
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
