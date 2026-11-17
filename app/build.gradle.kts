plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.handelha.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.aistudio.handelha.m7k2qp"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

// Temporary sync task before Flutter cleanup so bundled IBMPlexSansArabic fonts exist in res/font
val syncLocalFonts by tasks.registering(Copy::class) {
    val sourceFonts = rootProject.file("assets/fonts")
    onlyIf { sourceFonts.exists() }
    from(sourceFonts) {
        include("*.ttf")
        rename { fileName ->
            when (fileName) {
                "IBMPlexSansArabic-Light.ttf" -> "ibm_plex_sans_arabic_light.ttf"
                "IBMPlexSansArabic-Regular.ttf" -> "ibm_plex_sans_arabic_regular.ttf"
                "IBMPlexSansArabic-Medium.ttf" -> "ibm_plex_sans_arabic_medium.ttf"
                "IBMPlexSansArabic-SemiBold.ttf" -> "ibm_plex_sans_arabic_semibold.ttf"
                "IBMPlexSansArabic-Bold.ttf" -> "ibm_plex_sans_arabic_bold.ttf"
                else -> fileName.lowercase()
            }
        }
    }
    into(layout.projectDirectory.dir("src/main/res/font"))
}

tasks.named("preBuild") {
    dependsOn(syncLocalFonts)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material3.window.size)
    implementation(libs.androidx.material.icons.extended)

    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.google.material)

    debugImplementation(libs.androidx.ui.tooling)
}
