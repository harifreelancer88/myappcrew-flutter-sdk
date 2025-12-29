class MyAppCrewQueue {
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  int get length => _events.length;

  bool get isEmpty => _events.isEmpty;

  void add(Map<String, dynamic> event) {
    _events.add(event);
  }

  List<Map<String, dynamic>> snapshot(int maxCount) {
    if (_events.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final count = _events.length < maxCount ? _events.length : maxCount;
    return List<Map<String, dynamic>>.from(_events.take(count));
  }

  void removeFirst(int count) {
    if (count <= 0) {
      return;
    }
    if (count >= _events.length) {
      _events.clear();
      return;
    }
    _events.removeRange(0, count);
  }
}
