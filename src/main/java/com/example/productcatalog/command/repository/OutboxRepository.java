package com.example.productcatalog.command.repository;

import com.example.productcatalog.infrastructure.persistence.OutboxEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * JPA repository for the outbox table used by the transactional outbox pattern.
 */
@Repository
public interface OutboxRepository extends JpaRepository<OutboxEvent, UUID> {

    /** Returns all unpublished outbox entries for the polling job. */
    List<OutboxEvent> findByPublishedFalseOrderByCreatedAtAsc();
}
