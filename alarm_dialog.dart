import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class AlarmDialog extends StatefulWidget {
  final String medicineName;
  final String dose;

  const AlarmDialog({
    super.key,
    required this.medicineName,
    required this.dose,
  });

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  late AudioPlayer _audioPlayer;
  Timer? _autoStopTimer;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playAlarm();
    _autoStopTimer = Timer(const Duration(seconds: 10), () {
      if (_isPlaying && mounted) {
        _stopAlarm();
      }
    });
  }

  Future<void> _playAlarm() async {
    try {
      // Try to play custom sound, fallback to default notification sound
      await _audioPlayer.play(AssetSource('alarm.mp3'));
    } catch (e) {
      debugPrint('Custom alarm sound not found, playing default ringtone');
      await _audioPlayer.play(DeviceFileSource('system/media/audio/ringtones')); // fallback
    }
  }

  void _stopAlarm() {
    if (_isPlaying) {
      _audioPlayer.stop();
      _isPlaying = false;
      _autoStopTimer?.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _autoStopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Medicine Reminder'),
      content: Text('Time to take ${widget.medicineName} (${widget.dose})'),
      actions: [
        ElevatedButton(
          onPressed: _stopAlarm,
          child: const Text('Stop Alarm'),
        ),
      ],
    );
  }
}
