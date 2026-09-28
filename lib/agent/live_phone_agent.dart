import '../core/app_action_service.dart';
import 'agent_policy.dart';
import 'live_agent_result.dart';
import 'live_ui_observer.dart';
import 'models/ui_state.dart';
import 'tool_router.dart';

/// Device-side autonomous loop for the three user-approved tools.
/// Every interaction is visible in the foreground. It never injects hidden input.
class LivePhoneAgent {
 final AppActionService actions; late final LiveUiObserver observer=LiveUiObserver(actions);
 LivePhoneAgent(this.actions);
 Future<LiveAgentResult> run(String request,Map<String,String> allowedApps,{String? generatedText}) async {
  final trace=<String>[]; if(!actions.enabled)return const LiveAgentResult(false,'Apps خاموش است',[]);
  if(!await actions.accessibilityEnabled()){await actions.requestAccessibility();return const LiveAgentResult(false,'Accessibility را برای Atlas One فعال کنید',[]);}
  if(AgentPolicy.destructiveIntent(request)||AgentPolicy.sensitiveText(request))return const LiveAgentResult(false,'این درخواست به اقدام یا دادهٔ حساس مربوط است و خودکار اجرا نمی‌شود',[]);
  final q=request.toLowerCase();
  final google=ToolRouter.google(allowedApps), files=ToolRouter.files(allowedApps), notes=ToolRouter.notes(allowedApps);
  final image=_has(q,['عکس','تصویر','image','photo']); final write=_has(q,['note','notes','یادداشت','بنویس','paste','ثبت کن']); final research=_has(q,['google','search','جستجو','جست‌وجو','پیدا کن','مقاله','article'])||image;
  final showFile=_has(q,['نشان بده','نمایش بده','my file','my files','فایل','download','دانلود'])&& !write;
  if(research){if(google==null)return LiveAgentResult(false,'Google/Chrome در Apps مجاز نشده است',trace);final ok=await _googleSearch(google,_cleanQuery(request),image,trace);if(!ok)return LiveAgentResult(false,'جست‌وجوی زنده کامل نشد',trace);if(image&&_has(q,['دانلود','download'])){final d=await _tryVisibleImageDownload(trace);if(!d)return LiveAgentResult(false,'نتیجهٔ تصویر باز شد اما کنترل دانلود قابل‌اعتماد روی UI پیدا نشد',trace);}}
  if(write){if(notes==null)return LiveAgentResult(false,'Notes/Keep در Apps مجاز نشده است',trace);final ok=await _writeNote(notes,generatedText?.trim().isNotEmpty==true?generatedText!:request,trace);if(!ok)return LiveAgentResult(false,'نوشتن Note کامل نشد',trace);}
  if(showFile||image&&_has(q,['نشان بده','نمایش بده'])){if(files==null)return LiveAgentResult(false,'My Files/Files در Apps مجاز نشده است',trace);final ok=await _openDownloads(files,trace);if(!ok)return LiveAgentResult(false,'Downloads در My Files پیدا نشد',trace);}
  return LiveAgentResult(true,'کار زنده با ابزارها انجام شد',trace);
 }
 bool _has(String q,List<String> xs)=>xs.any(q.contains);
 String _cleanQuery(String q)=>q.replaceAll(RegExp(r'(?i)\bgoogle\b|جستجو|جست‌وجو|پیدا کن|برو|دانلود کن|نشان بده|نمایش بده|در اینترنت'),' ').replaceAll(RegExp(r'\s+'),' ').trim();
 Future<bool> _open(String package,List<String> expected,List<String> trace) async {if(!await actions.openSelectedApp(package))return false;trace.add('OPEN $package');await Future.delayed(const Duration(milliseconds:700));final s=await observer.settle();trace.add('OBSERVE ${s.packageName} nodes=${s.nodes.length}');return s.packageName.isNotEmpty||expected.any(s.contains);}
 Future<bool> _clickAny(List<String> labels,List<String> trace) async {var s=await observer.state();for(final label in labels){final n=s.findAny([label]);if(n?.viewId.isNotEmpty==true&&await actions.clickViewId(n!.viewId)){trace.add('CLICK_ID ${n.viewId}');await observer.settle();return true;}if(await actions.clickText(label)){trace.add('CLICK_TEXT $label');await observer.settle();return true;}}return false;}
 Future<bool> _type(String text,List<String> trace) async {var s=await observer.state();if(!s.hasEditable){await _clickAny(['Search','Search Google','جستجو','جست‌وجو','Take a note','یادداشت','Title','عنوان'],trace);s=await observer.state();}final ok=await actions.setText(text)||await actions.setFirstEditableText(text);if(ok){trace.add('TYPE ${text.length} chars');await Future.delayed(const Duration(milliseconds:180));}return ok;}
 Future<bool> _googleSearch(String package,String query,bool images,List<String> trace) async {if(!await _open(package,['google','search'],trace))return false;var s=await observer.state();if(!s.hasEditable)await _clickAny(['Search','Search Google','جستجو','جست‌وجو'],trace);if(!await _type(query,trace))return false;var submitted=await actions.pressEnter();if(!submitted)submitted=await _clickAny(['Search','Go','جستجو','جست‌وجو'],trace);if(!submitted)return false;trace.add('SUBMIT SEARCH');await Future.delayed(const Duration(milliseconds:900));s=await observer.settle();if(images){await _clickAny(['Images','تصاویر'],trace);await Future.delayed(const Duration(milliseconds:650));s=await observer.settle();}return s.nodes.isNotEmpty;}
 Future<bool> _tryVisibleImageDownload(List<String> trace) async {var s=await observer.state();UiNodeState? candidate; for(final n in s.nodes){if(n.clickable&&(n.desc.toLowerCase().contains('image')||n.text.toLowerCase().contains('image'))){candidate=n;break;}}if(candidate!=null){if(candidate.viewId.isNotEmpty)await actions.clickViewId(candidate.viewId);else if(candidate.text.isNotEmpty)await actions.clickText(candidate.text);await Future.delayed(const Duration(milliseconds:600));}
  if(await _clickAny(['Download image','Download','دانلود تصویر','بارگیری تصویر','Save image','ذخیره تصویر'],trace)){trace.add('DOWNLOAD_REQUEST');return true;}return false;}
 Future<bool> _openDownloads(String package,List<String> trace) async {if(!await _open(package,['files','my files','downloads','دانلود'],trace))return false;var s=await observer.state();if(s.contains('downloads')||s.contains('دانلود')){if(await _clickAny(['Downloads','Download','دانلودها','بارگیری‌ها'],trace))return true;return true;}if(await _clickAny(['Downloads','Download','دانلودها','بارگیری‌ها'],trace))return true;await actions.back();await Future.delayed(const Duration(milliseconds:300));return _clickAny(['Downloads','دانلودها'],trace);}
 Future<bool> _writeNote(String package,String text,List<String> trace) async {if(!await _open(package,['note','keep','یادداشت'],trace))return false;await _clickAny(['Take a note','New note','Create','Add','+','یادداشت جدید','ایجاد'],trace);if(!await _type(text,trace))return false;trace.add('VERIFY NOTE TEXT');return observer.waitFor((s)=>s.nodes.any((n)=>n.text.contains(text.substring(0,text.length>20?20:text.length))),attempts:5);}
}
