#!/bin/bash

function usage() {  #heredoc
	cat<<-EOF
gtd = Getting Things Done
Collect and manage your ideas, todos, logs and documents.

usage:
  gtd [-h|--help|-?]
  gtd <command> [<args>]

The most commonly used gtd commands are:
  add
  remove
  view
  edit
  list
  move
  set
  unset
	EOF
}

function debug() { >&2 echo "$@"; }

#=== INIT =====================================================================
function usage_init() {  #heredoc
	cat<<-EOF
Create GTD library for current user($USER) in $GTD_ROOT.
	EOF
}

GTD_ROOT="$HOME/.gtd"
GTD_INBOX="$GTD_ROOT/inbox"
GTD_TODO="$GTD_ROOT/todo"
GTD_WAIT="$GTD_ROOT/wait"
GTD_PROJECT="$GTD_ROOT/project"
GTD_LOG="$GTD_ROOT/log"
GTD_REFERENCE="$GTD_ROOT/reference"
GTD_SOMEDAY="$GTD_ROOT/someday"
GTD_TRASH="$GTD_ROOT/trash"

function check_dir { #check dir $1's existence
	[ ! -d "$1" ] && debug "No $1" && echo false && return
	echo true
}
function check_dirs() {
	[ $(check_dir "$GTD_ROOT") == false ] && echo false && return
	[ $(check_dir "$GTD_INBOX") == false ] && echo false && return
	[ $(check_dir "$GTD_TODO") == false ] && echo false && return
	[ $(check_dir "$GTD_WAIT") == false ] && echo false && return
	[ $(check_dir "$GTD_PROJECT") == false ] && echo false && return
	[ $(check_dir "$GTD_LOG") == false ] && echo false && return
	[ $(check_dir "$GTD_REFERENCE") == false ] && echo false && return
	[ $(check_dir "$GTD_SOMEDAY") == false ] && echo false && return
	echo true
}
NO_DIR="No GTD library, please run 'gtd init' first."

function check_and_make_dir() {  #make dir $1 if not exist
	[ ! -d "$1" ] && echo "No $1, create it." && mkdir "$1"
}
function check_and_make_dirs() {  #make gtd dirs
	check_and_make_dir "$GTD_ROOT"
	check_and_make_dir "$GTD_INBOX"
	check_and_make_dir "$GTD_TODO"
	check_and_make_dir "$GTD_WAIT"
	check_and_make_dir "$GTD_PROJECT"
	check_and_make_dir "$GTD_LOG"
	check_and_make_dir "$GTD_REFERENCE"
	check_and_make_dir "$GTD_SOMEDAY"
	check_and_make_dir "$GTD_TRASH"
}

