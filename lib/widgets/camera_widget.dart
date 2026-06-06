import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data'; // For Uint8List
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pb.dart';
import 'dart:async';

final imageProvider = StateNotifierProvider<ImageNotifier, ImageState>((ref) {
  return ImageNotifier();
});

class ImageState {
  final MemoryImage? image;
  final bool isLoaded;

  ImageState({this.image, this.isLoaded = false});

  ImageState copyWith({MemoryImage? image, bool? isLoaded}) {
    return ImageState(
      image: image ?? this.image,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class ImageNotifier extends StateNotifier<ImageState> {
  ImageNotifier() : super(ImageState());

  Future<void> updateImage(Uint8List imageData) async {
    final newImageProvider = MemoryImage(imageData);
    final ImageStream imageStream =
        newImageProvider.resolve(ImageConfiguration.empty);
    final completer = Completer<void>();

    // ImageStreamListener to listen for image load completion
    imageStream.addListener(ImageStreamListener((ImageInfo info, bool synchronousCall) {
      state = state.copyWith(image: newImageProvider, isLoaded: true);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      state = state.copyWith(isLoaded: false);
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    }));

    return completer.future;
  }
}

class CameraView extends ConsumerWidget {
  const CameraView({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<VideoFrame?>(videoFrameProvider, (_, videoFrame) {
      if(videoFrame != null){
        ref.read(imageProvider.notifier).updateImage(Uint8List.fromList(videoFrame.data));
      }
    });
    final imageState = ref.watch(imageProvider);

    if (imageState.isLoaded && imageState.image != null) {
      return SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Image(
        image: imageState.image!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text('Failed to load image')),
      ));
    } else {
      return const Center(child: Text('Loading image...'));
    }
  }
}