import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';
import 'package:latlong2/latlong.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'dart:developer' as dev;

// The StateProvider to hold the currently selected string
final selectedLaunchfileProvider = StateProvider<String?>((ref) => null);

final selectedMapNameProvider = StateProvider<String?>((ref) => null);

class ProcessedMapData {
  final String displayName;
  final String fullName;
  final LatLng? northEast;
  final LatLng? southWest;

  ProcessedMapData({
    required this.displayName,
    required this.fullName,
    this.northEast,
    this.southWest,
  });
}

LatLng calculateMapCenter(LatLng northEast, LatLng southWest) {
  final centerLat = (northEast.latitude + southWest.latitude) / 2;
  final centerLng = (northEast.longitude + southWest.longitude) / 2;
  return LatLng(centerLat, centerLng);
}

void centerMapOnSelectedMap(WidgetRef ref, String displayName) {
  final processedMaps = ref.read(processedMapDataProvider);
  print("changing map to $displayName");
  
  try {
    final selectedMap = processedMaps.firstWhere(
      (map) => map.displayName == displayName,
    );

    print("Found map: ${selectedMap.displayName}");           
    print("NorthEast: ${selectedMap.northEast}");          
    print("SouthWest: ${selectedMap.southWest}");   
    
    if (selectedMap.northEast != null && selectedMap.southWest != null) {

      final center = calculateMapCenter(selectedMap.northEast!, selectedMap.southWest!);
      
      print("Centering map on $center");
      ref.read(mapPositionProvider.notifier).updatePosition(center, 15);
      
      dev.log("Centered map on ${selectedMap.displayName} at $center", name: 'map_control');
    }
  } catch (e) {
    dev.log("Map not found or no coordinates: $displayName", name: 'map_control');
  }
}

final processedMapDataProvider = Provider<List<ProcessedMapData>>((ref) {
  final rawMapNames = ref.watch(mapNameListProvider);
  
  if (rawMapNames == null) return [];

  // print("Raw map names received: $rawMapNames"); 
  
  return rawMapNames.map((rawName) {
    final parts = rawName.split(':');
    
    final displayName = parts.isNotEmpty ? parts[0] : rawName;
    
    LatLng? northEast, southWest;
    if (parts.length >= 5) {
      try {
        final lat1 = double.parse(parts[1]);
        final lng1 = double.parse(parts[2]);
        final lat2 = double.parse(parts[3]);
        final lng2String = parts[4].replaceAll('.png', '');
        final lng2 = double.parse(lng2String);

        northEast = LatLng(lat1, lng1);
        southWest = LatLng(lat2, lng2);
        // print("Parsed coordinates - NE: $northEast, SW: $southWest");
      } catch (e) {
        dev.log("Failed to parse coordinates for $rawName: $e", name: 'map_processing');
      }
    }
    
    return ProcessedMapData(
      displayName: displayName,
      fullName: rawName,
      northEast: northEast,
      southWest: southWest,
    );
  }).toList();
});

final mapDisplayNamesProvider = Provider<List<String>>((ref) {
  final processedMaps = ref.watch(processedMapDataProvider);
  return processedMaps.map((map) => map.displayName).toList();
});



class LaunchfileDropdown extends ConsumerWidget {
  const LaunchfileDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchfileList = ref.watch(launchfileListProvider);
    final selectedLaunchfile = ref.watch(selectedLaunchfileProvider);

    return launchfileList == null
        ? const CircularProgressIndicator()
        : DropdownButton<String>(
            value: selectedLaunchfile,
            hint: const Text('Select a launchfile'),
            onChanged: (String? newValue) {
              ref.read(selectedLaunchfileProvider.notifier).state = newValue;
            },
            items: launchfileList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
  }
}

class MapNameDropdown extends ConsumerWidget {
  const MapNameDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapNameList = ref.watch(mapDisplayNamesProvider);
    final selectedMapName = ref.watch(selectedMapNameProvider);

    return mapNameList.isEmpty
        ? const CircularProgressIndicator()
        : DropdownButton<String>(
            value: selectedMapName,
            hint: const Text('Select a map'),
            onChanged: (String? newValue) {
              ref.read(selectedMapNameProvider.notifier).state = newValue;
              if (newValue != null) {
                centerMapOnSelectedMap(ref, newValue);
              }
            },
            items: mapNameList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
  }
}

class ROS2ControlButtons extends ConsumerWidget {
  const ROS2ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ros2NetworkComms = ref.watch(ros2NetworkCommsProvider);
    final launchfile = ref.watch(selectedLaunchfileProvider);
    final mapName = ref.watch(selectedMapNameProvider);

    return Column( 
      children: <Widget>[
        Row(
          children: <Widget>[
            FloatingActionButton(
              child: const Icon(Icons.play_arrow),
              onPressed: () {
                ros2NetworkComms?.startLaunch(launchfile ?? "", mapName);
            }),
            FloatingActionButton(
              child: const Icon(Icons.stop),
              onPressed: () {
                ros2NetworkComms?.stopLaunch();
            }),
            const Padding(padding: EdgeInsets.all(4.0)),
            const LaunchfileDropdown(), 
          ],
        ),
        const SizedBox(height: 8),  
        const MapNameDropdown(),  
      ],
    );

  }
}