function init() {
	TEMP=`getopt -o h --long help -n 'gtd.init' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	while : ; do
		case "$1" in
		-h|--help) to_help=true; shift;;
		--) shift; break;;
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help = true ] && usage_init && return
	check_and_make_dirs
}

#=== FILE ATTRIBUTES ==========================================================
# file name(fn) specification
# <id>.<ctime>[.-a.<alias>][.-x.<context1>[.context2]...][.-d.<due>]
# [.-o.<owner>][.-p.<priority>][.-s.<sensitivity>][.-t.<tag1>[.tag2]...]
# [.-e.<ext>]

function get_id_from_fn() {  #light func just to get id, $1=file.basename
	id_str=$(echo "$1" | sed -e "s/\..*//g")  #remove chars after dots
	re='^[0-9]+$'  #check if id is num w/ regular expression
	if ! [[ $id_str =~ $re ]]; then
		echo "0"
	else
		echo "$id_str"
	fi
}

function get_max_id_in_dir() {  #$1=dir
	declare -i max_id=1000  #id start from 1001
	declare -i max_id_dir
	for file in "$1"/*; do
		if [ -d "${file}" ]; then
			max_id_dir=$(get_max_id_in_dir "${file}")
			if [[ $max_id_dir > $max_id ]]; then
				max_id=$max_id_dir
			fi
		else
			fn=$(basename "${file}")
			[ "$fn" == "*" ] && continue
			id_str=$(get_id_from_fn "$fn")
			if [ $(($id_str+0)) -gt $max_id ]; then
				max_id=$(($id_str+0))
			fi
		fi
	done
	echo $max_id  #return value!
}
function get_max_id() { get_max_id_in_dir "$GTD_ROOT"; }  #';' is must

function parse_fn() {  #$1=fn
	IFS='.' read -ra PARTS <<< "$1"
	cur="id"
	id=""; ctime=""; alias="-a"
	context="-x"; due="-d"; owner="-o"
	priority="-p"; sensitivity="-s"
	tag="-t"; ext="-e"
	for str in "${PARTS[@]}"; do
		case "$cur" in
		id) id=$str; cur="ctime";;
		ctime) ctime=$str; cur="none";;
		none|context|tag)
			case "$str" in
			-a) cur="alias"; continue;;
			-c) cur="context"; continue;;
			-d) cur="due"; continue;;
			-o) cur="owner"; continue;;
			-p) cur="priority"; continue;;
			-s) cur="sensitivity"; continue;;
			-t) cur="tag"; continue;;
			-e) cur="ext"; continue;;
			esac
			if [ "$cur" == "context" ]; then
				context="$context.$str"
				continue
			fi
			if [ "$cur" == "tag" ]; then
				tag="$tag.$str"
				continue
			fi;;
		alias) alias="$alias.$str"; cur="none";;
		due) due="$due.$str"; cur="none";;
		owner) owner="$owner.$str"; cur="none";;
		priority) priority="$priority.$str"; cur="none";;
		sensitivity) sensitivity="$sensitivity.$str"; cur="none";;
		ext) ext="$ext.$str"; cur="none";;
		esac
	done
	echo "$id $ctime $alias $context $due $owner $priority $sensitivity \
	  $tag $ext"
}

function make_fn() {  #$1=id $2=ctime $3=alias $4=context $5=due $6=owner
                      #$7=priority $8=sensitiity $9=tag $10=ext
	str="$1.$2"
	[ "$3" != "-a" ] && str="$str.$3"
	[ "$4" != "-x" ] && str="$str.$4"
	[ "$5" != "-d" ] && str="$str.$5"
	[ "$6" != "-o" ] && str="$str.$6"
	[ "$7" != "-p" ] && str="$str.$7"
	[ "$8" != "-s" ] && str="$str.$8"
	[ "$9" != "-t" ] && str="$str.$9"
	[ "${10}" != "-e" ] && str="$str.${10}" || str="$str.-e.txt"
	echo "$str"
}

function get_file_in_dir() {  #$1= path, $2=id|alias
	result=""
	for file in "$1"/*; do
		if [ -d "${file}" ]; then
			result=$(get_file_in_dir "${file}" $2)
			[ ! -z $result ] && break
		else
			fn=$(basename "${file}")
			[ "$fn" == "*" ] && continue
			id_str=$(get_id_from_fn "$fn")
			if [ "$id_str" == "$2" ]; then
				result=$file
				break
			fi
		fi
	done
	echo "$result"  #return value!
}
function get_file() { get_file_in_dir "$GTD_ROOT" "$1"; }  #$1=id|alias

#=== ADD ======================================================================
function usage_add() {  #heredoc
	cat<<-EOF
usage: gtd <add-command> [options...]
  add-command
    add,           a   Add to the Inbox
    add-todo,      at  Add to the Todo List
    add-wait,      aw  Add to the Waiting List
    add-project,   ap  Add to the Projects
    add-log,       al  Add to the Logs
    add-reference, ar  Add to the Reference library
    add-someday,   as  Add to the Someday-Maybe items
  options
    --help,        -h  Display this documentation
    --verbose,     -v  Open vim to facilitate complex editing
	EOF
}

function add_stuff() {  #$1=dir
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	new_id=$(($(get_max_id) + 1))
	fn=$(make_fn $new_id $(date +%s) -a -x -d -o -p -s -t -e)
	path="$1/$fn"
	shift  #skip $1 to other args
	TEMP=`getopt -o m:vh --long message:,verbose,help -n 'gtd.add' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	message=""
	while : ; do
		case "$1" in
		-m|--message) message="$2"; shift 2;;
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; break;;
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_add && return
	[ ! -z "$message" ] && echo "$message" > "$path" \
	  && echo "$new_id created." && return
	if [ $verbose == true ]; then
		if [ -z $(command -v vim) ]; then
			echo "No vim, just simply."
		else
			vim $path
			[ -f "$path" ] && echo "$new_id created."
			return
		fi
	fi
	echo "Any stuff, please (ctrl-d end, ctrl-c cancel):"
	[ $in_shell == true ] && trap "echo; return" INT
	input=$(cat)  #save keyin until eof
	if [ -z `echo $input | tr -d '[:space:]'` ]; then  #empty check
		echo "Nothing!"
		return
	fi
	echo "$input" > "$path"
	echo "$new_id created."
}

#=== MOVE =====================================================================
function usage_move {  #heredoc
	cat<<-EOF
usage: gtd <move-command> [options...] <id or alias>
  move-command
    to-todo,      tt
    to-wait,      tw
    to-project,   tp
    to-log,       tl
    to-reference, tr
    to-someday,   ts
    to-trash
	EOF
}

