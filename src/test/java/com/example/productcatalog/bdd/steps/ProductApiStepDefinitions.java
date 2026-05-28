package com.example.productcatalog.bdd.steps;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.api.dto.ProductResponse;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import io.cucumber.datatable.DataTable;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import lombok.extern.slf4j.Slf4j;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.http.HttpStatus.*;

/**
 * Gherkin step definitions for the Product API feature.
 * Runs against a full Spring Boot context with Testcontainers for PostgreSQL.
 * Couchbase and Kafka are mocked.
 */
@Slf4j
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
public class ProductApiStepDefinitions {

    @Autowired
    private TestRestTemplate restTemplate;
    @Autowired
    private ProductRepository commandRepository;

    @MockBean
    private ProductProjectionRepository queryRepository;
    @MockBean
    private KafkaTemplate<String, String> kafkaTemplate;

    // ── In-memory projection store (backs the mock) ───────────────────────────
    private final Map<String, ProductProjection> projections = new LinkedHashMap<>();

    // ── Shared scenario state ─────────────────────────────────────────────────
    private ResponseEntity<?> lastResponse;
    private String lastProductId;
    private Map<String, Object> productData = new HashMap<>();
    private List<ProductResponse> searchResults = new ArrayList<>();

    // ── Before each scenario ──────────────────────────────────────────────────

    @Before
    public void resetState() {
        projections.clear();
        lastResponse = null;
        lastProductId = null;
        productData = new HashMap<>();
        searchResults = new ArrayList<>();

        commandRepository.deleteAll();

        // Reset mock and reconfigure with in-memory behaviour
        Mockito.reset(queryRepository);
        when(queryRepository.findById(anyString()))
                .thenAnswer(inv -> Optional.ofNullable(projections.get(inv.getArgument(0))));
        when(queryRepository.findByNameContainingIgnoreCase(anyString()))
                .thenAnswer(inv -> {
                    String term = ((String) inv.getArgument(0)).toLowerCase();
                    return projections.values().stream()
                            .filter(p -> p.getName() != null && p.getName().toLowerCase().contains(term))
                            .toList();
                });
        when(queryRepository.findAll(org.mockito.ArgumentMatchers.any(
                org.springframework.data.domain.Pageable.class)))
                .thenReturn(org.springframework.data.domain.Page.empty());
    }

    // ── Background ────────────────────────────────────────────────────────────

