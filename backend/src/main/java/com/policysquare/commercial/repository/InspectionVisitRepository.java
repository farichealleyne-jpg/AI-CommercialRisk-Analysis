package com.policysquare.commercial.repository;

import com.policysquare.commercial.model.InspectionVisit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface InspectionVisitRepository extends JpaRepository<InspectionVisit, String> {
    List<InspectionVisit> findByMobileNumberOrderByVisitDateDesc(String mobileNumber);

    List<InspectionVisit> findByPropertyCodeOrderByVisitDateDesc(String propertyCode);

    long countByPropertyCode(String propertyCode);
}
