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

ensure_venv: && discover_ros
	#!/usr/bin/env bash
	echo '-- Ensuring venv'
	[ -d .venv ] || python -m venv .venv
	{{ venv_pip }} install -r requirements.txt
	# Hijack package resolution of unnecessary ROS bloatwares
	echo ../../../src/faked > .venv/lib/site-packages/faked.pth

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

# Compile your IDLs!
compile pkg in_dir out_dir=in_dir:
	#!/usr/bin/env bash
	{{venv_python}} - << EOF
	from rosidl_generator_type_description.cli import HashTypeDescription
	from pathlib import Path

	def compile_idl(p: str, includes: list, package_name = None, out_path = None) -> str:
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
		import shutil

		my_package_name = r"{{pkg}}"
		my_in_dir = r"{{in_dir}}"
		my_out_dir = r"{{out_dir}}"
		my_includes = [] # TODO: support custom includes

		# Collect includes
		all_includes = [Path(p) for p in my_includes]
		all_includes.extend(
			[Path.cwd() / f"thirdparty/{repo}" for repo in [
				{{ros_interfaces}},
			]]
		)

		# Collect all IDLs to compile
		my_idls = []
		original_dir_of = {}
		for idl in Path(my_in_dir).glob('**/*.idl'):
			if idl.parent.name not in ['msg', 'srv', 'action']:
				d = idl.parent / 'msg' # TODO: Categorize by reading the IDL
				d.mkdir(exist_ok=True)
				df = Path(shutil.move(idl, d))
				original_dir_of[df] = idl.parent
				my_idls.append(str(df))
			else:
				my_idls.append(str(idl))

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
					my_package_name if i in my_idls else None,
					my_in_dir if i in my_idls else None
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

		d = Path(my_out_dir)
		for o in my_jsons:
			o = Path(o)
			if d.samefile(o.parent): continue
			(d / o.name).unlink(missing_ok=True)
			print(str(shutil.move(o, d)))
			if not any(o.parent.iterdir()): o.parent.rmdir()
		for df in original_dir_of.keys():
			shutil.move(df, original_dir_of[df])
			if not any(df.parent.iterdir()): df.parent.rmdir()
	EOF

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
