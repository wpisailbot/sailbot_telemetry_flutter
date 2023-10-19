import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:sailbot_telemetry_flutter/widgets/AlignPositioned.dart';

Size displaySize(BuildContext context) {
  return MediaQuery.of(context).size;
}

double displayHeight(BuildContext context) {
  double height = displaySize(context).height;
  dev.log("height is: $height", name: 'testing');
  return height;
}

double displayWidth(BuildContext context) {
  double width = displaySize(context).width;
  //dev.log("width is: $width", name: 'testing');
  return width;
}

class MapPage extends StatefulWidget {
  static const String route = '/polyline';

  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telemetry')),
      drawer: buildDrawer(context, MapPage.route),
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            Flexible(
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(51.5, -0.09),
                  initialZoom: 5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.wpi.sailbot.sailbot_telemetry',
                  ),
                ],
              ),
            ),
            AlignPositioned(
              alignment: Alignment.bottomCenter,
              centerPoint: Offset(displayWidth(context) / 2, 0),
              //width: min(displayWidth(context) / 3, 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: min(displayWidth(context) / 3, 150),
                    height: min(displayWidth(context) / 3, 150),
                    child: SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          startAngle: 270,
                          endAngle: 270,
                          minimum: 0,
                          maximum: 360,
                          interval: 30,
                          majorTickStyle: const MajorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                            thickness: 1.5,
                          ),
                          minorTickStyle: const MinorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                          ),
                          minorTicksPerInterval: 10,
                          showLabels: true,
                          showTicks: true,
                          ticksPosition: ElementsPosition.outside,
                          labelsPosition: ElementsPosition.outside,
                          offsetUnit: GaugeSizeUnit.factor,
                          labelOffset: -0.2,
                          radiusFactor: 0.75,
                          showLastLabel: false,
                          pointers: const <GaugePointer>[
                            NeedlePointer(
                              value:
                                  0, // Set your initial compass heading value
                              enableDragging: false,
                              needleLength: 0.7,
                              lengthUnit: GaugeSizeUnit.factor,
                              needleStartWidth: 1,
                              needleEndWidth: 1,
                              needleColor: Color(0xFFD12525),
                              knobStyle: KnobStyle(
                                knobRadius: 0.1,
                                color: Color(0xffc4c4c4),
                              ),
                              tailStyle: TailStyle(
                                lengthUnit: GaugeSizeUnit.factor,
                                length: 0.7,
                                width: 1,
                                color: Color(0xffc4c4c4),
                              ),
                            ),
                          ],
                          annotations: const <GaugeAnnotation>[
                            GaugeAnnotation(
                              axisValue: 270,
                              positionFactor: 0.6,
                              widget: Text('W', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 90,
                              positionFactor: 0.6,
                              widget: Text('E', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 0,
                              positionFactor: 0.6,
                              widget: Text('N', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 180,
                              positionFactor: 0.6,
                              widget: Text('S', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Text("heading"),
                ],
              ),
            ),
            AlignPositioned(
              alignment: Alignment.centerRight,
              centerPoint: Offset(0, displayHeight(context) / 2),
              //width: min(displayWidth(context) / 3, 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text("True wind"),
                  SizedBox(
                    width: min(displayWidth(context) / 3, 150),
                    height: min(displayWidth(context) / 3, 150),
                    child: SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          startAngle: 270,
                          endAngle: 270,
                          minimum: 0,
                          maximum: 360,
                          interval: 30,
                          majorTickStyle: const MajorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                            thickness: 1.5,
                          ),
                          minorTickStyle: const MinorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                          ),
                          minorTicksPerInterval: 10,
                          showLabels: true,
                          showTicks: true,
                          ticksPosition: ElementsPosition.outside,
                          labelsPosition: ElementsPosition.outside,
                          offsetUnit: GaugeSizeUnit.factor,
                          labelOffset: -0.2,
                          radiusFactor: 0.75,
                          showLastLabel: false,
                          pointers: const <GaugePointer>[
                            NeedlePointer(
                              value:
                                  0, // Set your initial compass heading value
                              enableDragging: false,
                              needleLength: 0.7,
                              lengthUnit: GaugeSizeUnit.factor,
                              needleStartWidth: 1,
                              needleEndWidth: 1,
                              needleColor: Color(0xFFD12525),
                              knobStyle: KnobStyle(
                                knobRadius: 0.1,
                                color: Color(0xffc4c4c4),
                              ),
                              tailStyle: TailStyle(
                                lengthUnit: GaugeSizeUnit.factor,
                                length: 0.7,
                                width: 1,
                                color: Color(0xffc4c4c4),
                              ),
                            ),
                          ],
                          annotations: const <GaugeAnnotation>[
                            GaugeAnnotation(
                              axisValue: 270,
                              positionFactor: 0.6,
                              widget: Text('W', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 90,
                              positionFactor: 0.6,
                              widget: Text('E', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 0,
                              positionFactor: 0.6,
                              widget: Text('N', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 180,
                              positionFactor: 0.6,
                              widget: Text('S', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Text("Apparent wind"),
                  SizedBox(
                    width: min(displayWidth(context) / 3, 150),
                    height: min(displayWidth(context) / 3, 150),
                    child: SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          startAngle: 270,
                          endAngle: 270,
                          minimum: 0,
                          maximum: 360,
                          interval: 30,
                          majorTickStyle: const MajorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                            thickness: 1.5,
                          ),
                          minorTickStyle: const MinorTickStyle(
                            length: 0.16,
                            lengthUnit: GaugeSizeUnit.factor,
                          ),
                          minorTicksPerInterval: 10,
                          showLabels: true,
                          showTicks: true,
                          ticksPosition: ElementsPosition.outside,
                          labelsPosition: ElementsPosition.outside,
                          offsetUnit: GaugeSizeUnit.factor,
                          labelOffset: -0.2,
                          radiusFactor: 0.75,
                          showLastLabel: false,
                          pointers: const <GaugePointer>[
                            NeedlePointer(
                              value:
                                  0, // Set your initial compass heading value
                              enableDragging: false,
                              needleLength: 0.7,
                              lengthUnit: GaugeSizeUnit.factor,
                              needleStartWidth: 1,
                              needleEndWidth: 1,
                              needleColor: Color(0xFFD12525),
                              knobStyle: KnobStyle(
                                knobRadius: 0.1,
                                color: Color(0xffc4c4c4),
                              ),
                              tailStyle: TailStyle(
                                lengthUnit: GaugeSizeUnit.factor,
                                length: 0.7,
                                width: 1,
                                color: Color(0xffc4c4c4),
                              ),
                            ),
                          ],
                          annotations: const <GaugeAnnotation>[
                            GaugeAnnotation(
                              axisValue: 270,
                              positionFactor: 0.6,
                              widget: Text('W', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 90,
                              positionFactor: 0.6,
                              widget: Text('E', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 0,
                              positionFactor: 0.6,
                              widget: Text('N', style: TextStyle(fontSize: 16)),
                            ),
                            GaugeAnnotation(
                              axisValue: 180,
                              positionFactor: 0.6,
                              widget: Text('S', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
