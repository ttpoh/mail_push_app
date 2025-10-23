import 'package:flutter/material.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:mail_push_app/menu/rule_options/rule_options_page.dart';
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

  // ✅ 규칙 on/off 저장 중인 인덱스 (칩에 로딩 UI 표시)
  int? _busyEnabledIndex;

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

  // ✅ ON/OFF 토글
  Future<void> _toggleRuleEnabled(int index) async {
    if (_busyEnabledIndex == index) return;
    final t = AppLocalizations.of(context)!;

    final prev = _rules[index];
    final toggled = prev.copyWith(enabled: !prev.enabled);

    setState(() {
      _busyEnabledIndex = index;
      _rules[index] = toggled; // 낙관적 업데이트
    });

    try {
      final fcm = await _secureStorage.read(key: 'fcm_token');
      await _api.updateRule(toggled, fcmToken: fcm);
      // 성공 시 유지
    } catch (e) {
      // 실패 시 롤백
      setState(() => _rules[index] = prev);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.ruleUpdateFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _busyEnabledIndex = null);
    }
  }

  // 🔹 알람 라벨/색상 매핑
  String _alarmLabel(AppLocalizations t, AlarmLevel a) {
    switch (a) {
      case AlarmLevel.normal:
        return t.generalAlarmLabel;      // 예: "일반 알림"
      case AlarmLevel.critical:
        return t.ringOnce;               // 예: "1회 울림"
      case AlarmLevel.until:
        return t.ringUntilStopped;       // 예: "멈출 때까지"
    }
  }

  Color _alarmColor(AlarmLevel a) {
    switch (a) {
      case AlarmLevel.normal:
        return Colors.green;
      case AlarmLevel.critical:
        return Colors.orange;
      case AlarmLevel.until:
        return Colors.red;
    }
  }

  // ✅ ON/OFF 칩 (탭 가능 + 로딩 표시) + (ON일 때) 아래에 알람 유형을 작게 표시
  Widget _enabledChip(
    BuildContext ctx, {
    required bool enabled,
    required VoidCallback? onTap,
    required bool processing,
    String? subtitleWhenOn,
    Color? subtitleColor,
  }) {
    final Color color = enabled ? Colors.green : Colors.grey;
    final String label = enabled ? 'ON' : 'OFF'; // 간단/명확. 필요 시 로컬라이즈 가능.

    final chipChild = processing
        ? SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        : Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: chipChild,
    );

    // 칩 자체는 탭 가능, 아래 라벨은 정보용
    final tappableChip = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: (processing || onTap == null) ? null : onTap,
      child: chip,
    );

    // ON일 때만 하단 라벨 표시
    final subtitle = (enabled && subtitleWhenOn != null && subtitleWhenOn.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 작은 상태 점
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: (subtitleColor ?? color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  subtitleWhenOn,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: (subtitleColor ?? color),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end, // 칩 오른쪽 정렬 느낌 유지
      children: [
        tappableChip,
        subtitle,
      ],
    );
  }

  Widget _buildRuleTile(BuildContext context, int idx) {
    final t = AppLocalizations.of(context)!;
    final rule = _rules[idx];
    final subtitle = rule.conditions
        .map((c) =>
            '${c.type.displayName(context)}: ${c.keywords.isEmpty ? '(${t.none})' : c.keywords.join(", ")}')
        .join(' • ');

    final isBusy = _busyEnabledIndex == idx;

    // 규칙이 꺼져 있으면 내용 전체를 살짝 흐리게
    final tileOpacity = rule.enabled ? 1.0 : 0.45;

    // 알람 표시 텍스트/색상
    final alarmText = _alarmLabel(t, rule.alarm);
    final alarmColor = _alarmColor(rule.alarm);

    return Opacity(
      opacity: tileOpacity,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _openEdit(idx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.rule, color: ec.eventDarkIconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목
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
                          // ✅ 규칙 ON/OFF 토글 칩 (+ ON이면 아래에 알람 유형 작은 라벨)
                          _enabledChip(
                            context,
                            enabled: rule.enabled,
                            onTap: () => _toggleRuleEnabled(idx),
                            processing: isBusy,
                            subtitleWhenOn: alarmText,
                            subtitleColor: alarmColor,
                          ),
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
