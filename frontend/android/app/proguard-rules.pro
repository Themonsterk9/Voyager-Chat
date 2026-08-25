# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Prevent obfuscation of MainActivity
-keep class com.voyager.chat.MainActivity { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Flutter generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Dontwarn for optional Play Core dependencies in Flutter engine
-dontwarn com.google.android.play.core.**
