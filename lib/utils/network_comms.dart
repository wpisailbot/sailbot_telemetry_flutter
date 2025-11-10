import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbserver.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/node_restart.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/widgets/video_source_select.dart';
import 'dart:developer' as dev; //log() conflicts with math

import 'package:sailbot_telemetry_flutter/utils/github_helper.dart' as gh;

final boatStateProvider =
    StateNotifierProvider<BoatStateNotifier, BoatState>((ref) {
  return BoatStateNotifier();
});

final mapImageProvider =
    StateNotifierProvider<MapImageNotifier, MapResponse?>((ref) {
  return MapImageNotifier();
});

final videoFrameProvider =
    StateNotifierProvider<VideoFrameNotifier, VideoFrame?>((ref) {
  return VideoFrameNotifier();
});

final cvParametersProvider =
    StateNotifierProvider<CVParametersNotifier, CVParameters?>((ref) {
  return CVParametersNotifier();
});

class BoatStateNotifier extends StateNotifier<BoatState> {
  BoatStateNotifier() : super(BoatState());

  void update(BoatState newState) {
    state = newState;
  }
}

final videoSourceListProvider = StateNotifierProvider<VideoSourceListNotifier, List<String>>((ref) {
  final boatState = ref.watch(boatStateProvider);
  return VideoSourceListNotifier(boatState.availableVideoSources);
});

class VideoSourceListNotifier extends StateNotifier<List<String>> {
  VideoSourceListNotifier(List<String> initialVideoSources) : super(initialVideoSources);

  void update(List<String> newVideoSources) {
    if (!listEquals(state, newVideoSources)) {
      state = newVideoSources;
    }
  }
}

bool listEquals<T>(List<T>? list1, List<T>? list2) {
  if (list1 == null && list2 == null) return true;
  if (list1 == null || list2 == null) return false;
  if (list1.length != list2.length) return false;
  for (int i = 0; i < list1.length; i++) {
    if (list1[i] != list2[i]) return false;
  }
  return true;
}

class MapImageNotifier extends StateNotifier<MapResponse?> {
  MapImageNotifier() : super(null);

  void update(MapResponse newImage) {
    state = newImage;
  }
}

class VideoFrameNotifier extends StateNotifier<VideoFrame?> {
  VideoFrameNotifier() : super(null); // Start with no initial frame

  void update(VideoFrame newFrame) {
    state = newFrame; // Update the state when a new frame is received
  }
}

class CVParametersNotifier extends StateNotifier<CVParameters?> {
  CVParametersNotifier() : super(null); // Start with no initial parameters

  void update(CVParameters newParameters) {
    state = newParameters;
  }
}

final selectedServerProvider = StateProvider<gh.Server?>((ref) => null);

final networkCommsProvider =
    StateNotifierProvider<NetworkCommsNotifier, NetworkComms?>((ref) {
  final selectedServer = ref.watch(selectedServerProvider);
  final notifier = NetworkCommsNotifier(ref, selectedServer);
  if (selectedServer != null) {
    notifier.changeServer(selectedServer);
  }
  return notifier;
});

class NetworkCommsNotifier extends StateNotifier<NetworkComms?> {
  NetworkCommsNotifier(this.ref, this.selectedServer) : super(null);
  final StateNotifierProviderRef ref;
  final gh.Server? selectedServer;
  void changeServer(gh.Server selectedServer) {
    state?.dispose(); // Dispose the old instance
    state = NetworkComms(selectedServer.address, ref); // Create a new instance
    String source = ref.read(videoSourceProvider.notifier).state;
    state?.setCameraSource(source);
    dev.log(
        'NetworkComms instance changed to new server: ${selectedServer.address}');
  }

  @override
  void dispose() {
    dev.log("Disposing NetworkComms");
    state
        ?.dispose(); // Ensure resources are cleaned up when notifier is disposed
    super.dispose();
  }
}

class NetworkComms {
  String? server;
  SetParameterServiceClient? _setParameterServiceClient;
  ControlCommandServiceClient? _controlCommandServiceClient;
  SendBoatStateServiceClient? _sendBoatStateStub;
  StreamBoatStateServiceClient? _streamBoatStateStub;
  GetMapServiceClient? _getMapStub;
  GetCVParametersServiceClient? _getCVParametersServiceClient;
  RestartNodeServiceClient? _restartNodeStub;
  VideoStreamerClient? _videoStreamerStub;
  StreamSubscription<VideoFrame>? _streamSubscription;
  String _currentCameraSource = 'COLOR';

