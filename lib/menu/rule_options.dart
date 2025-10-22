// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:mail_push_app/api/rule_list_client.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
// import 'package:mail_push_app/models/rule_model.dart' as rm;
// import 'package:mail_push_app/l10n/app_localizations.dart';

// /// ConditionType → 다국어 라벨
// extension ConditionTypeL10n on rm.ConditionType {
//   String localizedLabel(AppLocalizations t) {
//     switch (this) {
//       case rm.ConditionType.subjectContains:
//         return t.conditionTypeSubjectContains;
//       case rm.ConditionType.bodyContains:
//         return t.conditionTypeBodyContains;
//       case rm.ConditionType.fromSender:
//         return t.conditionTypeFromSender;
//     }
//   }
// }

// /// LogicType → 다국어 라벨
// extension LogicTypeL10n on rm.LogicType {
//   String localizedLabel(AppLocalizations t) {
//     switch (this) {
//       case rm.LogicType.and:
//         return t.logicAnd;
//       case rm.LogicType.or:
//         return t.logicOr;
//     }
//   }
// }

// /// 공통 카드
// class AppCard extends StatelessWidget {
//   final Widget child;
//   const AppCard({super.key, required this.child});
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: ec.eventLightCardColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: ec.eventLightBorderColor),
//         boxShadow: [
//           BoxShadow(
//             color: ec.eventLightShadowColor,
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }
// }

// /// ===== 알람 설정 모델(클라이언트 전용) =====
// class AlarmConfig {
//   String? sound; // 예: 'default', 'siren', ...
//   String? tts;   // 예: '긴급 메일이 도착했습니다'
//   AlarmConfig({this.sound, this.tts});

//   AlarmConfig copyWith({String? sound, String? tts}) =>
//       AlarmConfig(sound: sound ?? this.sound, tts: tts ?? this.tts);

//   bool get isEmpty => (sound == null || sound!.isEmpty) && (tts == null || tts!.isEmpty);
//   @override
//   String toString() => 'sound=$sound, tts=${tts ?? ""}';
// }

// /// 새 조건 컴포저 (재사용 위젯)
// typedef OnCreateCondition = void Function(rm.RuleCondition condition);

// class NewConditionComposer extends StatefulWidget {
//   const NewConditionComposer({
//     super.key,
//     required this.onCreate,
//     this.initialType = rm.ConditionType.subjectContains,
//     this.initialLogic = rm.LogicType.or,
//     this.enabled = true,
//   });

//   final OnCreateCondition onCreate;
//   final rm.ConditionType initialType;
//   final rm.LogicType initialLogic;
//   final bool enabled;

//   @override
//   State<NewConditionComposer> createState() => _NewConditionComposerState();
// }

// class _NewConditionComposerState extends State<NewConditionComposer> {
//   late rm.ConditionType _type;
//   late rm.LogicType _logic;
//   final TextEditingController _kwCtrl = TextEditingController();
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _type = widget.initialType;
//     _logic = widget.initialLogic;
//   }

//   @override
//   void dispose() {
//     _kwCtrl.dispose();
//     super.dispose();
//   }

//   bool get _hideLogic => _type == rm.ConditionType.fromSender;

//   List<String> _parseKeywords(String raw) {
//     final parts = raw
//         .split(RegExp(r'[,;\n]'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();
//     final set = <String>{};
//     for (final p in parts) set.add(p);
//     return set.toList();
//   }

//   void _commit({String? inline}) {
//     final t = AppLocalizations.of(context)!;
//     setState(() => _error = null);

//     final text = (inline ?? _kwCtrl.text).trim();
//     final keywords = _parseKeywords(text);
//     if (keywords.isEmpty) {
//       setState(() => _error = t.addAtLeastOneKeyword);
//       return;
//     }

//     final cond = rm.RuleCondition(
//       type: _type,
//       logic: _hideLogic ? rm.LogicType.or : _logic,
//       keywords: keywords,
//       position: 0,
//     );

