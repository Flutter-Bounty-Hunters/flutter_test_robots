import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Extensions for configuring a [WidgetTester] like a popular mobile device.
extension DeviceConfigurations on WidgetTester {
  void asIPhone14() {
    configureForDevice(TestDevices.iPhone14);
  }

  void asIPhone15() {
    configureForDevice(TestDevices.iPhone15);
  }

  void asIPhone15Pro() {
    configureForDevice(TestDevices.iPhone15Pro);
  }

  void asIPhone15ProMax() {
    configureForDevice(TestDevices.iPhone15ProMax);
  }

  void asIPhone16() {
    configureForDevice(TestDevices.iPhone16);
  }

  void asIPhone16Pro() {
    configureForDevice(TestDevices.iPhone16Pro);
  }

  void asIPhone16ProMax() {
    configureForDevice(TestDevices.iPhone16ProMax);
  }

  void asIPhone16e() {
    configureForDevice(TestDevices.iPhone16e);
  }

  void asIPhone17() {
    configureForDevice(TestDevices.iPhone17);
  }

  void asIPhone17ProMax() {
    configureForDevice(TestDevices.iPhone17ProMax);
  }

  void asSamsungGalaxyA06() {
    configureForDevice(TestDevices.samsungGalaxyA06);
  }

  void asSamsungGalaxyA14() {
    configureForDevice(TestDevices.samsungGalaxyA14);
  }

  void asSamsungGalaxyA15() {
    configureForDevice(TestDevices.samsungGalaxyA15);
  }

  void asSamsungGalaxyA16() {
    configureForDevice(TestDevices.samsungGalaxyA16);
  }

  void asSamsungGalaxyS24Ultra() {
    configureForDevice(TestDevices.samsungGalaxyS24Ultra);
  }

  void asSamsungGalaxyS25Ultra() {
    configureForDevice(TestDevices.samsungGalaxyS25Ultra);
  }

  /// Configures the tester with [configuration].
  void configureForDevice(DeviceConfiguration configuration) {
    view
      ..physicalSize = configuration.physicalSize
      ..devicePixelRatio = configuration.devicePixelRatio;

    addTearDown(resetDeviceConfiguration);
  }

  /// Resets the tester's device viewport overrides.
  void resetDeviceConfiguration() {
    view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  }
}

/// Popular mobile device configurations for widget tests.
///
/// This list favors globally popular phone models released or sold heavily from
/// 2023 through 2025. The iPhone values use Apple's native render scale. The
/// Samsung values use practical Android density defaults for Flutter tests.
class TestDevices {
  /// All built-in test device configurations.
  static const List<DeviceConfiguration> all = [
    iPhone14,
    iPhone15,
    iPhone15Pro,
    iPhone15ProMax,
    iPhone16,
    iPhone16Pro,
    iPhone16ProMax,
    iPhone16e,
    iPhone17,
    iPhone17ProMax,
    samsungGalaxyA06,
    samsungGalaxyA14,
    samsungGalaxyA15,
    samsungGalaxyA16,
    samsungGalaxyS24Ultra,
    samsungGalaxyS25Ultra,
  ];

  static const DeviceConfiguration iPhone14 = DeviceConfiguration(
    name: "iPhone 14",
    physicalSize: Size(1170, 2532),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone15 = DeviceConfiguration(
    name: "iPhone 15",
    physicalSize: Size(1179, 2556),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone15Pro = DeviceConfiguration(
    name: "iPhone 15 Pro",
    physicalSize: Size(1179, 2556),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone15ProMax = DeviceConfiguration(
    name: "iPhone 15 Pro Max",
    physicalSize: Size(1290, 2796),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone16 = DeviceConfiguration(
    name: "iPhone 16",
    physicalSize: Size(1179, 2556),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone16Pro = DeviceConfiguration(
    name: "iPhone 16 Pro",
    physicalSize: Size(1206, 2622),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone16ProMax = DeviceConfiguration(
    name: "iPhone 16 Pro Max",
    physicalSize: Size(1320, 2868),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone16e = DeviceConfiguration(
    name: "iPhone 16e",
    physicalSize: Size(1170, 2532),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone17 = DeviceConfiguration(
    name: "iPhone 17",
    physicalSize: Size(1206, 2622),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration iPhone17ProMax = DeviceConfiguration(
    name: "iPhone 17 Pro Max",
    physicalSize: Size(1320, 2868),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration samsungGalaxyA06 = DeviceConfiguration(
    name: "Samsung Galaxy A06",
    physicalSize: Size(720, 1600),
    devicePixelRatio: 2,
  );

  static const DeviceConfiguration samsungGalaxyA14 = DeviceConfiguration(
    name: "Samsung Galaxy A14",
    physicalSize: Size(1080, 2408),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration samsungGalaxyA15 = DeviceConfiguration(
    name: "Samsung Galaxy A15",
    physicalSize: Size(1080, 2340),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration samsungGalaxyA16 = DeviceConfiguration(
    name: "Samsung Galaxy A16",
    physicalSize: Size(1080, 2340),
    devicePixelRatio: 3,
  );

  static const DeviceConfiguration samsungGalaxyS24Ultra = DeviceConfiguration(
    name: "Samsung Galaxy S24 Ultra",
    physicalSize: Size(1440, 3120),
    devicePixelRatio: 3.75,
  );

  static const DeviceConfiguration samsungGalaxyS25Ultra = DeviceConfiguration(
    name: "Samsung Galaxy S25 Ultra",
    physicalSize: Size(1440, 3120),
    devicePixelRatio: 3.75,
  );

  const TestDevices._();
}

/// A test device viewport configuration for a [WidgetTester].
class DeviceConfiguration {
  const DeviceConfiguration({
    required this.name,
    required this.physicalSize,
    required this.devicePixelRatio,
  });

  /// A human-readable device name.
  final String name;

  /// The device display size in physical pixels, in portrait orientation.
  final Size physicalSize;

  /// The number of physical pixels for each logical pixel.
  final double devicePixelRatio;

  /// The device display size in logical pixels, in portrait orientation.
  Size get logicalSize => physicalSize / devicePixelRatio;
}
