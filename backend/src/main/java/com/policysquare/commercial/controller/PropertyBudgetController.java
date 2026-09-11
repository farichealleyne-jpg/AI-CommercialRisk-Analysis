package com.policysquare.commercial.controller;

import com.policysquare.commercial.model.PropertyBudget;
import com.policysquare.commercial.service.PropertyBudgetService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/property-budgets")
@CrossOrigin(originPatterns = "*")
@RequiredArgsConstructor
public class PropertyBudgetController {

    private final PropertyBudgetService service;

    @PostMapping
    public ResponseEntity<?> createBudget(@RequestBody PropertyBudget budget) {
        try {
            return ResponseEntity.ok(service.createBudget(budget));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Error creating property budget: " + e.getMessage());
        }
    }

    @GetMapping("/user/{mobileNumber}")
    public ResponseEntity<List<PropertyBudget>> getUserBudgets(@PathVariable String mobileNumber) {
        return ResponseEntity.ok(service.getBudgetsByMobileNumber(mobileNumber));
    }

    @GetMapping("/{id}")
    public ResponseEntity<PropertyBudget> getBudgetById(@PathVariable String id) {
        return ResponseEntity.ok(service.getBudgetById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<PropertyBudget> updateBudget(@PathVariable String id, @RequestBody PropertyBudget budget) {
        return ResponseEntity.ok(service.updateBudget(id, budget));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBudget(@PathVariable String id) {
        service.deleteBudget(id);
        return ResponseEntity.noContent().build();
    }
}
