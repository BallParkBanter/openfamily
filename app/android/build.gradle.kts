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

// bray piece 5: the geocoding_android plugin (3.3.1) still compiles against
// android-33 while its androidx dependencies (annotation-experimental 1.4.0,
// exifinterface 1.4.1, lifecycle-process 2.7.0, ...) need 34+. Compile every
// plugin's Android library against the app's own compileSdk instead of
// whatever the plugin shipped with. Remove once geocoding_android catches up.
subprojects {
    // Skip :app itself - other subprojects' evaluationDependsOn(":app") above
    // forces it to fully evaluate before we get here, and Gradle rejects
    // afterEvaluate on an already-evaluated project.
    if (name == "app") return@subprojects
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let { lib ->
            val appExtension =
                rootProject.project(":app").extensions
                    .findByType<com.android.build.gradle.BaseExtension>()
            val appSdk =
                appExtension?.compileSdkVersion
                    ?.removePrefix("android-")
                    ?.toIntOrNull()
                    ?: 36 // OPEN: chosen - fallback matches flutter.compileSdkVersion for Flutter 3.44 if the app extension isn't readable here
            if ((lib.compileSdk ?: 0) < appSdk) {
                lib.compileSdk = appSdk
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
