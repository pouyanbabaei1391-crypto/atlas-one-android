import 'ui_observer.dart';
class ActionVerifier {
  final UiObserver observer;
  ActionVerifier(this.observer);
  Future<bool> changed(String before) async { await Future.delayed(const Duration(milliseconds:350)); return (await observer.snapshot()) != before; }
  Future<bool> visible(List<String> markers) => observer.containsAny(markers);
}
