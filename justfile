venv_bin_folder := if os_family() == 'windows' { 'Scripts' } else { 'bin' }
venv_pip := '.venv/' + venv_bin_folder + '/pip'
venv_python := '.venv/' + venv_bin_folder + '/python'

[private]
default:
	@just --list --list-heading '' --list-prefix '  just ' --justfile '{{ justfile() }}'

# Start from here!
prepare distro='jazzy': (fetch_ros distro) activate_venv

fetch_ros distro='jazzy': && discover_ros
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

discover_ros:
	#!/usr/bin/env bash
	[ -d thirdparty/rosidl ] || exit
	[ -d .venv ] || exit
	if [ -f .venv/lib/site-packages/rosidl.pth ]; then
		echo '-- Rediscovering Python packages in ros2/rosidl'
	else
		echo '-- Discovering Python packages in ros2/rosidl'
	fi
	/usr/bin/find thirdparty/rosidl -name __init__.py |\
		/usr/bin/awk -v max=3 -F'/' 'OFS="/" {
			out=""; cnt=0;
			for(i=1; i<=NF; i++) {
				if($i != "") { cnt++; if(cnt<=max) out=out (out==""?"":"/") $i; }
			}
			print "../../../" ($0 ~ /^\// ? "/" : "") out
		}' |\
		/usr/bin/sort -u > .venv/lib/site-packages/rosidl.pth

ensure_venv: && discover_ros
	#!/usr/bin/env bash
	echo '-- Ensuring venv'
	[ -d .venv ] || python -m venv .venv
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
