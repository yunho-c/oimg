import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/settings/developer_diagnostics.dart';
import 'package:oimg/src/rust/types.dart';

import 'file_open_channel.dart';
import 'opened_image_file.dart';

enum ExplorerSelectionType { file, folder }

class ExplorerSelection {
  const ExplorerSelection._({required this.type, required this.path});

  const ExplorerSelection.file(String path)
    : this._(type: ExplorerSelectionType.file, path: path);

  const ExplorerSelection.folder(String path)
    : this._(type: ExplorerSelectionType.folder, path: path);

  final ExplorerSelectionType type;
  final String path;
}

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
  String? _selectedFolderPath;

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
  String? get selectedFolderPath => _selectedFolderPath;
  bool get isFolderSelected => _selectedFolderPath != null;
  ExplorerSelection? get explorerSelection {
    if (_selectedFolderPath case final folderPath?) {
      return ExplorerSelection.folder(folderPath);
    }
    if (currentPath case final path?) {
      return ExplorerSelection.file(path);
    }
    return null;
  }
  String? get currentFileName =>
      currentPath == null ? null : fileNameOf(currentPath!);
  String? get currentDisplayTitle =>
      isFolderSelected
          ? (selectedFolderName ?? selectedFolderPath)
          : currentFileName;
  String? get selectedFolderName =>
      _selectedFolderPath == null ? null : directoryLabelOf(_selectedFolderPath!);
  UnmodifiableListView<OpenedImageFile> get selectedFolderFiles {
    if (_selectedFolderPath == null) {
      return UnmodifiableListView(const <OpenedImageFile>[]);
    }

    final files = _sessionFiles
        .where((file) => directoryOf(file.path) == _selectedFolderPath)
        .toList(growable: false);
    return UnmodifiableListView(files);
  }
  int? get selectedFolderSizeBytes {
    if (_selectedFolderPath == null) {
      return null;
    }

    var hasSize = false;
    var totalBytes = 0;
    for (final file in _sessionFiles) {
      if (directoryOf(file.path) != _selectedFolderPath) {
        continue;
      }
      final bytes = file.metadata.fileSize?.toInt();
      if (bytes == null) {
        continue;
      }
      hasSize = true;
      totalBytes += bytes;
    }
    return hasSize ? totalBytes : null;
  }
  String? get currentPositionLabel =>
      isFolderSelected
          ? null
          : (hasSession ? '${_currentIndex + 1} / ${_sessionFiles.length}' : null);

  Future<void> initialize() async {
    await _channel.bind(openPaths);
    await openPaths(_initialPaths);
  }

  Future<void> pickFilesAndOpen() async {
    final paths = await _channel.pickFiles();
    if (paths.isEmpty) {
      return;
    }
    await openPaths(paths);
  }

  Future<void> pickFolderAndOpen() async {
    final paths = await _channel.pickFolder();
    if (paths.isEmpty) {
      return;
    }
    await openPaths(paths);
  }

  Future<String?> pickStorageFolder() async {
    final paths = await _channel.pickFolder();
    if (paths.isEmpty) {
      return null;
    }
    return paths.first;
  }

  Future<void> showInFileManager(String path) async {
    await _channel.showInFileManager(path);
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
    _selectedFolderPath = null;
    _pendingNotice = rejectedCount == 0 ? null : 'Some files could not be opened.';
    notifyListeners();
  }

  void showPrevious() {
    if (!canGoPrevious) {
      return;
    }

    _currentIndex -= 1;
    _selectedFolderPath = null;
    notifyListeners();
  }

  void showNext() {
    if (!canGoNext) {
      return;
    }

    _currentIndex += 1;
    _selectedFolderPath = null;
    notifyListeners();
  }

  void showPath(String path) {
    final index = _sessionFiles.indexWhere((file) => file.path == path);
    if (index == -1) {
      return;
    }
    if (index == _currentIndex && _selectedFolderPath == null) {
      return;
    }

    _currentIndex = index;
    _selectedFolderPath = null;
    notifyListeners();
  }

  void showFolder(String path) {
    final hasFilesInFolder = _sessionFiles.any(
      (file) => directoryOf(file.path) == path,
    );
    if (!hasFilesInFolder || _selectedFolderPath == path) {
      return;
    }

    _selectedFolderPath = path;
    notifyListeners();
  }

  String? takePendingNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  Future<void> applyProcessResults(
    List<BatchItemResult> results, {
    Set<String> keepSourceEntries = const <String>{},
    Set<String> deleteSourcesAfterSuccess = const <String>{},
  }) async {
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
      final keepSourceEntry = keepSourceEntries.contains(item.inputPath);
      final deleteSourceAfterSuccess =
          deleteSourcesAfterSuccess.contains(item.inputPath);
      if (keepSourceEntry) {
        DeveloperDiagnostics.logTiming(
          'optimize-results',
          'retained-source input=${item.inputPath} output=${result.outputPath} didWrite=${result.didWrite}',
        );
        updatedFiles[index] = updatedFiles[index].copyWith(
          lastResult: result,
          clearLastError: true,
        );
        continue;
      }

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
      if (deleteSourceAfterSuccess &&
          result.didWrite &&
          result.outputPath != item.inputPath) {
        try {
          final inputFile = File(item.inputPath);
          if (await inputFile.exists()) {
            await inputFile.delete();
          }
        } on Object {
          // Best-effort cleanup; the optimized file has already been written.
        }
      }
      updatedFiles[index] = refreshedFile.copyWith(
        lastResult: result,
        clearLastError: true,
      );
    }

    _sessionFiles = updatedFiles;
    if (_sessionFiles.isNotEmpty) {
      _currentIndex = selectedIndex.clamp(0, _sessionFiles.length - 1);
    }
    if (_selectedFolderPath case final folderPath?) {
      final folderStillExists = _sessionFiles.any(
        (file) => directoryOf(file.path) == folderPath,
      );
      if (!folderStillExists) {
        _selectedFolderPath = null;
      }
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

  static String directoryOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final separator = normalized.lastIndexOf('/');
    if (separator < 0) {
      return '.';
    }
    if (separator == 0) {
      return '/';
    }
    return normalized.substring(0, separator);
  }

  static String directoryLabelOf(String directory) {
    final label = fileNameOf(directory);
    if (label.isNotEmpty) {
      return label;
    }
    return directory;
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
