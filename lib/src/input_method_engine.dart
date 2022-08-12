import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extensions on [WidgetTester] for simulating input method engine (IME) behavior.
extension ImeTester on WidgetTester {
  /// Returns an [ImeSimulator], which can be used to simulate various user
  /// interactions, as if they originated in the platform's input method engine.
  ImeSimulator get ime => ImeSimulator(this);
}

/// Simulator for input method engine (IME) behavior.
///
/// When users enter text, or press certain keys, those signals are intercepted by the
/// host operating system and communicated to the app through something called the
/// "input method engine" or "IME".
///
/// The reason for the IME is to introduce any number of content manipulations before the
/// change reaches the app. For example, spelling auto-correct, special character combinations,
/// and emoji insertions are all achieved by separating apps from the input source.
///
/// IMEs send changes, piece by piece, in what are known as "deltas", e.g., insertion, replacement,
/// and deletion.
///
///
/// Flutter doesn't provide any testing tools for simulating delta-based IME input. This simulator
/// creates deltas that approximate what a real operating system might send to accomplish the same
/// outcome, so that you can test your delta-based widgets without writing costly integration tests.
class ImeSimulator {
  ImeSimulator(this._tester);

  final WidgetTester _tester;

  /// Simulates the user typing [textToType], character by character.
  ///
  /// The given [imeClientFinder] must find a [StatefulWidget] whose [State] implements
  /// [DeltaTextInputClient].
  ///
  /// If the [DeltaTextInputClient] currently has selected text, that text is first deleted,
  /// which is the standard behavior when typing new characters with an existing selection.
  Future<void> typeText(
    String textToType, {
    Finder? finder,
    GetDeltaTextInputClient? getter,
  }) async {
    assert(finder != null && getter == null || finder == null && getter != null);

    late final DeltaTextInputClient imeClient;
    if (finder != null) {
      imeClient = (finder.evaluate().single as StatefulElement).state as DeltaTextInputClient;
    } else {
      imeClient = getter!();
    }
    assert(imeClient.currentTextEditingValue != null, "The target widget doesn't have a text selection to type into.");
    assert(imeClient.currentTextEditingValue!.selection.extentOffset != -1,
        "The target widget doesn't have a text selection to type into.");

    for (final character in textToType.characters) {
      await _typeCharacter(imeClient, character);
    }
  }

  Future<void> _typeCharacter(DeltaTextInputClient imeClient, String character) async {
    assert(imeClient.currentTextEditingValue != null);
    assert(imeClient.currentTextEditingValue!.selection.extentOffset != -1);

    // Compose deltas that insert the given `character`.
    final deltas = [
      if (!imeClient.currentTextEditingValue!.selection.isCollapsed)
        // The IME selection is expanded. Simulate the deletion of the selected text before
        // simulating the insertion.
        TextEditingDeltaDeletion(
          oldText: imeClient.currentTextEditingValue!.text,
          deletedRange: imeClient.currentTextEditingValue!.selection,
          selection: TextSelection.collapsed(offset: imeClient.currentTextEditingValue!.selection.baseOffset),
          composing: TextRange.empty,
        ),
      TextEditingDeltaInsertion(
        oldText: imeClient.currentTextEditingValue!.text.replaceRange(
          // In case the selection is expanded, assume that we removed the selected text
          // with the deletion delta above.
          imeClient.currentTextEditingValue!.selection.start,
          imeClient.currentTextEditingValue!.selection.end,
          "",
        ),
        textInserted: character,
        insertionOffset: imeClient.currentTextEditingValue!.selection.baseOffset,
        selection: TextSelection.collapsed(offset: imeClient.currentTextEditingValue!.selection.baseOffset + 1),
        composing: TextRange.empty,
      ),
    ];

    imeClient.updateEditingValueWithDeltas(deltas);

    // TODO: Send messages through the standard channel when it works. For some reason, only the first test delivers
    //       messages across the channel.
    // Pretend that we're the host platform and send our IME deltas to the app, as
    // if the user typed them.
    // await _sendDeltasThroughChannel(deltas);

    // Let the app handle the deltas, however long it takes.
    await _tester.pumpAndSettle();
  }

