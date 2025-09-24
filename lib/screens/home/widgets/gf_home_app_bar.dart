import 'package:flutter/material.dart';
import 'package:mail_push_app/ui/uikit_bridge.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';

enum AccountMenu { logout }
enum SettingsMenu { alarm, rules }

class GfHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAlarmSettings;
  final VoidCallback onOpenRules;
  final VoidCallback onLogout;
  final void Function(Locale) onChangeLocale;

  const GfHomeAppBar({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.onOpenAlarmSettings,
    required this.onOpenRules,
    required this.onLogout,
    required this.onChangeLocale,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  String _settingsMenuLabel(BuildContext context, SettingsMenu m) {
    final l10n = AppLocalizations.of(context)!;
    switch (m) {
      case SettingsMenu.alarm:
        return l10n.menuAlarmSettings; // "알람 설정"
      case SettingsMenu.rules:
        return l10n.menuRulesLabel; // "메일 규칙"
    }
  }

  String _accountMenuLabel(BuildContext context, AccountMenu m) {
    final l10n = AppLocalizations.of(context)!;
    switch (m) {
      case AccountMenu.logout:
        return l10n.menuLogout; // "로그아웃"
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      leadingWidth: 56,
      // 👤 계정 메뉴 (로그아웃)
      leading: PopupMenuButton<AccountMenu>(
        tooltip: '계정', // .arb 키가 없으니 고정 텍스트 유지
        offset: const Offset(0, 48),
        onSelected: (v) {
          if (v == AccountMenu.logout) onLogout();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: AccountMenu.logout,
            child: Text(_accountMenuLabel(context, AccountMenu.logout)),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: UiKit.primary(context).withOpacity(0.12),
            child: Icon(Icons.person, color: UiKit.primary(context)),
          ),
        ),
      ),

      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),

      actions: [
        // ✉️ 메일(새로고침)
        IconButton(
          tooltip: l10n.reload, // "새로 고침"
          onPressed: onRefresh,
          icon: const Icon(Icons.mail),
        ),

        // ⚙️ 설정(알림/규칙)
        PopupMenuButton<SettingsMenu>(
          tooltip: '설정', // .arb 키가 없으니 고정 텍스트 유지
          offset: const Offset(0, 48),
          icon: const Icon(Icons.settings),
          onSelected: (v) {
            switch (v) {
              case SettingsMenu.alarm:
                onOpenAlarmSettings();
                break;
              case SettingsMenu.rules:
                onOpenRules();
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: SettingsMenu.alarm,
              child: Text(_settingsMenuLabel(context, SettingsMenu.alarm)),
            ),
            PopupMenuItem(
              value: SettingsMenu.rules,
              child: Text(_settingsMenuLabel(context, SettingsMenu.rules)),
            ),
          ],
        ),

        // 🌐 언어 변경
        PopupMenuButton<Locale>(
          tooltip: '언어', // .arb 키가 없으니 고정 텍스트 유지
          offset: const Offset(0, 48),
          icon: const Icon(Icons.language),
          onSelected: onChangeLocale,
          itemBuilder: (_) => [
            PopupMenuItem(value: const Locale('ko'), child: Text(l10n.langKorean)),
            PopupMenuItem(value: const Locale('en'), child: Text(l10n.langEnglish)),
            PopupMenuItem(value: const Locale('ja'), child: Text(l10n.langJapanese)),
          ],
        ),
      ],
    );
  }
}
