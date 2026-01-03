add_executable(tarox ${TAROX_SOURCE_DIR}/platforms/common/empty.c)
set(FW_NAME ${TAROX_BOARD_VENDOR}_${TAROX_BOARD_MODEL}_${TAROX_BOARD_LABEL}.elf)
set_target_properties(tarox PROPERTIES OUTPUT_NAME ${FW_NAME}) 
add_dependencies(tarox git_nuttx)

add_subdirectory(Nuttx ${TAROX_BINARY_DIR}/Nuttx)

