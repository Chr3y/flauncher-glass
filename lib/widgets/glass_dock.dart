/*
 * FLauncher Glass – based on FLauncher by Étienne Fesser
 * Copyright (C) 2026  Matthias Locher (Lisorect)
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
import 'dart:ui';

import 'package:flauncher/database.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const glassGlowColor = Color(0xFF4FE3FF);

/// Frosted glass surface: blurred backdrop, ~12 % white fill, thin light border.
/// When [focused], the fill and border brighten and a coloured glow appears.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final bool focused;
  final BoxShape shape;
  final double radius;

  GlassPanel({
    Key? key,
    required this.child,
    this.focused = false,
    this.shape = BoxShape.rectangle,
    this.radius = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderRadius = shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null;
    final duration = Duration(milliseconds: 200);
    final glass = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: borderRadius,
          color: Colors.white.withOpacity(focused ? 0.20 : 0.12),
          border: Border.all(color: Colors.white.withOpacity(focused ? 0.75 : 0.25), width: focused ? 2 : 1),
        ),
        child: child,
      ),
    );
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: focused
            ? [BoxShadow(color: glassGlowColor.withOpacity(0.55), blurRadius: 28, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: shape == BoxShape.circle
          ? ClipOval(child: glass)
          : ClipRRect(borderRadius: borderRadius!, child: glass),
    );
  }
}

/// All visible apps in one centred horizontal row, in category order.
class GlassDock extends StatelessWidget {
  final List<CategoryWithApps> categoriesWithApps;

  GlassDock({Key? key, required this.categoriesWithApps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final entries = <_DockEntry>[];
    final seen = <String>{};
    for (final categoryWithApps in categoriesWithApps) {
      for (int i = 0; i < categoryWithApps.applications.length; ++i) {
        final app = categoryWithApps.applications[i];
        if (seen.add(app.packageName)) {
          entries.add(_DockEntry(categoryWithApps.category, app, i, categoryWithApps.applications.length));
        }
      }
    }
    if (entries.isEmpty) {
      return Text("No applications", style: TextStyle(color: Colors.white70));
    }
    return SizedBox(
      height: AppCard.height + 48,
      child: Center(
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          itemCount: entries.length,
          // Lets a card keep its state (and the "moving" mode) when reordering shifts its index.
          findChildIndexCallback: (key) {
            final index = entries.indexWhere((entry) => entry.key == (key as ValueKey<String>).value);
            return index < 0 ? null : index;
          },
          itemBuilder: (context, index) {
            final entry = entries[index];
            return EnsureVisible(
              key: ValueKey(entry.key),
              alignment: 0.5,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: AppCard(
                  category: entry.category,
                  application: entry.app,
                  autofocus: index == 0,
                  onMove: (direction) => _onMove(context, direction, entry),
                  onMoveEnd: () => context.read<AppsService>().saveOrderInCategory(entry.category),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Reordering stays within the app's own category and is saved on every step,
  // so leaving the move mode with Back/Home does not lose the new order.
  void _onMove(BuildContext context, AxisDirection direction, _DockEntry entry) {
    int? newIndex;
    if (direction == AxisDirection.right && entry.indexInCategory < entry.categorySize - 1) {
      newIndex = entry.indexInCategory + 1;
    } else if (direction == AxisDirection.left && entry.indexInCategory > 0) {
      newIndex = entry.indexInCategory - 1;
    }
    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      appsService.reorderApplication(entry.category, entry.indexInCategory, newIndex);
      appsService.saveOrderInCategory(entry.category);
    }
  }
}

class _DockEntry {
  final Category category;
  final App app;
  final int indexInCategory;
  final int categorySize;

  _DockEntry(this.category, this.app, this.indexInCategory, this.categorySize);

  String get key => "${category.id}-${app.packageName}";
}
