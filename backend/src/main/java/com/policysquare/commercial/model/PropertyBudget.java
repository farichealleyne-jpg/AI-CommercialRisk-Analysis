package com.policysquare.commercial.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Data
@Table(name = "property_budgets")
public class PropertyBudget {

    @Id
    private String id;

    @Column(name = "mobile_number")
    private String mobileNumber;

    @Column(name = "property_address")
    private String propertyAddress;

    @Column(name = "risk_assessment_id")
    private String riskAssessmentId; // Optional link to an inspection/risk assessment

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private BudgetStatus status;

    @Column(name = "total_estimated_cost", precision = 15, scale = 2)
    private BigDecimal totalEstimatedCost;

    @Column(columnDefinition = "TEXT")
    private String data; // JSON array of repair/maintenance line items

    @Column(updatable = false)
    @com.fasterxml.jackson.annotation.JsonFormat(shape = com.fasterxml.jackson.annotation.JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt = LocalDateTime.now();

    public LocalDateTime getCreatedAt() {
        return createdAt != null ? createdAt : LocalDateTime.now();
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }

    public enum BudgetStatus {
        DRAFT, FINALIZED
    }
}
