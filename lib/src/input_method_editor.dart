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
  /// This is optional. Calls that don't pass a [Finder] or [GetDeltaTextInputClient]
  /// install the simulated IME automatically before targeting the active text
  /// input client.
  void install() {
    _inputControl.install();
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
  bool get isVisible => _inputControl.isVisible;

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
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient(finder: finder, getter: getter);

    assert(imeClient.currentTextEditingValue != null, "The target widget doesn't have a text selection to type into.");
    assert(imeClient.currentTextEditingValue!.selection.extentOffset != -1,
        "The target widget doesn't have a text selection to type into.");

    for (final character in textToType.characters) {
      await _typeCharacter(imeClient, character, settle: settle, extraPumps: extraPumps);
    }
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

    // TODO: Send messages through the standard channel when it works. For some reason, only the first test delivers
    //       messages across the channel.
    // Pretend that we're the host platform and send our IME deltas to the app, as
    // if the user typed them.
    // await _sendDeltasThroughChannel(deltas);

    // Let the app handle the deltas, however long it takes.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the tab button on a software keyboard.
  Future<void> pressTab({
    Finder? finder,
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
    Finder? finder,
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

    // TODO: Send messages through the standard channel when it works. For some reason, only the first test delivers
    //       messages across the channel.
    // Send a delta for a backspace behavior.
    //
    // If the selection is collapsed, we backspace a single character. If the selection is expanded,
    // we delete the selection.
    // await _sendDeltasThroughChannel(deltas);

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
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final imeClient = await _getImeClient(finder: finder, getter: getter);

    imeClient.updateEditingValueWithDeltas(deltas);

    // Let the app handle the deltas.
    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
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

  // ignore: unused_element
  Future<void> _sendDeltasThroughChannel(List<TextEditingDelta> deltas) async {
    await _sendTextInputMethodCall(
      MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          -1,
          {
            "deltas": [
              for (final delta in deltas) //
                _deltaToJson(delta, delta.oldText),
            ],
          },
        ],
      ),
    );
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
        "deltaStart": -1,
        "deltaEnd": -1,
        "deltaText": "",
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

  Future<void> _maybeSettleOrExtraPumps({bool settle = true, int extraPumps = 0}) async {
    if (settle) {
      await _tester.pumpAndSettle();
    }
    for (int i = 0; i < extraPumps; i += 1) {
      await _tester.pump();
    }
  }
}

typedef GetDeltaTextInputClient = DeltaTextInputClient Function();

class _SimulatedImeTextInputControl with TextInputControl {
  _SimulatedImeTextInputControl._();

  static final _SimulatedImeTextInputControl instance = _SimulatedImeTextInputControl._();

  TextInputClient? _client;
  TextInputConfiguration? _configuration;
  TextEditingValue? _editingValue;
  bool _isInstalled = false;
  bool _isVisible = false;

  bool get isInstalled => _isInstalled;

  bool get hasActiveClient => _client != null;

  bool get isVisible => _isVisible;

  TextEditingValue? get currentTextEditingValue => _client?.currentTextEditingValue ?? _editingValue;

  DeltaTextInputClient get deltaTextInputClient {
    final client = _client;

    if (client == null) {
      throw StateError(
        "There isn't an active text input client. Focus a text input before simulating IME behavior.",
      );
    }

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

  void install() {
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
    _isVisible = false;
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
      _isVisible = false;
    }
  }

  @override
  void show() {
    _isVisible = true;
  }

  @override
  void hide() {
    _isVisible = false;
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
