import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/nodes_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';
import 'package:sailbot_telemetry_flutter/widgets/trim_state_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/ballast_slider.dart';
import 'package:sailbot_telemetry_flutter/widgets/path_point.dart';
import 'package:sailbot_telemetry_flutter/widgets/path_buttons.dart';
import 'package:sailbot_telemetry_flutter/widgets/video_source_select.dart';
import 'package:sailbot_telemetry_flutter/widgets/heading_speed_display.dart';
import 'package:sailbot_telemetry_flutter/widgets/wind_direction_display.dart';
import 'package:sailbot_telemetry_flutter/widgets/align_positioned.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/rudder_control_widget.dart';
import 'package:gamepads/gamepads.dart';
import 'dart:async';
import 'package:sailbot_telemetry_flutter/utils/gamepad_normalizer.dart';
import 'package:sailbot_telemetry_flutter/utils/input_controller.dart';

import 'dart:developer' as dev;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

final GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

// Riverpod provider
final inputControllerProvider = Provider<InputController>((ref) {
  final c = InputController();
  ref.onDispose(c.stop);
  return c;
});


class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}


class _MyAppState extends ConsumerState<MyApp> {
  NetworkComms? _networkComms;
  final GlobalKey<CircleDragWidgetState> _trimTabKey =GlobalKey<CircleDragWidgetState>();
  final FocusNode _rootFocus = FocusNode();
  late final RudderControlWidget _rudderControlWidget = RudderControlWidget();
  late final CircleDragWidget _trimTabControlWidget = CircleDragWidget(
  width: 150,
  height: 75,
  lineLength: 60,
  radius: 7,
  resetOnRelease: false,
  isInteractive: true,
  callback: _updateTrimtabAngle,
  key: _trimTabKey,
  );
  
  @override
  void initState() {
    super.initState();

    // Request focus once after first frame so the Flutter view is focused
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocus.requestFocus();
    });

    final ic = ref.read(inputControllerProvider);

    // Inject callbacks to talk to your network layer
    ic.onRudder = (angle) => _updateRudderAngle(angle); // _networkComms?.setRudderAngle(angle);
    ic.onTrimtab = (angle) => _updateTrimtabAngle(angle); // _networkComms?.setTrimtabAngle(angle);
    ic.onTack = () => _networkComms?.requestTack();
    ic.onAutoMode = (mode) {
      final notifier = ref.read(autonomousModeProvider.notifier);
      notifier.state = mode; // 'NONE' | 'BALLAST' | 'TRIMTAB' | 'FULL'
      ic.applyMode(mode);
    };

    ic.start(); // begin listening + ticking
  }

  @override
  void dispose() {
    ref.read(inputControllerProvider).stop();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ref.listen<AsyncValue<List<Server>>>(serverListProvider, (previous, next) {
      next.when(
        loading: () {},
        error: (error, stackTrace) {},
        data: (servers) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedServerProvider.notifier).state = servers[0];
            dev.log("3. Setting current server to: ${servers[0].name}");
          });
        },
      );
    });

    // this is only used to reset the autonomous mode to NONE when we reconnect, comment out when we don't have a robot to connect to
    // because it gets called on every try of rebuild connection which is very often

    ref.listen<NetworkComms?>(networkCommsProvider, (_, networkComms) {
      _networkComms = networkComms;
      ref.read(autonomousModeProvider.notifier).state = 'NONE';
    });

    _networkComms = ref.watch(networkCommsProvider);
    ref.read(ros2NetworkCommsProvider.notifier).initialize();
    final trimTabControlWidget = _trimTabControlWidget;

    final rudderControlWidget = _rudderControlWidget;

    ref.listen<String>(autonomousModeProvider, (_, selectedMode) {
      print(selectedMode);
      if (selectedMode == 'NONE') {
        dev.log('Manual control');
        _networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_NONE);

        trimTabControlWidget.setInteractive(true);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'BALLAST') {
        dev.log('Auto ballast');
        _networkComms
            ?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_BALLAST);

        trimTabControlWidget.setInteractive(true);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'TRIMTAB') {
        dev.log('auto trimtab');
        _networkComms
            ?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_TRIMTAB);
        trimTabControlWidget.setInteractive(false);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'FULL') {
        dev.log('Full auto');
        _networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_FULL);

        trimTabControlWidget.setInteractive(false);
        rudderControlWidget.setInteractive(false);
      }
    });


    return MaterialApp(
      title: "Sailbot Telemetry",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Disable Android's jank-ass overscroll animation
      // builder: (context, child) {
      //   return ScrollConfiguration(
      //     behavior: CustomScrollBehavior(),
      //     child: child!,
      //   );
      // },
      builder: (context, child) {
        return Focus(
          focusNode: _rootFocus,
          autofocus: true,     // requests focus too; PostFrame callback is a backup
          child: child ?? const SizedBox.shrink(),
        );
      }, 
      home: Scaffold(
          drawer: const NodesDrawer(),
          endDrawer: const SettingsDrawer(),
          key: _scaffoldState,
          body: Stack(children: [
            const Flex(direction: Axis.horizontal, children: <Widget>[
              Flexible(child: MapCameraWidget()),
            ]),
            // const Align(
            //   alignment: Alignment.centerRight,
            //   child: MapCameraToggle(),
            // ),
            DrawerIconWidget(_scaffoldState),
            AlignPositioned(
                alignment: Alignment.centerLeft,
                centerPoint: Offset(displayWidth(context), displayHeight(context) / 3.5),
                child: const HeadingSpeedDisplay()),
            AlignPositioned(
                alignment: Alignment.centerRight,
                centerPoint: Offset(0, displayHeight(context) / 3.5),
                child: const WindDirectionDisplay()),
            Align(
                alignment: Alignment.topRight,
                child: SettingsIconWidget(_scaffoldState)),
            Align(
                alignment: Alignment.topCenter,
                child: Container(
                  transform: Matrix4.translationValues(0, 0, 0),
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const TrimStateWidget(),  // ← Keep only this, remove Column/Divider/AutonomousModeSelector
                ),
              ),
            // Align(
            //   alignment: Alignment.centerRight,
            //   child: Container(
            //     transform: Matrix4.translationValues(0, 120.0, 0),
            //     width: 150,
            //     decoration: BoxDecoration(
            //       color: Colors.white.withOpacity(1),
            //       borderRadius: BorderRadius.circular(10),
            //       border: Border.all(color: Colors.grey),
            //     ),
            //     child:
            //         Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            //       const TrimStateWidget(),
            //       const Divider(
            //         color: Colors.grey,
            //         thickness: 1,
            //         indent: 5,
            //         endIndent: 5,
            //       ),
            //       AutonomousModeSelector(),
            //     ]),
            //   ),
            // ),
            const PathPoint(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                transform: Matrix4.translationValues(0, -60.0, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey),
                ),
                child: VideoSourceSelect(),
              ),
            ),
            Transform.translate(
              offset: Offset(displayWidth(context) / 9, -40),
              child: Align(
                alignment: Alignment.bottomLeft,
                // centerPoint:
                //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
                child: rudderControlWidget,
              ),
            ),
            Transform.translate(
              offset: Offset(-displayWidth(context) / 9, -40),
              child: Align(
                alignment: Alignment.bottomRight,
                // centerPoint:
                //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
                child: trimTabControlWidget,
              ),
            ),
            Transform.translate(
                offset: Offset(displayWidth(context) / 2 - 180,
                    displayHeight(context) - 240),
                child: SizedBox(
                  height: 70,
                  width: 90,
                  child: FloatingActionButton(
                      onPressed: () {
                        _networkComms?.requestTack();
                      },
                      child: const Text("Tack")),
                  // const SizedBox(
                  //     height: 40, width: 250, child: BallastSlider())
                )),
            PathButtons(),
          ])),
    );
  }

  _updateTrimtabAngle(double angle) {
    _trimTabControlWidget.setAngle(angle);
    _networkComms?.setTrimtabAngle(angle);
    ref.read(inputControllerProvider).trimtabAngle = angle;
  }

  _updateRudderAngle(double angle) {
    _rudderControlWidget.setAngle(angle);
    _networkComms?.setRudderAngle(angle);
    ref.read(inputControllerProvider).rudderAngle = angle;
  }
}

class CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).primaryColor,
      child: child,
    );
  }
}

// ┌─────────────────────────────────────────────────────────────────────────┐
// │                        Flutter Telemetry Application                    │
// │  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────────────┐ │
// │  │   Gamepad UI    │  │   Map Interface  │  │   Control Widgets       │ │
// │  │                 │  │                  │  │                         │ │
// │  └─────────────────┘  └──────────────────┘  └─────────────────────────┘ │
// │                                │                                        │
// │                         ┌──────▼──────┐                                 │
// │                         │ gRPC Client │                                 │
// │                         └──────┬──────┘                                 │
// └────────────────────────────────┼────────────────────────────────────────┘
//                                  │ gRPC Protocol (Port 50051)
//                                  ▼
// ┌─────────────────────────────────────────────────────────────────────────┐
// │                           ROS2 Boat System                              │
// │  ┌────────────────────────────────────────────────────────────────────┐ │
// │  │                    NetworkComms Node                               │ │
// │  │  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐  │ │
// │  │  │   gRPC Server   │  │  Topic Bridge    │  │  State Manager    │  │ │
// │  │  │                 │  │                  │  │                   │  │ │
// │  │  └─────────────────┘  └──────────────────┘  └───────────────────┘  │ │
// │  └─────────────────────────────────────────────────────────────────────┘│
// │                                │                                        │
// │                         ROS2 Topics & Services                          │
// │                                │                                        │
// │  ┌──────────────┬──────────────┼──────────────┬─────────────────────────┤
// │  │              │              │              │                         │
// │  ▼              ▼              ▼              ▼                         │
// │┌─────────────┐┌──────────────┐┌─────────────┐┌───────────────────────┐  │
// ││Path         ││Control       ││Sensor       ││Hardware Controllers   │  │
// ││Generation   ││System        ││Processing   ││                       │  │
// ││             ││              ││             ││ • PWM Controller      │  │
// ││• path_gen   ││• path_fol_vf ││• airmar     ││ • Trim Tab Comms      │  │
// ││• waypoints  ││• station_keep││• wind_calc  ││ • Camera System       │  │
// │└─────────────┘└──────────────┘└─────────────┘└───────────────────────┘  │
// └─────────────────────────────────────────────────────────────────────────┘