/// Pure-Dart Phase 5 Unit Economics & Single-Channel Acquisition Gate Engine.
///
/// Enforces the Review Board's commercial discipline:
/// - Paid scaling is **blocked automatically** unless Phase 4b D28 retention gate passed.
/// - Accounts for Google Play Store fees (15% Small Business tier or 30% standard),
///   refunds, variable support/hosting cost, CAC per retained active user & per paid customer,
///   payback period, and contribution LTV:CAC ratio.
enum MonetizationGateDecision {
  blockedByPhase4bRetention,
  goScaleChannel,
  iteratePricingOrChannel,
  stopDoNotScale,
}

class UnitEconomicsInput {
  const UnitEconomicsInput({
    required this.channelName,
    required this.currency,
    required this.phase4bD28GatePassed,
    required this.channelSpend,
    required this.installedUsers,
    required this.activatedUsers,
    required this.retainedD28Users,
    required this.paidSubscribers,
    this.refundedSubscribers = 0,
    required this.grossPricePerPeriod,
    this.isAnnualPlan = false,
    this.googlePlayFeeRate = 0.15,
    this.monthlySupportCostPerPaidUser = 0.0,
    this.expectedPaidLifetimeMonths = 3.0,
  });

  final String channelName;
  final String currency;
  final bool phase4bD28GatePassed;
  final double channelSpend;
  final int installedUsers;
  final int activatedUsers;
  final int retainedD28Users;
  final int paidSubscribers;
  final int refundedSubscribers;
  final double grossPricePerPeriod;
  final bool isAnnualPlan;
  final double googlePlayFeeRate;
  final double monthlySupportCostPerPaidUser;
  final double expectedPaidLifetimeMonths;

  factory UnitEconomicsInput.fromJson(Map<String, dynamic> json) {
    return UnitEconomicsInput(
      channelName: (json['channelName'] ?? 'unspecified').toString(),
      currency: (json['currency'] ?? 'EGP').toString(),
      phase4bD28GatePassed: json['phase4bD28GatePassed'] == true,
      channelSpend: (json['channelSpend'] as num?)?.toDouble() ?? 0.0,
      installedUsers: (json['installedUsers'] as num?)?.toInt() ?? 0,
      activatedUsers: (json['activatedUsers'] as num?)?.toInt() ?? 0,
      retainedD28Users: (json['retainedD28Users'] as num?)?.toInt() ?? 0,
      paidSubscribers: (json['paidSubscribers'] as num?)?.toInt() ?? 0,
      refundedSubscribers: (json['refundedSubscribers'] as num?)?.toInt() ?? 0,
      grossPricePerPeriod:
          (json['grossPricePerPeriod'] as num?)?.toDouble() ?? 0.0,
      isAnnualPlan: json['isAnnualPlan'] == true,
      googlePlayFeeRate:
          (json['googlePlayFeeRate'] as num?)?.toDouble() ?? 0.15,
      monthlySupportCostPerPaidUser:
          (json['monthlySupportCostPerPaidUser'] as num?)?.toDouble() ?? 0.0,
      expectedPaidLifetimeMonths:
          (json['expectedPaidLifetimeMonths'] as num?)?.toDouble() ?? 3.0,
    );
  }
}

class UnitEconomicsReport {
  const UnitEconomicsReport({
    required this.input,
    required this.netPaidSubscribers,
    required this.refundRate,
    required this.activationRate,
    required this.d28RetentionRate,
    required this.activatedToPaidConversion,
    required this.cacPerInstall,
    required this.cacPerActivatedUser,
    required this.cacPerRetainedUser,
    required this.cacPerPaidCustomer,
    required this.netRevenuePerPeriod,
    required this.monthlyNetContributionPerPaidUser,
    required this.contributionLtv,
    required this.ltvToCacRatio,
    required this.paybackMonths,
    required this.netCohortContribution,
    required this.decision,
    required this.reasons,
  });

  final UnitEconomicsInput input;
  final int netPaidSubscribers;
  final double refundRate;
  final double activationRate;
  final double d28RetentionRate;
  final double activatedToPaidConversion;
  final double cacPerInstall;
  final double cacPerActivatedUser;
  final double cacPerRetainedUser;
  final double cacPerPaidCustomer;
  final double netRevenuePerPeriod;
  final double monthlyNetContributionPerPaidUser;
  final double contributionLtv;
  final double ltvToCacRatio;
  final double paybackMonths;
  final double netCohortContribution;
  final MonetizationGateDecision decision;
  final List<String> reasons;

