
import 'dart:async';
import 'package:gamepads/gamepads.dart';
import 'package:sailbot_telemetry_flutter/utils/gamepad_normalizer.dart';


class ModeEdge {
  bool isPressed = false;
  DateTime lastFire = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration cooldown = const Duration(milliseconds: 200);
  final double pressHigh;   // e.g. 0.6
  final double releaseLow;  // e.g. 0.4

  ModeEdge({this.pressHigh = 0.6, this.releaseLow = 0.4});

  // Call this for each analog event from your "button 4" axis
  // raw can be int (-32768..32767) or double (-1..1 or 0..1)
  bool update(num raw) {
    final v = raw;      // -> [0..1] makes thresholds easy
    final now = DateTime.now();

    // Rising edge: not pressed -> pressed
    if (!isPressed && v >= pressHigh) {
      // Debounce
      if (now.difference(lastFire) >= cooldown) {
        isPressed = true;
        lastFire = now;
        return true; // FIRE: one press detected
      }
    }

    // Falling edge: pressed -> released
    if (isPressed && v <= releaseLow) {
      isPressed = false;
    }
    return false; // no new press
  }
}

enum InputAction {
  none,
  rudderLeft,
  rudderRight,
  trimtabLeft,
  trimtabRight,
  centerRudder,
  centerTrim,
  leftJoyStick,
  rightJoyStick
}
InputAction currentAction = InputAction.none;
class InputController {
  // Pressed states
  // bool rudderLeft = false;
  // bool rudderRight = false;
  // bool trimtabLeft = false;
  // bool trimtabRight = false;
  // bool centerRudder = false;
  // bool centerTrim = false;
  int mode = 1;
  final modeEdge = ModeEdge(pressHigh: 0.6, releaseLow: 0.4);
  bool lockRudder = false;
  bool lockTrim   = false;
  bool rudderNotLockedYet = true;
  bool trimNotLockedYet = true;

  final List<double> _rudderHistory = [];
  final List<double> _trimHistory = [];
  static const int _historySize = 5; // Number of samples to average


  StreamSubscription? _sub;
  Timer? _tick;
  double rudderAngle = 0.0;
  double trimtabAngle = 0.0;
  double rudderAngle_t = 0.0;
  double trimtabAngle_t = 0.0;

  // External callbacks (inject your NetworkComms)
  void Function(double)? onRudder;
  void Function(double)? onTrimtab;
  void Function()? onTack;
  void Function(String)? onAutoMode;

  double rudderStep = 0.08;
  double trimStep = 0.08;

  void setRudderStep(double newStep) {
    rudderStep = newStep;
  }
  
  void setTrimStep(double newStep) {
    trimStep = newStep;
  }

