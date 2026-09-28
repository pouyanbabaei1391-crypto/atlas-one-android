enum LiveActionType { openApp, openUri, clickText, clickViewId, typeText, scroll, back, home, wait }
class LiveAction { final LiveActionType type; final String? value; final int direction; final String reason; const LiveAction(this.type,{this.value,this.direction=1,this.reason='' }); }
