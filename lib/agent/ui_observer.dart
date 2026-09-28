import '../core/app_action_service.dart';
class UiObserver {
  final AppActionService actions;
  UiObserver(this.actions);
  Future<String> snapshot() => actions.observeUi();
  Future<bool> containsAny(List<String> terms) async {
    final s=(await snapshot()).toLowerCase();
    return terms.any((e)=>s.contains(e.toLowerCase()));
  }
  Future<bool> waitFor(List<String> terms,{int attempts=5}) async {
    for(var i=0;i<attempts;i++) { if(await containsAny(terms)) return true; await Future.delayed(const Duration(milliseconds:450)); }
    return false;
  }
}
