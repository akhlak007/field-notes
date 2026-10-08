import 'dart:async';

class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void notifyExpired() {
    if (!_expired.isClosed) _expired.add(null);
  }

  Future<void> close() => _expired.close();
}
