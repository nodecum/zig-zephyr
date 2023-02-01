# for generic compile use the zephyr sdk 
include(${ZEPHYR_BASE}/cmake/toolchain/zephyr/generic.cmake)
message(NOTICE "toolchain/zig/generic: => toolchain/zepyr/generic")
message(NOTICE "TOOLCHAIN_ROOT:${TOOLCHAIN_ROOT}")
message(NOTICE "CMAKE_LINKER:${CMAKE_LINKER}")
