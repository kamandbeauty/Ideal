import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}


// Optional real release keystore. CI writes android/key.properties from the
// ANDROID_KEYSTORE_* secrets; locally the file simply does not exist and the
// build falls back to the debug key (installable, but not store-ready).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "app.subflow"
    compileSdk = 34
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "app.subflow"
        // Android 8.0 / API 26 is the supported floor.
        minSdk = 26
        targetSdk = 34
        versionCode = 6
        versionName = "0.4.0"

        // ARM64 first; x86_64 is kept for the emulator only. 32-bit ARM is
        // deliberately excluded from Phase 1 because whisper.cpp models are
        // unreasonable on 2-3 GB devices (see docs/ARCHITECTURE.md).
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DSF_ENABLE_WHISPER=ON",
                )
                // No global -ffast-math / -O2 here: directory-level flags reach
                // the vendored whisper.cpp/ggml, which refuses -ffinite-math
                // (ggml-cpu/vec.h has a hard #error for it) and sets its own
                // optimisation per target. Our own sources get their flags from
                // CMakeLists.txt.
                cppFlags += listOf("-std=c++17")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Production keystore when available, otherwise the debug key so CI
            // can always produce an installable APK for device testing.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 stays off until its keep rules have been verified on a device;
            // shipping a minifier we have not tested would be an unverified claim.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Media3: playback (Phase 1), Transformer for the export engine (Phase 6).
    val media3Version = "1.4.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")
    implementation("androidx.media3:media3-transformer:$media3Version")
    implementation("androidx.media3:media3-effect:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")

    // Activity result contracts (Photo Picker) and misc Kotlin helpers.
    implementation("androidx.activity:activity-ktx:1.9.0")
    implementation("androidx.core:core-ktx:1.13.1")
}
