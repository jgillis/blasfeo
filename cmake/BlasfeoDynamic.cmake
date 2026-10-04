# TARGET=DYNAMIC: one library bundling several targets, selected at load time.
#
# The targets come from one architecture group, the one compiled for (also when
# cross compiling): x86_64, x86, ARMv8A or ARMv7A. Each target of
# BLASFEO_DYNAMIC_TARGETS is built as a separate slice (this very source tree as
# an ExternalProject, BLASFEO_DYNAMIC_SUBBUILD=ON). Each slice is merged into one
# object whose API symbols get a per-slice prefix and whose other symbols become
# local (cmake/BlasfeoDynamicSlice.cmake). The public API names are stubs jumping
# through a table (cmake/BlasfeoDynamicGen.cmake), filled at load time with the
# best target for the CPU (auxiliary/blasfeo_dynamic_dispatch.c).
#
# The panel sizes D_PS and S_PS may differ between targets: in the installed
# headers they resolve to the globals blasfeo_d_ps and blasfeo_s_ps, set at
# load time, so BLASFEO_DMATEL & co follow the selected target.

include(ExternalProject)

# object format, which decides how the slices are made and the API exported
if(CMAKE_C_COMPILER_ID MATCHES MSVC OR CMAKE_C_SIMULATE_ID MATCHES MSVC)
	message(FATAL_ERROR "TARGET=DYNAMIC needs a GNU-compatible compiler (MSVC only supports TARGET=GENERIC)")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	set(BLASFEO_DYNAMIC_FORMAT MACHO)
	list(LENGTH CMAKE_OSX_ARCHITECTURES dynamic_osx_narch)
	if(dynamic_osx_narch GREATER 1)
		message(FATAL_ERROR "TARGET=DYNAMIC builds a single architecture, CMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}")
	endif()
elseif(CMAKE_SYSTEM_NAME MATCHES "Windows|CYGWIN|MSYS")
	set(BLASFEO_DYNAMIC_FORMAT COFF)
else()
	set(BLASFEO_DYNAMIC_FORMAT ELF)
endif()

# architecture group compiled for and its targets, most preferred first: by
# default all of them, GENERIC last as the fallback any CPU of the group runs
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|i[3-6]86|x86)$" AND CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(BLASFEO_DYNAMIC_ARCH X64)
	set(dynamic_group_targets X64_INTEL_SKYLAKE_X X64_INTEL_HASWELL X64_AMD_BULLDOZER X64_INTEL_SANDY_BRIDGE X64_INTEL_CORE GENERIC)
	if(BLASFEO_DYNAMIC_FORMAT STREQUAL COFF)
		# X64_INTEL_SKYLAKE_X crashes on Windows (example_d_riccati_recursion)
		list(REMOVE_ITEM dynamic_group_targets X64_INTEL_SKYLAKE_X)
	endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|i[3-6]86|x86)$")
	# X86_AMD_JAGUAR and X86_AMD_BARCELONA are only supported by the Makefile
	set(BLASFEO_DYNAMIC_ARCH X86)
	set(dynamic_group_targets GENERIC)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$" AND BLASFEO_DYNAMIC_FORMAT STREQUAL MACHO)
	# the Cortex kernels only support the Linux ABI (x18 is reserved on macOS)
	set(BLASFEO_DYNAMIC_ARCH ARMV8A)
	set(dynamic_group_targets ARMV8A_APPLE_M1 GENERIC)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$")
	set(BLASFEO_DYNAMIC_ARCH ARMV8A)
	set(dynamic_group_targets ARMV8A_APPLE_M1 ARMV8A_ARM_CORTEX_A76 ARMV8A_ARM_CORTEX_A73 ARMV8A_ARM_CORTEX_A57 ARMV8A_ARM_CORTEX_A55 ARMV8A_ARM_CORTEX_A53 GENERIC)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^arm")
	set(BLASFEO_DYNAMIC_ARCH ARMV7A)
	set(dynamic_group_targets ARMV7A_ARM_CORTEX_A15 ARMV7A_ARM_CORTEX_A9 ARMV7A_ARM_CORTEX_A7 GENERIC)
