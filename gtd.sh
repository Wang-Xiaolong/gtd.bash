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

debug=false
function debug() {
	if [ $debug == true ]; then
		>&2 echo "$@"
	fi  #can't be 1-line fmt - cause the func return [ $debug == true ]
}

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
	[ $to_help = true ] && usage_init && return
	check_and_make_dirs
}

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

function add_stuff() {  #$1=dir
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	new_id=$(($(get_max_id) + 1))
	path="$1/$new_id.$(date +%s)"
	shift  #skip $1 to other args
	TEMP=`getopt -o m:vh --long message:,verbose,help -n 'gtd' -- "$@"`
	[ $? != 0 ] && echo "Failed" && return
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
		*) echo "Unknown parameter $1"; return;;
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
Usage: gtd <move-command> [options...] <id or alias>
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

function get_file_in_dir() {  #$1 is path, $2 is id or alias
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
	TEMP=`getopt -o vh --long verbose,help -n 'gtd' -- "$@"`
	[ $? != 0 ] && echo "Failed" && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	items=""
	while : ; do
		case "$1" in
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; items="$1"; break;;  #no option args!
		*) echo "Unknown parameter $1"; return;;
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
Usage: gtd <remove-command> [options...] <id or alias>
  remove-command(with the same meaning): remove, delete, rm, del, to-trash
	EOF
}

function empty_trash() { rm -rI "$GTD_TRASH"/*; }

#=== EDIT =====================================================================
function edit_stuff() {  #$1 is id or alias
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	path=$(get_file $1)
	[ -z "$path" ] && echo "$1 not found." && return
	if [ -z $(command -v vim) ]; then
		echo "No vim, can't edit $1."
		return
	fi
	vim $path
}

#=== VIEW =====================================================================
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

function view_stuff() {  #$1 is id or alias
	[ $(check_dirs) == false ] && echo "$NO_DIR" && return
	path=$(get_file $1)
	[ -z "$path" ] && echo "$1 not found." && return
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

#=== LIST =====================================================================
function usage_list {  #heredoc
	cat<<-EOF
Usage: gtd <list-command> [options...]
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
	TEMP=`getopt -o vh --long verbose,help -n 'gtd' -- "$@"`
	[ $? != 0 ] && echo "Failed" && return
	eval set -- "$TEMP"
	to_help=false
	verbose=false
	while : ; do
		case "$1" in
		-v|--verbose) verbose=true; shift;;
		-h|--help) to_help=true; shift;;
		--) shift; break;;
		*) echo "Unknown parameter $1"; return;;
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
Install gtd.sh to /usr/local/bin to make it a command.
Only to be used with the script that's not installed.
(I mean you can't install 'gtd' command with 'gtd' command).
Usually need sudo or root permission.
	EOF
}

INSTALL_DEST=/usr/local/bin/gtd

function install() {
	[ $to_help == true ] && usage_install && return
	debug "cmd=$0"
	if [ "$0" == "$INSTALL_DEST" ]; then
		echo "You are already using the installed command."
		return
	fi
	if [ ! -f "$0" ]; then
		echo "I just can't locate the script at $0"
		exit 1
	fi
	cp -i $0 $INSTALL_DEST
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

	for arg in "$@"; do  #general flag: debug/version
		case $arg in
		--debug) debug=true;;
		--version) echo "0.01 2016-10-10 paulo.dx@gmail.com"
			return 0;;
		esac
	done

	case "$1" in  #$1 is command
	init) init;;
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
	view|v) view_stuff $2;;
	edit|e) edit_stuff $2;;
	install) install;;
	uninstall) echo "Please just manually remove $INSTALL_DEST."
		echo "You data is in $GTD_ROOT, take care of it.";;
	shell) [ $in_shell == false ] && gtd_shell \
	  || echo "We are already in gtd shell.";;
	exit) [ $in_shell == true ] && in_shell=false \
	  || echo "exit is a gtd shell command.";;
	help|-h|--help|-\?) usage;;
	*) echo "Incorrect command: $1"; usage;;
	esac
	return 0
}

function gtd_shell() {
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
