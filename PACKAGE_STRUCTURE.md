# Spring Boot CQRS Microservice - Package Structure Guide

## Overview

This document describes the standardized package structure for the Product Catalog Service, following DDD (Domain-Driven Design) and CQRS principles.

```
product-catalog-service/
├── src/
│   ├── main/
│   │   ├── java/com/example/productcatalog/
│   │   │   ├── command/              # Write Model
│   │   │   ├── query/                # Read Model
│   │   │   ├── event/                # Event Processing
│   │   │   ├── domain/               # Domain Logic
│   │   │   ├── api/                  # REST API Layer
│   │   │   ├── infrastructure/       # Technical Infrastructure
│   │   │   └── common/               # Shared Utilities
│   │   └── resources/
│   │       ├── application.yml       # Main config
│   │       ├── config/               # Config files
│   │       └── db/migration/         # Flyway migrations
│   └── test/
│       ├── java/com/example/productcatalog/
│       │   ├── command/              # Command tests
│       │   ├── query/                # Query tests
│       │   ├── domain/               # Domain tests
│       │   ├── api/                  # API tests
│       │   ├── event/                # Event tests
│       │   ├── bdd/                  # BDD/Cucumber tests
│       │   └── integration/          # Integration tests
│       └── resources/
│           └── features/             # Gherkin feature files
├── docker-compose.yml
├── Dockerfile
├── pom.xml
└── README.md
```

## Main Source Structure (`src/main/java/com/example/productcatalog/`)

### 1. **command/** - Write Model (CQRS Command Side)

Handles all write operations and state changes.

```
command/
├── handler/
│   ├── ProductCommandHandler.java      # Main command handler
│   └── ...CommandHandler.java          # Other handlers
├── repository/
│   ├── ProductRepository.java          # JPA repository for writes
│   ├── DomainEventRepository.java      # Event log repository
│   └── OutboxRepository.java           # Outbox for reliable publishing
└── [command models if separate]
```

**Responsibility:**
- Execute business commands (AddProduct, UpdateProduct, etc.)
- Validate business rules and invariants
- Persist aggregates to PostgreSQL
- Publish domain events
- Transaction management

**Key Classes:**
- `ProductCommandHandler` - Orchestrates command execution
- `ProductRepository` - JPA repository for product persistence
- `DomainEventRepository` - Stores all domain events (audit trail)
- `OutboxRepository` - Outbox pattern for reliable event publishing

### 2. **query/** - Read Model (CQRS Query Side)

Handles all read operations with optimized denormalized data.

```
query/
├── handler/
│   ├── ProductQueryHandler.java        # Main query handler
│   └── ...QueryHandler.java            # Other handlers
├── repository/
│   ├── ProductProjectionRepository.java # CouchBase repository
│   └── ...ProjectionRepository.java     # Other repositories
├── projection/
│   ├── ProductProjection.java          # Denormalized document
│   └── ...Projection.java              # Other projections
└── dto/
    ├── ProductDto.java                 # Transfer object for queries
    └── ...Dto.java                     # Other DTOs
```

**Responsibility:**
- Execute read-only queries
- Return optimized denormalized data from CouchBase
- No business logic
- Fast, scalable queries

**Key Classes:**
- `ProductQueryHandler` - Handles all product queries
- `ProductProjectionRepository` - CouchBase/R2DBC repository
- `ProductProjection` - Denormalized document model
- `ProductDto` - DTO for API responses

### 3. **event/** - Event Processing

Manages domain events and their lifecycle.

```
event/
├── model/
│   ├── DomainEvent.java                # Base event class
│   ├── ProductAddedEvent.java          # Product created
│   ├── ProductUpdatedEvent.java        # Product updated
│   ├── StockAddedEvent.java            # Stock increased
│   └── ...Event.java                   # Other domain events
├── publisher/
│   ├── DomainEventPublisher.java       # Publishes to Kafka
│   └── EventPublisher.java             # Interface/contract
└── consumer/
    ├── ProductEventConsumer.java       # Listens to events
    ├── InventoryEventConsumer.java     # Other event listeners
    └── ...EventConsumer.java
```

**Responsibility:**
- Define domain events (immutable)
- Publish events to Kafka
- Consume events and update projections
- Handle event versioning

**Key Classes:**
- `DomainEvent` - Base class for all events
- `ProductAddedEvent`, `ProductUpdatedEvent` - Specific events
- `DomainEventPublisher` - Publishes to Kafka topics
- `ProductEventConsumer` - Updates CouchBase from events

### 4. **domain/** - Domain Logic (DDD Core)

Pure business logic, independent of frameworks.

```
domain/
├── model/
│   ├── ProductAggregate.java           # Aggregate root
│   ├── Product.java                    # Entity
│   ├── StockInfo.java                  # Value object
│   ├── Money.java                      # Value object
│   └── ...Entity.java
├── service/
│   ├── ProductDomainService.java       # Domain service
│   └── ...DomainService.java
└── exception/
    ├── ProductNotFound.java            # Domain exception
    ├── InsufficientStock.java          # Domain exception
    └── ...Exception.java
```

