import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';
import 'package:wav/wav.dart';

import '../models/mel_spectrogram.dart';

class MelSpectrogramExtractor {
  final int sampleRate;
  final int nFft;
  final int hopLength;
  final int nMels;
  final double fMin;
  final double fMax;
  final double preEmphasis;

  late final Float32List _hannWindow = _createHannWindow(nFft);
  late final List<Float32List> _melFilterbank = _buildMelFilterbank();
  late final FFT _fft = FFT(nFft);

  late final Float64List _fftInput = Float64List(nFft);

  MelSpectrogramExtractor({
    this.sampleRate = 16_000,
    this.nFft = 1024,
    int? hopLength,
    this.nMels = 64,
    this.fMin = 0.0,
    double? fMax,
    this.preEmphasis = 0.97,
  }) : hopLength = hopLength ?? (1024 ~/ 2),
       fMax = fMax ?? (16_000 / 2);

  Future<Float32List> loadWavAsFloat32(String path) async {
    final wavFile = await Wav.readFile(path);

    // resample
    if (wavFile.samplesPerSecond != sampleRate) {
      throw FormatException(
        'Expected $sampleRate Hz, got ${wavFile.samplesPerSecond}',
      );
    }

    final channel = wavFile.toMono();

    final Float32List out = Float32List(channel.length);

    for (int i = 0; i < channel.length; i++) {
      out[i] = channel[i];
    }

    return out;
  }

  // Returns a natural‑log Mel‑spectrogram (shape **[nMels][time]**).
  MelSpectrogram extract(Float32List waveform) {
    final emphasised = _applyPreEmphasis(waveform);
    final frames = _frameSignal(emphasised);
    final power = _stftPower(frames);
    final mel = _applyMelFilterbank(power);
    final logMel = _logCompress(mel);

    // Flatten for cache‑friendliness if desired by caller.
    final nFrames = logMel[0].length;
    final result = Float32List(nMels * nFrames);
    for (var m = 0; m < nMels; ++m) {
      result.setRange(m * nFrames, (m + 1) * nFrames, logMel[m]);
    }
    return MelSpectrogram(result, nMels, nFrames);
  }

  // Signal processing pipeline
  Float32List _applyPreEmphasis(Float32List x) {
    final out = Float32List(x.length);
    if (x.isNotEmpty) out[0] = x[0];
    for (var i = 1; i < x.length; ++i) {
      out[i] = x[i] - preEmphasis * x[i - 1];
    }
    return out;
  }

  // Splits the waveform into **overlapping frames** and applies the window.
  List<Float32List> _frameSignal(Float32List s) {
    final n = s.length;
    final step = hopLength;
    final nFrames = ((n - nFft + step) / step).ceil();
    final List<Float32List> out = List.generate(
      nFrames,
      (_) => Float32List(nFft),
      growable: false,
    );

    for (var frame = 0; frame < nFrames; ++frame) {
      final start = frame * step;
      for (var j = 0; j < nFft; ++j) {
        final sample = (start + j) < n ? s[start + j] : 0.0; // zero‑pad tail
        out[frame][j] = sample * _hannWindow[j];
      }
    }
    return out;
  }

  // Magnitude‑squared STFT.  Returns **freqBins × time** as List<Float32List>.
  List<Float32List> _stftPower(List<Float32List> frames) {
    final freqBins = nFft ~/ 2 + 1;
    final List<Float32List> spec = List.generate(
      freqBins,
      (_) => Float32List(frames.length),
      growable: false,
    );

    for (var t = 0; t < frames.length; ++t) {
      // Copy to scratch (fftea expects Float64List)
      for (var i = 0; i < nFft; ++i) {
        _fftInput[i] = frames[t][i];
      }

      final complex = _fft.realFft(_fftInput);
      for (var k = 0; k < freqBins; ++k) {
        final re = complex[k].x;
        final im = complex[k].y;
        spec[k][t] = (re * re + im * im).toDouble();
      }
    }
    return spec;
  }

  // filterbank * powerSpec   (matrix‑vector mul in the innermost loop).
  List<Float32List> _applyMelFilterbank(List<Float32List> power) {
    final T = power[0].length;
    final List<Float32List> mel = List.generate(
      nMels,
      (_) => Float32List(T),
      growable: false,
    );

    for (var m = 0; m < nMels; ++m) {
      final fbRow = _melFilterbank[m];
      for (var t = 0; t < T; ++t) {
        double sum = 0;
        for (var k = 0; k < fbRow.length; ++k) {
          sum += fbRow[k] * power[k][t];
        }
        mel[m][t] = sum;
      }
    }
    return mel;
  }

  List<Float32List> _logCompress(List<Float32List> mel) {
    const eps = 1e-10; // smaller ε => larger dynamic range
    for (final row in mel) {
      for (var i = 0; i < row.length; ++i) {
        row[i] = math.log(row[i] + eps).toDouble();
      }
    }
    return mel;
  }

  List<Float32List> _buildMelFilterbank() {
    final int fftBins = nFft ~/ 2 + 1;
    double hz2mel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;
    double mel2hz(double mel) => 700 * (math.pow(10, mel / 2595) - 1) as double;

    final melPoints = List.generate(
      nMels + 2,
      (i) => hz2mel(fMin) + (hz2mel(fMax) - hz2mel(fMin)) * i / (nMels + 1),
    );
    final hzPoints = melPoints.map(mel2hz).toList();

    final binFreqs = List.generate(
      fftBins,
      (i) => i * (sampleRate / nFft).toDouble(),
    );

    final List<Float32List> fb = List.generate(
      nMels,
      (_) => Float32List(fftBins),
      growable: false,
    );

    for (var m = 1; m <= nMels; ++m) {
      final f0 = hzPoints[m - 1];
      final f1 = hzPoints[m];
      final f2 = hzPoints[m + 1];
      for (var k = 0; k < fftBins; ++k) {
        final f = binFreqs[k];
        double w = 0;
        if (f >= f0 && f <= f1) {
          w = (f - f0) / (f1 - f0);
        } else if (f >= f1 && f <= f2) {
          w = (f2 - f) / (f2 - f1);
        }
        fb[m - 1][k] = w.toDouble();
      }
    }
    return fb;
  }

  static Float32List _createHannWindow(int length) {
    final w = Float32List(length);
    final coef = 2 * math.pi / (length - 1);
    for (var i = 0; i < length; ++i) {
      w[i] = 0.5 * (1 - math.cos(coef * i)).toDouble();
    }
    return w;
  }
}
