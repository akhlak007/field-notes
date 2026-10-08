import 'dart:async';

class LocalChangeBus {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> close() => _controller.close();
}
