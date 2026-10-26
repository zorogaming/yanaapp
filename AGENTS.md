# Project build instructions

For Android release App Bundles, follow [.agents/skills/android-release-build/SKILL.md](.agents/skills/android-release-build/SKILL.md). In particular, set `JAVA_HOME` and prepend its `bin` directory to `PATH` in the same PowerShell process before invoking Flutter so the final `apkanalyzer` validation can run.
