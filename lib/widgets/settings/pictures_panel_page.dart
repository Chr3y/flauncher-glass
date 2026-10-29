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

import 'dart:io';

import 'package:flauncher/bundled_wallpapers.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flauncher/widgets/settings/upload_wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pick a wallpaper from the user's own pictures folder or from the bundled ones.
/// Long press on an own picture deletes it.
class PicturesPanelPage extends StatefulWidget {
  static const String routeName = "pictures_panel";

  @override
  State<PicturesPanelPage> createState() => _PicturesPanelPageState();
}

class _PicturesPanelPageState extends State<PicturesPanelPage> {
  @override
  void initState() {
    super.initState();
    context.read<WallpaperService>().refreshPictures();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text("Pictures", style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          Expanded(
            child: Consumer<WallpaperService>(
              builder: (context, wallpaperService, _) => CustomScrollView(
                slivers: [
                  _header(context, "Your pictures"),
                  if (wallpaperService.pictures.isEmpty)
                    SliverToBoxAdapter(child: _emptyHint(context, wallpaperService))
                  else
                    _grid(wallpaperService.pictures
                        .map((file) => _PictureCard(
                              key: Key("picture-${file.path}"),
                              image: ResizeImage(FileImage(file), width: 320),
                              label: null,
                              onSelect: () => wallpaperService.setFromPicture(file),
                              onDelete: () => _confirmDelete(context, wallpaperService, file),
                            ))
                        .toList()),
                  _header(context, "Included"),
                  _grid(BundledWallpapers.all
                      .map((wallpaper) => _PictureCard(
                            key: Key("bundled-${wallpaper.asset}"),
                            image: ResizeImage(AssetImage(wallpaper.asset), width: 320),
                            label: wallpaper.name,
                            autofocus: wallpaperService.pictures.isEmpty && wallpaper == BundledWallpapers.glass,
                            onSelect: () => wallpaperService.setFromBundled(wallpaper),
                          ))
                      .toList()),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _header(BuildContext context, String title) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      );

  Widget _grid(List<Widget> children) => SliverGrid.count(
        crossAxisCount: 2,
        childAspectRatio: 16 / 11,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: children.map((child) => EnsureVisible(alignment: 0.5, child: child)).toList(),
      );

  Widget _emptyHint(BuildContext context, WallpaperService wallpaperService) => Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "No pictures yet. Upload some from your phone, or copy them with adb to:\n"
              "${wallpaperService.picturesDirectory?.path ?? "…"}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 8),
            TextButton(
              autofocus: true,
              child: Row(
                children: [
                  Icon(Icons.qr_code_2),
                  Container(width: 8),
                  Text("Upload from phone", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              onPressed: () => Navigator.of(context).pushNamed(UploadWallpaperPanelPage.routeName),
            ),
          ],
        ),
      );

  Future<void> _confirmDelete(BuildContext context, WallpaperService wallpaperService, File file) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete picture?"),
        content: Text("The picture is removed from the folder. The current wallpaper stays until you pick another one."),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Delete")),
        ],
      ),
    );
    if (delete == true) {
      await wallpaperService.deletePicture(file);
    }
  }
}

class _PictureCard extends StatelessWidget {
  final ImageProvider image;
  final String? label;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  _PictureCard({
    Key? key,
    required this.image,
    required this.label,
    required this.onSelect,
    this.autofocus = false,
    this.onDelete,
  }) : super(key: key);

  @override
  // Like AppCard: a short press selects on key up, so a long press can delete without selecting first.
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: (key) {
          if (!longPressableKeys.contains(key)) {
            return KeyEventResult.ignored;
          }
          onSelect();
          return KeyEventResult.handled;
        },
        onLongPress: (key) {
          if (onDelete == null) {
            return KeyEventResult.ignored;
          }
          onDelete!();
          return KeyEventResult.handled;
        },
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: focused ? BorderSide(color: Colors.white, width: 2) : BorderSide.none,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    autofocus: autofocus,
                    // D-pad presses arrive through onPressed above; this keeps the card focusable.
                    onTap: () {},
                    onLongPress: onDelete,
                    child: Ink.image(image: image, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (label != null)
                Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    label!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: focused ? Colors.white : null),
                  ),
                ),
            ],
          );
        },
      );
}
