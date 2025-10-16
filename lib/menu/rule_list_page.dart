import 'package:flutter/material.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:mail_push_app/menu/rule_options.dart';
import 'package:mail_push_app/models/rule_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

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

class RuleListPage extends StatefulWidget {
  const RuleListPage({Key? key}) : super(key: key);
  @override
  State<RuleListPage> createState() => _RuleListPageState();
}

class _RuleListPageState extends State<RuleListPage> {
  final List<MailRule> _rules = [];
  late final RulesApi _api;
  bool _loading = true;
  String? _error;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _api = RulesApi();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fcm = await _secureStorage.read(key: 'fcm_token');
      final rules = await _api.fetchRules(fcmToken: fcm);
      setState(() {
        _rules..clear()..addAll(rules);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final MailRule? result = await Navigator.of(context).push<MailRule>(
      MaterialPageRoute(builder: (_) => const RuleOptionsPage(initialRule: null)),
    );
    if (result != null) {
      try {
        setState(() => _rules.add(result));
      } catch (e) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.ruleCreateFailed('$e'))));
      }
    }
  }

  Future<void> _openEdit(int index) async {
    final MailRule original = _rules[index];
    final MailRule? updated = await Navigator.of(context).push<MailRule>(
      MaterialPageRoute(builder: (_) => RuleOptionsPage(initialRule: original)),
    );
    if (updated != null) {
      try {
        setState(() => _rules[index] = updated);
      } catch (e) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.ruleUpdateFailed('$e'))));
      }
    }
  }

  Future<void> _deleteRule(int index) async {
    final t = AppLocalizations.of(context)!;
    final rule = _rules[index];
    if (rule.id != null) {
      try {
        final fcm = await _secureStorage.read(key: 'fcm_token');
        await _api.deleteRule(rule.id!, fcmToken: fcm);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.ruleDeleteFailed('$e'))));
        return;
      }
    }
    setState(() => _rules.removeAt(index));
  }

  Widget _alarmChip(BuildContext ctx, AlarmLevel level) {
    final t = AppLocalizations.of(ctx)!;
    late final Color color;
    late final String label;
    switch (level) {
      case AlarmLevel.normal:
        color = Colors.green;
        label = t.generalAlarmLabel; // "일반 알람"
        break;
      case AlarmLevel.critical:
        color = Colors.orange;
        label = t.criticalAlarmLabel; // "주의 알람"
        break;
      case AlarmLevel.until:
        color = Colors.red;
        label = t.ringUntilStopped; // "정지 시까지"
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildRuleTile(BuildContext context, int idx) {
    final t = AppLocalizations.of(context)!;
    final rule = _rules[idx];
    final subtitle = rule.conditions
        .map((c) =>
            '${c.type.displayName}: ${c.keywords.isEmpty ? '(${t.none})' : c.keywords.join(", ")}')
        .join(' • ');

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openEdit(idx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.rule, color: ec.eventDarkIconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _alarmChip(context, rule.alarm), // ✅ 알람 모드 칩
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ec.eventLightSecondaryTextColor,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // stopFurtherRules 관련 UI 제거
              PopupMenuButton<String>(
                color: Colors.white,
                iconColor: ec.eventLightUnselectedItemColor,
                onSelected: (v) {
                  if (v == 'edit') {
                    _openEdit(idx);
                  } else if (v == 'delete') {
                    _deleteRule(idx);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.ruleEdit)),
                  PopupMenuItem(value: 'delete', child: Text(t.ruleDelete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    Widget inner;
    if (_loading) {
      inner = const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ));
    } else if (_error != null) {
      inner = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.loadFailed(_error!), style: const TextStyle(color: Colors.black)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadRules, child: Text(t.retry)),
          ],
        ),
      );
    } else if (_rules.isEmpty) {
      inner = Center(
        child: Text(t.noRules, style: const TextStyle(color: Colors.black54)),
      );
    } else {
      inner = ListView.separated(
        itemBuilder: _buildRuleTile,
        separatorBuilder: (_, __) => Divider(height: 1, color: ec.eventLightDividerColor),
        itemCount: _rules.length,
      );
    }

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        backgroundColor: ec.eventLightCardColor,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(t.menuRulesLabel),
        actions: [
          IconButton(onPressed: _openCreate, icon: const Icon(Icons.add), tooltip: t.addRule),
          IconButton(onPressed: _loadRules, icon: const Icon(Icons.refresh), tooltip: t.reload),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AppCard(child: inner),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: t.newRule,
        backgroundColor: ec.eventPrimaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
