import 'package:flutter/material.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

class ConditionCard extends StatefulWidget {
  const ConditionCard({
    super.key,
    required this.condition,
    required this.onRemove,
    required this.onChanged,
  });

  final rm.RuleCondition condition;
  final VoidCallback onRemove;
  final ValueChanged<rm.RuleCondition> onChanged;

  @override
  State<ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<ConditionCard> {
  final TextEditingController _kwCtrl = TextEditingController();

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  bool get _hideLogic => widget.condition.type == rm.ConditionType.fromSender;

  void _addKeyword(String v) {
    final w = v.trim();
    if (w.isEmpty) return;
    final list = widget.condition.keywords;
    if (!list.contains(w)) {
      setState(() => list.add(w));
      widget.onChanged(widget.condition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cond = widget.condition;

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
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => cond.type = v);
                      widget.onChanged(cond);
                    },
                    items: rm.ConditionType.values.map((ctype) {
                      final label = switch (ctype) {
                        rm.ConditionType.subjectContains => '제목에 포함',
                        rm.ConditionType.bodyContains    => '내용에 포함',
                        rm.ConditionType.fromSender      => '보낸 사람',
                      };
                      return DropdownMenuItem(value: ctype, child: Text(label));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close),
                color: ec.eventLightUnselectedItemColor,
                tooltip: '조건 삭제',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 로직 (보낸 사람 제외)
          if (!_hideLogic)
            Row(
              children: [
                const Text(
                  '키워드 로직',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<rm.LogicType>(
                      value: cond.logic,
                      isExpanded: true,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => cond.logic = v);
                        widget.onChanged(cond);
                      },
                      items: rm.LogicType.values.map((ltype) {
                        final label = switch (ltype) {
                          rm.LogicType.and => '모두 포함(AND)',
                          rm.LogicType.or  => '하나 이상 포함(OR)',
                        };
                        return DropdownMenuItem(value: ltype, child: Text(label));
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          if (!_hideLogic) const SizedBox(height: 10),

          // 키워드 입력 + 추가 (새 위젯 안 띄우고 현재 조건에 바로 추가)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kwCtrl,
                  decoration: InputDecoration(
                    hintText: '키워드를 입력 후 Enter',
                    labelText: '키워드 추가',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventLightBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventPrimaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (v) {
                    _addKeyword(v);
                    _kwCtrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _addKeyword(_kwCtrl.text);
                  _kwCtrl.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ec.eventPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('추가'),
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
                onDeleted: () {
                  setState(() => cond.keywords.removeAt(kIdx));
                  widget.onChanged(cond);
                },
                backgroundColor: Colors.white,
                side: BorderSide(color: ec.eventLightBorderColor),
              );
            }),
          ),

          if (cond.keywords.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '키워드를 1개 이상 추가하세요.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
