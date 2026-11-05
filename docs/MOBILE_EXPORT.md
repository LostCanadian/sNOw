# Command-line mobile exports

Use Python 3.9 or newer. No Godot editor window is needed. On Windows replace `python3` with `py -3` in the commands below.

```sh
python3 tools/export_mobile.py android
python3 tools/export_mobile.py ios --team-id ABCDE12345
```

Android defaults to a debug APK at `build/android/sNOw-debug.apk`. iOS defaults to an Xcode project at `build/ios/sNOw.xcodeproj`. The script downloads the pinned Godot **4.6.3** editor and matching platform templates when missing, using the same verified portable installer as `play_web.py`. The template archive is approximately 1.2 GB; cached downloads are reused and only the requested platform files are extracted.

An Android SDK/JDK or macOS/Xcode must already be installed. These platform tools, signing accounts and credentials cannot be replaced by a Godot export script. `--check` checks readiness without downloads or exports:

```sh
python3 tools/export_mobile.py android --check
python3 tools/export_mobile.py ios --team-id ABCDE12345 --check
```

## Android setup without the Godot UI

Install **OpenJDK 17** (recommended; newer supported JDKs also work) and the Android SDK. Set `JAVA_HOME` to the JDK folder and `ANDROID_HOME` to the SDK folder. Alternatively pass `--java-home` and `--android-sdk`; standard SDK locations and the `java` executable are also detected.

If using Android Studio, install the packages below with its SDK Manager. If using the official [Android command-line tools](https://developer.android.com/tools), extract them under `<sdk>/cmdline-tools/latest/` and run:

```sh
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;35.0.1" "platforms;android-35"
```

For AAB/Gradle builds also install:

```sh
sdkmanager --sdk_root="$ANDROID_HOME" "ndk;28.1.13356709" "cmake;3.10.2.4988404"
```

Complete the SDK's license prompts (`sdkmanager --licenses` if needed). Package versions follow the [Godot 4.6 Android requirements](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html). The script configures Godot's SDK/JDK export settings headlessly and generates/reuses its local debug signing key. No release key is required for a debug APK.

```sh
# Export an installable test APK.
python3 tools/export_mobile.py android

# Export and install onto a connected, authorized USB-debugging device.
python3 tools/export_mobile.py android --install

# Pick a device if several are connected.
python3 tools/export_mobile.py android --install --device DEVICE_SERIAL
```

You can also transfer the APK to the phone and open it through Android's file installer. `--install` requires a USB-debugging connection; manual file installation does not.

## Signed Android releases and Play bundles

Set these environment variables in your shell or CI secret settings, keeping the signing key outside the checkout:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: path to the release `.jks` / `.keystore` file.
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: key alias.
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: key/keystore password.

Then:

```sh
python3 tools/export_mobile.py android --release --build-number 2
python3 tools/export_mobile.py android --format aab --build-number 2
```

Outputs are `build/android/sNOw-release.apk` or `build/android/sNOw-release.aab`. AAB selects release mode automatically and installs the matching Android Gradle build template into the temporary build copy. Its first build downloads Gradle dependencies. Use the APK for direct installation and the AAB for Google Play. `--install` accepts APKs only.

Keep `--bundle-id` and the signing key stable, and increase `--build-number` for distributed updates. Example:

```sh
python3 tools/export_mobile.py android --release --bundle-id com.lostcanadian.snow --version 0.2.0 --build-number 3
```

## iOS project and IPA exports

Run on **macOS with full Xcode and the iOS SDK installed**. Select Xcode with `xcode-select` and complete its first-launch setup. Supply your 10-character Apple team ID with `--team-id`, or set `SNOW_IOS_TEAM_ID`. The default exports project files; it does not claim to produce an installable IPA:

```sh
python3 tools/export_mobile.py ios --team-id ABCDE12345
```

For a signed IPA, configure the Apple signing account/certificates/profiles on the Mac and provide an Xcode `ExportOptions.plist` appropriate to the distribution method:

```sh
python3 tools/export_mobile.py ios --team-id ABCDE12345 --format ipa --export-options /path/to/ExportOptions.plist
```

This creates the Xcode project, runs `xcodebuild archive`, and runs `xcodebuild -exportArchive` with that plist. IPA mode uses a release build. Outputs include `build/ios/sNOw.xcarchive` and the signed `.ipa` under `build/ios/ipa/`. Xcode validates signing and device/distribution eligibility; the script cannot create Apple credentials or register testers. Use a plist generated for your current Xcode/account, or construct one using `xcodebuild -help`. See [Godot's iOS requirements](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html).

## Options and build isolation

- `--godot /path/to/godot` uses an existing **4.6.3 stable** editor. Use `--templates-dir /path/to/4.6.3.stable` to select an existing native template folder.
- `--output /path/game.apk` or `/path/game.aab` selects an Android output file; `--output /path/ios-build` selects an iOS output directory.
- `--no-download` disables automatic Godot/template downloads. It does not put Gradle/Xcode into offline mode.
- `--check` performs prerequisite checks only. Signing identities/provisioning are validated by Xcode during the actual build.
- `--help` lists all options.

Exports use a temporary copy under ignored `build/`; the checkout's presets, sources and Web export remain untouched. Staging copies are removed on success or failure. SDK paths and public app metadata are written into the build configuration; release signing credentials are passed through the environment. Android packages are validated before replacing a previous output. Godot settings/debug keys use the portable installer's ignored cache on Windows/Linux and Godot's standard user directories on macOS.

## Validation

Python tests cover target/format selection, SDK and signing errors, platform restrictions, template extraction, staging isolation, package publication/failure preservation, and Xcode command construction. A real Godot run verifies the setup helper writes typed presets, SDK settings and native texture-import settings without changing the checkout. Menu checks cover the speaker entry and audio panel.

An Android debug APK has been built with the installed SDK, with signing and alignment verified. Native touch/menu regressions exercise real input dispatch, independent simultaneous gameplay contacts and pause/resume. Movement-arrow touch areas extend above, below and beside the visible buttons, meeting halfway between the arrows without overlapping each other or the Whirlwind target. The artwork stays the same size. Phone performance still needs device measurements; AAB and signed IPA builds have not been validated here. Prerequisite checks report missing platform tools before downloading Godot/templates.
