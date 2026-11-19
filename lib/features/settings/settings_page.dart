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
                        'Choose the existing Windows printer queue or enable direct Wi-Fi/Ethernet printing below. Direct mode is for ESC/POS thermal printers that accept RAW TCP printing (usually port 9100) on the same network. USB/Bluetooth-only printers need a compatible Wi-Fi print server or Windows sharing.',
                        style: TextStyle(color: AppColors.cream2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use direct Wi-Fi / Network printer'),
                        subtitle: const Text(
                          'Send tickets directly to an ESC/POS printer by IP address. Turn off to return to the existing Windows printer queue.',
                        ),
                        value: printer.useNetworkPrinter,
                        onChanged: printer.setUseNetworkPrinter,
                      ),
                      _NetworkPrinterPanel(service: printer),
                      const Divider(color: AppColors.border),
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
                                            SnackBar(
                                              content: Text(
                                                printer.usesNetworkPrinter
                                                    ? 'Test receipt sent to network printer.'
                                                    : 'Test receipt sent to Windows print queue.',
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
                                ? (printer.usesNetworkPrinter ? 'NETWORK SET' : 'READY')
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

class _NetworkPrinterPanel extends StatefulWidget {
  const _NetworkPrinterPanel({required this.service});
  final PrinterService service;

  @override
  State<_NetworkPrinterPanel> createState() => _NetworkPrinterPanelState();
}

class _NetworkPrinterPanelState extends State<_NetworkPrinterPanel> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _saving = false;
  bool _editing = false;
  late String _loadedHost;
  late int _loadedPort;

  @override
  void initState() {
    super.initState();
    _loadedHost = widget.service.networkHost;
    _loadedPort = widget.service.networkPort;
    _hostController = TextEditingController(text: _loadedHost);
    _portController = TextEditingController(text: _loadedPort.toString());
  }

  @override
  void didUpdateWidget(covariant _NetworkPrinterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing &&
        (widget.service.networkHost != _loadedHost ||
            widget.service.networkPort != _loadedPort)) {
      _loadedHost = widget.service.networkHost;
      _loadedPort = widget.service.networkPort;
      _hostController.text = _loadedHost;
      _portController.text = _loadedPort.toString();
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid printer port.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.configureNetworkPrinter(
        host: _hostController.text,
        port: port,
      );
      _editing = false;
      _loadedHost = widget.service.networkHost;
      _loadedPort = widget.service.networkPort;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network printer saved and enabled. Use Test Print to verify it.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save network printer: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  onChanged: (_) => _editing = true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Printer IP address / host',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(Icons.wifi, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: _portController,
                  onChanged: (_) => _editing = true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '9100',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Find the printer IP in its network settings or router device list. The printer and PC must be on the same Wi-Fi/LAN. Port 9100 is the common RAW ESC/POS port; use the port shown by your printer if different. This direct mode requires ESC/POS support; unsupported regional-language characters may print as question marks.',
            style: TextStyle(color: AppColors.cream2, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 17),
              label: Text(_saving ? 'Saving...' : 'Save & Enable Wi-Fi Printer'),
            ),
          ),
        ],
      ),
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
