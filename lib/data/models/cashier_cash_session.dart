class CashierCashMovement {
  CashierCashMovement({
    required this.id,
    required this.branchId,
    this.cashSessionId,
    this.dayCloseId,
    required this.userId,
    this.userName,
    this.createdBy,
    this.createdByName,
    required this.businessDate,
    required this.type,
    required this.amount,
    this.balanceAfter,
    this.notes,
    this.createdAt,
  });

  final int id;
  final int branchId;
  final int? cashSessionId;
  final int? dayCloseId;
  final int userId;
  final String? userName;
  final int? createdBy;
  final String? createdByName;
  final String businessDate;
  final String type;
  final double amount;
  final double? balanceAfter;
  final String? notes;
  final String? createdAt;

  bool get isCashOut => type == 'cash_out';

  factory CashierCashMovement.fromJson(Map<String, dynamic> j) {
    return CashierCashMovement(
      id: (j['id'] as num?)?.toInt() ?? 0,
      branchId: (j['branch_id'] as num?)?.toInt() ?? 0,
      cashSessionId: (j['cash_session_id'] as num?)?.toInt(),
      dayCloseId: (j['day_close_id'] as num?)?.toInt(),
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      userName: j['user_name']?.toString(),
      createdBy: (j['created_by'] as num?)?.toInt(),
      createdByName: j['created_by_name']?.toString(),
      businessDate: j['business_date']?.toString() ?? '',
      type: j['type']?.toString() ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (j['balance_after'] as num?)?.toDouble(),
      notes: j['notes']?.toString(),
      createdAt: j['created_at']?.toString(),
    );
  }
}

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
    this.cashInTotal = 0,
    this.cashOutTotal = 0,
    required this.expectedClosingAmount,
    this.countedAmount,
    this.variance,
    required this.amountInHand,
    required this.status,
    this.openingNotes,
    this.closingNotes,
    this.dayCloseId,
    this.movements = const [],
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
  final double cashInTotal;
  final double cashOutTotal;
  final double expectedClosingAmount;
  final double? countedAmount;
  final double? variance;
  final double amountInHand;
  final String status;
  final String? openingNotes;
  final String? closingNotes;
  final int? dayCloseId;
  final List<CashierCashMovement> movements;

  bool get isOpen => status == 'open';

  factory CashierCashSession.fromJson(Map<String, dynamic> j) {
    final movementsRaw = j['movements'];
    final movements = <CashierCashMovement>[];
    if (movementsRaw is List) {
      for (final item in movementsRaw) {
        if (item is Map) {
          movements.add(CashierCashMovement.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
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
      cashInTotal: (j['cash_in_total'] as num?)?.toDouble() ?? 0,
      cashOutTotal: (j['cash_out_total'] as num?)?.toDouble() ?? 0,
      expectedClosingAmount: (j['expected_closing_amount'] as num?)?.toDouble() ?? 0,
      countedAmount: (j['counted_amount'] as num?)?.toDouble(),
      variance: (j['variance'] as num?)?.toDouble(),
      amountInHand: (j['amount_in_hand'] as num?)?.toDouble() ?? 0,
      status: j['status']?.toString() ?? 'open',
      openingNotes: j['opening_notes']?.toString(),
      closingNotes: j['closing_notes']?.toString(),
      dayCloseId: (j['day_close_id'] as num?)?.toInt(),
      movements: movements,
    );
  }
}

class CashierCurrentSessionResult {
  CashierCurrentSessionResult({
    this.session,
    required this.businessDate,
    required this.dayClosed,
    this.branchId,
    this.suggestedOpening,
  });

  final CashierCashSession? session;
  final String businessDate;
  final bool dayClosed;
  final int? branchId;
  final CashierSuggestedOpening? suggestedOpening;

  factory CashierCurrentSessionResult.fromJson(Map<String, dynamic> j) {
    final sessionMap = j['session'];
    final suggestedMap = j['suggested_opening'];
    return CashierCurrentSessionResult(
      session: sessionMap is Map
          ? CashierCashSession.fromJson(Map<String, dynamic>.from(sessionMap))
          : null,
      businessDate: j['business_date']?.toString() ?? '',
      dayClosed: j['day_closed'] == true,
      branchId: (j['branch_id'] as num?)?.toInt(),
      suggestedOpening: suggestedMap is Map
          ? CashierSuggestedOpening.fromJson(Map<String, dynamic>.from(suggestedMap))
          : null,
    );
  }
}

class CashierSuggestedOpening {
  CashierSuggestedOpening({
    this.amount,
    required this.source,
    this.label,
    this.previousShiftAmount,
    this.previousShiftDate,
    this.lastDayCloseAmount,
    this.lastDayCloseDate,
    this.lastDayCloseNotes,
  });

  final double? amount;
  final String source; // previous_shift | day_close | none
  final String? label;
  final double? previousShiftAmount;
  final String? previousShiftDate;
  final double? lastDayCloseAmount;
  final String? lastDayCloseDate;
  final String? lastDayCloseNotes;

  bool get hasSuggestion => amount != null;

  factory CashierSuggestedOpening.fromJson(Map<String, dynamic> j) {
    final prev = j['previous_shift'];
    final day = j['last_day_close'];
    Map<String, dynamic>? prevMap;
    Map<String, dynamic>? dayMap;
    if (prev is Map) prevMap = Map<String, dynamic>.from(prev);
    if (day is Map) dayMap = Map<String, dynamic>.from(day);

    return CashierSuggestedOpening(
      amount: (j['amount'] as num?)?.toDouble(),
      source: j['source']?.toString() ?? 'none',
      label: j['label']?.toString(),
      previousShiftAmount: (prevMap?['counted_amount'] as num?)?.toDouble(),
      previousShiftDate: prevMap?['business_date']?.toString(),
      lastDayCloseAmount: (dayMap?['total_counted_amount'] as num?)?.toDouble(),
      lastDayCloseDate: dayMap?['business_date']?.toString(),
      lastDayCloseNotes: dayMap?['notes']?.toString(),
    );
  }
}

class CashierDayTotals {
  CashierDayTotals({
    required this.openingAmount,
    required this.cashCollected,
    this.cashInTotal = 0,
    this.cashOutTotal = 0,
    required this.expectedClosingAmount,
    required this.countedAmount,
    required this.variance,
    required this.amountInHandOpen,
  });

  final double openingAmount;
  final double cashCollected;
  final double cashInTotal;
  final double cashOutTotal;
  final double expectedClosingAmount;
  final double countedAmount;
  final double variance;
  final double amountInHandOpen;

  factory CashierDayTotals.fromJson(Map<String, dynamic> j) {
    return CashierDayTotals(
      openingAmount: (j['opening_amount'] as num?)?.toDouble() ?? 0,
      cashCollected: (j['cash_collected'] as num?)?.toDouble() ?? 0,
      cashInTotal: (j['cash_in_total'] as num?)?.toDouble() ?? 0,
      cashOutTotal: (j['cash_out_total'] as num?)?.toDouble() ?? 0,
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
    this.closedByName,
    this.closedAt,
    this.branchId,
    this.branchName,
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
  final String? closedByName;
  final String? closedAt;
  final int? branchId;
  final String? branchName;

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
      closedByName: j['closed_by_name']?.toString(),
      closedAt: j['closed_at']?.toString(),
      branchId: (j['branch_id'] as num?)?.toInt(),
      branchName: j['branch_name']?.toString(),
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
    this.movements = const [],
    this.dayClose,
    this.branchId,
  });

  final String businessDate;
  final bool isClosed;
  final bool canClose;
  final int openSessions;
  final int sessionsCount;
  final CashierDayTotals totals;
  final List<CashierCashSession> sessions;
  final List<CashierCashMovement> movements;
  final CashierDayCloseInfo? dayClose;
  final int? branchId;

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
    final movementsRaw = j['movements'];
    final movements = <CashierCashMovement>[];
    if (movementsRaw is List) {
      for (final item in movementsRaw) {
        if (item is Map) {
          movements.add(CashierCashMovement.fromJson(Map<String, dynamic>.from(item)));
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
      movements: movements,
      dayClose: dayCloseMap is Map
          ? CashierDayCloseInfo.fromJson(Map<String, dynamic>.from(dayCloseMap))
          : null,
      branchId: (j['branch_id'] as num?)?.toInt(),
    );
  }
}
