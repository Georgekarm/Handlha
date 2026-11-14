import 'dart:math' as math;

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/presentation/auth_providers.dart';

class TokenBalanceState {
  const TokenBalanceState({
    required this.balance,
    required this.dailyAllowance,
    required this.lastRenewalDate,
    required this.adsWatchedToday,
    this.isLoadingAd = false,
  });

  static const int defaultDailyAllowance = 50;
  static const int textMessageCost = 2;
  static const int voiceMessageCost = 5;
  static const int googleAdReward = 15;

  final int balance;
  final int dailyAllowance;
  final String lastRenewalDate;
  final int adsWatchedToday;
  final bool isLoadingAd;

  bool get canSendText => balance >= textMessageCost;
  bool get canSendVoice => balance >= voiceMessageCost;

  double get fillRatio =>
      dailyAllowance <= 0 ? 0.0 : (balance / dailyAllowance).clamp(0.0, 1.0);

  TokenBalanceState copyWith({
    int? balance,
    int? dailyAllowance,
    String? lastRenewalDate,
    int? adsWatchedToday,
    bool? isLoadingAd,
  }) {
    return TokenBalanceState(
      balance: balance ?? this.balance,
      dailyAllowance: dailyAllowance ?? this.dailyAllowance,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      adsWatchedToday: adsWatchedToday ?? this.adsWatchedToday,
      isLoadingAd: isLoadingAd ?? this.isLoadingAd,
    );
  }
}

class TokenBalanceNotifier extends StateNotifier<TokenBalanceState> {
  TokenBalanceNotifier({required String userId})
      // ignore: prefer_initializing_formals
      : _userId = userId,
        super(
          TokenBalanceState(
            balance: TokenBalanceState.defaultDailyAllowance,
            dailyAllowance: TokenBalanceState.defaultDailyAllowance,
            lastRenewalDate: _todayKey(),
            adsWatchedToday: 0,
          ),
        ) {
    _load();
  }

  final String _userId;

  String get _balKey => 'handelha_tokens_balance_$_userId';
  String get _dateKey => 'handelha_tokens_date_$_userId';
  String get _adsKey => 'handelha_tokens_ads_$_userId';

  static String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final savedDate = prefs.getString(_dateKey);
      if (savedDate != today) {
        // Automatic daily renewal
        final current = prefs.getInt(_balKey) ?? 0;
        final renewed = math.max(current, TokenBalanceState.defaultDailyAllowance);
        await prefs.setInt(_balKey, renewed);
        await prefs.setString(_dateKey, today);
        await prefs.setInt(_adsKey, 0);
        if (mounted) {
          state = state.copyWith(
            balance: renewed,
            lastRenewalDate: today,
            adsWatchedToday: 0,
          );
        }
      } else {
        final savedBal =
            prefs.getInt(_balKey) ?? TokenBalanceState.defaultDailyAllowance;
        final savedAds = prefs.getInt(_adsKey) ?? 0;
        if (mounted) {
          state = state.copyWith(
            balance: savedBal,
            lastRenewalDate: savedDate ?? today,
            adsWatchedToday: savedAds,
          );
        }
      }
    } catch (_) {
      // Fallback to in-memory default if SharedPreferences unavailable
    }
  }

  Future<bool> consumeTextToken() =>
      _consume(TokenBalanceState.textMessageCost);

  Future<bool> consumeVoiceToken() =>
      _consume(TokenBalanceState.voiceMessageCost);

  Future<bool> _consume(int cost) async {
    await _ensureDailyRenewal();
    if (state.balance < cost) return false;
    final next = state.balance - cost;
    state = state.copyWith(balance: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_balKey, next);
      await prefs.setString(_dateKey, state.lastRenewalDate);
    } catch (_) {}
    return true;
  }

  Future<void> rewardFromGoogleAd() async {
    await _ensureDailyRenewal();
    final nextBal = state.balance + TokenBalanceState.googleAdReward;
    final nextAds = state.adsWatchedToday + 1;
    state = state.copyWith(
      balance: nextBal,
      adsWatchedToday: nextAds,
      isLoadingAd: false,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_balKey, nextBal);
      await prefs.setInt(_adsKey, nextAds);
      await prefs.setString(_dateKey, state.lastRenewalDate);
    } catch (_) {}
  }

  Future<void> _ensureDailyRenewal() async {
    final today = _todayKey();
    if (state.lastRenewalDate != today) {
      final renewed =
          math.max(state.balance, TokenBalanceState.defaultDailyAllowance);
      state = state.copyWith(
        balance: renewed,
        lastRenewalDate: today,
        adsWatchedToday: 0,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_balKey, renewed);
        await prefs.setString(_dateKey, today);
        await prefs.setInt(_adsKey, 0);
      } catch (_) {}
    }
  }
}

final tokenBalanceProvider =
    StateNotifierProvider<TokenBalanceNotifier, TokenBalanceState>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  return TokenBalanceNotifier(userId: user?.id ?? 'guest');
});
