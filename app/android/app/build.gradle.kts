import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // Push notifications (Firebase Cloud Messaging). Analytics is deliberately
    // not added: the app promises not to track people (plan.md section 1).
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Maps key comes from the same dart-defines as everything else
// (.env via scripts/build-apk.ps1), so there is one place to set it. Flutter
// hands them to Gradle base64-encoded in the `dart-defines` property.
//
// A missing key does not fail the build: the app checks for the key itself and
// shows "NO MAPS KEY" rather than the SDK's silent blank tiles.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            val pair = String(Base64.getDecoder().decode(encoded)).split("=", limit = 2)
            if (pair.size == 2) pair[0] to pair[1] else null
        }
        ?.toMap()
        ?: emptyMap()

// The Play upload key, from android/key.properties (gitignored):
//   storeFile=C:/path/outside/the/repo/dadliplug-upload.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// Without it a release build still works for testing, signed with the debug
// key, and says so; the Play Console refuses debug-signed uploads.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}
val hasUploadKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.antiguamap.antigua_business_map"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once the app is on Play. Changing it also means
        // re-registering the Android app in Firebase (google-services.json) and
        // the Android OAuth client for Google sign-in.
        applicationId = "com.antiguamap.antigua_business_map"
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
        manifestPlaceholders["googleMapsApiKey"] = dartDefines["GOOGLE_MAPS_API_KEY"] ?: ""
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn("No android/key.properties: release is debug-signed and cannot go to Play.")
                signingConfigs.getByName("debug")
            }
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
