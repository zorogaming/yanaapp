# flutter_application_1

Flutter app for Yana Worldwide Store.

## iOS IPA Build with GitHub Actions

This repository includes a GitHub Actions workflow for building a signed iOS `.ipa`:

- Workflow file: `.github/workflows/ios-ipa.yml`
- Manual run: `GitHub -> Actions -> Build iOS IPA -> Run workflow`
- Auto run: pushes to `main`

## Required GitHub Secrets

Add these repository secrets before running the workflow:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`
- `PROVISIONING_PROFILE_NAME`
- `APPLE_TEAM_ID`
- `KEYCHAIN_PASSWORD`

Detailed setup help is available in `.github/IOS_SIGNING_SECRETS.md`.

## Workflow Inputs

You can run the workflow manually with these inputs:

- `export_method`: `app-store`, `ad-hoc`, or `development`
- `build_name`: optional override for the iOS version name
- `build_number`: optional override for the iOS build number

If `build_name` and `build_number` are left empty, the workflow uses the values from `pubspec.yaml`.

## Output

After a successful run, GitHub Actions uploads:

- `ios-ipa`
- `ios-xcarchive`
