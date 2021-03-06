import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    for (int i = 0; i < plainText.length; i += 1) {
      final character = plainText[i];
      final keyCombo = _keyComboForCharacter(character);

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(keyCombo.physicalKey!, platform: 'macos', character: character);
        await sendKeyUpEvent(keyCombo.physicalKey!, platform: 'macos');
      } else {
        await sendKeyEvent(keyCombo.key, platform: 'macos');
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
      }

      await pump();
    }
  }

  Future<void> pressEnter() async {
    await sendKeyEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftEnter() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdEnter() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlEnter() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressNumpadEnter() async {
    await sendKeyEvent(LogicalKeyboardKey.numpadEnter, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftNumpadEnter() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.numpadEnter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.numpadEnter, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressTab() async {
    await sendKeyEvent(LogicalKeyboardKey.tab, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressBackspace() async {
    await sendKeyEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdBackspace() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressAltBackspace() async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlBackspace() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.backspace, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressDelete() async {
    await sendKeyEvent(LogicalKeyboardKey.delete, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdB() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyB, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyB, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlB() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyB, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyB, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdC() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyC, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyC, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlC() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyC, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyC, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdI() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyI, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyI, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlI() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyI, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyI, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdX() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyX, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyX, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlX() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyX, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyX, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdV() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyV, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlV() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyV, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdA() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlA() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlE() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.keyE, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.keyE, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressHome() async {
    await sendKeyDownEvent(LogicalKeyboardKey.home, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.home, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressEnd() async {
    await sendKeyDownEvent(LogicalKeyboardKey.end, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.end, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressLeftArrow() async {
    await sendKeyEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressAltLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftAltLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCtlLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCmdLeftArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowLeft, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressRightArrow() async {
    await sendKeyEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressAltRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftAltRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCtlRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCtlRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCmdRightArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowRight, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressUpArrow() async {
    await sendKeyEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftUpArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdUpArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCmdUpArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressAltUpArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowUp, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressDownArrow() async {
    await sendKeyEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftDownArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressCmdDownArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressShiftCmdDownArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressAltDownArrow() async {
    await sendKeyDownEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await sendKeyDownEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.arrowDown, platform: 'macos');
    await sendKeyUpEvent(LogicalKeyboardKey.alt, platform: 'macos');
    await pumpAndSettle();
  }

  Future<void> pressEscape() async {
    await sendKeyEvent(LogicalKeyboardKey.escape, platform: 'macos');
    await pumpAndSettle();
  }
}

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
