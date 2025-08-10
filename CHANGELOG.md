## 1.0.0
### Aug 10, 2025
First stable release.

No changes from previous release, but we think we've reached API stability.

## 0.1.0
### Aug 9, 2025
 * FEATURE: Added `pressShiftTab`
 * ADJUSTMENT: Make it optional to "pump and settle" for every key press (instead of forcing it)
 * ADJUSTMENT: Added a "quirks mode" when pressing ENTER via IME
 * BREAKING: Removed unnecessary `WidgetTester` parameter for some key presses

## 0.0.24
### May, 2025
Added `pressSpaceAdaptive`

## 0.0.23
### Feb, 2024
Added support for undo/redo shortcuts

 * `pressCmdZ`
 * `pressCmdShiftZ`
 * `pressCtrlZ`
 * `pressCtrlShiftZ`

## 0.0.22
### Oct, 2023
Add support for pressing ENTER via IME

 * `pressEnterWithIme` - Simulate pressing the "newline" button on a software keyboard.
 * `pressEnterAdapative` - Run `pressEnter()` and if it's not handled, run `pressEnterWithIme()`.
 * `pressNumpadEnterWithIme`
 * `pressNumpadEnterAdaptive`

## 0.0.21
### September, 2023
Additions and adjustments to work around Flutter's test key simulation

 * `pressKey`, `pressKeyDown`, `releaseKeyUp`, `repeatKey` wraps standard Flutter key simulations
    to prevent platform mismatches across key presses.
 * Don't use "ios" platform when simulating keyboard content typing because Flutter has a
    bug with generating key events for characters, specifically when simulating `platform` "ios".

## 0.0.20
### September, 2023
(DEPRECATED) Fixed a bug in keyboard key event platform overrides from version `0.0.19`

## 0.0.19
### September, 2023
(DEPRECATED) Keyboard and IME additions

 * CTRL + HOME/END
 * CMD + HOME/END
 * SHIFT + ALT + UP/DOWN
 * Tab button through IME (i.e., software keyboard)
 * All keyboard event now simulate with a platform as chosen by `defaultTargetPlatform`

## 0.0.18
### December, 2022
Added arbitrary delta from simulated IME

## 0.0.17
### August, 2022
Added simulated IME text input and backspace

## 0.0.16
### June, 2022
Add key combos

* CMD + B
* CMD + I

## 0.0.15
Add key combos (June, 2022)

* ALT + UP ARROW
* ALT + DOWN ARROW

## 0.0.14
### June, 2022
Changed simulated clipboard initialization

* Changed `ClipboardInteractions` > `simulateClipboard()` to clear the clipboard content, if a clipboard simulation is already active. This provides a consistent initial state across multiple tests.

## 0.0.13
### June, 2022
Fixed simulated clipboard initialization

* Bugfix - `ClipboardInteractions` previously didn't `init()` the simulation when requested. Now it does.

## 0.0.12
### June, 2022
Changed simulated clipboard API

* BREAKING - Changed `ClipboardInteractions` extensions to return clipboard text synchronously.

## 0.0.11
### June, 2022
Added SimulatedClipboard

* Added SimulatedClipboard and WidgetTester extensions to easily verify expected Clipboard interactions.

## 0.0.10
### June, 2022
Add HOME and END

* HOME
* END

## 0.0.9
### June, 2022
Fixed a bug

* Fixed CTL + BACKSPACE, previous implementation was pressing CMD + CTL

## 0.0.8
### June, 2022
Add key combos

* CTL + BACKSPACE
* ALT + BACKSPACE

## 0.0.7
### June, 2022
Add key combos

* CTL + E

## 0.0.6
### June, 2022
Add key combos

* CMD + BACKSPACE

## 0.0.5
### June, 2022
Add key combos

* SHIFT + UP ARROW
* SHIFT + CMD + UP ARROW
* SHIFT + DOWN ARROW
* SHIFT + CMD + DOWN ARROW

## 0.0.4
### June, 2022
Add key combos

* ALT + LEFT ARROW
* CTL + LEFT ARROW
* SHIFT + CTL + LEFT ARROW
* CMD + LEFT ARROW
* SHIFT + CMD + LEFT ARROW
* ALT + RIGHT ARROW
* CTL + RIGHT ARROW
* SHIFT + CTL + RIGHT ARROW
* CMD + RIGHT ARROW
* SHIFT + CMD + RIGHT ARROW

## 0.0.3
### June, 2022
Add key combos

* CMD/CTL + A 

## 0.0.2
### June, 2022
Add key combos

* CMD/CTL + C
* CMD/CTL + X
* CMD/CTL + V 

## 0.0.1
### June, 2022
Initial release

Test APIs for:
* pressing specific keyboard keys
* typing arbitrary text with keyboard keys
