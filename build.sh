#!/bin/ksh
set -eu

umask 022

base_dir=$(readlink -fn ${0%/*})
npm_config_cache="${base_dir}/npm_cache"

usage() {
	echo "${0##*/} [-cs] -o tarball"
	exit 1
}

# check arguments
clean=false
include_sao=false
output=
while getopts cso: arg; do
	case ${arg} in
	c)	clean=true ;;
	s)	include_sao=true ;;
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
echo "[+] clearing old files" >&2
rm -rf -- \
	'./node_modules' \
	'./bower_components' \
	'./dist' \
	'./package-lock.json'

[ "${clean}" = 'true' ] && \
	rm -rf -- "${npm_config_cache}"

echo '[+] running npm install' >&2
npm install --production >&2

echo '[+] running grunt' >&2
# dev:
#   dist/tryton-sao.js
#   src/sao.less -> dist/tryton-sao.css
# uglify:
#   dist/tryton-sao.js -> dist/tryton-sao.min.js
npx grunt dev uglify >&2

if [ ! -e "dist/tryton-sao.min.css" ] ; then
	ln -s "dist/tryton-sao.css" "dist/tryton-sao.min.css"
fi

(
	if [ "${include_sao}" = "true" ]; then
		echo '[+] collecting sao for' "${outputname}" >&2
		[ -d locale ] && echo "locale"
		[ -d images ] && echo "images"
		[ -d dist ] && echo "dist"
		[ -r index.html ] && echo "index.html"
	fi

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
	done 
) | xargs tar -zcf "${output}" -s "/^/${outputname}\//"
