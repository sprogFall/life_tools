import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.life_tools"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.life_tools"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!hasReleaseKeystore) return@create

            fun requireProp(name: String): String =
                keystoreProperties.getProperty(name)
                    ?: throw GradleException("android/key.properties 缺少 `$name`，无法进行 release 签名")

            storeFile = rootProject.file(requireProp("storeFile"))
            storePassword = requireProp("storePassword")
            keyAlias = requireProp("keyAlias")
            keyPassword = requireProp("keyPassword")
        }
    }

    buildTypes {
        release {
            // 为了支持“覆盖安装”，release 必须使用固定 keystore。
            // 若未配置 android/key.properties，则回退到 debug 签名（不同机器/CI 可能导致签名变化，进而无法覆盖安装）。
            signingConfig =
                if (hasReleaseKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications 依赖了部分 Java 8+ 标准库 API（如 java.time），需要开启 desugaring。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
