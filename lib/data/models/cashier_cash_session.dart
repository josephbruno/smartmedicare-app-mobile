class CashierCashSession {
  CashierCashSession({
    required this.id,
    required this.userId,
    this.userName,
    required this.branchId,
    required this.businessDate,
    this.startedAt,
    this.endedAt,
    required this.openingAmount,
    required this.cashCollected,
    required this.expectedClosingAmount,
    this.countedAmount,
    this.variance,
    required this.amountInHand,
    required this.status,
    this.openingNotes,
    this.closingNotes,
    this.dayCloseId,
  });

  final int id;
  final int userId;
  final String? userName;
  final int branchId;
  final String businessDate;
  final String? startedAt;
  final String? endedAt;
  final double openingAmount;
  final double cashCollected;
  final double expectedClosingAmount;
  final double? countedAmount;
  final double? variance;
  final double amountInHand;
  final String status;
  final String? openingNotes;
  final String? closingNotes;
  final int? dayCloseId;

  bool get isOpen => status == 'open';

  factory CashierCashSession.fromJson(Map<String, dynamic> j) {
    return CashierCashSession(
      id: (j['id'] as num?)?.toInt() ?? 0,
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      userName: j['user_name']?.toString(),
      branchId: (j['branch_id'] as num?)?.toInt() ?? 0,
      businessDate: j['business_date']?.toString() ?? '',
      startedAt: j['started_at']?.toString(),
      endedAt: j['ended_at']?.toString(),
      openingAmount: (j['opening_amount'] as num?)?.toDouble() ?? 0,
      cashCollected: (j['cash_collected'] as num?)?.toDouble() ?? 0,
      expectedClosingAmount: (j['expected_closing_amount'] as num?)?.toDouble() ?? 0,
      countedAmount: (j['counted_amount'] as num?)?.toDouble(),
      variance: (j['variance'] as num?)?.toDouble(),
      amountInHand: (j['amount_in_hand'] as num?)?.toDouble() ?? 0,
      status: j['status']?.toString() ?? 'open',
      openingNotes: j['opening_notes']?.toString(),
      closingNotes: j['closing_notes']?.toString(),
      dayCloseId: (j['day_close_id'] as num?)?.toInt(),
    );
  }
}

class CashierCurrentSessionResult {
  CashierCurrentSessionResult({
    this.session,
    required this.businessDate,
    required this.dayClosed,
  });

  final CashierCashSession? session;
  final String businessDate;
  final bool dayClosed;

  factory CashierCurrentSessionResult.fromJson(Map<String, dynamic> j) {
    final sessionMap = j['session'];
    return CashierCurrentSessionResult(
      session: sessionMap is Map
          ? CashierCashSession.fromJson(Map<String, dynamic>.from(sessionMap))
          : null,
      businessDate: j['business_date']?.toString() ?? '',
      dayClosed: j['day_closed'] == true,
    );
  }
}

class CashierDayTotals {
  CashierDayTotals({
    required this.openingAmount,
    required this.cashCollected,
    required this.expectedClosingAmount,
    required this.countedAmount,
    required this.variance,
    required this.amountInHandOpen,
  });

  final double openingAmount;
  final double cashCollected;
  final double expectedClosingAmount;
  final double countedAmount;
  final double variance;
  final double amountInHandOpen;

  factory CashierDayTotals.fromJson(Map<String, dynamic> j) {
    return CashierDayTotals(
      openingAmount: (j['opening_amount'] as num?)?.toDouble() ?? 0,
      cashCollected: (j['cash_collected'] as num?)?.toDouble() ?? 0,
      expectedClosingAmount: (j['expected_closing_amount'] as num?)?.toDouble() ?? 0,
      countedAmount: (j['counted_amount'] as num?)?.toDouble() ?? 0,
      variance: (j['variance'] as num?)?.toDouble() ?? 0,
      amountInHandOpen: (j['amount_in_hand_open'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CashierDayCloseInfo {
  CashierDayCloseInfo({
    required this.id,
    required this.businessDate,
    required this.totalOpeningAmount,
    required this.totalCashCollected,
    required this.totalExpectedClosing,
    required this.totalCountedAmount,
    required this.totalVariance,
    required this.sessionsCount,
    this.notes,
    this.closedBy,
    this.closedAt,
  });

  final int id;
  final String businessDate;
  final double totalOpeningAmount;
  final double totalCashCollected;
  final double totalExpectedClosing;
  final double totalCountedAmount;
  final double totalVariance;
  final int sessionsCount;
  final String? notes;
  final int? closedBy;
  final String? closedAt;

  factory CashierDayCloseInfo.fromJson(Map<String, dynamic> j) {
    return CashierDayCloseInfo(
      id: (j['id'] as num?)?.toInt() ?? 0,
      businessDate: j['business_date']?.toString() ?? '',
      totalOpeningAmount: (j['total_opening_amount'] as num?)?.toDouble() ?? 0,
      totalCashCollected: (j['total_cash_collected'] as num?)?.toDouble() ?? 0,
      totalExpectedClosing: (j['total_expected_closing'] as num?)?.toDouble() ?? 0,
      totalCountedAmount: (j['total_counted_amount'] as num?)?.toDouble() ?? 0,
      totalVariance: (j['total_variance'] as num?)?.toDouble() ?? 0,
      sessionsCount: (j['sessions_count'] as num?)?.toInt() ?? 0,
      notes: j['notes']?.toString(),
      closedBy: (j['closed_by'] as num?)?.toInt(),
      closedAt: j['closed_at']?.toString(),
    );
  }
}

class CashierDayStatus {
  CashierDayStatus({
    required this.businessDate,
    required this.isClosed,
    required this.canClose,
    required this.openSessions,
    required this.sessionsCount,
    required this.totals,
    required this.sessions,
    this.dayClose,
  });

  final String businessDate;
  final bool isClosed;
  final bool canClose;
  final int openSessions;
  final int sessionsCount;
  final CashierDayTotals totals;
  final List<CashierCashSession> sessions;
  final CashierDayCloseInfo? dayClose;

  factory CashierDayStatus.fromJson(Map<String, dynamic> j) {
    final sessionsRaw = j['sessions'];
    final sessions = <CashierCashSession>[];
    if (sessionsRaw is List) {
      for (final item in sessionsRaw) {
        if (item is Map) {
          sessions.add(CashierCashSession.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final dayCloseMap = j['day_close'];
    final totalsMap = j['totals'];
    return CashierDayStatus(
      businessDate: j['business_date']?.toString() ?? '',
      isClosed: j['is_closed'] == true,
      canClose: j['can_close'] == true,
      openSessions: (j['open_sessions'] as num?)?.toInt() ?? 0,
      sessionsCount: (j['sessions_count'] as num?)?.toInt() ?? 0,
      totals: totalsMap is Map
          ? CashierDayTotals.fromJson(Map<String, dynamic>.from(totalsMap))
          : CashierDayTotals(
              openingAmount: 0,
              cashCollected: 0,
              expectedClosingAmount: 0,
              countedAmount: 0,
              variance: 0,
              amountInHandOpen: 0,
            ),
      sessions: sessions,
      dayClose: dayCloseMap is Map
          ? CashierDayCloseInfo.fromJson(Map<String, dynamic>.from(dayCloseMap))
          : null,
    );
  }
}
