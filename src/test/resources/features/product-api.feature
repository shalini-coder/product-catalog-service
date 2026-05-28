Feature: Product Management API
  As a product manager
  I want to manage products in the catalog
  So that I can maintain accurate inventory and pricing

  Background:
    Given the product catalog service is running
    And the database is initialized
    And the authentication is configured

  @api @create
  Scenario: Create a new product successfully
    Given I have valid product details:
      | Field       | Value            |
      | Name        | Gaming Laptop    |
      | Price       | 1299.99          |
      | Description | High-performance |
    When I send a POST request to create the product
    Then the response status should be 201
    And the response should contain the product ID
    And the product should be persisted in PostgreSQL

  @api @create @validation
  Scenario: Cannot create product with empty name
    Given I have product details with an empty name:
      | Field | Value  |
      | Price | 999.99 |
    When I send a POST request to create the product
    Then the response status should be 400
    And the error message should contain "name cannot be blank"

  @api @create @validation
  Scenario Outline: Cannot create product with invalid price
    Given I have product details with price <price>
    When I send a POST request to create the product
    Then the response status should be 400
    And the error message should mention "price"

    Examples:
      | price |
      | -100  |
      | 0     |
      | null  |

  @api @read
  Scenario: Get product by ID
    Given a product exists with ID "prod-123" and name "Laptop"
    When I send a GET request for product "prod-123"
    Then the response status should be 200
    And the response should contain the product details
    And the product name should be "Laptop"

  @api @read
  Scenario: Get non-existent product returns 404
    Given no product with ID "unknown-id" exists
    When I send a GET request for product "unknown-id"
    Then the response status should be 404
    And the error message should mention "not found"

  @api @read @search
  Scenario: Search products by name
    Given the following products exist:
      | ID     | Name          | Price   |
      | prod-1 | Gaming Laptop | 1299.99 |
      | prod-2 | Office Laptop | 799.99  |
      | prod-3 | Desktop PC    | 1599.99 |
    When I search for products containing "Laptop"
    Then the response status should be 200
    And I should get 2 products
    And all products should contain "Laptop" in the name

  @api @update
  Scenario: Update product details
    Given I have valid product details:
      | Field | Value          |
      | Name  | Original Name  |
      | Price | 999.99         |
    When I send a POST request to create the product
    Then the response status should be 201
    When I send a PUT request to update the last created product with:
      | Field | Value    |
      | Name  | New Name |
      | Price | 1099.99  |
    Then the response status should be 204
