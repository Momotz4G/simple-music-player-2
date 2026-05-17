allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for old plugins that don't declare a namespace (required by AGP 8+)
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                if (android.namespace.isNullOrEmpty()) {
                    android.namespace = project.group.toString().ifEmpty {
                        "com.flutter.${project.name.replace("-", "_")}"
                    }
                }
                // Force old plugins to compile against modern SDK
                if (android.compileSdkVersion != "android-36") {
                    android.compileSdkVersion(36)
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
