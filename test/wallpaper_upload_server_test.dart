import 'dart:convert';
import 'dart:io';

import 'package:flauncher/wallpaper_upload_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late WallpaperUploadServer server;
  late Uri url;
  final uploaded = <File>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("wallpapers");
    uploaded.clear();
    server = WallpaperUploadServer(directory, uploaded.add);
    url = (await server.start())!;
  });

  tearDown(() async {
    await server.stop();
    await directory.delete(recursive: true);
  });

  Future<HttpClientResponse> post(String pin, List<int> fileBytes, String fileName) async {
    const boundary = "testboundary";
    final body = <int>[
      ...utf8.encode("--$boundary\r\nContent-Disposition: form-data; name=\"images\"; filename=\"$fileName\"\r\n"
          "Content-Type: application/octet-stream\r\n\r\n"),
      ...fileBytes,
      ...utf8.encode("\r\n--$boundary--\r\n"),
    ];
    final client = HttpClient();
    final request = await client.postUrl(url.replace(path: "/upload", queryParameters: {"pin": pin}));
    request.headers.contentType = ContentType("multipart", "form-data", parameters: {"boundary": boundary});
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response;
  }

  test("asks for the PIN when it is missing", () async {
    final client = HttpClient();
    final response = await (await client.getUrl(url.replace(queryParameters: {}))).close();
    final html = await response.transform(utf8.decoder).join();
    client.close();
    expect(response.statusCode, 200);
    expect(html, contains("PIN eingeben"));
  });

  test("rejects uploads with a wrong PIN", () async {
    final response = await post("0000", [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3], "a.jpg");
    expect(response.statusCode, HttpStatus.forbidden);
    expect(directory.listSync(), isEmpty);
  });

  test("stores JPEG uploads and ignores other files", () async {
    final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5];
    expect((await post(server.pin, jpeg, "photo.jpg")).statusCode, 200);
    expect((await post(server.pin, utf8.encode("not an image"), "evil.jpg")).statusCode, 200);
    final files = directory.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.path, endsWith(".jpg"));
    expect(files.single.readAsBytesSync(), jpeg);
    expect(uploaded, hasLength(1));
  });
}
