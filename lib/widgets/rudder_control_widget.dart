import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'dart:math';
import 'dart:io' show Platform;

class RudderControlWidget extends ConsumerWidget {
  RudderControlWidget({super.key});
  NetworkComms? _networkComms;
  String _lastAutoMode = "NONE";
  final _controller = CircleDragWidget(
      width: 150,
      height: 75,
      lineLength: 60,
      radius: 7,
      resetOnRelease: Platform.isAndroid || Platform.isIOS ? true : false,
      isInteractive: true,
      callback: (){},
      key: GlobalKey<CircleDragWidgetState>(),
    );
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _controller.callback = _updateRudderAngle;
    final String autonomousMode = ref.watch(autonomousModeProvider);
    final boatState = ref.watch(boatStateProvider);
    _networkComms = ref.watch(networkCommsProvider);

    if(autonomousMode == 'FULL') {
      _controller.setAngle(boatState.rudderPosition * (pi / 180) * -1);
    } else {
      if(autonomousMode == 'NONE' && autonomousMode != _lastAutoMode){
        _controller.setAngle(0);
      }
    }
    _lastAutoMode = autonomousMode;

    return _controller;
  }

  _updateRudderAngle(double angle) {
    // print(angle);
    _networkComms?.setRudderAngle(angle);
  }

  setInteractive(bool interactive){
    _controller.setInteractive(interactive);
  }
  
  void setAngle(double radians) {
    _controller.setAngle(radians);
  }
}