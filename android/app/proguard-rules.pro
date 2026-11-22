# Keep Flutter & Native MethodChannel classes intact under R8
-keep class io.flutter.** { *; }
-keep class com.moaz.focusstudiopro.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn java.awt.**
-dontwarn javax.naming.**

# Aggressive obfuscation
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''
