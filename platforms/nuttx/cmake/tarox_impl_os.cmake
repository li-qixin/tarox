#=============================================================================
#
#	Defined functions in this file
#
#	Required OS Interface Functions
#
#		* tarox_os_add_flags
# 		* tarox_os_determine_build_chip
#		* tarox_os_prebuild_targets
#

#=============================================================================
#
#	tarox_os_add_flags
#
#	Set the nuttx build flags.
#
function(tarox_os_add_flags)

	include_directories(BEFORE SYSTEM
		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/include
	)

	if(CONFIG_LIB_TFLM) # Since TFLM uses the standard C++ library, we need to exclude the NuttX C++ include path
		add_custom_target(copy_header ALL
		COMMAND ${CMAKE_COMMAND} -E copy # One of the header files from nuttx is needed
		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/include/cxx/cstdlib
		${TAROX_SOURCE_DIR}/src/lib/tensorflow_lite_micro/include/cstdlib
		)

		include_directories(BEFORE SYSTEM
			${TAROX_SOURCE_DIR}/src/lib/tensorflow_lite_micro/include
		)
	else()
		include_directories(BEFORE SYSTEM
			${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/include/cxx
			${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/include/cxx	# custom new
		)

	endif()

	include_directories(
		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/arch/${CONFIG_ARCH}/src/${CONFIG_ARCH_FAMILY}
		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/arch/${CONFIG_ARCH}/src/chip
		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/nuttx/arch/${CONFIG_ARCH}/src/common

		${TAROX_SOURCE_DIR}/platforms/nuttx/NuttX/apps/include
	)


	set(cxx_flags)
	list(APPEND cxx_flags
		-fno-exceptions
		-fno-rtti
		-fno-sized-deallocation
		-fno-threadsafe-statics
	)

	if(NOT CONFIG_LIB_TFLM)
		list(APPEND cxx_flags -nostdinc++) # prevent using the toolchain's std c++ library if building for anything else than TFLM
	endif()

	foreach(flag ${cxx_flags})
		add_compile_options($<$<COMPILE_LANGUAGE:CXX>:${flag}>)
	endforeach()

	add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wbad-function-cast>)

	add_definitions(
		-D__TAROX_NUTTX

		-D_SYS_CDEFS_H_ # skip toolchain's <sys/cdefs.h>
		-D_SYS_REENT_H_	# skip toolchain's <sys/reent.h>
		)

	if("${CONFIG_ARMV7M_STACKCHECK}" STREQUAL "y")
		message(STATUS "NuttX Stack Checking (CONFIG_ARMV7M_STACKCHECK) enabled")
		add_compile_options(
			-ffixed-r10
			-finstrument-functions
			# instrumenting TAROX Matrix and Param methods is too burdensome
			-finstrument-functions-exclude-file-list=matrix/Matrix.hpp,tarox_platform_common/param.h,modules__ekf2_unity.cpp
		)
	endif()

	if("${CONFIG_BOARD_FORCE_ALIGNMENT}" STREQUAL "y")
		message(STATUS "Board forcing alignment")
		add_compile_options(
			-mno-unaligned-access
		)
	endif()

endfunction()

#=============================================================================
#
#	tarox_os_determine_build_chip
#
#	Sets TAROX_CHIP and TAROX_CHIP_MANUFACTURER.
#
#	Usage:
#		tarox_os_determine_build_chip()
#
function(tarox_os_determine_build_chip)

	# determine chip and chip manufacturer based on NuttX config
	if (CONFIG_STM32_STM32F10XX)
		set(CHIP_MANUFACTURER "stm")
		set(CHIP "stm32f1")
	elseif(CONFIG_STM32_STM32F30XX)
		set(CHIP_MANUFACTURER "stm")
		set(CHIP "stm32f3")
	elseif(CONFIG_STM32_STM32F4XXX)
		set(CHIP_MANUFACTURER "stm")
		set(CHIP "stm32f4")
	elseif(CONFIG_ARCH_CHIP_STM32F7)
		set(CHIP_MANUFACTURER "stm")
		set(CHIP "stm32f7")
	elseif(CONFIG_ARCH_CHIP_STM32H7)
		set(CHIP_MANUFACTURER "stm")
		set(CHIP "stm32h7")
	elseif(CONFIG_ARCH_CHIP_MK66FN2M0VMD18)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "k66")
	elseif(CONFIG_ARCH_CHIP_MIMXRT1062DVL6A)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "rt106x")
	elseif(CONFIG_ARCH_CHIP_MIMXRT1064DVL6A)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "rt106x")
	elseif(CONFIG_ARCH_CHIP_MIMXRT1176DVMAA)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "rt117x")
	elseif(CONFIG_ARCH_CHIP_S32K146)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "s32k14x")
	elseif(CONFIG_ARCH_CHIP_S32K344)
		set(CHIP_MANUFACTURER "nxp")
		set(CHIP "s32k34x")
	elseif(CONFIG_ARCH_CHIP_RP2040)
		set(CHIP_MANUFACTURER "rpi")
		set(CHIP "rp2040")
	elseif(CONFIG_ARCH_CHIP_ESP32)
		set(CHIP_MANUFACTURER "espressif")
		set(CHIP "esp32")
	else()
		message(FATAL_ERROR "Could not determine chip architecture from NuttX config. You may have to add it.")
	endif()

	set(TAROX_CHIP ${CHIP} CACHE STRING "TAROX Chip" FORCE)
	set(TAROX_CHIP_MANUFACTURER ${CHIP_MANUFACTURER} CACHE STRING "TAROX Chip Manufacturer" FORCE)
endfunction()

#=============================================================================
#
#	tarox_os_prebuild_targets
#
#	This function generates os dependent targets
#
#	Usage:
#		tarox_os_prebuild_targets(
#			OUT <out-list_of_targets>
#			BOARD <in-string>
#			)
#
#	Input:
#		BOARD		: board
#
#	Output:
#		OUT	: the target list
#
#	Example:
#		tarox_os_prebuild_targets(OUT target_list BOARD tarox_fmu-v2)
#
function(tarox_os_prebuild_targets)
	tarox_parse_function_args(
			NAME tarox_os_prebuild_targets
			ONE_VALUE OUT BOARD
			REQUIRED OUT
			ARGN ${ARGN})

	if(EXISTS ${TAROX_BOARD_DIR}/nuttx-config/${TAROX_BOARD_LABEL})
		set(NUTTX_CONFIG "${TAROX_BOARD_LABEL}" CACHE INTERNAL "NuttX config" FORCE)
	else()
		set(NUTTX_CONFIG "nsh" CACHE INTERNAL "NuttX config" FORCE)
	endif()

	add_library(prebuild_targets INTERFACE)
	target_link_libraries(prebuild_targets INTERFACE nuttx_xx m gcc)
	add_dependencies(prebuild_targets DEPENDS nuttx_context uorb_headers)

endfunction()