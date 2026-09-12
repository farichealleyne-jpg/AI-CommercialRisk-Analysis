package com.policysquare.commercial.service;

import com.policysquare.commercial.model.Property;
import com.policysquare.commercial.repository.PropertyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PropertyService {

    private final PropertyRepository repository;

    public Property createProperty(Property property) {
        if (property.getStatus() == null) {
            property.setStatus(Property.PropertyStatus.ACTIVE);
        }
        if (property.getCode() != null) {
            property.setCode(property.getCode().trim().toUpperCase());
        }
        return repository.save(property);
    }

    public List<Property> getPropertiesByMobileNumber(String mobileNumber) {
        return repository.findByMobileNumberOrderByNameAsc(mobileNumber);
    }

    public Property getPropertyByCode(String code) {
        return repository.findById(code)
                .orElseThrow(() -> new RuntimeException("Property not found with code " + code));
    }

    public Property updateProperty(String code, Property updated) {
        return repository.findById(code)
                .map(existing -> {
                    if (updated.getName() != null) existing.setName(updated.getName());
                    if (updated.getAddressLine() != null) existing.setAddressLine(updated.getAddressLine());
                    if (updated.getCity() != null) existing.setCity(updated.getCity());
                    if (updated.getRegion() != null) existing.setRegion(updated.getRegion());
                    if (updated.getStatus() != null) existing.setStatus(updated.getStatus());
                    if (updated.getNotes() != null) existing.setNotes(updated.getNotes());
                    return repository.save(existing);
                })
                .orElseThrow(() -> new RuntimeException("Property not found with code " + code));
    }

    public void deleteProperty(String code) {
        if (!repository.existsById(code)) {
            throw new RuntimeException("Property not found with code " + code);
        }
        repository.deleteById(code);
    }
}
