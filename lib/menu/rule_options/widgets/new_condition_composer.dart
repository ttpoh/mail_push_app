// lib/menu/rule_options/widgets/new_condition_composer.dart
import 'package:flutter/material.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/l10n/app_localizations.dart';

typedef OnCreateCondition = void Function(rm.RuleCondition condition);

/// B안: 조건 카드는 버튼으로만 추가.
/// 키워드 입력은 ConditionCard 내부에서만 이뤄지도록 역할 분리.
class NewConditionComposer extends StatelessWidget {
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

  rm.RuleCondition _buildEmptyCondition() {
    return rm.RuleCondition(
      type: initialType,
      logic: initialType == rm.ConditionType.fromSender ? rm.LogicType.or : initialLogic,
      keywords: <String>[],
      position: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!; // ✅ 다국어 사용

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => onCreate(_buildEmptyCondition()) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ec.eventPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.add),
        label: Text(t.addCondition), // ✅ '조건 추가' → ARB
      ),
    );
  }
}
