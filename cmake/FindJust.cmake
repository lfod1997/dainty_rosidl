# Locates user's system Just.

find_program(JUST
    NAMES just
    DOC "Just executable."
)
mark_as_advanced(JUST)

if (JUST)
    execute_process(
        COMMAND "${JUST}" --version
        OUTPUT_VARIABLE just_version_output
        RESULT_VARIABLE just_version_result
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if (just_version_result EQUAL 0)
        set(_ver "${just_version_output}")
        if (just_version_output MATCHES "just[ \t]*([0-9]+\\.[0-9]+\\.[0-9]+)")
            set(_ver "${CMAKE_MATCH_1}")
        endif ()
        set(JUST_VERSION "${_ver}" CACHE STRING "Just version (read-only)." FORCE)
        mark_as_advanced(JUST_VERSION)
    else ()
        unset(JUST_VERSION)
    endif ()
else ()
    unset(JUST_VERSION)
endif ()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Just
    REQUIRED_VARS JUST JUST_VERSION
    VERSION_VAR JUST_VERSION
)

unset(just_version_output)
unset(just_version_result)
