#!/bin/bash

echo "Checking for bash..."
if [ -z "$BASH_VERSION" ]; then
	echo "Invalid shell, re-running using bash..."
	exec bash "$0" "$@"
	exit $?
fi
SRCLOC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ROOT="$SRCLOC/.."

if [[ "$(uname -a)" =~ Linux ]]; then
	GET_FILE_MODIFICATION="stat -c %Y"
elif [[ "$(uname -a)" =~ Darwin ]]; then
	GET_FILE_MODIFICATION="stat -f %m"
elif [[ "$(uname -a)" =~ Cygwin ]]; then
	GET_FILE_MODIFICATION="stat -c %Y"
elif [[ "$(uname -a)" =~ MINGW ]]; then
	GET_FILE_MODIFICATION="stat -c %Y"
else
	echo "'$(uname -a)' is not recognized"
	exit 1
fi

# Prepare destination
DEST="$SRCLOC/Resources/Shipped"
mkdir -p "$DEST"

# Function downloadShippedResource(name, url)
function downloadShippedResource()
{
	local name=$1
	local url=$2
	
	(cd "$DEST" && \
		curl --remote-time --time-cond $name --location --output $name --fail $url && \
		$GET_FILE_MODIFICATION "$name" > "$name.stamp")
	if [ $? -ne 0 ]; then
		local retcode=$?
		echo "Failed to download '$name' from $url, aborting..."
		exit $retcode
	fi
	echo "Shipping '$name' with version '"$(cat "$DEST/$name.stamp")"'"
}

# Download world mini-basemap
downloadShippedResource WorldMiniBasemap.obf "http://builder.osmand.net:81/basemap/World_basemap_mini_2.obf"