//     widget.onCreate(cond);
//     _kwCtrl.clear();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final t = AppLocalizations.of(context)!;

//     return AbsorbPointer(
//       absorbing: !widget.enabled,
//       child: Opacity(
//         opacity: widget.enabled ? 1 : 0.6,
//         child: Container(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: ec.eventLightBorderColor),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 타입 선택
//               DropdownButtonHideUnderline(
//                 child: DropdownButton<rm.ConditionType>(
//                   value: _type,
//                   isExpanded: true,
//                   onChanged: (v) => setState(() => _type = v ?? _type),
//                   items: rm.ConditionType.values.map((e) {
//                     final label = switch (e) {
//                       rm.ConditionType.subjectContains => t.conditionTypeSubjectContains,
//                       rm.ConditionType.bodyContains    => t.conditionTypeBodyContains,
//                       rm.ConditionType.fromSender      => t.conditionTypeFromSender,
//                     };
//                     return DropdownMenuItem(value: e, child: Text(label));
//                   }).toList(),
//                 ),
//               ),
//               const SizedBox(height: 10),

//               // 로직 (보낸 사람일 때 숨김)
//               if (!_hideLogic)
//                 DropdownButtonHideUnderline(
//                   child: DropdownButton<rm.LogicType>(
//                     value: _logic,
//                     isExpanded: true,
//                     onChanged: (v) => setState(() => _logic = v ?? _logic),
//                     items: rm.LogicType.values.map((e) {
//                       final label = switch (e) {
//                         rm.LogicType.and => t.logicAnd,
//                         rm.LogicType.or  => t.logicOr,
//                       };
//                       return DropdownMenuItem(value: e, child: Text(label));
//                     }).toList(),
//                   ),
//                 ),
//               if (!_hideLogic) const SizedBox(height: 10),

//               // 키워드 입력 + 추가
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: _kwCtrl,
//                       decoration: InputDecoration(
//                         hintText: t.keywordHint,
//                         labelText: t.keywordAddLabel,
//                         isDense: true,
//                         errorText: _error,
//                         border: OutlineInputBorder(
//                           borderSide: BorderSide(color: ec.eventLightBorderColor),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: BorderSide(color: ec.eventPrimaryColor),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       onSubmitted: (v) => _commit(inline: v),
//                       textInputAction: TextInputAction.done,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   ElevatedButton(
//                     onPressed: _commit,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: ec.eventPrimaryColor,
//                       foregroundColor: Colors.white,
//                       elevation: 0,
//                     ),
//                     child: Text(t.add),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 (t.keywordInputHelper ?? '쉼표(,)·세미콜론(;)·줄바꿈으로 여러 개 입력할 수 있어요.'),
//                 style: const TextStyle(fontSize: 12, color: Colors.black54),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class RuleOptionsPage extends StatefulWidget {
//   final rm.MailRule? initialRule;
//   const RuleOptionsPage({Key? key, this.initialRule}) : super(key: key);

//   @override
//   State<RuleOptionsPage> createState() => _RuleOptionsPageState();
// }

// class _RuleOptionsPageState extends State<RuleOptionsPage> {
//   late final TextEditingController _nameController;
//   late List<rm.RuleCondition> _conditions;
//   String? _nameError;
//   final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
//   bool _saving = false;

//   // 규칙의 alarm 모드 (서버 저장 대상)
//   rm.AlarmLevel _alarm = rm.AlarmLevel.normal;

//   // 🔹 알람별 추가 설정(클라이언트 전용 보관; 서버 확장은 추후)
//   final Map<rm.AlarmLevel, AlarmConfig> _alarmConfigs = {
//     rm.AlarmLevel.critical: AlarmConfig(),
//     rm.AlarmLevel.until: AlarmConfig(),
//   };

//   /// ✅ 사운드 후보 + 'default' 포함 (중복 금지)
//   final List<String> _soundOptions = const [
//     'default', // ✅ 반드시 포함
//     'bugle', 'siren', 'cuckoo', 'gun', 'horn', 'melting', 'orchestra', 'right',
//   ];

