import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../models/unmixed_song.dart';

class AudioExportException implements Exception {
  final String message;

  AudioExportException(this.message);

  @override
  String toString() => message;
}

class AudioExportService {
  static const _methodChannel = MethodChannel(PlatformChannels.audioExport);

  Future<String> exportStems(UnmixedSong song) async {
    _checkStemFiles(song);
    await _requestLegacyStoragePermissionIfNeeded();

    try {
      final exportPath = await _methodChannel.invokeMethod<String>(
        'exportStems',
        {
          'originalFileName': _getOriginalFileName(song),
          'stems': {
            Stem.vocals.value: song.vocals,
            Stem.drums.value: song.drums,
            Stem.bass.value: song.bass,
            Stem.other.value: song.other,
          },
        },
      );

      if (exportPath == null || exportPath.isEmpty) {
        throw AudioExportException('Export failed: invalid destination path.');
      }

      return exportPath;
    } on PlatformException catch (error) {
      throw AudioExportException(error.message ?? 'Failed to export stems.');
    }
  }

  String _getOriginalFileName(UnmixedSong song) {
    final baseName = path.basenameWithoutExtension(song.mixture);
    if (baseName.isNotEmpty) return baseName;

    final title = song.title.trim();
    if (title.isNotEmpty) return title;

    return 'demixr_export';
  }

  Future<void> _requestLegacyStoragePermissionIfNeeded() async {
    if (!Platform.isAndroid) return;

    final requiresPermission = await _methodChannel
            .invokeMethod<bool>('requiresLegacyStoragePermission') ??
        false;

    if (!requiresPermission) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw AudioExportException(
          'Storage permission denied. Unable to save stems to Music/Demixr.');
    }
  }

  void _checkStemFiles(UnmixedSong song) {
    final stems = {
      Stem.vocals.value: song.vocals,
      Stem.drums.value: song.drums,
      Stem.bass.value: song.bass,
      Stem.other.value: song.other,
    };

    final missing = stems.entries
        .where((entry) => entry.value.trim().isEmpty || !File(entry.value).existsSync())
        .map((entry) => entry.key)
        .toList();

    if (missing.isNotEmpty) {
      throw AudioExportException(
        'Missing stem data: ${missing.join(', ')}.',
      );
    }
  }
}
