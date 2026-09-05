plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nouri.nouri"

    // 37, not the 35 originally planned: flutter_local_notifications requires
    // 36+ and permission_handler_android requires 37+. compileSdk only says
    // which APIs we compile against — targetSdk below still governs runtime
    // behaviour, so this does not change how the app behaves on the device.
    //
    // The minor version is required. Android SDK 37 ships as a minor-versioned
    // platform: it installs to platforms/android-37.0 and reports
    // AndroidVersion.ApiLevel=37.0. Setting compileSdk alone makes AGP look for
    // the plain hash "android-37", which does not exist, and the build fails
    // with "Failed to find target with hash string 'android-37'".
    compileSdk = 37
    compileSdkMinor = 0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications, which uses java.time on
        // minSdk levels that predate it. Without this the build fails at
        // :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.nouri.nouri"
        // minSdk 26 gives us native notification channels and keeps every
        // legacy notification code path out of the app.
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backports java.time and friends to older Android versions. Paired with
    // isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
