import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/src/input_method_engine.dart';

/// Simulates keyboard input in your Flutter app.
///
/// Flutter's [WidgetTester] provides a few key-event behaviors, but simulating
/// common key presses requires calling a number of these methods in succession.
/// This extension combines those methods to make it easy to simulate common
/// key presses, like [pressShiftEnter]. Additionally, this extension automatically
/// pumps and settles after every simulation to avoid pumping after every call.
///
/// The [KeyboardInput] extension also simulates text input with [typeKeyboardText],
/// which types one character after another, and pumps a frame between every key
/// press.
extension KeyboardInput on WidgetTester {
  /// Simulates typing the given [plainText] using a physical keyboard.
  ///
  /// A frame is `pump()`ed between every character in [plainText].
  ///
  /// This method only works with widgets that are configured to handle
  /// keyboard keys, which is different from the standard text input system,
  /// called the Input Method Engine (IME). For example, a standard Flutter
  /// `TextField` only responds to the IME, so this method would have no
  /// effect on a `TextField`.
  Future<void> typeKeyboardText(String plainText) async {
    // Avoid generating characters with an "ios" platform due to Flutter bug.
    // TODO: Remove special platform selection when Flutter issue is solved (https://github.com/flutter/flutter/issues/133956)
    final platform = _keyEventPlatform != "ios" ? _keyEventPlatform : "android";

    for (int i = 0; i < plainText.length; i += 1) {
      final character = plainText[i];
      final keyCombo = _keyComboForCharacter(character);

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: platform);
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(keyCombo.physicalKey!, platform: platform, character: character);
        await sendKeyUpEvent(keyCombo.physicalKey!, platform: platform);
      } else {
        await sendKeyEvent(keyCombo.key, platform: platform);
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: platform);
      }

      await pump();
    }
  }

  /// Runs [sendKeyEvent], using the current [defaultTargetPlatform] as the key simulators `platform` value.
  ///
  /// {@template flutter_key_simulation_override}
  /// This method was created because developers often use convenience methods in this package,
  /// along with Flutter's standard simulation methods. But, the convenience methods in this package
  /// simulate a key press `platform` based on the current [defaultTargetPlatform], whereas Flutter's
  /// standard simulation methods always default to "android". Using mismatched platforms across
  /// key simulations leads to unexpected results. By always using methods in this package, instead of
  /// standard Flutter methods, the simulated platform is guaranteed to match across calls, and also
  /// match the platform that's simulated within the surrounding test, i.e., [defaultTargetPlatform].
  /// {@endtemplate}
  Future<void> pressKey(LogicalKeyboardKey key) => sendKeyEvent(key, platform: _keyEventPlatform);

  /// Runs [simulateKeyDownEvent], using the current [defaultTargetPlatform] as the key simulators `platform` value.
  ///
  /// {@macro flutter_key_simulation_override}
  Future<void> pressKeyDown(LogicalKeyboardKey key) => simulateKeyDownEvent(key, platform: _keyEventPlatform);

  /// Runs [simulateKeyUpEvent], using the current [defaultTargetPlatform] as the key simulators `platform` value.
  ///
  /// {@macro flutter_key_simulation_override}
  Future<void> releaseKeyUp(LogicalKeyboardKey key) => simulateKeyUpEvent(key, platform: _keyEventPlatform);

  /// Runs [simulateKeyRepeatEvent], using the current [defaultTargetPlatform] as the key simulators `platform` value.
  ///
  /// {@macro flutter_key_simulation_override}
  Future<void> repeatKey(LogicalKeyboardKey key) => simulateKeyRepeatEvent(key, platform: _keyEventPlatform);

  Future<void> pressEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing ENTER in a widget attached to the IME.
  ///
  /// Instead of key events, this method generates a `\n` insertion followed by a `TextInputAction.newline`.
  ///
  /// {@template newline_quirks_mode}
  /// WARNING: On Android Web, and seemingly only Android Web, we've observed that the standard behavior is
  /// to send a newline `\n`, but not a `TextInputAction.newline`. Because this behavior is an outlier, we believe
  /// it's likely some kind of bug. Rather than always implement this behavior for Android Web, this method
  /// has a [useQuirksMode] parameter. When [useQuirksMode] is `true`, no `TextInputAction.newline` is dispatched
  /// for Android Web, but when its `false`, a `\n` AND a `TextInputAction.newline` are both dispatched, regardless
  /// of platform.
  /// {@endtemplate}
  ///
  /// {@template ime_client_getter}
  /// The given [finder] must find a [StatefulWidget] whose [State] implements
  /// [DeltaTextInputClient].
  ///
  /// If the [DeltaTextInputClient] currently has selected text, that text is first deleted,
  /// which is the standard behavior when typing new characters with an existing selection.
  /// {@endtemplate}
  Future<void> pressEnterWithIme({
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
    bool useQuirksMode = true,
  }) async {
    if (!testTextInput.hasAnyClients) {
      // There isn't any IME connections.
      return;
    }

    await ime.typeText('\n', finder: finder, getter: getter);
    await pump();

    // On any platform, except Android Web, we want to dispatch `TextInputAction.newline`
    // in addition to the newline `\n`. However, on Android Web, when quirks mode is
    // activated, we don't want to send a `TextInputAction.newline` because we've observed
    // that in the real world, Android Web doesn't dispatch a `TextInputAction.newline`.
    if (_keyEventPlatform != "android" || !kIsWeb || !useQuirksMode) {
      await testTextInput.receiveAction(TextInputAction.newline);
      await pump();
    }

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates pressing an ENTER button, either as a keyboard key, or as a software keyboard action button.
  ///
  /// First, this method simulates pressing the ENTER key on a physical keyboard. If that key event goes unhandled
  /// then this method simulates pressing the newline action button on a software keyboard, which inserts "/n"
  /// into the text, and also sends a NEWLINE action to the IME client.
  ///
  /// Pressing ENTER through the IME has some quirks:
  ///
  /// {@macro newline_quirks_mode}
  ///
  /// {@macro ime_client_getter}
  Future<void> pressEnterAdaptive({
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
    bool useQuirksMode = true,
  }) async {
    final handled = await sendKeyEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    if (handled) {
      // The textfield handled the key event.
      // It won't bubble up to the OS to generate text deltas or input actions.
      await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
      return;
    }

    await pressEnterWithIme(
      finder: finder,
      getter: getter,
      settle: settle,
      extraPumps: extraPumps,
      useQuirksMode: useQuirksMode,
    );
  }

  /// Simulates pressing the SPACE key.
  ///
  /// First, this method simulates pressing the SPACE key on a physical keyboard. If that key event goes unhandled
  /// then this method generates an insertion delta of " ".
  ///
  /// If there isn't an active IME connection, no deltas are generated.
  ///
  /// {@macro ime_client_getter}
  Future<void> pressSpaceAdaptive({
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final handled = await sendKeyEvent(LogicalKeyboardKey.space, platform: _keyEventPlatform);

    if (handled) {
      // The key press was handled by the app. We shouldn't generate any deltas.
      await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
      return;
    }

    if (!testTextInput.hasAnyClients) {
      // There isn't any IME connections. Fizzle.
      return;
    }

    await ime.typeText(' ', finder: finder, getter: getter);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlEnter() instead")
  Future<void> pressCtlEnter({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlEnter(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressNumpadEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.numpadEnter, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing NUMPAD ENTER in a widget attached to the IME.
  ///
  /// Instead of key events, this method generates a "\n" insertion followed by a TextInputAction.newline.
  /// Does nothing if there isn't an active IME connection.
  ///
  /// {@macro ime_client_getter}
  Future<void> pressNumpadEnterWithIme({
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    if (!testTextInput.hasAnyClients) {
      // There isn't any IME connections.
      return;
    }

    await ime.typeText('\n', finder: finder, getter: getter);
    await testTextInput.receiveAction(TextInputAction.newline);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates pressing an NUMPAD ENTER button, either as a keyboard key, or as a software keyboard action button.
  ///
  /// First, this method simulates pressing the NUMPAD ENTER key on a physical keyboard. If that key event goes unhandled
  /// then this method simulates pressing the newline action button on a software keyboard, which inserts "/n"
  /// into the text, and also sends a NEWLINE action to the IME client.
  ///
  /// {@macro ime_client_getter}
  Future<void> pressNumpadEnterAdaptive({
    Finder? finder,
    GetDeltaTextInputClient? getter,
    bool settle = true,
    int extraPumps = 0,
  }) async {
    final handled = await sendKeyEvent(LogicalKeyboardKey.numpadEnter, platform: _keyEventPlatform);
    if (handled) {
      // The textfield handled the key event.
      // It won't bubble up to the OS to generate text deltas or input actions.
      await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
      return;
    }

    await pressNumpadEnterWithIme(finder: finder, getter: getter, settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftNumpadEnter({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.numpadEnter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.numpadEnter, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressTab({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.tab, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftTab({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.tab, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.tab, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressBackspace({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdBackspace({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressAltBackspace({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlBackspace() instead")
  Future<void> pressCtlBackspace({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlBackspace(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlBackspace({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressDelete({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.delete, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdB({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyB, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyB, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlB() instead")
  Future<void> pressCtlB({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlB(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlB({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyB, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyB, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdC({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyC, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyC, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlC() instead")
  Future<void> pressCtlC({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlC(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlC({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyC, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyC, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdI({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyI, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyI, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlI() instead")
  Future<void> pressCtlI({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlI(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlI({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyI, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyI, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdX({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyX, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyX, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlX() instead")
  Future<void> pressCtlX({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlX(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlX({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyX, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyX, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdV({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyV, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlV() instead")
  Future<void> pressCtlV({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlV(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlV({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyV, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdA({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyA, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlA() instead")
  Future<void> pressCtlA({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlA(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlA({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyA, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlE() instead")
  Future<void> pressCtlE({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlE(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlE({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyE, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyE, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressHome({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressEnd({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressAltLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftAltLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlLeftArrow() instead")
  Future<void> pressCtlLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlLeftArrow(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressShiftCtrlLeftArrow() instead")
  Future<void> pressShiftCtlLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await pressShiftCtrlLeftArrow(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCtrlLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCmdLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressAltRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftAltRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressCtrlRightArrow() instead")
  Future<void> pressCtlRightArrow({bool settle = true, int extraPumps = 0}) async {
    await pressCtrlRightArrow(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  @Deprecated("Use pressShiftCtrlRightArrow() instead")
  Future<void> pressShiftCtlRightArrow({bool settle = true, int extraPumps = 0}) async {
    await pressShiftCtrlRightArrow(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCtrlRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCmdRightArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCmdUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressAltUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftAltUpArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftCmdDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressAltDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressShiftAltDownArrow({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressEscape({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.escape, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdHome({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdEnd({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlHome({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.home, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlEnd({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.end, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdZ({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlZ({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCmdShiftZ({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> pressCtrlShiftZ({bool settle = true, int extraPumps = 0}) async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyDownEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.keyZ, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: _keyEventPlatform);
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  Future<void> _maybeSettleOrExtraPumps({bool settle = true, int extraPumps = 0}) async {
    if (settle) {
      await pumpAndSettle();
    }
    for (int i = 0; i < extraPumps; i += 1) {
      await pump();
    }
  }
}

String get _keyEventPlatform {
  if (keyEventPlatformOverride != null) {
    return keyEventPlatformOverride!;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return "android";
    case TargetPlatform.iOS:
      return "ios";
    case TargetPlatform.macOS:
      return "macos";
    case TargetPlatform.windows:
      return "windows";
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
      return "linux";
  }
}

/// Override for the `platform` value that's passed to every key simulation event.
///
/// When `null`, Flutter's `defaultTargetPlatform` determines the `platform` value
/// that's passed to every key simulation event.
///
/// It is your responsibility to nullify this value when you're done with your
/// platform overrides.
String? keyEventPlatformOverride;

/// Returns a physical keyboard key combination that expects to create the
/// given [character].
_KeyCombo _keyComboForCharacter(String character) {
  if (_charactersToKey.containsKey(character)) {
    return _KeyCombo(_charactersToKey[character]!);
  }
  if (_shiftCharactersToKey.containsKey(character)) {
    final physicalKey = _enUSShiftCharactersToPhysicalKey[character] ?? _shiftCharactersToKey[character]!;

    return _KeyCombo(
      _shiftCharactersToKey[character]!,
      isShiftPressed: true,
      physicalKey: physicalKey,
    );
  }

  throw Exception("Couldn't convert '$character' to a key combo.");
}

const _charactersToKey = {
  'a': LogicalKeyboardKey.keyA,
  'b': LogicalKeyboardKey.keyB,
  'c': LogicalKeyboardKey.keyC,
  'd': LogicalKeyboardKey.keyD,
  'e': LogicalKeyboardKey.keyE,
  'f': LogicalKeyboardKey.keyF,
  'g': LogicalKeyboardKey.keyG,
  'h': LogicalKeyboardKey.keyH,
  'i': LogicalKeyboardKey.keyI,
  'j': LogicalKeyboardKey.keyJ,
  'k': LogicalKeyboardKey.keyK,
  'l': LogicalKeyboardKey.keyL,
  'm': LogicalKeyboardKey.keyM,
  'n': LogicalKeyboardKey.keyN,
  'o': LogicalKeyboardKey.keyO,
  'p': LogicalKeyboardKey.keyP,
  'q': LogicalKeyboardKey.keyQ,
  'r': LogicalKeyboardKey.keyR,
  's': LogicalKeyboardKey.keyS,
  't': LogicalKeyboardKey.keyT,
  'u': LogicalKeyboardKey.keyU,
  'v': LogicalKeyboardKey.keyV,
  'w': LogicalKeyboardKey.keyW,
  'x': LogicalKeyboardKey.keyX,
  'y': LogicalKeyboardKey.keyY,
  'z': LogicalKeyboardKey.keyZ,
  ' ': LogicalKeyboardKey.space,
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
  '`': LogicalKeyboardKey.backquote,
  '-': LogicalKeyboardKey.minus,
  '=': LogicalKeyboardKey.equal,
  '[': LogicalKeyboardKey.bracketLeft,
  ']': LogicalKeyboardKey.bracketRight,
  '\\': LogicalKeyboardKey.backslash,
  ';': LogicalKeyboardKey.semicolon,
  '\'': LogicalKeyboardKey.quoteSingle,
  ',': LogicalKeyboardKey.comma,
  '.': LogicalKeyboardKey.period,
  '/': LogicalKeyboardKey.slash,
};

const _shiftCharactersToKey = {
  'A': LogicalKeyboardKey.keyA,
  'B': LogicalKeyboardKey.keyB,
  'C': LogicalKeyboardKey.keyC,
  'D': LogicalKeyboardKey.keyD,
  'E': LogicalKeyboardKey.keyE,
  'F': LogicalKeyboardKey.keyF,
  'G': LogicalKeyboardKey.keyG,
  'H': LogicalKeyboardKey.keyH,
  'I': LogicalKeyboardKey.keyI,
  'J': LogicalKeyboardKey.keyJ,
  'K': LogicalKeyboardKey.keyK,
  'L': LogicalKeyboardKey.keyL,
  'M': LogicalKeyboardKey.keyM,
  'N': LogicalKeyboardKey.keyN,
  'O': LogicalKeyboardKey.keyO,
  'P': LogicalKeyboardKey.keyP,
  'Q': LogicalKeyboardKey.keyQ,
  'R': LogicalKeyboardKey.keyR,
  'S': LogicalKeyboardKey.keyS,
  'T': LogicalKeyboardKey.keyT,
  'U': LogicalKeyboardKey.keyU,
  'V': LogicalKeyboardKey.keyV,
  'W': LogicalKeyboardKey.keyW,
  'X': LogicalKeyboardKey.keyX,
  'Y': LogicalKeyboardKey.keyY,
  'Z': LogicalKeyboardKey.keyZ,
  '!': LogicalKeyboardKey.exclamation,
  '@': LogicalKeyboardKey.at,
  '#': LogicalKeyboardKey.numberSign,
  '\$': LogicalKeyboardKey.dollar,
  '%': LogicalKeyboardKey.percent,
  '^': LogicalKeyboardKey.caret,
  '&': LogicalKeyboardKey.ampersand,
  '*': LogicalKeyboardKey.asterisk,
  '(': LogicalKeyboardKey.parenthesisLeft,
  ')': LogicalKeyboardKey.parenthesisRight,
  '~': LogicalKeyboardKey.tilde,
  '_': LogicalKeyboardKey.underscore,
  '+': LogicalKeyboardKey.add,
  '{': LogicalKeyboardKey.braceLeft,
  '}': LogicalKeyboardKey.braceRight,
  '|': LogicalKeyboardKey.bar,
  ':': LogicalKeyboardKey.colon,
  '"': LogicalKeyboardKey.quote,
  '<': LogicalKeyboardKey.less,
  '>': LogicalKeyboardKey.greater,
  '?': LogicalKeyboardKey.question,
};

/// A mapping of shift characters to physical keys on en_US keyboards
const _enUSShiftCharactersToPhysicalKey = {
  '!': LogicalKeyboardKey.digit1,
  '@': LogicalKeyboardKey.digit2,
  '#': LogicalKeyboardKey.digit3,
  '\$': LogicalKeyboardKey.digit4,
  '%': LogicalKeyboardKey.digit5,
  '^': LogicalKeyboardKey.digit6,
  '&': LogicalKeyboardKey.digit7,
  '*': LogicalKeyboardKey.digit8,
  '(': LogicalKeyboardKey.digit9,
  ')': LogicalKeyboardKey.digit0,
  '~': LogicalKeyboardKey.backquote,
  '_': LogicalKeyboardKey.minus,
  '+': LogicalKeyboardKey.equal,
  '{': LogicalKeyboardKey.bracketLeft,
  '}': LogicalKeyboardKey.bracketRight,
  '|': LogicalKeyboardKey.backslash,
  ':': LogicalKeyboardKey.semicolon,
  '"': LogicalKeyboardKey.quoteSingle,
  '<': LogicalKeyboardKey.comma,
  '>': LogicalKeyboardKey.period,
  '?': LogicalKeyboardKey.slash,
};

/// A combination of pressed keys, including a logical key, and possibly one or
/// more modifier keys, such as "shift".
class _KeyCombo {
  _KeyCombo(
    this.key, {
    this.isShiftPressed = false,
    this.physicalKey,
  }) : assert(isShiftPressed ? physicalKey != null : physicalKey == null);

  final LogicalKeyboardKey key;
  final bool isShiftPressed;
  final LogicalKeyboardKey? physicalKey;
}
