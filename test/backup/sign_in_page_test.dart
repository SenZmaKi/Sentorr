import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/drive/sign_in_page.dart';

void main() {
  test('says how sign-in went', () {
    expect(signInPage(signedIn: true), contains("You're signed in"));
    expect(signInPage(signedIn: false), contains('Sign-in cancelled'));
  });

  test('desktop pages leave the tab to close; Android ones lead back', () {
    final desktop = signInPage(signedIn: true);
    expect(desktop, contains('You can close this tab'));
    expect(desktop, isNot(contains('sentorr://')));
    final android = signInPage(signedIn: true, returnLink: androidReturnLink);
    expect(android, contains('href="$androidReturnLink"'));
    expect(android, contains('location.href = "$androidReturnLink"'));
    expect(android, isNot(contains('close this tab')));
  });
}
