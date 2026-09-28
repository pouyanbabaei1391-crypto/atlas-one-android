import '../core/app_action_service.dart';
import 'agent_policy.dart';
import 'task_planner.dart';
import 'tool_router.dart';
import 'tools/google_tool.dart';
import 'tools/my_files_tool.dart';
import 'tools/notes_tool.dart';
class ExecutionEngine {
  final AppActionService actions; late final GoogleTool google=GoogleTool(actions); late final MyFilesTool files=MyFilesTool(actions); late final NotesTool notes=NotesTool(actions); final planner=TaskPlanner();
  ExecutionEngine(this.actions);
  Future<List<String>> run(String request,Map<String,String> allowedApps,{String? noteText}) async {
    final p=planner.classify(request); final log=<String>[];
    if(p['intent']=='confirm') return ['⛔ این کار حساس است و به تأیید مستقیم نیاز دارد.'];
    final gp=ToolRouter.google(allowedApps), fp=ToolRouter.files(allowedApps), np=ToolRouter.notes(allowedApps);
    if(p['search']==true) { if(gp==null) return ['⚠️ Google/Chrome در Apps مجاز نیست.']; final r=p['image']==true?await google.imageSearch(gp,request):await google.searchWeb(gp,request); log.add(r.ok?'✓ Google: ${r.message}':'⚠️ Google: ${r.message}'); if(!r.ok)return log; }
    if(p['write']==true) { if(np==null)return [...log,'⚠️ Notes/Keep در Apps مجاز نیست.']; final r=await notes.createNote(np,noteText??request); log.add(r.ok?'✓ Notes: ${r.message}':'⚠️ Notes: ${r.message}'); }
    if(p['file']==true && p['write']!=true) { if(fp==null)return [...log,'⚠️ My Files/Files در Apps مجاز نیست.']; final r=await files.openDownloads(fp); log.add(r.ok?'✓ My Files: ${r.message}':'⚠️ My Files: ${r.message}'); }
    return log;
  }
}
