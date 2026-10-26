---
name: android-release-build
description: Build this Flutter project's signed, obfuscated Android App Bundle and retain its Dart symbol files.
---

# Android release App Bundle

Use this workflow whenever building a release AAB for this project.

## Version

- Read the current `version:` in `pubspec.yaml` (`name+buildNumber`).
- Use a version and build number explicitly requested by the user when provided.
- Otherwise increment the patch version and build number by one, and update `pubspec.yaml` before building.
- Keep the `pubspec.yaml` version and the Flutter CLI build arguments in sync.

## Java environment

Flutter's Android Gradle wrapper can find Android Studio's bundled Java by itself, but Flutter's post-build AAB symbol validator (`apkanalyzer`) needs `JAVA_HOME` and Java on `PATH`. For this machine, use the installed JDK at `D:\Android\Java\jdk-17.0.20.1+1`.

In PowerShell, set the environment in the same process that runs Flutter:

```powershell
$env:JAVA_HOME = 'D:\Android\Java\jdk-17.0.20.1+1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

## Build

Replace the version and number below with the values chosen above:

```powershell
flutter build appbundle --release --build-name=1.0.53 --build-number=112 --obfuscate --split-debug-info=build/android-symbols/1.0.53-112
```

Always give each release a matching, unique symbol directory: `build/android-symbols/<version>-<buildNumber>`. Keep these symbol files so obfuscated crash reports can be symbolicated.

## Confirm completion

- Wait for Flutter to exit successfully and print `Built build\app\outputs\bundle\release\app-release.aab`.
- Report the AAB path, version/build number, and symbol directory.
- If the error says it failed to strip debug symbols after Gradle created the AAB, first confirm the JDK environment above. This project produced the required `.sym` files; the earlier failure was Flutter's `apkanalyzer` validator lacking Java environment variables.
- Do not run `flutter clean` routinely. Use it only when there is evidence of stale or corrupted generated build state, because it forces a slow full rebuild.
