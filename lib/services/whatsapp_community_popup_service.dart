import 'package:shared_preferences/shared_preferences.dart';

class WhatsAppCommunityPopupService {
  WhatsAppCommunityPopupService._();

  static final WhatsAppCommunityPopupService instance =
      WhatsAppCommunityPopupService._();

  static const String defaultInviteUrl =
      'https://chat.whatsapp.com/Jx3UrzGec0T52bI42qF5Cx';

  static const String _enabledKey = 'whatsapp_community_popup_enabled';
  static const String _inviteUrlKey = 'whatsapp_community_popup_invite_url';

  Future<WhatsAppCommunityPopupConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final inviteUrl = (prefs.getString(_inviteUrlKey) ?? defaultInviteUrl).trim();
    return WhatsAppCommunityPopupConfig(
      enabled: prefs.getBool(_enabledKey) ?? true,
      inviteUrl: _validUrl(inviteUrl) ? inviteUrl : defaultInviteUrl,
    );
  }

  Future<void> saveConfig({
    required bool enabled,
    required String inviteUrl,
  }) async {
    final cleanUrl = inviteUrl.trim();
    if (!_validUrl(cleanUrl)) {
      throw ArgumentError('Valid invite URL required.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setString(_inviteUrlKey, cleanUrl);
  }

  bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

class WhatsAppCommunityPopupConfig {
  const WhatsAppCommunityPopupConfig({
    required this.enabled,
    required this.inviteUrl,
  });

  final bool enabled;
  final String inviteUrl;
}

