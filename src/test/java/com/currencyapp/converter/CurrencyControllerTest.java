package com.currencyapp.converter;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

// NEW: Updated Spring Boot 4 package location for WebMvcTest
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
// NEW: MockBean is now MockitoBean in Spring Framework 7
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.RestTemplate;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(
        controllers = CurrencyController.class,
        properties = {
                "currency.api.key=test-mock-key",
                "currency.api.url=http://mock-api.com"
        }
)
class CurrencyControllerTest {

    @Autowired
    private MockMvc mockMvc;

    // CHANGED: Use @MockitoBean instead of @MockBean
    @MockitoBean
    private RestTemplate restTemplate;

    @Test
    void testIndexPageLoads() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(view().name("index"))
                .andExpect(model().attribute("from", "USD"))
                .andExpect(model().attribute("to", "INR"));
    }

    @Test
    void testConversionSuccess() throws Exception {
        CurrencyController.ExchangeResponse mockResponse =
                new CurrencyController.ExchangeResponse("success", 83.50);

        when(restTemplate.getForObject(
                any(String.class),
                eq(CurrencyController.ExchangeResponse.class),
                any(), any(), any(), any()
        )).thenReturn(mockResponse);

        mockMvc.perform(post("/convert")
                        .param("from", "USD")
                        .param("to", "INR")
                        .param("amount", "1.0"))
                .andExpect(status().isOk())
                .andExpect(view().name("index"))
                .andExpect(model().attribute("result", "83.5 INR"))
                .andExpect(model().attributeDoesNotExist("error"));
    }

    @Test
    void testConversionApiFailure() throws Exception {
        when(restTemplate.getForObject(
                any(String.class),
                eq(CurrencyController.ExchangeResponse.class),
                any(), any(), any(), any()
        )).thenThrow(new RuntimeException("Connection Timeout"));

        mockMvc.perform(post("/convert")
                        .param("from", "USD")
                        .param("to", "EUR")
                        .param("amount", "100.0"))
                .andExpect(status().isOk())
                .andExpect(view().name("index"))
                .andExpect(model().attributeExists("error"))
                .andExpect(model().attribute("error", "Failed to connect to the currency service."));
    }
}