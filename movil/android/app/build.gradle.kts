import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Signing configuration ──────────────────────────────────────────────────────
// Priority: Environment variables (CI/CD) > keystore.properties (local dev)
val keystoreFile: File?
val keystorePassword: String?
val keyAlias: String?
val keyPassword: String?

val envKeystore = System.getenv("ANDROID_KEYSTORE_PATH")
if (envKeystore != null) {
    // Running in GitHub Actions – keystore written from secret
    keystoreFile = file(envKeystore)
    keystorePassword = System.getenv("ANDROID_STORE_PASSWORD") ?: ""
    keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "ceos"
    keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
} else {
    // Local development – read from keystore.properties (not committed)
    val propsFile = rootProject.file("keystore.properties")
    if (propsFile.exists()) {
        val props = Properties().apply { load(propsFile.inputStream()) }
        keystoreFile = file(props.getProperty("storeFile") ?: "")
        keystorePassword = props.getProperty("storePassword")
        keyAlias = props.getProperty("keyAlias")
        keyPassword = props.getProperty("keyPassword")
    } else {
        keystoreFile = null
        keystorePassword = null
        keyAlias = null
        keyPassword = null
    }
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

    signingConfigs {
        if (keystoreFile != null && keystoreFile.exists()) {
            create("release") {
                storeFile = keystoreFile
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            val hasSigning = keystoreFile != null && keystoreFile.exists()
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

