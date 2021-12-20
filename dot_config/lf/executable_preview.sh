#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# "lf" preview script
# https://github.com/4volodin/dotfiles/blob/020e0bdb63709482277028b58db7055529af14be/.config/lf/preview
# ---
# exit with non-zero code to disable lf caching

FILE="${1}"
WIDTH="${2}"
HEIGHT="${3}"

WIDTH="$(( $WIDTH - 3))"

[ -L "${FILE}" ] && FILE="$(readlink "${FILE}")"

truecol() {
  curl -s https://raw.githubusercontent.com/JohnMorales/dotfiles/master/colors/24-bit-color.sh | bash
}
truecolor() {
awk -v term_cols="${width:-$(tput cols || echo 80)}" 'BEGIN{
    s="/\\";
    for (colnum = 0; colnum<term_cols; colnum++) {
        r = 255-(colnum*255/term_cols);
        g = (colnum*510/term_cols);
        b = (colnum*255/term_cols);
        if (g>255) g = 510-g;
        printf "\033[48;2;%d;%d;%dm", r,g,b;
        printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
        printf "%s\033[0m", substr(s,colnum%2+1,1);
    }
    printf "\n";
}'
}

function main() {
	# Use the right tool for the extension. Falls back on view_sourcecode (bat)
	case "${FILE}" in
		*.tar|*.tgz|*.xz) tar tfv "${FILE}"; return $?;;
		*.deb) ar -tv "${FILE}"; return $?;;
		*.zip) als "${FILE}" || unzip -l "${FILE}"; return $?;;
		*.rar) 7z l "${FILE}"; return $?;;
		*.7z|*.dmg) 7z l "${FILE}" && return $?;;
		*.gz|*.bzip|*.bzip2|*.bp|*.bz2) als "${FILE}" && return $?;;
		*.json) gojq --color-output "${FILE}" && return $?;;
		*.md) glow --style dark --width "${WIDTH}" "${FILE}" && return $?;;
		*.plist) plutil -p "${FILE}" && return $?;;
		*.xml) xmlstarlet fo --indent-spaces 2 "${FILE}" \
			| view_sourcecode && return $?;;
	esac

	## Use the right tool for the mimetype label
	case "$(file -b --mime-type "${FILE}")" in
		video/*|audio/*) view_audio || view_binary;;
		image/*) view_image || view_binary;;
		#image/*) truecol || view_binary;;
		application/pdf) view_pdf || view_binary;;
		application/x-sqlite*) view_sqlite || view_binary;;
		text/plain|text/x-shellscript|text/x-java|text/html) view_sourcecode;;
#		application/octet-stream|application/x-mach-binary|application/x-*executable)
#			view_binary;;
		application/vnd.*-officedocument*|application/vnd.*.opendocument*)
			view_opendocument || view_binary;;

		*) view_sourcecode;;
	esac
	return $?
}

# view binary hexdump
function view_binary() {
	hexyl -n 1024 "${FILE}" || heksa -l 1024 "${FILE}"
	return $?
}

# bat/pygmentize/highlight/cat
function view_sourcecode() {
	local input="$(if read -t 0; then echo ${FILE}; else echo '-'; fi)"
	local input="$(echo ${FILE};)"

	bat "${input}" --theme=TwoDark --color=always \
		--paging=never --tabs=2 --wrap=auto \
		--style=full --decorations=always \
		--terminal-width "${WIDTH}" --line-range :"${HEIGHT}"
	return $?
}

# pdf with pdftoppm and chafa or pdftotext
function view_pdf() {
	#if hash pdftoppm 2>/dev/null && hash chafa 2>/dev/null; then
	timg -g50x50 --frames=1 --title ${FILE} || \
		chafa -s "${WIDTH}x" <(pdftoppm -f 1 -l 1 \
			-scale-to-x 1920 \
			-scale-to-y -1 \
			-singlefile \
			-jpeg -tiffcompression jpeg \
			-- "${FILE}")
	#else
		#pdftotext -l 10 -nopgbrk -q -- "${FILE}" -
	#fi
	return $?
}

# image terminal view with chafa/timg/catimg/cam/imgcat
function view_image() {
	#truecol || \
	#printf "\033[31m red output" || \
	#timg -g50x50  "${FILE}" ||  \
		chafa -c full -s "${WIDTH}x" "${FILE}" || \
		#catimg -r 2 -w 110 -t "${FILE}" || \
		#cam -H "$(echo "$HEIGHT*0.6/1" | bc)" "${FILE}" || \
		#imgcat depth=256 --height "$(echo "$HEIGHT*0.9/1" | bc)" "${FILE}"
		#imgcat "${FILE}"

	if [ $? = 0 ]; then
		echo
		exiv2 "${FILE}" 2>/dev/null || true
	else
		return $code
	fi
}

# multimedia metadata information with mediainfo/id3ted/exiftool/id3info
function view_audio() {
	mediainfo "${FILE}" | sed 's/ *:/:/g' || \
		id3ted -L "${FILE}" || \
		exiftool "${FILE}" || \
		id3info "${FILE}"
	return $?
}

# opendocument with pandoc/odt2txt
function view_opendocument() {
	if ! hash odt2txt 2>/dev/null; then
		return 1
	elif ! hash pandoc 2>/dev/null; then
		odt2txt "${FILE}"
	elif ! hash glow 2>/dev/null; then
		pandoc "${FILE}" --to=markdown || odt2txt "${FILE}"
	elif hash glow 2>/dev/null; then
		glow -s dark -w "${WIDTH}" \
			<(pandoc "${FILE}" --to=markdown || odt2txt "${FILE}")
	fi
	return $?
}

function view_sqlite() {
	echo -e "\e[33m# \e[34m$(basename "${FILE}")\e[0m"
	echo -e "\n\e[35m## \e[34mTABLES\e[0m\n"
	sqlite3 "${FILE}" ".tables"
	return $?
}

main

# always disable lf caching
exit 1

# vim: set ts=2 sw=2 tw=80 noet :
