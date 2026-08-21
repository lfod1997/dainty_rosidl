venv_bin_folder := if os_family() == 'windows' { 'Scripts' } else { 'bin' }
venv_pip := '.venv/' + venv_bin_folder + '/pip'
venv_python := '.venv/' + venv_bin_folder + '/python'

[private]
default:
	@just --list --list-heading '' --list-prefix '  just ' --justfile '{{ justfile() }}'

# Start from here!
prepare distro='jazzy': (fetch_ros distro) activate_venv

fetch_ros distro='jazzy':
	#!/usr/bin/env bash
	echo '-- Checking out ros2/rosidl at "{{ distro }}"'
	if [ -d thirdparty/rosidl ]; then
		git -C thirdparty/rosidl checkout {{ distro }}
	else
		git clone https://github.com/ros2/rosidl.git -b {{ distro }} thirdparty/rosidl
	fi
	echo '-- Checking out ros2/common_interfaces at "{{ distro }}"'
	if [ -d thirdparty/common_interfaces ]; then
		git -C thirdparty/common_interfaces checkout {{ distro }}
	else
		git clone https://github.com/ros2/common_interfaces.git -b {{ distro }} thirdparty/common_interfaces
	fi

ensure_venv:
	#!/usr/bin/env bash
	echo '-- Ensuring venv'
	[ -d .venv ] || python -m venv .venv
	cat << EOF > .venv/lib/site-packages/rosidl.pth
	../../../thirdparty/rosidl/rosidl_adapter
	../../../thirdparty/rosidl/rosidl_buffer_py
	../../../thirdparty/rosidl/rosidl_cli
	../../../thirdparty/rosidl/rosidl_cmake
	../../../thirdparty/rosidl/rosidl_generator_c
	../../../thirdparty/rosidl/rosidl_generator_cpp
	../../../thirdparty/rosidl/rosidl_generator_type_description
	../../../thirdparty/rosidl/rosidl_parser
	../../../thirdparty/rosidl/rosidl_pycommon
	../../../thirdparty/rosidl/rosidl_typesupport_introspection_c
	../../../thirdparty/rosidl/rosidl_typesupport_introspection_cpp
	EOF
	{{ venv_pip }} install -r requirements.txt

[linux]
activate_venv: ensure_venv
	#!/usr/bin/env bash
	echo
	echo '-- Python venv need to be activated inside your current shell:'
	echo
	echo '  source .venv/{{ venv_bin_folder }}/activate'
	echo

[windows]
activate_venv: ensure_venv
	#!/usr/bin/env bash
	clear
	echo '-- Python venv need to be activated inside your current shell.'
	echo
	echo 'For CMD:'
	echo '  call .venv\{{ venv_bin_folder }}\activate.bat'
	echo
	echo 'For PowerShell:'
	echo '  .venv\Scripts\Activate.ps1'
	echo
	echo 'For Git BASH:'
	echo '  source .venv/{{ venv_bin_folder }}/activate'
