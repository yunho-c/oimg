part of 'package:oimg/main.dart';

class _FolderStage extends StatelessWidget {
  const _FolderStage({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folderPath = controller.selectedFolderPath;
    final folderFiles = controller.selectedFolderFiles;
    final totalBytes = controller.selectedFolderSizeBytes;
    if (folderPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      padding: EdgeInsets.zero,
      borderRadius: theme.borderRadiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folderPath,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ).xSmall(),
                const SizedBox(height: 4),
                Text(
                  controller.selectedFolderName ?? folderPath,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _PreviewMetaItem(
                      label: 'Images',
                      value: '${folderFiles.length}',
                    ),
                    if (totalBytes case final bytes?)
                      _PreviewMetaItem(
                        label: 'Size',
                        value: _formatBytes(bytes),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(14),
              child: _FolderCollage(
                files: folderFiles,
                onOpenFile: controller.showPath,
                onRevealFile: controller.showInFileManager,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
