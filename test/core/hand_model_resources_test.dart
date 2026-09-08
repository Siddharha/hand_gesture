import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hand_gesture/core/resources/app_assets.dart';
import 'package:hand_gesture/core/resources/hand_model_resources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both hand models are bundled', () async {
    for (final path in [
      AppAssets.handDetectorModel,
      AppAssets.handLandmarkDetectorModel,
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
    }
  });

  test('specs match the metadata shipped with the models', () async {
    final metadata = jsonDecode(
      await rootBundle.loadString(AppAssets.handModelMetadata),
    ) as Map<String, dynamic>;
    final files = metadata['model_files'] as Map<String, dynamic>;

    void expectSpec(String fileName, spec) {
      final entry = files[fileName] as Map<String, dynamic>;
      final input = (entry['inputs'] as Map<String, dynamic>)['image'] as Map<String, dynamic>;
      expect(spec.inputShape, (input['shape'] as List).cast<int>());

      final outputs = entry['outputs'] as Map<String, dynamic>;
      expect(spec.outputs.keys.toSet(), outputs.keys.toSet());
      for (final name in outputs.keys) {
        expect(
          spec.outputShape(name),
          ((outputs[name] as Map<String, dynamic>)['shape'] as List).cast<int>(),
          reason: '$fileName output "$name" shape drifted from metadata.json',
        );
      }
    }

    expectSpec('hand_detector.tflite', HandModelResources.detector);
    expectSpec('hand_landmark_detector.tflite', HandModelResources.landmarkDetector);
  });
}
