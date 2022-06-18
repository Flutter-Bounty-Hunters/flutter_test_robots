import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates a platform clipboard in widget tests.
///
/// The simulation is achieved by using a [SimulatedClipboard]. See
/// that class for more details about how the simulation works.
extension ClipboardInteractions on WidgetTester {
  /// Simulates clipboard access for widget tests, which can't
  /// access a real platform keyboard.
  ///
  /// You should call this method before your source code attempts
  /// to send content to the [Clipboard]. After your source code
  /// sends content using [Clipboard], you can verify that content
  /// by retrieving it with [getSimulatedClipboardContent].
  void simulateClipboard() {
    _simulatedClipboard ??= SimulatedClipboard(this);
  }

  /// Makes the given [content] available from the [Clipboard]
  /// as if the user copied the [content] to the platform clipboard.
  Future<void> setSimulatedClipboardContent(String content) async {
    _simulatedClipboard ??= SimulatedClipboard(this);

    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Returns the content stored within the simulated clipboard, or
  /// `null` if no clipboard is currently simulated.
  ///
  /// To use this method to verify that your source code sent expected
  /// content to the [Clipboard], you must call [simulateClipboard]
  /// before your source code tries to send content to the [Clipboard].
  String? getSimulatedClipboardContent() {
    if (_simulatedClipboard == null) {
      return null;
    }

    return _simulatedClipboard!.clipboardText;
  }

  /// Clears any content that was stored within a simulated clipboard
  /// and stops simulating the clipboard.
  void clearSimulatedClipboard() {
    if (_simulatedClipboard == null) {
      return;
    }

    _simulatedClipboard!.dispose();
    _simulatedClipboard = null;
  }
}

/// Singleton [SimulatedClipboard], used by the [ClipboardInteractions]
/// extensions to easily simulate clipboard behavior through a [WidgetTester].
SimulatedClipboard? _simulatedClipboard;

/// Simulates platform copy/paste behavior for testing purposes.
///
/// Clipboard behavior happens on the platform side. Flutter's copy/paste
/// operations delegate to the platform over the [SystemChannels.platform]
/// channel. [SimulatedClipboard] installs itself as the handler of the
/// copy/paste channel messages, pretending to be the platform.
///
/// [SimulatedClipboard] uses `setMockMethodCallHandler()` to intercept
/// the copy/paste channel messages. Flutter automatically resets the mock
/// method handler after every test. You don't need to do that manually.
/// To explicitly deregister the mock method handler before the end of a
/// test, call [dispose()].
class SimulatedClipboard {
  SimulatedClipboard(this._tester);

  final WidgetTester _tester;

  /// The content that is currently stored in this simulated clipboard.
  String? clipboardText;

  /// Starts intercepting [Clipboard] messages sent from Flutter
  /// to the platform, and responds to those messages as a simulated
  /// clipboard.
  void init() {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, _methodCallHandler);
  }

  /// Stops intercepting [Clipboard] messages sent from Flutter to
  /// the platform.
  void dispose() {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (call.method == 'Clipboard.setData') {
      clipboardText = call.arguments['text'];
    } else if (call.method == 'Clipboard.getData') {
      return {
        'text': clipboardText,
      };
    }
  }
}
