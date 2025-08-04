import 'dart:typed_data';

class MelSpectrogram {
  MelSpectrogram(this.data, this.nMels, this.nFrames);

  /// Row‑major, i.e. `data[m * nFrames + t]`
  final Float32List data;
  final int nMels;
  final int nFrames;
}
