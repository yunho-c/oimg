part of 'package:oimg/main.dart';

class _ExplorerSidebar extends StatelessWidget {
  const _ExplorerSidebar({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = _buildExplorerNodes(controller);

    return Card(
      padding: EdgeInsets.zero,
      borderRadius: theme.borderRadiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'Files',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ).xSmall(),
          ),
          // const Divider(),
          Expanded(
            child: TreeView<_ExplorerEntry>(
              nodes: nodes,
              branchLine: BranchLine.none,
              expandIcon: false,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              builder: (context, node) {
                final entry = node.data;
                final item = TreeItemView(
                  key: ValueKey('explorer-item-${entry.path}'),
                  leading: entry.isDirectory
                      ? Icon(
                          LucideIcons.folder,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        )
                      : null,
                  trailing: entry.sizeLabel == null
                      ? null
                      : Text(entry.sizeLabel!).small().muted(),
                  expandable: false,
                  onPressed: entry.isDirectory
                      ? () => controller.showFolder(entry.path)
                      : () => controller.showPath(entry.path),
                  child: Text(entry.label).small().mediumIf(entry.isDirectory),
                );
                final showInFileManagerLabel = _showInFileManagerLabel();
                if (showInFileManagerLabel == null) {
                  return item;
                }

                return ContextMenu(
                  items: [
                    MenuButton(
                      onPressed: (context) {
                        unawaited(controller.showInFileManager(entry.path));
                      },
                      child: Text(showInFileManagerLabel),
                    ),
                  ],
                  child: item,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TreeNode<_ExplorerEntry>> _buildExplorerNodes(
    FileOpenController controller,
  ) {
    final selection = controller.explorerSelection;
    final showFolderSize = controller.sessionFiles.length > 1;
    final groups = <String, List<OpenedImageFile>>{};
    for (final file in controller.sessionFiles) {
      final directory = FileOpenController.directoryOf(file.path);
      groups.putIfAbsent(directory, () => <OpenedImageFile>[]).add(file);
    }

    return groups.entries
        .map((entry) {
          final folderSizeLabel = showFolderSize
              ? _folderSizeLabel(entry.value)
              : null;
          return TreeItem<_ExplorerEntry>(
            data: _ExplorerEntry.directory(
              label: FileOpenController.directoryLabelOf(entry.key),
              path: entry.key,
              sizeLabel: folderSizeLabel,
            ),
            expanded: true,
            selected:
                selection?.type == ExplorerSelectionType.folder &&
                selection?.path == entry.key,
            children: entry.value
                .map(
                  (file) => TreeItem<_ExplorerEntry>(
                    data: _ExplorerEntry.file(
                      label: FileOpenController.fileNameOf(file.path),
                      path: file.path,
                      sizeLabel: _fileSizeLabel(file),
                    ),
                    selected:
                        selection?.type == ExplorerSelectionType.file &&
                        selection?.path == file.path,
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }
}

class _ExplorerEntry {
  const _ExplorerEntry._({
    required this.label,
    required this.path,
    required this.sizeLabel,
    required this.isDirectory,
  });

  const _ExplorerEntry.directory({
    required String label,
    required String path,
    required String? sizeLabel,
  }) : this._(
         label: label,
         path: path,
         sizeLabel: sizeLabel,
         isDirectory: true,
       );

  const _ExplorerEntry.file({
    required String label,
    required String path,
    required String? sizeLabel,
  }) : this._(
         label: label,
         path: path,
         sizeLabel: sizeLabel,
         isDirectory: false,
       );

  final String label;
  final String path;
  final String? sizeLabel;
  final bool isDirectory;
}
