import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/icons.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'dart:developer' as dev;

class PathButtons extends ConsumerStatefulWidget {
  const PathButtons({Key? key}) : super(key: key);

  @override
  _PathButtonsState createState() => _PathButtonsState();
}

class _PathButtonsState extends ConsumerState<PathButtons> {
  late TextEditingController latController;
  late TextEditingController lonController;
  FocusNode latFocusNode = FocusNode();
  FocusNode lonFocusNode = FocusNode();
  LatLng latlng = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    latController = TextEditingController();
    lonController = TextEditingController();
  }

  @override
  void dispose() {
    latController.dispose();
    lonController.dispose();
    latFocusNode.dispose();
    lonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final mapState = ref.watch(mapStateProvider);
    final pressLat = mapState.mapPressLatLng?.latitude;
    final pressLong = mapState.mapPressLatLng?.longitude;
    latlng = LatLng(pressLat ?? 0, pressLong ?? 0);

    if (!mapState.showPathButton || !isMapVisible) {
      latController.text = "";
      lonController.text = "";
      return const SizedBox.shrink();
    }

    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;

    // Initial position
    double top = mapState.mapPressPosition?.global.dy ?? 0;
    double left = mapState.mapPressPosition?.global.dx ?? 0;

    // Widget dimensions
    double widgetHeight = 180; // Approximate height of the widget
    double widgetWidth = 240; // Approximate width of the widget

    // Adjust position if the widget goes off-screen
    if (top + widgetHeight > screenSize.height) {
      top = screenSize.height - widgetHeight;
    }
    if (left + widgetWidth > screenSize.width) {
      left = screenSize.width - widgetWidth;
    }

    return Positioned(
      top: top,
      left: left,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: <Widget>[
          Column(children: <Widget>[
            SizedBox(
              width: 120,
              child: ListTile(
                title: const Text("Latitude"),
                subtitle: TextField(
                  controller: latController,
                  focusNode: latFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: pressLat.toString()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onEditingComplete: () {
                    latlng = LatLng(
                        double.parse(latController.text), latlng.longitude);
                    FocusScope.of(context)
                        .requestFocus(lonFocusNode); // Move to next field
                  },
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: ListTile(
                title: const Text("Longitude"),
                subtitle: TextField(
                  controller: lonController,
                  focusNode: lonFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: pressLong.toString()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onEditingComplete: () {
                    latlng = LatLng(
                        latlng.latitude, double.parse(lonController.text));
                    FocusScope.of(context).unfocus(); // Unfocus the field
                  },
                ),
              ),
            ),
          ]),
          Column(children: <Widget>[
            FloatingActionButton(
              onPressed: () {
                updateLatLngFromTextFields();
                _addWaypoint(WaypointType.WAYPOINT_TYPE_INTERSECT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationZ(pi / 4),
                alignment: Alignment.center,
                child: const Icon(Icons.add),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                updateLatLngFromTextFields();
                _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_RIGHT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationX(pi),
                alignment: Alignment.center,
                child: const Icon(MyFlutterApp.u_turn),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                updateLatLngFromTextFields();
                _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_LEFT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationZ(pi),
                alignment: Alignment.center,
                child: const Icon(MyFlutterApp.u_turn),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void updateLatLngFromTextFields() {
    double? latitude = double.tryParse(latController.text);
    double? longitude = double.tryParse(lonController.text);

    if (latitude != null && longitude != null) {
      latlng = LatLng(latitude, longitude);
    }
  }

  void _addWaypoint(WaypointType type, LatLng? pos) {
    dev.log("Adding waypoint: $pos");
    var tappedPoint = Waypoint();
    tappedPoint.type = type;
    var point = Point();
    point.latitude = pos?.latitude ?? 0;
    point.longitude = pos?.longitude ?? 0;
    tappedPoint.point = point;

    ref.read(networkCommsProvider)?.addWaypoint(tappedPoint);
    ref.read(mapStateProvider.notifier).resetTapDetails();
  }
}
