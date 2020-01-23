#!/bin/ksh
set -eu

base_dir=$(readlink -fn ${0%/*})
npm_config_cache="${base_dir}/npm_cache"

usage() {
	echo "${0##*/} [-c] -o tarball"
	exit 1
}

# check arguments
clean=false
output=
while getopts co: arg; do
	case ${arg} in
	c)	clean=true ;;
	o)	output=${OPTARG} ;;
	*)	usage ;;
	esac
done
shift $(( OPTIND -1 ))
[[ $# -ne 0 ]] && usage

# check output
[ -z "${output}" ] && usage
if [ -f "${output}" ]; then
	echo "error: output file already exists: ${output}" >&2
	exit 1
fi

# get archive name
if [ "${output}" != "-" ]; then
	outputname=${output##*/}
	outputname=${outputname%.tgz}
	outputname=${outputname%.tar.gz}
else
	outputname='.'
fi

# export configuration
export npm_config_cache

# check current directory
if [[ ! -r package.json && ! -r Gruntfile.js ]]; then
	echo "error: current directories seems to not contains npm source" >&2
	exit 1
fi

# clear old stuff
echo "[+] clearing old directories" >&2
rm -rf -- \
	'./node_modules' \
	'./bower_components'

[ "${clean}" = 'true' ] && \
	rm -rf -- "${npm_config_cache}"

echo '[+] running npm install' >&2
npm install --production >&2

echo '[+] collecting bower components for' "${outputname}" >&2
for dir in bower_components/* ; do
	name="${dir##*/}"

	for d in "${dir}/dist" "${dir}/min" "${dir}/build" \
		    "${dir}/plugins" "${dir}/extensions" \
		    ; do
		[ -d "${d}" ] && echo "${d}"
	done

	for f in "${dir}/${name}.js" "${dir}/${name}.min.js" \
		    "${dir}/${name}.css" "${dir}/${name}.min.css" \
		    ; do
		[ -r "${f}" ] && echo "${f}"
	done
done | xargs tar -zcf "${output}" -s "/^/${outputname}\//"
