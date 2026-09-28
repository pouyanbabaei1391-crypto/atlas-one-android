import '../../core/app_action_service.dart';
import '../agent_policy.dart';
import '../models/tool_result.dart';
import 'base_tool.dart';
class NotesTool extends BaseTool {
  NotesTool(AppActionService a):super(a);
  Future<ToolResult> createNote(String package,String text,{String? title}) async {
    if(AgentPolicy.sensitiveText(text)) return const ToolResult(false,'متن حساس خودکار وارد نمی‌شود');
    if(!await openPackage(package)) return const ToolResult(false,'Notes باز نشد');
    var created=await recovery.clickAlternatives(['Create','New note','Take a note','Add','+','یادداشت جدید','ایجاد']);
    if(created) await Future.delayed(const Duration(milliseconds:350));
    if(title!=null && title.trim().isNotEmpty) {
      if(await recovery.clickAlternatives(['Title','عنوان'])) { await actions.setText(title); await actions.pressTab(); }
    }
    final ok=await actions.setText(text);
    if(!ok) return ToolResult(false,'محل نوشتن پیدا نشد',observation:await observer.snapshot());
    await Future.delayed(const Duration(milliseconds:300));
    return ToolResult(true,'یادداشت نوشته شد',observation:await observer.snapshot());
  }
}
