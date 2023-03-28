set(NOSTDINC "")

# Note that NOSYSDEF_CFLAG may be an empty string, and
# set_ifndef() does not work with empty string.
if(NOT DEFINED NOSYSDEF_CFLAG)
  set(NOSYSDEF_CFLAG -undef)
endif()

# find zigcc and zigc++ which are at this repo root (=TOOLCHAIN_ROOT)
if(DEFINED TOOLCHAIN_ROOT)
  set(find_program_zig_args PATHS ${TOOLCHAIN_ROOT} NO_DEFAULT_PATH)
endif()

find_program(CMAKE_C_COMPILER zigcc ${find_program_zig_args})
find_program(CMAKE_CXX_COMPILER zigc++ ${find_program_zig_args})

#list(APPEND TOOLCHAIN_C_FLAGS  -fintegrated-as) #   Enable the integrated assembler
 

if(NOT "${ARCH}" STREQUAL "posix")
  # include(${ZEPHYR_BASE}/cmake/gcc-m-cpu.cmake)

  if("${ARCH}" STREQUAL "arm")

    set(ZIG_TARGET arm-freestanding-eabi)
    
    if (CONFIG_CPU_CORTEX_M0)
      set(ZIG_M_CPU cortex_m0)
    elseif(CONFIG_CPU_CORTEX_M0PLUS)
      set(ZIG_M_CPU cortex_m0plus)
    elseif(CONFIG_CPU_CORTEX_M1)
      set(ZIG_M_CPU cortex_m1)
    elseif(CONFIG_CPU_CORTEX_M3)
      set(ZIG_M_CPU cortex_m3)
    elseif(CONFIG_CPU_CORTEX_M4)
      set(ZIG_M_CPU cortex_m4)
    else()
      message(FATAL_ERROR "Expected CONFIG_CPU_CORTEX_x to be defined")
    endif()

    
    list(APPEND TOOLCHAIN_C_FLAGS -fshort-enums )
    list(APPEND TOOLCHAIN_LD_FLAGS -fshort-enums )
      
    # include(${ZEPHYR_BASE}/cmake/compiler/gcc/target_arm.cmake)
    
  endif() # "${ARCH}" STREQUAL "arm"

  list(APPEND TOOLCHAIN_C_FLAGS -target ${ZIG_TARGET})
  list(APPEND TOOLCHAIN_C_FLAGS -mcpu=${ZIG_M_CPU})

  
  foreach(file_name include/stddef.h)
    execute_process(
      COMMAND ${CMAKE_C_COMPILER} --print-file-name=${file_name}
      OUTPUT_VARIABLE _OUTPUT
      )
    get_filename_component(_OUTPUT "${_OUTPUT}" DIRECTORY)
    string(REGEX REPLACE "\n" "" _OUTPUT ${_OUTPUT})

    list(APPEND NOSTDINC ${_OUTPUT})
  endforeach()

  foreach(isystem_include_dir ${NOSTDINC})
    list(APPEND isystem_include_flags -isystem "\"${isystem_include_dir}\"")
  endforeach()

  #if(CONFIG_X86)
  #  if(CONFIG_64BIT)
  #    string(APPEND TOOLCHAIN_C_FLAGS "-m64")
  #  else()
  #    string(APPEND TOOLCHAIN_C_FLAGS "-m32")
  #  endif()
  #endif()

  # This libgcc code is partially duplicated in compiler/*/target.cmake
  execute_process(
    COMMAND ${CMAKE_C_COMPILER} ${TOOLCHAIN_C_FLAGS} --print-libgcc-file-name
    OUTPUT_VARIABLE LIBGCC_FILE_NAME
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )

  get_filename_component(LIBGCC_DIR ${LIBGCC_FILE_NAME} DIRECTORY)

  list(APPEND LIB_INCLUDE_DIR "-L\"${LIBGCC_DIR}\"")
  if(LIBGCC_DIR)
    list(APPEND TOOLCHAIN_LIBS gcc)
  endif()

  list(APPEND CMAKE_REQUIRED_FLAGS -nostartfiles -nostdlib ${isystem_include_flags})
  string(REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS}")

endif()


message(NOTICE "Setup target zig compiler")
message(NOTICE "Found zig c compiler: ${CMAKE_C_COMPILER}")
message(NOTICE "Call with flags: ${TOOLCHAIN_C_FLAGS}")


# Load toolchain_cc-family macros

macro(toolchain_cc_nostdinc)
  if(NOT "${ARCH}" STREQUAL "posix")
    zephyr_compile_options( -nostdinc)
  endif()
endmacro()
