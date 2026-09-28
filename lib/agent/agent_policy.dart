class AgentPolicy {
  static bool sensitiveText(String text) {
    final q=text.toLowerCase();
    const secrets=['password','passcode','otp','one-time','pin','رمز','کد تایید','کد تأیید','cvv','شماره کارت'];
    return secrets.any(q.contains);
  }
  static bool destructiveIntent(String text) {
    final q=text.toLowerCase();
    const risky=['delete','remove','erase','purchase','buy','pay','transfer','send money','حذف','پاک کن','خرید','پرداخت','انتقال وجه'];
    return risky.any(q.contains);
  }
}
