import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/saved_notification.dart';

class NotificationDetailScreen extends StatelessWidget {
  final SavedNotification notification;
  final VoidCallback onMarkAsRead;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
  });

  Color get _categoryColor {
    switch (notification.category) {
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

  IconData get _categoryIcon {
    switch (notification.category) {
      case 'otp':
        return Icons.pin_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'security':
        return Icons.security_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        toolbarHeight: 10,
        leading: const Text(''),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSection('Title', notification.title,16),
              const SizedBox(height: 20),
              _buildSection('Content', notification.text,16),
              const SizedBox(height: 20),
              _buildSection('Received on', DateFormat('MMM d, yyyy • h:mm a').format(notification.timestamp),14),
              const SizedBox(height: 16),
              // Mark as Read button at bottom right
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  // padding: EdgeInsets.symmetric(horizontal: 10,vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.success.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4))
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      onMarkAsRead();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.verified, size: 18),
                    label: const Text('Mark as Read'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _categoryColor.withValues(alpha: 0.1),
            _categoryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _categoryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _categoryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _categoryIcon,
              color: _categoryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.appName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _categoryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    notification.categoryDisplayName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content , double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15,vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SelectableText(
            content.isEmpty ? 'No content' : content,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceivedTime() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12,vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200)

      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Received: ${DateFormat('MMM d, yyyy • h:mm a').format(notification.timestamp)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
