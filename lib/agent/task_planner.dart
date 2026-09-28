import 'agent_policy.dart';
class TaskPlanner {
  Map<String,dynamic> classify(String request) {
    final q=request.toLowerCase();
    if(AgentPolicy.destructiveIntent(q)) return {'intent':'confirm','reason':'sensitive'};
    final wantsImage=['عکس','تصویر','image','photo'].any(q.contains);
    final wantsWrite=['note','notes','یادداشت','بنویس','paste','ذخیره متن'].any(q.contains);
    final wantsFile=['file','فایل','دانلود','download','نشان بده','باز کن'].any(q.contains);
    final wantsSearch=['google','search','جستجو','جست‌وجو','پیدا کن','مقاله','article'].any(q.contains);
    return {'intent':'tools','search':wantsSearch||wantsImage,'image':wantsImage,'write':wantsWrite,'file':wantsFile};
  }
}
