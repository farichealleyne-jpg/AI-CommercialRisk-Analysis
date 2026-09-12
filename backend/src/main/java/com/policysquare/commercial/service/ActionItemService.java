package com.policysquare.commercial.service;

import com.policysquare.commercial.dto.DashboardSummary;
import com.policysquare.commercial.model.ActionItem;
import com.policysquare.commercial.model.InspectionVisit;
import com.policysquare.commercial.repository.ActionItemRepository;
import com.policysquare.commercial.repository.InspectionVisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ActionItemService {

    private final ActionItemRepository repository;
    private final InspectionVisitRepository visitRepository;

    public synchronized ActionItem createAction(ActionItem action) {
        if (action.getStatus() == null) {
            action.setStatus(ActionItem.ActionStatus.OPEN);
        }
        if (action.getPriority() == null) {
            action.setPriority(ActionItem.Priority.MEDIUM);
        }
        if (action.getSafetyHazard() == null) {
            action.setSafetyHazard(false);
        }
        if (action.getLeaseReview() == null) {
            action.setLeaseReview(false);
        }
        if (action.getId() == null || action.getId().isEmpty()) {
            action.setId(nextActionId(action));
        }
        applyApprovalRule(action);
        return repository.save(action);
    }

    /**
     * Capital work cannot sit as "no approval needed". Promote it to pending,
     * but never overwrite an approval decision someone has already recorded.
     */
    private void applyApprovalRule(ActionItem action) {
        boolean undecided = action.getApprovalStatus() == null
                || action.getApprovalStatus() == ActionItem.ApprovalStatus.NOT_REQUIRED;
        if (action.isRequiresCapitalReview() && undecided) {
            action.setApprovalStatus(ActionItem.ApprovalStatus.PENDING);
        } else if (action.getApprovalStatus() == null) {
            action.setApprovalStatus(ActionItem.ApprovalStatus.NOT_REQUIRED);
        }
        // Below the threshold a manager may still classify work as capital
        // (part of a project, say); above it, operating is not an option.
        if (action.isRequiresCapitalReview()) {
            action.setCostClassification(ActionItem.CostClassification.CAPITAL);
        } else if (action.getCostClassification() == null) {
            action.setCostClassification(ActionItem.CostClassification.OPERATING);
        }
    }

    private String nextActionId(ActionItem action) {
        String base = action.getVisitId() != null && !action.getVisitId().isEmpty()
                ? action.getVisitId()
                : action.getPropertyCode();
        int sequence = 1;
        while (repository.existsById(String.format("%s-%02d", base, sequence))) {
            sequence++;
        }
        return String.format("%s-%02d", base, sequence);
    }

    public List<ActionItem> getActionsByMobileNumber(String mobileNumber) {
        return repository.findByMobileNumberOrderByCreatedAtDesc(mobileNumber);
    }

    public List<ActionItem> getActionsByProperty(String propertyCode) {
        return repository.findByPropertyCodeOrderByCreatedAtDesc(propertyCode);
    }

    public List<ActionItem> getActionsByVisit(String visitId) {
        return repository.findByVisitIdOrderByCreatedAtAsc(visitId);
    }

    public ActionItem getActionById(String id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Action item not found with id " + id));
    }

    public ActionItem updateAction(String id, ActionItem updated) {
        return repository.findById(id)
                .map(existing -> {
                    if (updated.getLocation() != null) existing.setLocation(updated.getLocation());
                    if (updated.getCategory() != null) existing.setCategory(updated.getCategory());
                    if (updated.getIssue() != null) existing.setIssue(updated.getIssue());
                    if (updated.getPriority() != null) existing.setPriority(updated.getPriority());
                    if (updated.getSafetyHazard() != null) existing.setSafetyHazard(updated.getSafetyHazard());
                    if (updated.getImmediateControl() != null) existing.setImmediateControl(updated.getImmediateControl());
                    if (updated.getResponsibleParty() != null) existing.setResponsibleParty(updated.getResponsibleParty());
                    if (updated.getTenantUnit() != null) existing.setTenantUnit(updated.getTenantUnit());
                    if (updated.getLeaseReview() != null) existing.setLeaseReview(updated.getLeaseReview());
                    if (updated.getActionOwner() != null) existing.setActionOwner(updated.getActionOwner());
                    if (updated.getStatus() != null) existing.setStatus(updated.getStatus());
                    if (updated.getTargetCompletion() != null) existing.setTargetCompletion(updated.getTargetCompletion());
                    if (updated.getCompletionDate() != null) existing.setCompletionDate(updated.getCompletionDate());
                    if (updated.getVerifiedBy() != null) existing.setVerifiedBy(updated.getVerifiedBy());
                    if (updated.getEstimatedCost() != null) existing.setEstimatedCost(updated.getEstimatedCost());
                    if (updated.getCostClassification() != null) existing.setCostClassification(updated.getCostClassification());
                    if (updated.getApprovalStatus() != null) existing.setApprovalStatus(updated.getApprovalStatus());
                    if (updated.getVendorRef() != null) existing.setVendorRef(updated.getVendorRef());
                    if (updated.getEvidenceLink() != null) existing.setEvidenceLink(updated.getEvidenceLink());
                    if (updated.getNotes() != null) existing.setNotes(updated.getNotes());
                    applyApprovalRule(existing);
                    return repository.save(existing);
                })
                .orElseThrow(() -> new RuntimeException("Action item not found with id " + id));
    }

    public void deleteAction(String id) {
        if (!repository.existsById(id)) {
            throw new RuntimeException("Action item not found with id " + id);
        }
        repository.deleteById(id);
    }

    public DashboardSummary buildSummary(String mobileNumber) {
        List<InspectionVisit> visits = visitRepository.findByMobileNumberOrderByVisitDateDesc(mobileNumber);
        List<ActionItem> actions = repository.findByMobileNumberOrderByCreatedAtDesc(mobileNumber);

        DashboardSummary summary = new DashboardSummary();
        summary.setVisits(visits.size());
        summary.setReportsPending(visits.stream()
                .filter(v -> v.getReportStatus() == InspectionVisit.ReportStatus.PENDING).count());
        summary.setReportsOverdue(visits.stream()
                .filter(v -> v.getReportStatus() == InspectionVisit.ReportStatus.OVERDUE).count());

        List<ActionItem> open = actions.stream().filter(ActionItem::isOpen).toList();
        summary.setOpenActions(open.size());
        summary.setOpenSafetyHazards(open.stream()
                .filter(a -> Boolean.TRUE.equals(a.getSafetyHazard())).count());
        summary.setOverdueActions(open.stream().filter(ActionItem::isOverdue).count());
        summary.setCapitalReviews(open.stream().filter(ActionItem::isRequiresCapitalReview).count());
        summary.setEstimatedOpenCost(open.stream()
                .map(ActionItem::getEstimatedCost)
                .filter(cost -> cost != null)
                .reduce(BigDecimal.ZERO, BigDecimal::add));

        summary.setCriticalOpen(countPriority(open, ActionItem.Priority.CRITICAL));
        summary.setHighOpen(countPriority(open, ActionItem.Priority.HIGH));
        summary.setMediumOpen(countPriority(open, ActionItem.Priority.MEDIUM));
        summary.setLowOpen(countPriority(open, ActionItem.Priority.LOW));
        return summary;
    }

    private long countPriority(List<ActionItem> actions, ActionItem.Priority priority) {
        return actions.stream().filter(a -> a.getPriority() == priority).count();
    }
}
