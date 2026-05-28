package com.example.productcatalog.infrastructure.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Security configuration for the {@code poc} Spring profile.
 *
 * <p>Disables all authentication so every endpoint — including write
 * operations — is publicly accessible. <strong>Do not use in production.</strong>
 *
 * <p>When {@code SPRING_PROFILES_ACTIVE=poc} (set in docker-compose.poc.yml),
 * this bean is used instead of {@link SecurityConfig}.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@Profile("poc")
public class PocSecurityConfig {

    @Bean
    public SecurityFilterChain pocSecurityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .build();
    }
}
