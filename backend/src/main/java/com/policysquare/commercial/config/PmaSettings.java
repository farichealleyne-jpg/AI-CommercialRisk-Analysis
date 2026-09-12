package com.policysquare.commercial.config;

import java.math.BigDecimal;

/**
 * Control settings drawn from the Property Management Agreement. These govern
 * report timing and when work has to go through the capital-approval process.
 */
public final class PmaSettings {

    /** Attendance report is due this many calendar days after the visit. */
    public static final int REPORT_DUE_DAYS = 5;

    /** Work expected to exceed this amount requires the PMA capital-work process. */
    public static final BigDecimal CAPITAL_REVIEW_THRESHOLD = new BigDecimal("10000");

    private PmaSettings() {
    }
}