else()
	message(FATAL_ERROR "TARGET=DYNAMIC is not supported for processor ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(dynamic_targets ${BLASFEO_DYNAMIC_TARGETS})
if(NOT dynamic_targets)
	set(dynamic_targets ${dynamic_group_targets})
endif()
foreach(t IN LISTS dynamic_targets)
	list(FIND dynamic_group_targets ${t} isvalid)
	if(isvalid EQUAL -1)
		message(FATAL_ERROR "Target ${t} in BLASFEO_DYNAMIC_TARGETS is not supported for architecture ${BLASFEO_DYNAMIC_ARCH}, choose among ${dynamic_group_targets}")
	endif()
endforeach()

set(BLASFEO_DYNAMIC_EXCLUDE_REGEX "^kernel_" CACHE STRING "Global symbols of the slices not exported by TARGET=DYNAMIC")

set(dynamic_tools NM)
if(NOT BLASFEO_DYNAMIC_FORMAT STREQUAL MACHO)
	list(APPEND dynamic_tools OBJCOPY OBJDUMP)
endif()
foreach(tool IN LISTS dynamic_tools)
	if(NOT CMAKE_${tool})
		message(FATAL_ERROR "TARGET=DYNAMIC needs CMAKE_${tool}")
	endif()
endforeach()

string(REPLACE ";" ", " BLASFEO_DYNAMIC_TARGETS_STR "${dynamic_targets}")
message(STATUS "Compiling for target: ${TARGET} on ${BLASFEO_DYNAMIC_ARCH} ${BLASFEO_DYNAMIC_FORMAT} (${BLASFEO_DYNAMIC_TARGETS_STR})")

if(BUILD_SHARED_LIBS)
	set(BLASFEO_DYNAMIC_DLL ON)
endif()
configure_file(${PROJECT_SOURCE_DIR}/blasfeo_target_dynamic.h.in
	${CMAKE_CURRENT_SOURCE_DIR}/include/blasfeo_target.h @ONLY)

set(dynamic_dir ${CMAKE_CURRENT_BINARY_DIR}/dynamic)
set(dynamic_gen_dir ${dynamic_dir}/gen)
file(MAKE_DIRECTORY ${dynamic_gen_dir})

# options forwarded to the slices
set(dynamic_cmake_args
	-DBLASFEO_DYNAMIC_SUBBUILD=ON
	-DBUILD_SHARED_LIBS=OFF
	-DBLASFEO_EXAMPLES=OFF
	-DBLASFEO_TESTING=OFF
	-DBLASFEO_BENCHMARKS=OFF
	-DBLASFEO_CROSSCOMPILING=ON
	-DCMAKE_VERBOSE_MAKEFILE=OFF
	-DLA=${LA}
	-DMF=${MF}
	-DEXTERNAL_BLAS=${EXTERNAL_BLAS}
	-DBLAS_API=${BLAS_API}
	-DFORTRAN_BLAS_API=${FORTRAN_BLAS_API}
	-DK_MAX_STACK=${K_MAX_STACK}
	-DUSE_C99_MATH=${USE_C99_MATH}
	-DEXT_DEP=${EXT_DEP}
	-DEXT_DEP_MALLOC=${EXT_DEP_MALLOC}
	-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
	-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
	-DCMAKE_ASM_COMPILER=${CMAKE_ASM_COMPILER}
	-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
	-DCMAKE_ASM_FLAGS=${CMAKE_ASM_FLAGS}
	)
foreach(var CMAKE_TOOLCHAIN_FILE CMAKE_SYSTEM_NAME CMAKE_SYSTEM_PROCESSOR CMAKE_SYSROOT CMAKE_C_COMPILER_TARGET CMAKE_ASM_COMPILER_TARGET CMAKE_FIND_ROOT_PATH)
	if(CMAKE_CROSSCOMPILING AND DEFINED ${var})
		list(APPEND dynamic_cmake_args -D${var}=${${var}})
	endif()
endforeach()
foreach(var CMAKE_OSX_ARCHITECTURES CMAKE_OSX_DEPLOYMENT_TARGET CMAKE_OSX_SYSROOT)
	if(${var})
		list(APPEND dynamic_cmake_args -D${var}=${${var}})
	endif()
endforeach()

separate_arguments(dynamic_c_flags UNIX_COMMAND "${CMAKE_C_FLAGS}")

set(dynamic_slice_objs "")
set(dynamic_api_files "")
set(dynamic_d_ps "")
set(dynamic_s_ps "")
set(ii 0)
foreach(t IN LISTS dynamic_targets)
	set(slice_dir ${dynamic_dir}/${t})
	file(MAKE_DIRECTORY ${slice_dir})

	# panel sizes, straight from blasfeo_block_size.h
	file(WRITE ${slice_dir}/ps.c "#include \"blasfeo_block_size.h\"\nBLASFEO_PS D_PS S_PS\n")
	execute_process(
		COMMAND ${CMAKE_C_COMPILER} ${dynamic_c_flags} -E -P -DTARGET_${t} -I${PROJECT_SOURCE_DIR}/include ${slice_dir}/ps.c
		OUTPUT_VARIABLE ps_out RESULT_VARIABLE ps_res)
	if(NOT ps_res EQUAL 0 OR NOT ps_out MATCHES "BLASFEO_PS ([0-9]+) ([0-9]+)")
		message(FATAL_ERROR "Cannot get the panel sizes of target ${t}")
	endif()
	list(APPEND dynamic_d_ps ${CMAKE_MATCH_1})
	list(APPEND dynamic_s_ps ${CMAKE_MATCH_2})

	ExternalProject_Add(blasfeo_dynamic_${t}
		SOURCE_DIR ${PROJECT_SOURCE_DIR}
		BINARY_DIR ${slice_dir}/build
		CMAKE_ARGS -DTARGET=${t} ${dynamic_cmake_args}
		INSTALL_COMMAND ""
		BUILD_ALWAYS ON
		BUILD_BYPRODUCTS ${slice_dir}/build/libblasfeo.a
		)

	add_custom_command(
		OUTPUT ${slice_dir}/blasfeo_dynamic${ii}_slice.o ${slice_dir}/api.txt
		COMMAND ${CMAKE_COMMAND}
			-DARCHIVE=${slice_dir}/build/libblasfeo.a
			-DOUT_DIR=${slice_dir}
			-DINDEX=${ii}
			-DEXCLUDE_REGEX=${BLASFEO_DYNAMIC_EXCLUDE_REGEX}
			-DCC=${CMAKE_C_COMPILER}
			"-DCFLAGS=${CMAKE_C_FLAGS}"
			-DNM=${CMAKE_NM}
			-DOBJCOPY=${CMAKE_OBJCOPY}
			-DOBJDUMP=${CMAKE_OBJDUMP}
			-DFORMAT=${BLASFEO_DYNAMIC_FORMAT}
			-P ${PROJECT_SOURCE_DIR}/cmake/BlasfeoDynamicSlice.cmake
		DEPENDS blasfeo_dynamic_${t} ${slice_dir}/build/libblasfeo.a ${PROJECT_SOURCE_DIR}/cmake/BlasfeoDynamicSlice.cmake
		COMMENT "BLASFEO dynamic: preparing slice ${t}"
		VERBATIM
		)
	list(APPEND dynamic_slice_objs ${slice_dir}/blasfeo_dynamic${ii}_slice.o)
	list(APPEND dynamic_api_files ${slice_dir}/api.txt)

	math(EXPR ii "${ii} + 1")
endforeach()

# lists are passed '|'-separated to survive the command line
string(REPLACE ";" "|" dynamic_targets_arg "${dynamic_targets}")
string(REPLACE ";" "|" dynamic_api_files_arg "${dynamic_api_files}")
string(REPLACE ";" "|" dynamic_d_ps_arg "${dynamic_d_ps}")
string(REPLACE ";" "|" dynamic_s_ps_arg "${dynamic_s_ps}")
add_custom_command(
	OUTPUT ${dynamic_gen_dir}/blasfeo_dynamic_stubs.S ${dynamic_gen_dir}/blasfeo_dynamic_table.inc
		${dynamic_gen_dir}/blasfeo_dynamic.map ${dynamic_gen_dir}/blasfeo_dynamic.exp ${dynamic_gen_dir}/blasfeo_dynamic.def
	COMMAND ${CMAKE_COMMAND}
		-DARCH=${BLASFEO_DYNAMIC_ARCH}
		-DFORMAT=${BLASFEO_DYNAMIC_FORMAT}
		"-DTARGETS=${dynamic_targets_arg}"
		"-DAPI_FILES=${dynamic_api_files_arg}"
		"-DD_PS=${dynamic_d_ps_arg}"
		"-DS_PS=${dynamic_s_ps_arg}"
		-DOUT_DIR=${dynamic_gen_dir}
		-P ${PROJECT_SOURCE_DIR}/cmake/BlasfeoDynamicGen.cmake
	DEPENDS ${dynamic_api_files} ${PROJECT_SOURCE_DIR}/cmake/BlasfeoDynamicGen.cmake
	COMMENT "BLASFEO dynamic: generating dispatch layer"
	VERBATIM
	)

set_source_files_properties(${dynamic_slice_objs} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)

add_library(blasfeo
	${PROJECT_SOURCE_DIR}/auxiliary/blasfeo_dynamic_dispatch.c
	${dynamic_gen_dir}/blasfeo_dynamic_stubs.S
	${dynamic_slice_objs}
	)
set_source_files_properties(${PROJECT_SOURCE_DIR}/auxiliary/blasfeo_dynamic_dispatch.c PROPERTIES
	OBJECT_DEPENDS ${dynamic_gen_dir}/blasfeo_dynamic_table.inc)
target_include_directories(blasfeo PRIVATE ${dynamic_gen_dir})
set_target_properties(blasfeo PROPERTIES POSITION_INDEPENDENT_CODE ON)
if(CMAKE_C_COMPILER_ID MATCHES "GNU" OR CMAKE_C_COMPILER_ID MATCHES "Clang")
	target_compile_options(blasfeo PRIVATE $<$<COMPILE_LANGUAGE:C>:-O2>)
endif()
# shared library: export only the API, not the prefixed implementations of the slices
if(BUILD_SHARED_LIBS AND BLASFEO_DYNAMIC_FORMAT STREQUAL ELF)
	target_link_libraries(blasfeo PRIVATE "-Wl,--version-script=${dynamic_gen_dir}/blasfeo_dynamic.map")
	set_target_properties(blasfeo PROPERTIES LINK_DEPENDS ${dynamic_gen_dir}/blasfeo_dynamic.map)
elseif(BUILD_SHARED_LIBS AND BLASFEO_DYNAMIC_FORMAT STREQUAL MACHO)
	target_link_libraries(blasfeo PRIVATE "-Wl,-exported_symbols_list,${dynamic_gen_dir}/blasfeo_dynamic.exp")
	set_target_properties(blasfeo PROPERTIES LINK_DEPENDS ${dynamic_gen_dir}/blasfeo_dynamic.exp)
elseif(BUILD_SHARED_LIBS AND BLASFEO_DYNAMIC_FORMAT STREQUAL COFF)
	target_sources(blasfeo PRIVATE ${dynamic_gen_dir}/blasfeo_dynamic.def)
endif()

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/version" BLASFEO_VERSION)
string(STRIP "${BLASFEO_VERSION}" BLASFEO_VERSION)
string(REPLACE "." ";" VERSION_LIST ${BLASFEO_VERSION})
list(GET VERSION_LIST 0 BLASFEO_SOVERSION)
# not ABI compatible with blasfeo: D_PS and S_PS are runtime variables
set_target_properties(blasfeo PROPERTIES
	OUTPUT_NAME blasfeo-dynamic
	VERSION ${BLASFEO_VERSION}
	SOVERSION ${BLASFEO_SOVERSION}
)

target_include_directories(blasfeo
	PUBLIC
		$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
		$<INSTALL_INTERFACE:${BLASFEO_HEADERS_INSTALLATION_DIRECTORY}>)

install(TARGETS blasfeo EXPORT blasfeoConfig
	LIBRARY DESTINATION lib
	ARCHIVE DESTINATION lib
	RUNTIME DESTINATION bin)

install(EXPORT blasfeoConfig DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmake/blasfeo FILE blasfeoConfig.cmake)

file(GLOB_RECURSE BLASFEO_HEADERS "include/*.h")
install(FILES ${BLASFEO_HEADERS} DESTINATION ${BLASFEO_HEADERS_INSTALLATION_DIRECTORY})

if(BLASFEO_EXAMPLES MATCHES ON AND EXTERNAL_BLAS MATCHES 0)
	set(EXTERNAL_BLAS_LIBRARIES )
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DEXTERNAL_BLAS_NONE")
	add_subdirectory(examples)
endif()
