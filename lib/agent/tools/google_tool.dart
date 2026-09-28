import '../../core/app_action_service.dart';
import '../models/tool_result.dart';
import 'base_tool.dart';
class GoogleTool extends BaseTool {
  GoogleTool(AppActionService a):super(a);
  Future<ToolResult> searchWeb(String package,String query) async {
    if(!await openPackage(package)) return const ToolResult(false,'Google باز نشد');
    final before=await observer.snapshot();
    var clicked=await recovery.clickAlternatives(['Search','Search Google','جستجو','جست‌وجو']);
    if(clicked) await Future.delayed(const Duration(milliseconds:250));
    final typed=await actions.setText(query);
    if(!typed) return ToolResult(false,'فیلد جستجو پیدا نشد',observation:before);
    final submitted=await actions.pressEnter();
    if(!submitted) await recovery.clickAlternatives(['Search','Go','جستجو','جست‌وجو']);
    await Future.delayed(const Duration(milliseconds:900));
    return ToolResult(true,'جستجو اجرا شد',observation:await observer.snapshot());
  }
  Future<ToolResult> imageSearch(String package,String query) async {
    final r=await searchWeb(package,'$query images'); if(!r.ok) return r;
    await recovery.clickAlternatives(['Images','تصاویر']); await Future.delayed(const Duration(milliseconds:700));
    return ToolResult(true,'نتایج تصویر باز شد',observation:await observer.snapshot());
  }
  String googleSearchUri(String q)=>'https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}';
}
