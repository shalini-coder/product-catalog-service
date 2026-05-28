package com.example.productcatalog.bdd.steps;

import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.HttpStatus.OK;

/**
 * Reusable step definitions shared across all feature files.
 */
@Slf4j
public class CommonStepDefinitions {

    @Autowired
    private TestRestTemplate restTemplate;

    @Before
    public void resetSharedState() {
        log.debug("Resetting shared BDD state before scenario");
    }

    @Given("the product catalog service is running")
    public void serviceIsRunning() {
        var health = restTemplate.getForEntity("/actuator/health", String.class);
        assertThat(health.getStatusCode()).isEqualTo(OK);
    }

    @Given("the authentication is configured")
    public void authenticationIsConfigured() {
        // JWT token set up per-scenario in step definition subclasses
    }
}
