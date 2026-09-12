package com.policysquare.commercial.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.policysquare.commercial.config.PmaSettings;
import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Data
@Table(name = "inspection_visits")
public class InspectionVisit {

    /** Stable visit reference, e.g. "RR-20260912-1". */
    @Id
    private String id;

    @Column(name = "property_code", nullable = false)
    private String propertyCode;

    @Column(name = "visit_date")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate visitDate;

    private String inspector;

    @Column(name = "inspection_type")
    private String inspectionType;

    @Column(name = "weather_conditions")
    private String weatherConditions;

    @Column(name = "report_due_date")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate reportDueDate;

    @Column(name = "report_sent_date")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate reportSentDate;

    @Column(name = "sent_to")
    private String sentTo;

    @Column(name = "report_link")
    private String reportLink;

    @Column(name = "areas_inspected", columnDefinition = "TEXT")
    private String areasInspected;

    @Column(name = "overall_condition", columnDefinition = "TEXT")
    private String overallCondition;

    @Column(name = "operations_summary", columnDefinition = "TEXT")
    private String operationsSummary;

    @Column(name = "revenue_expense_issues", columnDefinition = "TEXT")
    private String revenueExpenseIssues;

    @Column(name = "immediate_actions", columnDefinition = "TEXT")
    private String immediateActions;

    @Column(name = "decisions_required", columnDefinition = "TEXT")
    private String decisionsRequired;

    @Column(name = "mobile_number")
    private String mobileNumber;

    @Column(updatable = false)
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt = LocalDateTime.now();

    public LocalDateTime getCreatedAt() {
        return createdAt != null ? createdAt : LocalDateTime.now();
    }

    /**
     * Reporting compliance against the PMA window. Derived on read so it stays
     * true as dates pass rather than going stale in the database.
     */
    @Transient
    public ReportStatus getReportStatus() {
        if (reportSentDate != null) {
            return ReportStatus.SENT;
        }
        if (reportDueDate != null && LocalDate.now().isAfter(reportDueDate)) {
            return ReportStatus.OVERDUE;
        }
        return ReportStatus.PENDING;
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (reportDueDate == null && visitDate != null) {
            reportDueDate = visitDate.plusDays(PmaSettings.REPORT_DUE_DAYS);
        }
    }

    public enum ReportStatus {
        PENDING, SENT, OVERDUE
    }
}