function move() {  #$1=target dir, $2=path
	[ -z "$2" ] && echo "not_found" && return
	dir=$(dirname $2)
	[ $dir == $1 ] && echo already && return
	mv "$2" "$1"
}

function move_stuff() { #$1=target dir
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	target=$1
	target_base=$(basename $1)

	shift  #skip $1 to other args
	TEMP=`getopt -o vh --long verbose,help -n 'gtd.move' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	items=""
	while : ; do
		case "$1" in
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; items="$1"; break;;  #no option args!
		*) echo "Unknown option: $1"; return;;
		esac
	done
	if [ $to_help == true ]; then
		[ $target_base == trash ] && usage_remove || usage_move
		return
	fi
	[ -z "$items" ] && echo "No item specified." && return
	IFS="," read -r -a item_array <<< "$items"
	for item in "${item_array[@]}"; do
		path=$(get_file "$item")
		case "$(move "$target" "$path")" in
		not_found) echo "$item not found.";;
		already)
			case "$target_base" in
			inbox) echo "$item is already in the inbox.";;
			todo) echo "$item is already in the todo list.";;
			wait) echo "$item is already in the waiting list.";;
			project) echo "$item is already a project.";;
			log) echo "$item is already a log.";;
			reference) echo "$item is already a reference.";;
			someday) echo "$item is already for someday-maybe.";;
			trash) echo "$item is already in the trash."
				printf "Permanently remove it? "
				read y_n
				case "$y_n" in
				y|Y|yes|Yes|YES) rm -f $path
					echo "$item was permanently removed.";;
				esac;;
			esac;;
		*)
			case "$target_base" in
			inbox) echo "$item was moved into the inbox.";;
			todo) echo "$item was moved into the todo list.";;
			wait) echo "$item was moved into the waiting list.";;
			project) echo "$item was turned to a project.";;
			log) echo "$item was turned to a log.";;
			reference) echo "$item was turned to a reference.";;
			someday) echo "$item is for someday-maybe now.";;
			trash) echo "$item was removed to trash."
			esac;;
		esac
	done
}

#=== REMOVE ===================================================================
function usage_remove {  #heredoc
	cat<<-EOF
usage: gtd <remove-command> [options...] <id or alias>
  remove-command(with the same meaning): remove, delete, rm, del, to-trash
	EOF
}

function empty_trash() { rm -rI "$GTD_TRASH"/*; }

#=== EDIT =====================================================================
function usage_edit {  #heredoc
	cat<<-EOF
usage: gtd edit [options...] <id or alias>
  options:
    -h, --help
    -e, --editor
	EOF
}

function edit_stuff() {
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	TEMP=`getopt -o he: --long help,editor: -n 'gtd.edit' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	item=""
	editor="vim"
	while : ; do
		case "$1" in
		-e|--editor) editor=$2; shift 2;;
		-h|--help) to_help=true; shift;;
		--) shift; item="$1"; break;;  #no option args!
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_edit && return
	[ -z $editor ] && echo "No editor specified." && return
	[ -z $(command -v $editor) ] && echo "No $editor found." && return
	path=$(get_file $item)
	[ -z "$path" ] && echo "$item not found." && return
	$editor $path
}

#=== VIEW =====================================================================
function usage_view {  #heredoc
	cat<<-EOF
usage: gtd view [options...] <id or alias>
  options:
    -h, --help
    -v, --verbose
	EOF
}

function print_file_info() {  #$1 is format, $2 is path
	str=$1
	fn=$(basename "$2")
	IFS='.' read -ra PARTS <<< "$fn"  #split w/ Internal Field Separator
	str=$(echo "$str" | sed -r "s/%i/${PARTS[0]}/g")
	create_time=$(date --date="@${PARTS[1]}" "+%F %H:%M")
	str=$(echo "$str" | sed -r "s/%ct/$create_time/g")
	update_time="$(date "+%F %H:%M" -r "$2")"
	str=$(echo "$str" | sed -r "s/%ut/$update_time/g")
	echo "$str"
}