  StreamSubscription<BoatState>? _boatStateSubscription;

  Timer? _timer;

  ClientChannel? channel;

  final StateNotifierProviderRef ref;

  NetworkComms(this.server, this.ref) {
    _createClient();
    //dev.log('created client to boat');
  }

  void reconnect(String server) {
    this.server = server;
    _createClient();
  }

  void _initializeBoatStateStream() {
    try {
      final call = _streamBoatStateStub!.streamBoatState(BoatStateRequest());
      _boatStateSubscription = call.listen((BoatState response) {
        ref.read(boatStateProvider.notifier).update(response);
      }, onError: (e) {
        dev.log("Error: $e", name: "network");
        // Do not attempt to reconnect both here and in onDone, it creates exponential callbacks
      }, onDone: () {
        // Stream closed, possibly due to server shutdown or network issue
        dev.log("Stream closed", name: "network");
      });
    } catch (e) {
      dev.log("Failed to start stream: $e");
    }
  }

  Timer? _retryTimer;
  void _getInitialCVParameters(){
    GetCVParametersRequest cvRequest = GetCVParametersRequest();
      _getCVParametersServiceClient?.getCVParameters(cvRequest).then(
        (response) {
          dev.log("got cv response: ${response}");
          if(response.hasParameters()){
            ref.read(cvParametersProvider.notifier).update(response.parameters);
          } else {
            _retryTimer = Timer(const Duration(seconds: 1), () {
              _getInitialCVParameters();
              _retryTimer?.cancel();
            });
          }
        },
      );
  }

  Future<void> _createClient() async {
    _timer?.cancel();
    //dev.log("about to create channel", name: 'network');
    if (server == null) {
      dev.log("Something went wrong, server address is null", name: 'network');
      return;
    }
    if (server == '') {
      return;
    }
    try {
      channel = ClientChannel(
        server ?? "?",
        port: 50051,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
          keepAlive: ClientKeepAliveOptions(
              pingInterval: Duration(seconds: 1),
              timeout: Duration(seconds: 2)),
        ),
      );
      channel?.onConnectionStateChanged.listen((connectionState) {
        switch (connectionState) {
          case ConnectionState.idle:
            dev.log("Connection is idle.", name: 'network');
            break;
          case ConnectionState.connecting:
            //dev.log("Connecting to server...", name: 'network');
            break;
          case ConnectionState.ready:
            dev.log("Connected to server.", name: 'network');
            MapRequest request = MapRequest();
            // Get current navigation map
            _getMapStub?.getMap(request).then((response) {
              dev.log(
                  "got map response: ${response.north}, ${response.south}, ${response.east}, ${response.west}");
              if (response.north != 0 && response.south != 0) {
                ref.read(mapImageProvider.notifier).update(response);
              }
            });
            // Get current CV parameters
            _getInitialCVParameters();

            _initializeBoatStateStream();
            break;
          case ConnectionState.transientFailure:
            dev.log("Connection lost, transient failure", name: 'network');
            break;
          case ConnectionState.shutdown:
            //dev.log("Connection is shutting down or shut down.", name: 'network');
            break;
        }
      }, onError: (error) {
        dev.log('onError');
      });
    } catch (e) {
      dev.log("Could not create channel");
      return;
    }
    //dev.log("created channel", name: 'network');
    _controlCommandServiceClient = ControlCommandServiceClient(channel!);
    _setParameterServiceClient = SetParameterServiceClient(channel!);
    _sendBoatStateStub = SendBoatStateServiceClient(channel!);
    _streamBoatStateStub = StreamBoatStateServiceClient(channel!);
    _getMapStub = GetMapServiceClient(channel!);
    _getCVParametersServiceClient = GetCVParametersServiceClient(channel!);
    _restartNodeStub = RestartNodeServiceClient(channel!);
    _videoStreamerStub = VideoStreamerClient(channel!);

