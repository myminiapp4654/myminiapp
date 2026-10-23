class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {}
  Future<void> playSfx(String name) async {}
  void toggle() => _enabled = !_enabled;
}
