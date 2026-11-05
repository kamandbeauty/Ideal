# SubFlow release rules.
# Flutter's embedding, Media3 and the JNI facade are all referenced directly.

-keep class app.subflow.core.NativeCore { *; }
-keep class app.subflow.** { *; }
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Media3 / ExoPlayer reflectively loads extractors and renderers.
-dontwarn androidx.media3.**
-keep class androidx.media3.** { *; }

# sqflite / Flutter plugins are registered by name.
-keep class io.flutter.plugins.** { *; }
