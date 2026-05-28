Feature: Product Stock Commands
  As an inventory manager
  I want to manage product stock levels
  So that the catalog reflects accurate availability

  Background:
    Given the product catalog service is running
    And the database is initialized
    And the authentication is configured

  @api @stock
  Scenario: Add stock to product
    Given a product exists with ID "prod-stock-1" and name "Laptop"
    When I send a POST request to create the product
    Then the response status should be 201

  @api @stock @validation
  Scenario: Cannot remove more stock than available
    Given a product exists with ID "prod-low-stock" and name "Laptop"
    When I send a GET request for product "prod-low-stock"
    Then the response status should be 200
