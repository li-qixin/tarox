if("${CMAKE_CXX_COMPILER_ID}" MATCHES "GNU")
	if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS_EQUAL 7)
		message(FATAL_ERROR "GCC 7 or older no longer supported.")
	endif()
endif()

if(NOT TAROX_BOARD)
  message(FATAL_ERROR "TAROX_BOARD must be set (flysq_v1)")
endif()

if(NOT TAROX_BINARY_DIR)
  message(FATAL_ERROR "TAROX_BINARY_DIR must be set")
endif()

set(NUTTX_CONFIG_DIR ${TAROX_BOARD_DIR}/nuttx-config CACHE FILEPATH "nuttx config path" FORCE)

# nuttx defconfig
# NUTTX_CONFIG is set in the file of tarox_impl_os.cmake (default is nsh)
set(NUTTX_DEFCONFIG ${NUTTX_CONFIG_DIR}/${NUTTX_CONFIG}/defconfig CACHE FILEPATH "path to defconfig" FORCE)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${NUTTX_DEFCONFIG})

set(NUTTX_SRC_DIR ${TAROX_SOURCE_DIR}/platforms/nuttx/Nuttx)
set(NUTTX_KERNEL_DIR ${TAROX_SOURCE_DIR}/platforms/nuttx/Nuttx/nuttx CACHE FILEPATH "nuttx kernel directory" FORCE)
set(NUTTX_APPS_DIR ${TAROX_SOURCE_DIR}/platforms/nuttx/Nuttx/apps CACHE FILEPATH "nuttx apps directory" FORCE)

execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${NUTTX_CONFIG_DIR}/src)
execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_SRC_DIR}/Make.defs.in ${NUTTX_KERNEL_DIR}/Make.defs)
execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_DEFCONFIG} ${NUTTX_KERNEL_DIR}/.config)
execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_DEFCONFIG} ${NUTTX_KERNEL_DIR}/defconfig)

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${NUTTX_KERNEL_DIR}/defconfig)

execute_process(
  COMMAND ${NUTTX_SRC_DIR}/tools/tarox_nuttx_make_olddefconfig.sh
  WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
  OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/nuttx_olddefconfig.log
  RESULT_VARIABLE ret
)

execute_process(
  COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_CURRENT_BINARY_DIR}/defconfig_inflate_stamp
  WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
)

execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_KERNEL_DIR}/.config ${TAROX_BINARY_DIR}/Nuttx/nuttx/.config)

file(STRINGS ${TAROX_BINARY_DIR}/Nuttx/nuttx/.config ConfigContents)
foreach(NameAndValue ${ConfigContents})
  string(REGEX "^[]+" "" NameAndValue ${NameAndValue})
  string(REGEX MATCH "^CONFIG[^=]+" Name ${NameAndValue})
  if(Name)
    string(REPLACE "${Name}=" "" Value ${NameAndValue})
    string(REPLACE "\"" "" Value ${Value})
    
    set(${Name} ${Value} CACHE INTERNAL "NUTTX DEFCONFIG: ${Name}" FORCE)
  endif()
endforeach()

# =======================================================================
#
# merge ${BOARD_CONFIG} and ${TAROX_BINARY_DIR}/Nuttx/nuttx/.config
# into ${BOARD_CONFIG}, if a fragment in two files is same, last one wins
#
# (here ${BOARD_CONFIG} is ${TAROX_BINARY_DIR}/boardconfig)
# 
# =======================================================================
execute_process(
  COMMAND ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTING}
  ${PYTHON_EXECUTABLE} ${TAROX_SOURCE_DIR}/tools/kconfig/merge_config.py Kconfig ${BOARD_CONFIG} ${BOARD_CONFIG} ${TAROX_BINARY_DIR}/Nuttx/nuttx/.config
  WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
  OUTPUT_VARIABLE DUMMY_RESULTS
)