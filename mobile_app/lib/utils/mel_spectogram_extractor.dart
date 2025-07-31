import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart'; // for FFT and windowing

class MelSpectrogramExtractor {
  final int sampleRate;
  final int nFft;
  final int hopLength;
  final int nMels;
  final double fMin;
  final double fMax;
  final double preEmphasis;

  late List<double> _hannWindow;
  late List<List<double>> _melFilterbank; // [nMels][fftBins]

  MelSpectrogramExtractor({
    this.sampleRate = 16000,
    this.nFft = 1024,
    int? hopLength,
    this.nMels = 64,
    this.fMin = 0.0,
    double? fMax,
    this.preEmphasis = 0.97,
  }) : hopLength = hopLength ?? (nFft ~/ 2),
       fMax = fMax ?? (16000 / 2) {
    _hannWindow = _createHannWindow(nFft);
    _melFilterbank = _buildMelFilterbank();
  }

  /// Reads a WAV file (PCM16 little endian, mono) and returns normalized float waveform [-1,1].
  Future<Float32List> loadWavAsFloat32(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    // Minimal WAV parser: assume PCM16, little-endian, mono.
    // WAV header is 44 bytes usually; data chunk starts after header.
    const int headerSize = 44;
    if (bytes.length < headerSize) {
      throw Exception('Invalid WAV file.');
    }

    // Extract sample rate from header to verify (optional).
    final byteData = bytes.buffer.asByteData();
    final int fileSampleRate = byteData.getUint32(24, Endian.little);
    if (fileSampleRate != sampleRate) {
      // Ideally resample here. For brevity, throw if mismatch.
      throw Exception('Expected sample rate $sampleRate but file has $fileSampleRate');
    }

    // Data starts at offset 44; read int16 samples.
    final int numSamples = (bytes.length - headerSize) ~/ 2;
    final Float32List waveform = Float32List(numSamples);
    int offset = headerSize;
    for (int i = 0; i < numSamples; i++, offset += 2) {
      final int16 = byteData.getInt16(offset, Endian.little);
      waveform[i] = int16 / 32768.0; // normalize to [-1,1]
    }
    return waveform;
  }

  /// Applies pre-emphasis: y[t] = x[t] - alpha * x[t-1]
  Float32List _applyPreEmphasis(Float32List signal) {
    final out = Float32List(signal.length);
    out[0] = signal[0];
    for (int i = 1; i < signal.length; i++) {
      out[i] = signal[i] - preEmphasis * signal[i - 1];
    }
    return out;
  }

  /// Main entry: given waveform, returns log-mel spectrogram as [nMels, timeFrames]
  List<List<double>> extract(Float32List waveform) {
    final emphasized = _applyPreEmphasis(waveform);
    final frames = _frameSignal(emphasized);
    final powerSpectrogram = _stftToPowerSpectrogram(frames);
    final melSpec = _applyMelFilterbank(powerSpectrogram);
    final logMel = _logCompress(melSpec);
    return logMel; // shape: [nMels][timeFrames]
  }

  /// Frame signal into overlapping windows with window function applied.
  List<Float32List> _frameSignal(Float32List signal) {
    final int frameStep = hopLength;
    final int frameSize = nFft;
    final int numFrames = ((signal.length - frameSize) / frameStep).floor() + 1;
    List<Float32List> frames = [];
    for (int i = 0; i < numFrames; i++) {
      int start = i * frameStep;
      final frame = Float32List(frameSize);
      for (int j = 0; j < frameSize; j++) {
        frame[j] = signal[start + j] * _hannWindow[j];
      }
      frames.add(frame);
    }
    return frames;
  }

  /// Compute magnitude-squared (power) spectrogram via STFT using FFT.
  List<List<double>> _stftToPowerSpectrogram(List<Float32List> frames) {
    final int fftSize = nFft;
    final int freqBins = fftSize ~/ 2 + 1;
    List<List<double>> spec = List.generate(
        freqBins, (_) => List.filled(frames.length, 0.0),
        growable: false);

    final fft = FFT(fftSize);

    for (int t = 0; t < frames.length; t++) {
      // Zero-pad to nFft already ensured.
      final input = frames[t];
      final complex = fft.realFft(input); // returns ComplexList or format depending on API
      // Extract magnitude squared for first (nFft/2+1) bins.
      for (int k = 0; k < freqBins; k++) {
        final re = complex[k].x;
        final im = complex[k].y;
        final mag2 = re * re + im * im;
        spec[k][t] = mag2;
      }
    }
    return spec; // [freqBins][timeFrames]
  }

  /// Build mel filterbank matrix [nMels][fftBins]
  List<List<double>> _buildMelFilterbank() {
    final int fftBins = nFft ~/ 2 + 1;
    final double nyquist = sampleRate / 2.0;

    // Convert Hz to Mel and mel to Hz
    double hzToMel(double hz) => 2595 * log(1 + hz / 700) / ln10;
    double melToHz(double mel) =>
        700 * (pow(10, mel * ln10 / 2595) - 1); // inverse of above

    final double minMel = hzToMel(fMin);
    final double maxMel = hzToMel(fMax);
    final List<double> mels = List.generate(
        nMels + 2, (i) => minMel + (maxMel - minMel) * i / (nMels + 1));
    final List<double> hzPoints = mels.map((m) => melToHz(m)).toList();

    // FFT bin frequencies
    final List<double> binFrequencies = List.generate(
        fftBins, (i) => i * (sampleRate / nFft));

    // Create filters
    List<List<double>> filterbank =
        List.generate(nMels, (_) => List.filled(fftBins, 0.0));

    for (int m = 1; m <= nMels; m++) {
      final double fMMinus = hzPoints[m - 1];
      final double fM = hzPoints[m];
      final double fMPlus = hzPoints[m + 1];

      for (int k = 0; k < fftBins; k++) {
        final double freq = binFrequencies[k];
        double weight = 0.0;
        if (freq >= fMMinus && freq <= fM) {
          weight = (freq - fMMinus) / (fM - fMMinus);
        } else if (freq >= fM && freq <= fMPlus) {
          weight = (fMPlus - freq) / (fMPlus - fM);
        }
        filterbank[m - 1][k] = weight.clamp(0.0, 1.0);
      }
    }
    return filterbank;
  }

  /// Apply filterbank: mel energies = filterbank * powerSpectrogram
  List<List<double>> _applyMelFilterbank(List<List<double>> powerSpec) {
    final int timeFrames = powerSpec[0].length;
    List<List<double>> melSpec =
        List.generate(nMels, (_) => List.filled(timeFrames, 0.0));

    for (int m = 0; m < nMels; m++) {
      for (int t = 0; t < timeFrames; t++) {
        double sum = 0.0;
        for (int k = 0; k < powerSpec.length; k++) {
          sum += _melFilterbank[m][k] * powerSpec[k][t];
        }
        melSpec[m][t] = sum;
      }
    }
    return melSpec;
  }

  /// Log compression with small epsilon
  List<List<double>> _logCompress(List<List<double>> melSpec) {
    const double epsilon = 1e-6;
    final int timeFrames = melSpec[0].length;
    List<List<double>> logMel =
        List.generate(nMels, (_) => List.filled(timeFrames, 0.0));
    for (int m = 0; m < nMels; m++) {
      for (int t = 0; t < timeFrames; t++) {
        logMel[m][t] = log(melSpec[m][t] + epsilon);
      }
    }
    return logMel;
  }

  static List<double> _createHannWindow(int length) {
    return List.generate(
        length, (i) => 0.5 * (1 - cos(2 * pi * i / (length - 1))));
  }
}
