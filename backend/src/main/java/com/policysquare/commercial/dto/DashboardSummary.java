package com.policysquare.commercial.dto;

import lombok.Data;
import java.math.BigDecimal;

/** Aggregate control figures for the property manager dashboard. */
@Data
public class DashboardSummary {
    private long visits;
    private long reportsPending;
    private long reportsOverdue;
    private long openActions;
    private long openSafetyHazards;
    private long overdueActions;
    private long capitalReviews;
    private BigDecimal estimatedOpenCost = BigDecimal.ZERO;
    private long criticalOpen;
    private long highOpen;
    private long mediumOpen;
    private long lowOpen;
}
