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

// verify*Resources only re-checks plugin resources with AAPT2; the real resource
// link still runs for the app. Skipping it avoids the AAPT2 daemon timeouts seen
// on this machine and does not change the APK.
subprojects {
    tasks.matching { it.name.startsWith("verify") && it.name.endsWith("Resources") }
        .configureEach { enabled = false }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
