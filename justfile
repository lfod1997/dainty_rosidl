venv_bin_folder := if os_family() == 'windows' { 'Scripts' } else { 'bin' }
venv_pip := '.venv/' + venv_bin_folder + '/pip'
venv_python := '.venv/' + venv_bin_folder + '/python'

# NOTE: repo names, verbatim; syntax: use double quote and comma
ros_interfaces := '"common_interfaces", "rcl_interfaces"'

[private]
list:
	@just --list --list-heading '' --list-prefix '  just ' --justfile '{{ justfile() }}'

# Talk more!
help: list
	#!/usr/bin/env bash
	cols=85
	echo
	cat << EOF | fold -sw $cols
	A {{ YELLOW }}*dainty*{{ NORMAL }} workspace to deal with ROS 2 types without a ROS installation.

	{{ WHITE }}Abilities{{ NORMAL }}

	- Compile IDLs into type definition JSONs by running {{ BOLD + WHITE }}just compile{{ NORMAL }} followed by path to the directory containing your IDLs, then optionally a path to populate at.

	- Access the rosidl APIs in a lightweight Python venv, enabling you to achieve ROS-compatible type support through an official implementation.

	- Works with any ROS distro: it's an extraction from the ROS toolset itself.

	- Switch distro by {{ BOLD + WHITE }}just use_ros{{ NORMAL }} , targeting multiple ROS versions made easy.
	EOF
	echo
	read -p "Learn how to get started? (y/N): " confirm && [[ "$confirm" == [yY] ]] || exit 0
	echo
	cat << EOF | fold -s -w $cols
	{{ WHITE }}Get Started{{ NORMAL }}

	- To use from terminal, run {{ BOLD + WHITE }}just prepare{{ NORMAL }} first.

	- To use inside your build pipeline, first run {{ BOLD + WHITE }}just use_ros{{ NORMAL }} upon build or configure, then run any script using the venv's Python executable.

	  Both commands accept a {{ CYAN }}distro{{ NORMAL }} argument.
	  The default {{ GREEN }}jazzy{{ NORMAL }} is recommended for new projects; but you may be targeting a different one, hopefully newer, as type handling differs between humble and newer versions.
	EOF
	echo
	read -p "Learn how it works? (y/N): " confirm && [[ "$confirm" == [yY] ]] || exit 0
	echo
	cat << EOF | fold -s -w $cols
	{{ WHITE }}How it works{{ NORMAL }}

	  The script only relies on the "working parts" inside ROS that translates one interface definition format into another, i.e. the rosidl Python modules. Taking advantage of a venv, a simple monkey-patch approach is used to keep the venv small and self-contained.
	EOF
	echo
	read -p "You should be good to go. Should I talk more (really just bullsh)? (y/N): " confirm && [[ "$confirm" == [yY] ]] || exit 0
	echo
	cat << EOF | fold -s -w $cols
	{{ WHITE }}Why?{{ NORMAL }}

	  Life inside a ROS environment may be fine. But it's so frustratingly hard if you don't work that way and try to integrate ROS into whatever you're building, as a normal dependency.

	  "Workspace managers" like Pixi tries to solve the compatibility & cohesiveness problem, and things are a bit better. But the pyramid of dependency is still inverted: ROS wants {{ ITALIC }}you{{ NORMAL }} to be a package, not the other way around.

	  But ROS is no OS after all: it's a package that grants us machiniloquence so we can talk to robots. It's supposed to appear like a skill book at our disposal. It can be helpful if the book has more to offer; but if those out-of-the-box convenience one might enjoy is now mandatory, I got a strong feeling that particular things are wrongly arranged.
	EOF
	echo
	read -p "I can whine even more. Go on? (y/N): " confirm && [[ "$confirm" == [yY] ]] || exit 0
	echo
	cat << EOF | fold -s -w $cols
	  A full ROS 2 Jazzy installation is ~3.25 GB on Windows, aiming to give you {{ ITALIC }}absolutely everything{{ NORMAL }} to develop a robotics app. But the chance you always needed several dedicated tool to control a cyber turtle (tortoise, maybe), or multiple interchangeable implementations of a same net protocol (one of them warns you about not finding a separate software every time you start working, even though it's not loaded after all), or a Qt runtime for GUI is fractionally small.

	  You'd also have to "colcon build" your app, wrestle with an "ament" version of CMake that amends nothing, rely on a dependency manager that breaks on Windows (though "Tier 1 support" is announced for this platform), and develop a skill set only to meet ROS' requirements, which takes you nowhere special.

	  {{ WHITE }}Why{{ NORMAL }} invest the bandwidth, the disk/memory/deployed size and importantly the {{ ITALIC }}time{{ NORMAL }} for things you don't need?
	EOF

# Start from here!
prepare distro='jazzy': (use_ros distro) hint_activate_venv

# Update Python venv!
ensure_venv: && discover_ros
	#!/usr/bin/env bash
	echo '-- Ensuring venv'
	[ -d .venv ] || python -m venv .venv
	{{ venv_pip }} install -r requirements.txt
	# Hijack package resolution of unnecessary ROS bloatwares
	echo ../../../src/faked > .venv/lib/site-packages/faked.pth

# Print the Python to use!
find_python:
	#!/usr/bin/env bash
	printf '%s' '{{ absolute_path(venv_python) }}'

[private]
checkout_ros distro='jazzy': && discover_ros
	#!/usr/bin/env bash
	if [ -d thirdparty/rosidl ]; then
		if [[ `git -C thirdparty/rosidl rev-parse HEAD` != `git -C thirdparty/rosidl rev-parse {{ distro }}` ]]; then
			echo "-- Checking out ros2/rosidl at \"{{ distro }}\""
			git -C thirdparty/rosidl clean -fd
			git -C thirdparty/rosidl checkout {{ distro }}
		fi
	else
		echo "-- Cloning ros2/rosidl at \"{{ distro }}\""
		git clone https://github.com/ros2/rosidl.git -b {{ distro }} thirdparty/rosidl
	fi
	IFS=', ' read -ra array <<< `echo '{{ ros_interfaces }}' | tr -d '"'`
	for repo in "${array[@]}"; do
		if [ -d thirdparty/interfaces/$repo ]; then
			if [[ `git -C thirdparty/interfaces/$repo rev-parse HEAD` != `git -C thirdparty/interfaces/$repo rev-parse {{ distro }}` ]]; then
				echo "-- Checking out ros2/$repo at \"{{ distro }}\""
				git -C thirdparty/interfaces/$repo clean -fd
				git -C thirdparty/interfaces/$repo checkout {{ distro }}
			fi
		else
			echo "-- Cloning ros2/$repo at \"{{ distro }}\""
			git clone https://github.com/ros2/$repo.git -b {{ distro }} thirdparty/interfaces/$repo
		fi
	done

# Check for ROS updates!
fetch_ros:
	#!/usr/bin/env bash
	if [ -d thirdparty/rosidl ]; then
		echo "-- Fetching ros2/rosidl from remote"
		git -C thirdparty/rosidl fetch origin --tags --prune
		if git -C thirdparty/rosidl rev-parse --abbrev-ref @{u} > /dev/null 2> /dev/null; then # Have any upstream
			if [[ `git -C thirdparty/rosidl rev-list --count HEAD..@{u}` != '0' ]]; then # Behind count != 0
				echo "{{ CYAN }}Update available{{ NORMAL }} for \"`git -C thirdparty/rosidl branch --show-current`\"!"
				if [[ `git -C thirdparty/rosidl rev-list --count @{u}..HEAD` == '0' ]]; then # Ahead count == 0
					echo "Run {{ BOLD + WHITE }}git -C thirdparty/rosidl pull{{ NORMAL }} to update."
				else
					echo "Wow, you have customized ros2/rosidl; receive updates when you're ready, then."
				fi
			else
				echo "{{ GREEN }}Up to date{{ NORMAL }} with \"`git -C thirdparty/rosidl rev-parse --abbrev-ref @{u}`\"."
			fi
		else
			echo 'Not tracking any remote branch, further checking is skipped.'
		fi
	else
		echo "-- Cloning ros2/rosidl at default branch"
		git clone https://github.com/ros2/rosidl.git thirdparty/rosidl
	fi
	IFS=', ' read -ra array <<< `echo '{{ ros_interfaces }}' | tr -d '"'`
	for repo in "${array[@]}"; do
		if [ -d thirdparty/interfaces/$repo ]; then
			echo "-- Fetching ros2/$repo from remote"
			git -C thirdparty/interfaces/$repo fetch origin --tags --prune
			if git -C thirdparty/interfaces/$repo rev-parse --abbrev-ref @{u} > /dev/null 2> /dev/null; then # Have any upstream
				if [[ `git -C thirdparty/interfaces/$repo rev-list --count HEAD..@{u}` != '0' ]]; then # Behind count != 0
					echo "{{ CYAN }}Update available{{ NORMAL }} for \"`git -C thirdparty/interfaces/$repo branch --show-current`\"!"
					if [[ `git -C thirdparty/interfaces/$repo rev-list --count @{u}..HEAD` == '0' ]]; then # Ahead count == 0
						echo "Run {{ BOLD + WHITE }}git -C thirdparty/interfaces/$repo pull{{ NORMAL }} to update."
					else
						echo "Wow, you have customized ros2/$repo; receive updates when you're ready, then."
					fi
				else
					echo "{{ GREEN }}Up to date{{ NORMAL }} with \"`git -C thirdparty/interfaces/$repo rev-parse --abbrev-ref @{u}`\"."
				fi
			else
				echo 'Not tracking any remote branch, further checking is skipped.'
			fi
		else
			echo "-- Cloning ros2/$repo at default branch"
			git clone https://github.com/ros2/$repo.git thirdparty/interfaces/$repo
		fi
	done

[private]
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

# Switch ROS 2 distro!
use_ros distro='jazzy': (checkout_ros distro) ensure_venv
	#!/usr/bin/env bash
	echo '-- Compiling ROS interfaces'
	{{ venv_python }} - << EOF > /dev/null
	from rosidl_adapter.msg import convert_msg_to_idl
	from rosidl_adapter.srv import convert_srv_to_idl
	from rosidl_adapter.action import convert_action_to_idl
	from pathlib import Path

	for repo in [{{ ros_interfaces }}]:
		src = Path(r'{{ justfile_directory() }}') / f"thirdparty/interfaces/{repo}"
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
	IFS=', ' read -ra array <<< `echo '{{ ros_interfaces }}' | tr -d '"'`
	for repo in "${array[@]}"; do
		/usr/bin/find thirdparty/interfaces/$repo -name *.json -print0 | xargs -r0 rm
	done

# Compile my IDLs to JSON!
compile in_dir out_dir=in_dir:
	#!/usr/bin/env bash
	captured_python=`pwd`/{{ venv_python }}
	cd {{ invocation_directory() }}
	$captured_python - << EOF
	from rosidl_generator_type_description.cli import HashTypeDescription
	from pathlib import Path
	import re

	IDL_MODULE_PATTERN = r'\bmodule\s+(\w+)\s*\{[^{}]*?\bmodule\s+(\w+)\s*\{'
	ACCEPTED_IDL_INNER_MODULE = ['msg', 'srv', 'action']

	def check_idl(path: Path):
		with open(path, 'r') as f:
			idl_text = f.read()
		match = re.search(IDL_MODULE_PATTERN, idl_text)
		return (match.group(1), match.group(2)) if match else ("", "")

	def compile_idl(p: str, includes: list, package_name: str | None = None, out_path: Path | None = None) -> str:
		path = Path(p).resolve()
		if package_name is None: package_name = path.parents[1].name
		if out_path is None: out_path = path.parents[1] # Suffixed with '/msg'
		return HashTypeDescription('').generate_type_hashes(
			package_name=package_name,
			interface_files=[p],
			include_paths=includes,
			output_path=out_path
		)[0]

	if __name__ == '__main__':
		import sys
		import shutil

		my_in = Path(r"{{ in_dir }}")
		my_out_dir = Path(r"{{ out_dir }}")
		my_includes = [] # TODO: support custom includes

		# Collect includes
		all_includes = [Path(p) for p in my_includes]
		all_includes.extend(
			[Path(r'{{ justfile_directory() }}') / f"thirdparty/interfaces/{repo}" for repo in [
				{{ ros_interfaces }},
			]]
		)

		# Collect all IDLs to compile
		my_in_dir = my_in
		my_in_glob = []
		if my_in.is_dir():
			my_in_glob = my_in.glob('**/*.idl')
		elif my_in.is_file() and my_in.name.endswith('.idl'):
			my_in_dir = my_in.parent
			if my_out_dir.is_file(): # In case default arg was passed
				my_out_dir = my_in_dir
			my_in_glob = [my_in]
		else:
			raise ValueError(my_in)

		# Check IDLs
		my_idls = []
		original_dir_of = {}
		package_name_of = {}
		for idl in my_in_glob:
			package_name, category = check_idl(idl)
			if len(package_name) == 0 or len(category) == 0:
				print(f'Skipping file {idl}: not a ROS-compatible IDL, expected struct in nested modules', file=sys.stderr)
				continue
			if category not in ACCEPTED_IDL_INNER_MODULE:
				print(f'Skipping file {idl}: bad inner module name, expected one of: "', end='', file=sys.stderr)
				print(*ACCEPTED_IDL_INNER_MODULE, sep='", "', end='', file=sys.stderr)
				print(f'"; got: "{category}"', file=sys.stderr)
				continue
			if idl.parent.name not in ACCEPTED_IDL_INNER_MODULE:
				# Most possibly located in its "package root"; we want to support this
				d = idl.parent / category
				d.mkdir(exist_ok=True)
				df = Path(shutil.move(idl, d))
				original_dir_of[df] = idl.parent
				my_idls.append(str(df))
				package_name_of[str(df)] = package_name
			else:
				if idl.parent.name != category:
					# Wrongly located, eg. a srv IDL located at pkg/msg;
					# We're not definitely sure where to actually put it, just warn the user
					print(f'Skipping file {idl}: bad location, expected parent: "{category}"', file=sys.stderr)
					continue
				# Located following ROS convention, good
				my_idls.append(str(idl))
				package_name_of[str(idl)] = package_name

		# Restore directories
		my_idls = set(my_idls)
		todo = list(my_idls)
		done = set()
		my_jsons = []
		while len(todo) != 0:
			i = todo[-1]
			if i in done:
				assert i == todo.pop()
				continue
			o = ''
			try:
				o = compile_idl(
					i, all_includes,
					package_name_of[i] if i in my_idls else None,
					# TODO: Warn about the folder structure that makes this cond True
					my_in_dir if i in my_idls and Path(i).parents[1].name != package_name_of[i] else None
				)
			except FileNotFoundError as e:
				who = e.filename
				if who is None: raise e
				if not isinstance(who, str): who = str(who, encoding='utf-8')
				who = who.rsplit('.', 1)[0] + '.idl'
				if who == i: raise e
				todo.append(who)
			else:
				assert i == todo.pop()
				done.add(i)
				if i in my_idls: my_jsons.append(o)

		for o in my_jsons:
			o = Path(o)
			if my_out_dir.samefile(o.parent): continue
			(my_out_dir / o.name).unlink(missing_ok=True)
			print(str(shutil.move(o, my_out_dir)))
			if not any(o.parent.iterdir()): o.parent.rmdir()
		for df in original_dir_of.keys():
			shutil.move(df, original_dir_of[df])
			if not any(df.parent.iterdir()): df.parent.rmdir()
	EOF

[private]
[linux]
hint_activate_venv:
	#!/usr/bin/env bash
	echo
	echo '-- You can activate rosidl Python venv inside your current shell:'
	echo
	echo '  {{ BOLD + WHITE }}source .venv/{{ venv_bin_folder }}/activate{{ NORMAL }}'
	echo

[private]
[windows]
hint_activate_venv:
	#!/usr/bin/env bash
	clear
	echo '-- You can activate rosidl Python venv inside your current shell.'
	echo
	echo 'For CMD:'
	echo '  {{ BOLD + WHITE }}call .venv\{{ venv_bin_folder }}\activate.bat{{ NORMAL }}'
	echo
	echo 'For PowerShell:'
	echo '  {{ BOLD + WHITE }}.venv\Scripts\Activate.ps1{{ NORMAL }}'
	echo
	echo 'For Git BASH:'
	echo '  {{ BOLD + WHITE }}source .venv/{{ venv_bin_folder }}/activate{{ NORMAL }}'
