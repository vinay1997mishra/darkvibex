# DarkVibeX Android signing

DarkVibeX uses package name `com.darkvibex.app`.

The GitHub Actions workflow can build a stable signed release APK when these repository secrets are configured:

- `ANDROID_KEYSTORE_B64`: base64-encoded JKS/keystore file
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Do not commit the keystore or passwords to Git.

After creating the permanent signing key, obtain the Google OAuth fingerprints with:

```bash
keytool -list -v -keystore darkvibex-release.jks -alias YOUR_ALIAS
```

Record the SHA-1 and SHA-256 fingerprints. Use the SHA-1 with the Android OAuth client for package `com.darkvibex.app`.

The debug APK continues to build even when signing secrets are absent. The signed release APK artifact is produced only when all four signing secrets are available.
Google Sign-In release validation uses the permanent DarkVibeX signing key and the Android OAuth client registered for package `com.darkvibex.app`.
