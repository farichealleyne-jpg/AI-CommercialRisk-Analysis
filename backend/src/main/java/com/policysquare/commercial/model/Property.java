package com.policysquare.commercial.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Data
@Table(name = "properties")
public class Property {

    /** Short property code used to prefix visit and action IDs, e.g. "RR". */
    @Id
    private String code;

    @Column(nullable = false)
    private String name;

    @Column(name = "address_line")
    private String addressLine;

    private String city;

    private String region;

    @Column(name = "mobile_number")
    private String mobileNumber;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private PropertyStatus status;

    @Column(columnDefinition = "TEXT")
    private String notes;

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

    public enum PropertyStatus {
        ACTIVE, INACTIVE
    }
}