  String toMarkdownReport() {
    String money(double v) => '${v.toStringAsFixed(2)} ${input.currency}';
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final b = StringBuffer()
      ..writeln('# Handelha Phase 5 Unit Economics & Channel Gate Report')
      ..writeln('- **Channel:** `${input.channelName}`')
      ..writeln(
        '- **Phase 4b D28 Retention Gate Passed:** `${input.phase4bD28GatePassed}`',
      )
      ..writeln('- **Gate Decision:** `${decision.name}`')
      ..writeln()
      ..writeln('## Gate Rationale');
    for (final r in reasons) {
      b.writeln('- $r');
    }
    b
      ..writeln()
      ..writeln('## Funnel & Conversion')
      ..writeln(
        '- **Installs -> Activated:** ${pct(activationRate)} (${input.activatedUsers}/${input.installedUsers})',
      )
      ..writeln(
        '- **D28 Retention (of Activated):** ${pct(d28RetentionRate)} (${input.retainedD28Users}/${input.activatedUsers})',
      )
      ..writeln(
        '- **Activated -> Net Paid Conversion:** ${pct(activatedToPaidConversion)} ($netPaidSubscribers/${input.activatedUsers}, refunds: ${input.refundedSubscribers}, refund rate: ${pct(refundRate)})',
      )
      ..writeln()
      ..writeln('## Acquisition Cost & Contribution Margin')
      ..writeln('- **Total Channel Spend:** ${money(input.channelSpend)}')
      ..writeln('- **CAC / Install:** ${money(cacPerInstall)}')
      ..writeln('- **CAC / Activated User:** ${money(cacPerActivatedUser)}')
      ..writeln('- **CAC / Retained D28 User:** ${money(cacPerRetainedUser)}')
      ..writeln('- **CAC / Net Paid Customer:** ${money(cacPerPaidCustomer)}')
      ..writeln(
        '- **Net Revenue / Period (after ${(input.googlePlayFeeRate * 100).toStringAsFixed(0)}% Play fee):** ${money(netRevenuePerPeriod)}',
      )
      ..writeln(
        '- **Monthly Contribution / Paid User:** ${money(monthlyNetContributionPerPaidUser)}',
      )
      ..writeln(
        '- **Estimated Contribution LTV (${input.expectedPaidLifetimeMonths.toStringAsFixed(1)} mo):** ${money(contributionLtv)}',
      )
      ..writeln('- **LTV : CAC Ratio:** ${ltvToCacRatio.toStringAsFixed(2)}x')
      ..writeln(
        '- **Payback Period:** ${paybackMonths.isInfinite ? 'N/A (non-positive margin)' : '${paybackMonths.toStringAsFixed(1)} months'}',
      )
      ..writeln(
        '- **Net Cohort Contribution (LTV × Net Paid - Spend):** ${money(netCohortContribution)}',
      );
    return b.toString();
  }
}

class UnitEconomicsCalculator {
  const UnitEconomicsCalculator._();

