/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flauncher/bundled_wallpapers.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/unsplash_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  final ImagePicker _imagePicker;
  final FLauncherChannel _fLauncherChannel;
  final UnsplashService _unsplashService;
  late SettingsService _settingsService;

  late final File _wallpaperFile;
  Uint8List? _wallpaper;
  Directory? _picturesDirectory;
  List<File> _pictures = [];

  Uint8List? get wallpaperBytes => _wallpaper;

  /// Folder for the user's own wallpapers: filled by the phone upload or via
  /// `adb push <image> /sdcard/Android/data/<package>/files/Wallpapers/`.
  Directory? get picturesDirectory => _picturesDirectory;

  /// Images in [picturesDirectory], newest first.
  List<File> get pictures => _pictures;

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.greatWhale,
      );

  set settingsService(SettingsService settingsService) => _settingsService = settingsService;

  WallpaperService(this._imagePicker, this._fLauncherChannel, this._unsplashService) {
    _init();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    if (await _wallpaperFile.exists()) {
      _wallpaper = await _wallpaperFile.readAsBytes();
      notifyListeners();
    }
    final externalDirectory = await getExternalStorageDirectory();
    _picturesDirectory = Directory("${(externalDirectory ?? directory).path}/Wallpapers");
    await _picturesDirectory!.create(recursive: true);
    await refreshPictures();
  }

  Future<void> refreshPictures() async {
    final directory = _picturesDirectory;
    if (directory == null) {
      return;
    }
    final files = await directory
        .list()
        .where((entity) => entity is File && _pictureExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext)))
        .cast<File>()
        .toList();
    final modified = {for (final file in files) file.path: await file.lastModified()};
    files.sort((a, b) => modified[b.path]!.compareTo(modified[a.path]!));
    _pictures = files;
    notifyListeners();
  }

  Future<void> setFromPicture(File picture) async => _setWallpaper(await picture.readAsBytes());

  Future<void> setFromBundled(BundledWallpaper wallpaper) async =>
      _setWallpaper((await rootBundle.load(wallpaper.asset)).buffer.asUint8List());

  Future<void> deletePicture(File picture) async {
    if (await picture.exists()) {
      await picture.delete();
    }
    await refreshPictures();
  }

  Future<void> _setWallpaper(Uint8List bytes) async {
    await _wallpaperFile.writeAsBytes(bytes);
    _wallpaper = bytes;
    await _settingsService.setUnsplashAuthor(null);
    notifyListeners();
  }

  Future<void> pickWallpaper() async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      await _wallpaperFile.writeAsBytes(bytes);
      _wallpaper = bytes;
      await _settingsService.setUnsplashAuthor(null);
      notifyListeners();
    }
  }

  Future<void> randomFromUnsplash(String query) async {
    final photo = await _unsplashService.randomPhoto(query);
    final bytes = await _unsplashService.downloadPhoto(photo);
    await _wallpaperFile.writeAsBytes(bytes);
    _wallpaper = bytes;
    await _settingsService
        .setUnsplashAuthor(jsonEncode({"username": photo.username, "link": photo.userLink.toString()}));
    notifyListeners();
  }

  Future<List<Photo>> searchFromUnsplash(String query) => _unsplashService.searchPhotos(query);

  Future<void> setFromUnsplash(Photo photo) async {
    final bytes = await _unsplashService.downloadPhoto(photo);
    await _wallpaperFile.writeAsBytes(bytes);
    _wallpaper = bytes;
    await _settingsService
        .setUnsplashAuthor(jsonEncode({"username": photo.username, "link": photo.userLink.toString()}));
    notifyListeners();
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }
    _wallpaper = null;
    _settingsService.setUnsplashAuthor(null);
    _settingsService.setGradientUuid(fLauncherGradient.uuid);
    notifyListeners();
  }
}

const _pictureExtensions = [".jpg", ".jpeg", ".png", ".webp"];

class NoFileExplorerException implements Exception {}
