import '../core/app_action_service.dart';
import 'models/ui_state.dart';
class LiveUiObserver {
 final AppActionService actions; LiveUiObserver(this.actions);
 Future<UiState> state() async=>UiState.parse(await actions.observeUiStructured());
 Future<UiState> settle({int attempts=8,int delayMs=220}) async { var previous=''; UiState last=await state(); for(var i=0;i<attempts;i++){await Future.delayed(Duration(milliseconds:delayMs)); final n=await state(); if(n.raw==previous&&n.raw.isNotEmpty)return n; previous=n.raw; last=n;} return last; }
 Future<bool> waitFor(bool Function(UiState) predicate,{int attempts=12,int delayMs=250}) async {for(var i=0;i<attempts;i++){final s=await state();if(predicate(s))return true;await Future.delayed(Duration(milliseconds:delayMs));}return false;}
}
