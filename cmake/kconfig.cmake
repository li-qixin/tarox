set(BOARD_DEFCONFIG
    ${TAROX_CONFIG_FILE}
    CACHE FILEPATH "path to defconfig" FORCE)
set(BOARD_CONFIG
    ${TAROX_BINARY_DIR}/boardconfig
    CACHE FILEPATH "path to config" FORCE)

execute_process(COMMAND ${PYTHON_EXECUTABLE} -c "import menuconfig"
                RESULT_VARIABLE ret)
if(ret EQUAL "1")
  message(FATAL_ERROR "kconfiglib is not installed or not in PATH\n"
                      "please install using \"pip3 install kconfiglib\"\n")
endif()

set(MENUCONFIG_PATH
    ${PYTHON_EXECUTABLE} -m menuconfig
    CACHE INTERNAL "menuconfig program" FORCE)
set(GUICONFIG_PATH
    ${PYTHON_EXECUTABLE} -m guiconfig
    CACHE INTERNAL "guiconfig program" FORCE)
set(DEFCONFIG_PATH
    ${PYTHON_EXECUTABLE} -m defconfig
    CACHE INTERNAL "defconfig program" FORCE)
set(SAVEDEFCONFIG_PATH
    ${PYTHON_EXECUTABLE} -m savedefconfig
    CACHE INTERNAL "savedefconfig program" FORCE)
set(GENCONFIG_PATH
    ${PYTHON_EXECUTABLE} -m genconfig
    CACHE INTERNAL "genconfig program" FORCE)

set(COMMON_KCONFIG_ENV_SETTINGS
    PYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}
    KCONFIG_CONFIG=${BOARD_CONFIG}
    # Set environment variables so that Kconfig can prune Kconfig source files
    # for other architectures
    PLATFORM=${TAROX_PLATFORM}
    VENDOR=${TAROX_BOARD_VENDOR}
    MODEL=${TAROX_BOARD_MODEL}
    LABEL=${TAROX_BOARD_LABEL}
    TOOLCHAIN=${CMAKE_TOOLCHAIN_FILE}
    ARCHITECTURE=${CMAKE_SYSTEM_PROCESSOR}
    ROMFSROOT=${config_romfs_root}
    BASE_DEFCONFIG=${BOARD_CONFIG})

set(config_user_list)

if(EXISTS ${BOARD_DEFCONFIG})

  # Depend on BOARD_DEFCONFIG so that we reconfigure on config change
  set_property(
    DIRECTORY
    APPEND
    PROPERTY CMAKE_CONFIGURE_DEPENDS ${BOARD_DEFCONFIG})
  if(${LABEL} MATCHES "default")
    # Generate boardconfig from saved defconfig
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS}
              ${DEFCONFIG_PATH} ${BOARD_DEFCONFIG}
      WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
      OUTPUT_VARIABLE DUMMY_RESULTS)
  else()
    # Generate boardconfig from default.taroxboard and {label}.taroxboard
    execute_process(
      COMMAND
        ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS}
        ${PYTHON_EXECUTABLE} ${TAROX_SOURCE_DIR}/Tools/kconfig/merge_config.py
        Kconfig ${BOARD_CONFIG} ${TAROX_BOARD_DIR}/default.taroxboard
        ${BOARD_DEFCONFIG}
      WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
      OUTPUT_VARIABLE DUMMY_RESULTS)
  endif()

  # Generate header file for C/C++ preprocessor
  execute_process(
    COMMAND
      ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS} ${GENCONFIG_PATH}
      --header-path ${TAROX_BINARY_DIR}/tarox_boardconfig.h
    WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
    OUTPUT_VARIABLE DUMMY_RESULTS)

  # parse board config options for cmake
  file(STRINGS ${BOARD_CONFIG} ConfigContents)
  foreach(NameAndValue ${ConfigContents})
    # Strip leading spaces
    string(REGEX REPLACE "^[ ]+" "" NameAndValue ${NameAndValue})

    # Find variable name
    string(REGEX MATCH "^CONFIG[^=]+" Name ${NameAndValue})

    if(Name)
      # Find the value
      string(REPLACE "${Name}=" "" Value ${NameAndValue})

      # remove extra quotes
      string(REPLACE "\"" "" Value ${Value})

      # Set the variable
      set(${Name}
          ${Value}
          CACHE INTERNAL "BOARD DEFCONFIG: ${Name}" FORCE)

    else()
      # Find boolean not set
      string(REGEX MATCH " (CONFIG[^ ]+) is not set" Name ${NameAndValue})

      if(${CMAKE_MATCH_1})
        set(${CMAKE_MATCH_1}
            ""
            CACHE INTERNAL "BOARD DEFCONFIG: ${CMAKE_MATCH_1}" FORCE)
      endif()
    endif()

  # Find variable name
  string(REGEX MATCH "^CONFIG_BOARD_" Board ${NameAndValue})

  if(Board)
    string(REPLACE "CONFIG_BOARD_" "" ConfigKey ${Name})
    if(Value)
      set(${ConfigKey} ${Value})
      message(STATUS "${ConfigKey}: ${Value}")
    endif()
  endif()

  endforeach()

endif()

if(PLATFORM)
  # set OS, and append specific platform module path
  set(TAROX_PLATFORM ${PLATFORM} CACHE STRING "tarox board OS" FORCE)
  list(APPEND CMAKE_MODULE_PATH ${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/cmake)

  # platform-specific include path
  include_directories(${TAROX_SOURCE_DIR}/platforms/${TAROX_PLATFORM}/src/tarox/common/include)
endif()

if(${LABEL} MATCHES "default")
  add_custom_target(
    boardconfig
    ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS} ${MENUCONFIG_PATH}
    Kconfig
    COMMAND ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS}
            ${SAVEDEFCONFIG_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy defconfig ${BOARD_DEFCONFIG}
    COMMAND ${CMAKE_COMMAND} -E remove defconfig
    COMMAND ${CMAKE_COMMAND} -E remove ${TAROX_BINARY_DIR}/NuttX/apps_copy.stamp
    WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
    USES_TERMINAL COMMAND_EXPAND_LISTS)

  add_custom_target(
    boardguiconfig
    ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS} ${GUICONFIG_PATH}
    Kconfig
    COMMAND ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS}
            ${SAVEDEFCONFIG_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy defconfig ${BOARD_DEFCONFIG}
    COMMAND ${CMAKE_COMMAND} -E remove defconfig
    COMMAND ${CMAKE_COMMAND} -E remove ${TAROX_BINARY_DIR}/NuttX/apps_copy.stamp
    WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
    USES_TERMINAL COMMAND_EXPAND_LISTS)

  add_custom_target(
    tarox_savedefconfig
    ${CMAKE_COMMAND} -E env ${COMMON_KCONFIG_ENV_SETTINGS} ${SAVEDEFCONFIG_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy defconfig ${BOARD_DEFCONFIG}
    COMMAND ${CMAKE_COMMAND} -E remove defconfig
    COMMAND ${CMAKE_COMMAND} -E remove ${TAROX_BINARY_DIR}/NuttX/apps_copy.stamp
    WORKING_DIRECTORY ${TAROX_SOURCE_DIR}
    USES_TERMINAL COMMAND_EXPAND_LISTS)


endif()
