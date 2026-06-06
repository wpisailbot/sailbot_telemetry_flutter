import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

final videoSourceProvider = StateProvider<String>((ref) => 'COLOR');

class VideoSourceSelect extends ConsumerWidget {
  const VideoSourceSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final networkComms = ref.watch(networkCommsProvider);
    final selectedVideoSource = ref.watch(videoSourceProvider);
    final videoSources = ref.watch(videoSourceListProvider);

    return isMapVisible
        ? const Text("")
        : DropdownButton<String>(
            value: selectedVideoSource,
            dropdownColor: const Color.fromARGB(255, 255, 255, 255),
            onChanged: (String? newValue) {
              networkComms?.setCameraSource(newValue!);
              ref.read(videoSourceProvider.notifier).state = newValue!;
            },
            items: videoSources
                .map<DropdownMenuItem<String>>((String source) {
              return DropdownMenuItem<String>(
                value: source,
                child: Text(source),
              );
            }).toList(),
          );
  }
}
