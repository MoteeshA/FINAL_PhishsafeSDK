class InputTracker {
  String? lastTransactionAmount;
  DateTime? transactionStartTime;
  DateTime? transactionEndTime;
  DateTime? fdBrokenTime;
  DateTime? loanTakenTime;
  DateTime? loginTime;

  // Called when user starts transaction (e.g., opens transfer screen)
  void markTransactionStart() {
    transactionStartTime = DateTime.now();
    transactionEndTime = null; // Reset end time on new start
  }

  // Called when transaction completes successfully (e.g., after PIN confirmation)
  void markTransactionEnd() {
    transactionEndTime = DateTime.now();
  }

  // Set the transaction amount and optionally mark transaction end if not set
  void setTransactionAmount(String amount) {
    lastTransactionAmount = amount;
    transactionEndTime ??= DateTime.now();
  }

  // Get the last transaction amount, if any
  String? getTransactionAmount() => lastTransactionAmount;

  // Mark the user login time
  void markLogin() {
    loginTime = DateTime.now();
  }

  // Mark fixed deposit broken time
  void markFDBroken() {
    fdBrokenTime = DateTime.now();
  }

  // Check if FD is broken
  bool get isFDBroken => fdBrokenTime != null;

  // Mark loan taken time
  void markLoanTaken() {
    loanTakenTime = DateTime.now();
  }

  // Check if loan is taken
  bool get isLoanTaken => loanTakenTime != null;

  // Duration from login to FD broken
  Duration? get timeFromLoginToFD =>
      (loginTime != null && fdBrokenTime != null)
          ? fdBrokenTime!.difference(loginTime!)
          : null;

  // Duration from login to loan taken
  Duration? get timeFromLoginToLoan =>
      (loginTime != null && loanTakenTime != null)
          ? loanTakenTime!.difference(loginTime!)
          : null;

  // Removed as requested: Duration between FD and loan
  // Duration? get timeBetweenFDAndLoan => ...

  // Duration it took the user to complete the transaction (start to end)
  Duration? get timeToCompleteTransaction =>
      (transactionStartTime != null && transactionEndTime != null)
          ? transactionEndTime!.difference(transactionStartTime!)
          : null;

  // Duration from login to transaction start
  Duration? get timeFromLoginToTransactionStart =>
      (loginTime != null && transactionStartTime != null)
          ? transactionStartTime!.difference(loginTime!)
          : null;

  // Reset all tracking data
  void reset() {
    lastTransactionAmount = null;
    transactionStartTime = null;
    transactionEndTime = null;
    fdBrokenTime = null;
    loanTakenTime = null;
    loginTime = null;
  }
}
