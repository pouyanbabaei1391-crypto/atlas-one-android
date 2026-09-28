import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_one_mobile_ai/agent/models/ui_state.dart';
void main(){test('structured UI state parses interactive nodes',(){final s=UiState.parse('{"package":"com.test","nodes":[{"i":1,"text":"Search","desc":"","viewId":"q","class":"EditText","bounds":"0,0,1,1","clickable":true,"editable":true,"scrollable":false,"enabled":true,"focused":false}]}');expect(s.packageName,'com.test');expect(s.hasEditable,true);expect(s.contains('Search'),true);});}
