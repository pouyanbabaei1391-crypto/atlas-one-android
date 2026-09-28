import '../../core/app_action_service.dart';
import '../models/tool_result.dart';
import 'base_tool.dart';
class MyFilesTool extends BaseTool {
  MyFilesTool(AppActionService a):super(a);
  Future<ToolResult> openDownloads(String package) async {
    if(!await openPackage(package)) return const ToolResult(false,'Files باز نشد');
    final ok=await recovery.clickAlternatives(['Downloads','Download','دانلودها','بارگیری‌ها']);
    if(!ok && !await observer.containsAny(['Downloads','دانلود'])) return ToolResult(false,'Downloads پیدا نشد',observation:await observer.snapshot());
    await Future.delayed(const Duration(milliseconds:500));
    return ToolResult(true,'Downloads باز شد',observation:await observer.snapshot());
  }
  Future<ToolResult> openNamed(String package,String name) async {
    final d=await openDownloads(package); if(!d.ok) return d;
    final ok=await actions.clickText(name); return ToolResult(ok,ok?'فایل باز شد':'فایل با نام موردنظر پیدا نشد',observation:await observer.snapshot());
  }
}
