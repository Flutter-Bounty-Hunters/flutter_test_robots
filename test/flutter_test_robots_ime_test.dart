import 'package:flutter/foundation.dart';
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

    testWidgets("types known accented characters", (tester) async {
      await _pumpScaffold(tester);
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      const accentedText = "áÁéÉíÍóÓúÚýÝ àÀèÈìÌòÒùÙ âÂêÊîÎôÔûÛ ãÃñÑõÕ äÄëËïÏöÖüÜÿŸ";
      await tester.ime.typeText(accentedText);

      expect(find.text(accentedText), findsOneWidget);
      expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: accentedText.length));
      expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
    });

    testWidgets("dispatches macOS accent composition deltas for accented characters", (tester) async {
      await _withTargetPlatform(TargetPlatform.macOS, () async {
        final deltaBatches = <List<TextEditingDelta>>[];
        await _pumpScaffold(
          tester,
          null,
          null,
          (deltas) {
            deltaBatches.add(List.of(deltas));
          },
        );
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        addTearDown(tester.ime.uninstall);

        await tester.ime.typeText("caf");
        deltaBatches.clear();
        await tester.ime.typeText("é");

        expect(find.text("café"), findsOneWidget);
        expect(deltaBatches, hasLength(2));

        final accentInsertion = deltaBatches[0].single as TextEditingDeltaInsertion;
        expect(accentInsertion.oldText, "caf");
        expect(accentInsertion.textInserted, "´");
        expect(accentInsertion.insertionOffset, 3);
        expect(accentInsertion.selection, const TextSelection.collapsed(offset: 4));
        expect(accentInsertion.composing, const TextRange(start: 3, end: 4));

        final accentedReplacement = deltaBatches[1].single as TextEditingDeltaReplacement;
        expect(accentedReplacement.oldText, "caf´");
        expect(accentedReplacement.replacedRange, const TextRange(start: 3, end: 4));
        expect(accentedReplacement.replacementText, "é");
        expect(accentedReplacement.selection, const TextSelection.collapsed(offset: 4));
        expect(accentedReplacement.composing, TextRange.empty);
      });
    });

    testWidgets("dispatches Windows composed character deltas for accented characters", (tester) async {
      await _withTargetPlatform(TargetPlatform.windows, () async {
        final deltaBatches = <List<TextEditingDelta>>[];
        await _pumpScaffold(
          tester,
          null,
          null,
          (deltas) {
            deltaBatches.add(List.of(deltas));
          },
        );
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        addTearDown(tester.ime.uninstall);

        await tester.ime.typeText("caf");
        deltaBatches.clear();
        await tester.ime.typeText("é");

        expect(find.text("café"), findsOneWidget);
        expect(deltaBatches, hasLength(1));

        final accentedInsertion = deltaBatches.single.single as TextEditingDeltaInsertion;
        expect(accentedInsertion.oldText, "caf");
        expect(accentedInsertion.textInserted, "é");
        expect(accentedInsertion.insertionOffset, 3);
        expect(accentedInsertion.selection, const TextSelection.collapsed(offset: 4));
        expect(accentedInsertion.composing, TextRange.empty);
      });
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

    testWidgets("deletes individual characters", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "Abc💙",
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      await tester.ime.delete();

      expect(find.text("Ac💙"), findsOneWidget);
    });

    testWidgets("presses an action button", (tester) async {
      TextInputAction? pressedAction;
      await _pumpScaffold(
        tester,
        null,
        (action) {
          pressedAction = action;
        },
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      await tester.ime.pressAction(TextInputAction.search);

      expect(pressedAction, TextInputAction.search);
    });

    testWidgets("accepts a text replacement suggestion", (tester) async {
      await _pumpScaffold(
        tester,
        const TextEditingValue(
          text: "teh cat",
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
      addTearDown(tester.ime.uninstall);

      await tester.ime.acceptTextReplacementSuggestion(
        replacedRange: const TextRange(start: 0, end: 3),
        replacementText: "the",
      );

      expect(find.text("the cat"), findsOneWidget);
      expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: 3));
    });

    group("expansions and autocorrects >", () {
      testWidgets("applies autocorrect after a word boundary", (tester) async {
        tester.ime.install(
          autocorrects: {
            "teh": "the",
          },
        );
        addTearDown(tester.ime.uninstall);
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

        await tester.ime.typeText("teh ");

        expect(find.text("the "), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: 4));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      });

      testWidgets("expands a text replacement shortcut", (tester) async {
        tester.ime.install(
          expansions: {
            "omw": "On my way!",
          },
        );
        addTearDown(tester.ime.uninstall);
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

        await tester.ime.typeText("omw ");

        expect(find.text("On my way! "), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: 11));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      });

      testWidgets("leaves words unchanged without configured replacements", (tester) async {
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        addTearDown(tester.ime.uninstall);

        await tester.ime.typeText("omw ");

        expect(find.text("omw "), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: 4));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      });

      testWidgets("prefers expansions over autocorrects", (tester) async {
        tester.ime.install(
          expansions: {
            "idk": "I don't know",
          },
          autocorrects: {
            "idk": "I do know",
          },
        );
        addTearDown(tester.ime.uninstall);
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

        await tester.ime.typeText("idk ");

        const expectedText = "I don't know ";
        expect(find.text(expectedText), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, TextSelection.collapsed(offset: expectedText.length));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      });

      testWidgets("replaces only the word before the boundary", (tester) async {
        tester.ime.install(
          expansions: {
            "omw": "On my way!",
          },
          autocorrects: {
            "teh": "the",
          },
        );
        addTearDown(tester.ime.uninstall);
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));

        await tester.ime.typeText("say omw ");

        const expectedText = "say On my way! ";
        expect(find.text(expectedText), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, TextSelection.collapsed(offset: expectedText.length));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      });
    });

    group("composing region interactions >", () {
      testWidgets("accepts dictation text", (tester) async {
        await _pumpScaffold(tester);
        await tester.tap(find.byType(BareBonesTextFieldWithInputClient));
        addTearDown(tester.ime.uninstall);

        // TODO: Call a simulator API that represents accepting text recognized by dictation.

        expect(find.text("Hello world"), findsOneWidget);
        expect(tester.ime.currentTextEditingValue?.selection, const TextSelection.collapsed(offset: 11));
        expect(tester.ime.currentTextEditingValue?.composing, TextRange.empty);
      }, skip: true);
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

Future<void> _pumpScaffold(
  WidgetTester tester, [
  TextEditingValue? initialValue,
  ValueChanged<TextInputAction>? onPerformAction,
  ValueChanged<List<TextEditingDelta>>? onUpdateEditingValueWithDeltas,
]) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: BareBonesTextFieldWithInputClient(
            initialValue: initialValue,
            onPerformAction: onPerformAction,
            onUpdateEditingValueWithDeltas: onUpdateEditingValueWithDeltas,
          ),
        ),
      ),
    ),
  );
}

Future<void> _withTargetPlatform(TargetPlatform targetPlatform, Future<void> Function() callback) async {
  debugDefaultTargetPlatformOverride = targetPlatform;
  try {
    await callback();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
