cmake_minimum_required(VERSION 3.25)

if (ROS_DISTRO)
    message(STATUS "Targeting ROS 2 distro '${ROS_DISTRO}'")
else ()
    message(STATUS "Target ROS 2 distro not set; defaulting to 'jazzy'")
    set(ROS_DISTRO "jazzy" CACHE STRING "Target ROS2 distro, should be name of an official ROS2 branch.")
endif ()

if (NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/public")
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)
endif ()
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(Just REQUIRED)

execute_process(
    COMMAND ${JUST} use_ros ${ROS_DISTRO}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
    COMMAND ${JUST} find_python
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE ROSIDL_PYTHON
    COMMAND_ERROR_IS_FATAL ANY
)

# Export variables
set(ROSIDL_INTERFACES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/interfaces" CACHE PATH "DaintyRosidl: Directory which official ROS interface repositories (the \"metapackages\") are cloned into." FORCE)
set(ROSIDL_WORK_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH "DaintyRosidl: Package directory." FORCE)
set(ROSIDL_PYTHON "${ROSIDL_PYTHON}" CACHE FILEPATH "DaintyRosidl: Python3 interpreter that provides access to the rosidl venv." FORCE)
