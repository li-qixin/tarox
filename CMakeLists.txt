cmake_minimum_required(VERSION 3.10 FATAL_ERROR)
set(TAROX_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE FILEPATH "tarox source directory" FORCE)
set(TAROX_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE FILEPATH "tarox binary directory" FORCE)

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

# Find Python
find_package(PythonInterp 3)
# We have a custom error message to tell users how to install python3.
if(NOT PYTHONINTERP_FOUND)
	message(FATAL_ERROR "Python 3 not found. Please install Python 3:\n"
		"    Ubuntu: sudo apt install python3 python3-dev python3-pip\n"
		"    macOS: brew install python")
endif()

include(tarox_config)
include(kconfig)

message(STATUS "tarox config: ${TAROX_CONFIG}")
message(STATUS "tarox platform: ${TAROX_PLATFORM}")
include(${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake/tarox_impl_os.cmake)
list(APPEND CMAKE_MODULE_PATH ${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake)

if(EXISTS "${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake/init.cmake")
  include(init)
endif()

#===============================================================================
# project configuration
#===============================================================================
project(tarox CXX C ASM)

if(NOT CMAKE_BUILD_TYPE)
  if(${TAROX_PLATFORM} STREQUAL "nuttx")
    set(TAROX_BUILD_TYPE "MinSizeRel")
  else()
    set(TAROX_BUILD_TYPE "RelWithDebInfo")
  endif()

  set(CMAKE_BUILD_TYPE ${TAROX_BUILD_TYPE} CACHE STRING "build type" FORCE)
endif()

message(STATUS "cmake build type: ${CMAKE_BUILD_TYPE}")

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${TAROX_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${TAROX_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${TAROX_BINARY_DIR})

#=============================================================================
# get chip and chip manufacturer
#=============================================================================
tarox_os_determine_build_chip()
if(NOT TAROX_CHIP_MANUFACTURER)
	message(FATAL_ERROR "tarox_os_determine_build_chip() needs to set TAROX_CHIP_MANUFACTURER")
endif()
if(NOT TAROX_CHIP)
	message(FATAL_ERROR "tarox_os_determine_build_chip() needs to set TAROX_CHIP")
endif()

#=============================================================================
# nuttx added last to generate the builtin for included modules
#=============================================================================
add_subdirectory(platforms/${TAROX_PLATFORM})