//   bool get _isEditing => widget.initialRule != null;

//   @override
//   void initState() {
//     super.initState();

//     if (_isEditing) {
//       final clone = rm.MailRule.clone(widget.initialRule!);
//       _nameController = TextEditingController(text: clone.name);
//       _conditions = clone.conditions;
//       _alarm = clone.alarm;
//     } else {
//       _nameController = TextEditingController();
//       _conditions = [];
//       _alarm = rm.AlarmLevel.normal;
//     }
//   }

//   // ====== 기존 조건 편집 ======
//   void _addKeyword(int condIndex, String keyword) {
//     final w = keyword.trim();
//     if (w.isEmpty) return;
//     setState(() {
//       final list = _conditions[condIndex].keywords;
//       if (!list.contains(w)) list.add(w);
//     });
//   }

//   void _removeKeyword(int condIndex, int keywordIndex) {
//     setState(() {
//       _conditions[condIndex].keywords.removeAt(keywordIndex);
//     });
//   }

//   void _removeCondition(int condIndex) {
//     setState(() {
//       _conditions.removeAt(condIndex);
//     });
//   }

//   Future<bool> _sendRuleToServer(rm.MailRule rule) async {
//     try {
//       final api = RulesApi();
//       final fcm = await _secureStorage.read(key: 'fcm_token');

//       if (_isEditing && widget.initialRule!.id != null) {
//         rule.id = widget.initialRule!.id;
//         await api.updateRule(rule, fcmToken: fcm);
//       } else {
//         final newId = await api.createRule(rule, fcmToken: fcm);
//         rule.id = newId;
//       }
//       return true;
//     } catch (e) {
//       debugPrint("Rule save error: $e");
//       return false;
//     }
//   }

//   Map<String, dynamic> _buildAlarmExtrasForServer() {
//     Map<String, dynamic> levelToJson(rm.AlarmLevel lvl) {
//       final cfg = _alarmConfigs[lvl];
//       return {
//         "sound": (cfg?.sound?.isNotEmpty == true) ? cfg!.sound : null,
//         "tts": (cfg?.tts?.isNotEmpty == true) ? cfg!.tts : null,
//       };
//     }

//     return {
//       "alarm_config": {
//         "critical": levelToJson(rm.AlarmLevel.critical),
//         "until": levelToJson(rm.AlarmLevel.until),
//       }
//     };
//   }

//   void _saveRule() async {
//     final t = AppLocalizations.of(context)!;
//     final name = _nameController.text.trim();

//     if (name.isEmpty) {
//       setState(() => _nameError = t.ruleNameRequired);
//       return;
//     }
//     if (_conditions.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(t.needAtLeastOneCondition)),
//       );
//       return;
//     }
//     for (var cond in _conditions) {
//       if (cond.keywords.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(t.needKeywordsInAllConditions)),
//         );
//         return;
//       }
//     }

//     // (선택) Critical/Until일 때 사운드/tts 중 하나 입력하도록 강제하려면 아래 주석 해제
//     // if (_alarm == rm.AlarmLevel.critical || _alarm == rm.AlarmLevel.until) {
//     //   final cfg = _alarmConfigs[_alarm];
//     //   if (cfg == null || cfg.isEmpty) {
//     //     ScaffoldMessenger.of(context).showSnackBar(
//     //       SnackBar(content: Text(t.enterSoundOrTts ?? '사운드 또는 TTS 메시지를 하나 이상 설정해 주세요.')),
//     //     );
//     //     return;
//     //   }
//     // }

//     // position 정렬
//     for (int i = 0; i < _conditions.length; i++) {
//       _conditions[i].position = i;
//     }

//     setState(() => _saving = true);

//     final rm.MailRule result = rm.MailRule(
//       name: name,
//       conditions: _conditions,
//       enabled: true,
//       alarm: _alarm,
//       id: widget.initialRule?.id,
//     );

