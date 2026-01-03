set(NUTTX_CONFIG_DIR ${TAROX_BOARD_DIR}/nuttx-config)
set(APPS_DIR ${NUTTX_SRC_DIR}/apps)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/nuttx)
configure_file(${TAROX_SOURCE_DIR}/platforms/nuttx/Nuttx/Make.defs.in ${CMAKE_CURRENT_BINARY_DIR}/nuttx/Make.defs)

add_custom_command(
	OUTPUT ${NUTTX_KERNEL_DIR}/.config
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/nuttx/Make.defs ${NUTTX_KERNEL_DIR}/Make.defs
	COMMAND cat ${NUTTX_DEFCONFIG} ${EXTRA_NUTTX_CONFIG_FILE} > ${NUTTX_KERNEL_DIR}/.config
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_DEFCONFIG} ${NUTTX_KERNEL_DIR}/defconfig
	COMMAND ${NUTTX_SRC_DIR}/tools/px4_nuttx_make_olddefconfig.sh > ${CMAKE_CURRENT_BINARY_DIR}/nuttx_olddefconfig.log
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_KERNEL_DIR}/.config ${CMAKE_CURRENT_BINARY_DIR}/nuttx/.config
	DEPENDS
		${NUTTX_DEFCONFIG}
		${NUTTX_KERNEL_DIR}/defconfig
		${CMAKE_CURRENT_BINARY_DIR}/nuttx/Make.defs
		${CMAKE_CURRENT_BINARY_DIR}/../defconfig_inflate_stamp
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	#USES_TERMINAL
)

add_custom_command(
	OUTPUT ${NUTTX_KERNEL_DIR}/include/nuttx/config.h ${NUTTX_KERNEL_DIR}/include/arch/chip
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/nuttx/.config ${NUTTX_KERNEL_DIR}/.config
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/nuttx/Make.defs ${NUTTX_KERNEL_DIR}/Make.defs
	COMMAND make --no-print-directory --silent clean_context
	COMMAND make --no-print-directory --silent pass1dep > ${CMAKE_CURRENT_BINARY_DIR}/nuttx_context.log
	DEPENDS
		${CMAKE_CURRENT_BINARY_DIR}/nuttx/Make.defs
		${NUTTX_KERNEL_DIR}/.config
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	#USES_TERMINAL
)

add_custom_target(nuttx_context DEPENDS ${NUTTX_KERNEL_DIR}/include/nuttx/config.h)

set(builtin_apps_string)
set(builtin_apps_decl_string)

if(CONFIG_NSH_LIBRARY)
	list(SORT module_libraries)
	foreach(module ${module_libraries})
		get_target_property(MAIN ${module} MAIN)
		get_target_property(STACK_MAIN ${module} STACK_MAIN)
		get_target_property(PRIORITY ${module} PRIORITY)

		if(MAIN)
			set(builtin_apps_string "${builtin_apps_string}{ \"${MAIN}\", ${PRIORITY}, ${STACK_MAIN}, ${MAIN}_main },\n")
			set(builtin_apps_decl_string "${builtin_apps_decl_string}int ${MAIN}_main(int argc, char *argv[]);\n")
		endif()
	endforeach()
endif()


configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tarox.bdat.in ${CMAKE_CURRENT_BINARY_DIR}/tarox.bdat)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tarox.pdat.in ${CMAKE_CURRENT_BINARY_DIR}/tarox.pdat)

