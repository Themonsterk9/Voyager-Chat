# Flutter Engine & Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Prevent obfuscation of MainActivity
-keep class com.voyager.chat.MainActivity { *; }

# Plugin Keep Rules
-keep class com.tekartik.sqflite.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }

# Flutter generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Dontwarn for optional Play Core dependencies in Flutter engine
-dontwarn com.google.android.play.core.**
