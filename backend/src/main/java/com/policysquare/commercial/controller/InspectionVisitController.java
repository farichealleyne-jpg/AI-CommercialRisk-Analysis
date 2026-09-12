package com.policysquare.commercial.controller;

import com.policysquare.commercial.model.InspectionVisit;
import com.policysquare.commercial.service.InspectionVisitService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/visits")
@CrossOrigin(originPatterns = "*")
@RequiredArgsConstructor
public class InspectionVisitController {

    private final InspectionVisitService service;

    @PostMapping
    public ResponseEntity<?> createVisit(@RequestBody InspectionVisit visit) {
        try {
            return ResponseEntity.ok(service.createVisit(visit));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Error creating visit: " + e.getMessage());
        }
    }

    @GetMapping("/user/{mobileNumber}")
    public ResponseEntity<List<InspectionVisit>> getUserVisits(@PathVariable String mobileNumber) {
        return ResponseEntity.ok(service.getVisitsByMobileNumber(mobileNumber));
    }

    @GetMapping("/property/{propertyCode}")
    public ResponseEntity<List<InspectionVisit>> getPropertyVisits(@PathVariable String propertyCode) {
        return ResponseEntity.ok(service.getVisitsByProperty(propertyCode));
    }

    @GetMapping("/{id}")
    public ResponseEntity<InspectionVisit> getVisit(@PathVariable String id) {
        return ResponseEntity.ok(service.getVisitById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<InspectionVisit> updateVisit(@PathVariable String id, @RequestBody InspectionVisit visit) {
        return ResponseEntity.ok(service.updateVisit(id, visit));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteVisit(@PathVariable String id) {
        service.deleteVisit(id);
        return ResponseEntity.noContent().build();
    }
}
