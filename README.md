# sailbot_telemetry_flutter

Telemetry application for WPI's Sailbot. Written in Dart using Flutter.

Requires access to Sailbot's ZeroTier network.

Setup: 

1. Install flutter+Dart https://docs.flutter.dev/get-started/install

2. (recommended) Install VS code & flutter extension

3. Clone this repo & run "git submodule init" and "git submodule update" in the project folder (may need to be run in git bash, submodules are bugged on windows with SSH keys)

4. Clone the modified gamepads library (necessary for bugfix, check if gamepads has fixed this issue https://github.com/flame-engine/gamepads/issues/3) into the parent directory (the one you cloned this repo into)

5. run "flutter pub get" in the project folder

The app will pull servers from servers.json in here: https://github.com/wpisailbot/sailbot_servers. You can select which server (sailbot controller) to connect to from in the app.

Communication with Sailbot happens over gRPC (see lib/utils/network_comms.dart), using message formats defined here: https://github.com/wpisailbot/telemetry_messages

To fix issues with gradle being outdated, change the version of gradle-wrapper.properties and settings.gradle