//     final success = await _sendRuleToServer(result);
//     if (!mounted) return;
//     setState(() => _saving = false);

//     if (!success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(t.ruleSaveFailed)),
//       );
//       return;
//     }

//     Navigator.of(context).pop(result);
//   }

//   /// 사운드 키 → 라벨 (다국어, 없으면 안전한 fallback)
//   String _soundLabel(AppLocalizations t, String key) {
//     switch (key) {
//       case 'default':    return t.soundDefault ?? 'Default';
//       case 'bugle':      return t.soundBugle ?? 'Bugle';
//       case 'siren':      return t.soundSiren ?? 'Siren';
//       case 'cuckoo':     return t.soundCuckoo ?? 'Cuckoo';
//       case 'gun':        return t.soundGun ?? 'Gun';
//       case 'horn':       return t.soundHorn ?? 'Horn';
//       case 'melting':    return t.soundMelting ?? 'Melting';
//       case 'orchestra':  return t.soundOrchestra ?? 'Orchestra';
//       case 'right':      return t.soundRight ?? 'Right';
//       default:           return key; // 정의 안 된 키는 그대로
//     }
//   }

//   /// ===== 알람 설정 다이얼로그 =====
//   Future<bool> _openAlarmConfigDialog(rm.AlarmLevel level) async {
//     final t = AppLocalizations.of(context)!;
//     final existing = _alarmConfigs[level] ?? AlarmConfig();

//     // ✅ 항상 사운드 값은 리스트에 있는 값으로 초기화 (없으면 'default')
//     final initSound = _soundOptions.contains(existing.sound) ? existing.sound : 'default';
//     final sound = ValueNotifier<String?>(initSound);
//     final ttsCtrl = TextEditingController(text: existing.tts ?? '');

//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (ctx) {
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           title: Text(
//             level == rm.AlarmLevel.critical ? t.ringOnce : t.ringUntilStopped,
//             style: const TextStyle(fontWeight: FontWeight.w700),
//           ),
//           // ✅ overflow 방지
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // 사운드 선택
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     t.soundLabel ?? '사운드',
//                     style: const TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 ValueListenableBuilder<String?>(
//                   valueListenable: sound,
//                   builder: (_, value, __) {
//                     return DropdownButtonFormField<String>(
//                       // ✅ value는 items 중 하나여야 함
//                       value: (value != null && _soundOptions.contains(value))
//                           ? value
//                           : 'default',
//                       isExpanded: true,
//                       items: _soundOptions
//                           .map((s) => DropdownMenuItem(
//                                 value: s,
//                                 child: Text(_soundLabel(t, s)),
//                               ))
//                           .toList(),
//                       onChanged: (v) => sound.value = v,
//                       decoration: InputDecoration(
//                         isDense: true,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: ec.eventLightBorderColor),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: ec.eventPrimaryColor),
//                         ),
//                         hintText: t.selectSoundHint ?? '사운드를 선택하세요',
//                       ),
//                     );
//                   },
//                 ),
//                 const SizedBox(height: 14),

//                 // TTS 입력
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     t.ttsMessageLabel ?? 'TTS 메시지',
//                     style: const TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 TextField(
//                   controller: ttsCtrl,
//                   maxLines: 2,
//                   decoration: InputDecoration(
//                     isDense: true,
//                     hintText: t.ttsMessageHint ?? '예: 긴급 메일이 도착했습니다',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide(color: ec.eventLightBorderColor),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide(color: ec.eventPrimaryColor),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(false),
//               child: Text(t.cancel),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: ec.eventPrimaryColor,
//                 foregroundColor: Colors.white,
//                 elevation: 0,
//               ),
//               onPressed: () => Navigator.of(ctx).pop(true),
//               child: Text(t.save),
//             ),
//           ],
//         );
//       },
//     );

//     if (ok == true) {
//       _alarmConfigs[level] = AlarmConfig(sound: sound.value, tts: ttsCtrl.text.trim());
//       return true;
//     }
//     return false;
//   }

//   // 규칙의 알람 레벨 선택(전역 스위치와 독립)
//   Widget _buildAlarmButtons() {
//     final t = AppLocalizations.of(context)!;

//     Widget colorButton({
//       required Color color,
//       required bool selected,
//       required String label,
//       required VoidCallback onTap,
//     }) {
//       final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
//       const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
//       const Size minSize = Size(0, 28);
//       final visual = VisualDensity.compact;

//       if (selected) {
//         return ElevatedButton(
//           onPressed: onTap,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: color,
//             foregroundColor: Colors.white,
//             elevation: 0,
//             shape: shape,
//             padding: padding,
//             minimumSize: minSize,
//             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             visualDensity: visual,
//           ),
//           child: Text(
//             label,
//             overflow: TextOverflow.visible,
//             softWrap: false,
//             style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
//           ),
//         );
//       } else {
//         return OutlinedButton(
//           onPressed: onTap,
//           style: OutlinedButton.styleFrom(
//             foregroundColor: color,
//             side: BorderSide(color: ec.eventLightBorderColor),
//             backgroundColor: Colors.white,
//             shape: shape,
//             padding: EdgeInsets.zero,
//             minimumSize: minSize,
//             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             visualDensity: visual,
//           ),
//           child: Container(
//             padding: padding,
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.10),
//               borderRadius: BorderRadius.circular(7),
//             ),
//             child: Text(
//               label,
//               overflow: TextOverflow.visible,
//               softWrap: false,
//               style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: color),
//             ),
//           ),
//         );
//       }
//     }

