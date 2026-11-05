# Flutter engine entry points
-keep class io.flutter.** { *; }
-keep class com.motionshot.app.** { *; }

# The bridge and renderer are reached only through reflection-free channels,
# but keep their signatures so the obfuscator does not rename channel names.
-keepclassmembers class com.motionshot.app.NativeBridge {
    public *;
}

# MediaCodec / MediaMuxer are platform APIs, nothing to keep, but the render
# thread classes are started by name in some OEM builds.
-keep class com.motionshot.app.motion.** { *; }
