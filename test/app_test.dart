import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_detection_field/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // Phone-like surface so long screens are not clipped during the test.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ScamDetectionApp());
    await tester.pumpAndSettle();
  }

  /// Scrolls the widget into view before tapping it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the app launches and explains its purpose', (tester) async {
    await pumpApp(tester);

    expect(find.text('Scam Detection Field'), findsOneWidget);
    expect(find.text('Why should I be suspicious of this?'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.byKey(const ValueKey('analyze-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting an empty input shows a friendly error',
      (tester) async {
    await pumpApp(tester);

    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

    expect(find.byKey(const ValueKey('error-text')), findsOneWidget);
    expect(
      find.text('Paste or type something to analyse first.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the example link produces a full explainable result',
      (tester) async {
    await pumpApp(tester);

    await tapVisible(tester, find.text('Try a suspicious link'));
    expect(find.textContaining('paypal-secure-login'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

    expect(find.byKey(const ValueKey('risk-label')), findsOneWidget);
    expect(find.text('HIGH RISK'), findsOneWidget);
    expect(find.text('Why this result'), findsOneWidget);
    expect(find.byKey(const ValueKey('recommendation')), findsOneWidget);
    expect(find.text('What you should do'), findsOneWidget);
    expect(find.text('About this analysis'), findsOneWidget);
    expect(find.text('AI explanation'), findsNothing);
    expect(tester.takeException(), isNull);

    await tapVisible(tester, find.byKey(const ValueKey('again-button')));
    expect(find.byKey(const ValueKey('analyze-button')), findsOneWidget);
  });

  testWidgets('a full message pasted into the link tab is caught',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('input-field')),
      'URGENT: send me your password right now',
    );
    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

    expect(find.text('Switch to Message'), findsOneWidget);

    await tapVisible(tester, find.text('Switch to Message'));
    expect(find.byKey(const ValueKey('error-text')), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

    expect(find.text('HIGH RISK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a benign message produces a LOW risk result', (tester) async {
    await pumpApp(tester);

    await tapVisible(tester, find.text('Try a suspicious message'));

    await tester.enterText(
      find.byKey(const ValueKey('input-field')),
      'Hey, are we still meeting at 5pm tomorrow?',
    );
    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

    expect(find.text('LOW RISK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the result can be copied as a plain-text report',
      (tester) async {
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        clipboardCalls.add(call);
        return null;
      },
    );

    await pumpApp(tester);
    await tapVisible(tester, find.text('Try a suspicious link'));
    await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));
    await tapVisible(tester, find.byKey(const ValueKey('copy-button')));

    expect(find.text('Report copied to clipboard'), findsOneWidget);
    final setData =
        clipboardCalls.where((c) => c.method == 'Clipboard.setData').toList();
    expect(setData, hasLength(1));
    final text = (setData.first.arguments as Map)['text'] as String;
    expect(text, contains('HIGH RISK'));
    expect(text, contains('What to do:'));
  });
}
