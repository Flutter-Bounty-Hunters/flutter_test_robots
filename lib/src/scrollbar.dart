import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the user interacting with a Scrollbar.
extension ScrollbarInteractions on WidgetTester {
  /// Press a scrollbar thumb at [thumbLocation] and drag it vertically by [delta] pixels.
  Future<void> dragScrollbar(Offset thumbLocation, double delta) async {
    //Hover to make the thumb visible with a duration long enough to run the fade in animation.
    final testPointer = TestPointer(1, PointerDeviceKind.mouse);

    await sendEventToBinding(testPointer.hover(thumbLocation, timeStamp: const Duration(seconds: 1)));
    await pumpAndSettle();

    // Press the thumb.
    await sendEventToBinding(testPointer.down(thumbLocation));
    await pump(const Duration(milliseconds: 40));

    // Move the thumb down.
    await sendEventToBinding(testPointer.move(thumbLocation + Offset(0, delta)));
    await pump();

    // Release the pointer.
    await sendEventToBinding(testPointer.up());
    await pump();
  }
}
