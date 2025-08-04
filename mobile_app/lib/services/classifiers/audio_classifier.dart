import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:result_dart/result_dart.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../core/constants.dart' as constants;
import '../../interfaces/classifier.dart';
import '../../models/classification_probabilities.dart';
import '../../models/mel_spectrogram.dart';
import '../../utils/mel_spectogram_extractor.dart';

class AudioClassifier implements Classifier<XFile> {
  late Future<void> _initializeFuture;
  late String _modelPath;
  late OrtSession _session;

  final int nFft = 1024;
  final int hopLength = 512;
  final double fMin = 0;
  late double fMax;

  AudioClassifier(String modelPath) {
    _modelPath = modelPath;
    fMax = constants.sampleRate / 2;
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

  Future<Result<OrtValue>> _preprocessAudio(XFile audioFile) async {
    try {
      final extractor = MelSpectrogramExtractor(
        sampleRate: constants.sampleRate,
        nFft: nFft,
        hopLength: hopLength,
        nMels: constants.numMels,
        fMin: fMin,
      );

      final Float32List wav = await extractor.loadWavAsFloat32(audioFile.path);
      final MelSpectrogram mel = extractor.extract(wav);

      if (mel.nMels != constants.numMels) {
        return Failure(
          Exception(
            'Extractor produced ${mel.nMels} Mel bands; '
            'model expects ${constants.numMels}.',
          ),
        );
      }

      // Pad / truncate in the time dimension
      final int srcFrames = mel.nFrames;
      final int dstFrames = constants.timeFrames;

      final Float32List inputData = Float32List(
        1 * 1 * constants.numMels * dstFrames,
      );

      for (int m = 0; m < constants.numMels; ++m) {
        final int srcOffset = m * srcFrames;
        final int dstOffset = m * dstFrames;
        final int copyLen = min(srcFrames, dstFrames);

        inputData.setRange(dstOffset, dstOffset + copyLen, mel.data, srcOffset);
      }

      final OrtValue tensor = await OrtValue.fromList(inputData, [
        1,
        1,
        constants.numMels,
        dstFrames,
      ]);

      return Success(tensor);
    } catch (e) {
      return Failure(Exception('Audio preprocessing failed: $e'));
    }
  }

  @override
  Future<Result<ClassificationProbabilities>> classify(XFile audio) async {
    Result<OrtValue> input = await _preprocessAudio(audio);

    if (input.isError()) {
      return Failure(input.exceptionOrNull()!);
    }

    return await _classifyTensor(input.getOrNull()!);
  }

  Future<Result<ClassificationProbabilities>> _classifyTensor(
    OrtValue inputTensor,
  ) async {
    if (!listEquals(inputTensor.shape, [
      1,
      1,
      constants.numMels,
      constants.timeFrames,
    ])) {
      return Failure(
        Exception(
          'Input tensor must have shape [1, 1, ${constants.numMels}, ${constants.timeFrames}]. Received ${inputTensor.shape}',
        ),
      );
    }

    await _initializeFuture;

    final String inputName = _session.inputNames.first;
    final String outputName = _session.outputNames.first;

    final outputs = await _session.run({inputName: inputTensor});

    final List<double> scores = (await outputs[outputName]!.asFlattenedList())
        .cast<double>();

    List<double> probabilities = _softmax(scores);

    return Success(
      ClassificationProbabilities.fromLists(
        constants.classLabels,
        probabilities,
      ),
    );
  }

  List<double> _softmax(List<double> logits) {
    final double maxLogit = logits.reduce(max);
    final List<double> exps = logits.map((l) => exp(l - maxLogit)).toList();
    final double sumExp = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  @override
  Future<void> close() async {
    await _session.close();
  }
}
