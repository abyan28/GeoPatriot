import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing rilis: baca dari key.properties (di-gitignore, tidak pernah
// ter-commit). Kalau file ini tidak ada (mis. clone baru tanpa keystore),
// releaseSigningProperties tetap null dan build release JATUH BALIK ke
// debug-signing (lihat buildTypes.release di bawah) supaya `flutter build
// apk --release` tidak gagal keras untuk kontributor lain.
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties: Properties? = if (keystorePropertiesFile.exists()) {
    Properties().apply { load(keystorePropertiesFile.inputStream()) }
} else {
    null
}

android {
    namespace = "com.geotagcamera.geotag_camera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.geotagcamera.geotag_camera"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningProperties != null) {
            create("release") {
                storeFile = file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Pakai keystore rilis asli kalau key.properties ada; kalau tidak
            // (mis. clone baru tanpa keystore), jatuh balik ke debug-signing
            // supaya `flutter build apk --release` tetap jalan untuk dev lain.
            signingConfig = if (releaseSigningProperties != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Pangkas kode Java/Kotlin & resource yang tidak terpakai.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
