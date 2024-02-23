#!/bin/bash -e
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="meson ninja unzip curl pip flex bison zip"
workdir="$(pwd)/turnip_workdir"
driverdir="$workdir/turnip_module"
ndkver="android-ndk-r26c"
sdkver="34"
clear

# there are 4 functions here, simply comment to disable.
# you can insert your own function and make a pull request.
run_all(){
	check_deps
	prepare_workdir
	build_lib_for_android
	prepare_zip
}


check_deps(){
	echo "Checking system for required Dependencies ..."
	for deps_chk in $deps;
		do
			sleep 0.25
			if command -v "$deps_chk" >/dev/null 2>&1 ; then
				echo -e "$green - $deps_chk found $nocolor"
			else
				echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
				deps_missing=1
			fi;
		done

		if [ "$deps_missing" == "1" ]
			then echo "Please install missing dependencies" && exit 1
		fi

	echo "Installing python Mako dependency (if missing) ..." $'\n'
	pip install mako &> /dev/null
}



prepare_workdir(){
	echo "Creating and entering to work directory ..." $'\n'
	mkdir -p "$workdir" && cd "$_"

	echo "Downloading android-ndk from google server (~640 MB) ..." $'\n'
	curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
	###
	echo "Exracting android-ndk to a folder ..." $'\n'
	unzip "$ndkver"-linux.zip  &> /dev/null

	echo "Downloading mesa source (~30 MB) ..." $'\n'
	curl https://gitlab.freedesktop.org/mesa/mesa/-/archive/main/mesa-main.zip --output mesa-main.zip &> /dev/null
	###
	echo "Exracting mesa source to a folder ..." $'\n'
	unzip mesa-main.zip &> /dev/null
	cd mesa-main
}



build_lib_for_android(){
	echo "Creating meson cross file ..." $'\n'
	ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"

	cat <<EOF >"android-aarch64"
	[binaries]
	ar = '$ndk/llvm-ar'
	c = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang']
	cpp = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
	c_ld = 'lld'
	cpp_ld = 'lld'
	strip = '$ndk/aarch64-linux-android-strip'
	pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkgconfig', '/usr/bin/pkg-config']
	[host_machine]
	system = 'android'
	cpu_family = 'aarch64'
	cpu = 'armv8'
	endian = 'little'
EOF

	echo "Generating build files ..." $'\n'
	meson build-android-aarch64 --cross-file "$workdir"/mesa-main/android-aarch64 -Dbuildtype=release -Dplatforms=android -Dplatform-sdk-version=$sdkver -Dandroid-stub=true -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dvulkan-beta=true -Dfreedreno-kmds=kgsl -Db_lto=true &> "$workdir"/meson_log

	echo "Compiling build files ..." $'\n'
	ninja -C build-android-aarch64 &> "$workdir"/ninja_log
}



prepare_zip(){
	echo "Create driverdir ..." $'\n'
	mkdir -p $driverdir
	cd $driverdir

	echo "Create meta file ..." $'\n'
	cat <<EOF >"meta.json"
{
  "schemaVersion": 1,
  "name": "Mesa Turnip Adreno Driver",
  "description": "Open-source Vulkan driver",
  "author": "Mesa",
  "packageVersion": "dev",
  "vendor": "Mesa",
  "driverVersion": "latest Main",
  "minApi": 30,
  "libraryName": "libvulkan_freedreno.so"
}
EOF

	echo "Copy .so file to driverdir ..." $'\n'
	cp $workdir/mesa-main/build-android-aarch64/src/freedreno/vulkan/libvulkan_freedreno.so $driverdir

	echo "Zip driverdir ..." $'\n'
	zip -r "$workdir"/turnip.zip ./* &> /dev/null

	echo "Build process finished ..." $'\n'
}

run_all
