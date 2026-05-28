# Product Catalog Service

A production-ready **CQRS + DDD + Event-Driven** microservice built with Spring Boot 3.2, Java 21, PostgreSQL (write side), Couchbase (read side), and Kafka (event bus).

---

## Architecture

### CQRS Request Flow

```mermaid
flowchart LR
    Client(["🌐 Client\n(Swagger / App)"])

    subgraph API["API Layer"]
        PC["ProductController\n/api/v1/products"]
    end

    subgraph Write["✏️ Write Side (Command)"]
        direction TB
        PCH["ProductCommandHandler"]
        PA["ProductAggregate\n(domain logic)"]
        PG[("PostgreSQL\nwrite store")]
        OB["OutboxEvent\ntable"]
        OP["OutboxPoller\n(every 5 s)"]
    end

    subgraph Messaging["📨 Kafka"]
        T1["product.added"]
        T2["product.updated"]
        T3["product.stock.changed"]
    end

    subgraph Read["🔍 Read Side (Query)"]
        direction TB
        PQH["ProductQueryHandler"]
        PEC["ProductEventConsumer"]
        CB[("Couchbase\nread store\nProjections")]
    end

    Client -->|"POST / PUT / DELETE"| PC
    Client -->|"GET"| PC
    PC -->|"Command"| PCH
    PC -->|"Query"| PQH
    PCH --> PA
    PA -->|"save"| PG
    PA -->|"outbox event"| OB
    OB -->|"poll"| OP
    OP -->|"publish"| T1
    OP -->|"publish"| T2
    OP -->|"publish"| T3
    T1 -->|"consume"| PEC
    T2 -->|"consume"| PEC
    T3 -->|"consume"| PEC
    PEC -->|"upsert projection"| CB
    PQH -->|"read"| CB
```

---

### Component Diagram

```mermaid
graph TD
    subgraph domain["Domain Layer (no Spring)"]
        PA["ProductAggregate"]
        MO["Money (value object)"]
        SI["StockInfo (value object)"]
        DE["DomainEvent (abstract)"]
        PDS["ProductDomainService"]
    end

    subgraph command["Command Side"]
        ADD["AddProductCommand"]
        UPD["UpdateProductCommand"]
        ADDS["AddStockCommand"]
        REMS["RemoveStockCommand"]
        PCH2["ProductCommandHandler"]
        REPO["ProductRepository\n(JPA → PostgreSQL)"]
        OUTR["OutboxRepository"]
        OUTP["OutboxPoller"]
    end

    subgraph query["Query Side"]
        PQH2["ProductQueryHandler"]
        PROJ["ProductProjection\n(Couchbase @Document)"]
        PROJR["ProductProjectionRepository\n(Couchbase)"]
        DTO["ProductDto"]
    end

    subgraph events["Event Bus"]
        EP["DomainEventPublisher\n(Kafka)"]
        PEC2["ProductEventConsumer"]
    end

    subgraph infra["Infrastructure"]
        PGCFG["PostgresConfig\n(@EntityScan)"]
        CBCFG["CouchbaseConfig"]
        KFKCFG["KafkaConfig"]
        SECCFG["SecurityConfig\n(JWT stateless)"]
        OE["OutboxEvent @Entity"]
        DEE["DomainEventEntity @Entity"]
    end

    subgraph api["API Layer"]
        CTRL["ProductController\n(@RestController)"]
        EXCH["GlobalExceptionHandler\n(@RestControllerAdvice)"]
        REQ["ProductRequest (@Jacksonized)"]
        RESP["ProductResponse"]
    end

    PCH2 --> PA
    PCH2 --> REPO
    PCH2 --> OUTR
    OUTP --> EP
    EP -->|Kafka| PEC2
    PEC2 --> PROJR
    PQH2 --> PROJR
    CTRL --> PCH2
    CTRL --> PQH2
    PA --> DE
    PA --> MO
    PA --> SI
```

---

### Transactional Outbox Pattern

```mermaid
sequenceDiagram
    participant C as Client
    participant Ctrl as ProductController
    participant Handler as ProductCommandHandler
    participant DB as PostgreSQL (products + outbox_events)
    participant Poller as OutboxPoller (5s)
    participant Kafka as Kafka
    participant Consumer as ProductEventConsumer
    participant CB as Couchbase

    C->>Ctrl: POST /api/v1/products
    Ctrl->>Handler: handle(AddProductCommand)
    Handler->>DB: BEGIN TX
    Handler->>DB: INSERT INTO products ...
    Handler->>DB: INSERT INTO outbox_events (published=false)
    Handler->>DB: COMMIT TX
    Handler-->>Ctrl: UUID
    Ctrl-->>C: 201 Created (Location header)

    Note over Poller: Every 5 seconds
    Poller->>DB: SELECT * FROM outbox_events WHERE published=false
    Poller->>Kafka: publish → product.added
    Poller->>DB: UPDATE outbox_events SET published=true

    Kafka->>Consumer: @KafkaListener(topics="product.added")
    Consumer->>CB: upsert ProductProjection

    Note over C,CB: ~2-5 seconds later
    C->>Ctrl: GET /api/v1/products/{id}
    Ctrl->>Handler: handle(GetProductQuery)
    Handler->>CB: findById(id)
    CB-->>Handler: ProductProjection
    Handler-->>Ctrl: ProductDto
    Ctrl-->>C: 200 OK (served from Couchbase)
```

---

### Package Structure

