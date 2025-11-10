import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/widgets/speed_compass_gauges.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

import 'dart:math';

class HeadingSpeedDisplay extends ConsumerWidget {
  const HeadingSpeedDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boatState = ref.watch(boatStateProvider);
    return Column(  
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text("Heading"), 
        SizedBox(
            width: min(displayWidth(context) / 3, 150),
            height: min(displayWidth(context) / 3, 150),
            child: buildCompassGauge(boatState.currentHeading)),
        const Text("Speed"),
        SizedBox(
            width: min(displayWidth(context) / 3, 150),
            height: min(displayWidth(context) / 3, 150),
            child: buildSpeedGauge(boatState.speedKnots)),
      ],
    );
    // Row(
    //   children: <Widget>[
    //     Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: <Widget>[
    //         SizedBox(
    //             width: min(displayWidth(context) / 3, 150),
    //             height: min(displayWidth(context) / 3, 150),
    //             child: buildCompassGauge(boatState.currentHeading)),
    //         const Text("heading"),
    //       ],
    //     ),
    //     Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: <Widget>[
    //         SizedBox(
    //             width: min(displayWidth(context) / 3, 150),
    //             height: min(displayWidth(context) / 3, 150),
    //             child: buildSpeedGauge(boatState.speedKnots)),
    //         const Text("Speed"),
    //       ],
    //     ),
    //   ],
    // );
  }
}