    //dummy call to force gRPC to open the connection immediately
    _sendBoatStateStub?.sendBoatState(BoatStateRequest()).then((boatState) {});
  }

  terminate() {
    channel?.terminate();
  }

  void dispose() {
    _streamSubscription?.cancel(); // Cancel any active subscriptions
    _boatStateSubscription?.cancel();
    channel?.shutdown(); // Gracefully shutdown the gRPC channel
    dev.log('NetworkComms resources have been disposed.');
  }

  startVideoStreaming() {
    VideoRequest req = VideoRequest();
    req.videoSource = _currentCameraSource;
    final call = _videoStreamerStub!.streamVideo(req);
    _streamSubscription = call.listen((VideoFrame response) {
      ref.read(videoFrameProvider.notifier).update(response);
    }, onError: (e) {
      dev.log("Error: $e", name: "network");
    }, onDone: () {
      // Stream closed, possibly due to server shutdown or network issue
      dev.log("Video stream closed", name: "network");
    });
  }

  void cancelVideoStreaming() {
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
      dev.log("Video stream canceled", name: "network");
    }
  }

  setCameraSource(String source) {
    cancelVideoStreaming();
    _currentCameraSource = source;
    startVideoStreaming();
  }

  restartNode(String node) {
    RestartNodeRequest request = RestartNodeRequest();
    request.nodeName = node;
    _restartNodeStub?.restartNode(request).then((response) {
      dev.log("Restart node: ${response.success ? "success" : "fail"}",
          name: "network");
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setRudderAngle(double angle) {
    RudderCommand command = RudderCommand();
    command.rudderControlValue = angle;
    dev.log("sending rudder command", name: "network");
    // print(command);
    _controlCommandServiceClient?.executeRudderCommand(command).then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Rudder control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setTrimtabAngle(double angle) {
    TrimTabCommand command = TrimTabCommand();
    command.trimtabControlValue = angle;
    // print(command);
    _controlCommandServiceClient?.executeTrimTabCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Trimtab control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setBallastPosition(
      double
          position /* positions from -1.0 (full left) to 1.0 (full right) */) {
    BallastCommand command = BallastCommand();
    command.ballastControlValue = position;
    _controlCommandServiceClient?.executeBallastCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Ballast control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setWaypoints(
    WaypointPath newWaypoints,
  ) {
    SetWaypointsCommand command = SetWaypointsCommand();
    command.newWaypoints = newWaypoints;
    _controlCommandServiceClient?.executeSetWaypointsCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log(
          "Override waypoints control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  addWaypoint(
    Waypoint newWaypoint,
  ) {
    AddWaypointCommand command = AddWaypointCommand();
    command.newWaypoint = newWaypoint;
    _controlCommandServiceClient?.executeAddWaypointCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Add waypoint control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setAutonomousMode(AutonomousMode mode) {
    AutonomousModeCommand command = AutonomousModeCommand();
    command.autonomousMode = mode;
    // print(command);
    _controlCommandServiceClient
        ?.executeAutonomousModeCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Autonomous mode control command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setVFForwardMagnitude(double magnitude) {
    SetVFForwardMagnitudeCommand command = SetVFForwardMagnitudeCommand();
    command.magnitude = magnitude;
    _setParameterServiceClient
        ?.executeSetVFForwardMagnitudeCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log(
          "Set VF forward magnitude command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setRudderAdjustmentScale(double scale) {
    SetRudderAdjustmentScaleCommand command = SetRudderAdjustmentScaleCommand();
    command.scale = scale;
    _setParameterServiceClient?.executeSetRudderAdjustmentScaleCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Set rudder KP command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setRudderOvershootBias(double bias) {
    SetRudderOvershootBiasCommand command = SetRudderOvershootBiasCommand();
    command.bias = bias;
    _setParameterServiceClient?.executeSetRudderOvershootBiasCommand(command).then(
        (response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Set rudder KD command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log('onError');
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  setCVParameters(CVParameters parameters) {
    SetCVParametersCommand command =
        SetCVParametersCommand(parameters: parameters);
    _setParameterServiceClient
        ?.executeSetCVParametersCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Set CV Parameters command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log(error);
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }

  requestTack() {
    RequestTackCommand command = RequestTackCommand();
    _controlCommandServiceClient?.executeRequestTackCommand(command).then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Request tack command returned with response: $status",
          name: 'network');
    }, onError: (error) {
      dev.log(error);
    }).catchError((error) {
      dev.log('caught error: ${error.toString()}');
    });
  }
}
