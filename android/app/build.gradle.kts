import io.sentry.android.gradle.extensions.InstrumentationFeature
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("io.sentry.android.gradle") version "6.8.1"
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
keystoreProperties.load(FileInputStream(keystorePropertiesFile))
kotlin {
    compilerOptions {
        languageVersion =
            org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0
        // Optional: Set jvmTarget
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
android {
    namespace = "com.codel1417.tailApp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    defaultConfig {
        applicationId = "com.codel1417.tailApp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        getByName("release") {
            // Deactivate R8.
            isMinifyEnabled = false
            isShrinkResources = false
            ndk {
                debugSymbolLevel = "FULL"
            }
            signingConfig = signingConfigs.getByName("release")
        }
        getByName("debug") {
            isDebuggable = true
            signingConfig = if (file(keystorePropertiesFile).exists())
                signingConfigs
                    .getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.3.21")
    testImplementation("junit:junit:4.13.2")
    implementation("io.rebble.pebblekit2:client:1.1.0")
}

sentry {
    ignoredBuildTypes.set(setOf("debug"))
    org.set("floof")
    projectName.set("tail-app")
    authToken.set(System.getenv("SENTRY_AUTH_TOKEN"))
    url.set("https://glitchtip.codel1417.xyz")
    includeProguardMapping.set(true)
    autoUploadProguardMapping.set(true)
    includeNativeSources.set(true)
    includeSourceContext.set(true)
    tracingInstrumentation {
        enabled.set(true)
        features.set(setOf(InstrumentationFeature.DATABASE, InstrumentationFeature.FILE_IO, InstrumentationFeature.OKHTTP, InstrumentationFeature.COMPOSE))
        logcat {
            enabled.set(true)
            // Specifies a minimum log level for the logcat breadcrumb logging.
            // Defaults to LogcatLevel.WARNING.
            //minLevel.set(LogcatLevel.WARNING)
        }
    }
    // Enable auto-installation of Sentry components (sentry-android SDK and okhttp, timber, fragment and compose integrations).
    // Default is enabled.
    // Only available v3.1.0 and above.
    autoInstallation {
        enabled.set(false)
    }
    sizeAnalysis {
        enabled = providers.environmentVariable("GITHUB_ACTIONS").isPresent
    }
}