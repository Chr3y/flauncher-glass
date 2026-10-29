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

import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/wallpaper_upload_server.dart';
import 'package:flauncher/widgets/settings/pictures_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a QR code for uploading wallpapers from a phone. The upload server only runs while this page is open.
class UploadWallpaperPanelPage extends StatefulWidget {
  static const String routeName = "upload_wallpaper_panel";

  @override
  State<UploadWallpaperPanelPage> createState() => _UploadWallpaperPanelPageState();
}

class _UploadWallpaperPanelPageState extends State<UploadWallpaperPanelPage> {
  WallpaperUploadServer? _server;
  Uri? _url;
  String? _error;
  int _received = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final wallpaperService = context.read<WallpaperService>();
    final directory = wallpaperService.picturesDirectory;
    if (directory == null) {
      setState(() => _error = "The pictures folder is not ready yet. Please try again.");
      return;
    }
    final server = WallpaperUploadServer(directory, (_) {
      wallpaperService.refreshPictures();
      if (mounted) {
        setState(() => _received++);
      }
    });
    try {
      final url = await server.start();
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _url = url;
        if (url == null) {
          _error = "No network connection found.";
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Could not start the upload server: $e");
      }
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text("Upload from phone", style: textTheme.titleLarge),
        Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: _error != null
                ? Text(_error!, style: textTheme.bodyMedium)
                : _url == null
                    ? Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                    : Column(
                        children: [
                          Text("Scan with your phone (same Wi-Fi):", style: textTheme.bodySmall),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: QrImageView(data: _url.toString(), size: 180, padding: EdgeInsets.zero),
                          ),
                          SizedBox(height: 12),
                          SelectableText(
                            "http://${_url!.host}:${_url!.port}",
                            style: textTheme.bodyMedium!.copyWith(color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text("PIN  ${_server!.pin}",
                              style: textTheme.headlineSmall!.copyWith(color: Colors.white, letterSpacing: 4)),
                          SizedBox(height: 12),
                          Text(
                            _received == 0
                                ? "Waiting for pictures…"
                                : _received == 1
                                    ? "1 picture received"
                                    : "$_received pictures received",
                            style: textTheme.bodyMedium,
                          ),
                          SizedBox(height: 8),
                          Text("The upload stops when you leave this page.", style: textTheme.bodySmall),
                        ],
                      ),
          ),
        ),
        TextButton(
          autofocus: true,
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined),
              Container(width: 8),
              Text("Show pictures", style: textTheme.bodyMedium),
            ],
          ),
          onPressed: () => Navigator.of(context).pushReplacementNamed(PicturesPanelPage.routeName),
        ),
      ],
    );
  }
}
