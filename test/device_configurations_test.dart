import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/src/device_configurations.dart';

void main() {
  group("Device Configurations >", () {
    testWidgets("configures a named iPhone device", (tester) async {
      tester.asIPhone16ProMax();

      expect(tester.view.physicalSize, const Size(1320, 2868));
      expect(tester.view.devicePixelRatio, 3);
      expect(tester.view.physicalSize / tester.view.devicePixelRatio, const Size(440, 956));
    });

    testWidgets("configures a named Samsung device", (tester) async {
      tester.asSamsungGalaxyA16();

      expect(tester.view.physicalSize, const Size(1080, 2340));
      expect(tester.view.devicePixelRatio, 3);
      expect(tester.view.physicalSize / tester.view.devicePixelRatio, const Size(360, 780));
    });

    testWidgets("configures an arbitrary device", (tester) async {
      tester.configureForDevice(
        const DeviceConfiguration(
          name: "Test Phone",
          physicalSize: Size(1000, 2000),
          devicePixelRatio: 2.5,
        ),
      );

      expect(tester.view.physicalSize, const Size(1000, 2000));
      expect(tester.view.devicePixelRatio, 2.5);
    });
  });
}
