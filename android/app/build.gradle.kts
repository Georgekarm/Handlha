import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val releaseStoreFilePath: String? =
    (keystoreProperties.getProperty("storeFile") ?: System.getenv("UPLOAD_STORE_FILE"))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
val releaseStorePassword: String? =
    (keystoreProperties.getProperty("storePassword") ?: System.getenv("UPLOAD_STORE_PASSWORD"))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
val releaseKeyAlias: String? =
    (keystoreProperties.getProperty("keyAlias") ?: System.getenv("UPLOAD_KEY_ALIAS"))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
val releaseKeyPassword: String? =
    (keystoreProperties.getProperty("keyPassword") ?: System.getenv("UPLOAD_KEY_PASSWORD"))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

val hasReleaseSigning =
    releaseStoreFilePath != null &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null &&
        rootProject.file(releaseStoreFilePath).exists()

val allowDebugReleaseSigning =
    project.findProperty("allowDebugReleaseSigning")?.toString()?.toBoolean() == true
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (isReleaseTaskRequested && !hasReleaseSigning && !allowDebugReleaseSigning) {
    throw org.gradle.api.GradleException(
        "Release signing is required for production builds. Configure android/key.properties " +
            "or UPLOAD_STORE_FILE / UPLOAD_STORE_PASSWORD / UPLOAD_KEY_ALIAS / UPLOAD_KEY_PASSWORD. " +
            "For local-only sideload testing, pass -PallowDebugReleaseSigning=true explicitly."
    )
}

android {
    namespace = "com.handelha.app"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required for flutter_local_notifications (java.time) on Android 7.x (API 24-25).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.handelha.app"
        // Uses Flutter's lowest supported SDK baseline (API 24 / Android 7.0+ on Flutter 3.35+)
        // covering older 32-bit armeabi-v7a and budget devices alongside Android 16 (API 36).
        minSdk = flutter.minSdkVersion
        // Explicitly target Android 16 (API 36) to meet Google Play target API requirements.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Use the official upload key when android/key.properties is configured,
            // or fall back to debug signing so local release APKs can be installed on a phone.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
