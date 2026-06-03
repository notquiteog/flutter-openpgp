import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openpgp/model/bridge_model_generated.dart' as model;
import 'package:openpgp/openpgp.dart' as openpgp;
import 'package:openpgp_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OpenPGP', () {
    var input =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras orci ex, pellentesque quis lobortis in";

    var dyScroll = 200.0;
    final list = find.byType(Scrollable).first;

    group('Generate', () {
      testWidgets(
        'Default',
        (WidgetTester tester) async {
          final instance = app.MyApp();
          await tester.pumpWidget(instance);
          await tester.pumpAndSettle();

          const channel = MethodChannel('openpgp');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'generate');
            return model.KeyPairResponseObjectBuilder(
              output: model.KeyPairObjectBuilder(
                publicKey: 'test public key',
                privateKey: 'test private key',
              ),
            ).toBytes();
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

          final keyPair = await openpgp.OpenPGP.generate(
            options: openpgp.Options()
              ..name = 'test'
              ..email = 'test@test.com'
              ..passphrase = 'test'
              ..keyOptions = (openpgp.KeyOptions()
                ..algorithm = openpgp.Algorithm.EDDSA),
          );

          expect(keyPair.publicKey, 'test public key');
          expect(keyPair.privateKey, 'test private key');
        },
        timeout: Timeout(Duration(seconds: 60)),
        skip: !kIsWeb,
      );
    });

    group('Encrypt and Decrypt', () {
      final parent = find.byKey(ValueKey("encrypt-decrypt"));

      testWidgets('Encrypt / Decrypt', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("encrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );

        await expectLater(resultSelector, findsWidgets);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("decrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        await expectLater(resultSelector, findsWidgets);

        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, equals(input));
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('EncryptSign and DecryptVerify', () {
      final parent = find.byKey(ValueKey("encrypt-sign-decrypt-verify"));

      testWidgets('Encrypt / Decrypt', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("encrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );

        await expectLater(resultSelector, findsWidgets);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("decrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        await expectLater(resultSelector, findsWidgets);

        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, equals(input));
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Encrypt and Decrypt Bytes', () {
      final parent = find.byKey(ValueKey("encrypt-decrypt-bytes"));

      testWidgets('Encrypt / Decrypt', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("encrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));

        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("decrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Encrypt and Decrypt Symmetric', () {
      final parent = find.byKey(ValueKey("encrypt-decrypt-symmetric"));

      testWidgets('Encrypt / Decrypt', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("encrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));

        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("decrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, equals(input));
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Encrypt and Decrypt Symmetric Bytes', () {
      final parent = find.byKey(ValueKey("encrypt-decrypt-symmetric-bytes"));

      testWidgets('Encrypt / Decrypt', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("encrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("decrypt")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, equals(input));
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Sign And Verify', () {
      final parent = find.byKey(ValueKey("sign-verify"));

      testWidgets('Sign / Verify', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("sign")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("verify")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, "VALID");
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Sign And Verify Data', () {
      final parent = find.byKey(ValueKey("sign-verify-data"));

      testWidgets('Sign / Verify Data', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("sign")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("verify")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, "VALID");
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Sign And Verify Bytes', () {
      final parent = find.byKey(ValueKey("sign-verify-bytes"));

      testWidgets('Sign / Verify', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("sign")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("verify")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, "VALID");
      }, timeout: Timeout(Duration(seconds: 60)));
    });

    group('Sign And Verify Data Bytes', () {
      final parent = find.byKey(ValueKey("sign-verify-data-bytes"));

      testWidgets('Sign / Verify Data Bytes', (WidgetTester tester) async {
        final instance = app.MyApp();
        await tester.pumpWidget(instance);
        await tester.pumpAndSettle();

        var container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("sign")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("message")),
          ),
          input,
        );
        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        var resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        var result = resultSelector.evaluate().single.widget as Text;
        expect(result.data != "", equals(true));

        container = find.descendant(
          of: parent,
          matching: find.byKey(ValueKey("verify")),
        );
        await tester.scrollUntilVisible(container, dyScroll, scrollable: list);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: container,
            matching: find.byKey(ValueKey("button")),
          ),
        );
        await tester.pumpAndSettle(Duration(seconds: 3));
        resultSelector = find.descendant(
          of: container,
          matching: find.byKey(ValueKey("result")),
        );
        expect(resultSelector, findsOneWidget);
        result = resultSelector.evaluate().single.widget as Text;
        expect(result.data, "VALID");
      }, timeout: Timeout(Duration(seconds: 60)));
    });
  });
}
