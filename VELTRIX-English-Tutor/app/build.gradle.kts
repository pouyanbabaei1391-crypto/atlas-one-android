plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.jetbrains.kotlin.android)
}
android {
    namespace = "ai.veltrix.tutor"
    compileSdk = 36
    defaultConfig {
        applicationId = "ai.veltrix.tutor"
        minSdk = 33
        targetSdk = 35
        versionCode = 3
        versionName = "3.0.0"
        ndk { abiFilters += listOf("arm64-v8a") }
    }
    buildTypes {
        debug { isMinifyEnabled = false }
        release { isMinifyEnabled = false; isShrinkResources = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin { jvmToolchain(17) }
    packaging { jniLibs { useLegacyPackaging = true } }
}
dependencies {
    implementation(project(":lib"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.coroutines.android)
}
