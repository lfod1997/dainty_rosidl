# DaintyRosidl

A <span style='color:yellow'>\*dainty\*</span> workspace to deal with ROS 2 types without a ROS installation.

A.k.a. [rosidl](https://github.com/ros2/rosidl/) without ROS.

## Requirements

0. Git
1. Python 3.11+
2. [Just](https://just.systems/)

## Usage

To get a workspace for Python development with rosidl:

```
git clone https://github.com/lfod1997/dainty_rosidl.git
cd dainty_rosidl
just prepare YOUR_ROS_DISTRO
```

To integrate into your build system:

1. Embed this repo into some git-ignored location within your project
2. Let your build system run the command `just use_ros YOUR_ROS_DISTRO`, to fetch necessary contents
3. Use it:
    - Run `just compile IN_DIR OUT_DIR` to compile your IDLs into ROS type description JSONs
    - Run `just find_python` and read its output, to get a Python interpreter you can use to access rosidl (a.k.a. it can `import rosidl_XXX`) and run your custom Python script

Example CMake:

```cmake
cmake_minimum_required(VERSION 3.25)
set(ROS_DISTRO "jazzy" CACHE STRING "Target ROS2 distro, should be name of an official ROS2 branch.")

# Find Python and Just
find_program(PYTHON NAMES python python3 REQUIRED)
execute_process(COMMAND ${PYTHON} --version)
find_program(JUST NAMES just REQUIRED)
execute_process(COMMAND ${JUST} --version)

# Declare a dependency
include(FetchContent)
FetchContent_Declare(
    DaintyRosidl
    GIT_REPOSITORY https://github.com/lfod1997/dainty_rosidl.git
    GIT_SHALLOW TRUE
)

# Fetch the dependency
message("Fetching DaintyRosidl")
FetchContent_MakeAvailable(DaintyRosidl)

# Fetch contents
execute_process(
    COMMAND ${JUST} use_ros ${ROS_DISTRO}
    WORKING_DIRECTORY ${daintyrosidl_SOURCE_DIR}
    COMMAND_ERROR_IS_FATAL ANY
)

# Use VPYTHON to run your custom rosidl-based Python script
execute_process(
    COMMAND ${JUST} find_python
    WORKING_DIRECTORY ${daintyrosidl_SOURCE_DIR}
    COMMAND_ERROR_IS_FATAL ANY
    OUTPUT_VARIABLE VPYTHON
)

# Imaginary script: parses IDL via rosidl, and generates some headers for your project
set(MY_ROSIDL_BASED_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate.py")

# Example CMake setting for the code-gen
file(
    GLOB_RECURSE MY_PREREQUISITES
    CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/schema/my_package/*.idl"
)
set(MY_OUTPUT_FILES "${CMAKE_CURRENT_SOURCE_DIR}/schema/generated/my_package.h")
add_custom_command(
    DEPENDS ${MY_PREREQUISITES} ${MY_ROSIDL_BASED_SCRIPT}
    OUTPUT ${MY_OUTPUT_FILES}
    COMMAND ${VPYTHON} ${MY_ROSIDL_BASED_SCRIPT}
    COMMENT "Generating code in DaintyRosidl venv"
    VERBATIM
)

# Targets, DEPENDS on ${MY_OUTPUT_FILES}
# ...
```

## How it works

The script only relies on the "working parts" inside ROS that translates one interface definition format into another, i.e. the rosidl Python modules. Taking advantage of a venv, a simple monkey-patch approach is used to keep the venv small and self-contained.

## Why?

Life inside a ROS environment may be fine. But it's so frustratingly hard if you don't work that way and try to integrate ROS into whatever you're building, as a normal dependency.

"Workspace managers" like Pixi tries to solve the compatibility & cohesiveness problem, and things are a bit better. But the pyramid of dependency is still inverted: ROS wants *you* to be a package, not the other way around. As a package that implements a communication protocol, I expect ROS to appear like a skill book at my disposal. It can be conditionally helpful if the book has more to offer; but if those out-of-the-box convenience is mandatory, I got a strong feeling that particular things are wrongly arranged.

You'd also have to "colcon build" your app, wrestle with an "ament" CMake that amends nothing, rely on a dependency manager that breaks on Windows (though "Tier 1 support" is announced for this platform), and train yourself to meet ROS' software development requirements/standards, which takes you nowhere special.

I simply refuse to invest the bandwidth, the disk/memory/deployed size and importantly the *time* for things I don't need.
