cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

set(TAROX_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE FILEPATH "tarox source directory" FORCE)
set(TAROX_BIRNARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE FILEPATH "tarox binary directory" FORCE)

list(APPEND CMAKE_MODULE_PATH ${TAROX_SOURCE_DIR}/cmake)
include(tarox_parse_function_args)

define_property(GLOBAL PROPERTY TAROX_MODULE_LIBRARIES
                BRIEF_DOCS "tarox module libs"
                FULL_DOCS "list of all tarox module libraries")

define_property(GLOBAL PROPERTY TAROX_KERNEL_MODULE_LIBRARIES
                BRIEF_DOCS "tarox kernel side module libs"
                FULL_DOCS "list of all tarox kernel module libraries")
                
define_property(GLOBAL PROPERTY TAROX_MODULE_PATHS
                BRIEF_DOCS "tarox module path"
                FULL_DOCS "list of paths to all tarox module")

define_property(GLOBAL PROPERTY TAROX_SRC_FILES
                BRIEF_DOCS "src files from all tarox modules and libs"
                FULL_DOCS "src files from tarox_add_{module, library}")

include(tarox_add_module)

set(config_module_list)
set(config_kernel_list)
include(tarox_config)
include(${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake/tarox_impl_os.cmake)
list(APPEND CMAKE_MODULE_PATH ${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake)

project(tarox CXX C ASM)