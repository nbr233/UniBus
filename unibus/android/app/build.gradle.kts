plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase Google Services Plugin
    id("com.google.gms.google-services")
    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.reachad.unibus" // এটি তোমার applicationId এর সাথে মিল রাখা ভালো
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // তোমার Firebase কনসোলে দেওয়া অ্যাপ্লিকেশন আইডি
        applicationId = "com.reachad.unibus" 
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM (Bill of Materials) - লেটেস্ট ভার্সন ব্যবহার করা হয়েছে
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // Firebase Authentication
    implementation("com.google.firebase:firebase-auth")

    // Firebase Analytics (প্রয়োজন হলে)
    implementation("com.google.firebase:firebase-analytics")
}
