package com.policysquare.commercial.repository;

import com.policysquare.commercial.model.PropertyBudget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PropertyBudgetRepository extends JpaRepository<PropertyBudget, String> {
    List<PropertyBudget> findByMobileNumberOrderByCreatedAtDesc(String mobileNumber);
}
