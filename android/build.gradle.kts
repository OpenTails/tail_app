allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
var flutterCompileSdkVersion = 36
subprojects {
    afterEvaluate {
        plugins.withType<com.flutter.gradle.FlutterPlugin> {
            configure<com.flutter.gradle.FlutterExtension> {
                flutterCompileSdkVersion = compileSdkVersion
            }
        }

        plugins.withType<com.android.build.gradle.BasePlugin> {
            configure<com.android.build.gradle.BaseExtension> {
                val current =
                    (compileSdkVersion ?: "android-1").substring(8).toInt()
                if (current < flutterCompileSdkVersion) {
                    compileSdkVersion(flutterCompileSdkVersion)
                }

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_21
                    targetCompatibility = JavaVersion.VERSION_21
                }
            }
        }

        plugins.withType<org.jetbrains.kotlin.gradle.plugin.KotlinBasePlugin> {
            configure<org.jetbrains.kotlin.gradle.dsl.KotlinBaseExtension> {
                jvmToolchain(21)
            }
        }

        plugins.withType<org.gradle.api.plugins.JavaBasePlugin> {
            configure<org.gradle.api.plugins.JavaPluginExtension> {
                toolchain {
                    languageVersion = JavaLanguageVersion.of(21)
                }
            }
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompilationTask<org.jetbrains.kotlin.gradle.dsl.KotlinJvmCompilerOptions>>()
            .configureEach {
                compilerOptions {
                    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                }
            }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core-ktx:1.18.0")
        force("org.jetbrains.kotlin:kotlin-stdlib:2.3.21")
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