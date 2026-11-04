package com.comicreading.security;

public record AppPrincipal(Long userId, String email, String role) {}
