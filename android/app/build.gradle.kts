import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (gitignored), e.g.
//   storeFile=/absolute/path/to/bwiapps.jks
//   storePassword=...
//   keyAlias=key0
//   keyPassword=...
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.smartmedicare.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.smartmedicare.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // key.properties wins when present; otherwise fall back to the
            // bundled keystore (android/app/bwiapps.jks) used on build PCs.
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: "key0"
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: "BIDev@123"
            storeFile = file(keystoreProperties.getProperty("storeFile") ?: "bwiapps.jks")
            storePassword = keystoreProperties.getProperty("storePassword") ?: "BIDev@123"
        }
    }

    // direct = sideloaded APK with in-app auto-update (clinic tablets/PCs).
    // store  = Google Play bundle: no self-update, no REQUEST_INSTALL_PACKAGES
    //          (see src/store/AndroidManifest.xml); Play delivers updates.
    flavorDimensions += "distribution"
    productFlavors {
        create("direct") { dimension = "distribution" }
        create("store") { dimension = "distribution" }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
