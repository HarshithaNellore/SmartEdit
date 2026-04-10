# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SharedPreferences
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep all standard flutter plugins (image_picker, etc)
-keep class io.flutter.plugins.** { *; }

# Keep file_picker plugin
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# image_picker Pigeon channels (fixes PlatformException on APK)
-keep class dev.flutter.pigeon.image_picker_android.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# video_player plugin
-keep class dev.flutter.pigeon.video_player_android.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }

# Firebase & Firestore
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# General: keep ALL Pigeon-generated code (prevents channel-error on APK)
-keep class dev.flutter.pigeon.** { *; }

# path_provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class dev.flutter.pigeon.path_provider_android.** { *; }

# shared_preferences Pigeon
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }

# Don't warn on play core classes
-dontwarn com.google.android.play.core.**

# Ignore warnings for missing Play Core classes referenced by Flutter
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
