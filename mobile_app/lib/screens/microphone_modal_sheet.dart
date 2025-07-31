import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';

class MicrophoneModalSheet extends StatefulWidget {
  const MicrophoneModalSheet({super.key});

  @override
  State<MicrophoneModalSheet> createState() => _MicrophoneModalSheetState();
}

class _MicrophoneModalSheetState extends State<MicrophoneModalSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ensureMicrophonePermission();
  }

  Future<void> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return;

    final result = await Permission.microphone.request();
    if (result.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone permanently denied. Please enable it from settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } else if (!result.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio.'),
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    final hasPerm = await Permission.microphone.isGranted;
    if (!hasPerm) {
      await _ensureMicrophonePermission();
      if (!await Permission.microphone.isGranted) return;
    }

    final tempDir = Directory.systemTemp;
    final filePath =
        '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        bitRate: 16000 * 16,
        sampleRate: 16000,
      ),
      path: filePath,
    );

    _duration = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() {
        _duration += const Duration(milliseconds: 200);
      });
    });

    setState(() {
      _isRecording = true;
      _recordedPath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final path = await _recorder.stop();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });

    if (path != null && mounted) {
      Navigator.of(context).pop(XFile(path));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _formattedDuration() {
    final minutes = _duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: SizedBox(
                  width: 48,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 80,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording ? 'Recording...' : 'Tap to start recording',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formattedDuration(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    FloatingActionButton.extended(
                      onPressed: _isRecording
                          ? _stopRecording
                          : _startRecording,
                      backgroundColor: _isRecording
                          ? Colors.grey[700]
                          : Colors.blue,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop' : 'Record'),
                    ),
                    const SizedBox(height: 12),
                    if (_recordedPath != null && !_isRecording)
                      Text('Last recording: ${_recordedPath!.split('/').last}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