  /// Simulates the user pressing the backspace button.
  ///
  /// If the selection is collapsed, the upstream character is deleted. If the selection is expanded, then
  /// the selection is deleted.
  Future<void> backspace(Finder imeClientFinder) async {
    final imeClient = (imeClientFinder.evaluate().single as StatefulElement).state as DeltaTextInputClient;
    assert(
        imeClient.currentTextEditingValue != null, "The target widget doesn't have a text selection to backspace in.");
    assert(imeClient.currentTextEditingValue!.selection.extentOffset != -1,
        "The target widget doesn't have a text selection to backspace in.");

    if (imeClient.currentTextEditingValue!.selection.isCollapsed &&
        imeClient.currentTextEditingValue!.selection.extentOffset == 0) {
      // Caret is at the beginning of the text. Nothing to backspace.
      return;
    }

    final deltas = [
      TextEditingDeltaDeletion(
        oldText: imeClient.currentTextEditingValue!.text,
        deletedRange: imeClient.currentTextEditingValue!.selection.isCollapsed
            ? TextSelection(
                baseOffset: imeClient.currentTextEditingValue!.selection.start,
                extentOffset: imeClient.currentTextEditingValue!.selection.start - 1,
              )
            : imeClient.currentTextEditingValue!.selection,
        selection: imeClient.currentTextEditingValue!.selection.isCollapsed
            ? TextSelection.collapsed(offset: imeClient.currentTextEditingValue!.selection.start - 1)
            : TextSelection.collapsed(offset: imeClient.currentTextEditingValue!.selection.start),
        composing: TextRange.empty,
      ),
    ];

    imeClient.updateEditingValueWithDeltas(deltas);

    // TODO: Send messages through the standard channel when it works. For some reason, only the first test delivers
    //       messages across the channel.
    // Send a delta for a backspace behavior.
    //
    // If the selection is collapsed, we backspace a single character. If the selection is expanded,
    // we delete the selection.
    // await _sendDeltasThroughChannel(deltas);

    // Let the app handle the deltas, however long it takes.
    await _tester.pumpAndSettle();
  }

  // ignore: unused_element
  Future<void> _sendDeltasThroughChannel(List<TextEditingDelta> deltas) async {
    final ByteData? messageBytes = const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'args': <dynamic>[
        1,
        {
          "deltas": [
            for (final delta in deltas) //
              _deltaToJson(delta, delta.oldText),
          ],
        },
      ],
      'method': 'TextInputClient.updateEditingStateWithDeltas',
    });

    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/textinput',
      messageBytes,
      (ByteData? _) {},
    );
  }

  Map<String, dynamic> _deltaToJson(TextEditingDelta delta, String oldText) {
    if (delta is TextEditingDeltaInsertion) {
      return {
        "oldText": oldText,
        "deltaStart": delta.insertionOffset,
        "deltaEnd": delta.insertionOffset,
        "deltaText": delta.textInserted,
        "selectionBase": delta.selection.baseOffset,
        "selectionExtent": delta.selection.extentOffset,
        "selectionAffinity": _fromTextAffinity(delta.selection.affinity),
        "selectionIsDirection": false,
        "composingBase": -1,
        "composingExtent": -1,
      };
    } else if (delta is TextEditingDeltaReplacement) {
      return {
        "oldText": oldText,
        "deltaStart": delta.replacedRange.start,
        "deltaEnd": delta.replacedRange.end,
        "deltaText": delta.replacementText,
        "selectionBase": delta.selection.baseOffset,
        "selectionExtent": delta.selection.extentOffset,
        "selectionAffinity": _fromTextAffinity(delta.selection.affinity),
        "selectionIsDirection": false,
        "composingBase": -1,
        "composingExtent": -1,
      };
    } else if (delta is TextEditingDeltaDeletion) {
      return {
        "oldText": oldText,
        "deltaStart": delta.deletedRange.start,
        "deltaEnd": delta.deletedRange.end,
        "deltaText": "",
        "selectionBase": delta.selection.baseOffset,
        "selectionExtent": delta.selection.extentOffset,
        "selectionAffinity": _fromTextAffinity(delta.selection.affinity),
        "selectionIsDirection": false,
        "composingBase": -1,
        "composingExtent": -1,
      };
    } else if (delta is TextEditingDeltaNonTextUpdate) {
      return {
        "oldText": oldText,
        "selectionBase": delta.selection.baseOffset,
        "selectionExtent": delta.selection.extentOffset,
        "selectionAffinity": _fromTextAffinity(delta.selection.affinity),
        "selectionIsDirection": delta.selection.isDirectional,
        "composingBase": delta.composing.start,
        "composingExtent": delta.composing.end,
      };
    }

    throw Exception("Invalid delta: $delta");
  }

  String _fromTextAffinity(TextAffinity affinity) {
    switch (affinity) {
      case TextAffinity.downstream:
        return 'TextAffinity.downstream';
      case TextAffinity.upstream:
        return 'TextAffinity.upstream';
    }
  }
}

typedef GetDeltaTextInputClient = DeltaTextInputClient Function();
