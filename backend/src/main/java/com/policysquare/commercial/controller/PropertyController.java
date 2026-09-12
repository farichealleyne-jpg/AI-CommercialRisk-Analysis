package com.policysquare.commercial.controller;

import com.policysquare.commercial.model.Property;
import com.policysquare.commercial.service.PropertyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/properties")
@CrossOrigin(originPatterns = "*")
@RequiredArgsConstructor
public class PropertyController {

    private final PropertyService service;

    @PostMapping
    public ResponseEntity<?> createProperty(@RequestBody Property property) {
        try {
            return ResponseEntity.ok(service.createProperty(property));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().body("Error creating property: " + e.getMessage());
        }
    }

    @GetMapping("/user/{mobileNumber}")
    public ResponseEntity<List<Property>> getUserProperties(@PathVariable String mobileNumber) {
        return ResponseEntity.ok(service.getPropertiesByMobileNumber(mobileNumber));
    }

    @GetMapping("/{code}")
    public ResponseEntity<Property> getProperty(@PathVariable String code) {
        return ResponseEntity.ok(service.getPropertyByCode(code));
    }

    @PutMapping("/{code}")
    public ResponseEntity<Property> updateProperty(@PathVariable String code, @RequestBody Property property) {
        return ResponseEntity.ok(service.updateProperty(code, property));
    }

    @DeleteMapping("/{code}")
    public ResponseEntity<Void> deleteProperty(@PathVariable String code) {
        service.deleteProperty(code);
        return ResponseEntity.noContent().build();
    }
}
