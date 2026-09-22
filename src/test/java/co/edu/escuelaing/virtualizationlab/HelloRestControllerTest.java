package co.edu.escuelaing.virtualizationlab;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class HelloRestControllerTest {

    private final HelloRestController controller = new HelloRestController();

    @Test
    void greetingUsesDefaultNameWhenNoneIsGiven() {
        assertThat(controller.greeting("World")).isEqualTo("Hello, World!");
    }

    @Test
    void greetingUsesTheGivenName() {
        assertThat(controller.greeting("Pedro")).isEqualTo("Hello, Pedro!");
    }
}