```mermaid
graph LR
    root["com.example.productcatalog"]

    root --> domain
    root --> command
    root --> query
    root --> event
    root --> api
    root --> infrastructure
    root --> common

    domain --> dom_model["model\nProductAggregate\nMoney · StockInfo"]
    domain --> dom_exc["exception\nProductNotFoundException\nInsufficientStockException"]
    domain --> dom_svc["service\nProductDomainService"]

    command --> cmd_model["model\nAddProductCommand\nUpdateProductCommand\nAddStockCommand\nRemoveStockCommand"]
    command --> cmd_repo["repository\nProductRepository\nOutboxRepository"]
    command --> cmd_handler["handler\nProductCommandHandler"]

    query --> q_model["model\nGetProductQuery\nSearchProductsByNameQuery\n..."]
    query --> q_proj["projection\nProductProjection"]
    query --> q_dto["dto\nProductDto"]
    query --> q_repo["repository\nProductProjectionRepository"]
    query --> q_handler["handler\nProductQueryHandler"]

    event --> ev_model["model\nDomainEvent\nProductAddedEvent\nProductUpdatedEvent\nStockAddedEvent\nStockRemovedEvent"]
    event --> ev_pub["publisher\nEventPublisher\nDomainEventPublisher"]
    event --> ev_con["consumer\nProductEventConsumer\nInventoryEventConsumer"]

    api --> api_dto["dto\nProductRequest · ProductResponse\nErrorResponse"]
    api --> api_exc["exception\nGlobalExceptionHandler"]
    api --> api_ctrl["controller\nProductController\nHealthController"]

    infrastructure --> infra_pers["persistence\nOutboxEvent\nDomainEventEntity\nOutboxPoller"]
    infrastructure --> infra_cfg["config\nPostgresConfig\nCouchbaseConfig\nKafkaConfig\nSecurityConfig\nOpenApiConfig"]
    infrastructure --> infra_sec["security\nJwtTokenProvider\nJwtAuthenticationFilter"]

    common --> com_const["constants\nKafkaTopics · AppConstants\nErrorCodes"]
    common --> com_util["util\nJsonUtil · UuidUtil · DateUtil"]
    common --> com_log["logging\nCorrelationIdFilter\nLoggingAspect · StructuredLogger"]
```

---

## Quick Start

### Local (Docker Compose)

```bash
docker compose -f docker-compose.poc.yml up --build
```

Then open [http://localhost:8080/swagger-ui/index.html](http://localhost:8080/swagger-ui/index.html).

### Cloud (Azure — zero local install)

See [POC_QUICKSTART.md](POC_QUICKSTART.md) — deploy entirely from your browser via Azure Cloud Shell.

---

## Sample Data

Ten products are seeded automatically by Flyway migration **V3** on first startup:

| # | Name | Price | Stock |
|---|------|------:|------:|
| 1 | Gaming Laptop Pro 16" | $1,499.99 | 25 |
| 2 | Wireless Noise-Cancelling Headphones | $299.99 | 80 |
| 3 | 4K UHD Smart TV 55" | $899.00 | 15 |
| 4 | Mechanical Keyboard RGB | $139.99 | 60 |
| 5 | Espresso Machine Barista Pro | $549.00 | 30 |
| 6 | Smart Air Purifier HEPA-13 | $199.99 | 45 |
| 7 | Adjustable Dumbbell Set 5-52 lb | $349.00 | 20 |
| 8 | Smart Fitness Tracker Band | $79.99 | 120 |
| 9 | Designing Data-Intensive Applications | $44.99 | 200 |
| 10 | Limited Edition Retro Console *(out of stock)* | $129.99 | 0 |

Product #10 has `stock_quantity = 0` so `inStock: false` will appear in the Couchbase projection — useful for demonstrating the search / filter endpoints.

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/products` | ADMIN | Create product → writes to PostgreSQL |
| `PUT` | `/api/v1/products/{id}` | ADMIN | Update product |
| `POST` | `/api/v1/products/{id}/stock` | ADMIN | Add stock |
| `DELETE` | `/api/v1/products/{id}/stock` | ADMIN | Remove stock |
| `GET` | `/api/v1/products/{id}` | Public | Read from Couchbase |
| `GET` | `/api/v1/products` | Public | Paginated list from Couchbase |
| `GET` | `/api/v1/products/search?name=` | Public | Search by name (Couchbase) |
| `GET` | `/api/v1/health` | Public | Health check |

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Java 21 (LTS) |
| Framework | Spring Boot 3.2 |
| Write store | PostgreSQL 16 + Flyway migrations |
| Read store | Couchbase Community 7.2 |
| Event bus | Apache Kafka 3.6 (KRaft mode) |
| Security | Spring Security 6 + JWT (JJWT 0.12) |
| API docs | SpringDoc OpenAPI 3 (Swagger UI) |
| Build | Maven 3.9 + Docker multi-stage |
| Deployment | Azure Container Apps |

---

## Java 21 Features Used

- **Pattern matching** for `instanceof` checks in exception handlers
- **Records** for lightweight DTOs where applicable
- **Sealed classes** pattern for domain events (compile-time exhaustiveness)
- **Text blocks** for multi-line SQL in tests
- **Virtual threads** ready (enable via `spring.threads.virtual.enabled=true`)

---

## Environment Variables (Docker Compose POC)

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `catalog_user` | PostgreSQL username |
| `POSTGRES_PASSWORD` | — | **Required** |
| `COUCHBASE_USER` | `Administrator` | Couchbase admin user |
| `COUCHBASE_PASSWORD` | — | **Required** |
| `APP_JWT_SECRET` | — | Min 64 chars; used to sign JWTs |
| `SPRING_PROFILES_ACTIVE` | `poc` | Spring profile |
