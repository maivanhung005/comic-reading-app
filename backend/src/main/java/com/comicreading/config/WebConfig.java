package com.comicreading.config;

import org.springframework.context.annotation.Configuration;

/** Uploaded files are deliberately served by MediaController so permission and age checks cannot be bypassed. */
@Configuration
public class WebConfig {}
