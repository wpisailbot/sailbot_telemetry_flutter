import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

class TrimStateWidget extends ConsumerWidget {
  const TrimStateWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boatState = ref.watch(boatStateProvider);
    final isMapVisible = ref.watch(cameraToggleProvider);
    if (!isMapVisible) {
      return const SizedBox.shrink();
    }
    String currentTrimState = '';
    switch (boatState.currentTrimState) {
      case TrimState.TRIM_STATE_MIN_LIFT:
        currentTrimState = "MIN_LIFT";
        break;
      case TrimState.TRIM_STATE_MAX_LIFT_PORT:
        currentTrimState = "MAX_LIFT_PORT";
        break;
      case TrimState.TRIM_STATE_MAX_LIFT_STARBOARD:
        currentTrimState = "MAX_LIFT_STBD";
        break;
      case TrimState.TRIM_STATE_MAX_DRAG_PORT:
        currentTrimState = "MAX_DRAG_PORT";
        break;
      case TrimState.TRIM_STATE_MAX_DRAG_STARBOARD:
        currentTrimState = "MAX_DRAG_STBD";
        break;
      case TrimState.TRIM_STATE_MANUAL:
        currentTrimState = "MANUAL";
        break;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const Text("Trim state:"),
      Text(
        currentTrimState,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
  }
}
