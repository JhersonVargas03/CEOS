import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ceos.app.ceos_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ceos.app.ceos_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Signing configuration ─────────────────────────────────────────────────
    // CI/CD (GitHub Actions): reads from environment variables
    // Local dev: reads from android/key.properties  (not committed to git)
    // Fallback: uses debug keystore (only for local `flutter run --release`)
    signingConfigs {
        val envKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
        val bundledKeystore = file("ceos-release.jks")
        val localKeyProps = rootProject.file("key.properties")

        val effectiveStoreFile = when {
            !envKeystorePath.isNullOrBlank() && file(envKeystorePath).exists() && file(envKeystorePath).length() > 0 -> file(envKeystorePath)
            bundledKeystore.exists() && bundledKeystore.length() > 0 -> bundledKeystore
            else -> null
        }

        if (effectiveStoreFile != null) {
            create("release") {
                storeFile = effectiveStoreFile
                storePassword = System.getenv("ANDROID_STORE_PASSWORD")?.ifBlank { null } ?: "ceosclinico2024"
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")?.ifBlank { null } ?: "ceos"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")?.ifBlank { null } ?: "ceosclinico2024"
            }
        } else if (localKeyProps.exists()) {
            val props = Properties().apply { load(localKeyProps.inputStream()) }
            create("release") {
                storeFile = file(props.getProperty("storeFile", ""))
                storePassword = props.getProperty("storePassword", "")
                keyAlias = props.getProperty("keyAlias", "")
                keyPassword = props.getProperty("keyPassword", "")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false  // shrinkResources requiere minifyEnabled; los desactivamos juntos
        }
    }
}

flutter {
    source = "../.."
}

