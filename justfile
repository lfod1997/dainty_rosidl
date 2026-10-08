venv_bin_folder := if os_family() == 'windows' { 'Scripts' } else { 'bin' }
venv_pip := '.venv/' + venv_bin_folder + '/pip'
venv_python := '.venv/' + venv_bin_folder + '/python'

# NOTE: repo names, verbatim; syntax: use double quote and comma
ros_interfaces := '"common_interfaces", "rcl_interfaces"'

[private]
default:
	@just --list --list-heading '' --list-prefix '  just ' --justfile '{{ justfile() }}'

# Start from here!
prepare distro='jazzy': (use_ros distro) hint_activate_venv

[private]
fetch_ros distro='jazzy': && discover_ros
	#!/usr/bin/env bash
	IFS=', ' read -ra array <<< `echo 'rosidl, {{ros_interfaces}}' | tr -d '"'`
	for repo in "${array[@]}"; do
		if [ -d thirdparty/$repo ]; then
			if [[ `git -C thirdparty/$repo rev-parse HEAD` != `git -C thirdparty/$repo rev-parse {{ distro }}` ]]; then
				echo "-- Checking out ros2/$repo at \"{{ distro }}\""
				git -C thirdparty/$repo clean -fd
				git -C thirdparty/$repo checkout {{ distro }}
			fi
		else
			echo "-- Cloning ros2/$repo at \"{{ distro }}\""
			git clone https://github.com/ros2/$repo.git -b {{ distro }} thirdparty/$repo
		fi
	done

discover_ros:
	#!/usr/bin/env bash
	[ -d thirdparty/rosidl ] || exit 0
	[ -d .venv ] || exit 0
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

use_ros distro='jazzy': (fetch_ros distro) ensure_venv
	#!/usr/bin/env bash
	echo '-- Compiling ROS interfaces'
	{{venv_python}} - << EOF > /dev/null
	from rosidl_adapter.msg import convert_msg_to_idl
	from rosidl_adapter.srv import convert_srv_to_idl
	from rosidl_adapter.action import convert_action_to_idl
	from pathlib import Path

	for repo in [{{ros_interfaces}}]:
		src = Path.cwd() / f"thirdparty/{repo}"
		for msg in src.glob('**/*.msg'):
			pkg = msg.parents[1]
			convert_msg_to_idl(pkg, pkg.name, msg.relative_to(pkg), msg.parent)
		for srv in src.glob('**/*.srv'):
			pkg = srv.parents[1]
			convert_srv_to_idl(pkg, pkg.name, srv.relative_to(pkg), srv.parent)
		for action in src.glob('**/*.action'):
			pkg = action.parents[1]
			convert_action_to_idl(pkg, pkg.name, action.relative_to(pkg), action.parent)
	EOF
	echo '-- Removing stale artifacts'
	IFS=', ' read -ra array <<< `echo '{{ros_interfaces}}' | tr -d '"'`
	for repo in "${array[@]}"; do
		/usr/bin/find thirdparty/$repo -name *.json -print0 | xargs -r0 rm
	done

ensure_venv: && discover_ros
	#!/usr/bin/env bash
	echo '-- Ensuring venv'
	[ -d .venv ] || python -m venv .venv
	{{ venv_pip }} install -r requirements.txt
	# Hijack package resolution of unnecessary ROS bloatwares
	echo ../../../src/faked > .venv/lib/site-packages/faked.pth

[linux, private]
hint_activate_venv:
	#!/usr/bin/env bash
	echo
	echo '-- You can activate Python venv inside your current shell:'
	echo
	echo '  source .venv/{{ venv_bin_folder }}/activate'
	echo

[windows, private]
hint_activate_venv:
	#!/usr/bin/env bash
	clear
	echo '-- You can activate Python venv inside your current shell.'
	echo
	echo 'For CMD:'
	echo '  call .venv\{{ venv_bin_folder }}\activate.bat'
	echo
	echo 'For PowerShell:'
	echo '  .venv\Scripts\Activate.ps1'
	echo
	echo 'For Git BASH:'
	echo '  source .venv/{{ venv_bin_folder }}/activate'
