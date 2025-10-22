// lib/menu/rule_options/rule_options_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

import 'models/alarm_config.dart';
import 'widgets/new_condition_composer.dart';
import 'widgets/condition_card.dart';
import 'widgets/alarm_selector.dart';

class RuleOptionsPage extends StatefulWidget {
  final rm.MailRule? initialRule;
  const RuleOptionsPage({Key? key, this.initialRule}) : super(key: key);

  @override
  State<RuleOptionsPage> createState() => _RuleOptionsPageState();
}

class _RuleOptionsPageState extends State<RuleOptionsPage> {
  late final TextEditingController _nameController;
  late List<rm.RuleCondition> _conditions;
  String? _nameError;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _saving = false;

  rm.AlarmLevel _alarm = rm.AlarmLevel.normal;

  // 알람 상세 설정(사운드/tts). normal은 설정 불필요.
  final Map<rm.AlarmLevel, AlarmConfig> _alarmConfigs = {
    rm.AlarmLevel.critical: AlarmConfig(sound: 'default'),
    rm.AlarmLevel.until:   AlarmConfig(sound: 'default'),
  };

  bool get _isEditing => widget.initialRule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final clone = rm.MailRule.clone(widget.initialRule!);
      _nameController = TextEditingController(text: clone.name);
      _conditions = clone.conditions;
      _alarm = clone.alarm;