//     Widget _miniChip(IconData icon, String text) {
//       return Chip(
//         label: Text(
//           text,
//           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
//           overflow: TextOverflow.ellipsis,
//         ),
//         avatar: Icon(icon, size: 14),
//         backgroundColor: Colors.white,
//         side: BorderSide(color: ec.eventLightBorderColor),
//         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//         visualDensity: VisualDensity.compact,
//       );
//     }

//     Widget _wrapChipColor(Widget chip, Color color) {
//       return DecoratedBox(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(0.08),
//               blurRadius: 6,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: chip,
//       );
//     }

//     // 선택 요약칩(사운드/메시지)
//     Widget configChips(rm.AlarmLevel lvl) {
//       final cfg = _alarmConfigs[lvl];
//       if (cfg == null || cfg.isEmpty) return const SizedBox.shrink();

//       final List<Widget> chips = [];
//       if ((cfg.sound?.isNotEmpty ?? false) && cfg!.sound != 'none') {
//         chips.add(_miniChip(Icons.music_note, _soundLabel(t, cfg.sound!)));
//       }
//       if ((cfg.tts?.isNotEmpty ?? false)) {
//         chips.add(_miniChip(Icons.record_voice_over, cfg!.tts!));
//       }
//       if (chips.isEmpty) return const SizedBox.shrink();

//       final color = (lvl == rm.AlarmLevel.critical)
//           ? Colors.orange
//           : (lvl == rm.AlarmLevel.until ? Colors.red : Colors.green);

