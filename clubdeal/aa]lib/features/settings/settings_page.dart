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
              subtitle: 'Desktop terminal configuration',
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
              child: Builder(
                builder: (context) {
                  final printer = context.read<PrinterService>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Windows printer integration is intentionally isolated '
                        'from the UI. Do not use the Android Bluetooth printer '
                        'package in the desktop build.',
                        style: TextStyle(color: AppColors.cream2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await printer.testPrint();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            },
                            icon: const Icon(Icons.print_outlined, size: 17),
                            label: const Text('Test Printer'),
                          ),
                          StatusPill(
                            text: printer.isConnected
                                ? 'CONNECTED'
                                : 'NOT CONFIGURED',
                            color: printer.isConnected
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
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
