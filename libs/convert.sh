for lib in "$1"/*.dylib; do
	echo "Processing $lib"
	install_path="$(otool -D "$lib"|tail -n1)"
	new_install_path="${install_path/executable_path/loader_path}"
	if [[ "${install_path}" == "${new_install_path}" ]]; then
		echo "-  Install path already uses @loader_path"
	else
		echo "-  Changing install path from $install_path to ${new_install_path}"
	fi
	install_name_tool -id "${new_install_path}" "$lib"
	otool -L "$lib"|egrep --only-matching '^	@executable_path.+\.dylib'|while read dependancy_path; do
		echo "-  Switching dependancy path ${dependancy_path} to @loader_path${dependancy_path#@executable_path}"
		install_name_tool -change "${dependancy_path}" "@loader_path${dependancy_path#@executable_path}" "$lib"
	done
done