//       return Padding(
//         padding: const EdgeInsets.only(top: 6),
//         child: Wrap(
//           spacing: 6,
//           runSpacing: 6,
//           children: chips.map((c) => _wrapChipColor(c, color)).toList(),
//         ),
//       );
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(right: 12, top: 4),
//               child: Text(
//                 t.alarmSettingsTitle,
//                 style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                       color: ec.eventLightPrimaryTextColor,
//                       fontWeight: FontWeight.w700,
//                     ),
//               ),
//             ),
//             Flexible(
//               child: Wrap(
//                 spacing: 8,
//                 runSpacing: 6,
//                 children: [
//                   // 일반
//                   colorButton(
//                     color: Colors.green,
//                     selected: _alarm == rm.AlarmLevel.normal,
//                     label: t.generalAlarmLabel,
//                     onTap: () => setState(() => _alarm = rm.AlarmLevel.normal),
//                   ),
//                   // 1회 울림 → 다이얼로그
//                   colorButton(
//                     color: Colors.orange,
//                     selected: _alarm == rm.AlarmLevel.critical,
//                     label: t.ringOnce,
//                     onTap: () async {
//                       final ok = await _openAlarmConfigDialog(rm.AlarmLevel.critical);
//                       if (ok) setState(() => _alarm = rm.AlarmLevel.critical);
//                     },
//                   ),
//                   // 멈출 때까지 → 다이얼로그
//                   colorButton(
//                     color: Colors.red,
//                     selected: _alarm == rm.AlarmLevel.until,
//                     label: t.ringUntilStopped,
//                     onTap: () async {
//                       final ok = await _openAlarmConfigDialog(rm.AlarmLevel.until);
//                       if (ok) setState(() => _alarm = rm.AlarmLevel.until);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         // 선택 요약칩 노출
//         if (_alarmConfigs[rm.AlarmLevel.critical]?.isEmpty == false)
//           configChips(rm.AlarmLevel.critical),
//         if (_alarmConfigs[rm.AlarmLevel.until]?.isEmpty == false)
//           configChips(rm.AlarmLevel.until),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     super.dispose();
//   }

//   // ====== 기존 조건 카드 ======
//   Widget _buildConditionCard(int idx) {
//     final t = AppLocalizations.of(context)!;
//     final cond = _conditions[idx];
//     final keywordController = TextEditingController();
//     final hideLogic = cond.type == rm.ConditionType.fromSender;

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: ec.eventLightCardColor,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: ec.eventLightBorderColor),
//         boxShadow: [
//           BoxShadow(
//             color: ec.eventLightShadowColor,
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 타입 + 삭제
//           Row(
//             children: [
//               Expanded(
//                 child: DropdownButtonHideUnderline(
//                   child: DropdownButton<rm.ConditionType>(
//                     value: cond.type,
//                     isExpanded: true,
//                     iconEnabledColor: ec.eventLightPrimaryTextColor,
//                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                           color: ec.eventLightPrimaryTextColor,
//                         ),
//                     onChanged: (v) {
//                       if (v == null) return;
//                       setState(() => cond.type = v);
//                     },
//                     items: rm.ConditionType.values
//                         .map((ctype) => DropdownMenuItem(
//                               value: ctype,
//                               child: Text(ctype.localizedLabel(t)),
//                             ))
//                         .toList(),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               IconButton(
//                 onPressed: () => _removeCondition(idx),
//                 icon: const Icon(Icons.close),
//                 color: ec.eventLightUnselectedItemColor,
//                 tooltip: t.deleteCondition,
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),

//           // 키워드 로직 선택 (보낸 사람일 때 숨김)
//           if (!hideLogic)
//             Row(
//               children: [
//                 Text(
//                   t.keywordLogicLabel,
//                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                         color: ec.eventLightPrimaryTextColor,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: DropdownButtonHideUnderline(
//                     child: DropdownButton<rm.LogicType>(
//                       value: cond.logic,
//                       isExpanded: true,
//                       iconEnabledColor: ec.eventLightPrimaryTextColor,
//                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                             color: ec.eventLightPrimaryTextColor,
//                           ),
//                       onChanged: (v) {
//                         if (v == null) return;
//                         setState(() => cond.logic = v);
//                       },
//                       items: rm.LogicType.values
//                           .map((ltype) => DropdownMenuItem(
//                                 value: ltype,
//                                 child: Text(ltype.localizedLabel(t)),
//                               ))
//                           .toList(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           if (!hideLogic) const SizedBox(height: 10),

