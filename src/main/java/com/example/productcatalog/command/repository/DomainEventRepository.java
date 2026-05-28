package com.example.productcatalog.command.repository;

import com.example.productcatalog.infrastructure.persistence.DomainEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

/**
 * JPA repository for persisting domain events as an immutable audit trail.
 */
@Repository
public interface DomainEventRepository extends JpaRepository<DomainEventEntity, UUID> {

    List<DomainEventEntity> findByAggregateIdOrderByOccurredAtAsc(UUID aggregateId);
}
