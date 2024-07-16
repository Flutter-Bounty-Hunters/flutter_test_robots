---
layout: layouts/homepage.jinja
contentRenderers: 
  - markdown
  - jinja
---
## Quickly press keys
With a Flutter `WidgetTester`, common shortcut key presses require 3-5 method calls. With `flutter_test_robots`, you only need to make a single method call.

{{ components.code_two_column() }}

--- 

## Simulate a user typing
The `flutter_test_robots` package offers unique tools for simulating user typing input. You can either simulate input through the OS Input Method Editor (IME), or through direct physical keyboard key pressed.

### Simulate IME input
When you want to simulate IME text input, `flutter_test_robots` generates IME insertion deltas for every character in your text and then sends them through Flutter’s IME communication channel.

```dart
testWidgets((tester) async {
  // Setup the test.

  // Type “Hello, World!” via IME.
  await tester.ime.typeText("Hello, World!");

  // Verify expectations.
});
```

### Simulate Keyboard Input
When you want to simulate hardware keyboard text input, `flutter_test_robots` maps every character of your text to a physical key press and then simulates that press.

```dart
testWidgets((tester) async {
  // Setup the test.
    
  // Type “Hello, World!” via physical keyboard.
  await tester.typeKeyboardText(
    "Hello, World!"
  );
  
  // Verify expectations.
});
```

---

## Built by the<br>Flutter Bounty Hunters
This package was built by the [Flutter Bounty Hunters (FBH)](https://flutterbountyhunters.com). 
The Flutter Bounty Hunters is a development agency that works exclusively on open source Flutter 
and Dark packages.

With funding from corporate clients, the goal of the Flutter Bounty Hunters is to solve 
common problems for The Last Time™. If your team gets value from Flutter Bounty Hunter 
packages, please consider funding further development. 

### Other FBH packages
Other packages that the Flutter Bounty Hunters brought to the community...

[Super Editor, Super Text, Attributed Text](https://github.com/superlistapp/super_editor), [Static Shock](https://staticshock.io), 
[Follow the Leader](https://github.com/flutter-bounty-hunters/follow_the_leader), [Overlord](https://github.com/flutter-bounty-hunters/overlord),
[Flutter Test Robots](https://github.com/flutter-bounty-hunters/flutter_test_robots), and more.

## Contributors
The `flutter_test_robots` package was built by...

{{ components.contributors() }}