# -*- mode: cmake -*-
# SPDX-License-Identifier: Apache-2.0

# using zig cc as c compiler to compile zephyr

cmake_minimum_required(VERSION 3.13.1)

if(USEZIG)
  # use zig as toolchain
  set(ZEPHYR_SDK_INSTALL_DIR $ENV{HOME}/bin/zephyr-sdk-0.15.1)
  set(ZEPHYR_TOOLCHAIN_VARIANT zig)
  set(TOOLCHAIN_ROOT  ${CMAKE_CURRENT_SOURCE_DIR}) # set this repo as toolchain root
else()
  # use the zephyr-sdk as toolchain
  set(ZEPHYR_TOOLCHAIN_VARIANT zephyr)
endif()

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(blinky)

target_sources (app PRIVATE src/main.c) 


