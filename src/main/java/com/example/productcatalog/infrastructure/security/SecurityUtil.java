package com.example.productcatalog.infrastructure.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Optional;

/**
 * Static helpers for reading the current security context.
 */
public final class SecurityUtil {

    private SecurityUtil() {}

    /** Returns the username of the currently authenticated user, if any. */
    public static Optional<String> getCurrentUsername() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) return Optional.empty();

        Object principal = auth.getPrincipal();
        if (principal instanceof UserDetails ud) return Optional.of(ud.getUsername());
        if (principal instanceof String s)       return Optional.of(s);
        return Optional.empty();
    }

    /** Returns {@code true} if the current user has the given role (without the ROLE_ prefix). */
    public static boolean hasRole(String role) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return false;
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_" + role));
    }
}
