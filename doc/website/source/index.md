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
The `flutter_test_robots` package offers unique tools for simulating user typing input. You can either simulate input through the OS Input Method Editor (IME), or through direct physical keyboard key presses.

### Simulate IME input
Simulate a variety of IME text editing behaviors:

```dart
testWidgets("my test", (tester) async {
  // Setup the test.

  // Type “Hello, World!” via IME.
  await tester.ime.typeText("Hello, World!");

  // Type text with an accented character.
  await tester.ime.typeText("café");

  // Simulate user-configured text expansion and autocorrect behavior.
  tester.ime.install(
    expansions: {
      "omw": "On my way!",
    },
    autocorrects: {
      "teh": "the",
    },
  );
  await tester.ime.typeText(" omw teh ");

  // Simulate software keyboard buttons.
  await tester.ime.backspace();
  await tester.ime.delete();
  await tester.ime.pressAction(TextInputAction.search);

  // Verify expectations.
});
```

#### What is an IME?
The IME is the operating system's Input Method Editor, which intercepts all keyboard input and reports
changes to the app with an open IME connection.

Among other responsibilities, the IME applies spelling autocorrect changes, applies user selected
suggested words, and orchestrates compound character entry.

#### How the simulator works

In Flutter IME input from the user works like this:

    User action → software keyboard (IME) → send deltas to Flutter via system channel → Flutter sends deltas to active `DeltaTextInputClient`

In a `flutter_test_robots` test, IME input is simulated like this:

    Run simulator method → simulator finds the active `DeltaTextInputClient` → sends deltas to the `DeltaTextInputClient`

The key detail to make this work is for `flutter_test_robots` to find the active `TextInputClient`.
To do this, `flutter_test_robots` pretends to be the global IME connection by making itself Flutter's
global `TextInputControl` within the `TextInput` singleton. By doing this, whenever any editor or 
text field opens an IME connection, Flutter registers that `TextInputClient` with the fake 
`TextInputControl`. From that moment on, `flutter_test_robots` knows where to direct all simulated 
editing deltas.


### Simulate Keyboard Input
When you want to simulate hardware keyboard text input, `flutter_test_robots` maps every character of your text to a physical key press and then simulates that press.

```dart
testWidgets("my test", (tester) async {
  // Setup the test.
    
  // Type “Hello, World!” via physical keyboard.
  await tester.typeKeyboardText(
    "Hello, World!"
  );
  
  // Verify expectations.
});
```

## Other Test Robot Features

### Simulate platform clipboard access
Widget tests don't have access to a real platform clipboard. `flutter_test_robots` can simulate Flutter's
platform clipboard channel so you can test copy and paste behavior.

```dart
testWidgets("copies text", (tester) async {
  tester.simulateClipboard();

  // Run app behavior that calls Clipboard.setData(...).

  expect(tester.getSimulatedClipboardContent(), "Copied text");
});
```

```dart
testWidgets("pastes text", (tester) async {
  tester.simulateClipboard();
  await tester.setSimulatedClipboardContent("Text from the clipboard");

  // Run app behavior that calls Clipboard.getData(...).
});
```

### Test popular device sizes
Configure the test viewport like common phones, or loop through every built-in device.

```dart
testWidgets("renders on iPhone 16 Pro Max", (tester) async {
  tester.asIPhone16ProMax();

  await tester.pumpWidget(MyApp());
});

testWidgets("renders on every built-in test device", (tester) async {
  for (final device in TestDevices.all) {
    tester.configureForDevice(device);

    await tester.pumpWidget(MyApp());
  }
});
```

### Drag scrollbars
When a widget uses a Flutter `Scrollbar`, drag the scrollbar thumb directly.

```dart
testWidgets("drags a scrollbar", (tester) async {
  await tester.pumpWidget(MyScrollableApp());

  await tester.dragScrollbarDown(200);
  await tester.dragScrollbarUp(100);
});
```

---

## Built by the<br>Flutter Bounty Hunters
This package was built by the [Flutter Bounty Hunters (FBH)](https://flutterbountyhunters.com). 
The Flutter Bounty Hunters is a development agency that works exclusively on open source Flutter 
and Dart packages.

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
