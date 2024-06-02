<p align="center">
  <img src="https://github.com/Flutter-Bounty-Hunters/flutter_test_robots/assets/7259036/957e6907-6dfa-4614-810d-3d79ad6bd92d" alt="Flutter Test Robots - Easily simulate human behaviors in tests">
</p>

<p align="center">
  <a href="https://flutterbountyhunters.com" target="_blank">
    <img src="https://github.com/Flutter-Bounty-Hunters/flutter_test_robots/assets/7259036/1b19720d-3dad-4ade-ac76-74313b67a898" alt="Built by the Flutter Bounty Hunters">
  </a>
</p>

<br><br>

<p align="center">Check out our <a href="https://flutter-bounty-hunters.github.io/flutter_test_robots/" target="_blank">Usage Guide</a></p>

---

## Easy keyboard shortcuts
`flutter_test_robots` adds methods to `WidgetTester` for many common keyboard shortcuts.

```dart
void main() {
  testWidgets("easy shortcuts", (tester) async {
    await tester.pressEnter();

    await tester.pressShiftEnter();
    
    await tester.pressCmdAltLeftArrow();
  });
}
```

## Simulate hardware keyboard text input
`flutter_test_robots` presses key combos for every character in a given string.

```dart
void main() {
  testWidgets("type with a hardware keyboard", (tester) async {
    // Simulate every key press that's needed to type "Hello, world!".
    await tester.typeKeyboardText("Hello, world!");
  });
}
```

## Simulate IME text input
`flutter_test_robots` breaks strings into text editing deltas and sends the deltas through the
standard `DeltaTextInputClient` API.

```dart
void main() {
  testWidgets("type with the IME", (tester) async {
    // Simulate every IME delta needed to type "Hello, world!".
    await tester.ime.typeText("Hello, world!");
  });
}
```