**Responsibility:**
- Core business logic
- Aggregates, entities, value objects
- Business rule enforcement
- Domain exceptions
- No Spring or framework dependencies

**Key Classes:**
- `ProductAggregate` - Aggregate root for Product
- `StockInfo` - Value object for inventory
- `Money` - Value object for price
- `ProductDomainService` - Cross-aggregate logic

### 5. **api/** - REST API Layer

HTTP interface and data transfer.

```
api/
├── controller/
│   ├── ProductController.java          # REST endpoints
│   ├── HealthController.java           # Health checks
│   └── ...Controller.java
├── dto/
│   ├── ProductRequest.java             # Input DTO
│   ├── ProductResponse.java            # Output DTO
│   ├── ErrorResponse.java              # Error DTO
│   └── ...Request/Response.java
└── exception/
    ├── GlobalExceptionHandler.java     # @ControllerAdvice
    ├── ResourceNotFoundException.java   # HTTP 404
    ├── BadRequestException.java        # HTTP 400
    └── ...Exception.java
```

**Responsibility:**
- REST endpoints (@RestController)
- Request/response DTOs (API contracts)
- Input validation
- Error handling and HTTP status codes
- OpenAPI/Swagger documentation

**Key Classes:**
- `ProductController` - REST endpoints for products
- `ProductRequest` - DTO for POST/PUT requests
- `ProductResponse` - DTO for GET responses
- `GlobalExceptionHandler` - Centralized error handling

### 6. **infrastructure/** - Technical Infrastructure

Framework integration and external concerns.

```
infrastructure/
├── config/
│   ├── PostgresConfig.java             # JPA/Hibernate
│   ├── CouchbaseConfig.java            # CouchBase setup
│   ├── KafkaConfig.java                # Kafka producer/consumer
│   ├── SecurityConfig.java             # Spring Security
│   ├── OpenApiConfig.java              # Swagger/OpenAPI
│   └── ...Config.java
├── security/
│   ├── JwtTokenProvider.java           # JWT generation/validation
│   ├── CustomUserDetailsService.java   # User loading
│   └── SecurityUtil.java               # Security helpers
├── persistence/
│   ├── OutboxEvent.java                # Outbox entity
│   ├── OutboxPoller.java               # Background job for outbox
│   ├── DomainEventEntity.java          # Event log entity
│   └── ...Persistence.java
└── kafka/
    ├── KafkaProducerTemplate.java      # Kafka template wrapper
    ├── KafkaConsumerTemplate.java      # Consumer setup
    └── ...Kafka.java
```

**Responsibility:**
- Spring Boot configuration
- Database connections (PostgreSQL, CouchBase)
- Kafka setup (producer, consumer)
- Security (JWT, OAuth2)
- Persistence mechanisms
- External integrations

**Key Classes:**
- `PostgresConfig` - JPA/Hibernate configuration
- `CouchbaseConfig` - CouchBase connection
- `KafkaConfig` - Kafka producer/consumer configuration
- `JwtTokenProvider` - JWT token handling
- `OutboxPoller` - Reliable event publishing

### 7. **common/** - Shared Utilities

Cross-cutting concerns and utilities.

```
common/
├── util/
│   ├── JsonUtil.java                   # JSON serialization
│   ├── UuidUtil.java                   # UUID generation
│   ├── DateUtil.java                   # Date/time utilities
│   └── ...Util.java
├── constants/
│   ├── AppConstants.java               # App-level constants
│   ├── KafkaTopics.java                # Kafka topic names
│   ├── ErrorCodes.java                 # Error code constants
│   └── ...Constants.java
└── logging/
    ├── CorrelationIdFilter.java        # Request correlation
    ├── LoggingAspect.java              # AOP logging
    └── StructuredLogger.java           # Structured logging
```

**Responsibility:**
- Utilities and helpers
- Application constants
- Correlation ID tracking
- Logging infrastructure
- Shared annotations

**Key Classes:**
- `JsonUtil` - JSON serialization helpers
- `KafkaTopics` - Kafka topic name constants
- `CorrelationIdFilter` - Request tracing
- `StructuredLogger` - Structured logging

## Test Structure (`src/test/java/com/example/productcatalog/`)

Mirrors main structure with test implementations.

### Test Directories

```
test/
├── java/com/example/productcatalog/
│   ├── command/handler/
│   │   ├── AddProductCommandHandlerTest.java
│   │   ├── UpdateProductCommandHandlerTest.java
│   │   └── ...Test.java
│   ├── query/handler/
│   │   ├── GetProductQueryHandlerTest.java
│   │   ├── SearchProductsQueryHandlerTest.java
│   │   └── ...Test.java
│   ├── domain/model/
│   │   ├── ProductAggregateTest.java
│   │   ├── ProductTest.java
│   │   └── ...Test.java
│   ├── api/controller/
│   │   ├── ProductControllerTest.java
│   │   └── ...Test.java
│   ├── event/consumer/
│   │   ├── ProductEventConsumerTest.java
│   │   └── ...Test.java
│   ├── bdd/steps/
│   │   ├── ProductApiStepDefinitions.java
│   │   ├── CommonStepDefinitions.java
│   │   └── ...StepDefinitions.java
│   └── integration/
│       ├── ProductApiIntegrationTest.java
│       ├── EventProcessingIntegrationTest.java
│       └── ...IntegrationTest.java
└── resources/
    ├── features/
    │   ├── product-api.feature
    │   ├── product-commands.feature
    │   └── ...feature
    ├── application-test.yml
    └── test-data.sql
```

