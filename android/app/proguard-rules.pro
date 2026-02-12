# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# Preserve Dart VM Service Protocol classes
-keep class dev.flutter.** { *; }

# Lottie animations
-keep class com.airbnb.lottie.** { *; }

# Isar database
-keep class io.isar.** { *; }
-dontwarn io.isar.**

# Watch connectivity
-keep class dev.rexios.watch_connectivity.** { *; }

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Ignore warnings for Play Store split install (not used in this app)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# General ignore warnings for missing classes
-ignorewarnings
