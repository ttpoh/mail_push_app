import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:mail_push_app/device/alarm_setting_sync.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ConditionType → 다국어 라벨
extension ConditionTypeL10n on rm.ConditionType {
  String localizedLabel(AppLocalizations t) {
    switch (this) {
      case rm.ConditionType.subjectContains:
        return t.conditionTypeSubjectContains;
      case rm.ConditionType.bodyContains:
        return t.conditionTypeBodyContains;
      case rm.ConditionType.fromSender:
        return t.conditionTypeFromSender;
    }
  }
}

/// LogicType → 다국어 라벨
extension LogicTypeL10n on rm.LogicType {
  String localizedLabel(AppLocalizations t) {
    switch (this) {
      case rm.LogicType.and:
        return t.logicAnd;
      case rm.LogicType.or:
        return t.logicOr;
    }
  }
}

/// 공통 카드
class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

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

  // 규칙의 alarm 모드 (서버 저장 대상)
  rm.AlarmLevel _alarm = rm.AlarmLevel.normal;

  // 디바이스 알람 동기화
  late final AlarmSettingSync _alarmSync;
  bool _normalOn = true;
  bool _criticalOn = false;
  bool _until = false;

  Timer? _flagTimer;
  bool? _qNormal;
  bool? _qCritical;
  bool? _qUntil;

  // ====== 새 조건 컴포저 상태(생성 모드에서만 사용) ======
  rm.ConditionType _newType = rm.ConditionType.subjectContains;
  rm.LogicType _newLogic = rm.LogicType.or;
  final TextEditingController _newKeywordCtrl = TextEditingController();
  final List<String> _newKeywords = [];

  bool get _isEditing => widget.initialRule != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final clone = rm.MailRule.clone(widget.initialRule!);
      _nameController = TextEditingController(text: clone.name);
      _conditions = clone.conditions;
      _alarm = clone.alarm;
    } else {
      _nameController = TextEditingController();
      _conditions = [];
      _alarm = rm.AlarmLevel.normal;
    }

    // AlarmSettingSync 주입
    final api = ApiClient();
    _alarmSync = AlarmSettingSync(
      api: api,
      fcmInstance: FirebaseMessaging.instance,
      storage: const FlutterSecureStorage(),
    );

    _initAlarmFlags();
  }

  Future<void> _initAlarmFlags() async {
    try {
      final server = await _alarmSync.loadFromServerAndSeedPrefs(alsoSeedPrefs: true);
      setState(() {
        _normalOn = server.normalOn ?? true;
        _criticalOn = server.criticalOn ?? false;
        _until = server.criticalUntil ?? false;
        if (_until && !_criticalOn) _criticalOn = true;
      });
    } catch (_) {
      setState(() {
        _normalOn = true;
        _criticalOn = false;
        _until = false;
      });
    }
  }

  void _queuePatch({bool? normal, bool? critical, bool? until}) {
    if (normal != null) _qNormal = normal;
    if (critical != null) _qCritical = critical;
    if (until != null) _qUntil = until;

    _flagTimer?.cancel();
    _flagTimer = Timer(const Duration(milliseconds: 500), () async {
      final n = _qNormal; final c = _qCritical; final u = _qUntil;
      _qNormal = null; _qCritical = null; _qUntil = null;
      try {
        await _alarmSync.patchFlags(
          normalOn: n,
          criticalOn: c,
          criticalUntilStopped: u,
        );
      } catch (e) {
        debugPrint('patchFlags error: $e');
      }
    });
  }

  // ====== 기존 조건 편집 ======
  void _addKeyword(int condIndex, String keyword) {
    final w = keyword.trim();
    if (w.isEmpty) return;
    setState(() {
      final list = _conditions[condIndex].keywords;
      if (!list.contains(w)) list.add(w);
    });
  }

  void _removeKeyword(int condIndex, int keywordIndex) {
    setState(() {
      _conditions[condIndex].keywords.removeAt(keywordIndex);
    });
  }

  void _removeCondition(int condIndex) {
    setState(() {
      _conditions.removeAt(condIndex);
    });
  }

  // ====== (수정됨) 새 조건 컴포저: 키워드 추가 버튼이 '조건 추가'까지 처리 ======
  void _commitComposer({String? inline}) {
    final t = AppLocalizations.of(context)!;
    final hideLogic = _newType == rm.ConditionType.fromSender;

    // 입력창에 남아 있는 텍스트도 반영
    final w = (inline ?? _newKeywordCtrl.text).trim();
    if (w.isNotEmpty && !_newKeywords.contains(w)) {
      _newKeywords.add(w);
    }

    if (_newKeywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.addAtLeastOneKeyword)),
      );
      return;
    }

    setState(() {
      _conditions.add(
        rm.RuleCondition(
          type: _newType,
          logic: hideLogic ? rm.LogicType.or : _newLogic,
          keywords: List<String>.from(_newKeywords),
          position: _conditions.length,
        ),
      );
      // 컴포저 초기화
      _newType = rm.ConditionType.subjectContains;
      _newLogic = rm.LogicType.or;
      _newKeywords.clear();
      _newKeywordCtrl.clear();
    });
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
    final t = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();

    // (유지) 생성 모드에서 컴포저에 잔여 키워드가 남아 있으면 안내
    if (!_isEditing && _newKeywords.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.addCondition)), // “조건 추가” 먼저
      );
      return;
    }

    if (name.isEmpty) {
      setState(() => _nameError = t.ruleNameRequired);
      return;
    }
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.needAtLeastOneCondition)),
      );
      return;
    }
    for (var cond in _conditions) {
      if (cond.keywords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.needKeywordsInAllConditions)),
        );
        return;
      }
      if (cond.type != rm.ConditionType.fromSender && cond.logic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.needLogicForConditions)),
        );
        return;
      }
    }

    // position 정렬
    for (int i = 0; i < _conditions.length; i++) {
      _conditions[i].position = i;
    }

    setState(() => _saving = true);

    final rm.MailRule result = rm.MailRule(
      name: name,
      conditions: _conditions,
      enabled: true,
      alarm: _alarm,
      id: widget.initialRule?.id,
    );

    final success = await _sendRuleToServer(result);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.ruleSaveFailed)),
      );
      return;
    }

    // 디바이스 플래그 반영
    _flagTimer?.cancel();
    await _alarmSync.patchFlags(
      normalOn: _normalOn,
      criticalOn: _criticalOn,
      criticalUntilStopped: _until,
    );

    Navigator.of(context).pop(result);
  }

  // ====== 알림 버튼 UI (라벨 + 소형 Wrap, 텍스트 포함) ======
  // ====== 알림 버튼 UI (라벨 + 소형 Wrap, 텍스트 포함) ======
  Widget _buildAlarmButtons() {
    final t = AppLocalizations.of(context)!;

    Widget colorButton({
      required Color color,
      required bool selected,
      required String label,
      required VoidCallback onTap,
    }) {
      final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

      // 공통: 버튼이 내용에 맞게 늘어나고, 높이만 얇게 유지
      const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      const Size minSize = Size(0, 28); // 얇은 높이만 보장, 폭은 내용대로
      final visual = VisualDensity.compact;

      if (selected) {
        return ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: shape,
            padding: padding,
            minimumSize: minSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: visual,
          ),
          child: Text(
            label,
            // 줄임표 제거: 버튼이 내용만큼 넓어지도록
            overflow: TextOverflow.visible,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          ),
        );
      } else {
        return OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: ec.eventLightBorderColor),
            backgroundColor: Colors.white,
            shape: shape,
            padding: EdgeInsets.zero, // 내부에 살짝 색 오버레이 주기 위해 컨테이너로 패딩 처리
            minimumSize: minSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: visual,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: color),
            ),
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Text(
            t.alarmSettingsTitle, // “알람 설정”
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ec.eventLightPrimaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              colorButton(
                color: Colors.green,
                selected: _alarm == rm.AlarmLevel.normal,
                label: AppLocalizations.of(context)!.generalAlarmLabel,
                onTap: () {
                  setState(() {
                    _alarm = rm.AlarmLevel.normal;
                    _normalOn = true;
                  });
                  _queuePatch(normal: true);
                },
              ),
              colorButton(
                color: Colors.orange,
                selected: _alarm == rm.AlarmLevel.critical,
                label: AppLocalizations.of(context)!.ringOnce,
                onTap: () {
                  setState(() {
                    _alarm = rm.AlarmLevel.critical;
                    _criticalOn = true;
                    _until = false;
                  });
                  _queuePatch(critical: true, until: false);
                },
              ),
              colorButton(
                color: Colors.red,
                selected: _alarm == rm.AlarmLevel.until,
                label: AppLocalizations.of(context)!.ringUntilStopped,
                onTap: () {
                  setState(() {
                    _alarm = rm.AlarmLevel.until;
                    _criticalOn = true;
                    _until = true;
                  });
                  _queuePatch(critical: true, until: true);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ====== 기존 조건 카드 ======
  Widget _buildConditionCard(int idx) {
    final t = AppLocalizations.of(context)!;
    final cond = _conditions[idx];
    final keywordController = TextEditingController();
    final hideLogic = cond.type == rm.ConditionType.fromSender;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ec.eventLightCardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ec.eventLightBorderColor),
        boxShadow: [
          BoxShadow(
            color: ec.eventLightShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 + 삭제
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<rm.ConditionType>(
                    value: cond.type,
                    isExpanded: true,
                    iconEnabledColor: ec.eventLightPrimaryTextColor,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ec.eventLightPrimaryTextColor,
                        ),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => cond.type = v);
                    },
                    items: rm.ConditionType.values
                        .map((ctype) => DropdownMenuItem(
                              value: ctype,
                              child: Text(ctype.localizedLabel(t)),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeCondition(idx),
                icon: const Icon(Icons.close),
                color: ec.eventLightUnselectedItemColor,
                tooltip: t.deleteCondition,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 키워드 로직 선택 (보낸 사람일 때 숨김)
          if (!hideLogic)
            Row(
              children: [
                Text(
                  t.keywordLogicLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ec.eventLightPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<rm.LogicType>(
                      value: cond.logic,
                      isExpanded: true,
                      iconEnabledColor: ec.eventLightPrimaryTextColor,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ec.eventLightPrimaryTextColor,
                          ),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => cond.logic = v);
                      },
                      items: rm.LogicType.values
                          .map((ltype) => DropdownMenuItem(
                                value: ltype,
                                child: Text(ltype.localizedLabel(t)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          if (!hideLogic) const SizedBox(height: 10),

          // 키워드 입력 + 추가
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keywordController,
                  decoration: InputDecoration(
                    hintText: t.keywordHint,
                    labelText: t.keywordAddLabel,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventLightBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventLightBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventPrimaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (v) {
                    _addKeyword(idx, v);
                    keywordController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _addKeyword(idx, keywordController.text);
                  keywordController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ec.eventPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(t.add),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 키워드 칩
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(cond.keywords.length, (kIdx) {
              final kw = cond.keywords[kIdx];
              return InputChip(
                label: Text(kw),
                onDeleted: () => _removeKeyword(idx, kIdx),
                backgroundColor: Colors.white,
                side: BorderSide(color: ec.eventLightBorderColor),
              );
            }),
          ),

          if (cond.keywords.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t.addAtLeastOneKeyword,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ====== (수정됨) 새 조건 컴포저(생성 모드에서만 렌더링) ======
  Widget _buildNewConditionComposer() {
    final t = AppLocalizations.of(context)!;
    final hideLogic = _newType == rm.ConditionType.fromSender;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ec.eventLightBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 선택
          DropdownButtonHideUnderline(
            child: DropdownButton<rm.ConditionType>(
              value: _newType,
              isExpanded: true,
              onChanged: (v) => setState(() => _newType = v ?? _newType),
              items: rm.ConditionType.values
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.localizedLabel(t)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),

          // 로직 (보낸 사람일 때 숨김)
          if (!hideLogic)
            DropdownButtonHideUnderline(
              child: DropdownButton<rm.LogicType>(
                value: _newLogic,
                isExpanded: true,
                onChanged: (v) => setState(() => _newLogic = v ?? _newLogic),
                items: rm.LogicType.values
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.localizedLabel(t)),
                        ))
                    .toList(),
              ),
            ),
          if (!hideLogic) const SizedBox(height: 10),

          // 키워드 입력 + (수정됨) 추가 = 조건 생성까지
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newKeywordCtrl,
                  decoration: InputDecoration(
                    hintText: t.keywordHint,
                    labelText: t.keywordAddLabel,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventLightBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (v) => _commitComposer(inline: v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _commitComposer(), // 입력창 텍스트 포함해 조건 생성
                style: ElevatedButton.styleFrom(
                  backgroundColor: ec.eventPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(t.add), // “추가”가 곧 “조건 추가”
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 참고: 이제는 ‘칩으로 쌓아두는’ 단계 없이 바로 조건으로 들어가므로
          // _newKeywords를 칩으로 보여줄 필요가 없어져도 되지만,
          // 사용자가 여러 개를 입력 후 한 번에 담고 싶다면 아래 주석을 풀고 유지 가능.
          //
          // Wrap(
          //   spacing: 6,
          //   runSpacing: 6,
          //   children: List.generate(_newKeywords.length, (i) {
          //     final kw = _newKeywords[i];
          //     return InputChip(
          //       label: Text(kw),
          //       onDeleted: () => setState(() => _newKeywords.removeAt(i)),
          //       backgroundColor: Colors.white,
          //       side: BorderSide(color: ec.eventLightBorderColor),
          //     );
          //   }),
          // ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flagTimer?.cancel();
    _nameController.dispose();
    _newKeywordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? t.ruleEditTitle : t.ruleCreateTitle),
        backgroundColor: ec.eventLightCardColor,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveRule,
            child: Text(
              _saving ? t.savingEllipsis : t.save,
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
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 제목
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: t.ruleNameLabel,
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

                      // 조건 섹션
                      Text(
                        t.conditions,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: ec.eventLightPrimaryTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // (생성 모드) 새 조건 컴포저
                      if (!_isEditing) ...[
                        _buildNewConditionComposer(),
                        const SizedBox(height: 10),
                      ],

                      // 기존 조건 리스트
                      ...List.generate(_conditions.length, (i) => _buildConditionCard(i)),

                      const SizedBox(height: 12),

                      // 알람 설정
                      _buildAlarmButtons(),

                      const SizedBox(height: 20),

                      // 액션
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: Text(t.cancel),
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
                              child: Text(_saving ? t.savingEllipsis : t.save),
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
