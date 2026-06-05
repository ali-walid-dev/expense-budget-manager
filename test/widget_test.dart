// This file intentionally exists so `flutter create .` in CI does NOT generate
// its default counter-app widget_test.dart (which references a `MyApp` that
// doesn't exist here — our root widget is `App`). Booting the real app in a
// widget test needs SharedPreferences + a Drift database, which is covered by
// the dedicated test files; keep this a lightweight sanity check.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test harness sanity check', () {
    expect(1 + 1, 2);
  });
}