    @Given("the database is initialized")
    public void databaseIsInitialized() {
        // resetState() already clears everything
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    @Given("I have valid product details:")
    public void iHaveValidProductDetails(DataTable dataTable) {
        Map<String, String> data = dataTable.asMap(String.class, String.class);
        productData.put("name", data.getOrDefault("Name", "Test Product"));
        productData.put("description", data.getOrDefault("Description", ""));
        productData.put("price", new BigDecimal(data.getOrDefault("Price", "9.99")));
    }

    @Given("I have product details with an empty name:")
    public void iHaveProductDetailsWithEmptyName(DataTable dataTable) {
        Map<String, String> data = dataTable.asMap(String.class, String.class);
        productData.put("name", "");
        productData.put("price", new BigDecimal(data.get("Price")));
    }

    @Given("I have product details with price {}")
    public void iHaveProductDetailsWithPrice(String price) {
        productData.put("name", "Test Product");
        productData.put("price", price == null || "null".equalsIgnoreCase(price) ? null : new BigDecimal(price));
    }

    // ── Commands ──────────────────────────────────────────────────────────────

    @When("I send a POST request to create the product")
    public void iSendPostRequestToCreateProduct() {
        ProductRequest req = ProductRequest.builder()
                .name((String) productData.get("name"))
                .description((String) productData.getOrDefault("description", ""))
                .price((BigDecimal) productData.get("price"))
                .build();

        lastResponse = restTemplate.postForEntity("/api/v1/products", req, Void.class);

        // Extract ID from Location header (controller returns 201 with Location, no
        // body)
        if (lastResponse.getStatusCode() == CREATED && lastResponse.getHeaders().getLocation() != null) {
            var locationUri = lastResponse.getHeaders().getLocation();
            String path = locationUri.getPath();
            lastProductId = path.substring(path.lastIndexOf('/') + 1);
            assertThat(lastProductId).as("Product ID not found in Location header").isNotBlank();
        }
    }

    @When("I send a PUT request to update the last created product with:")
    public void iSendPutRequestToUpdateLastProduct(DataTable dataTable) {
        assertThat(lastProductId).as("No product was created yet").isNotBlank();
        Map<String, String> data = dataTable.asMap(String.class, String.class);
        ProductRequest req = ProductRequest.builder()
                .name(data.get("Name"))
                .price(new BigDecimal(data.get("Price")))
                .build();

        lastResponse = restTemplate.exchange(
                "/api/v1/products/" + lastProductId,
                HttpMethod.PUT,
                new HttpEntity<>(req),
                Void.class);
    }

    @When("I send a PUT request to update product {string} with:")
    public void iSendPutRequestToUpdateProduct(String productId, DataTable dataTable) {
        Map<String, String> data = dataTable.asMap(String.class, String.class);
        ProductRequest req = ProductRequest.builder()
                .name(data.get("Name"))
                .price(new BigDecimal(data.get("Price")))
                .build();

        lastResponse = restTemplate.exchange(
                "/api/v1/products/" + productId,
                HttpMethod.PUT,
                new HttpEntity<>(req),
                Void.class);
    }

    @When("I send a POST request to add {int} units of stock to the last created product")
    public void iSendPostRequestToAddStock(int quantity) {
        assertThat(lastProductId).as("No product was created yet").isNotBlank();
        lastResponse = restTemplate.postForEntity(
                "/api/v1/products/" + lastProductId + "/stock?quantity=" + quantity,
                null, Void.class);
    }

    @When("I send a DELETE request to remove {int} units of stock from the last created product")
    public void iSendDeleteRequestToRemoveStock(int quantity) {
        assertThat(lastProductId).as("No product was created yet").isNotBlank();
        lastResponse = restTemplate.exchange(
                "/api/v1/products/" + lastProductId + "/stock?quantity=" + quantity,
                HttpMethod.DELETE, null, Void.class);
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    @When("I send a GET request for product {string}")
    public void iSendGetRequestForProduct(String productId) {
        lastResponse = restTemplate.getForEntity(
                "/api/v1/products/" + productId, ProductResponse.class);
    }

    @When("I search for products containing {string}")
    public void iSearchForProductsContaining(String searchTerm) {
        var response = restTemplate.getForEntity(
                "/api/v1/products/search?name=" + searchTerm, ProductResponse[].class);
        lastResponse = response;
        searchResults = response.getBody() != null
                ? Arrays.asList(response.getBody())
                : new ArrayList<>();
    }

    // ── Assertions ────────────────────────────────────────────────────────────

    @Then("the response status should be {int}")
    public void responseStatusShouldBe(int expectedStatus) {
        assertThat(lastResponse.getStatusCode().value()).isEqualTo(expectedStatus);
    }

    @Then("the response should contain the product ID")
    public void responseShouldContainProductId() {
        assertThat(lastProductId).isNotBlank();
    }

    @Then("the response should contain the product details")
    public void responseShouldContainProductDetails() {
        assertThat(lastResponse.getBody()).isNotNull();
    }

    @Then("the product name should be {string}")
    public void productNameShouldBe(String expectedName) {
        assertThat(((ProductResponse) lastResponse.getBody()).getName()).isEqualTo(expectedName);
    }

    @Then("I should get {int} products")
    public void iShouldGetCountProducts(int expectedCount) {
        assertThat(searchResults).hasSize(expectedCount);
    }

    @Then("all products should contain {string} in the name")
    public void allProductsShouldContainInName(String keyword) {
        assertThat(searchResults).allMatch(p -> p.getName().contains(keyword));
    }

    @Then("the error message should contain {string}")
    public void errorMessageShouldContain(String expected) {
        assertThat(lastResponse.getBody().toString()).containsIgnoringCase(expected);
    }

    @Then("the error message should mention {string}")
    public void errorMessageShouldMention(String keyword) {
        assertThat(lastResponse.getBody().toString()).containsIgnoringCase(keyword);
    }

    @Then("the product should be persisted in PostgreSQL")
    public void productShouldBePersistedInPostgres() {
        assertThat(lastProductId).isNotBlank();
        assertThat(commandRepository.findById(UUID.fromString(lastProductId))).isPresent();
    }

    @Then("the CouchBase read model should be updated")
    public void couchbaseReadModelShouldBeUpdated() {
        assertThat(lastProductId).isNotBlank();
        // Awaitility waits for the mock to be called by the async event consumer
        await().atMost(5, TimeUnit.SECONDS)
                .pollInterval(200, TimeUnit.MILLISECONDS)
                .untilAsserted(() -> assertThat(queryRepository.findById(lastProductId)).isPresent());
    }

    // ── Test data helpers ─────────────────────────────────────────────────────

    @Given("a product exists with ID {string} and name {string}")
    public void productExistsWithIdAndName(String scenarioId, String name) {
        ProductProjection p = new ProductProjection();
        p.setId(scenarioId);
        p.setName(name);
        p.setPrice(new BigDecimal("999.99"));
        p.setStockQuantity(10);
        projections.put(scenarioId, p);
        // mock is already configured in resetState() to read from the projections map
        lastProductId = scenarioId;
    }

    @Given("a product exists with ID {string}")
    public void productExistsWithId(String productId) {
        productExistsWithIdAndName(productId, "Test Product");
    }

    @Given("no product with ID {string} exists")
    public void noProductWithIdExists(String productId) {
        projections.remove(productId);
    }

    @Given("the following products exist:")
    public void followingProductsExist(DataTable dataTable) {
        dataTable.asMaps().forEach(row -> {
            ProductProjection p = new ProductProjection();
            p.setId(row.get("ID"));
            p.setName(row.get("Name"));
            p.setPrice(new BigDecimal(row.get("Price")));
            p.setStockQuantity(10);
            projections.put(p.getId(), p);
        });
    }
}
