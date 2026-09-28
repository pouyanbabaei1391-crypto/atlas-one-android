class ToolRouter {
  static String? findPackage(Map<String,String> apps,List<String> hints) {
    for(final e in apps.entries) { final s='${e.key} ${e.value}'.toLowerCase(); if(hints.any((h)=>s.contains(h))) return e.key; }
    return null;
  }
  static String? google(Map<String,String> a)=>findPackage(a,['google','chrome']);
  static String? files(Map<String,String> a)=>findPackage(a,['my files','files','file manager','documentsui','sec.android.app.myfiles']);
  static String? notes(Map<String,String> a)=>findPackage(a,['notes','keep','memo']);
}
