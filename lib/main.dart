import 'dart:io';

import 'package:flutter/material.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/rust/frb_generated.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final controller = FileOpenController(
    channel: MethodChannelFileOpenChannel(),
    initialPaths: args,
  );
  await controller.initialize();

  runApp(MyApp(controller: controller));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OIMG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: OimgHomePage(controller: controller),
    );
  }
}

class OimgHomePage extends StatefulWidget {
  const OimgHomePage({super.key, required this.controller});

  final FileOpenController controller;

  @override
  State<OimgHomePage> createState() => _OimgHomePageState();
}

class _OimgHomePageState extends State<OimgHomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final notice = widget.controller.takePendingNotice();
    if (notice == null || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('OIMG')),
          body: widget.controller.hasSession
              ? _ImageSessionView(controller: widget.controller)
              : const _EmptyState(),
        );
      },
    );
  }
}

class _ImageSessionView extends StatelessWidget {
  const _ImageSessionView({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final currentPath = controller.currentPath;
    final currentFileName = controller.currentFileName;
    if (currentPath == null || currentFileName == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            currentFileName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(currentPath, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6,
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Image.file(
                      File(currentPath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Unable to load $currentFileName.',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.canGoPrevious
                    ? controller.showPrevious
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: controller.canGoNext ? controller.showNext : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
              const Spacer(),
              if (controller.currentPositionLabel case final position?)
                Text(position, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Open an image with OIMG',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Use Finder, File Explorer, or your Linux file manager to open PNG, JPEG, GIF, BMP, WebP, or TIFF files with OIMG.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