  // Call once (e.g., in main widget init or provider init)
  void start() {
    // 1) Listen to events -> update pressed/axis states
    _sub = Gamepads.events.listen((event) {
      final rawKey = event.key;
      final rawVal = event.value; // 0/1 for buttons, or analog for axes

      final canon = normalizeButton(
        rawKey: rawKey,
        rawValue: rawVal,
        type: event.type
      );
      // print('rawval: $rawVal');

      if (canon == null) return;
      // print(canon.key);

      // SAFETY: Only act on buttons you care about.
      // Map your button numbers clearly (example mapping):
      // '6' = rudderRight, '7' = rudderLeft
      // '1' = trimtabRight, '3' = trimtabLeft
      // '10' = center rudder, '2' = center trim
      // '2' = left joystick (rudder) '8' = right joystick (trimtab)
      // 4 = mode cycle
      // 5 = tack

      if (canon.key == '7') {
        currentAction = canon.pressed ? InputAction.rudderLeft : InputAction.none;
      }
      if (canon.key == '6') {
        currentAction = canon.pressed ? InputAction.rudderRight : InputAction.none;
      }
      if (canon.key == '1' ) {
        currentAction = canon.pressed ? InputAction.trimtabRight : InputAction.none;
      }
      if (canon.key == '3' ) {
          currentAction = canon.pressed ? InputAction.trimtabLeft : InputAction.none;
      }

      if (canon.key == '2') {
          if (canon.pressed) {
          currentAction = InputAction.leftJoyStick;
          rudderAngle_t = canon.value * 1.5;
          
        } else {
          currentAction = InputAction.centerRudder;
          rudderAngle_t = 0;
        }
        // print(canon.value);
        // print(canon.pressed);

      }
      if (canon.key == '8') {
        if (canon.pressed) {
          currentAction = InputAction.rightJoyStick;
          trimtabAngle_t = canon.value * 1.5;
        } else {
          currentAction = InputAction.centerTrim;
          trimtabAngle_t = 0;
        }
      }

      if (canon.key == '10') {
        currentAction = canon.pressed ? InputAction.centerRudder : InputAction.none;
      }
      if (canon.key == '11') {
        currentAction = canon.pressed ? InputAction.centerTrim : InputAction.none;
      }


      if(canon.key == '5'){
        if (modeEdge.update(canon.value)) {   // true only on rising edge (debounced)
          // print("TACK!");
          onTack?.call();
          // centerRudder = true;
          // centerTrim = true;  
          currentAction = InputAction.centerTrim; // auto center trimtab on tack
          currentAction = InputAction.centerRudder;  // auto center rudder on tack
        }

         }

      if (canon.key == '4') {                  
        if (modeEdge.update(canon.value)) {   // true only on rising edge (debounced)
          mode += 1;
          if (mode > 4) mode = 1;
          if (mode == 1) onAutoMode?.call('NONE');
          if (mode == 2) onAutoMode?.call('BALLAST');
          if (mode == 3) onAutoMode?.call('TRIMTAB');
          if (mode == 4) onAutoMode?.call('FULL');
          // applyMode(mode == 1 ? 'NONE' : mode == 2 ? 'BALLAST' : mode == 3 ? 'TRIMTAB' : 'FULL'); 
        }
      }


    });

    const dt = Duration(milliseconds: 33); // ~30 FPS 
    _tick = Timer.periodic(dt, (_) {
      const minAngle = -1.5;
      const maxAngle =  1.5;

      // === Rudder ===
      if (lockRudder) {
        // Center once and only send if changed (avoid spamming)
        if (rudderAngle != 0.0 && rudderNotLockedYet) {
          rudderAngle = 0.0;
          onRudder?.call(rudderAngle);
          rudderNotLockedYet = false;
        }
      } else {
        // apply manual increments from pressed flags
        switch (currentAction) {
          case InputAction.centerRudder:
            rudderAngle = 0.0;
            onRudder?.call(rudderAngle);
            break;
          case InputAction.rudderLeft:
            rudderAngle -= (rudderStep);
            rudderAngle = rudderAngle.clamp(minAngle, maxAngle);
            onRudder?.call(rudderAngle);
            break;
          case InputAction.rudderRight:
            rudderAngle += (rudderStep);
            rudderAngle = rudderAngle.clamp(minAngle, maxAngle);
            onRudder?.call(rudderAngle);
            break;
          case InputAction.leftJoyStick:
            rudderAngle = _smoothValue(_rudderHistory, rudderAngle_t); // Smooth the value
            print("targetRudder: $rudderAngle_t");
            print("rudderAngle: $rudderAngle");
            onRudder?.call(rudderAngle);
            break;
          default:
            break;
        }
        rudderNotLockedYet = true;
      }

      // === Trimtab ===
      if (lockTrim) {
        if (trimtabAngle != 0.0 && trimNotLockedYet) {
          trimtabAngle = 0.0;
          onTrimtab?.call(trimtabAngle);
          trimNotLockedYet = false;
        }
      } else {
        switch (currentAction) {
          case InputAction.centerTrim:
            trimtabAngle = 0.0;
            onTrimtab?.call(trimtabAngle);
            break;
          case InputAction.trimtabLeft:
            trimtabAngle += (trimStep);
            trimtabAngle = trimtabAngle.clamp(minAngle, maxAngle);
            onTrimtab?.call(trimtabAngle);
            break;
          case InputAction.trimtabRight:
            trimtabAngle -= (trimStep);
            trimtabAngle = trimtabAngle.clamp(minAngle, maxAngle);
            onTrimtab?.call(trimtabAngle);
            break;
          case InputAction.rightJoyStick:
            trimtabAngle = _smoothValue(_trimHistory, trimtabAngle_t); // Smooth the value
            
            onTrimtab?.call(trimtabAngle);
            break;
          default:
            break;
        }
        trimNotLockedYet = true;
      }
      // print("Rudder: $rudderAngle Trimtab: $trimtabAngle");
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
  }

  double _smoothValue(List<double> history, double newValue) {
    history.add(newValue);
    if (history.length > _historySize) {
      history.removeAt(0); // Remove oldest value
    }
    
    // Return average of recent values
    return history.reduce((a, b) => a + b) / history.length;
  }

  // Call this when mode or tack changes:
  void applyMode(String mode) {
    if (mode == 'NONE') {
      lockRudder = false;
      lockTrim   = false;
    } else if (mode == 'BALLAST') {
      lockRudder = false;
      lockTrim   = false;
    } else if (mode == 'TRIMTAB') {
      lockRudder = false; // manual rudder OK
      lockTrim   = true;  // auto controls trim
    } else if (mode == 'FULL') {
      lockRudder = true;
      lockTrim   = true;
    }

    // Optional: immediately center when entering locks
    if (lockRudder) { rudderAngle = 0.0; onRudder?.call(0.0); }
    if (lockTrim)   { trimtabAngle = 0.0; onTrimtab?.call(0.0); }
    print("Mode $mode: lockRudder=$lockRudder lockTrim=$lockTrim"); 
  }

  // If you press "Tack", you may want to lock both during the maneuver
  void beginTack() {
    lockRudder = true;
    lockTrim   = true;
    rudderAngle = 0.0;
    // trimtabAngle = 0.0;
    onRudder?.call(0.0);
    // onTrimtab?.call(0.0);
    onTack?.call();
  }

  // Call this when robot reports tack finished (via NetworkComms callback)
  void endTack(String currentMode) {
    applyMode(currentMode); // restore locks based on current mode
  }

}
// ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
// │   Gamepad/User  │    │  Android/Linux  │    │     Flutter     │
// │     Input       │───▶│   Event Layer   │───▶│   Application   │
// └─────────────────┘    └─────────────────┘    └─────────────────┘
//                                                        │
//                        ┌─────────────────┐    ┌─────────────────┐
//                        │   Riverpod      │    │   Gamepad       │
//                        │   Providers     │◀───│   Normalizer    │
//                        └─────────────────┘    └─────────────────┘
//                                │
//                        ┌─────────────────┐    ┌─────────────────┐
//                        │  UI Widgets     │    │   NetworkComms  │
//                        │  (setAngle)     │    │   gRPC Client   │
//                        └─────────────────┘    └─────────────────┘
//                                                        │
//                                                ┌─────────────────┐
//                                                │     Network     │
//                                                │   (gRPC/Proto)  │
//                                                └─────────────────┘
//                                                        │
// ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
// │     Physical    │    │     ESP32       │    │  ROS2 Network   │
// │    Actuators    │◀───│   Controllers   │◀───│     Comms       │
// │ (Rudder/Trim)   │    │  (Websockets)   │    │      Node       │
// └─────────────────┘    └─────────────────┘    └─────────────────┘
//                                                        │
//                        ┌─────────────────┐    ┌─────────────────┐
//                        │    Ballast      │    │   Heading/Path  │
//                        │    Control      │◀───│   Controllers   │
//                        └─────────────────┘    └─────────────────┘