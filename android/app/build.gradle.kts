import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/RELEASE.md): the key lives in android/key.properties,
// committed so the CI pipeline can sign. Missing file -> debug key fallback,
// so local `flutter build apk --release` profiling keeps working.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.motionshot.app"
    // androidx.core 1.18+ (transitive) requires compileSdk 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf("-opt-in=kotlin.RequiresOptIn")
    }

    defaultConfig {
        applicationId = "com.motionshot.app"
        // 24 keeps the Android Photo Picker availability high while still
        // allowing a document-picker fallback on older devices.
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        vectorDrawables.useSupportLibrary = true
        // The native renderer is written in Kotlin only; no NDK code needed.
        // The JVM conformance tests read the same golden vectors as the Python
        // reference and the Dart preview.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    testOptions {
        unitTests.all {
            it.useJUnit()
            it.maxHeapSize = "2g"
            // Conformance failures must fail the build, never be swallowed.
            it.testLogging { events("failed", "skipped") }
        }
    }


    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storeType = "pkcs12"
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8/resource shrinking off for the first release cut: the
            // plugin set (video_player, just_audio, sqflite, image_picker)
            // is untested under shrinking. Revisit once the release build
            // is proven stable on device.
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    packaging {
        resources.excludes += setOf(
            "META-INF/DEPENDENCIES",
            "META-INF/LICENSE*",
            "META-INF/NOTICE*"
        )
    }

    sourceSets["main"].java.srcDirs("src/main/kotlin")
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.annotation:annotation:1.8.2")
    implementation("androidx.concurrent:concurrent-futures-ktx:1.2.0")
    // FileProvider for sharing exports; also used indirectly by the picker.
    implementation("androidx.activity:activity-ktx:1.9.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