function view_stuff() {
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	TEMP=`getopt -o vh --long verbose,help -n 'gtd.view' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	item=""
	while : ; do
		case "$1" in
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; item="$1"; break;;  #no option args!
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_view && return
	path=$(get_file $item)
	[ -z "$path" ] && echo "$item not found." && return
	if [ $verbose == true ]; then
		if [ -z $(command -v view) ]; then  #check cmd 'view' exist
			echo "No 'view' command, just do simple view."
		else
			view $path
			return
		fi
	fi 
	print_file_info "[%i] created@%ct  updated@%ut" "$path"
	printf '%0.s-' $(seq 1 $(tput cols))  #print a separate line
  	cat "$path" 
}

#=== SET/UNSET ================================================================
function usage_set {  #heredoc
	cat<<-EOF
usage: gtd set [options] <items>
       gtd unset [options] <items>
  options:
    -a, --alias
    -c, --ctime
    -d, --due
    -e, --ext
    -o, --owner
    -p, --priority
    -s, --sensitivity
    -t, --tag
    -x, --context
	EOF
}

function set_stuff() {
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	TEMP=`getopt -o ha:x:d:o:p:s:t:e: \
	  --long help,alias:context:date:owner:priority:sensitivity:tag:ext: \
	  -n 'gtd.set' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"

	to_help=false
	ctime=""
	alias=""
	context=""
	due=""
	owner=""
	priority=""
	sensitivity=""
	tag=""
	ext="txt"
	item=""
	while : ; do
		case "$1" in
		-h|--help) to_help=true; shift;;
		-a|--alias) alias=$2; shift 2;;
		-c|--ctime) ctime=$2; shift 2;;
		-x|--context) context=$2; shift 2;;
		-d|--due) due=$2; shift 2;;
		-o|--owner) owner=$2; shift 2;;
		-p|--priority) priority=$2; shift 2;;
		-s|--sensitivity) sensitivity=$2; shift 2;;
		-t|--tag) tag=$2; shift 2;;
		-e|--ext) ext=$2; shift 2;;
		--) shift; item="$1"; break;;  #no option args!
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_set && return
	path=$(get_file $item)
	[ -z "$path" ] && echo "$item not found." && return
	dir=$(dirname "$path")
	fn=$(basename "$path")
	declare -a fn_arr=($(parse_fn "$fn"))
	echo ${fn_arr[@]}
	[ ! -z "$ctime" ] && fn_arr[1]="$(date -d"$ctime" +%s)"
	[ ! -z "$alias" ] && fn_arr[2]="-a.$alias"
	[ ! -z "$context" ] && fn_arr[3]="-x.$context"
	[ ! -z "$due" ] && fn_arr[4]="-d.$(date -d"$due" +%s)"
	[ ! -z "$owner" ] && fn_arr[5]="-o.$owner"
	[ ! -z "$priority" ] && fn_arr[6]="-p.$priority"
	[ ! -z "$sensitivity" ] && fn_arr[7]="-s.$sensitivity"
	[ ! -z "$tag" ] && fn_arr[8]="-t.$tag"
	[ ! -z "$ext" ] && fn_arr[9]="-e.$ext"
	new_fn="$(make_fn ${fn_arr[@]})"
	[ $new_fn != $fn ] && mv "$path" "$dir/$new_fn"
}

#=== LIST =====================================================================
function usage_list {  #heredoc
	cat<<-EOF
usage: gtd <list-command> [options...]
  list-command
    list,           l
    list-todo,      lt
    list-wait,      lw
    list-project,   lp
    list-log,       ll
    list-reference, lr
    list-someday,   ls
    list-trash
	EOF
}

function list_stuff() {  #$1=dir
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	dir=$1
	shift  #skip $1 to other args
	TEMP=`getopt -o vh --long verbose,help -n 'gtd.list' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	while : ; do
		case "$1" in
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; break;;
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_list && return
	for fn in $(ls "$dir/" | sort -n -t '.' -k 1); do
		path="$dir/$fn"
		if [ $verbose == true ]; then  #id, create/update time
			print_file_info "[%i] created@%ct  updated@%ut" "$path"
			echo "$(cat "$path")"  # and content
		else  #brief: just id and the 1st line
			echo -e "[$(get_id_from_fn "$fn")]\t" \
			  "$(head -n 1 "$path")"
		fi
	done
}

#=== INSTALL ==================================================================
function usage_install() {  #heredoc
	cat<<-EOF
usage: gtd install [options...]
  options
    no options                Install gtd.sh to /usr/local/bin/gtd
                                to make it a command.
                                (Need sudo permission probably)
    -h,       --help          Show this document.
    -p <dir>, --option=<dir>  Install portable gtd.sh to the specified directory.
	EOF
}

function install() {
	script_path="$0"
	destin_path=/usr/local/bin/gtd
	portable=false
	TEMP=`getopt -o hp: --long help,portable: -n 'gtd.install' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	while : ; do
		case "$1" in
		-h|--help) to_help=true; shift;;
		-p|--portable)
			[ ! -d "$2" ] && echo "Dir $2 not found." && return
			destin_path="$2"/gtd.sh
			portable=true
			shift 2;;
		--) shift; break;;
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_install && return
	if [ "$script_path" == "$destin_path" ]; then
		echo "You are already using the installed command."
		return
	fi
	if [ ! -f "$script_path" ]; then
		echo "I just can't locate the script at $0"
		exit 1
	fi
	cp -i $script_path $destin_path
	[ $portable == true ] && \
	  sed -i -e 's/^GTD_ROOT=.*$/GTD_ROOT="."/g' "$destin_path"
	  #replace GTD_ROOT="..." to GTD_ROOT=".", then it's portable.
}

