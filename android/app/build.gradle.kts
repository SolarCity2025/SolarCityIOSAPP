import kotlin.io.path.exists
import kotlin.jvm.java
import java.util.Properties // For java.util.Properties
import java.io.FileInputStream // For java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
// In android/app/build.gradle.kts

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

android {
    namespace = "com.solarcityuk.solar_city_v2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // ADD THIS SIGNING CONFIGS BLOCK
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile")) // Make sure file() is used here
                storePassword = keystoreProperties.getProperty("storePassword")
            } else {
                // This part is a fallback, ideally key.properties should always exist for a release build.
                println("Warning: key.properties not found. Release build may not be signed correctly.")
                // For CI or environments where signing isn't needed, you might use debug signing here.
                // For actual release, this 'else' block should ideally not be hit.
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.solarcityuk.solar_city_v2"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") { // Changed from 'release {' to 'getByName("release") {' for clarity with Kotlin DSL
            // TODO: Add your own signing config for the release build. // This comment can stay or go
            // Signing with the debug keys for now, so `flutter run --release` works. // This comment is now outdated
            // signingConfig = signingConfigs.getByName("debug") // <<< COMMENT OUT OR DELETE THIS OLD LINE
            signingConfig = signingConfigs.getByName("release") // <<< ADD THIS NEW LINE

            // Optional: You might want to enable code shrinking and obfuscation here
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
