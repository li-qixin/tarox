if(tarox_add_module_included)
	return()
endif(tarox_add_module_included)
set(tarox_add_module_included true)

include(tarox_list_make_absolute)

function(tarox_add_module)
  tarox_parse_function_args(
    NAME tarox_add_module
    ONE_VALUE MODULE MAIN STACK_MAIN STACK_MAX PRIORITY
    MULTI_VALUE COMPILE_FLAGS LINK_FLAGS SRCS INCLUDES DEPENDS MODULE_CONFIG
    OPTIONS EXTERNAL DYNAMIC UNITY_BUILD
    REQUIRED MODULE MAIN
    ARGN ${ARGN}
  )
  if(UNITY_BUILD AND (${TAROX_PLATFORM} STREQUAL "nuttx"))
    add_library(${MODULE}_original STATIC EXCLUDE_FROM_ALL ${SRCS})
    if(DEPENDS)
      add_dependencies(${MODULE}_original ${DEPENDS})
    endif()

    if(INCLUDES)
      target_include_directories(${MODULE}_original PRIVATE ${INCLUDES})
    endif()

    target_compile_definitions(${MODULE}_original PRIVATE TAROX_MAIN=${MAIN}_app_main)
    target_compile_definitions(${MODULE}_original PRIVATE MODULE_NAME=${MAIN}_original)

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${MODULE}_unity.cpp
                       COMMAND cat ${SRCS} > ${CMAKE_CURRENT_BINARY_DIR}/${MODULE}_unity.cpp
                       DEPENDS ${SRCS}
                       COMMENT "${MODULE} merging source"
                       WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

    set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/${MODULE}_unity.cpp PROPERTIES GENERATED true)
    add_library(${MODULE} STATIC EXCLUDE_FROM_ALL ${CMAKE_CURRENT_BINARY_DIR}/${MODULE}_unity.cpp)
    target_include_directories(${MODULE} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    add_dependencies(${MODULE} ${MODULE}_original)

    if(COMPILE_FLAGS)
      target_compile_options(${MODULE}_original PRIVATE ${COMPILE_FLAGS})
    endif()

    if(DEPENDS)
      foreach(dep ${DEPENDS})
        get_target_property(dep_type ${dep} TYPE)
        if((${dep_type} STREQUAL "STATIC_LIBRARY") OR (${dep_type} STREQUAL "INTERFACE_LIBRARY"))
          target_link_libraries(${MODULE}_original PRIVATE ${dep})
        else()
          add_dependencies(${MODULE}_original ${dep})
        endif()
      endforeach()
    endif()

  elseif(DYNAMIC AND MAIN AND (${TAROX_PLATFORM} STREQUAL "posix"))

    message(FATAL_ERROR "current version doesn't support posix!")

  else()

    add_library(${MODULE} STATIC EXCLUDE_FROM_ALL ${SRCS})

  endif()

  get_target_property(MODULE_SOURCE_DIR ${MODULE} SOURCE_DIR)
  file(RELATIVE_PATH module ${PROJECT_SOURCE_DIR}/src ${MODULE_SOURCE_DIR})

  list(FIND config_kernel_list ${module} _index)
  if(${_index} GREATER -1)
    set(KERNEL TRUE)
  endif()

  if(NOT DYNAMIC)
    target_link_libraries(${MODULE} PRIVATE prebuild_targets tarox_platform systemlib perf)
    if(${TAROX_PLATFORM} STREQUAL "nuttx" AND NOT CONFIG_BUILD_FLAT AND KERNEL)
      target_link_libraries(${MODULE} PRIVATE
                            kernel_events_interface kernel_parameters_interface
                            tarox_kernel_layer)
      set_property(GLOBAL APPEND PROPERTY TAROX_KERNEL_MODULE_LIBRARIES ${MODULE}) 
    else()
      target_link_libraries(${MODULE} PRIVATE
                            events_interface parameters_interface tarox_layer uORB)
      set_property(GLOBAL APPEND PROPERTY TAROX_MODULE_LIBRARIES ${MODULE}) 
    endif()
  endif()
  set_property(GLOBAL APPEND PROPERTY TAROX_MODULE_PATHS ${CMAKE_CURRENT_SOURCE_DIR})
  tarox_list_make_absolute(ABS_SRCS ${CMAKE_CURRENT_SOURCE_DIR} ${SRCS})
  set_property(GLOBAL APPEND PROPERTY TAROX_SRC_FILES ${ABS_SRCS})
  
  set(MAIN_DEFAULT MAIN-NOTFOUND)
	set(STACK_MAIN_DEFAULT 2048)
	set(PRIORITY_DEFAULT SCHED_PRIORITY_DEFAULT)

	foreach(property MAIN STACK_MAIN PRIORITY)
		if(NOT ${property})
			set(${property} ${${property}_DEFAULT})
		endif()
		set_target_properties(${MODULE} PROPERTIES ${property} ${${property}})
	endforeach()

	# default stack max to stack main
	if(NOT STACK_MAX)
		set(STACK_MAX ${STACK_MAIN})
	endif()
	set_target_properties(${MODULE} PROPERTIES STACK_MAX ${STACK_MAX})

	if(${TAROX_PLATFORM} STREQUAL "nuttx")
		# double the allocated stacks for 64 bit nuttx targets
		set(STACK_MAIN "${STACK_MAIN} * (__SIZEOF_POINTER__ >> 2)")

		target_compile_options(${MODULE} PRIVATE -Wframe-larger-than=${STACK_MAX})
	endif()

	# MAIN
	if(MAIN)
		target_compile_definitions(${MODULE} PRIVATE TAROX_MAIN=${MAIN}_app_main)
		target_compile_definitions(${MODULE} PRIVATE MODULE_NAME="${MAIN}")
	else()
		message(FATAL_ERROR "MAIN required")
	endif()

	if(COMPILE_FLAGS)
		target_compile_options(${MODULE} PRIVATE ${COMPILE_FLAGS})
	endif()

	if (KERNEL)
		target_compile_options(${MODULE} PRIVATE -D__KERNEL__)
	endif()

	if(INCLUDES)
		target_include_directories(${MODULE} PRIVATE ${INCLUDES})
	endif()

	if(DEPENDS)
		foreach(dep ${DEPENDS})
			get_target_property(dep_type ${dep} TYPE)
			if((${dep_type} STREQUAL "STATIC_LIBRARY") OR (${dep_type} STREQUAL "INTERFACE_LIBRARY"))
				target_link_libraries(${MODULE} PRIVATE ${dep})
			else()
				add_dependencies(${MODULE} ${dep})
			endif()
		endforeach()
	endif()

	foreach (prop LINK_FLAGS STACK_MAIN MAIN PRIORITY)
		if (${prop})
			set_target_properties(${MODULE} PROPERTIES ${prop} ${${prop}})
		endif()
	endforeach()

	if(MODULE_CONFIG)
		foreach(module_config ${MODULE_CONFIG})
			set_property(GLOBAL APPEND PROPERTY TAROX_MODULE_CONFIG_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${module_config})
		endforeach()
	endif()
  
endfunction()