#=== SHELL ====================================================================
function usage_shell() {  #heredoc
	cat<<-EOF
Shell-like environment, where you can run gtd commands without typing 'gtd'.
	EOF
}

in_shell=false
function process_command() {
	[ $# -eq 0 ] && usage && return 0  #No arg, show usage

	case "$1" in  #$1 is command
	init) shift; init "$@";;
	add|a) shift; add_stuff "$GTD_INBOX" "$@";;
	add-todo|at) shift; add_stuff "$GTD_TODO" "$@";;
	add-wait|aw) shift; add_stuff "$GTD_WAIT" "$@";;
	add-project|ap) shift; add_stuff "$GTD_PROJECT" "$@";;
	add-log|al) shift; add_stuff "$GTD_LOG" "$@";;
	add-reference|ar) shift; add_stuff "$GTD_REFERENCE" "$@";;
	add-someday|as) shift; add_stuff "$GTD_SOMEDAY" "$@";;
	to-inbox|ti) shift; move_stuff "$GTD_INBOX" "$@";;
	to-todo|tt) shift; move_stuff "$GTD_TODO" "$@";;
	to-wait|tw) shift; move_stuff "$GTD_WAIT" "$@";;
	to-project|tp) shift; move_stuff "$GTD_PROJECT" "$@";;
	to-log|tl) shift; move_stuff "$GTD_LOG" "$@";;
	to-reference|tr) shift; move_stuff "$GTD_REFERENCE" "$@";;
	to-someday|ts) shift; move_stuff "$GTD_SOMEDAY" "$@";;
	remove|rm|delete|del|to-trash) shift; move_stuff "$GTD_TRASH" "$@";;
	empty-trash) empty_trash;;
	list|l) shift; list_stuff "$GTD_INBOX" "$@";;
	list-todo|lt) shift; list_stuff "$GTD_TODO" "$@";;
	list-wait|lw) shift; list_stuff "$GTD_WAIT" "$@";;
	list-project|lp) shift; list_stuff "$GTD_PROJECT" "$@";;
	list-log|ll) shift; list_stuff "$GTD_LOG" "$@";;
	list-reference|lr) shift; list_stuff "$GTD_REFERENCE" "$@";;
	list-someday|ls) shift; list_stuff "$GTD_SOMEDAY" "$@";;
	list-trash) shift; list_stuff $GTD_TRASH "$@";;
	view|v) shift; view_stuff "$@";;
	edit|e) shift; edit_stuff "$@";;
	set|s) shift; set_stuff "$@";;
	install) shift; install "$@";;
	uninstall) echo "Please just manually remove $INSTALL_DEST."
		echo "You data is in $GTD_ROOT, take care of it.";;
	shell) [ $in_shell == false ] && gtd_shell "$@"\
	  || echo "We are already in gtd shell.";;
	exit) [ $in_shell == true ] && in_shell=false \
	  || echo "exit is a gtd shell command.";;
	help|-h|--help|-\?) usage;;
	version) echo "0.01 2016-10-10 paulo.dx@gmail.com";;
	*) echo "Incorrect command: $1"; usage;;
	esac
	return 0
}

function gtd_shell() {
	shift  #bypass 'shell'
	TEMP=`getopt -o h --long help -n 'gtd.shell' -- "$@"`
	[ $? != 0 ] && echo "Failed parsing the arguments." && return
	eval set -- "$TEMP"
	to_help=false
	while : ; do
		case "$1" in
		-h|--help) to_help=true; shift;;
		--) shift; break;;
		*) echo "Unknown option: $1"; return;;
		esac
	done
	[ $to_help == true ] && usage_shell && return

	in_shell=true
	while : ; do  # infinite loop
		printf "gtd~ "
		read args
		eval set -- "$args"
		process_command "$@"
		[ $in_shell == false ] && break
	done
}

#=== MAIN =====================================================================
[ -z $(command -v getopt) ] && echo "No getopt command." && exit 1
process_command "$@"  #only "$@" can trans things properly, $@/$*/"$*" can't.
