import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Resolve GOOGLE_MAPS_API_KEY from Gradle property, local.properties, or root .env (never hardcoded).
fun resolveMapsApiKey(): String {
    val propKey = project.findProperty("GOOGLE_MAPS_API_KEY")?.toString()?.trim()
    if (!propKey.isNullOrEmpty()) return propKey

    val envVarKey = System.getenv("GOOGLE_MAPS_API_KEY")?.trim()
    if (!envVarKey.isNullOrEmpty()) return envVarKey

    val localPropsFile = rootProject.file("local.properties")
    if (localPropsFile.exists()) {
        val props = Properties()
        localPropsFile.inputStream().use { props.load(it) }
        val lpKey = props.getProperty("GOOGLE_MAPS_API_KEY")?.trim()
        if (!lpKey.isNullOrEmpty()) return lpKey
    }

    val rootEnvFile = rootProject.file("../.env")
    if (rootEnvFile.exists()) {
        rootEnvFile.readLines().forEach { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("GOOGLE_MAPS_API_KEY=")) {
                val value = trimmed.removePrefix("GOOGLE_MAPS_API_KEY=").trim()
                if (value.isNotEmpty()) return value
            }
        }
    }

    return ""
}

android {
    namespace = "si.marprom.m_mobilnost"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "si.marprom.m_mobilnost"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = resolveMapsApiKey()
    }

    buildTypes {
        release {
            // Signing with debug keys for clean local release builds; swap with keystore for Play Store.
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
