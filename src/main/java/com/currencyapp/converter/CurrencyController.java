package com.currencyapp.converter;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.client.RestTemplate;

@Controller
public class CurrencyController {

    // Inject configuration values from application.properties
    @Value("${currency.api.key}")
    private String apiKey;

    @Value("${currency.api.url}")
    private String apiUrl;

    // RestTemplate handles HTTP requests to external APIs
    private final RestTemplate restTemplate;

    // Spring Boot automatically injects the Bean here
    public CurrencyController(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @GetMapping("/")
    public String index(Model model) {
        model.addAttribute("amount", 1.0);
        model.addAttribute("from", "USD");
        model.addAttribute("to", "INR");
        return "index";
    }

    @PostMapping("/convert")
    public String convert(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam double amount,
            Model model) {

        try {
            // Spring safely substitutes the {placeholders} in the URL in order
            ExchangeResponse response = restTemplate.getForObject(
                    apiUrl,
                    ExchangeResponse.class,
                    apiKey, from, to, amount
            );

            // Verify the API call was successful
            if (response != null && "success".equals(response.result())) {
                model.addAttribute("result", response.conversion_result() + " " + to);
            } else {
                model.addAttribute("error", "The external API returned an error.");
            }
        } catch (Exception e) {
            // Catch network errors, invalid keys, or API downtime
            model.addAttribute("error", "Failed to connect to the currency service.");
        }

        // Persist form data on the screen so the user doesn't have to re-type it
        model.addAttribute("amount", amount);
        model.addAttribute("from", from);
        model.addAttribute("to", to);

        return "index";
    }

    // Spring Boot's built-in Jackson library automatically maps the API's JSON to this record.
    // It safely ignores any extra JSON fields the API sends that we don't need.
    public record ExchangeResponse(String result, double conversion_result) {}
}