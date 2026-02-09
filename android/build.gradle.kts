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

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.findByName("android") ?: return@withPlugin
        val getNamespaceMethod =
            androidExtension.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            } ?: return@withPlugin
        val setNamespaceMethod =
            androidExtension.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            } ?: return@withPlugin

        val currentNamespace = getNamespaceMethod.invoke(androidExtension) as? String
        if (!currentNamespace.isNullOrBlank()) return@withPlugin

        val fallbackNamespace =
            project.group
                .toString()
                .takeIf { it.isNotBlank() && it.contains('.') }
                ?: "com.life_tools.${project.name.replace(Regex("[^A-Za-z0-9_]"), "_")}"
        setNamespaceMethod.invoke(androidExtension, fallbackNamespace)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
