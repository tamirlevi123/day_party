## Android Project Plan

**Created:** 2025-10-31

### Project Overview
Creating the Day Party Android app using Kotlin + Jetpack Compose, following MVVM architecture.

---

### Setup Steps

#### 1. Create Project in Android Studio
- **Template:** Empty Activity
- **Package Name:** `com.dayparty.app`
- **Language:** Kotlin
- **Minimum SDK:** API 24 (Android 7.0)
- **Build System:** Gradle (Kotlin DSL)
- **Compose:** Enable Jetpack Compose

#### 2. Project Structure
```
app/
├── src/
│   ├── main/
│   │   ├── java/com/dayparty/app/
│   │   │   ├── di/                    # Dependency Injection (Hilt)
│   │   │   ├── data/
│   │   │   │   ├── remote/            # API clients (Retrofit)
│   │   │   │   ├── local/             # Database (Room, if needed)
│   │   │   │   └── repository/        # Data repositories
│   │   │   ├── domain/
│   │   │   │   ├── model/             # Domain models
│   │   │   │   └── usecase/           # Business logic
│   │   │   ├── ui/
│   │   │   │   ├── theme/             # Compose theme
│   │   │   │   ├── common/            # Shared UI components
│   │   │   │   ├── auth/              # Auth screens
│   │   │   │   ├── home/              # Feed screens
│   │   │   │   ├── thread/            # Thread detail
│   │   │   │   ├── node/              # Node detail
│   │   │   │   └── profile/           # User profile
│   │   │   └── MainActivity.kt
│   │   └── res/
│   │       ├── values/                # Strings, colors, themes
│   │       └── drawable/              # Icons, images
├── build.gradle.kts                   # App-level Gradle
└── proguard-rules.pro
```

#### 3. Gradle Dependencies (build.gradle.kts)

```kotlin
dependencies {
    // Core Android
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    
    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")
    
    // ViewModel & StateFlow
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    
    // Dependency Injection - Hilt
    implementation("com.google.dagger:hilt-android:2.48")
    kapt("com.google.dagger:hilt-android-compiler:2.48")
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")
    
    // Networking - Retrofit & OkHttp
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    
    // Image Loading - Coil
    implementation("io.coil-kt:coil-compose:2.5.0")
    
    // Video - Media3
    implementation("androidx.media3:media3-exoplayer:1.2.0")
    implementation("androidx.media3:media3-ui:1.2.0")
    
    // Secure Storage
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // JSON
    implementation("com.google.code.gson:gson:2.10.1")
    
    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.02.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

kapt {
    correctErrorTypes = true
}
```

#### 4. Required Plugins (build.gradle.kts)

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("kotlin-kapt")
    id("dagger.hilt.android.plugin")
    id("kotlin-parcelize")
}
```

#### 5. API Configuration
- **Base URL:** `https://172.167.43.172/api`
- **Certificate Pin:** Self-signed cert (development only)
- **Headers:** `Authorization: Bearer <JWT>`

#### 6. Features to Implement (Priority Order)

**Phase 1: Core Infrastructure**
1. ✅ Project setup
2. Hilt DI configuration
3. Retrofit API client
4. Secure token storage (EncryptedSharedPreferences)
5. Theme system (Material 3 with Hebrew RTL support)

**Phase 2: Authentication**
1. Splash screen with auth check
2. OAuth flow (Google)
3. JWT token management
4. Deep linking configuration

**Phase 3: Core Features**
1. Home feed (topics/threads)
2. Thread detail with replies tree
3. Node detail with voting
4. Create/edit node
5. Vote functionality

**Phase 4: Advanced Features**
1. Search
2. My Activity
3. Profile/Settings
4. Notifications

---

### Android Manifest Configuration

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <application
        android:name=".Di.Application"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.DayParty"
        tools:targetApi="31">

        <!-- Main Activity -->
        <activity
            android:name=".ui.MainActivity"
            android:exported="true"
            android:screenOrientation="portrait"
            android:theme="@style/Theme.DayParty">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Deep Link for OAuth Callback -->
        <activity
            android:name=".ui.AuthCallbackActivity"
            android:exported="true"
            android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:scheme="dayparty"
                    android:host="auth"
                    android:pathPrefix="/callback" />
            </intent-filter>
        </activity>

    </application>

</manifest>
```

---

### Next Steps

1. **Open Android Studio**
2. **Create New Project** → Empty Activity
3. **Configure** with settings above
4. **Add dependencies** to build.gradle
5. **Sync Gradle**
6. **Create base structure**
7. **Implement Phase 1** features

---

### Notes
- RTL support: Compose automatically handles RTL when `android:supportsRtl="true"`
- Theme: Use Material 3 theming for modern UI
- Network: Handle self-signed certs in development (NetworkSecurityConfig)
- Icons: Use Material Icons Extended for UI elements

