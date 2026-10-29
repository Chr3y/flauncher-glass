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
class BundledWallpaper {
  final String asset;
  final String name;
  /// Attribution for third-party pictures; null for the project's own ones.
  final String? credit;

  const BundledWallpaper(this.asset, this.name, this.credit);
}

/// Wallpapers shipped with the app. [glass] is the project's own default; the pictures in
/// assets/wallpapers/ are freely licensed photos from Wikimedia Commons (cropped to 16:9).
class BundledWallpapers {
  static const BundledWallpaper glass = BundledWallpaper("assets/wallpaper.jpg", "Glass", null);

  static const BundledWallpaper desert = BundledWallpaper(
    "assets/wallpapers/desert-milky-way.jpg",
    "Desert",
    "\"The Gecko's trail\" by Akyriaz, CC BY-SA 4.0",
  );

  static const List<BundledWallpaper> all = [
    glass,
    desert,
    BundledWallpaper(
      "assets/wallpapers/dolomites-tre-cime.jpg",
      "Tre Cime",
      "\"Drei Zinnen Tre Cime di Lavaredo Dolomites\" by Wolfgang Moroder, CC BY-SA 3.0",
    ),
    BundledWallpaper(
      "assets/wallpapers/dolomites-seceda.jpg",
      "Seceda",
      "\"Odles da Secëda Gherdëina\" by Wolfgang Moroder, CC BY-SA 3.0",
    ),
    BundledWallpaper(
      "assets/wallpapers/aurora-lofoten.jpg",
      "Aurora",
      "\"Lofoten, Norway\" by Johannes Groll, CC0",
    ),
    BundledWallpaper(
      "assets/wallpapers/aurora-perseids.jpg",
      "Perseids",
      "\"Aurora and perseids\" by Stephan Sprinz, CC BY 4.0",
    ),
    BundledWallpaper(
      "assets/wallpapers/sunset-sete.jpg",
      "Sunset",
      "\"Sète's sunset\" by Christian Ferrer, CC BY 4.0",
    ),
    BundledWallpaper(
      "assets/wallpapers/forest-madeira.jpg",
      "Forest",
      "\"Foggy Fanal forest in Seixal\" by Ximonic (Simo Räsänen), CC BY-SA 4.0",
    ),
  ];
}
