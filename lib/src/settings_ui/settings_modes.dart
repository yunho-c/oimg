part of 'package:oimg/main.dart';

class _AdvancedSettingsModeSection extends StatelessWidget {
  const _AdvancedSettingsModeSection({
    super.key,
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsLabel('Codec'),
        const SizedBox(height: 8),
        RadioGroup<PreferredCodec>(
          value: settings.preferredCodec,
          onChanged: controlsLocked ? null : notifier.setPreferredCodec,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PreferredCodec.values
                    .map(
                      (codec) => SizedBox(
                        width: cardWidth,
                        child: RadioCard<PreferredCodec>(
                          value: codec,
                          child: _ChoiceCard(title: codecLabel(codec)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasicSettingsModeSection extends StatelessWidget {
  const _BasicSettingsModeSection({
    super.key,
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsLabel('Compression'),
        const SizedBox(height: 8),
        RadioGroup<CompressionMethod>(
          value: settings.compressionMethod,
          onChanged: controlsLocked ? null : notifier.setCompressionMethod,
          child: Row(
            children: [
              Expanded(
                child: RadioCard<CompressionMethod>(
                  value: CompressionMethod.lossless,
                  child: const _ChoiceCard(title: 'Lossless'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RadioCard<CompressionMethod>(
                  value: CompressionMethod.lossy,
                  child: const _ChoiceCard(title: 'Lossy'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsLabel('Priority'),
        const SizedBox(height: 8),
        RadioGroup<CompressionPriority>(
          value: settings.compressionPriority,
          onChanged: controlsLocked ? null : notifier.setCompressionPriority,
          child: Row(
            children: [
              Expanded(
                child: RadioCard<CompressionPriority>(
                  value: CompressionPriority.compatibility,
                  child: const _ChoiceCard(title: 'Compatibility'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RadioCard<CompressionPriority>(
                  value: CompressionPriority.efficiency,
                  child: const _ChoiceCard(title: 'Efficiency'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
