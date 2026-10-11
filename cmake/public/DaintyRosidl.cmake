include(CMakeParseArguments)

function(rosidl_get_metapackage_path)
    ## Args
    set(options "")
    set(oneValueArgs INTERFACE_ROOT METAPACKAGE OUTPUT_VARIABLE)
    set(multiValueArgs "")
    cmake_parse_arguments(
        PARSE_ARGV 0 _arg
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    ## Impl
    if (_arg_METAPACKAGE)
        if (_arg_INTERFACE_ROOT)
            message(FATAL_ERROR "INTERFACE_ROOT and METAPACKAGE can't be both specified")
        endif ()
        set(_result "${ROSIDL_INTERFACES_DIR}/${_arg_METAPACKAGE}")
    elseif (_arg_INTERFACE_ROOT)
        file(RELATIVE_PATH _intern_mp "${CMAKE_CURRENT_SOURCE_DIR}" "${_arg_INTERFACE_ROOT}")
        set(_result "${ROSIDL_INTERFACES_DIR}/${_intern_mp}")
    else ()
        message(FATAL_ERROR "Either INTERFACE_ROOT or METAPACKAGE must be specified")
    endif ()

    ## Returns
    set(${_arg_OUTPUT_VARIABLE} "${_result}" PARENT_SCOPE)
endfunction()

function(rosidl_import_interfaces INTERFACE_ROOT)
    ## Args
    set(options "")
    set(oneValueArgs INTERN_SOURCES EXTERN_SOURCES EXTERN_METAPACKAGES)
    set(multiValueArgs "")
    cmake_parse_arguments(
        PARSE_ARGV 0 _arg
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    ## Impl
    set(_extern_src "")
    set(_extern_mps "")

    # Parse index.json if present
    set(INDEX_JSON "${INTERFACE_ROOT}/index.json")
    if (EXISTS "${INDEX_JSON}")
        file(READ ${INDEX_JSON} _content)
        string(JSON _len LENGTH "${_content}")
        math(EXPR _len "${_len} - 1") # CMake range is inclusive
        foreach (i RANGE ${_len})
            string(JSON _key MEMBER "${_content}" ${i})
            if (NOT _key MATCHES "^[a-z][a-z0-9_]+$")
                continue()
            endif ()
            list(APPEND _extern_mps ${_key})
            string(JSON _apis GET "${_content}" ${_key})
            string(JSON _api_count LENGTH "${_apis}")
            if (_api_count LESS_EQUAL 0)
                continue()
            endif ()
            math(EXPR _api_count "${_api_count} - 1")
            foreach (j RANGE ${_api_count})
                string(JSON _api GET "${_apis}" ${j})
                list(APPEND _extern_src "${ROSIDL_INTERFACES_DIR}/${_key}/${_api}")
            endforeach ()
        endforeach ()

        get_property(_tmp_depends_list DIRECTORY PROPERTY CMAKE_CONFIGURE_DEPENDS)
        if (NOT "${INDEX_JSON}" IN_LIST _tmp_depends_list)
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${INDEX_JSON}")
        endif ()
    endif ()

    # Glob intern sources
    get_property(_tmp_roots GLOBAL PROPERTY ROSIDL_INTERFACE_ROOTS)
    if (NOT "${INTERFACE_ROOT}" IN_LIST _tmp_roots)
        file(GLOB_RECURSE _intern_src CONFIGURE_DEPENDS "${INTERFACE_ROOT}/*.idl")
        set_property(GLOBAL APPEND PROPERTY ROSIDL_INTERFACE_ROOTS "${INTERFACE_ROOT}")
    else ()
        file(GLOB_RECURSE _intern_src "${INTERFACE_ROOT}/*.idl")
    endif ()

    ## Returns
    set(${_arg_INTERN_SOURCES} "${_intern_src}" PARENT_SCOPE)
    set(${_arg_EXTERN_SOURCES} "${_extern_src}" PARENT_SCOPE)
    set(${_arg_EXTERN_METAPACKAGES} "${_extern_mps}" PARENT_SCOPE)
endfunction()

function(rosidl_compile)
    ## Args
    set(options KEEP)
    set(oneValueArgs INTERFACE_ROOT)
    set(multiValueArgs OUTPUT_FILES OUTPUT_JSONS)
    cmake_parse_arguments(
        PARSE_ARGV 0 _arg
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )
    if (NOT _arg_INTERFACE_ROOT)
        message(FATAL_ERROR "INTERFACE_ROOT must be specified")
    endif ()
    if (NOT _arg_OUTPUT_FILES)
        message(FATAL_ERROR "A variable name for OUTPUT_FILES must be specified")
    endif ()

    ## Impl
    set(_products "") # All declared OUTPUT files
    set(_jsons "") # All generated JSON files

    rosidl_import_interfaces("${_arg_INTERFACE_ROOT}"
        INTERN_SOURCES _intern_src
        EXTERN_SOURCES _extern_src
    )
    file(RELATIVE_PATH _intern_mp "${CMAKE_CURRENT_SOURCE_DIR}" "${_arg_INTERFACE_ROOT}")

    # _intern_mp may contain bad chars
    string(REPLACE "/" "_" _intern_mp_sanitized "${_intern_mp}")
    string(REPLACE "\\" "_" _intern_mp_sanitized "${_intern_mp_sanitized}")
    string(REPLACE ":" "__" _intern_mp_sanitized "${_intern_mp_sanitized}")

    # Declare custom commands
    if (_intern_src)
        set(_intern_jsons "")
        foreach (src IN LISTS _intern_src)
            string(REGEX REPLACE "\\.idl$" ".json" _tmp_out "${src}")
            list(APPEND _intern_jsons "${_tmp_out}")
        endforeach ()
        set(_intern_gen_command COMMAND ${JUST} compile ${_arg_INTERFACE_ROOT})
        set(_intern_gen_output "")
        if (_arg_KEEP)
            set(_intern_json_stamp "${CMAKE_CURRENT_BINARY_DIR}/rosidl_${_intern_mp_sanitized}_json.stamp")
            list(APPEND _intern_gen_command COMMAND ${CMAKE_COMMAND} -E touch ${_intern_json_stamp})
            set(_intern_gen_output ${_intern_json_stamp})
        else()
            set(_intern_gen_output ${_intern_jsons})
        endif ()
        add_custom_command(
            DEPENDS ${_intern_src}
            OUTPUT ${_intern_gen_output}
            ${_intern_gen_command}
            WORKING_DIRECTORY "${ROSIDL_WORK_DIR}"
            COMMENT "Compiling IDL sources in '${_intern_mp}'"
            VERBATIM
        )
        list(APPEND _products ${_intern_gen_output})
        list(APPEND _jsons ${_intern_jsons})
    endif ()
    set(_extern_jsons "")
    foreach (src IN LISTS _extern_src)
        string(REGEX REPLACE "\\.idl$" ".json" _tmp_out ${src})
        list(APPEND _extern_jsons ${_tmp_out})
        string(REPLACE "${ROSIDL_INTERFACES_DIR}/" "" _tmp_name ${src})
        add_custom_command(
            DEPENDS ${src}
            OUTPUT ${_tmp_out}
            COMMAND ${JUST} compile ${src}
            WORKING_DIRECTORY "${ROSIDL_WORK_DIR}"
            COMMENT "Compiling IDL source '${_tmp_name}'"
            VERBATIM
        )
    endforeach ()
    if (_extern_jsons)
        list(APPEND _products ${_extern_jsons})
        list(APPEND _jsons ${_extern_jsons})
    endif ()

    ## Returns
    set(${_arg_OUTPUT_FILES} ${_products} PARENT_SCOPE)
    set(${_arg_OUTPUT_JSONS} ${_jsons} PARENT_SCOPE)
endfunction()
