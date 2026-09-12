package com.policysquare.commercial.service;

import com.policysquare.commercial.config.PmaSettings;
import com.policysquare.commercial.model.InspectionVisit;
import com.policysquare.commercial.repository.InspectionVisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
public class InspectionVisitService {

    private static final DateTimeFormatter ID_DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final InspectionVisitRepository repository;

    public synchronized InspectionVisit createVisit(InspectionVisit visit) {
        if (visit.getVisitDate() == null) {
            visit.setVisitDate(LocalDate.now());
        }
        if (visit.getReportDueDate() == null) {
            visit.setReportDueDate(visit.getVisitDate().plusDays(PmaSettings.REPORT_DUE_DAYS));
        }
        if (visit.getId() == null || visit.getId().isEmpty()) {
            visit.setId(nextVisitId(visit.getPropertyCode(), visit.getVisitDate()));
        }
        return repository.save(visit);
    }

    private String nextVisitId(String propertyCode, LocalDate visitDate) {
        String base = propertyCode + "-" + visitDate.format(ID_DATE);
        int sequence = 1;
        while (repository.existsById(base + "-" + sequence)) {
            sequence++;
        }
        return base + "-" + sequence;
    }

    public List<InspectionVisit> getVisitsByMobileNumber(String mobileNumber) {
        return repository.findByMobileNumberOrderByVisitDateDesc(mobileNumber);
    }

    public List<InspectionVisit> getVisitsByProperty(String propertyCode) {
        return repository.findByPropertyCodeOrderByVisitDateDesc(propertyCode);
    }

    public InspectionVisit getVisitById(String id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Visit not found with id " + id));
    }

    public InspectionVisit updateVisit(String id, InspectionVisit updated) {
        return repository.findById(id)
                .map(existing -> {
                    if (updated.getVisitDate() != null) {
                        existing.setVisitDate(updated.getVisitDate());
                        existing.setReportDueDate(
                                updated.getReportDueDate() != null
                                        ? updated.getReportDueDate()
                                        : updated.getVisitDate().plusDays(PmaSettings.REPORT_DUE_DAYS));
                    }
                    if (updated.getInspector() != null) existing.setInspector(updated.getInspector());
                    if (updated.getInspectionType() != null) existing.setInspectionType(updated.getInspectionType());
                    if (updated.getWeatherConditions() != null) existing.setWeatherConditions(updated.getWeatherConditions());
                    if (updated.getReportSentDate() != null) existing.setReportSentDate(updated.getReportSentDate());
                    if (updated.getSentTo() != null) existing.setSentTo(updated.getSentTo());
                    if (updated.getReportLink() != null) existing.setReportLink(updated.getReportLink());
                    if (updated.getAreasInspected() != null) existing.setAreasInspected(updated.getAreasInspected());
                    if (updated.getOverallCondition() != null) existing.setOverallCondition(updated.getOverallCondition());
                    if (updated.getOperationsSummary() != null) existing.setOperationsSummary(updated.getOperationsSummary());
                    if (updated.getRevenueExpenseIssues() != null) existing.setRevenueExpenseIssues(updated.getRevenueExpenseIssues());
                    if (updated.getImmediateActions() != null) existing.setImmediateActions(updated.getImmediateActions());
                    if (updated.getDecisionsRequired() != null) existing.setDecisionsRequired(updated.getDecisionsRequired());
                    return repository.save(existing);
                })
                .orElseThrow(() -> new RuntimeException("Visit not found with id " + id));
    }

    public void deleteVisit(String id) {
        if (!repository.existsById(id)) {
            throw new RuntimeException("Visit not found with id " + id);
        }
        repository.deleteById(id);
    }
}
