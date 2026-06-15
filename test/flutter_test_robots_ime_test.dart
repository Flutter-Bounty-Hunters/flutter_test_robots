import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';

import 'tools/basic_ime_client.dart';

void main() {
  group("IME simulator >", () {
    group("legacy simulated IME with finder/getter >", () {
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

    group("installation timing >", () {
      testWidgets("can be installed before a client receives focus", (tester) async {
        tester.ime.install();
        addTearDown(tester.ime.uninstall);
        await _pumpScaffold(tester);

        expect(tester.ime.isInstalled, isTrue);
        expect(tester.ime.hasActiveClient, isFalse);

        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        await tester.ime.typeText("abc");

        expect(find.text("abc"), findsOneWidget);
        expect(tester.ime.hasActiveClient, isTrue);
        expect(tester.ime.isVisible, isTrue);
      });

      testWidgets("can be installed after a client receives focus", (tester) async {
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        addTearDown(tester.ime.uninstall);

        expect(tester.ime.isInstalled, isFalse);
        expect(tester.ime.hasActiveClient, isFalse);

        await tester.ime.typeText("abc");

        expect(find.text("abc"), findsOneWidget);
        expect(tester.ime.isInstalled, isTrue);
        expect(tester.ime.hasActiveClient, isTrue);
      });
    });

    testWidgets("types characters", (tester) async {
      await _pumpScaffold(tester);
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      await tester.ime.typeText("Abc💙");

      expect(find.text("Abc💙"), findsOneWidget);
      expect(tester.ime.isInstalled, isTrue);
      expect(tester.ime.hasActiveClient, isTrue);
      expect(tester.ime.currentTextEditingValue?.text, "Abc💙");
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
      addTearDown(tester.ime.uninstall);

      await tester.ime.backspace();

      expect(find.text("Ac💙"), findsOneWidget);
    });

    testWidgets("dispatches arbitrary deltas", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc",
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      await tester.ime.sendDeltas(
        const [
          TextEditingDeltaReplacement(
            oldText: "Abc",
            replacementText: "xyz",
            replacedRange: TextRange(start: 0, end: 3),
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange.empty,
          )
        ],
      );

      expect(find.text("xyz"), findsOneWidget);
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
