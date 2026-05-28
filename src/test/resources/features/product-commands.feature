Feature: Product Stock Commands
  As an inventory manager
  I want to manage product stock levels
  So that the catalog reflects accurate availability

  Background:
    Given the product catalog service is running
    And the database is initialized
    And the authentication is configured

  @api @stock
  Scenario: Add stock to a product
    Given I have valid product details:
      | Field | Value  |
      | Name  | Laptop |
      | Price | 999.99 |
    When I send a POST request to create the product
    Then the response status should be 201
    When I send a POST request to add 50 units of stock to the last created product
    Then the response status should be 200

  @api @stock @validation
  Scenario: Cannot remove more stock than available
    Given I have valid product details:
      | Field | Value       |
      | Name  | Low Stock PC |
      | Price | 599.99      |
    When I send a POST request to create the product
    Then the response status should be 201
    When I send a DELETE request to remove 999 units of stock from the last created product
    Then the response status should be 422
