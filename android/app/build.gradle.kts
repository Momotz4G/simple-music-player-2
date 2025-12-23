plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.momotz4g.simplemusicplayer2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // 🚀 Enable Desugaring
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.momotz4g.simplemusicplayer2"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true // 🚀 Enable MultiDex

        // 🚀 Required for youtubedl-android
        ndk {
            abiFilters += listOf("x86", "x86_64", "armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // 🚀 Fix for llvm-strip error on libffmpeg.zip.so
    packaging {
        jniLibs {
            keepDebugSymbols.add("**/libffmpeg.zip.so")
            keepDebugSymbols.add("**/libyoutubedl_android.so")
            keepDebugSymbols.add("**/libmetadata_god.so")
        }
    }
}

flutter {
    source = "../.."
}

// 🚀 youtubedl-android dependencies
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3") // 🚀 Desugaring Lib
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}
