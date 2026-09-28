import '../core/app_action_service.dart';
class RecoveryEngine {
  final AppActionService actions;
  RecoveryEngine(this.actions);
  Future<bool> clickAlternatives(List<String> labels) async { for(final l in labels) { if(await actions.clickText(l)) return true; } return false; }
  Future<void> backAndWait() async { await actions.back(); await Future.delayed(const Duration(milliseconds:450)); }
}
