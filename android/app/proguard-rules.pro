# ─── Play Core (split-install / deferred components) ────────────
# Flutter engine references these classes for dynamic delivery support.
# Since this app does NOT use dynamic feature modules / deferred components,
# these classes are absent from the classpath. Suppress the R8 hard-error.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ─── Flutter engine ──────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Firebase (firebase_core, firebase_messaging) ───────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── google_sign_in (Credential Manager, v7+) ───────────────────
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# ─── sign_in_with_apple ──────────────────────────────────────────
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# ─── mobile_scanner (ML Kit barcode scanning) ───────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# ─── video_player (ExoPlayer / Media3) ──────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# ─── flutter_local_notifications ────────────────────────────────
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

# ─── hive_flutter (reflection-free, but keep generated adapters) ─
-keep class ** extends com.hivedb.** { *; }
-keepclassmembers class * {
    @hive.HiveField <fields>;
}

# ─── flutter_secure_storage (Android Keystore) ──────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ─── dio / okhttp / okio (networking) ───────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ─── file_picker / image_picker / gal ───────────────────────────
-keep class androidx.exifinterface.** { *; }
-dontwarn androidx.exifinterface.**

# ─── app_links / deep linking ────────────────────────────────────
-keep class com.llfbandit.app_links.** { *; }

# ─── General Android/Kotlin housekeeping ────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn org.jetbrains.annotations.**

# Keep native method names (JNI, used indirectly by several plugins)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable CREATORs (common source of runtime crashes under R8)
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep enums (enum.values()/valueOf() are reflection-sensitive)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
