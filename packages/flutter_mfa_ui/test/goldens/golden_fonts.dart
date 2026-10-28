import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the test fonts (see fonts/README.md) once per test file.
Future<void> loadGoldenFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('test/goldens/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
  await load('NotoSansArabic', ['NotoSansArabic.ttf']);
  await load('NotoSansDevanagari', ['NotoSansDevanagari.ttf']);
}
