import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/admin_service.dart';

class AdminUpdateNotificationScreen extends StatefulWidget {
  const AdminUpdateNotificationScreen({super.key});

  @override
  State<AdminUpdateNotificationScreen> createState() =>
      _AdminUpdateNotificationScreenState();
}

class _AdminUpdateNotificationScreenState
    extends State<AdminUpdateNotificationScreen> {
  static const String _playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.yanaworldwide.shop&pcampaignid=web_share";

  final AdminService _admin = AdminService();

  bool _loading = true;
  bool _busy = false;
  bool _forceUpdate = false;
  bool _testMode = false;
  String _status = "";
  String _currentVersion = "";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final data = await _admin.getAppUpdateConfig();
    if (!mounted) return;

    final state =
        (data["state"] is Map)
            ? Map<String, dynamic>.from(data["state"])
            : const <String, dynamic>{};

    final currentVersion = _composeAppVersion(
      packageInfo.version,
      packageInfo.buildNumber,
    );
    final buildNumber = packageInfo.buildNumber.trim();

    if (state.isNotEmpty) {
      _forceUpdate = state["force_update"] == true;
      final active = state["active"] == true;
      final campaignId = (state["campaign_id"] ?? 0).toString();
      final updatedAt = (state["updated_at"] ?? "-").toString();
      _status = "Current: active=$active, campaign_id=$campaignId, updated_at=$updatedAt";
    } else {
      _status = "Could not fetch current config.";
    }

    setState(() {
      _currentVersion = currentVersion;
      _buildNumber = buildNumber;
      _loading = false;
    });
  }

  Future<void> _triggerUpdate() async {
    final version = _currentVersion.trim();
    if (version.isEmpty && !_testMode) {
      setState(() {
        _status = "Current app version detect nahi ho paayi.";
      });
      return;
    }

    setState(() => _busy = true);
    final data = await _admin.triggerAppUpdate(
      title: _forceUpdate ? "Update Required" : "Update Available",
      message: _forceUpdate
          ? "Please update the app to continue."
          : "A new app version is available. Please update for the best experience.",
      url: _playStoreUrl,
      minVersion: _testMode ? "" : version,
      latestVersion: version,
      forceUpdate: _forceUpdate,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data["ok"] == true) {
        final state =
            (data["state"] is Map)
                ? Map<String, dynamic>.from(data["state"])
                : const <String, dynamic>{};
        _status = _testMode
            ? "Test mode enabled for all customers. campaign_id=${state["campaign_id"] ?? "-"}"
            : "Enabled for app version $version. campaign_id=${state["campaign_id"] ?? "-"}";
      } else {
        _status = (data["message"] ?? "Failed to enable customer update").toString();
      }
    });
  }

  Future<void> _disableUpdate() async {
    setState(() => _busy = true);
    final data = await _admin.deactivateAppUpdate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data["ok"] == true) {
        _status = "Customer update disabled.";
      } else {
        _status = (data["message"] ?? "Failed to disable customer update")
            .toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Update for Customers"),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _buildInfoCard(
                  title: "Detected App Version",
                  value: _currentVersion.isEmpty ? "Not found" : _currentVersion,
                  subtitle: _buildNumber.isEmpty ? null : "Build $_buildNumber",
                ),
                const SizedBox(height: 10),
                _buildInfoCard(
                  title: "Play Store Link",
                  value: "com.yanaworldwide.shop",
                  subtitle: "System auto-uses the Play Store update link.",
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _forceUpdate,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _forceUpdate = value),
                  title: const Text(
                    "Force Update",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _forceUpdate
                        ? "Customer ko update kiye bina app use nahi karne dega."
                        : "Customer ko update suggestion milega, app use kar sakta hai.",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  activeColor: Colors.orange,
                  tileColor: const Color(0xFF1C1F2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _testMode,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _testMode = value),
                  title: const Text(
                    "Test Mode",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "On rahega to same version wale customers ko bhi popup dikh sakega.",
                    style: TextStyle(color: Colors.white70),
                  ),
                  activeColor: Colors.orange,
                  tileColor: const Color(0xFF1C1F2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _triggerUpdate,
                        child: Text(
                          _testMode
                              ? "Enable Test Popup"
                              : _forceUpdate
                              ? "Enable Force Update"
                              : "Enable Customer Update",
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _disableUpdate,
                        child: const Text("Disable Customer Update"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _composeAppVersion(String version, String buildNumber) {
    final cleanVersion = version.trim();
    final cleanBuild = buildNumber.trim();
    if (cleanVersion.isEmpty) return cleanBuild;
    if (cleanBuild.isEmpty) return cleanVersion;
    return "$cleanVersion+$cleanBuild";
  }
}
