## 0.0.16 - Add key combos (June, 2022)

* CMD + B
* CMD + I

## 0.0.15 - Add key combos (June, 2022)

* ALT + UP ARROW
* ALT + DOWN ARROW

## 0.0.14 - Changed simulated clipboard initialization (June, 2022)

* Changed `ClipboardInteractions` > `simulateClipboard()` to clear the clipboard content, if a clipboard simulation is already active. This provides a consistent initial state across multiple tests.

## 0.0.13 - Fixed simulated clipboard initialization (June, 2022)

* Bugfix - `ClipboardInteractions` previously didn't `init()` the simulation when requested. Now it does.

## 0.0.12 - Changed simulated clipboard API (June, 2022)

* BREAKING - Changed `ClipboardInteractions` extensions to return clipboard text synchronously.

## 0.0.11 - Added SimulatedClipboard (June, 2022)

* Added SimulatedClipboard and WidgetTester extensions to easily verify expected Clipboard interactions.

## 0.0.10 - Add HOME and END (June, 2022)

* HOME
* END

## 0.0.9 - Fixed a bug (June, 2022)

* Fixed CTL + BACKSPACE, previous implementation was pressing CMD + CTL

## 0.0.8 - Add key combos (June, 2022)

* CTL + BACKSPACE
* ALT + BACKSPACE

## 0.0.7 - Add key combos (June, 2022)

* CTL + E

## 0.0.6 - Add key combos (June, 2022)

* CMD + BACKSPACE

## 0.0.5 - Add key combos (June, 2022)

* SHIFT + UP ARROW
* SHIFT + CMD + UP ARROW
* SHIFT + DOWN ARROW
* SHIFT + CMD + DOWN ARROW

## 0.0.4 - Add key combos (June, 2022)

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

## 0.0.3 - Add key combos (June, 2022)

* CMD/CTL + A 

## 0.0.2 - Add key combos (June, 2022)

* CMD/CTL + C
* CMD/CTL + X
* CMD/CTL + V 

## 0.0.1 - Initial release (June, 2022)

Test APIs for:
* pressing specific keyboard keys
* typing arbitrary text with keyboard keys
