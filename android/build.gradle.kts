// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    // This was corrected in the previous step
    val kotlin_version = "1.9.23"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// THIS IS THE SECTION THAT FIXES THE NEW ERRORS
rootProject.layout.buildDirectory.set(rootProject.file("../build"))
subprojects {
    project.layout.buildDirectory.set(
        rootProject.layout.buildDirectory.dir(project.name)
    )
}
subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}