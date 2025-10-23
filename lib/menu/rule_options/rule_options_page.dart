// lib/menu/rule_options/rule_options_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/api/rule_list_client.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/l10n/app_localizations.dart';
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

      if (clone.sound != null || clone.tts != null) {
        final cfgLevel = (clone.alarm == rm.AlarmLevel.critical || clone.alarm == rm.AlarmLevel.until)
            ? clone.alarm
            : rm.AlarmLevel.critical;
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
    } catch (_) {
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

    String? sound;
    String? tts;
    if (_alarm == rm.AlarmLevel.critical || _alarm == rm.AlarmLevel.until) {
      final cfg = _alarmConfigs[_alarm];
      if (cfg == null || cfg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.enterSoundOrTts)),
        );
        return;
      }
      sound = cfg.sound?.trim().isEmpty == true ? null : cfg.sound?.trim();
      tts   = cfg.tts?.trim().isEmpty   == true ? null : cfg.tts?.trim();
    }

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
      sound: sound ?? '',
      tts: tts,
    );

    final success = await _sendRuleToServer(result);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.ruleSaveFailed)));
      return;
    }

    Navigator.of(context).pop(result);
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
          padding: const EdgeInsets.all(16),
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

                      Text(t.conditions, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),

                      NewConditionComposer(
                        onCreate: (cond) {
                          setState(() {
                            cond.position = _conditions.length;
                            _conditions.add(cond);
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      ...List.generate(_conditions.length, (i) {
                        return ConditionCard(
                          condition: _conditions[i],
                          onRemove: () => setState(() => _conditions.removeAt(i)),
                          onChanged: (c) => setState(() => _conditions[i] = c),
                        );
                      }),

                      const SizedBox(height: 12),

                      AlarmSelector(
                        selected: _alarm,
                        configs: _alarmConfigs,
                        onSelected: (lvl) => setState(() => _alarm = lvl),
                        onConfigSaved: (lvl, cfg) => setState(() => _alarmConfigs[lvl] = cfg),
                        showInlineSummary: false,
                      ),

                      const SizedBox(height: 20),
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