## Resources Structure (`src/main/resources/`)

```
resources/
├── application.yml                 # Main config
├── application-prod.yml            # Production profile
├── application-test.yml            # Test profile
├── config/
│   ├── logback-spring.xml          # Logging configuration
│   └── messages.properties         # i18n messages
├── db/
│   └── migration/
│       ├── V1__init_schema.sql     # PostgreSQL schema
│       ├── V2__add_indexes.sql     # Database optimization
│       └── V3__...sql              # Future migrations
└── static/                         # (Optional) Static assets
```

## Naming Conventions

### Classes

| Type | Naming | Example |
|------|--------|---------|
| Command Handler | `{Action}{Entity}CommandHandler` | `AddProductCommandHandler` |
| Query Handler | `{Action}{Entity}QueryHandler` | `GetProductQueryHandler` |
| Command | `{Action}{Entity}Command` | `AddProductCommand` |
| Query | `{Action}{Entity}Query` | `GetProductQuery` |
| Event | `{Entity}{Action}Event` | `ProductAddedEvent` |
| Consumer | `{Entity}EventConsumer` | `ProductEventConsumer` |
| Repository | `{Entity}Repository` | `ProductRepository` |
| Projection | `{Entity}Projection` | `ProductProjection` |
| DTO | `{Entity}Dto` | `ProductDto` |
| Controller | `{Entity}Controller` | `ProductController` |
| Service | `{Entity}Service` | `ProductService` |
| Config | `{Feature}Config` | `PostgresConfig` |

### Files

- **Java files**: CamelCase (e.g., `ProductCommandHandler.java`)
- **Test files**: Append `Test` (e.g., `ProductCommandHandlerTest.java`)
- **Feature files**: kebab-case (e.g., `product-api.feature`)
- **Config files**: kebab-case (e.g., `application-test.yml`)

## Package Organization Principles

### 1. **CQRS Separation**
- Write logic in `command/`
- Read logic in `query/`
- Never share code between them

### 2. **Domain-Driven Design**
- Domain logic in `domain/` (no Spring)
- Infrastructure in `infrastructure/`
- API layer in `api/`

### 3. **Layered Architecture**
```
API Layer (Controllers, DTOs)
    ↓
Application Layer (Handlers, Services)
    ↓
Domain Layer (Aggregates, Entities)
    ↓
Infrastructure Layer (Persistence, Config)
```

### 4. **Dependency Direction**
- Lower layers don't depend on higher layers
- All dependencies point inward toward domain

### 5. **Test Proximity**
- Test classes mirror main source structure
- Unit tests in `test/java/` matching packages
- Integration tests in `integration/` subpackage
- BDD tests in `bdd/steps/`

## Best Practices

### Do's ✅

- Keep domain logic free of framework dependencies
- Use dependency injection for everything
- Organize by feature (vertical slicing when appropriate)
- Name classes based on responsibility
- Keep packages small and focused
- Use interfaces for abstractions

### Don'ts ❌

- Don't mix command and query logic
- Don't put business logic in controllers
- Don't use static utility classes
- Don't have circular dependencies
- Don't create package-private classes that leak implementation
- Don't mix Spring annotations with pure domain logic

## Adding New Features

When adding a new feature (e.g., "product reviews"):

1. Create directories:
   ```
   command/handler/AddReviewCommandHandler.java
   query/handler/GetReviewsQueryHandler.java
   event/model/ReviewAddedEvent.java
   api/controller/ReviewController.java
   api/dto/ReviewRequest.java, ReviewResponse.java
   domain/model/Review.java
   ```

2. Add corresponding tests:
   ```
   test/java/command/handler/AddReviewCommandHandlerTest.java
   test/java/query/handler/GetReviewsQueryHandlerTest.java
   test/bdd/steps/ReviewStepDefinitions.java
   ```

3. Add Kafka topic:
   ```
   infrastructure/kafka/ReviewTopics.java
   ```

4. Add database migration:
   ```
   resources/db/migration/V{N}__add_reviews_table.sql
   ```

## Resources

- Maven Standard Directory Layout: https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html
- Spring Boot Best Practices: https://spring.io/guides
- Domain-Driven Design: https://en.wikipedia.org/wiki/Domain-driven_design
- CQRS Pattern: https://martinfowler.com/bliki/CQRS.html
- Microservices Patterns: https://microservices.io/patterns/index.html
