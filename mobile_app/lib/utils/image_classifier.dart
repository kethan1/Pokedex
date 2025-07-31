import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'classification_probabilities.dart';

class ImageClassifier {
  late Future<void> _initializeFuture;
  late String _modelPath;
  late OrtSession _session;

  final List<String> _labels = [
    'bulbosaur',
    'charmander',
    'gengar',
    'magikarp',
    'mew',
    'pikachu',
    'psyduck',
    'squirtle',
  ];

  ImageClassifier(String modelPath) {
    _modelPath = modelPath;
    _initializeFuture = initialize();
  }

  Future<void> initialize() async {
    List<OrtProvider> availableProviders = await OnnxRuntime()
        .getAvailableProviders();

    OrtProvider provider = availableProviders.isNotEmpty
        ? availableProviders.first
        : OrtProvider.CPU;

    final sessionOptions = OrtSessionOptions(providers: [provider]);

    _session = await OnnxRuntime().createSessionFromAsset(
      _modelPath,
      options: sessionOptions,
    );
  }

  /// Reads [imageFile], resizes to 200×200, normalizes, and returns a List shaped [3,200,200] (CHW).
  Future<OrtValue> _preprocessImage(XFile imageFile) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory.path}/image.jpg');
    await file.writeAsBytes(await imageFile.readAsBytes());

    final bytes = await imageFile.readAsBytes();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) {
      throw Exception('Could not decode image bytes');
    }

    final resized = img.copyResize(rawImage, width: 200, height: 200);

    final Float32List imgData = Float32List(1 * 3 * 200 * 200);

    const List<double> mean = [0.4960, 0.4695, 0.4262];
    const List<double> std = [0.2158, 0.2027, 0.1885];

    int pixelIndex = 0;
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        final pixel = resized.getPixel(x, y);

        // imgData[pixelIndex++] = ((pixel.r / 255.0) - mean[0]) / std[0];
        // imgData[pixelIndex++] = ((pixel.g / 255.0) - mean[1]) / std[1];
        // imgData[pixelIndex++] = ((pixel.b / 255.0) - mean[2]) / std[2];

        imgData[pixelIndex++] = pixel.r / 255.0;
        imgData[pixelIndex++] = pixel.g / 255.0;
        imgData[pixelIndex++] = pixel.b / 255.0;
      }
    }

    OrtValue inputTensor = await OrtValue.fromList(
      imgData,
      [1, 3, 200, 200], // Input shape: batch, channels, height, width
    );

    return inputTensor;
  }

  Future<ClassificationProbabilities> classifyImage(XFile image) async {
    return await classifyTensor(await _preprocessImage(image));
  }

  // Input shape: OrtValue with [1, 3, 200, 200]
  // Batch dimension is handled internally
  Future<ClassificationProbabilities> classifyTensor(
    OrtValue inputTensor,
  ) async {
    await _initializeFuture;

    final String inputName = _session.inputNames.first;
    final String outputName = _session.outputNames.first;

    final outputs = await _session.run({inputName: inputTensor});

    final List<double> scores = (await outputs[outputName]!.asFlattenedList())
        .cast<double>();

    List<double> probabilities = _softmax(scores);

    return ClassificationProbabilities(
      Map.fromIterables(_labels, probabilities),
    );
  }

  List<double> _softmax(List<double> logits) {
    double sumExp = logits.map((logit) => exp(logit)).reduce((a, b) => a + b);
    return logits.map((logit) => exp(logit) / sumExp).toList();
  }

  void close() async {
    _session.close();
  }
}
