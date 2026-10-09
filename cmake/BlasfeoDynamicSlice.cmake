# Turn the static library of one slice of a TARGET=DYNAMIC build into a single
# relocatable object in which only the API symbols are global, renamed with a
# per-slice prefix. Everything else (kernels, helpers) becomes local, so that
# the slices can be linked together without clashes.
#
# Invoked with cmake -P and the variables:
#   ARCHIVE        static library of the slice
#   OUT_DIR        where to write blasfeo_dynamic<INDEX>_slice.o and api.txt (list of API symbols)
#   INDEX          index of the slice in the dynamic build
#   EXCLUDE_REGEX  global symbols matching this are not part of the API
#   CC CFLAGS      compiler (also used as linker driver, so that e.g. -m32 or a
#                  cross compiler select the right object format) and its flags
#   NM OBJCOPY OBJDUMP  binutils (OBJCOPY, OBJDUMP not used for MACHO)
#   FORMAT         object format: ELF, MACHO or COFF
#
# The API symbols are prefixed with blasfeo_dynamic<INDEX>_.

function(run)
	execute_process(COMMAND ${ARGN} RESULT_VARIABLE res OUTPUT_VARIABLE out ERROR_VARIABLE err)
	if(NOT res EQUAL 0)
		message(FATAL_ERROR "${ARGN}\nfailed: ${res}\n${err}")
	endif()
	set(out "${out}" PARENT_SCOPE)
endfunction()

set(PREFIX blasfeo_dynamic${INDEX}_)
separate_arguments(cflags UNIX_COMMAND "${CFLAGS}")

# Mach-O prefixes C symbols with an underscore
if(FORMAT STREQUAL MACHO)
	set(us "_")
	run(${CC} ${cflags} -nostdlib -r -Wl,-all_load ${ARCHIVE} -o ${OUT_DIR}/whole.o)
else()
	set(us "")
	run(${CC} ${cflags} -nostdlib -r -Wl,--whole-archive ${ARCHIVE} -Wl,--no-whole-archive -o ${OUT_DIR}/whole.o)
endif()


# the whole archive is pulled in, so also objects referencing kernels that the
# target never compiles (unnoticed in a regular build unless such an object is
# linked): define them as stubs aborting with a message
run(${NM} -u -P ${OUT_DIR}/whole.o)
string(REPLACE "\n" ";" lines "${out}")
set(stubs "")
set(nn 0)
foreach(line IN LISTS lines)
	if(NOT line MATCHES "^([^ ]+) ")
		continue()
	endif()
	if(NOT CMAKE_MATCH_1 MATCHES "^${us}(.+)$")
		continue()
	endif()
	set(sym ${CMAKE_MATCH_1})
	if(sym MATCHES "${EXCLUDE_REGEX}" OR sym MATCHES "^blasfeo_")
		string(APPEND stubs "void ${sym}(void) { blasfeo_dynamic_abort(\"${sym}\", ${INDEX}); }\n")
		math(EXPR nn "${nn} + 1")
	endif()
endforeach()
file(WRITE ${OUT_DIR}/undefined.c
	"void blasfeo_dynamic_abort(const char *name, int arch);\n${stubs}")
run(${CC} ${cflags} -O2 -fPIC -c ${OUT_DIR}/undefined.c -o ${OUT_DIR}/undefined.o)
run(${CC} ${cflags} -nostdlib -r ${OUT_DIR}/whole.o ${OUT_DIR}/undefined.o -o ${OUT_DIR}/merged.o)
if(nn GREATER 0)
	message(STATUS "BLASFEO dynamic: slice ${INDEX} references ${nn} symbols it does not define, replaced by aborting stubs")
endif()

run(${NM} -g --defined-only -P ${OUT_DIR}/merged.o)

