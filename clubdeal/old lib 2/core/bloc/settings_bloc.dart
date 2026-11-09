import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/alert_sound_service.dart';

class SettingsState {
  final bool usingDefaultSound;
  final String? customSoundPath;
  final bool soundsEnabled;

  const SettingsState({
    this.usingDefaultSound = true,
    this.customSoundPath,
    this.soundsEnabled = true,
  });
}

abstract class SettingsEvent {
  const SettingsEvent();
}

class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

class CustomSoundSelected extends SettingsEvent {
  final String path;
  const CustomSoundSelected(this.path);
}

class DefaultSoundRestored extends SettingsEvent {
  const DefaultSoundRestored();
}

class SoundPreviewRequested extends SettingsEvent {
  const SoundPreviewRequested();
}

class SoundsToggled extends SettingsEvent {
  final bool enabled;
  const SoundsToggled(this.enabled);
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final AlertSoundService service;

  SettingsBloc(this.service) : super(const SettingsState()) {
    on<SettingsStarted>(_load);
    on<CustomSoundSelected>(_select);
    on<DefaultSoundRestored>(_restore);
    on<SoundPreviewRequested>((event, emit) => service.playPreview());
    on<SoundsToggled>((event, emit) {
      service.setEnabled(event.enabled);
      emit(SettingsState(
        usingDefaultSound: state.usingDefaultSound,
        customSoundPath: state.customSoundPath,
        soundsEnabled: event.enabled,
      ));
    });
  }

  Future<void> _load(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    final path = await service.customSound();
    emit(SettingsState(
      usingDefaultSound: path == null,
      customSoundPath: path,
      soundsEnabled: service.enabled,
    ));
  }

  Future<void> _select(
    CustomSoundSelected event,
    Emitter<SettingsState> emit,
  ) async {
    await service.saveCustomSound(event.path);
    emit(SettingsState(
      usingDefaultSound: false,
      customSoundPath: event.path,
      soundsEnabled: state.soundsEnabled,
    ));
  }

  Future<void> _restore(
    DefaultSoundRestored event,
    Emitter<SettingsState> emit,
  ) async {
    await service.reset();
    emit(SettingsState(
      usingDefaultSound: true,
      soundsEnabled: state.soundsEnabled,
    ));
  }
}
