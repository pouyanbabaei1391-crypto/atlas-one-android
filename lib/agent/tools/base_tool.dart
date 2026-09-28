import '../../core/app_action_service.dart';
import '../action_verifier.dart';
import '../recovery_engine.dart';
import '../ui_observer.dart';
abstract class BaseTool {
  final AppActionService actions; late final UiObserver observer=UiObserver(actions); late final ActionVerifier verifier=ActionVerifier(observer); late final RecoveryEngine recovery=RecoveryEngine(actions);
  BaseTool(this.actions);
  Future<bool> openPackage(String package) async { final ok=await actions.openSelectedApp(package); if(ok) await Future.delayed(const Duration(milliseconds:650)); return ok; }
}
