# FLauncher Glass

**FLauncher Glass** is a fork of [FLauncher](https://gitlab.com/flauncher/flauncher) by Étienne Fesser with a
tvOS-style "glass" look: a frosted, blurred dock, glowing focus and a calmer home screen. It was built for and tested on a
**BenQ GP01** projector (Android TV 11, ARM32), but should run on other Android TV devices too.

- Fork maintained by **Matthias Locher** – [Lisorect](https://www.lisorect.it), software development from South Tyrol (Italy)
- Developed with the help of an AI assistant (Claude by Anthropic); every change was reviewed and tested on a real device
- License unchanged: **GNU GPL v3** (see `LICENSE`). All credit for the original launcher goes to Étienne Fesser and the
  FLauncher contributors.

### Changes compared to FLauncher (October 2026)
- Glass dock (`lib/widgets/glass_dock.dart`): blurred, translucent app row with a glowing focus effect
- Reworked home screen, clock and settings panels for the glass look
- Firebase (Analytics, Crashlytics, Remote Config) removed – no tracking, no Google services required
- Build limited to `armeabi-v7a` (the GP01 is 32-bit only) – remove the `abiFilters` block in
  `android/app/build.gradle` for 64-bit devices
- Own default wallpaper (a simple gradient, part of this project and under the same license)
- Release builds are signed with the debug key – sign with your own key before distributing

The Play Store link below points to the original FLauncher, not to this fork.

---

# FLauncher
FLauncher is an open-source alternative launcher for Android TV, built with [Flutter](https://flutter.dev).

The project is still at an early development stage and may be unstable. It currently lacks testing on real devices and has only been tested on Chromecast with Google TV.

<a href="https://play.google.com/store/apps/details?id=me.efesser.flauncher">
 <img alt="Get it on Google Play" width="200" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png"/>
</a>

## Features
- [x] No ads
- [x] Customizable categories
- [x] Manually reorder apps within categories
- [x] Wallpaper support
- [x] Open "Android Settings"
- [x] Open "App info"
- [x] Uninstall app
- [x] Clock
- [x] Switch between row and grid for categories
- [x] Support for non-TV (sideloaded) apps
- [x] Navigation sound feedback
- [ ] Force stop app

## Screenshots
|  |  |  |
|--|--|--|
| ![](screenshots/Screenshot_1624378896.png) | ![](screenshots/Screenshot_1624378921.png) | ![](screenshots/Screenshot_1624378938.png) |

## Set FLauncher as default launcher

### Method 1: remap the Home button
This is the "safer" and easiest way. Use [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) to remap the Home button of the remote to launch FLauncher.

### Method 2: disable the default launcher
**:warning: Disclaimer :warning:**

**You are doing this at your own risk, and you'll be responsible in any case of malfunction on your device.**

The following commands have been tested on Chromecast with Google TV only. This may be different on other devices.

Once the default launcher is disabled, press the Home button on the remote, and you'll be prompted by the system to choose which app to set as default.

#### Disable default launcher
```shell
# Disable com.google.android.apps.tv.launcherx which is the default launcher on CCwGTV
$ adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
# com.google.android.tungsten.setupwraith will then be used as a 'fallback' and will automatically
# re-enable the default launcher, so disable it as well
$ adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
```

#### Re-enable default launcher
```shell
$ adb shell pm enable com.google.android.apps.tv.launcherx
$ adb shell pm enable com.google.android.tungsten.setupwraith
```

#### Known issues
On Chromecast with Google TV (maybe others), the "YouTube" remote button will stop working if the default launcher is disabled. As a workaround, you can use [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) to remap it correctly.

## Wallpaper
Because Android's `WallpaperManager` is not available on some Android TV devices, FLauncher implements its own wallpaper management method.

Please note that changing wallpaper requires a file explorer to be installed on the device in order to pick a file.

<a href="https://www.buymeacoffee.com/etienn01" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="200"></a>
