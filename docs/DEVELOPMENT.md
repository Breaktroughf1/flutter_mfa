# Development setup (Debian / Ubuntu)

How to set up a Linux workstation to develop, test and release flutter_mfa. It matches what CI runs (`.github/workflows/ci.yml`). [CONTRIBUTING.md](../CONTRIBUTING.md) has the workflow rules; this file is the machine setup.

## 1. System packages

```bash
sudo apt update
sudo apt install -y git curl unzip xz-utils zip openjdk-17-jdk python3 python3-venv chromium
```

Java 17 is what CI uses for the Android build. Chromium (or Google Chrome) runs the browser tests. If the Chrome binary is not on `PATH` as `google-chrome` or `chromium`, set `CHROME_EXECUTABLE`.

## 2. Flutter (pinned)

CI pins Flutter **3.47.8** (`FLUTTER_VERSION` in `ci.yml`). Analyzer output and goldens must match it, so use the same version.

```bash
git clone https://github.com/flutter/flutter.git ~/sdk/flutter
cd ~/sdk/flutter && git checkout 3.47.8
echo 'export PATH="$HOME/sdk/flutter/bin:$HOME/.pub-cache/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter --version && flutter doctor
```

Optional, for the minimum-SDK check (Flutter **3.35.7**, the supported floor):

```bash
git clone https://github.com/flutter/flutter.git ~/sdk/flutter-3.35 && (cd ~/sdk/flutter-3.35 && git checkout 3.35.7)
```

## 3. The workspace

```bash
git clone https://github.com/Breaktroughf1/flutter_mfa && cd flutter_mfa
dart pub global activate melos     # Melos 8.x
flutter pub get                    # resolves all packages (one root pubspec.lock)
melos run verify                   # format, analyze, guards, all tests + coverage gates
```

Daily loop:

| Command | Use |
|---|---|
| `melos run test:core` | Fastest loop for `flutter_mfa_core` |
| `melos run test` | All unit, widget and browser tests |
| `melos run coverage` | Tests plus the coverage gates (core 95/90, others 85/75) |
| `melos run analyze` / `melos run format:check` / `melos run checks` | The CI "verify" job, piece by piece |
| `melos run publish:dry` | pub.dev dry run for every package |
| `melos run l10n` | Regenerate localisations after editing `packages/flutter_mfa_ui/lib/l10n/*.arb` |
| `melos run pigeon` | Regenerate the platform channel after editing `tool/pigeon/messages.dart` |

**Goldens** (`melos run test:goldens`) are only valid on CI's pinned Ubuntu 24.04 image; fonts render differently elsewhere. Don't update them locally. Regenerate them in a PR (`melos run goldens:update` on CI) only for an intended visual change.

**Backup known-answer cross-check** (only when the backup format changes):

```bash
python3 -m venv ~/.venvs/mfa && ~/.venvs/mfa/bin/pip install cryptography
(cd packages/flutter_mfa_core && ~/.venvs/mfa/bin/python -I tool/crosscheck_backup.py test/vectors/backup_v1.json)
```

## 4. Android

Install Android Studio, or the command-line tools only:

```bash
mkdir -p ~/sdk/android/cmdline-tools && cd ~/sdk/android/cmdline-tools
# download "Command line tools only" for Linux from developer.android.com, then:
unzip commandlinetools-linux-*_latest.zip && mv cmdline-tools latest
echo 'export ANDROID_HOME="$HOME/sdk/android"; export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"' >> ~/.bashrc
source ~/.bashrc
sdkmanager "platform-tools" "emulator" "platforms;android-36" \
  "system-images;android-24;google_apis;x86_64" "system-images;android-36;google_apis;x86_64"
flutter doctor --android-licenses
sudo adduser "$USER" kvm   # hardware acceleration for the emulator; log out and back in
```

Emulators matching CI (the floor and the latest):

```bash
avdmanager create avd -n api24 -k "system-images;android-24;google_apis;x86_64"
avdmanager create avd -n api36 -k "system-images;android-36;google_apis;x86_64"
emulator -avd api36 &
```

Tests, as CI runs them:

```bash
cd packages/flutter_mfa/example
flutter build apk --debug
(cd android && ./gradlew :flutter_mfa:testDebugUnitTest)              # Kotlin JVM tests
./android/gradlew -p android :flutter_mfa:connectedDebugAndroidTest   # instrumented (emulator)
flutter test integration_test -d emulator-5554                        # end-to-end journeys
```

A real phone works the same way: enable USB debugging, then `flutter devices`. Biometric checks need a real phone (see [launch/06-ardc-testing.md](launch/06-ardc-testing.md)).

## 5. Web integration test

`flutter drive` needs a ChromeDriver whose **major version matches the browser**, or the session fails with "This version of ChromeDriver only supports Chrome version N". Debian's `chromium-driver` package matches the `chromium` package:

```bash
sudo apt install -y chromium-driver
chromedriver --port=4444 &
cd packages/flutter_mfa/example
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --browser-name=chrome --headless \
  --chrome-binary="$(command -v chromium)"
```

## 6. iOS

iOS builds and tests need macOS with Xcode. From Linux, use CI: label the PR `ci:ios`. Adding the label after the PR is opened does not start a run, so start the `ci` workflow manually on the branch (Actions → ci → Run workflow). CI runs the native XCTests and the integration tests on the simulator.

## 7. Minimum-SDK check

What CI's `min-sdk` job does, locally:

```bash
PATH="$HOME/sdk/flutter-3.35/bin:$PATH"
flutter pub upgrade && bash tool/test.sh              # our code on the floor SDK
flutter pub downgrade && dart analyze --fatal-infos . # our lower bounds still compile
git checkout pubspec.lock                             # restore the pinned lockfile
```

## 8. Commits

```bash
git config user.name  "Your Name"
git config user.email "you@example.com"
git commit -s -m "feat(core): ... [TASK-ID]"   # DCO sign-off is required
```

Conventional Commits with a task ID; scopes are listed in `CONTRIBUTING.md`. Run `melos run verify` before every push. Progress is logged in `docs/STATUS.md`, and the next task is in `docs/06_BUILD_PLAN.md`.

## 9. Working with Claude Code

`CLAUDE.md` at the repository root gives the agent the project rules and reading order. Start a session in the repository root; it continues from `docs/STATUS.md` and the build plan.
