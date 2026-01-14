# JVM 目标兼容性修复说明

## 问题描述
在 GitHub Actions 构建过程中出现以下错误：
```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':receive_sharing_intent:compileDebugKotlin'.
> Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks
    Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks
      Inconsistent JVM-target compatibility detected for tasks 'compileDebugJavaWithJavac' (1.8) and 'compileDebugKotlin' (17).
```

## 根本原因
- Java 编译任务使用 JVM 1.8 目标
- Kotlin 编译任务使用 JVM 17 目标
- 这种不一致性导致了构建失败

## 解决方案
根据错误信息的建议，使用 JVM Toolchain 来统一管理 JVM 版本。

### 1. 修改 `android/gradle.properties`
添加 JVM Toolchain 自动配置：
```properties
# Enable JVM Toolchain to resolve JVM version compatibility issues
org.gradle.java.installations.auto-download=true
org.gradle.java.installations.auto-detect=true
```

### 2. 修改 `android/app/build.gradle.kts`
在 Android 配置中添加 JVM Toolchain：
```kotlin
android {
    namespace = "com.example.life_tools"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Configure JVM Toolchain to resolve Java/Kotlin version conflicts
    kotlin {
        jvmToolchain(17)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}
```

### 3. 修改 `android/build.gradle.kts`
为所有子项目（包括 receive_sharing_intent 等第三方插件项目）统一配置 JVM 17：
```kotlin
// Configure all subprojects to use JVM 17 to resolve compatibility issues
subprojects {
    afterEvaluate {
        // Configure Kotlin Android projects
        plugins.withId("org.jetbrains.kotlin.android") {
            project.extensions.findByName("android")?.let { androidExt ->
                androidExt as com.android.build.gradle.BaseExtension
                androidExt.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                androidExt.kotlinOptions {
                    jvmTarget = JavaVersion.VERSION_17.toString()
                }
            }
        }
        
        // Configure Kotlin JVM projects
        plugins.withId("org.jetbrains.kotlin.jvm") {
            project.extensions.findByName("kotlin")?.let { kotlinExt ->
                kotlinExt as org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension
                kotlinExt.jvmToolchain(17)
            }
        }
    }
}
```

## 技术原理
1. **JVM Toolchain**: Gradle 的 JVM Toolchain 特性允许自动检测和配置合适的 JDK 版本
2. **统一版本**: 确保所有 Java 和 Kotlin 编译任务使用相同的 JVM 目标版本（17）
3. **自动检测**: 启用自动下载和检测，确保构建环境使用正确的 JDK 版本
4. **全局配置**: 通过 `afterEvaluate` 确保配置在所有插件（包括第三方插件）应用后生效

## 预期效果
- 解决 Java 和 Kotlin 编译任务之间的 JVM 版本不一致问题
- 确保包括 receive_sharing_intent 在内的所有子项目使用统一的 JVM 17 目标
- 提高构建的稳定性和兼容性
- 符合现代 Gradle 构建最佳实践

## 测试验证
修改后可以通过以下方式验证：
```bash
flutter analyze  # 验证代码分析
flutter build apk --debug  # 验证 Android 构建（需要 Android SDK）
```

这些修改应该能够解决 GitHub Actions 中的构建错误。