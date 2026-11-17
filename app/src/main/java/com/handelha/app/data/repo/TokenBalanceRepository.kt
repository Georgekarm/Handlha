package com.handelha.app.data.repo

import com.handelha.app.data.local.AppPreferencesStore
import com.handelha.app.domain.TokenBalanceState
import java.util.Calendar
import kotlin.math.max

class TokenBalanceRepository(private val prefs: AppPreferencesStore) {
    private fun todayKey(): String {
        val c = Calendar.getInstance()
        val y = c.get(Calendar.YEAR).toString().padStart(4, '0')
        val m = (c.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = c.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        return "$y-$m-$d"
    }

    suspend fun load(userId: String): TokenBalanceState {
        val snap = prefs.snapshot()
        val today = todayKey()
        val savedDate = snap[prefs.userTokenDateKey(userId)]
        if (savedDate != today) {
            val prevBal = snap[prefs.userTokenBalanceKey(userId)] ?: 0
            val renewed = max(prevBal, TokenBalanceState.DEFAULT_DAILY_ALLOWANCE)
            prefs.update { ed ->
                ed[prefs.userTokenBalanceKey(userId)] = renewed
                ed[prefs.userTokenDateKey(userId)] = today
                ed[prefs.userTokenAdsKey(userId)] = 0
            }
            return TokenBalanceState(
                balance = renewed,
                dailyAllowance = TokenBalanceState.DEFAULT_DAILY_ALLOWANCE,
                lastRenewalDate = today,
                adsWatchedToday = 0,
            )
        }
        val bal = snap[prefs.userTokenBalanceKey(userId)] ?: TokenBalanceState.DEFAULT_DAILY_ALLOWANCE
        val ads = snap[prefs.userTokenAdsKey(userId)] ?: 0
        return TokenBalanceState(
            balance = bal,
            dailyAllowance = TokenBalanceState.DEFAULT_DAILY_ALLOWANCE,
            lastRenewalDate = today,
            adsWatchedToday = ads,
        )
    }

    suspend fun consume(userId: String, cost: Int): Pair<Boolean, TokenBalanceState> {
        val current = load(userId)
        if (current.balance < cost) return false to current
        val nextBal = current.balance - cost
        prefs.update { ed ->
            ed[prefs.userTokenBalanceKey(userId)] = nextBal
            ed[prefs.userTokenDateKey(userId)] = current.lastRenewalDate
        }
        return true to current.copy(balance = nextBal)
    }

    suspend fun rewardFromAd(userId: String): TokenBalanceState {
        val current = load(userId)
        val nextBal = current.balance + TokenBalanceState.GOOGLE_AD_REWARD
        val nextAds = current.adsWatchedToday + 1
        prefs.update { ed ->
            ed[prefs.userTokenBalanceKey(userId)] = nextBal
            ed[prefs.userTokenAdsKey(userId)] = nextAds
            ed[prefs.userTokenDateKey(userId)] = current.lastRenewalDate
        }
        return current.copy(balance = nextBal, adsWatchedToday = nextAds, isLoadingAd = false)
    }
}
