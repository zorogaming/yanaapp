GitHub Actions me signed `.ipa` build chalane ke liye ye repository secrets add karein:

- `BUILD_CERTIFICATE_BASE64`
  - Apple Distribution certificate ka `.p12` file base64 me.
- `P12_PASSWORD`
  - `.p12` export karte waqt jo password diya tha.
- `BUILD_PROVISION_PROFILE_BASE64`
  - iOS provisioning profile `.mobileprovision` ka base64.
- `PROVISIONING_PROFILE_NAME`
  - Apple Developer portal me provisioning profile ka exact naam.
- `APPLE_TEAM_ID`
  - Apple Developer Team ID.
- `KEYCHAIN_PASSWORD`
  - GitHub Actions temporary keychain ke liye koi strong random password.

PowerShell se base64 banane ke examples:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\dist-cert.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\profile.mobileprovision"))
```

Recommended GitHub repo secrets path:

`Repository -> Settings -> Secrets and variables -> Actions -> New repository secret`
