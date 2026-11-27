import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The popup cannot be exercised without a phone, so guard the cause: only a
  // button the user presses may open Google's sign-in.
  test('nothing in the app signs in to Google by itself', () {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final code = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains('attemptLightweightAuthentication')),
        reason: file.path,
      );
    }
  });
}
