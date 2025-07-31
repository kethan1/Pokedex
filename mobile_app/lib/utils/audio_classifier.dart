import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'classification_probabilities.dart';
import 'mel_spectogram_extractor.dart';

class AudioClassifier {
  late Future<void> _initializeFuture;
  late String _modelPath;
  late Future<Interpreter> _interpreter;

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

  // Spectrogram / preprocessing params (tunable to match training)
  final int sampleRate = 16000; // expected sampling rate
  final int nFft = 1024;
  final int hopLength = 512;
  final int nMels = 64;
  final double fMin = 0;
  late double fMax;

  AudioClassifier(String modelPath) {
    _modelPath = modelPath;
    fMax = sampleRate / 2;
    _interpreter = Interpreter.fromAsset(modelPath);
  }

  /// Loads the audio file, ensures correct sample rate (caller should provide 16k or resample),
  /// computes log-mel spectrogram, and returns a tensor shaped [1, 1, nMels, timeFrames].
  Future<List<List<List<List<double>>>>> _preprocessAudio(XFile audioFile) async {
    final extractor = MelSpectrogramExtractor(
      sampleRate: 16000,
      nFft: 1024,
      hopLength: 512,
      nMels: 64,
      fMin: 0,
    );

    final waveform = await extractor.loadWavAsFloat32(audioFile.path);
    final List<List<double>> logMel = extractor.extract(waveform);

    final int timeFrames = logMel[0].length;

    // [1, 1, nMels, timeFrames]
    final List<List<List<List<double>>>> specData = List.generate(
      1,
      (_) => List.generate(
        1,
        (_) => List.generate(
          extractor.nMels,
          (_) => List.filled(timeFrames, 0.0),
        ),
      ),
    );

    for (int m = 0; m < extractor.nMels; m++) {
      for (int t = 0; t < timeFrames; t++) {
        specData[0][0][m][t] = logMel[m][t].toDouble();
      }
    }

    if (timeFrames < 200) {
      // Pad with zeros if too short
      final int padding = 200 - timeFrames;
      for (int m = 0; m < extractor.nMels; m++) {
        specData[0][0][m].addAll(List.filled(padding, 0.0));
      }
    } else if (timeFrames > 200) {
      for (int m = 0; m < extractor.nMels; m++) {
        specData[0][0][m] = specData[0][0][m].sublist(0, 200);
      }
    }

    return specData;
  }

  Future<ClassificationProbabilities> classifyAudio(XFile audio) async {
    return await classifyTensor(await _preprocessAudio(audio));
  }

  Future<ClassificationProbabilities> classifyTensor(
    List<List<List<List<double>>>> inputTensor,
  ) async {
    await _initializeFuture;

    List<double> scores = List<double>.from(List.filled(1*8, 0).reshape([1,8]));

    (await _interpreter).run(inputTensor, scores);

    List<double> probabilities = _softmax(scores);

    print('Probabilities: $probabilities');

    return ClassificationProbabilities(
      Map.fromIterables(_labels, probabilities),
    );
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((l) => exp(l - maxLogit)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  void close() async {
    (await _interpreter).close();
  }
}
