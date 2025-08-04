import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:image/image.dart' as img;
import 'package:cross_file/cross_file.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:result_dart/result_dart.dart';

import '../../core/constants.dart' as constants;
import '../../interfaces/classifier.dart';
import '../../models/classification_probabilities.dart';
import '../../utils/utils.dart';

class ImageClassifier implements Classifier<XFile> {
  late Future<void> _initializeFuture;
  late String _modelPath;
  late OrtSession _session;

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

  Future<Result<OrtValue>> _preprocessImage(XFile imageFile) async {
    final Uint8List bytes = await File(imageFile.path).readAsBytes();
    final img.Image? rawImage = img.decodeImage(bytes);

    if (rawImage == null) {
      throw Failure(Exception('Could not decode image bytes'));
    }

    final img.Image resized = img.copyResize(
      rawImage,
      width: constants.imageWidth,
      height: constants.imageHeight,
    );

    final Float32List imgData = Float32List(
      1 * 3 * constants.imageHeight * constants.imageWidth,
    );

    const List<double> mean = [0.4960, 0.4695, 0.4262];
    const List<double> std = [0.2158, 0.2027, 0.1885];

    int pixelIndex = 0;
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < constants.imageHeight; y++) {
        for (int x = 0; x < constants.imageWidth; x++) {
          final pixel = resized.getPixel(x, y);

          if (c == 0) {
            imgData[pixelIndex++] = (pixel.r / 255.0 - mean[0]) / std[0];
          } else if (c == 1) {
            imgData[pixelIndex++] = (pixel.g / 255.0 - mean[1]) / std[1];
          } else {
            imgData[pixelIndex++] = (pixel.b / 255.0 - mean[2]) / std[2];
          }
        }
      }
    }

    OrtValue inputTensor = await OrtValue.fromList(
      imgData,
      // batch, channels, height, width
      [1, 3, constants.imageHeight, constants.imageWidth],
    );

    return Success(inputTensor);
  }

  @override
  Future<Result<ClassificationProbabilities>> classify(XFile image) async {
    Result<OrtValue> input = await _preprocessImage(image);

    if (input.isError()) {
      return Failure(input.exceptionOrNull()!);
    }

    return await _classifyTensor(input.getOrNull()!);
  }

  // Input: OrtValue with shape [1, 3, constants.imageHeight, constants.imageWidth]
  Future<Result<ClassificationProbabilities>> _classifyTensor(
    OrtValue inputTensor,
  ) async {
    if (!listEquals(inputTensor.shape, [
      1,
      3,
      constants.imageHeight,
      constants.imageWidth,
    ])) {
      return Failure(
        Exception(
          'Input tensor must have shape [1, 3, ${constants.imageHeight}, ${constants.imageWidth}]. Received ${inputTensor.shape}',
        ),
      );
    }

    await _initializeFuture;

    final String inputName = _session.inputNames.first;
    final String outputName = _session.outputNames.first;

    final outputs = await _session.run({inputName: inputTensor});

    final List<double> scores = (await outputs[outputName]!.asFlattenedList())
        .cast<double>();

    List<double> probabilities = softmax(scores);

    return Success(
      ClassificationProbabilities.fromLists(
        constants.classLabels,
        probabilities,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _session.close();
  }
}
