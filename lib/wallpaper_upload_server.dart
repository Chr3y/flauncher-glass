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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

/// Small HTTP server on the local network so a phone can upload wallpapers.
/// It only runs while the upload page in the settings is open, and every request needs the PIN shown on screen.
class WallpaperUploadServer {
  static const int preferredPort = 8080;
  static const int maxUploadBytes = 40 * 1024 * 1024;

  final Directory directory;
  final void Function(File) onUploaded;
  final String pin = (Random.secure().nextInt(9000) + 1000).toString();

  HttpServer? _server;

  WallpaperUploadServer(this.directory, this.onUploaded);

  /// Starts the server and returns the URL to open on the phone (including the PIN), or null without a network.
  Future<Uri?> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen((request) => _handle(request).catchError((Object e) => debugPrint("Upload request failed: $e")));
    final address = await _localAddress();
    if (address == null) {
      return null;
    }
    return Uri(scheme: "http", host: address, port: _server!.port, queryParameters: {"pin": pin});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String?> _localAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final addresses = interfaces
        .expand((interface) => interface.addresses)
        .where((address) => !address.isLoopback && !address.address.startsWith("169.254."))
        .toList();
    return addresses.isEmpty ? null : addresses.first.address;
  }

  Future<void> _handle(HttpRequest request) async {
    final pinOk = request.uri.queryParameters["pin"] == pin;
    if (request.method == "GET" && request.uri.path == "/") {
      await _respond(request, pinOk ? _uploadForm() : _pinForm(request.uri.queryParameters.containsKey("pin")));
    } else if (request.method == "POST" && request.uri.path == "/upload") {
      if (!pinOk) {
        await _respond(request, _pinForm(true), status: HttpStatus.forbidden);
        return;
      }
      await _receiveUpload(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  Future<void> _receiveUpload(HttpRequest request) async {
    final contentType = request.headers.contentType;
    final boundary = contentType?.parameters["boundary"];
    if (contentType?.mimeType != "multipart/form-data" || boundary == null) {
      await _respond(request, _result("Ungültige Anfrage."), status: HttpStatus.badRequest);
      return;
    }
    if (request.contentLength > maxUploadBytes) {
      await _respond(request, _result("Zu groß – höchstens 40 MB auf einmal."), status: HttpStatus.requestEntityTooLarge);
      return;
    }

    var received = 0;
    var saved = 0;
    var rejected = 0;
    final limited = request.transform<List<int>>(StreamTransformer.fromHandlers(handleData: (data, sink) {
      received += data.length;
      if (received > maxUploadBytes) {
        sink.addError(const FormatException("upload too large"));
      } else {
        sink.add(data);
      }
    }));
    try {
      await for (final part in MimeMultipartTransformer(boundary).bind(limited)) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in part) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isEmpty) {
          continue;
        }
        final extension = _imageExtension(bytes);
        if (extension == null) {
          rejected++;
          continue;
        }
        final file = File("${directory.path}/upload-${DateTime.now().millisecondsSinceEpoch}-$saved.$extension");
        await file.writeAsBytes(bytes, flush: true);
        saved++;
        onUploaded(file);
      }
    } catch (e) {
      // Too large (see the limiter above) or a broken multipart body.
      await _respond(request, _result("Upload abgebrochen – höchstens 40 MB auf einmal."),
          status: HttpStatus.badRequest);
      return;
    }

    final message = saved == 0
        ? "Kein Bild empfangen."
        : saved == 1
            ? "1 Bild hochgeladen – am Beamer unter Wallpaper → Pictures auswählen."
            : "$saved Bilder hochgeladen – am Beamer unter Wallpaper → Pictures auswählen.";
    await _respond(request, _result(rejected > 0 ? "$message ($rejected Datei(en) waren keine Bilder.)" : message));
  }

  // Decides by content, not by file name: JPEG, PNG or WebP.
  String? _imageExtension(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return "jpg";
    }
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return "png";
    }
    if (bytes.length > 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == "RIFF" &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == "WEBP") {
      return "webp";
    }
    return null;
  }

  Future<void> _respond(HttpRequest request, String body, {int status = HttpStatus.ok}) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..headers.set("Cache-Control", "no-store")
      ..write(body);
    await request.response.close();
  }

  String _page(String content) => """<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>FLauncher Glass – Hintergrund hochladen</title>
<style>
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:system-ui,sans-serif;
background:linear-gradient(160deg,#0b1030,#3a2a5a 55%,#c8743a);color:#fff}
.card{margin:16px;padding:28px 24px;max-width:420px;width:100%;border-radius:24px;background:rgba(255,255,255,.12);
border:1px solid rgba(255,255,255,.3);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
h1{font-size:1.3rem;margin:0 0 8px}p{opacity:.85;line-height:1.4}
input[type=file],input[type=text]{width:100%;box-sizing:border-box;margin:12px 0;padding:12px;border-radius:12px;
border:1px solid rgba(255,255,255,.4);background:rgba(0,0,0,.25);color:#fff;font-size:1rem}
button,a.btn{display:block;width:100%;box-sizing:border-box;padding:14px;border:0;border-radius:14px;background:#4fe3ff;
color:#06222b;font-size:1rem;font-weight:600;text-align:center;text-decoration:none;margin-top:8px}
</style></head><body><div class="card">$content</div></body></html>""";

  String _uploadForm() => _page("""
<h1>Hintergrund hochladen</h1>
<p>Fotos auswählen und hochladen. Danach am Beamer unter <b>Wallpaper → Pictures</b> auswählen.</p>
<form method="post" action="/upload?pin=$pin" enctype="multipart/form-data">
<input type="file" name="images" accept="image/jpeg,image/png,image/webp" multiple required>
<button type="submit">Hochladen</button>
</form>""");

  String _pinForm(bool wrongPin) => _page("""
<h1>PIN eingeben</h1>
<p>${wrongPin ? "Die PIN stimmt nicht. " : ""}Die PIN steht am Beamer auf der Upload-Seite.</p>
<form method="get" action="/">
<input type="text" name="pin" inputmode="numeric" autocomplete="off" placeholder="PIN" required>
<button type="submit">Weiter</button>
</form>""");

  String _result(String message) => _page("""
<h1>Hintergrund hochladen</h1>
<p>${const HtmlEscape().convert(message)}</p>
<a class="btn" href="/?pin=$pin">Weitere Bilder hochladen</a>""");
}
