import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extensions on [WidgetTester] for simulating input method editor (IME) behavior.
extension ImeTester on WidgetTester {
  /// Returns an [ImeSimulator], which can be used to simulate various user
  /// interactions, as if they originated in the platform's input method editor.
  ImeSimulator get ime => ImeSimulator(this);
}

/// Simulator for input method editor (IME) behavior.
///
/// When users enter text, or press certain keys, those signals are intercepted by the
/// host operating system and communicated to the app through something called the
/// "input method editor" or "IME".
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

  _SimulatedImeTextInputControl get _inputControl => _SimulatedImeTextInputControl.instance;

  /// Installs this simulator as Flutter's current text input control.
  ///
  /// Developers can optionally provide [expansions], which are text runs that expand to larger text, e.g.,
  /// "omw" becomes "On my way!", and [autocorrects], which are common misspellings and their corrections.
  /// When using [typeText], the insertion of a space after a non-space will evaluate both [expansions] and
  /// [autocorrects] and apply any matching candidate. This simulates what the OS does when running real
  /// apps, but with developer control.
  ///
  /// This is optional. Calls that don't pass a [Finder] or [GetDeltaTextInputClient]
  /// install the simulated IME automatically before targeting the active text
  /// input client.
  void install({
    Map<String, String> expansions = const {},
    Map<String, String> autocorrects = const {},
  }) {
    _inputControl.install(
      expansions: expansions,
      autocorrects: autocorrects,
    );
  }

  /// Restores Flutter's default platform text input control.
  void uninstall() {
    _inputControl.uninstall();
  }

  /// Whether the simulated IME is installed as Flutter's current text input control.
  bool get isInstalled => _inputControl.isInstalled;

  /// Whether the simulated IME is attached to an active text input client.
  bool get hasActiveClient => _inputControl.hasActiveClient;

  /// Whether the simulated keyboard is visible.
  bool get isVisible => _inputControl.isKeyboardVisible;

  /// The active client's current editing value, when a client is attached.
  TextEditingValue? get currentTextEditingValue => _inputControl.currentTextEditingValue;

  /// Simulates the user typing [textToType], character by character.
  ///
  /// If [finder] is provided, it must find a [StatefulWidget] whose [State]
  /// implements [DeltaTextInputClient]. If [getter] is provided, it must return
  /// a [DeltaTextInputClient]. Those legacy lookup options are retained for
  /// compatibility.
  ///
  /// If neither [finder] nor [getter] is provided, the simulator installs a
  /// [TextInputControl] and targets the active text input client.
  ///
  /// If the [DeltaTextInputClient] currently has selected text, that text is first deleted,
  /// which is the standard behavior when typing new characters with an existing selection.
  Future<void> typeText(
    String textToType, {
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    Finder? finder,
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient(finder: finder, getter: getter);

    assert(imeClient.currentTextEditingValue != null, "The target widget doesn't have a text selection to type into.");
    assert(
      imeClient.currentTextEditingValue!.selection.extentOffset != -1,
      "The target widget doesn't have a text selection to type into.",
    );

    for (final character in textToType.characters) {
      final accentMark = defaultTargetPlatform == TargetPlatform.macOS //
          ? _macOsDeadKeyAccentedCharacters[character]
          : null;

      if (accentMark != null) {
        // Accent characters involve multiple key presses, so we have to handle them in a special way.
        //
        // Example: Typing é requires a key combo, followed by a letter: `opt+e`, `e`.
        await _typeAccentedCharacter(
          imeClient,
          character,
          accentMark: accentMark,
          settle: settle,
          extraPumps: extraPumps,
        );
      } else {
        // This is a regular, non-accent character. Type it like normal.
        await _typeCharacter(imeClient, character, settle: settle, extraPumps: extraPumps);
      }

      if (character == " ") {
        await _applyReplacementTriggeredBySpace(imeClient, settle: settle, extraPumps: extraPumps);
      }
    }
  }

  Future<void> _applyReplacementTriggeredBySpace(
    DeltaTextInputClient imeClient, {
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final currentValue = imeClient.currentTextEditingValue;
    assert(currentValue != null, "The target widget doesn't have a text selection to replace in.");

    final nonNullCurrentValue = currentValue!;
    if (!nonNullCurrentValue.selection.isCollapsed || nonNullCurrentValue.selection.extentOffset < 2) {
      return;
    }

    final caretOffset = nonNullCurrentValue.selection.extentOffset;
    if (nonNullCurrentValue.text.substring(caretOffset - 1, caretOffset) != " ") {
      return;
    }

    final wordEnd = caretOffset - 1;
    if (_isSpace(nonNullCurrentValue.text.substring(wordEnd - 1, wordEnd))) {
      return;
    }

    var wordStart = wordEnd - 1;
    while (wordStart > 0 && !_isSpace(nonNullCurrentValue.text.substring(wordStart - 1, wordStart))) {
      wordStart -= 1;
    }

    final typedWord = nonNullCurrentValue.text.substring(wordStart, wordEnd);
    final replacement = _inputControl.expansions[typedWord] ?? _inputControl.autocorrects[typedWord];
    if (replacement == null) {
      return;
    }

    imeClient.updateEditingValueWithDeltas([
      TextEditingDeltaReplacement(
        oldText: nonNullCurrentValue.text,
        replacedRange: TextRange(start: wordStart, end: wordEnd),
        replacementText: replacement,
        selection: TextSelection.collapsed(offset: wordStart + replacement.length + 1),
        composing: TextRange.empty,
      ),
    ]);

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> _typeCharacter(
    DeltaTextInputClient imeClient,
    String character, {
    bool settle = true,
    int extraPumps = 0,
  }) async {
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

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> _typeAccentedCharacter(
    DeltaTextInputClient imeClient,
    String character, {
    required String accentMark,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    assert(imeClient.currentTextEditingValue != null);
    assert(imeClient.currentTextEditingValue!.selection.extentOffset != -1);

    final currentValue = imeClient.currentTextEditingValue!;
    final insertionOffset = currentValue.selection.baseOffset;
    final oldTextAfterSelectionDeletion = currentValue.text.replaceRange(
      currentValue.selection.start,
      currentValue.selection.end,
      "",
    );

    if (!currentValue.selection.isCollapsed) {
      imeClient.updateEditingValueWithDeltas([
        TextEditingDeltaDeletion(
          oldText: currentValue.text,
          deletedRange: currentValue.selection,
          selection: TextSelection.collapsed(offset: insertionOffset),
          composing: TextRange.empty,
        ),
      ]);
      await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
    }

    imeClient.updateEditingValueWithDeltas([
      TextEditingDeltaInsertion(
        oldText: oldTextAfterSelectionDeletion,
        textInserted: accentMark,
        insertionOffset: insertionOffset,
        selection: TextSelection.collapsed(offset: insertionOffset + accentMark.length),
        composing: TextRange(start: insertionOffset, end: insertionOffset + accentMark.length),
      ),
    ]);
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);

    final oldTextWithAccentMark = oldTextAfterSelectionDeletion.replaceRange(
      insertionOffset,
      insertionOffset,
      accentMark,
    );
    imeClient.updateEditingValueWithDeltas([
      TextEditingDeltaReplacement(
        oldText: oldTextWithAccentMark,
        replacedRange: TextRange(start: insertionOffset, end: insertionOffset + accentMark.length),
        replacementText: character,
        selection: TextSelection.collapsed(offset: insertionOffset + character.length),
        composing: TextRange.empty,
      ),
    ]);
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the tab button on a software keyboard.
  Future<void> pressTab({
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    Finder? finder,
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    await typeText('\t', finder: finder, getter: getter, settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the backspace button.
  ///
  /// If the selection is collapsed, the upstream character is deleted. If the selection is expanded, then
  /// the selection is deleted.
  Future<void> backspace({
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    Finder? finder,
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient(finder: finder, getter: getter);

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

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the delete button on a software keyboard.
  ///
  /// If the selection is collapsed, the downstream character is deleted. If the selection is expanded, then the
  /// selection is deleted.
  Future<void> delete({
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient();
    final currentValue = imeClient.currentTextEditingValue;

    assert(currentValue != null, "The target widget doesn't have a text selection to delete in.");
    assert(currentValue!.selection.extentOffset != -1, "The target widget doesn't have a text selection to delete in.");
    final nonNullCurrentValue = currentValue!;

    if (nonNullCurrentValue.selection.isCollapsed &&
        nonNullCurrentValue.selection.extentOffset == nonNullCurrentValue.text.length) {
      // Caret is at the end of the text. Nothing to delete.
      return;
    }

    final deletedRange = nonNullCurrentValue.selection.isCollapsed
        ? TextRange(
            start: nonNullCurrentValue.selection.start,
            end: nonNullCurrentValue.selection.start + 1,
          )
        : nonNullCurrentValue.selection;

    final deltas = [
      TextEditingDeltaDeletion(
        oldText: nonNullCurrentValue.text,
        deletedRange: deletedRange,
        selection: TextSelection.collapsed(offset: deletedRange.start),
        composing: TextRange.empty,
      ),
    ];

    imeClient.updateEditingValueWithDeltas(deltas);

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the software keyboard's action button.
  Future<void> pressAction(
    TextInputAction action, {
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getTextInputClient();

    imeClient.performAction(action);

    // Let the app handle the action, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user accepting a text replacement suggestion from the software keyboard.
  Future<void> acceptTextReplacementSuggestion({
    required TextRange replacedRange,
    required String replacementText,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient();
    final currentValue = imeClient.currentTextEditingValue;

    assert(currentValue != null, "The target widget doesn't have a text selection to replace in.");
    assert(
      replacedRange.isValid && replacedRange.start >= 0 && replacedRange.end <= currentValue!.text.length,
      "The replaced range must be within the current text.",
    );
    final nonNullCurrentValue = currentValue!;

    final newSelection = TextSelection.collapsed(offset: replacedRange.start + replacementText.length);
    final deltas = [
      TextEditingDeltaReplacement(
        oldText: nonNullCurrentValue.text,
        replacedRange: replacedRange,
        replacementText: replacementText,
        selection: newSelection,
        composing: TextRange.empty,
      ),
    ];

    imeClient.updateEditingValueWithDeltas(deltas);

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates dispatching arbitrary deltas.
  ///
  /// If [finder] is provided, it must find a [StatefulWidget] whose [State]
  /// implements [DeltaTextInputClient]. If [getter] is provided, it must return
  /// a [DeltaTextInputClient]. Those legacy lookup options are retained for
  /// compatibility.
  ///
  /// If neither [finder] nor [getter] is provided, the simulator installs a
  /// [TextInputControl] and targets the active text input client.
  Future<void> sendDeltas(
    List<TextEditingDelta> deltas, {
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    Finder? finder,
    @Deprecated(
      "Your editor/text field is now found automatically. Not needed. Just ensure your editor/text field is focused.",
    )
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient(finder: finder, getter: getter);

    imeClient.updateEditingValueWithDeltas(deltas);

    // Let the app handle the deltas.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<TextInputClient> _getTextInputClient() async {
    _inputControl.install();
    if (!_inputControl.hasActiveClient) {
      await _requestExistingInputState();
    }
    return _inputControl.textInputClient;
  }

  Future<DeltaTextInputClient> _getImeClient({
    Finder? finder,
    GetDeltaTextInputClient? getter,
  }) async {
    if (finder != null || getter != null) {
      return _findImeClient(finder: finder, getter: getter);
    }

    _inputControl.install();
    if (!_inputControl.hasActiveClient) {
      await _requestExistingInputState();
    }
    return _inputControl.deltaTextInputClient;
  }

  DeltaTextInputClient _findImeClient({
    Finder? finder,
    GetDeltaTextInputClient? getter,
  }) {
    assert(finder != null && getter == null || finder == null && getter != null);

    if (finder != null) {
      return (finder.evaluate().single as StatefulElement).state as DeltaTextInputClient;
    } else {
      return getter!();
    }
  }

  Future<void> _requestExistingInputState() async {
    await _sendTextInputMethodCall(
      const MethodCall('TextInputClient.requestExistingInputState'),
    );
  }

  Future<void> _sendTextInputMethodCall(MethodCall methodCall) async {
    await _tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(methodCall),
      (ByteData? _) {},
    );
  }

  Future<void> _maybeSettleOrExtraPumps({bool settle = true, int extraPumps = 0}) async {
    if (settle) {
      await _tester.pumpAndSettle();
    }
    for (int i = 0; i < extraPumps; i += 1) {
      await _tester.pump();
    }
  }
}

bool _isSpace(String character) => character.trim().isEmpty;

typedef GetDeltaTextInputClient = DeltaTextInputClient Function();

const _macOsDeadKeyAccentedCharacters = {
  "á": "´",
  "Á": "´",
  "é": "´",
  "É": "´",
  "í": "´",
  "Í": "´",
  "ó": "´",
  "Ó": "´",
  "ú": "´",
  "Ú": "´",
  "ý": "´",
  "Ý": "´",
  "à": "`",
  "À": "`",
  "è": "`",
  "È": "`",
  "ì": "`",
  "Ì": "`",
  "ò": "`",
  "Ò": "`",
  "ù": "`",
  "Ù": "`",
  "â": "ˆ",
  "Â": "ˆ",
  "ê": "ˆ",
  "Ê": "ˆ",
  "î": "ˆ",
  "Î": "ˆ",
  "ô": "ˆ",
  "Ô": "ˆ",
  "û": "ˆ",
  "Û": "ˆ",
  "ã": "˜",
  "Ã": "˜",
  "ñ": "˜",
  "Ñ": "˜",
  "õ": "˜",
  "Õ": "˜",
  "ä": "¨",
  "Ä": "¨",
  "ë": "¨",
  "Ë": "¨",
  "ï": "¨",
  "Ï": "¨",
  "ö": "¨",
  "Ö": "¨",
  "ü": "¨",
  "Ü": "¨",
  "ÿ": "¨",
  "Ÿ": "¨",
};

class _SimulatedImeTextInputControl with TextInputControl {
  static final _SimulatedImeTextInputControl instance = _SimulatedImeTextInputControl._();

  _SimulatedImeTextInputControl._();

  TextInputConfiguration? _configuration;

  /// Whether the simulated IME is currently registered as Flutter's text input control.
  ///
  /// Tests can use this to verify that an IME interaction installed the simulator before attempting to target the
  /// active text input client.
  bool get isInstalled => _isInstalled;
  bool _isInstalled = false;

  /// Whether Flutter has attached a text input client to the simulated IME.
  ///
  /// Tests can use this to verify that focus created an app-facing text input connection before sending IME deltas.
  bool get hasActiveClient => _client != null;
  TextInputClient? _client;

  /// Whether Flutter has requested that the simulated keyboard be shown.
  ///
  /// Tests can use this to verify the normal text input lifecycle when the simulator is installed before focus is
  /// received.
  bool get isKeyboardVisible => _isKeyboardVisible;
  bool _isKeyboardVisible = false;

  /// The latest editing value known to the simulated IME.
  ///
  /// Tests can use this to verify that the app and simulated IME agree on text, selection, and composing state after an
  /// interaction.
  TextEditingValue? get currentTextEditingValue => _client?.currentTextEditingValue ?? _editingValue;
  TextEditingValue? _editingValue;

  Map<String, String> get expansions => _expansions;
  Map<String, String> _expansions = const {};

  Map<String, String> get autocorrects => _autocorrects;
  Map<String, String> _autocorrects = const {};

  TextInputClient get textInputClient {
    final client = _client;

    if (client == null) {
      throw StateError(
        "There isn't an active text input client. Focus a text input before simulating IME behavior.",
      );
    }

    return client;
  }

  DeltaTextInputClient get deltaTextInputClient {
    final client = textInputClient;

    if (_configuration?.enableDeltaModel != true) {
      throw StateError(
        "The active text input client hasn't enabled Flutter's delta model. "
        "Use a TextInputConfiguration with enableDeltaModel set to true before "
        "simulating delta-based IME behavior.",
      );
    }

    if (client is! DeltaTextInputClient) {
      throw StateError(
        "The active text input client isn't a DeltaTextInputClient. "
        "Use a delta-enabled text input before simulating delta-based IME behavior.",
      );
    }

    return client;
  }

  void install({
    Map<String, String>? expansions,
    Map<String, String>? autocorrects,
  }) {
    if (expansions != null) {
      _expansions = Map.unmodifiable(expansions);
    }
    if (autocorrects != null) {
      _autocorrects = Map.unmodifiable(autocorrects);
    }

    if (_isInstalled) {
      return;
    }

    TextInput.setInputControl(this);
    _isInstalled = true;
  }

  void uninstall() {
    if (!_isInstalled) {
      return;
    }

    TextInput.restorePlatformInputControl();
    _isInstalled = false;
    _client = null;
    _configuration = null;
    _editingValue = null;
    _isKeyboardVisible = false;
    _expansions = const {};
    _autocorrects = const {};
  }

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    _client = client;
    _configuration = configuration;
    _editingValue = client.currentTextEditingValue;
  }

  @override
  void detach(TextInputClient client) {
    if (_client == client) {
      _client = null;
      _configuration = null;
      _editingValue = null;
      _isKeyboardVisible = false;
    }
  }

  @override
  void show() {
    _isKeyboardVisible = true;
  }

  @override
  void hide() {
    _isKeyboardVisible = false;
  }

  @override
  void updateConfig(TextInputConfiguration configuration) {
    _configuration = configuration;
  }

  @override
  void setEditingState(TextEditingValue value) {
    _editingValue = value;
  }
}
