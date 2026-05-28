package com.example.productcatalog.command.repository;

import com.example.productcatalog.domain.model.ProductAggregate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * JPA repository for the write-side {@link ProductAggregate}.
 *
 * <p>Only used on the command (write) side — never from query handlers.
 */
@Repository
public interface ProductRepository extends JpaRepository<ProductAggregate, UUID> {
}
