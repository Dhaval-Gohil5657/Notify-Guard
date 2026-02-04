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
              'Notify Guard',
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
          _buildCategoryFilter(context.watch<NotificationProvider>()),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'emergency':
        return AppColors.emergencyCategory;
      case 'otp':
        return AppColors.otpCategory;
      case 'bank':
        return AppColors.bankCategory;
      case 'security':
        return AppColors.securityCategory;
      default:
        return AppColors.primary;
    }
  }

  int _getCategoryCount(String category, NotificationProvider provider) {
    return category == 'all'
        ? provider.notifications.length
        : provider.getCountByCategory(category);
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label, NotificationProvider provider) {
    final isSelected = _selectedCategory == value;
    final color = _getCategoryColor(value);
    final count = _getCategoryCount(value, provider);

    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isSelected ? color : color.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getCategoryIcon(value),
                color: isSelected ? Colors.white : color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: color, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(NotificationProvider provider) {
    return PopupMenuButton<String>(
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      onSelected: (String value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 48),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildFilterItem('all', 'All', provider),
        _buildFilterItem('emergency', 'Emergency', provider),
        _buildFilterItem('otp', 'OTP', provider),
        _buildFilterItem('bank', 'Banking', provider),
        _buildFilterItem('security', 'Security', provider),
      ],
      child: const Padding(
        padding: EdgeInsets.only(right: 15,left: 5),
        child: Icon(Icons.filter_list),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'emergency':
        return Icons.emergency_outlined;
      case 'otp':
        return Icons.pin_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'security':
        return Icons.security_outlined;
      default:
        return Icons.all_inbox_outlined;
    }
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
      case 'emergency':
        return 'Emergency';
      case 'otp':
        return 'OTP';
      case 'bank':
        return 'banking';
      case 'security':
        return 'security';
      default:
        return 'All';
    }
  }

  void _openDetail(
      SavedNotification notification, NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: NotificationDetailScreen(
              notification: notification,
              onMarkAsRead: () => provider.deleteNotification(notification),
            ),
          );
        },
      ),
    );
  }
}
