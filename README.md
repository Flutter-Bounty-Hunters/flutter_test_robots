<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/176973439-cf134e98-abde-429a-b845-3f7a754f2eeb.png" width="300" alt="Flutter Test Robots"><br>
  <span><b>Simulate human interactions in your tests.</b></span><br><br>
</p>

> This project is maintainbed by the [Flutter Bounty Hunters](https://flutterbountyhunters.com). Need more capabilities? [Fund a milestone](https://policies.flutterbountyhunters.com/fund-milestone) today!

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