string(REPLACE "\n" ";" lines "${out}")
set(api "")
set(helpers "")
foreach(line IN LISTS lines)
	if(NOT line MATCHES "^([^ ]+) ([A-Za-z]) ")
		continue()
	endif()
	set(name ${CMAKE_MATCH_1})
	set(type ${CMAKE_MATCH_2})
	# compiler helpers (e.g. i386 __x86.get_pc_thunk.bx, MinGW .refptr.*) are
	# not API, but stay global: they are COMDAT, the linker keeps one copy per
	# name for all objects
	# (a second MATCHES in the same if() would clear CMAKE_MATCH_1)
	if(NOT name MATCHES "^${us}([A-Za-z_][A-Za-z0-9_]*)$")
		list(APPEND helpers ${name})
		continue()
	endif()
	set(sym ${CMAKE_MATCH_1})
	if(sym MATCHES "^__")
		list(APPEND helpers ${name})
		continue()
	endif()
	if(sym MATCHES "${EXCLUDE_REGEX}")
		continue()
	endif()
	if(NOT type STREQUAL "T")
		message(FATAL_ERROR "${sym} (nm type ${type}) is not a function and cannot be dispatched")
	endif()
	list(APPEND api ${sym})
endforeach()
list(SORT api)

if(FORMAT STREQUAL MACHO)
	# no objcopy for Mach-O: let ld -r alias the API symbols to their prefixed
	# names and keep only those global; the other globals become private
	# externs, which ld -r turns into local symbols
	set(alias "")
	set(keep "")
	foreach(sym IN LISTS api)
		string(APPEND alias "_${sym} _${PREFIX}${sym}\n")
		string(APPEND keep "_${PREFIX}${sym}\n")
	endforeach()
	foreach(name IN LISTS helpers)
		string(APPEND keep "${name}\n")
	endforeach()
	file(WRITE ${OUT_DIR}/alias.txt "${alias}")
	file(WRITE ${OUT_DIR}/keep.txt "${keep}")
	run(${CC} ${cflags} -nostdlib -r ${OUT_DIR}/merged.o
		-Wl,-alias_list,${OUT_DIR}/alias.txt -Wl,-exported_symbols_list,${OUT_DIR}/keep.txt
		-o ${OUT_DIR}/${PREFIX}slice.o)
	file(REMOVE ${OUT_DIR}/alias.txt)
else()
	string(REPLACE ";" "\n" keep "${api};${helpers}")
	file(WRITE ${OUT_DIR}/keep.txt "${keep}\n")
	set(rename "")
	foreach(sym IN LISTS api)
		string(APPEND rename "${sym} ${PREFIX}${sym}\n")
	endforeach()
	set(rename_sections "")
	if(FORMAT STREQUAL COFF)
		# MinGW .refptr.<sym> pointers are COMDAT: give them per-slice names, or
		# the linker would let all slices share the one of a single slice
		foreach(name IN LISTS helpers)
			if(name MATCHES "^\\.refptr\\.(.+)$")
				string(APPEND rename "${name} .refptr.${PREFIX}${CMAKE_MATCH_1}\n")
			endif()
		endforeach()
		run(${OBJDUMP} -h ${OUT_DIR}/merged.o)
		string(REGEX MATCHALL "\\.rdata\\$\\.refptr\\.[A-Za-z0-9_.]+" sections "${out}")
		foreach(section IN LISTS sections)
			string(REPLACE ".rdata$.refptr." ".rdata$.refptr.${PREFIX}" renamed "${section}")
			list(APPEND rename_sections --rename-section "${section}=${renamed}")
		endforeach()
	endif()
	file(WRITE ${OUT_DIR}/rename.txt "${rename}")

	# localize first, rename second: the order objcopy applies the two within
	# one invocation is not documented
	run(${OBJCOPY} --keep-global-symbols=${OUT_DIR}/keep.txt ${OUT_DIR}/merged.o ${OUT_DIR}/local.o)
	run(${OBJCOPY} --redefine-syms=${OUT_DIR}/rename.txt ${rename_sections} ${OUT_DIR}/local.o ${OUT_DIR}/${PREFIX}slice.o)
	file(REMOVE ${OUT_DIR}/local.o ${OUT_DIR}/rename.txt)
endif()
file(REMOVE ${OUT_DIR}/whole.o ${OUT_DIR}/undefined.o ${OUT_DIR}/merged.o)

# written last: it is the output the build tracks
string(REPLACE ";" "\n" api "${api}")
file(WRITE ${OUT_DIR}/api.txt.tmp "${api}\n")
file(REMOVE ${OUT_DIR}/keep.txt)
file(RENAME ${OUT_DIR}/api.txt.tmp ${OUT_DIR}/api.txt)
