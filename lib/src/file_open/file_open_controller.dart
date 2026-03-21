import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'file_open_channel.dart';

class FileOpenController extends ChangeNotifier {
  FileOpenController({
    required FileOpenChannel channel,
    List<String> initialPaths = const [],
  }) : _channel = channel,
       _initialPaths = List<String>.unmodifiable(initialPaths);

  static const supportedExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.tif',
    '.tiff',
  };

  final FileOpenChannel _channel;
  final List<String> _initialPaths;

  List<String> _sessionPaths = const [];
  int _currentIndex = 0;
  String? _pendingNotice;

  UnmodifiableListView<String> get sessionPaths =>
      UnmodifiableListView(_sessionPaths);

  bool get hasSession => _sessionPaths.isNotEmpty;
  int get currentIndex => _currentIndex;
  int get sessionLength => _sessionPaths.length;
  bool get canGoPrevious => _currentIndex > 0;
  bool get canGoNext => _currentIndex + 1 < _sessionPaths.length;
  String? get currentPath => hasSession ? _sessionPaths[_currentIndex] : null;
  String? get currentFileName =>
      currentPath == null ? null : fileNameOf(currentPath!);
  String? get currentPositionLabel =>
      hasSession ? '${_currentIndex + 1} / ${_sessionPaths.length}' : null;

  Future<void> initialize() async {
    await _channel.bind(openPaths);
    await openPaths(_initialPaths);
  }

  Future<void> openPaths(List<String> paths) async {
    final supportedPaths = paths
        .where(isSupportedImagePath)
        .toList(growable: false);
    if (supportedPaths.isEmpty) {
      if (paths.isNotEmpty) {
        _pendingNotice =
            'OIMG can only open PNG, JPEG, GIF, BMP, WebP, and TIFF files.';
        notifyListeners();
      }
      return;
    }

    _sessionPaths = supportedPaths;
    _currentIndex = 0;
    _pendingNotice = null;
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

  String? takePendingNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  static bool isSupportedImagePath(String path) {
    final lowerPath = path.toLowerCase();
    return supportedExtensions.any(lowerPath.endsWith);
  }

  static String fileNameOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }
}
