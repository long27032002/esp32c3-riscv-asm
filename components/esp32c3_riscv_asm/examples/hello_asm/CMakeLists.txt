# Example project: hello_asm
#
# Two ways this example gets built, and both must work:
#
#   from a git clone     the component sits next to this example, three
#                        directories up, and EXTRA_COMPONENT_DIRS finds it
#                        under its real name, esp32c3_riscv_asm
#
#   from the registry    idf.py create-project-from-example copies only this
#                        example out; EXTRA_COMPONENT_DIRS then points at
#                        nothing and the component manager resolves the
#                        dependency declared in main/idf_component.yml
cmake_minimum_required(VERSION 3.16)

get_filename_component(COMPONENTS_DIR "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
if(EXISTS "${COMPONENTS_DIR}/esp32c3_riscv_asm/idf_component.yml")
    set(EXTRA_COMPONENT_DIRS "${COMPONENTS_DIR}")
endif()

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(hello_asm)
