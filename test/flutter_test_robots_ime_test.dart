import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/src/input_method_engine.dart';

import 'basic_ime_client.dart';

void main() {
  group("IME simulator", () {
    tearDown(() {
      // This line seems to be required when running multiple tests because without
      // it, the previous `TextInputConnection` ID remains across tests and causes
      // problems within Flutter. This is true even when explicitly closing the
      // connection in a widget's `dispose()` method.
      TextInputConnection.debugResetId();
    });

    testWidgets("types characters", (tester) async {
      await _pumpScaffold(tester);
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

      await tester.ime.typeText("Abc💙", finder: find.byType(BareBonesTextFieldWithInputClient));

      expect(find.text("Abc💙"), findsOneWidget);
    });

    testWidgets("replaces selected characters with new character", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc💙",
          selection: TextSelection(baseOffset: 1, extentOffset: 3),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

      await tester.ime.typeText("d", finder: find.byType(BareBonesTextFieldWithInputClient));

      expect(find.text("Ad💙"), findsOneWidget);
    });

    testWidgets("backspaces individual characters", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc💙",
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

      await tester.ime.backspace(finder: find.byType(BareBonesTextFieldWithInputClient));
      await tester.ime.backspace(finder: find.byType(BareBonesTextFieldWithInputClient));

      // Run a 3rd backspace, which shouldn't have any effect. This ensures that our
      // simulator doesn't blow up when backspacing at the beginning of text.
      await tester.ime.backspace(finder: find.byType(BareBonesTextFieldWithInputClient));

      expect(find.text("c💙"), findsOneWidget);
    });

    testWidgets("backspaces a selection", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc💙",
          selection: TextSelection(
            baseOffset: 1,
            extentOffset: 3,
          ),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

      await tester.ime.backspace(finder: find.byType(BareBonesTextFieldWithInputClient));

      expect(find.text("A💙"), findsOneWidget);
    });

    testWidgets("dispatches arbitrary deltas", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc",
          selection: TextSelection(baseOffset: 1, extentOffset: 3),
        ),
      );

      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

      // Dispatch a delta to insert the letter 'd' at the end of the text.
      await tester.ime.sendDeltas(
        const [
          TextEditingDeltaInsertion(
            oldText: "Abc",
            textInserted: "d",
            insertionOffset: 3,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextSelection.collapsed(offset: 3),
          )
        ],
        finder: find.byType(BareBonesTextFieldWithInputClient),
      );

      expect(find.text("Abcd"), findsOneWidget);
    });
  });
}

Future<void> _pumpScaffold(WidgetTester tester, [TextEditingValue? initialValue]) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: BareBonesTextFieldWithInputClient(
            initialValue: initialValue,
          ),
        ),
      ),
    ),
  );
}
