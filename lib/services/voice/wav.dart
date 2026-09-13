import 'dart:typed_data';

/// Wraps raw 16-bit PCM samples in a WAV header. Pure Dart, unit-tested,
/// so the same bytes go up from every platform (the recorder streams PCM
/// on iOS, Android and the web alike).
Uint8List wavFromPcm16(List<int> pcm, {int sampleRate = 16000, int channels = 1}) {
  final dataLength = pcm.length;
  final byteRate = sampleRate * channels * 2;
  final out = ByteData(44 + dataLength);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // PCM chunk size
  out.setUint16(20, 1, Endian.little); // PCM format
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, byteRate, Endian.little);
  out.setUint16(32, channels * 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  out.setUint32(40, dataLength, Endian.little);
  final bytes = out.buffer.asUint8List();
  bytes.setRange(44, 44 + dataLength, pcm);
  return bytes;
}

/// Seconds of audio in a 16-bit PCM buffer.
double pcm16Seconds(int byteLength, {int sampleRate = 16000, int channels = 1}) =>
    byteLength / (sampleRate * channels * 2);
