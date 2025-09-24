import 'package:flutter/material.dart';
import 'package:mail_push_app/models/rule_model.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

// i18n
import 'package:mail_push_app/l10n/app_localizations.dart';

/// ConditionType → 다국어 라벨
extension ConditionTypeL10n on ConditionType {
  String localizedLabel(AppLocalizations t) {
    switch (this) {
      case ConditionType.subjectContains:
        return t.conditionTypeSubjectContains; // 예) "제목에 포함"
      case ConditionType.bodyContains:
        return t.conditionTypeBodyContains;    // 예) "본문에 포함"
      case ConditionType.fromSender:
        return t.conditionTypeFromSender;      // 예) "보낸 사람"
    }
  }
}

/// 공통 라이트 카드
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
  final MailRule? initialRule;
  const RuleOptionsPage({Key? key, this.initialRule}) : super(key: key);

  @override
  State<RuleOptionsPage> createState() => _RuleOptionsPageState();
}

class _RuleOptionsPageState extends State<RuleOptionsPage> {
  late final TextEditingController _nameController;
  late List<RuleCondition> _conditions;
  bool _stopFurther = false;
  String? _nameError;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRule != null) {
      final clone = MailRule.clone(widget.initialRule!);
      _nameController = TextEditingController(text: clone.name);
      _conditions = clone.conditions;
      _stopFurther = clone.stopFurtherRules;
    } else {
      _nameController = TextEditingController();
      _conditions = [];
    }
  }

  void _addEmptyCondition() {
    setState(() {
      _conditions.add(RuleCondition(type: ConditionType.subjectContains));
    });
  }

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

  Future<bool> _sendRuleToServer(MailRule rule) async {
    try {
      final api = RulesApi();
      final fcm = await _secureStorage.read(key: 'fcm_token');
      if (widget.initialRule != null && widget.initialRule!.id != null) {
        rule.id = widget.initialRule!.id; // 유지
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
    }

    setState(() => _saving = true);

    final MailRule result = MailRule(
      name: name,
      conditions: _conditions,
      stopFurtherRules: _stopFurther,
      enabled: true,
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

    Navigator.of(context).pop(result);
  }

  Widget _buildConditionCard(int idx) {
    final t = AppLocalizations.of(context)!;
    final cond = _conditions[idx];
    final keywordController = TextEditingController();

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
          // 상단 타입 + 삭제
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ConditionType>(
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
                    items: ConditionType.values
                        .map(
                          (ctype) => DropdownMenuItem(
                            value: ctype,
                            child: Text(ctype.localizedLabel(t)),
                          ),
                        )
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

          // 키워드 입력 + 추가
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keywordController,
                  decoration: InputDecoration(
                    hintText: t.keywordHint,      // 예: MTG
                    labelText: t.keywordAddLabel, // 키워드 추가
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
                t.addAtLeastOneKeyword, // 키워드를 하나 이상 추가하세요.
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: t.ruleNameLabel, // 규칙 이름
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
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null && _nameController.text.trim().isNotEmpty) {
              setState(() => _nameError = null);
            }
          },
        ),
        if (_nameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _nameError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isEditing = widget.initialRule != null;

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? t.ruleEditTitle : t.ruleCreateTitle),
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
                      // 규칙 이름
                      _buildTitleInput(),
                      const SizedBox(height: 16),

                      // 조건 타이틀
                      Row(
                        children: [
                          Text(
                            t.conditions, // 조건
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: ec.eventLightPrimaryTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addEmptyCondition,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(t.addCondition),
                            style: TextButton.styleFrom(
                              foregroundColor: ec.eventPrimaryColor,
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 조건 목록/없음 안내
                      if (_conditions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: ec.eventLightBorderColor),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: Text(
                            t.noConditionsHint,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ...List.generate(_conditions.length, (i) => _buildConditionCard(i)),
                      const SizedBox(height: 16),

                      // 추가 옵션
                      Row(
                        children: [
                          Checkbox(
                            value: _stopFurther,
                            activeColor: ec.eventPrimaryColor,
                            onChanged: (v) => setState(() => _stopFurther = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              t.stopFurtherRules, // 이 규칙 이후 처리 중지
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ec.eventLightPrimaryTextColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 하단 액션
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
