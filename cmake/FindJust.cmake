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
        if (just_version_output MATCHES "just\\s*([0-9]+\\.[0-9]+\\.[0-9]+)")
            set(JUST_VERSION "${CMAKE_MATCH_1}")
        endif ()
    endif ()
endif ()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Just
    REQUIRED_VARS JUST
    VERSION_VAR JUST_VERSION
)

unset(just_version_output)
unset(just_version_result)
