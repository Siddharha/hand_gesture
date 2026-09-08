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
// Pin every module - app and plugins alike - to the same JVM target.
//
// Plugins that never set a Kotlin jvmTarget inherit whatever JDK Gradle happens
// to run on (21 here), while their Java target stays at the AGP default. Kotlin
// 2.x rejects that mismatch outright: `tflite_flutter` fails to compile with
// "Inconsistent JVM-target compatibility ... (11) and (21)". Aligning both ends
// on 17 keeps plugin builds reproducible across machines with different JDKs.
//
// This must stay above the evaluationDependsOn block below, which evaluates
// :app eagerly and would make a later afterEvaluate hook illegal.
subprojects {
    // Registered here, from the root project, so it lands ahead of the hooks AGP
    // installs when a plugin module applies it: a plugin's own
    // `android { compileOptions }` runs in its script body, and AGP reads the
    // value in a later afterEvaluate, so this is the window where overriding it
    // actually sticks.
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