      // 서버에서 sound/tts를 내려주고 모델이 보유한다면 초기화
      if (clone.sound != null || clone.tts != null) {
        final cfgLevel = (clone.alarm == rm.AlarmLevel.critical || clone.alarm == rm.AlarmLevel.until)
            ? clone.alarm
            : rm.AlarmLevel.critical; // 안전 기본값
        _alarmConfigs[cfgLevel] = AlarmConfig(
          sound: clone.sound,
          tts: clone.tts,
        );
      }
    } else {
      _nameController = TextEditingController();
      _conditions = [];
      _alarm = rm.AlarmLevel.normal;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<bool> _sendRuleToServer(rm.MailRule rule) async {
    try {
      final api = RulesApi();
      final fcm = await _secureStorage.read(key: 'fcm_token');
      if (_isEditing && widget.initialRule!.id != null) {
        rule.id = widget.initialRule!.id;
        await api.updateRule(rule, fcmToken: fcm);
      } else {
        final newId = await api.createRule(rule, fcmToken: fcm);
        rule.id = newId;
      }
      return true;
    } catch (e) {
      debugPrint("Rule save error: $e");
      return false;
    }
  }

  void _saveRule() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = '규칙 이름을 입력하세요.');
      return;
    }
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조건을 최소 1개 이상 추가하세요.')),
      );
      return;
    }
    for (var cond in _conditions) {
      if (cond.keywords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 조건에 키워드를 1개 이상 입력하세요.')),
        );
        return;
      }
    }

    // critical / until 은 최소 하나의 사운드 또는 TTS가 필요
    String? sound;
    String? tts;
    if (_alarm == rm.AlarmLevel.critical || _alarm == rm.AlarmLevel.until) {
      final cfg = _alarmConfigs[_alarm];
      if (cfg == null || cfg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사운드 또는 TTS를 설정하세요.')),
        );
        return;
      }
      sound = cfg.sound?.trim().isEmpty == true ? null : cfg.sound?.trim();
      tts   = cfg.tts?.trim().isEmpty   == true ? null : cfg.tts?.trim();
    }

    // position 정렬 보장
    for (int i = 0; i < _conditions.length; i++) {
      _conditions[i].position = i;
    }

    setState(() => _saving = true);

    // 모델에 sound/tts 필드가 있다고 가정 (없다면 rm.MailRule에 필드 추가 필요)
    final rm.MailRule result = rm.MailRule(
      name: name,
      conditions: _conditions,
      enabled: true,
      alarm: _alarm,
      id: widget.initialRule?.id,
      sound: sound ?? '', // ✅ 알람 상세 설정 반영
      tts: tts,           // ✅ 알람 상세 설정 반영
    );

    final success = await _sendRuleToServer(result);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했습니다.')),
      );
      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? '규칙 수정' : '규칙 만들기'),
        backgroundColor: ec.eventLightCardColor,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveRule,
            child: Text(
              _saving ? '저장 중...' : '저장',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              decoration: BoxDecoration(
                color: ec.eventLightCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ec.eventLightBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: ec.eventLightShadowColor,
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 이름
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '규칙 이름',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ec.eventLightBorderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ec.eventPrimaryColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: _nameError,
                        ),
                        onChanged: (_) {
                          if (_nameError != null && _nameController.text.trim().isNotEmpty) {
                            setState(() => _nameError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('조건', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),

                      // ✅ 생성/수정 모두에서 조건 추가 가능
                      NewConditionComposer(
                        onCreate: (cond) {
                          setState(() {
                            cond.position = _conditions.length;
                            _conditions.add(cond);
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // 기존 조건 리스트
                      ...List.generate(_conditions.length, (i) {
                        return ConditionCard(
                          condition: _conditions[i],
                          onRemove: () => setState(() => _conditions.removeAt(i)),
                          onChanged: (c) => setState(() => _conditions[i] = c),
                        );
                      }),

                      const SizedBox(height: 12),

                      // 알람 선택 + 상세 설정(사운드/tts) 다이얼로그
                      AlarmSelector(
                        selected: _alarm,
                        configs: _alarmConfigs,
                        onSelected: (lvl) => setState(() => _alarm = lvl),
                        onConfigSaved: (lvl, cfg) => setState(() => _alarmConfigs[lvl] = cfg),

                        showInlineSummary: false, // ✅ 요약 감추기

                      ),
                      const SizedBox(height: 8),

                      // ====================================================
                      // ✅ "알람 옵션 바로 아래" 3열×2행 요약 (아이콘 유지 + 세로 정렬)
                      // ====================================================
                      // Builder(
                      //   builder: (context) {
                      //     final criticalCfg = _alarmConfigs[rm.AlarmLevel.critical];
                      //     final untilCfg    = _alarmConfigs[rm.AlarmLevel.until];

                      //     String disp(String? v) =>
                      //         (v == null || v.trim().isEmpty) ? '—' : v.trim();

                      //     Widget cell({required IconData icon, required String text}) {
                      //       return Row(
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         children: [
                      //           Icon(icon, size: 14, color: Colors.black54),
                      //           const SizedBox(width: 6),
                      //           Expanded(
                      //             child: Text(
                      //               text,
                      //               maxLines: 1,
                      //               overflow: TextOverflow.ellipsis,
                      //               style: Theme.of(context).textTheme.labelSmall,
                      //             ),
                      //           ),
                      //         ],
                      //       );
                      //     }

                      //     return Row(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         // Normal
                      //         Expanded(
                      //           child: Padding(
                      //             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      //             child: Column(
                      //               crossAxisAlignment: CrossAxisAlignment.start,
                      //               children: [
                      //                 cell(icon: Icons.music_note, text: '—'),
                      //                 const SizedBox(height: 6),
                      //                 cell(icon: Icons.person,     text: '—'),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //         // Critical
                      //         Expanded(
                      //           child: Padding(
                      //             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      //             child: Column(
                      //               crossAxisAlignment: CrossAxisAlignment.start,
                      //               children: [
                      //                 cell(
                      //                   icon: Icons.music_note,
                      //                   text: 'sound: ${disp(criticalCfg?.sound)}',
                      //                 ),
                      //                 const SizedBox(height: 6),
                      //                 cell(
                      //                   icon: Icons.person,
                      //                   text: 'tts: ${disp(criticalCfg?.tts)}',
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //         // Until
                      //         Expanded(
                      //           child: Padding(
                      //             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      //             child: Column(
                      //               crossAxisAlignment: CrossAxisAlignment.start,
                      //               children: [
                      //                 cell(
                      //                   icon: Icons.music_note,
                      //                   text: 'sound: ${disp(untilCfg?.sound)}',
                      //                 ),
                      //                 const SizedBox(height: 6),
                      //                 cell(
                      //                   icon: Icons.person,
                      //                   text: 'tts: ${disp(untilCfg?.tts)}',
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     );
                      //   },
                      // ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('취소'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveRule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ec.eventPrimaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              child: Text(_saving ? '저장 중...' : '저장'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
