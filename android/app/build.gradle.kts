plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.motionshot.app"
    compileSdk = 35
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


    buildTypes {
        release {
            // Signed with the upload key configured in the release pipeline;
            // see docs/RELEASE.md.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
