// rule_options.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final String RULES_API_BASE = "${dotenv.env['SERVER_BASE_URL']}/rules";
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

enum ConditionType {
  subjectContains,
  bodyContains,
  fromSender,
}

extension ConditionTypeExt on ConditionType {
  String get displayName {
    switch (this) {
      case ConditionType.subjectContains:
        return '제목에 포함';
      case ConditionType.bodyContains:
        return '내용에 포함';
      case ConditionType.fromSender:
        return '보낸 사람';
    }
  }
}

class RuleCondition {
  ConditionType type;
  List<String> keywords;
  RuleCondition({
    required this.type,
    List<String>? keywords,
  }) : keywords = List.from(keywords ?? []);

  RuleCondition.clone(RuleCondition other)
      : type = other.type,
        keywords = List.from(other.keywords);
}

class MailRule {
  String name;
  List<RuleCondition> conditions;
  bool stopFurtherRules;
  MailRule({
    required this.name,
    required this.conditions,
    this.stopFurtherRules = false,
  });

  MailRule.clone(MailRule other)
      : name = other.name,
        conditions =
            other.conditions.map((c) => RuleCondition.clone(c)).toList(),
        stopFurtherRules = other.stopFurtherRules;
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
    if (keyword.trim().isEmpty) return;
    setState(() {
      final list = _conditions[condIndex].keywords;
      if (!list.contains(keyword.trim())) {
        list.add(keyword.trim());
      }
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
  Future<bool> _sendRuleToServer(MailRule rule, {int? ruleId}) async {
    final url = ruleId != null
        ? Uri.parse("$RULES_API_BASE/$ruleId")
        : Uri.parse(RULES_API_BASE);

    final body = {
      "name": rule.name,
      "enabled": true,
      "stop_further_rules": rule.stopFurtherRules,
      "conditions": rule.conditions.map((c) {
        return {
          "type": c.type.name, // enum 이름: subjectContains, bodyContains, fromSender
          "keywords": c.keywords,
        };
      }).toList(),
      "fcm_token": await await _secureStorage.read(key: 'fcm_token'), // 현재 사용자 디바이스 토큰

    };

    try {
      final response = ruleId != null
          ? await http.put(url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(body))
          : await http.post(url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint(
            "Rule save failed (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error sending rule to server: $e");
      return false;
    }
  }

  void _saveRule() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = '이름을 입력하세요.';
      });
      return;
    }

    final MailRule result = MailRule(
      name: name,
      conditions: _conditions,
      stopFurtherRules: _stopFurther,
    );

    // 서버에 저장 (처음이면 생성, 있으면 수정)
    int? existingId;
    if (widget.initialRule != null) {
      // initialRule이 서버에서 받아온 객체라면 id를 가진다고 가정
      // 외부에서 id를 확장해서 넣어두는 구조라면 여기서 꺼냄
      final dynamic maybeId = (widget.initialRule as dynamic).id;
      if (maybeId is int) existingId = maybeId;
    }

    final success = await _sendRuleToServer(result, ruleId: existingId);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('규칙 저장 실패, 다시 시도해주세요.')),
      );
      return;
    }

    Navigator.of(context).pop(result);
  }


  Widget _buildConditionCard(int idx) {
    final cond = _conditions[idx];
    final keywordController = TextEditingController();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<ConditionType>(
                  value: cond.type,
                  underline: const SizedBox(),
                  isExpanded: true,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      cond.type = v;
                    });
                  },
                  items: ConditionType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeCondition(idx),
                icon: const Icon(Icons.close),
                tooltip: '조건 삭제',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keywordController,
                  decoration: const InputDecoration(
                    hintText: '예: 미팅',
                    labelText: '키워드 추가',
                    isDense: true,
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
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(cond.keywords.length, (kIdx) {
              final kw = cond.keywords[kIdx];
              return InputChip(
                label: Text(kw),
                onDeleted: () => _removeKeyword(idx, kIdx),
              );
            }),
          ),
          if (cond.keywords.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '키워드를 하나 이상 추가하세요.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '규칙 이름 지정',
            border: const OutlineInputBorder(),
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null && _nameController.text.trim().isNotEmpty) {
              setState(() {
                _nameError = null;
              });
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
    final isEditing = widget.initialRule != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(isEditing ? '규칙 수정' : '새 규칙'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saveRule,
            child: const Text('저장', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleInput(),
              const SizedBox(height: 16),
              const Text('조건',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_conditions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: const Text(
                    '조건이 없습니다. 아래 "다른 조건 추가"로 추가하세요.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ...List.generate(
                  _conditions.length, (i) => _buildConditionCard(i)),
              TextButton.icon(
                onPressed: _addEmptyCondition,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('다른 조건 추가'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _stopFurther,
                    onChanged: (v) {
                      setState(() {
                        _stopFurther = v ?? false;
                      });
                    },
                  ),
                  const Expanded(child: Text('더 이상 규칙 수행 중지')),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('버리기'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveRule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
