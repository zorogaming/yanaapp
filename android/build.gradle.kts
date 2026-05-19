import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val isolatedBuildRoot: Directory =
    rootProject.layout.projectDirectory
        .dir("../build2")

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val defaultSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(defaultSubprojectBuildDir)

    if (project.name in setOf("firebase_core", "firebase_messaging")) {
        val isolatedSubprojectBuildDir: Directory = isolatedBuildRoot.dir(project.name)
        project.layout.buildDirectory.value(isolatedSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(isolatedBuildRoot)
}
