package com.policysquare.commercial.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.policysquare.commercial.config.PmaSettings;
import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * A deficiency or follow-up item raised by an inspection visit, tracked from
 * discovery through quote, approval, completion and verification.
 */
@Entity
@Data
@Table(name = "action_items")
public class ActionItem {

    /** Stable action reference, e.g. "RR-20260912-01". */
    @Id
    private String id;

    @Column(name = "visit_id")
    private String visitId;

    @Column(name = "property_code", nullable = false)
    private String propertyCode;

    private String location;

    private String category;

    @Column(columnDefinition = "TEXT")
    private String issue;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private Priority priority;

    @Column(name = "safety_hazard")
    private Boolean safetyHazard = false;

    @Column(name = "immediate_control", columnDefinition = "TEXT")
    private String immediateControl;

    @Column(name = "responsible_party")
    private String responsibleParty;

    @Column(name = "tenant_unit")
    private String tenantUnit;

    @Column(name = "lease_review")
    private Boolean leaseReview = false;

    @Column(name = "action_owner")
    private String actionOwner;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private ActionStatus status;

    @Column(name = "target_completion")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate targetCompletion;

    @Column(name = "completion_date")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate completionDate;

    @Column(name = "verified_by")
    private String verifiedBy;

    @Column(name = "estimated_cost", precision = 15, scale = 2)
    private BigDecimal estimatedCost;

    @Column(name = "cost_classification")
    @Enumerated(EnumType.STRING)
    private CostClassification costClassification;

    @Column(name = "approval_status")
    @Enumerated(EnumType.STRING)
    private ApprovalStatus approvalStatus;

    @Column(name = "vendor_ref")
    private String vendorRef;

    @Column(name = "evidence_link")
    private String evidenceLink;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "mobile_number")
    private String mobileNumber;

    @Column(updatable = false)
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt = LocalDateTime.now();

    public LocalDateTime getCreatedAt() {
        return createdAt != null ? createdAt : LocalDateTime.now();
    }

    /** Work above the PMA threshold cannot proceed on operating approval alone. */
    @Transient
    public boolean isRequiresCapitalReview() {
        return estimatedCost != null
                && estimatedCost.compareTo(PmaSettings.CAPITAL_REVIEW_THRESHOLD) > 0;
    }

    @Transient
    public boolean isOpen() {
        return status != ActionStatus.CLOSED;
    }

    @Transient
    public boolean isOverdue() {
        return isOpen()
                && targetCompletion != null
                && LocalDate.now().isAfter(targetCompletion);
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }

    public enum Priority {
        CRITICAL, HIGH, MEDIUM, LOW
    }

    public enum ActionStatus {
        OPEN, QUOTE_REQUESTED, APPROVED, IN_PROGRESS, VERIFIED, CLOSED
    }

    public enum CostClassification {
        OPERATING, CAPITAL
    }

    public enum ApprovalStatus {
        NOT_REQUIRED, PENDING, APPROVED, DECLINED
    }
}
