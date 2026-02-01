import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/camera_widget.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/model_3d_widget.dart';

// final cameraToggleProvider =
//     StateProvider<bool>((ref) => true); // true for camera, false for map

// 0 = Map, 1 = Camera, 2 = 3D Model
final viewModeProvider = StateProvider<int>((ref) => 0);

// Auto-computed: true when Map visible, false when Camera/Model visible
final cameraToggleProvider = Provider<bool>((ref) {
  final currentView = ref.watch(viewModeProvider);
  return true;  // true for camera or 3D model view, false for map
});

class MapCameraToggle extends ConsumerWidget {
  const MapCameraToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final currentView = ref.watch(viewModeProvider);
    final networkComms = ref.watch(networkCommsProvider);
    return ToggleButtons(
      isSelected: [
        currentView == 0,
        currentView == 1,
        currentView == 2,
      ],
      onPressed: (index) {
        ref.read(viewModeProvider.notifier).state = index;
        
        if (index == 1) {
          print("Starting video streaming");
          networkComms?.startVideoStreaming();
        } else {
          print("Stopping video streaming");
          networkComms?.cancelVideoStreaming();
        }
      },
      children: const [
        Icon(Icons.map),
        Icon(Icons.camera),
        Icon(Icons.view_in_ar),  // 3D model icon
      ],
    );
  }
}

class MapCameraWidget extends ConsumerWidget {
  const MapCameraWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(viewModeProvider);
    
    switch (currentView) {
      case 1:
        return const CameraView();
      case 2:
        return const Model3DWidget();
      default:
        return const MapView();
    }
  }
}
