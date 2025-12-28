if(NOT CONFIG)
  set(CONFIG
      "flysq_v1_default"
      CACHE STRING "desired configuration")
endif()

# =============================================================================
# the purpose of this file is to configure what is the current project and what
# configure file does this project use.
#
# below each variable are used with example of
#
# make flysq-v1_default
#
# =============================================================================
if(NOT TAROX_CONFIG_FILE)
  file(
    GLOB_RECURSE board_configs
    RELATIVE "${TAROX_SOURCE_DIR}/boards"
    "boards/*.taroxboard")

  foreach(filename ${board_configs})
    string(REPLACE ".taroxboard" "" filename_stripped ${filename})
    string(REPLACE "/" ";" config ${filename_stripped})
    list(LENGTH config config_len)
    if(${config_len} EQUAL 3)
      list(GET config 0 vendor)
      list(GET config 1 model)
      list(GET config 2 label)

      set(board "${vendor}${model}")
      if((${CONFIG} MATCHES "${vendor}_${model}_${label}")
         OR ((${label} STREQUAL "default") AND (${CONFIG} STREQUAL
                                                "${vendor}_${model}")))
        set(TAROX_CONFIG_FILE
            "${TAROX_SOURCE_DIR}/boards/${filename}"
            CACHE FILEPATH "path to TAROX CONFIG file" FORCE)
        set(TAROX_BOARD_DIR
            "${TAROX_SOURCE_DIR}/boards/${vendor}/${model}"
            CACHE STRING "tarox board directory" FORCE)
        set(MODEL
            "${model}"
            CACHE STRING "tarox board model" FORCE)
        set(VENDOR
            "${vendor}"
            CACHE STRING "tarox board vendor" FORCE)
        set(LABEL
            "${label}"
            CACHE STRING "tarox board vendor" FORCE)
        break()
      endif()
    endif()
  endforeach()
endif()

# =============================================================================
#
# TAROX_CONFIG_FILE: ${TAROX_SOURCE_DIR}/boards/flysq/v1/default.taroxboard
# TAROX_BOARD_DIR: ${TAROX_SOURCE_DIR}/boards/flysq/v1
#
# =============================================================================

message(STATUS "tarox config file: ${TAROX_CONFIG_FILE}")

include_directories(${TAROX_BOARD_DIR}/src)

set(TAROX_BOARD
    ${VENDOR}_${MODEL}
    CACHE STRING "tarox board" FORCE)

string(TOUPPER ${TAROX_BOARD} TAROX_BOARD_NAME)
string(REPLACE "-" "_" TAROX_BOARD_NAME ${TAROX_BOARD_NAME})

# TAROX_BOARD_NAME = FLYSQ_V1
set(TAROX_BOARD_NAME
    ${TAROX_BOARD_NAME}
    CACHE STRING "tarox board name" FORCE)

set(TAROX_BOARD_VENDOR
    ${VENDOR}
    CACHE STRING "TAROX board vendor" FORCE)
set(TAROX_BOARD_MODEL
    ${MODEL}
    CACHE STRING "TAROX board model" FORCE)
set(TAROX_BOARD_LABEL
    ${LABEL}
    CACHE STRING "TAROX board label" FORCE)

set(TAROX_CONFIG
    "${TAROX_BOARD_VENDOR}_${TAROX_BOARD_MODEL}_${TAROX_BOARD_LABEL}"
    CACHE STRING "tarox config" FORCE)
