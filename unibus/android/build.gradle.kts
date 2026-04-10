// ১. প্লাগিন ব্লকটি সবার উপরে থাকে
plugins {
    // এই আইডিটি এখানে ডিফাইন করা হয় যাতে সব সাব-প্রজেক্ট এটি চিনতে পারে
    id("com.google.gms.google-services") version "4.4.2" apply false
    // অন্যান্য প্লাগিন যদি থাকে...
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// বিল্ড ডিরেক্টরি সেটআপ (ফ্লাটারের ডিফল্ট কনফিগারেশন)
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