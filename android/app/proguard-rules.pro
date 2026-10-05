# R8 rules for the release build (Flutter's own rules are added by its Gradle plugin).
#
# Comic archives (v3): Commons Compress and junrar refer to optional libraries
# Unfurl doesn't ship. Zstandard is a codec comics never use; SLF4J's binder is
# optional, and junrar logs through SLF4J's no-op logger without it.
-dontwarn com.github.luben.zstd.**
-dontwarn org.slf4j.impl.**
