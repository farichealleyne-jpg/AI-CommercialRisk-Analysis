package com.policysquare.commercial.service;

import com.policysquare.commercial.model.PropertyBudget;
import com.policysquare.commercial.repository.PropertyBudgetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PropertyBudgetService {

    private final PropertyBudgetRepository repository;

    public synchronized PropertyBudget createBudget(PropertyBudget budget) {
        if (budget.getStatus() == null) {
            budget.setStatus(PropertyBudget.BudgetStatus.DRAFT);
        }
        if (budget.getId() == null || budget.getId().isEmpty()) {
            long count = repository.count();
            budget.setId(String.format("BUD%03d", count + 1));
        }
        return repository.save(budget);
    }

    public List<PropertyBudget> getBudgetsByMobileNumber(String mobileNumber) {
        return repository.findByMobileNumberOrderByCreatedAtDesc(mobileNumber);
    }

    public PropertyBudget getBudgetById(String id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Property budget not found with id " + id));
    }

    public PropertyBudget updateBudget(String id, PropertyBudget updatedBudget) {
        return repository.findById(id)
                .map(existing -> {
                    if (updatedBudget.getPropertyAddress() != null) {
                        existing.setPropertyAddress(updatedBudget.getPropertyAddress());
                    }
                    if (updatedBudget.getRiskAssessmentId() != null) {
                        existing.setRiskAssessmentId(updatedBudget.getRiskAssessmentId());
                    }
                    if (updatedBudget.getData() != null) {
                        existing.setData(updatedBudget.getData());
                    }
                    if (updatedBudget.getTotalEstimatedCost() != null) {
                        existing.setTotalEstimatedCost(updatedBudget.getTotalEstimatedCost());
                    }
                    if (updatedBudget.getStatus() != null) {
                        existing.setStatus(updatedBudget.getStatus());
                    }
                    return repository.save(existing);
                })
                .orElseThrow(() -> new RuntimeException("Property budget not found with id " + id));
    }

    public void deleteBudget(String id) {
        if (!repository.existsById(id)) {
            throw new RuntimeException("Property budget not found with id " + id);
        }
        repository.deleteById(id);
    }
}
