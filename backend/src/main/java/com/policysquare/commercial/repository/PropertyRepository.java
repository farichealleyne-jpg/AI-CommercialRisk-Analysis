package com.policysquare.commercial.repository;

import com.policysquare.commercial.model.Property;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PropertyRepository extends JpaRepository<Property, String> {
    List<Property> findByMobileNumberOrderByNameAsc(String mobileNumber);
}
