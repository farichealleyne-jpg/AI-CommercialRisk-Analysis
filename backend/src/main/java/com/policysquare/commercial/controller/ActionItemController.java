package com.policysquare.commercial.controller;

import com.policysquare.commercial.dto.DashboardSummary;
import com.policysquare.commercial.model.ActionItem;
import com.policysquare.commercial.service.ActionItemService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/actions")
@CrossOrigin(originPatterns = "*")
@RequiredArgsConstructor
public class ActionItemController {

    private final ActionItemService service;

    @PostMapping
    public ResponseEntity<?> createAction(@RequestBody ActionItem action) {
        try {
            return ResponseEntity.ok(service.createAction(action));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Error creating action item: " + e.getMessage());
        }
    }

    @GetMapping("/user/{mobileNumber}")
    public ResponseEntity<List<ActionItem>> getUserActions(@PathVariable String mobileNumber) {
        return ResponseEntity.ok(service.getActionsByMobileNumber(mobileNumber));
    }

    @GetMapping("/property/{propertyCode}")
    public ResponseEntity<List<ActionItem>> getPropertyActions(@PathVariable String propertyCode) {
        return ResponseEntity.ok(service.getActionsByProperty(propertyCode));
    }

    @GetMapping("/visit/{visitId}")
    public ResponseEntity<List<ActionItem>> getVisitActions(@PathVariable String visitId) {
        return ResponseEntity.ok(service.getActionsByVisit(visitId));
    }

    @GetMapping("/summary/{mobileNumber}")
    public ResponseEntity<DashboardSummary> getSummary(@PathVariable String mobileNumber) {
        return ResponseEntity.ok(service.buildSummary(mobileNumber));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ActionItem> getAction(@PathVariable String id) {
        return ResponseEntity.ok(service.getActionById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ActionItem> updateAction(@PathVariable String id, @RequestBody ActionItem action) {
        return ResponseEntity.ok(service.updateAction(id, action));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAction(@PathVariable String id) {
        service.deleteAction(id);
        return ResponseEntity.noContent().build();
    }
}
