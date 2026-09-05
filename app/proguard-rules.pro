# Keep kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.ideal.woomanager.**$$serializer { *; }
-keepclassmembers class com.ideal.woomanager.data.model.** { *; }

# Retrofit
-keepattributes Signature, Exceptions
-keep class retrofit2.** { *; }
-keepclasseswithmembers interface * { @retrofit2.http.* <methods>; }
