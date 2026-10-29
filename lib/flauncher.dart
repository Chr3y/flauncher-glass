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

import 'dart:typed_data';
import 'dart:ui';

import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/glass_dock.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/time_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FLauncher extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: RowByRowTraversalPolicy(),
        child: Stack(
          children: [
            Consumer2<WallpaperService, SettingsService>(
              builder: (_, wallpaper, settings, __) => _wallpaper(
                context,
                wallpaper.wallpaperBytes,
                settings.gradientUuid != null ? wallpaper.gradient.gradient : null,
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    _topBar(context),
                    Expanded(
                      child: Consumer<AppsService>(
                        builder: (context, appsService, _) => appsService.initialized
                            ? Align(
                                alignment: Alignment(0, 0.75),
                                child: GlassDock(categoriesWithApps: appsService.categoriesWithApps),
                              )
                            : _emptyState(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _topBar(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(48, 24, 40, 0),
        child: Row(
          children: [
            TimeWidget(),
            Spacer(),
            _SettingsButton(),
          ],
        ),
      );

  // Custom wallpaper first, then a gradient the user picked explicitly, otherwise the bundled default.
  Widget _wallpaper(BuildContext context, Uint8List? wallpaperImage, Gradient? gradient) {
    final size = window.physicalSize;
    if (wallpaperImage != null) {
      return Image.memory(wallpaperImage,
          key: Key("background"), fit: BoxFit.cover, height: size.height, width: size.width);
    }
    if (gradient != null) {
      return Container(key: Key("background"), decoration: BoxDecoration(gradient: gradient));
    }
    return Image.asset("assets/wallpaper.jpg",
        key: Key("background"), fit: BoxFit.cover, height: size.height, width: size.width);
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading...", style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
}

class _SettingsButton extends StatefulWidget {
  @override
  _SettingsButtonState createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: CircleBorder(),
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTap: () => showDialog(context: context, builder: (_) => SettingsPanel()),
        child: AnimatedScale(
          scale: _focused ? 1.08 : 1.0,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: GlassPanel(
            focused: _focused,
            shape: BoxShape.circle,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.settings_outlined, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
}
