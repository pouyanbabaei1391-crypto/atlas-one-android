import 'dart:convert';
class UiNodeState {
  final int index; final String text,desc,viewId,klass,bounds; final bool clickable,editable,scrollable,enabled,focused;
  const UiNodeState({required this.index,required this.text,required this.desc,required this.viewId,required this.klass,required this.bounds,required this.clickable,required this.editable,required this.scrollable,required this.enabled,required this.focused});
  factory UiNodeState.fromMap(Map<String,dynamic> m)=>UiNodeState(index:(m['i'] as num?)?.toInt()??-1,text:'${m['text']??''}',desc:'${m['desc']??''}',viewId:'${m['viewId']??''}',klass:'${m['class']??''}',bounds:'${m['bounds']??''}',clickable:m['clickable']==true,editable:m['editable']==true,scrollable:m['scrollable']==true,enabled:m['enabled']!=false,focused:m['focused']==true);
  String get searchable=>'$text $desc $viewId'.toLowerCase();
}
class UiState {
  final String packageName,windowClass,raw; final List<UiNodeState> nodes;
  const UiState(this.packageName,this.windowClass,this.nodes,this.raw);
  factory UiState.parse(String raw){ try{ final m=jsonDecode(raw) as Map<String,dynamic>; final ns=(m['nodes'] as List? ?? const []).whereType<Map>().map((e)=>UiNodeState.fromMap(Map<String,dynamic>.from(e))).toList(); return UiState('${m['package']??''}','${m['windowClass']??''}',ns,raw);}catch(_){return UiState('','',const [],raw);} }
  bool contains(String s){final q=s.toLowerCase();return nodes.any((n)=>n.searchable.contains(q));}
  UiNodeState? findAny(Iterable<String> terms,{bool clickable=false,bool editable=false}){for(final t in terms){final q=t.toLowerCase();for(final n in nodes){if((!clickable||n.clickable)&&(!editable||n.editable)&&n.searchable.contains(q))return n;}}return null;}
  bool get hasEditable=>nodes.any((n)=>n.editable&&n.enabled);
}
