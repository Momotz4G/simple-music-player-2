plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.momotz4g.simplemusicplayer2"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // JNI: Build native isochronous USB transfer library
    externalNativeBuild {
        cmake {
            path = file("src/main/jni/CMakeLists.txt")
        }
    }

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
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true // 🚀 Enable MultiDex


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
            keepDebugSymbols.add("**/libpython.zip.so")
        }
    }
    // 🚀 Disable Lint to avoid File Locking errors
    lint {
        checkReleaseBuilds = false
        abortOnError = false
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
