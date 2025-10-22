// lib/menu/rule_options/widgets/new_condition_composer.dart
import 'package:flutter/material.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

typedef OnCreateCondition = void Function(rm.RuleCondition condition);

class NewConditionComposer extends StatefulWidget {
  const NewConditionComposer({
    super.key,
    required this.onCreate,
    this.initialType = rm.ConditionType.subjectContains,
    this.initialLogic = rm.LogicType.or,
    this.enabled = true,
  });

  final OnCreateCondition onCreate;
  final rm.ConditionType initialType;
  final rm.LogicType initialLogic;
  final bool enabled;

  @override
  State<NewConditionComposer> createState() => _NewConditionComposerState();
}

class _NewConditionComposerState extends State<NewConditionComposer> {
  late rm.ConditionType _type;
  late rm.LogicType _logic;
  final TextEditingController _kwCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _logic = widget.initialLogic;
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  bool get _hideLogic => _type == rm.ConditionType.fromSender;

  List<String> _parseKeywords(String raw) {
    final parts = raw
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return {...parts}.toList(); // 중복 제거
  }

  void _commit({String? inline}) {
    setState(() => _error = null);

    final text = (inline ?? _kwCtrl.text).trim();
    final keywords = _parseKeywords(text);
    if (keywords.isEmpty) {
      setState(() => _error = '키워드를 1개 이상 입력하세요.');
      return;
    }

    final cond = rm.RuleCondition(
      type: _type,
      logic: _hideLogic ? rm.LogicType.or : _logic,
      keywords: keywords,
      position: 0,
    );

    widget.onCreate(cond);
    _kwCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.6,
        child: Container(
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
              DropdownButtonHideUnderline(
                child: DropdownButton<rm.ConditionType>(
                  value: _type,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _type = v ?? _type),
                  items: rm.ConditionType.values.map((e) {
                    final label = switch (e) {
                      rm.ConditionType.subjectContains => '제목에 포함',
                      rm.ConditionType.bodyContains    => '내용에 포함',
                      rm.ConditionType.fromSender      => '보낸 사람',
                    };
                    return DropdownMenuItem(value: e, child: Text(label));
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              if (!_hideLogic)
                DropdownButtonHideUnderline(
                  child: DropdownButton<rm.LogicType>(
                    value: _logic,
                    isExpanded: true,
                    onChanged: (v) => setState(() => _logic = v ?? _logic),
                    items: rm.LogicType.values.map((e) {
                      final label = switch (e) {
                        rm.LogicType.and => '모두 포함(AND)',
                        rm.LogicType.or  => '하나 이상 포함(OR)',
                      };
                      return DropdownMenuItem(value: e, child: Text(label));
                    }).toList(),
                  ),
                ),
              if (!_hideLogic) const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kwCtrl,
                      decoration: InputDecoration(
                        hintText: '쉼표(,), 세미콜론(;), 줄바꿈으로 여러 개 입력',
                        labelText: '키워드 추가',
                        isDense: true,
                        errorText: _error,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ec.eventLightBorderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ec.eventPrimaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (v) => _commit(inline: v),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _commit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ec.eventPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '예) "mtg, 회의" 처럼 여러 개 입력할 수 있어요.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
