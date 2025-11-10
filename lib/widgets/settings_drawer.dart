import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/widgets/cv_settings.dart';
import 'package:sailbot_telemetry_flutter/main.dart'; 
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';
import 'package:sailbot_telemetry_flutter/widgets/trim_state_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

import 'dart:developer' as dev;

final vfForwardMagnitudeProvider = StateProvider<String>((ref) => '2.0');
final rudderASProvider = StateProvider<String>((ref) => '0.05');
final rudderOBProvider = StateProvider<String>((ref) => '50000.0');

final rudderStepProvider = StateProvider<String>((ref) => '0.08');
final trimStepProvider = StateProvider<String>((ref) => '0.08');

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final networkComms = ref.watch(networkCommsProvider);
    final inputController = ref.watch(inputControllerProvider);

    final lastVFForwardMagnitude = ref.watch(vfForwardMagnitudeProvider);
    final lastRudderKP = ref.watch(rudderASProvider);
    final lastRudderKD = ref.watch(rudderOBProvider);

    final lastRudderStep = ref.watch(rudderStepProvider);
    final lastTrimStep = ref.watch(trimStepProvider);

    return Drawer(
      child: ListView(
        children: [
          ListTile(
            title: const Text("VF forward magnitude"),
            subtitle: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: lastVFForwardMagnitude),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              onSubmitted: ((String value) {
                ref.read(vfForwardMagnitudeProvider.notifier).state = value;
                networkComms?.setVFForwardMagnitude(double.parse(value));
              }),
            ),
          ),
          ListTile(
            title: const Text("Rudder Adjustment Scale"),
            subtitle: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: lastRudderKP),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              onSubmitted: ((String value) {
                ref.read(rudderASProvider.notifier).state = value;
                networkComms?.setRudderAdjustmentScale(double.parse(value));
              }),
            ),
          ),
          ListTile(
            title: const Text("Rudder Overshoot Bias"),
            subtitle: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: lastRudderKD),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              onSubmitted: ((String value) {
                ref.read(rudderOBProvider.notifier).state = value;
                networkComms?.setRudderOvershootBias(double.parse(value));
              }),
            ),
          ),
          ListTile(
            title: const Text("Rudder Control Step"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current: ${lastRudderStep}"),
                Slider(
                  activeColor: const Color.fromARGB(255, 0, 100, 255),
                  value: double.tryParse(lastRudderStep) ?? 0.08,
                  max: 0.3,
                  min: 0.01,
                  divisions: 29,
                  onChanged: (value) {
                    final stringValue = value.toStringAsFixed(3);
                    ref.read(rudderStepProvider.notifier).state = stringValue;
                    inputController.setRudderStep(value);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text("Trim Control Step"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current: ${lastTrimStep}"),
                Slider(
                  activeColor: const Color.fromARGB(255, 0, 100, 255),
                  value: double.tryParse(lastTrimStep) ?? 0.08, 
                  max: 0.3,
                  min: 0.01,
                  divisions: 29,
                  onChanged: (value) {
                    final stringValue = value.toStringAsFixed(3);
                    ref.read(trimStepProvider.notifier).state = stringValue; 
                    inputController.setTrimStep(value);
                  },
                ),
              ],
            ),
          ),
          const ListTile(
            title: Text(
              "Display Settings",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const ListTile(
            title: Text("View Mode"),
            subtitle: MapCameraToggle(), 
          ),

          const Divider(),
          const ListTile(
            title: Text(
              "Control Mode",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text("Autonomous Mode"),
            subtitle: AutonomousModeSelector(),  
          ),
          const Divider(),
          const CVSettings(),
        ],
      ),
    );
  }

  Server? findMatchingServer(List<Server> servers, Server? currentValue) {
    if (currentValue == null) return null;

    try {
      return servers
          .firstWhere((server) => server.address == currentValue.address);
    } catch (e) {
      // No matching server found
      return null;
    }
  }
}
