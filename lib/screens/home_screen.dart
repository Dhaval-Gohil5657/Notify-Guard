import 'package:flutter/material.dart';
import 'package:notify_guard/widgets/Loader.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/notification_provider.dart';
import '../models/saved_notification.dart';
import 'notification_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/notification_card.dart';
import '../widgets/category_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationProvider>().checkNotificationAccess();
    }
  }

  Future<void> _checkPermissions() async {
    final provider = context.read<NotificationProvider>();
    final hasAccess = await provider.checkNotificationAccess();
    if (!hasAccess && mounted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required'),
        content: const Text(
          'NotifyGuard needs notification access to capture and save important notifications like OTPs, bank alerts, and security warnings.\n\nPlease enable notification access in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotificationProvider>().openNotificationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/notify_guard.png',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'NotifyGuard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (!provider.isInitialized) {
            return const Center(
              child: BouncingDotsLoader(),
            );
          }

          return Column(
            children: [
              if (!provider.hasNotificationAccess)
              _buildStatusBanner(provider),
              _buildCategoryFilter(provider),
              Expanded(child: _buildNotificationList(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(NotificationProvider provider) {
    return GestureDetector(
      onTap: () => provider.openNotificationSettings(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(color: AppColors.warning.withOpacity(0.2)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Notification access required. Tap to enable.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: AppColors.warning, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(NotificationProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CategoryChip(
              label: 'All',
              count: provider.notifications.length,
              isSelected: _selectedCategory == 'all',
              color: AppColors.primary,
              onTap: () => setState(() => _selectedCategory = 'all'),
            ),
            const SizedBox(width: 10),
            CategoryChip(
              label: 'OTP',
              count: provider.getCountByCategory('otp'),
              isSelected: _selectedCategory == 'otp',
              color: AppColors.otpCategory,
              onTap: () => setState(() => _selectedCategory = 'otp'),
            ),
            const SizedBox(width: 10),
            CategoryChip(
              label: 'Banking',
              count: provider.getCountByCategory('bank'),
              isSelected: _selectedCategory == 'bank',
              color: AppColors.bankCategory,
              onTap: () => setState(() => _selectedCategory = 'bank'),
            ),
            const SizedBox(width: 10),
            CategoryChip(
              label: 'Security',
              count: provider.getCountByCategory('security'),
              isSelected: _selectedCategory == 'security',
              color: AppColors.securityCategory,
              onTap: () => setState(() => _selectedCategory = 'security'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    final notifications = _selectedCategory == 'all'
        ? provider.notifications
        : provider.getByCategory(_selectedCategory);

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 50,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedCategory == 'all'
                  ? 'No notifications yet'
                  : 'No ${_getCategoryName()} notifications',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Critical notifications will appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return NotificationCard(
            notification: notification,
            onTap: () => _openDetail(notification, provider),
            onMarkAsRead: () => provider.deleteNotification(notification),
          );
        },
      ),
    );
  }

  String _getCategoryName() {
    switch (_selectedCategory) {
      case 'otp':
        return 'OTP';
      case 'bank':
        return 'banking';
      case 'security':
        return 'security';
      default:
        return '';
    }
  }

  void _openDetail(
      SavedNotification notification, NotificationProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          notification: notification,
          onMarkAsRead: () => provider.deleteNotification(notification),
        ),
      ),
    );
  }
}
