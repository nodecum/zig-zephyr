#include_guard(GLOBAL)
#include(extensions)
#include(python)

#include(CMakeParseArguments)

include(cmake/compiler/zig/zig-target.cmake)

message("zig.cmake\n========")

# find zig script which is at this repo root 
set(find_program_zigscript_args PATHS ${CMAKE_CURRENT_SOURCE_DIR} NO_DEFAULT_PATH)

find_program(ZIG_BUILD_OBJ zig_build_obj ${find_program_zigscript_args})
message("ZIG_BUILD_OBJ: ${ZIG_BUILD_OBJ}")

set(EDT_LIB $ENV{ZEPHYR_BASE}/scripts/dts/python-devicetree/src)
set(DTS_ZIG_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/gen_dts_zig.py)
set(PROJECT_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/zephyr)
set(DTS_ZIG        ${PROJECT_BINARY_DIR}/include/generated/devicetree_generated.zig)

function(create_dts_zig)

add_custom_command(
  OUTPUT ${DTS_ZIG}
  COMMAND ${PYTHON_EXECUTABLE} ${DTS_ZIG_SCRIPT}
  --edt-lib ${EDT_LIB} 
  --edt-pickle ${EDT_PICKLE}
  --zig-out ${DTS_ZIG}
  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
  VERBATIM
  DEPENDS ${EDT_PICKLE} ${DTS_ZIG_SCRIPT}
)
add_custom_target( generate_dts_zig DEPENDS ${DTS_ZIG})
message("dts_zig:${DTS_ZIG}")
endfunction()  


# arguments: target zig-source-file dependent-source-files
function(add_zig_obj) 
    # set the target binary
    list(POP_FRONT ARGN our_target)
    message("add_zig_obj: target:${our_target}")
    list(POP_FRONT ARGN zig_src)
    message("add_zig_obj: src:${zig_src}")

    set(zig_bin "${PROJECT_BINARY_DIR}/CMakeFiles/${our_target}.dir/${zig_src}.obj")
    message("add_zig_obj: bin:${zig_bin}")
   
    # set the main source file
    set(src_file "${CMAKE_CURRENT_SOURCE_DIR}/${zig_src}")
    
    # collect set of depedent source files
    set(dep_files "")
    foreach(src ${ARGN})
      list(APPEND dep_files "${CMAKE_CURRENT_SOURCE_DIR}/${src}")
    endforeach()
    message("add_zig_obj: dep:${dep_files}") 

    # add custom command to call the zig compiler
    add_custom_command(
      OUTPUT ${zig_bin}
      COMMAND ${ZIG_BUILD_OBJ}  
      # --verbose-link --verbose-cimport
      -freference-trace
      -fbuiltin
      -O ReleaseSmall
      # the cImports
      --mod c::${CMAKE_CURRENT_SOURCE_DIR}/src/c.zig
      # allow inclusion of our generated devicetree
      --mod devicetree:c:${DTS_ZIG}
      --deps c,devicetree 
      -target ${ZIG_TARGET} -mcpu=${ZIG_M_CPU} -femit-bin=${zig_bin}
      "-I${CMAKE_CURRENT_SOURCE_DIR}/src"
      "-I$<JOIN:$<TARGET_PROPERTY:app,INTERFACE_INCLUDE_DIRECTORIES>,;-I>"
      -fno-PIC -fno-PIE
      ${src_file} 
      COMMAND_EXPAND_LISTS
      VERBATIM
      DEPENDS ${src_file} ${dep_files} generate_dts_zig
    )
    target_sources( ${our_target} PRIVATE ${zig_bin} )

endfunction()


