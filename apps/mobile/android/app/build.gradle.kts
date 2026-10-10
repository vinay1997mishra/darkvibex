plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.darkvibex.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.darkvibex.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

flutter {
    source = "../.."
}
