// rule_list_page.dart
import 'package:flutter/material.dart';
import 'rule_options.dart';

class RuleListPage extends StatefulWidget {
  const RuleListPage({Key? key}) : super(key: key);

  @override
  State<RuleListPage> createState() => _RuleListPageState();
}

class _RuleListPageState extends State<RuleListPage> {
  final List<MailRule> _rules = [
    MailRule(
      name: '제목에 미팅 포함',
      conditions: [
        RuleCondition(
          type: ConditionType.subjectContains,
          keywords: ['미팅'],
        ),
      ],
      stopFurtherRules: false,
    ),
    MailRule(
      name: '보낸 사람이 example@domain.com',
      conditions: [
        RuleCondition(
          type: ConditionType.fromSender,
          keywords: ['example@domain.com'],
        ),
      ],
      stopFurtherRules: true,
    ),
  ];

  void _openCreate() async {
    final MailRule? result = await Navigator.of(context).push<MailRule>(
      MaterialPageRoute(
        builder: (_) => const RuleOptionsPage(
          initialRule: null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _rules.add(result);
      });
    }
  }

  void _openEdit(int index) async {
    final MailRule original = _rules[index];
    final MailRule? updated = await Navigator.of(context).push<MailRule>(
      MaterialPageRoute(
        builder: (_) => RuleOptionsPage(
          initialRule: original,
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _rules[index] = updated;
      });
    }
  }

  void _deleteRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  Widget _buildRuleTile(int idx) {
    final rule = _rules[idx];
    return ListTile(
      onTap: () => _openEdit(idx),
      title: Text(rule.name),
      subtitle: Text(
        rule.conditions
            .map((c) =>
                '${c.type.displayName}: ${c.keywords.isEmpty ? "(없음)" : c.keywords.join(", ")}')
            .join(" • "),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rule.stopFurtherRules)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.block, size: 18),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _openEdit(idx);
              } else if (v == 'delete') {
                _deleteRule(idx);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메일 규칙'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: '새 규칙 추가',
          ),
        ],
      ),
      body: _rules.isEmpty
          ? const Center(
              child:
                  Text('등록된 규칙이 없습니다. + 버튼으로 새 규칙을 만들어보세요.'),
            )
          : ListView.separated(
              itemBuilder: (_, i) => _buildRuleTile(i),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: _rules.length,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
        tooltip: '새 규칙',
      ),
    );
  }
}
