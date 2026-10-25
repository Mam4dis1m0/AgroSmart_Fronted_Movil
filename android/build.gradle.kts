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

// Arreglo: another_telephony compila Java en 11 y Kotlin en 1.8 (Gradle 9 no lo permite).
// Se fuerza Java 1.8 para que coincida con su Kotlin.
subprojects {
    if (project.name == "another_telephony") {
        afterEvaluate {
            extensions.findByName("android")?.let { ext ->
                (ext as com.android.build.gradle.BaseExtension).compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}