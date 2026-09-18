import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/backup/sign_in_error.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

void main() {
  test('DEVELOPER_ERROR is reported as a signing-configuration problem', () {
    final f = classifySignInError(
      code: 'sign_in_failed',
      message: 'com.google.android.gms.common.api.ApiException: 10: ',
    );

    expect(f, isA<SignInConfigurationFailure>());
    // The raw code must survive so the user can act on it (see
    // GOOGLE_SIGNIN_SETUP.md) instead of seeing a generic failure.
    expect(f.detail, contains('10'));
  });

  test('a bare status code 10 is recognised too', () {
    expect(classifySignInError(code: 'sign_in_failed', message: '10'),
        isA<SignInConfigurationFailure>());
  });

  test('consent-screen rejection is reported separately', () {
    final f = classifySignInError(
        code: 'sign_in_failed', message: 'access_denied by consent screen');

    expect(f, isA<ConsentDeniedFailure>());
  });

  test('a cancelled picker is not an error', () {
    expect(classifySignInError(code: 'sign_in_canceled'),
        isA<SignInCancelled>());
  });

  test('network errors keep their own type', () {
    expect(classifySignInError(code: 'network_error'), isA<NetworkFailure>());
  });

  test('an unrecognised failure still carries its code for diagnosis', () {
    final f = classifySignInError(code: 'something_new', message: 'boom');

    expect(f, isA<AuthFailure>());
    expect(f.detail, contains('something_new'));
  });

  test('status 12501 (user cancelled) is not surfaced as a failure', () {
    expect(
        classifySignInError(code: 'sign_in_failed', message: 'ApiException: 12501'),
        isA<SignInCancelled>());
  });

  test('status 7 is a network problem, not a configuration one', () {
    expect(
        classifySignInError(code: 'sign_in_failed', message: 'ApiException: 7: '),
        isA<NetworkFailure>());
  });
}
