buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory = file("../build")

subprojects {
    project.layout.buildDirectory = file("${rootProject.layout.buildDirectory.asFile.get().path}/${project.name}")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
