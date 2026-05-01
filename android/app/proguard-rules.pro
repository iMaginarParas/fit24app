# ProGuard rules for Fit24
# ─────────────────────────────────────────────────────────────────────────────

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / HTTP / JSON
-keep class com.google.gson.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }

# Health Connect
-keep class androidx.health.connect.client.** { *; }

# Prevent obfuscation of model classes (if any are native)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep the StepCounterService and BootReceiver
-keep class com.fit24app.StepCounterService { *; }
-keep class com.fit24app.BootReceiver { *; }

# Don't warn about missing classes from Play Core (Deferred Components)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Health Connect
-dontwarn androidx.health.connect.client.**