//           // 키워드 입력 + 추가
//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: keywordController,
//                   decoration: InputDecoration(
//                     hintText: t.keywordHint,
//                     labelText: t.keywordAddLabel,
//                     isDense: true,
//                     border: OutlineInputBorder(
//                       borderSide: BorderSide(color: ec.eventLightBorderColor),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderSide: BorderSide(color: ec.eventLightBorderColor),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderSide: BorderSide(color: ec.eventPrimaryColor),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onSubmitted: (v) {
//                     _addKeyword(idx, v);
//                     keywordController.clear();
//                   },
//                 ),
//               ),
//               const SizedBox(width: 8),
//               ElevatedButton(
//                 onPressed: () {
//                   _addKeyword(idx, keywordController.text);
//                   keywordController.clear();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: ec.eventPrimaryColor,
//                   foregroundColor: Colors.white,
//                   elevation: 0,
//                 ),
//                 child: Text(t.add),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),

//           // 키워드 칩
//           Wrap(
//             spacing: 6,
//             runSpacing: 6,
//             children: List.generate(cond.keywords.length, (kIdx) {
//               final kw = cond.keywords[kIdx];
//               return InputChip(
//                 label: Text(kw),
//                 onDeleted: () => _removeKeyword(idx, kIdx),
//                 backgroundColor: Colors.white,
//                 side: BorderSide(color: ec.eventLightBorderColor),
//               );
//             }),
//           ),

//           if (cond.keywords.isEmpty)
//             Padding(
//               padding: const EdgeInsets.only(top: 6),
//               child: Text(
//                 t.addAtLeastOneKeyword,
//                 style: TextStyle(color: Colors.red.shade700, fontSize: 12),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final t = AppLocalizations.of(context)!;

//     return Scaffold(
//       backgroundColor: ec.eventLightBackgroundColor,
//       appBar: AppBar(
//         title: Text(_isEditing ? t.ruleEditTitle : t.ruleCreateTitle),
//         backgroundColor: ec.eventLightCardColor,
//         elevation: 0,
//         foregroundColor: Colors.black,
//         actions: [
//           TextButton(
//             onPressed: _saving ? null : _saveRule,
//             child: Text(
//               _saving ? t.savingEllipsis : t.save,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//         ],
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 720),
//             child: AppCard(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       // 제목
//                       TextField(
//                         controller: _nameController,
//                         decoration: InputDecoration(
//                           labelText: t.ruleNameLabel,
//                           border: OutlineInputBorder(
//                             borderSide: BorderSide(color: ec.eventLightBorderColor),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: ec.eventPrimaryColor),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           errorText: _nameError,
//                         ),
//                         onChanged: (_) {
//                           if (_nameError != null && _nameController.text.trim().isNotEmpty) {
//                             setState(() => _nameError = null);
//                           }
//                         },
//                       ),
//                       const SizedBox(height: 16),

//                       // 조건 섹션
//                       Text(
//                         t.conditions,
//                         style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                               color: ec.eventLightPrimaryTextColor,
//                               fontWeight: FontWeight.w700,
//                             ),
//                       ),
//                       const SizedBox(height: 8),

//                       // (생성 모드) 새 조건 컴포저
//                       if (!_isEditing) ...[
//                         NewConditionComposer(
//                           onCreate: (cond) {
//                             setState(() {
//                               cond.position = _conditions.length;
//                               _conditions.add(cond);
//                             });
//                           },
//                         ),
//                         const SizedBox(height: 10),
//                       ],

//                       // 기존 조건 리스트
//                       ...List.generate(_conditions.length, (i) => _buildConditionCard(i)),

//                       const SizedBox(height: 12),

//                       // 규칙 알람 레벨 + 요약칩
//                       _buildAlarmButtons(),

//                       const SizedBox(height: 20),

//                       // 액션
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           TextButton(
//                             onPressed: _saving ? null : () => Navigator.of(context).pop(),
//                             child: Text(t.cancel),
//                           ),
//                           const SizedBox(width: 12),
//                           ElevatedButton(
//                             onPressed: _saving ? null : _saveRule,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: ec.eventPrimaryColor,
//                               foregroundColor: Colors.white,
//                               elevation: 0,
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//                               child: Text(_saving ? t.savingEllipsis : t.save),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
