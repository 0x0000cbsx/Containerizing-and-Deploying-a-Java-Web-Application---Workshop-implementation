package co.edu.escuelaing.virtualizationlab;

import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class RestServiceApplication {

    public static void main(String[] args) {
        SpringApplication application =
                new SpringApplication(RestServiceApplication.class);

        application.setDefaultProperties(
                Map.of("server.port",
                        System.getenv().getOrDefault("PORT", "6000")));

        application.run(args);
    }
}
