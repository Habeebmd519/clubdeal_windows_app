import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/settings_bloc.dart';
import '../../core/services/printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageTitle(
              title: 'Settings',
              subtitle: 'Desktop terminal configuration, version 0.1',
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Order Alerts',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable order sounds'),
                    subtitle: const Text(
                      'Play an alert when a new order is received.',
                    ),
                    value: state.soundsEnabled,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(SoundsToggled(value));
                    },
                  ),
                  const Divider(color: AppColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      state.usingDefaultSound
                          ? 'Default sound'
                          : state.customSoundPath ?? 'Custom sound',
                    ),
                    subtitle: const Text('Windows audio file'),
                    leading: const Icon(Icons.volume_up_outlined),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final files = await FilePicker.pickFiles(
                              type: FileType.audio,
                            );

                            if (files.isEmpty) {
                              return;
                            }

                            final path = files.first.path;

                            if (path == null || path.isEmpty) {
                              return;
                            }

                            if (!context.mounted) return;

                            context.read<SettingsBloc>().add(
                              CustomSoundSelected(path),
                            );
                          },
                          icon: const Icon(Icons.folder_open, size: 17),
                          label: const Text('Choose'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.soundsEnabled
                              ? () => context.read<SettingsBloc>().add(
                                  const SoundPreviewRequested(),
                                )
                              : null,
                          icon: const Icon(Icons.play_arrow, size: 17),
                          label: const Text('Preview'),
                        ),
                        TextButton(
                          onPressed: state.usingDefaultSound
                              ? null
                              : () => context.read<SettingsBloc>().add(
                                  const DefaultSoundRestored(),
                                ),
                          child: const Text('Default'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Printer',
              child: AnimatedBuilder(
                animation: context.read<PrinterService>(),
                builder: (context, _) {
                  final printer = context.read<PrinterService>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the printer installed in Windows. Connect the POS58 by USB and install its Windows driver first.',
                        style: TextStyle(color: AppColors.cream2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatically print kitchen tickets',
                        ),
                        subtitle: const Text(
                          'Send a kitchen ticket when a new order arrives. Existing order history is not reprinted.',
                        ),
                        value: printer.autoPrintNewOrders,
                        onChanged: printer.setAutoPrintNewOrders,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value:
                                  printer.printers.any(
                                    (p) =>
                                        p.name == printer.selectedPrinterName,
                                  )
                                  ? printer.selectedPrinterName
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Windows printer',
                                prefixIcon: Icon(Icons.print_outlined),
                              ),
                              hint: Text(
                                printer.printers.isEmpty
                                    ? 'No printers found'
                                    : 'Select printer',
                              ),
                              items: printer.printers
                                  .map(
                                    (p) => DropdownMenuItem<String>(
                                      value: p.name,
                                      child: Text(
                                        p.isDefault
                                            ? '${p.name} (Default)'
                                            : p.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: printer.selectPrinter,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: printer.isLoading
                                ? null
                                : printer.refreshPrinters,
                            icon: const Icon(Icons.refresh, size: 17),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: !printer.isConnected || printer.isLoading
                                ? null
                                : () async {
                                    try {
                                      await printer.testPrint();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Test receipt sent to Windows print queue.',
                                              ),
                                            ),
                                          );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Test print failed: $e',
                                              ),
                                            ),
                                          );
                                    }
                                  },
                            icon: const Icon(Icons.print, size: 17),
                            label: const Text('Test Print'),
                          ),
                          StatusPill(
                            text: printer.isConnected
                                ? 'READY'
                                : 'NOT CONNECTED',
                            color: printer.isConnected
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
                      if (printer.lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          printer.lastError!,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const _Section(
              title: 'Desktop Performance',
              child: Text(
                'This build avoids charts, gradients, heavy shadows, continuous '
                'animations and Google Fonts. Lists are virtualized and all '
                'business state is handled through BLoC.',
                style: TextStyle(
                  color: AppColors.cream2,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
