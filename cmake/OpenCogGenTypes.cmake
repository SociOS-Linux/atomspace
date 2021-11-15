#
# OpenCogGenTypes.cmake
#
# Definitions for automatically building the atom_types files, given
# a master file "atom_types.script" that defines all of the type
# relationships.
#
# Macro example call:
# XXX TBD

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# Parse one line of type definitions, and set up various
# flags and values that later stages can use.
#

MACRO(OPENCOG_TYPEINFO_REGEX)
	# This regular expression is more complex than required
	# due to cmake's regex engine bugs
	STRING(REGEX MATCH "^[ 	]*([A-Z0-9_]+)?([ 	]*<-[ 	]*([A-Z0-9_, 	]+))?[ 	]*(\"[A-Za-z]*\")?[ 	]*(//.*)?[ 	]*$" MATCHED "${LINE}")
ENDMACRO(OPENCOG_TYPEINFO_REGEX)

MACRO(OPENCOG_TYPEINFO_SETUP)
	SET(TYPE ${CMAKE_MATCH_1})
	SET(PARENT_TYPES ${CMAKE_MATCH_3})
	SET(TYPE_NAME "")
	IF (CMAKE_MATCH_4)
		MESSAGE(STATUS "Custom atom type name specified: ${CMAKE_MATCH_4}")
		STRING(REGEX MATCHALL "." CHARS ${CMAKE_MATCH_4})
		LIST(LENGTH CHARS LIST_LENGTH)
		MATH(EXPR LAST_INDEX "${LIST_LENGTH} - 1")
		FOREACH(I RANGE ${LAST_INDEX})
			LIST(GET CHARS ${I} C)
			IF (NOT ${C} STREQUAL "\"")
				SET(TYPE_NAME "${TYPE_NAME}${C}")
			ENDIF (NOT ${C} STREQUAL "\"")
		ENDFOREACH(I RANGE ${LIST_LENGTH})
	ENDIF (CMAKE_MATCH_4)

	IF (TYPE_NAME STREQUAL "")
		# Set type name using camel casing
		STRING(REGEX MATCHALL "." CHARS ${TYPE})
		LIST(LENGTH CHARS LIST_LENGTH)
		MATH(EXPR LAST_INDEX "${LIST_LENGTH} - 1")
		FOREACH(I RANGE ${LAST_INDEX})
			LIST(GET CHARS ${I} C)
			IF (NOT ${C} STREQUAL "_")
				MATH(EXPR IP "${I} - 1")
				LIST(GET CHARS ${IP} CP)
				IF (${I} EQUAL 0)
					SET(TYPE_NAME "${TYPE_NAME}${C}")
				ELSE (${I} EQUAL 0)
					IF (${CP} STREQUAL "_")
						SET(TYPE_NAME "${TYPE_NAME}${C}")
					ELSE (${CP} STREQUAL "_")
						STRING(TOLOWER "${C}" CL)
						SET(TYPE_NAME "${TYPE_NAME}${CL}")
					ENDIF (${CP} STREQUAL "_")
				ENDIF (${I} EQUAL 0)
			ENDIF (NOT ${C} STREQUAL "_")
		ENDFOREACH(I RANGE ${LIST_LENGTH})
	ENDIF (TYPE_NAME STREQUAL "")

	STRING(REGEX REPLACE "([a-zA-Z]*)(Link|Node)$" "\\1" SHORT_NAME ${TYPE_NAME})
	MESSAGE(STATUS "Atom type name: ${TYPE_NAME} ${SHORT_NAME}")

	# -----------------------------------------------------------
	# Try to guess if the thing is a node or link based on its name
	STRING(REGEX MATCH "VALUE$" ISVALUE ${TYPE})
	STRING(REGEX MATCH "STREAM$" ISSTREAM ${TYPE})
	STRING(REGEX MATCH "ATOMSPACE$" ISATOMSPACE ${TYPE})
	STRING(REGEX MATCH "NODE$" ISNODE ${TYPE})
	STRING(REGEX MATCH "LINK$" ISLINK ${TYPE})
	STRING(REGEX MATCH "AST$" ISAST ${TYPE})

	# If not explicitly named, assume its a link. This is kind of
	# hacky, but is needed for e.g. "VariableList" ...
	IF (NOT ISNODE STREQUAL "NODE"
		AND NOT ISVALUE STREQUAL "VALUE"
		AND NOT ISSTREAM STREQUAL "STREAM"
		AND NOT ISATOMSPACE STREQUAL "ATOMSPACE"
		AND NOT ISAST STREQUAL "AST")
		SET(ISLINK "LINK")
	ENDIF (NOT ISNODE STREQUAL "NODE"
		AND NOT ISVALUE STREQUAL "VALUE"
		AND NOT ISSTREAM STREQUAL "STREAM"
		AND NOT ISATOMSPACE STREQUAL "ATOMSPACE"
		AND NOT ISAST STREQUAL "AST")

	IF (${TYPE} STREQUAL "VALUATION")
		SET(ISLINK "")
	ENDIF (${TYPE} STREQUAL "VALUATION")
