part of 'package:oimg/main.dart';

class _ImageSessionView extends ConsumerStatefulWidget {
  const _ImageSessionView({required this.title});

  final String title;

  @override
  ConsumerState<_ImageSessionView> createState() => _ImageSessionViewState();
}

class _ImageSessionViewState extends ConsumerState<_ImageSessionView> {
  double _sidebarWidth = _defaultSidebarWidth;
  double _settingsSidebarWidth = _defaultSettingsSidebarWidth;
  double _bottomSidebarHeight = _defaultBottomSidebarHeight;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(fileOpenControllerProvider);
    final currentFile = controller.currentFile;
    if (currentFile == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 1120;
          final sidebar = _ExplorerSidebar(controller: controller);
          final stage = controller.isFolderSelected
              ? _FolderStage(controller: controller)
              : _ImageStage(title: widget.title, currentFile: currentFile);
          const settingsSidebar = _SettingsSidebar();
          final bottomSidebar = _BottomSidebar(controller: controller);

          if (wideLayout) {
            final maxWidth = _clampSidebarWidth(constraints.maxWidth * 0.38);
            final sidebarWidth = _sidebarWidth.clamp(
              _minSidebarWidth,
              maxWidth,
            );
            final settingsMaxWidth = _clampSettingsSidebarWidth(
              constraints.maxWidth * 0.34,
            );
            final settingsSidebarWidth = _settingsSidebarWidth.clamp(
              _minSettingsSidebarWidth,
              settingsMaxWidth,
            );
            final bottomSidebarMaxHeight = _clampBottomSidebarHeight(
              constraints.maxHeight * 0.4,
            );
            final bottomSidebarHeight = _bottomSidebarHeight.clamp(
              _minBottomSidebarHeight,
              bottomSidebarMaxHeight,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: sidebarWidth, child: sidebar),
                      _ResizeHandle(
                        axis: Axis.horizontal,
                        onDragUpdate: (delta) {
                          setState(() {
                            _sidebarWidth = _clampSidebarWidth(
                              _sidebarWidth + delta,
                              maxWidth: maxWidth,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: stage),
                      const SizedBox(width: 12),
                      _ResizeHandle(
                        axis: Axis.horizontal,
                        onDragUpdate: (delta) {
                          setState(() {
                            _settingsSidebarWidth = _clampSettingsSidebarWidth(
                              _settingsSidebarWidth - delta,
                              maxWidth: settingsMaxWidth,
                            );
                          });
                        },
                      ),
                      SizedBox(
                        width: settingsSidebarWidth,
                        child: settingsSidebar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _ResizeHandle(
                  axis: Axis.vertical,
                  onDragUpdate: (delta) {
                    setState(() {
                      _bottomSidebarHeight = _clampBottomSidebarHeight(
                        _bottomSidebarHeight - delta,
                        maxHeight: bottomSidebarMaxHeight,
                      );
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(height: bottomSidebarHeight, child: bottomSidebar),
              ],
            );
          }

          final bottomSidebarMaxHeight = _clampBottomSidebarHeight(
            constraints.maxHeight * 0.35,
          );
          final bottomSidebarHeight = _bottomSidebarHeight.clamp(
            _minBottomSidebarHeight,
            bottomSidebarMaxHeight,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 220, child: sidebar),
                    const SizedBox(height: 16),
                    Expanded(child: stage),
                    const SizedBox(height: 16),
                    const SizedBox(height: 420, child: settingsSidebar),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _ResizeHandle(
                axis: Axis.vertical,
                onDragUpdate: (delta) {
                  setState(() {
                    _bottomSidebarHeight = _clampBottomSidebarHeight(
                      _bottomSidebarHeight - delta,
                      maxHeight: bottomSidebarMaxHeight,
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(height: bottomSidebarHeight, child: bottomSidebar),
            ],
          );
        },
      ),
    );
  }

  double _clampSidebarWidth(double width, {double? maxWidth}) {
    return width.clamp(_minSidebarWidth, maxWidth ?? _maxSidebarWidth);
  }

  double _clampSettingsSidebarWidth(double width, {double? maxWidth}) {
    return width.clamp(
      _minSettingsSidebarWidth,
      maxWidth ?? _maxSettingsSidebarWidth,
    );
  }

  double _clampBottomSidebarHeight(double height, {double? maxHeight}) {
    return height.clamp(
      _minBottomSidebarHeight,
      maxHeight ?? _maxBottomSidebarHeight,
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.axis, required this.onDragUpdate});

  final Axis axis;
  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal
            ? (details) => onDragUpdate(details.delta.dx)
            : null,
        onVerticalDragUpdate: isHorizontal
            ? null
            : (details) => onDragUpdate(details.delta.dy),
        child: isHorizontal
            ? const SizedBox(width: 8)
            : const SizedBox(height: 8),
      ),
    );
  }
}
