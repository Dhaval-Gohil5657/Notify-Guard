class NotificationCategorizer {
  static const List<String> _otpKeywords = [
    'otp', 'verification code', 'verify', 'one-time', 'one time',
    'authentication code', 'security code', 'login code', '2fa',
    'two-factor', 'passcode', 'pin code', 'confirmation code',
  ];

  static const List<String> _bankKeywords = [
    'bank', 'banking', 'credit', 'debit', 'transaction', 'payment', 'upi',
    'credited', 'debited', 'account', 'balance', 'transfer',
    'withdrawn', 'withdraw', 'deposit', 'atm', 'rs.',
  ];

  static const List<String> _emergencyKeywords = [
    'emergency', 'help', 'health', 'sos', 'accident', 'blood',
  ];

  static const List<String> _securityKeywords = [
    'security', 'warning', 'suspicious', 'unauthorized',
    'login attempt', 'new device', 'password changed', 'breach',
  ];

  static const List<String> blockedPackages = [
    'com.android.systemui',
    'android',
  ];

  static bool _containsWord(String content, String keyword) {
    return RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(content);
  }

  static String categorize(String title, String text) {
    final content = '$title $text'.toLowerCase();

    final scores = {
      'otp': _otpKeywords.where((k) => _containsWord(content, k)).length,
      'bank': _bankKeywords.where((k) => _containsWord(content, k)).length,
      'emergency':
          _emergencyKeywords.where((k) => _containsWord(content, k)).length,
      'security':
          _securityKeywords.where((k) => _containsWord(content, k)).length,
    };

    final best = scores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return best.value > 0 ? best.key : 'general';
  }
}
