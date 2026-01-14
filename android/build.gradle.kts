allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}