package com.policysquare.commercial.repository;

import com.policysquare.commercial.model.ActionItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ActionItemRepository extends JpaRepository<ActionItem, String> {
    List<ActionItem> findByMobileNumberOrderByCreatedAtDesc(String mobileNumber);

    List<ActionItem> findByPropertyCodeOrderByCreatedAtDesc(String propertyCode);

    List<ActionItem> findByVisitIdOrderByCreatedAtAsc(String visitId);

    long countByVisitId(String visitId);
}