  static UnitEconomicsReport evaluate(UnitEconomicsInput input) {
    final netPaid =
        (input.paidSubscribers - input.refundedSubscribers).clamp(0, 1 << 30);
    final refundRate = input.paidSubscribers == 0
        ? 0.0
        : (input.refundedSubscribers / input.paidSubscribers).clamp(0.0, 1.0);
    final activationRate = input.installedUsers == 0
        ? 0.0
        : (input.activatedUsers / input.installedUsers).clamp(0.0, 1.0);
    final d28Rate = input.activatedUsers == 0
        ? 0.0
        : (input.retainedD28Users / input.activatedUsers).clamp(0.0, 1.0);
    final conversionRate = input.activatedUsers == 0
        ? 0.0
        : (netPaid / input.activatedUsers).clamp(0.0, 1.0);

    final cacInstall =
        input.installedUsers == 0 ? 0.0 : input.channelSpend / input.installedUsers;
    final cacActivated =
        input.activatedUsers == 0 ? 0.0 : input.channelSpend / input.activatedUsers;
    final cacRetained = input.retainedD28Users == 0
        ? 0.0
        : input.channelSpend / input.retainedD28Users;
    final cacPaid = netPaid == 0 ? double.infinity : input.channelSpend / netPaid;

    final fee = input.googlePlayFeeRate.clamp(0.0, 0.50);
    final netRevPerPeriod = input.grossPricePerPeriod * (1.0 - fee);
    final monthsPerPeriod = input.isAnnualPlan ? 12.0 : 1.0;
    final monthlyNetRev = netRevPerPeriod / monthsPerPeriod;
    final monthlyContrib = monthlyNetRev - input.monthlySupportCostPerPaidUser;
    final effectiveMonths = input.isAnnualPlan
        ? (input.expectedPaidLifetimeMonths < 12.0
            ? 12.0
            : input.expectedPaidLifetimeMonths)
        : input.expectedPaidLifetimeMonths;
    final ltv = monthlyContrib <= 0 ? 0.0 : monthlyContrib * effectiveMonths;

    final ltvToCac = (cacPaid == 0)
        ? (ltv > 0 ? double.infinity : 0.0)
        : (cacPaid.isInfinite ? 0.0 : ltv / cacPaid);
    final payback = (monthlyContrib <= 0 || cacPaid.isInfinite)
        ? double.infinity
        : (cacPaid / monthlyContrib);
    final netCohort = (netPaid * ltv) - input.channelSpend;

    final reasons = <String>[];
    MonetizationGateDecision decision;

    if (!input.phase4bD28GatePassed) {
      decision = MonetizationGateDecision.blockedByPhase4bRetention;
      reasons.add(
        'BLOCKED: Phase 4b D28 retention gate has not passed. Per Review Board rules, do NOT run paid acquisition campaigns before proving organic retention.',
      );
    } else if (netPaid == 0) {
      decision = MonetizationGateDecision.stopDoNotScale;
      reasons.add(
        'STOP: Zero net paid conversions recorded on `${input.channelName}`. Do not expand acquisition spend without real paying transactions.',
      );
    } else if (monthlyContrib <= 0 || netCohort < 0) {
      decision = MonetizationGateDecision.stopDoNotScale;
      reasons.add(
        'STOP: Contribution margin (${ltv.toStringAsFixed(2)} ${input.currency} LTV) does not cover CAC (${cacPaid.toStringAsFixed(2)} ${input.currency}) and support costs.',
      );
    } else if (refundRate > 0.15) {
      decision = MonetizationGateDecision.iteratePricingOrChannel;
      reasons.add(
        'ITERATE: Refund rate ${(refundRate * 100).toStringAsFixed(1)}% (> 15%) indicates expectation mismatch.',
      );
    } else if ((ltvToCac >= 2.0 || input.channelSpend == 0) &&
        netPaid >= 5 &&
        payback <= 6.0) {
      decision = MonetizationGateDecision.goScaleChannel;
      reasons.add(
        'GO: $netPaid net paid subscribers with positive contribution margin (LTV:CAC = ${ltvToCac.isInfinite ? 'Organic ∞' : '${ltvToCac.toStringAsFixed(2)}x'}, payback = ${payback.toStringAsFixed(1)} mo). Safe to scale `${input.channelName}` cautiously.',
      );
    } else {
      decision = MonetizationGateDecision.iteratePricingOrChannel;
      reasons.add(
        'ITERATE: Positive margin but sample size ($netPaid net paid), LTV:CAC (${ltvToCac.toStringAsFixed(2)}x), or payback (${payback.toStringAsFixed(1)} mo) needs refinement before scaling.',
      );
    }

    return UnitEconomicsReport(
      input: input,
      netPaidSubscribers: netPaid,
      refundRate: refundRate,
      activationRate: activationRate,
      d28RetentionRate: d28Rate,
      activatedToPaidConversion: conversionRate,
      cacPerInstall: cacInstall,
      cacPerActivatedUser: cacActivated,
      cacPerRetainedUser: cacRetained,
      cacPerPaidCustomer: cacPaid.isInfinite ? 0.0 : cacPaid,
      netRevenuePerPeriod: netRevPerPeriod,
      monthlyNetContributionPerPaidUser: monthlyContrib,
      contributionLtv: ltv,
      ltvToCacRatio: ltvToCac.isInfinite ? 999.0 : ltvToCac,
      paybackMonths: payback,
      netCohortContribution: netCohort,
      decision: decision,
      reasons: reasons,
    );
  }
}
