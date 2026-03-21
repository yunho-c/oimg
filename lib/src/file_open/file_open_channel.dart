import 'dart:async';

import 'package:flutter/services.dart';

typedef OpenFilesHandler = Future<void> Function(List<String> paths);

abstract class FileOpenChannel {
  Future<void> bind(OpenFilesHandler onOpenFiles);
}

class MethodChannelFileOpenChannel implements FileOpenChannel {
  MethodChannelFileOpenChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'oimg/file_open';

  final MethodChannel _channel;

  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openFiles') {
        throw MissingPluginException('Unknown method: ${call.method}');
      }

      final arguments = call.arguments;
      if (arguments is! List) {
        return;
      }

      final paths = arguments.whereType<String>().toList(growable: false);
      await onOpenFiles(paths);
    });

    unawaited(_waitForNativeChannel());
  }

  Future<void> _waitForNativeChannel() async {
    for (var attempt = 0; attempt < 50; attempt += 1) {
      try {
        await _channel.invokeMethod<void>('ready');
        return;
      } on MissingPluginException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}