ENDMACRO(OPENCOG_TYPEINFO_SETUP)

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# Write out the initial boilerplate for the four C++ files.
# Not for external use.

MACRO(OPENCOG_CPP_SETUP HEADER_FILE DEFINITIONS_FILE INHERITANCE_FILE)

	IF (NOT HEADER_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CPP_ATOMTYPES missing HEADER_FILE")
	ENDIF (NOT HEADER_FILE)

	IF (NOT DEFINITIONS_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CPP_ATOMTYPES missing DEFINITIONS_FILE")
	ENDIF (NOT DEFINITIONS_FILE)

	IF (NOT INHERITANCE_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CPP_ATOMTYPES missing INHERITANCE_FILE")
	ENDIF (NOT INHERITANCE_FILE)

	SET(TMPHDR_FILE ${CMAKE_BINARY_DIR}/tmp_types.h)
	SET(CNAMES_FILE ${CMAKE_BINARY_DIR}/atom_names.h)

	MESSAGE(STATUS "Generating C++ Atom Type defintions from ${SCRIPT_FILE}.")

	SET(CLASSSERVER_REFERENCE "opencog::nameserver().")
	SET(CLASSSERVER_INSTANCE "opencog::nameserver()")

	FILE(WRITE "${TMPHDR_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n"
		"#include <opencog/atoms/atom_types/types.h>\nnamespace opencog\n{\n"
	)
	FILE(WRITE "${DEFINITIONS_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES.  Do not edit */\n"
		"#include <opencog/atoms/atom_types/NameServer.h>\n"
		"#include <opencog/atoms/atom_types/atom_types.h>\n"
		"#include <opencog/atoms/atom_types/types.h>\n"
		"#include \"${HEADER_FILE}\"\n"
	)

	# We need to touch the class-server before doing anything.
	# This is in order to guarantee that the main atomspace types
	# get created before other derived types.
	#
	# There's still a potentially nasty bug here: if some third types.script
	# file depends on types defined in a second file, but the third initializer
	# runs before the second, then any atoms in that third file that inherit
	# from the second will get a type of zero.  This will crash code later on.
	# The only fix for this is to make sure that the third script forces the
	# initailzers for the second one to run first. Hopefully, the programmer
	# will figure this out, before the bug shows up. :-)
	FILE(WRITE "${INHERITANCE_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n\n"
		"/* Touch the server before adding types. */\n"
		"${CLASSSERVER_INSTANCE};\n"
	)

	FILE(WRITE "${CNAMES_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n"
		"#include <opencog/atoms/atom_types/atom_types.h>\n"
		"#include <opencog/atoms/base/Handle.h>\n"
		"#include <opencog/atoms/base/Node.h>\n"
		"#include <opencog/atoms/base/Link.h>\n\n"
		"namespace opencog {\n\n"
		"#define NODE_CTOR(FUN,TYP) inline Handle FUN(std::string name) {\\\n"
		"    return createNode(TYP, std::move(name)); }\n\n"
		"#define LINK_CTOR(FUN,TYP) template<typename ...Atoms>\\\n"
		"    inline Handle FUN(Atoms const&... atoms) {\\\n"
		"       return createLink(TYP, atoms...); }\n\n"
	)

ENDMACRO()

# ------------
# Print out the C++ definitions
MACRO(OPENCOG_CPP_WRITE_DEFS)

	IF (NOT "${TYPE}" STREQUAL "NOTYPE")
		FILE(APPEND "${TMPHDR_FILE}" "extern opencog::Type ${TYPE};\n")
		FILE(APPEND "${DEFINITIONS_FILE}"  "opencog::Type opencog::${TYPE};\n")
	ELSE (NOT "${TYPE}" STREQUAL "NOTYPE")
		FILE(APPEND "${TMPHDR_FILE}"
			"#ifndef _OPENCOG_NOTYPE_\n"
			"#define _OPENCOG_NOTYPE_\n"
			"// Set notype's code with the last possible Type code\n"
			"static const opencog::Type ${TYPE}=((Type) -1);\n"
			"#endif // _OPENCOG_NOTYPE_\n"
		)
	ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")

	IF (ISNODE STREQUAL "NODE" AND
		NOT SHORT_NAME STREQUAL "" AND
		NOT SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "NODE_CTOR(${SHORT_NAME}, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		NOT SHORT_NAME STREQUAL "" AND
		NOT SHORT_NAME STREQUAL "Atom" AND
		NOT SHORT_NAME STREQUAL "Notype" AND
		NOT SHORT_NAME STREQUAL "Type" AND
		NOT SHORT_NAME STREQUAL "TypeSet" AND
		NOT SHORT_NAME STREQUAL "Arity")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(${SHORT_NAME}, ${TYPE})\n")
	ENDIF ()
	# Special case...
	IF (ISNODE STREQUAL "NODE" AND
		SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "NODE_CTOR(TypeNode, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(TypeLink, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "TypeSet")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(TypeIntersection, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "Arity")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(ArityLink, ${TYPE})\n")
	ENDIF ()

	# ------------------------------------
	# Create the type inheritance C++ file.

	IF (PARENT_TYPES)
		STRING(REGEX REPLACE "[ 	]*,[ 	]*" ";" PARENT_TYPES "${PARENT_TYPES}")
		FOREACH (PARENT_TYPE ${PARENT_TYPES})
			# Skip inheritance of the special "notype" class; we could move
			# this test up but it was left here for simplicity's sake
			IF (NOT "${TYPE}" STREQUAL "NOTYPE")
				FILE(APPEND "${INHERITANCE_FILE}"
					"opencog::${TYPE} = ${CLASSSERVER_REFERENCE}"
					"declType(opencog::${PARENT_TYPE}, \"${TYPE_NAME}\");\n"
				)
			ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")
		ENDFOREACH (PARENT_TYPE)
	ELSE (PARENT_TYPES)
		IF (NOT "${TYPE}" STREQUAL "NOTYPE")
			FILE(APPEND "${INHERITANCE_FILE}"
				"opencog::${TYPE} = ${CLASSSERVER_REFERENCE}"
				"declType(opencog::${TYPE}, \"${TYPE_NAME}\");\n"
			)
		ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")
	ENDIF (PARENT_TYPES)
ENDMACRO(OPENCOG_CPP_WRITE_DEFS)

# Macro called up the conclusion of the scripts file.
MACRO(OPENCOG_CPP_TEARDOWN HEADER_FILE)
	FILE(APPEND "${TMPHDR_FILE}" "} // namespace opencog\n")

	FILE(APPEND "${CNAMES_FILE}"
		"#undef NODE_CTOR\n"
		"#undef LINK_CTOR\n"
		"} // namespace opencog\n"
	)

	# Must be last, so that all writing has completed *before* the
	# file appears in the filesystem. Without this, parallel-make
	# will sometimes use an incompletely-written file.
	FILE(RENAME "${TMPHDR_FILE}" "${HEADER_FILE}")
ENDMACRO()

MACRO(OPENCOG_CPP_ATOMTYPES SCRIPT_FILE HEADER_FILE DEFINITIONS_FILE INHERITANCE_FILE)
	OPENCOG_CPP_SETUP(${HEADER_FILE} ${DEFINITIONS_FILE} ${INHERITANCE_FILE})

	FILE(STRINGS "${SCRIPT_FILE}" TYPE_SCRIPT_CONTENTS)
	FOREACH (LINE ${TYPE_SCRIPT_CONTENTS})
		OPENCOG_TYPEINFO_REGEX()
		IF (MATCHED AND CMAKE_MATCH_1)

			OPENCOG_TYPEINFO_SETUP()
			OPENCOG_CPP_WRITE_DEFS()    # Print out the C++ definitions
		ELSEIF (NOT MATCHED)
			MESSAGE(FATAL_ERROR "Invalid line in ${SCRIPT_FILE} file: [${LINE}]")
		ENDIF ()
	ENDFOREACH (LINE)

	OPENCOG_CPP_TEARDOWN(${HEADER_FILE})
ENDMACRO()

#####################################################################