file(GLOB_RECURSE nuttx_apps_files LIST_DIRECTORIES false
	${APPS_DIR}/*.c
	${APPS_DIR}/*.h
)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/apps/libapps.a
	COMMAND ${CMAKE_COMMAND} -E remove -f ${APPS_DIR}/libapps.a ${APPS_DIR}/builtin/builtin_list.h ${APPS_DIR}/builtin/builtin_proto.h
	COMMAND find ${APPS_DIR} -type f -name \*.o -delete
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/tarox.bdat ${APPS_DIR}/builtin/registry/tarox.bdat
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/tarox.pdat ${APPS_DIR}/builtin/registry/tarox.pdat
	COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${APPS_DIR}/builtin/registry/.updated
	COMMAND make --no-print-directory --silent TOPDIR="${NUTTX_KERNEL_DIR}" > ${CMAKE_CURRENT_BINARY_DIR}/nuttx_apps.log
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${APPS_DIR}/libapps.a ${CMAKE_CURRENT_BINARY_DIR}/apps/libapps.a
	DEPENDS ${nuttx_apps_files} nuttx_context ${NUTTX_KERNEL_DIR}/include/nuttx/config.h
	WORKING_DIRECTORY ${APPS_DIR}
	#USES_TERMINAL
)

add_custom_target(nuttx_apps_build DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/apps/libapps.a)
add_library(nuttx_apps STATIC IMPORTED GLOBAL)
set_property(TARGET nuttx_apps PROPERTY IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/apps/libapps.a)
add_dependencies(nuttx_apps nuttx_apps_build)

function(add_nuttx_dir nuttx_lib nuttx_lib_dir kernel extra target)
	if (${target} STREQUAL all)
		set(nuttx_lib_target all)
	else()
		set(nuttx_lib_target lib${target}.a)
	endif()

	file(GLOB_RECURSE nuttx_lib_files LIST_DIRECTORIES false
		${CMAKE_CURRENT_SOURCE_DIR}/nuttx/${nuttx_lib_dir}/*.c
		${CMAKE_CURRENT_SOURCE_DIR}/nuttx/${nuttx_lib_dir}/*.h
	)

	add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/nuttx/${nuttx_lib_dir}/lib${nuttx_lib}.a
		COMMAND ${CMAKE_COMMAND} -E remove -f ${NUTTX_KERNEL_DIR}/${nuttx_lib_dir}/lib${nuttx_lib}.a
		COMMAND find ${nuttx_lib_dir} -type f -name \*.o -delete
		COMMAND make -C ${nuttx_lib_dir} --no-print-directory --silent ${nuttx_lib_target} TOPDIR="${NUTTX_KERNEL_DIR}" KERNEL=${kernel} EXTRAFLAGS=${extra}
		COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NUTTX_KERNEL_DIR}/${nuttx_lib_dir}/lib${nuttx_lib}.a ${CMAKE_CURRENT_BINARY_DIR}/nuttx/${nuttx_lib_dir}/lib${nuttx_lib}.a
		DEPENDS
			${nuttx_lib_files}
			nuttx_context ${NUTTX_KERNEL_DIR}/include/nuttx/config.h
		WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
		#USES_TERMINAL
	)
	add_custom_target(nuttx_${nuttx_lib}_build DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/nuttx/${nuttx_lib_dir}/lib${nuttx_lib}.a)

	add_library(nuttx_${nuttx_lib} STATIC IMPORTED GLOBAL)
	set_property(TARGET nuttx_${nuttx_lib} PROPERTY IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/nuttx/${nuttx_lib_dir}/lib${nuttx_lib}.a)
	add_dependencies(nuttx_${nuttx_lib} nuttx_${nuttx_lib}_build)
endfunction()

add_nuttx_dir(binfmt binfmt y -D__KERNEL__ all)
add_nuttx_dir(boards boards y -D__KERNEL__ all)
add_nuttx_dir(drivers drivers y -D__KERNEL__ all)
add_nuttx_dir(fs fs y -D__KERNEL__ all)
add_nuttx_dir(sched sched y -D__KERNEL__ all)
add_nuttx_dir(xx libs/libxx n "" all)
add_nuttx_dir(crypto crypto y -D__KERNEL__ all)

add_nuttx_dir(arch arch/${CONFIG_ARCH}/src y -D__KERNEL__ all)
add_nuttx_dir(c libs/libc n "" all)
add_nuttx_dir(mm mm n "" mm)

###############################################################################
# Nuttx oldconfig: Update a configuration using a provided .config as base
add_custom_target(oldconfig_nuttx
	COMMAND make --no-print-directory --silent oldconfig
	DEPENDS ${NUTTX_KERNEL_DIR}/.config
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running Nuttx make oldconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

# Nuttx oldconfig + savedefconfig back to tarox
add_custom_target(oldconfig
	COMMAND make --no-print-directory --silent savedefconfig
	COMMAND ${CMAKE_COMMAND} -E copy ${NUTTX_KERNEL_DIR}/defconfig ${NUTTX_DEFCONFIG}
	COMMAND ${CMAKE_COMMAND} -E remove -f ${NUTTX_KERNEL_DIR}/.config
	DEPENDS oldconfig_nuttx
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running make oldconfig then savedefconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

###############################################################################
# Nuttx olddefconfig: same as oldconfig, but additionally update deps and sets new symbols to their default value
add_custom_target(olddefconfig_nuttx
	COMMAND make --no-print-directory --silent olddefconfig
	DEPENDS ${NUTTX_KERNEL_DIR}/.config
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running Nuttx make olddefconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
	)

# Nuttx olddefconfig + savedefconfig back to tarox
add_custom_target(olddefconfig
	COMMAND make --no-print-directory --silent savedefconfig
	COMMAND ${CMAKE_COMMAND} -E copy ${NUTTX_KERNEL_DIR}/defconfig ${NUTTX_DEFCONFIG}
	COMMAND ${CMAKE_COMMAND} -E remove -f ${NUTTX_KERNEL_DIR}/.config
	DEPENDS olddefconfig_nuttx
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running make olddefconfig then savedefconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

###############################################################################
# Nuttx menuconfig
add_custom_target(menuconfig_nuttx
	COMMAND make --no-print-directory --silent menuconfig
	DEPENDS ${NUTTX_KERNEL_DIR}/.config
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running Nuttx make menuconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

# Nuttx menuconfig + savedefconfig back to tarox
add_custom_target(menuconfig
	COMMAND make --no-print-directory --silent savedefconfig
	COMMAND ${CMAKE_COMMAND} -E copy ${NUTTX_KERNEL_DIR}/defconfig ${NUTTX_DEFCONFIG}
	COMMAND ${CMAKE_COMMAND} -E remove -f ${NUTTX_KERNEL_DIR}/.config
	DEPENDS menuconfig_nuttx
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running make nuttx_menuconfig then savedefconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

###############################################################################
# Nuttx qconfig
add_custom_target(qconfig_nuttx
	COMMAND make --no-print-directory --silent qconfig
	DEPENDS ${NUTTX_KERNEL_DIR}/.config
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running Nuttx make qconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)

# Nuttx qconfig + savedefconfig back to tarox
add_custom_target(qconfig
	COMMAND make --no-print-directory --silent savedefconfig
	COMMAND ${CMAKE_COMMAND} -E copy ${NUTTX_KERNEL_DIR}/defconfig ${NUTTX_DEFCONFIG}
	COMMAND ${CMAKE_COMMAND} -E remove -f ${NUTTX_KERNEL_DIR}/.config
	DEPENDS qconfig_nuttx
	WORKING_DIRECTORY ${NUTTX_KERNEL_DIR}
	COMMENT "Running make qconfig then savedefconfig for ${NUTTX_CONFIG}"
	USES_TERMINAL
)
