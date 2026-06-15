import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/src/input_method_editor.dart';

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
  /// called the Input Method Editor (IME). For example, a standard Flutter
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

  /// Simulates the user pressing CMD+N, which in an app typically creates a new document, window, tab, or item.
  Future<void> pressCmdN({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+N, which in an app typically creates a new document, window, tab, or item.
  Future<void> pressCtrlN({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyN], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+O, which in an app typically opens an existing file, document, or project.
  Future<void> pressCmdO({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyO], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+O, which in an app typically opens an existing file, document, or project.
  Future<void> pressCtrlO({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyO], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+S, which in an app typically saves the current document or state.
  Future<void> pressCmdS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+S, which in an app typically saves the current document or state.
  Future<void> pressCtrlS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyS], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+SHIFT+S, which in an app typically opens Save As or saves a copy.
  Future<void> pressCmdShiftS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CTRL+SHIFT+S, which in an app typically opens Save As or saves a copy.
  Future<void> pressCtrlShiftS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+P, which in an app typically opens the print dialog.
  Future<void> pressCmdP({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+P, which in an app typically opens the print dialog.
  Future<void> pressCtrlP({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyP], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+F, which in an app typically opens find or search within the current view.
  Future<void> pressCmdF({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+F, which in an app typically opens find or search within the current view.
  Future<void> pressCtrlF({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyF], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+G, which in an app typically moves to the next find match.
  Future<void> pressCmdG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyG], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+G, which in an app typically moves to the next find match.
  Future<void> pressCtrlG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyG], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+SHIFT+G, which in an app typically moves to the previous find match.
  Future<void> pressCmdShiftG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyG],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CTRL+SHIFT+G, which in an app typically moves to the previous find match.
  Future<void> pressCtrlShiftG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyG],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+H, which in an app typically hides the app or opens replace.
  Future<void> pressCmdH({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyH], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+H, which in an app typically opens replace.
  Future<void> pressCtrlH({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyH], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+R, which in an app typically reloads or refreshes the current view.
  Future<void> pressCmdR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+R, which in an app typically reloads or refreshes the current view.
  Future<void> pressCtrlR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyR], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+SHIFT+R, which in an app typically force-reloads or refreshes without cache.
  Future<void> pressCmdShiftR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CTRL+SHIFT+R, which in an app typically force-reloads or refreshes without cache.
  Future<void> pressCtrlShiftR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+W, which in an app typically closes the current tab, document, or window.
  Future<void> pressCmdW({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+W, which in an app typically closes the current tab, document, or window.
  Future<void> pressCtrlW({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyW], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+Q, which in an app typically quits the app.
  Future<void> pressCmdQ({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyQ], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+Q, which in an app typically quits the app on Linux or cross-platform apps.
  Future<void> pressCtrlQ({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyQ], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+T, which in an app typically opens a new tab.
  Future<void> pressCmdT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyT], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+T, which in an app typically opens a new tab.
  Future<void> pressCtrlT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyT], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+SHIFT+T, which in an app typically reopens the most recently closed tab.
  Future<void> pressCmdShiftT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyT],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CTRL+SHIFT+T, which in an app typically reopens the most recently closed tab.
  Future<void> pressCtrlShiftT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyT],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+L, which in an app typically focuses the location or search field.
  Future<void> pressCmdL({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyL], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+L, which in an app typically focuses the location or search field.
  Future<void> pressCtrlL({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyL], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+U, which in an app typically toggles underline or opens source/details.
  Future<void> pressCmdU({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyU], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+U, which in an app typically toggles underline or opens source/details.
  Future<void> pressCtrlU({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyU], settle: settle, extraPumps: extraPumps);
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

  /// Simulates the user pressing PAGE UP, which in an app typically scrolls or moves one page upward.
  Future<void> pressPageUp({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.pageUp, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing PAGE DOWN, which in an app typically scrolls or moves one page downward.
  Future<void> pressPageDown({bool settle = true, int extraPumps = 0}) async {
    await sendKeyEvent(LogicalKeyboardKey.pageDown, platform: _keyEventPlatform);

    await _maybeSettleOrExtraPumps(settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+PAGE UP, which in an app typically extends selection one page upward.
  Future<void> pressShiftPageUp({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.pageUp], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+PAGE DOWN, which in an app typically extends selection one page downward.
  Future<void> pressShiftPageDown({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.pageDown],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+HOME, which in an app typically selects to the start of the current line.
  Future<void> pressShiftHome({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.home], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+END, which in an app typically selects to the end of the current line.
  Future<void> pressShiftEnd({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.end], settle: settle, extraPumps: extraPumps);
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

  /// Simulates the user pressing CTRL+TAB, which in an app typically moves to the next tab or pane.
  Future<void> pressCtrlTab({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.tab], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+SHIFT+TAB, which in an app typically moves to the previous tab or pane.
  Future<void> pressCtrlShiftTab({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+SHIFT+], which in an app typically moves to the next tab.
  Future<void> pressCmdShiftBracketRight({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.bracketRight],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+SHIFT+[, which in an app typically moves to the previous tab.
  Future<void> pressCmdShiftBracketLeft({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.bracketLeft],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CMD+[, which in an app typically navigates back.
  Future<void> pressCmdBracketLeft({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketLeft],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+], which in an app typically navigates forward.
  Future<void> pressCmdBracketRight({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketRight],
        settle: settle, extraPumps: extraPumps);
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

  /// Simulates the user pressing CTRL+SHIFT+HOME, which in an app typically selects to the start of the document.
  Future<void> pressCtrlShiftHome({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.home],
      settle: settle,
      extraPumps: extraPumps,
    );
  }

  /// Simulates the user pressing CTRL+SHIFT+END, which in an app typically selects to the end of the document.
  Future<void> pressCtrlShiftEnd({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo(
      [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.end],
      settle: settle,
      extraPumps: extraPumps,
    );
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

  /// Simulates the user pressing CTRL+Y, which in an app typically redoes the last undone action.
  Future<void> pressCtrlY({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.keyY], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+PLUS, which in an app typically zooms in.
  Future<void> pressCmdPlus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.add], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+PLUS, which in an app typically zooms in.
  Future<void> pressCtrlPlus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.add], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+MINUS, which in an app typically zooms out.
  Future<void> pressCmdMinus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.minus], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+MINUS, which in an app typically zooms out.
  Future<void> pressCtrlMinus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.minus],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+0, which in an app typically resets zoom to the default level.
  Future<void> pressCmd0({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.digit0], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+0, which in an app typically resets zoom to the default level.
  Future<void> pressCtrl0({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.digit0],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+COMMA, which in an app typically opens preferences or settings.
  Future<void> pressCmdComma({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.comma], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+COMMA, which in an app typically opens preferences or settings.
  Future<void> pressCtrlComma({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.comma],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CMD+M, which in an app typically minimizes the current window.
  Future<void> pressCmdM({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.meta, LogicalKeyboardKey.keyM], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing ALT+F4, which in an app typically closes the current window.
  Future<void> pressAltF4({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.alt, LogicalKeyboardKey.f4], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+F4, which in an app typically closes the current document or tab.
  Future<void> pressCtrlF4({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.f4], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+DELETE, which in an app typically deletes the word after the cursor.
  Future<void> pressCtrlDelete({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.delete],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing ALT+DELETE, which in an app typically deletes the word after the cursor.
  Future<void> pressAltDelete({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.alt, LogicalKeyboardKey.delete], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing CTRL+INSERT, which in an app typically copies the current selection.
  Future<void> pressCtrlInsert({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.control, LogicalKeyboardKey.insert],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+INSERT, which in an app typically pastes from the clipboard.
  Future<void> pressShiftInsert({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.insert], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+DELETE, which in an app typically cuts the current selection.
  Future<void> pressShiftDelete({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, LogicalKeyboardKey.delete], settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+ENTER, which typically confirms or submits.
  Future<void> pressAdaptiveModifierEnter({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.enter],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+BACKSPACE, which typically deletes to a boundary.
  Future<void> pressAdaptiveModifierBackspace({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.backspace],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+B, which typically toggles bold formatting.
  Future<void> pressAdaptiveModifierB({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyB],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+C, which typically copies the current selection.
  Future<void> pressAdaptiveModifierC({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyC],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+I, which typically toggles italic formatting.
  Future<void> pressAdaptiveModifierI({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyI],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+X, which typically cuts the current selection.
  Future<void> pressAdaptiveModifierX({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyX],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+V, which typically pastes from the clipboard.
  Future<void> pressAdaptiveModifierV({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyV],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+A, which typically selects all content.
  Future<void> pressAdaptiveModifierA({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyA],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+N, which typically creates a new document, window, tab, or item.
  Future<void> pressAdaptiveModifierN({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyN],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+O, which typically opens an existing file, document, or project.
  Future<void> pressAdaptiveModifierO({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyO],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+S, which typically saves the current document or state.
  Future<void> pressAdaptiveModifierS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyS],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+SHIFT+S, which typically opens Save As or saves a copy.
  Future<void> pressAdaptiveModifierShiftS({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+P, which typically opens the print dialog.
  Future<void> pressAdaptiveModifierP({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyP],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+F, which typically opens find or search.
  Future<void> pressAdaptiveModifierF({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyF],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+G, which typically moves to the next find match.
  Future<void> pressAdaptiveModifierG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyG],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+SHIFT+G, which typically moves to the previous find match.
  Future<void> pressAdaptiveModifierShiftG({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyG],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+H, which typically hides the app or opens replace.
  Future<void> pressAdaptiveModifierH({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyH],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+R, which typically reloads or refreshes.
  Future<void> pressAdaptiveModifierR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyR],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+SHIFT+R, which typically force-reloads or refreshes without cache.
  Future<void> pressAdaptiveModifierShiftR({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+W, which typically closes the current tab, document, or window.
  Future<void> pressAdaptiveModifierW({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyW],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+Q, which typically quits the app.
  Future<void> pressAdaptiveModifierQ({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyQ],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+T, which typically opens a new tab.
  Future<void> pressAdaptiveModifierT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyT],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+SHIFT+T, which typically reopens the most recently closed tab.
  Future<void> pressAdaptiveModifierShiftT({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyT],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+L, which typically focuses the location or search field.
  Future<void> pressAdaptiveModifierL({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyL],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+U, which typically toggles underline or opens source/details.
  Future<void> pressAdaptiveModifierU({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyU],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+LEFT ARROW, which typically jumps to a line or word boundary.
  Future<void> pressAdaptiveModifierLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.arrowLeft],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+adaptive shortcut modifier+LEFT ARROW, which typically selects to a line or word boundary.
  Future<void> pressShiftAdaptiveModifierLeftArrow({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, _adaptiveShortcutModifierKey, LogicalKeyboardKey.arrowLeft],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+RIGHT ARROW, which typically jumps to a line or word boundary.
  Future<void> pressAdaptiveModifierRightArrow({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.arrowRight],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing SHIFT+adaptive shortcut modifier+RIGHT ARROW, which typically selects to a line or word boundary.
  Future<void> pressShiftAdaptiveModifierRightArrow({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([LogicalKeyboardKey.shift, _adaptiveShortcutModifierKey, LogicalKeyboardKey.arrowRight],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+HOME, which typically jumps to the start of the document.
  Future<void> pressAdaptiveModifierHome({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.home],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+END, which typically jumps to the end of the document.
  Future<void> pressAdaptiveModifierEnd({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.end],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+Z, which typically undoes the last action.
  Future<void> pressAdaptiveModifierZ({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.keyZ],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+SHIFT+Z, which typically redoes the last undone action.
  Future<void> pressAdaptiveModifierShiftZ({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+PLUS, which typically zooms in.
  Future<void> pressAdaptiveModifierPlus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.add],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+MINUS, which typically zooms out.
  Future<void> pressAdaptiveModifierMinus({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.minus],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+0, which typically resets zoom to the default level.
  Future<void> pressAdaptiveModifier0({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.digit0],
        settle: settle, extraPumps: extraPumps);
  }

  /// Simulates the user pressing the adaptive shortcut modifier+COMMA, which typically opens preferences or settings.
  Future<void> pressAdaptiveModifierComma({bool settle = true, int extraPumps = 0}) async {
    await _pressKeyCombo([_adaptiveShortcutModifierKey, LogicalKeyboardKey.comma],
        settle: settle, extraPumps: extraPumps);
  }

  Future<void> _pressKeyCombo(
    List<LogicalKeyboardKey> keys, {
    bool settle = true,
    int extraPumps = 0,
  }) async {
    for (final key in keys) {
      await sendKeyDownEvent(key, platform: _keyEventPlatform);
    }

    for (final key in keys.reversed) {
      await sendKeyUpEvent(key, platform: _keyEventPlatform);
    }

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

LogicalKeyboardKey get _adaptiveShortcutModifierKey {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return LogicalKeyboardKey.meta;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return LogicalKeyboardKey.control;
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
