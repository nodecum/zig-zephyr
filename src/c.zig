pub const c = @cImport({
    // Zephyr Defines
    @cDefine("Kernel", "");
    @cDefine("NRF52840_XXAA", "");
    @cDefine("__PROGRAM_START", "");
    @cDefine("__ZEPHYR__", "1");
    @cInclude("autoconf.h");
    @cInclude("zephyr/toolchain/zephyr_stdint.h");
    @cInclude("zephyr/kernel.h");
    @cInclude("zephyr/drivers/gpio.h");
});
