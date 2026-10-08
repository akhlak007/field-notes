# Flutter and plugins keep JSON / JNI bindings if R8 is ever enabled.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.fieldnotes.field_notes.** { *; }
-dontwarn io.flutter.embedding.**
