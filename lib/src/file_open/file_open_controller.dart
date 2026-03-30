import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/settings/developer_diagnostics.dart';
import 'package:oimg/src/rust/types.dart';

import 'file_open_channel.dart';
import 'opened_image_file.dart';

class FileOpenController extends ChangeNotifier {
  FileOpenController({
    required FileOpenChannel channel,
    required SlimgApi slimg,
    List<String> initialPaths = const [],
  }) : _channel = channel,
       _slimg = slimg,
       _initialPaths = List<String>.unmodifiable(initialPaths);

  final FileOpenChannel _channel;
  final SlimgApi _slimg;
  final List<String> _initialPaths;

  List<OpenedImageFile> _sessionFiles = const [];
  int _currentIndex = 0;
  String? _pendingNotice;

  UnmodifiableListView<OpenedImageFile> get sessionFiles =>
      UnmodifiableListView(_sessionFiles);
  UnmodifiableListView<String> get sessionPaths =>
      UnmodifiableListView(_sessionFiles.map((file) => file.path).toList());

  bool get hasSession => _sessionFiles.isNotEmpty;
  int get currentIndex => _currentIndex;
  int get sessionLength => _sessionFiles.length;
  bool get canGoPrevious => _currentIndex > 0;
  bool get canGoNext => _currentIndex + 1 < _sessionFiles.length;
  OpenedImageFile? get currentFile =>
      hasSession ? _sessionFiles[_currentIndex] : null;
  String? get currentPath => currentFile?.path;
  String? get currentFileName =>
      currentPath == null ? null : fileNameOf(currentPath!);
  String? get currentPositionLabel =>
      hasSession ? '${_currentIndex + 1} / ${_sessionFiles.length}' : null;

  Future<void> initialize() async {
    await _channel.bind(openPaths);
    await openPaths(_initialPaths);
  }

  Future<void> openPaths(List<String> paths) async {
    final candidatePaths = await _expandCandidatePaths(paths);
    final inspectedFiles = <OpenedImageFile>[];
    var rejectedCount = 0;

    for (final path in candidatePaths) {
      final file = await _inspectPath(path);
      if (file == null) {
        rejectedCount += 1;
        continue;
      }
      inspectedFiles.add(file);
    }

    if (inspectedFiles.isEmpty) {
      if (candidatePaths.isNotEmpty) {
        _pendingNotice = 'Some files could not be opened.';
        notifyListeners();
      }
      return;
    }

    _sessionFiles = inspectedFiles;
    _currentIndex = 0;
    _pendingNotice = rejectedCount == 0 ? null : 'Some files could not be opened.';
    notifyListeners();
  }

  void showPrevious() {
    if (!canGoPrevious) {
      return;
    }

    _currentIndex -= 1;
    notifyListeners();
  }

  void showNext() {
    if (!canGoNext) {
      return;
    }

    _currentIndex += 1;
    notifyListeners();
  }

  void showPath(String path) {
    final index = _sessionFiles.indexWhere((file) => file.path == path);
    if (index == -1 || index == _currentIndex) {
      return;
    }

    _currentIndex = index;
    notifyListeners();
  }

  String? takePendingNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  Future<void> applyProcessResults(List<BatchItemResult> results) async {
    if (_sessionFiles.isEmpty) {
      return;
    }

    final updatedFiles = _sessionFiles.toList(growable: false);
    final selectedIndex = _currentIndex;

    for (final item in results) {
      DeveloperDiagnostics.logTiming(
        'optimize-results',
        'input=${item.inputPath} success=${item.success} hasResult=${item.result != null} error=${item.error}',
      );
      final index = updatedFiles.indexWhere((file) => file.path == item.inputPath);
      if (index == -1) {
        continue;
      }

      if (!item.success || item.result == null) {
        DeveloperDiagnostics.logTiming(
          'optimize-results',
          'failed input=${item.inputPath} error=${item.error}',
        );
        updatedFiles[index] = updatedFiles[index].copyWith(
          lastError: item.error?.toString() ?? 'Unable to optimize file.',
          clearLastResult: true,
        );
        continue;
      }

      final result = item.result!;
      final refreshedFile = await _inspectPath(result.outputPath);
      if (refreshedFile == null) {
        DeveloperDiagnostics.logTiming(
          'optimize-results',
          'reload-failed input=${item.inputPath} output=${result.outputPath} didWrite=${result.didWrite}',
        );
        updatedFiles[index] = updatedFiles[index].copyWith(
          lastResult: result,
          lastError: 'Unable to reload optimized file.',
        );
        continue;
      }

      DeveloperDiagnostics.logTiming(
        'optimize-results',
        'applied input=${item.inputPath} output=${result.outputPath} didWrite=${result.didWrite} original=${result.originalSize} new=${result.newSize}',
      );
      updatedFiles[index] = refreshedFile.copyWith(
        lastResult: result,
        clearLastError: true,
      );
    }

    _sessionFiles = updatedFiles;
    if (_sessionFiles.isNotEmpty) {
      _currentIndex = selectedIndex.clamp(0, _sessionFiles.length - 1);
    }
    notifyListeners();
  }

  Future<OpenedImageFile?> _inspectPath(String path) async {
    try {
      final metadata = await _slimg.inspectFile(inputPath: path);
      return OpenedImageFile(path: path, metadata: metadata);
    } on Object {
      return null;
    }
  }

  static String fileNameOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }

  Future<List<String>> _expandCandidatePaths(List<String> paths) async {
    final expanded = <String>{};

    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        try {
          await for (final entity in Directory(
            path,
          ).list(recursive: true, followLinks: false)) {
            if (entity is File) {
              expanded.add(entity.path);
            }
          }
        } on FileSystemException {
          expanded.add(path);
        }
        continue;
      }

      expanded.add(path);
    }

    return expanded.toList(growable: false);
  }
}
