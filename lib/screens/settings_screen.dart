import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/notification_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Settings',style: TextStyle(fontWeight: FontWeight.bold),),
        leading: IconButton(onPressed: (){
          Navigator.of(context).pop();
        }, icon: Icon(Icons.arrow_back_ios)),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Notification Access Section
              _buildSectionHeader('Notification Access'),
              _buildSettingCard(
                icon: Icons.notifications_active_outlined,
                title: 'Notification Listener',
                subtitle: provider.hasNotificationAccess
                    ? 'Enabled - Listening for notifications'
                    : 'Disabled - Tap to enable',
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: provider.hasNotificationAccess
                        ? AppColors.success
                        : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => provider.openNotificationSettings(),
              ),
              const SizedBox(height: 8),
              _buildSettingCard(
                icon: Icons.autorenew_outlined,
                title: 'Background Autostart',
                subtitle: 'Required to capture notifications when app is closed',
                onTap: () => _showAutostartGuide(context),
              ),
              const SizedBox(height: 20),

              // Data Management Section
              _buildSectionHeader('Data Management'),
              _buildSettingCard(
                icon: Icons.delete_sweep_outlined,
                title: 'Delete Old Notifications',
                subtitle: 'Remove notifications older than 30 days',
                onTap: () => _showDeleteOldDialog(context, provider),
              ),
              const SizedBox(height: 8),
              _buildSettingCard(
                icon: Icons.delete_forever_outlined,
                title: 'Clear All Notifications',
                subtitle: 'Delete all saved notifications',
                iconColor: AppColors.error,
                onTap: () => _showClearAllDialog(context, provider),
              ),
              const SizedBox(height: 20),
              // About Section
              _buildSectionHeader('Data Privacy'),
              _buildSettingCard(
                icon: Icons.shield_outlined,
                title: 'Privacy and Security',
                subtitle: 'How we protect your data',
                onTap: () => _showPrivacyDialog(context),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('About'),
              _buildSettingCard(
                icon: Icons.info_outline,
                title: 'About NotifyGuard',
                subtitle: 'Version 1.0.0',
                onTap: () => _showAboutDialog(context),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: trailing ??
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteOldDialog(
      BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Old Notifications',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 22)),
        content: const Text(
          'This will delete all notifications older than 30 days. This action cannot be undone.',
            style: TextStyle(fontWeight: FontWeight.w500,color: AppColors.textSecondary)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteOldNotifications(30);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Old notifications deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(
      BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 22)),
        content: const Text(
          'This will permanently delete all saved notifications. This action cannot be undone.',
            style: TextStyle(fontWeight: FontWeight.w500,color: AppColors.textSecondary)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              provider.deleteAllNotifications();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All notifications deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showAutostartGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enable Background Autostart',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To capture notifications even when the app is closed, enable Autostart for NotifyGuard.',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Steps:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Open device Settings\n'
              '2. Go to Apps > NotifyGuard\n'
              '3. Look for "Autostart" or "Background autostart"\n'
              '4. Enable it',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Note: The setting name and location may vary depending on your device manufacturer.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy and Security',style: TextStyle(fontWeight: FontWeight.w600),),
        content: const Text(
          'Your privacy is our top priority. NotifyGuard operates entirely on your device.\n\nAll your notifications are stored locally and are never sent to any server. This means only you have access to your information.',
            style: TextStyle(fontWeight: FontWeight.w500,color: AppColors.textSecondary),),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Image.asset(
              'assets/notify_guard.png',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'NotifyGuard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Never miss important notifications.\nCaptures OTPs, bank alerts, and security warnings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
                fontWeight: FontWeight.w500
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
