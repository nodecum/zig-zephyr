const c = @import("c").c;
const dt = @import("devicetree");

// get a c.struct_gpio_dt_spec from devicetree gpios property
fn gpio_dt_spec(gpios: anytype) c.struct_gpio_dt_spec {
    return .{ .port = gpios.ph._device, .pin = gpios.pin, .dt_flags = gpios.flags };
}

const led = gpio_dt_spec(dt.leds.led_0.gpios);

pub export fn main() void {
    var ret: c_int = undefined;
    if (!c.device_is_ready(led.port)) return;

    ret = c.gpio_pin_configure_dt(&led, c.GPIO_OUTPUT_ACTIVE);
    if (ret < 0) return;

    while (true) {
        ret = c.gpio_pin_toggle_dt(&led);
        if (ret < 0) return;
        _ = c.k_msleep(1000);
    }
}
