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

#=== INIT =====================================================================
debug=false
function debug() {
	[ $debug == true ] && >&2 echo "$@"
}

showhelp=false
verbose=false

function check_and_make_dir() {  #make dir if not exist
	if [ ! -d "$1" ]; then
		echo "No $1, create it."
		mkdir "$1"
	fi
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

function get_id_from_fn() {  #light func just to get id, $1 is file base name
	id_str=$(echo "$1" | sed -e "s/\..*//g")  #remove chars after dots
	re='^[0-9]+$'  #check if id is num w/ regular expression
	if ! [[ $id_str =~ $re ]]; then
		echo "0"
	else
		echo "$id_str"
	fi
}

function get_max_id_in_dir() {
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

function add_stuff() {  #$1 is dir
	[ $showhelp == true ] && usage_add && return
	check_and_make_dirs
	new_id=$(($(get_max_id) + 1))
	path="$1/$new_id.$(date +%s)"
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
	input=$(cat)  #save keyin until eof
	if [ -z `echo $input | tr -d '[:space:]'` ]; then  #empty check
		echo "Nothing!"
		return
	fi
	echo "$input" > "$path"
	echo "$new_id created."
}

#=== REMOVE ===================================================================
function usage_remove {  #heredoc
	cat<<-EOF
Usage: gtd <remove-command> [options...] <id or alias>
  remove-command(with the same meaning): remove, delete, rm, del
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

function remove_stuff() { #$1 is id or alias
	[ $showhelp == true ] && usage_remove && return
	path=$(get_file $1)
	[ -z "$path" ] && echo "$1 not found." && return
	mv "$path" "$GTD_TRASH" && echo "$1 was removed to the Trash."
}

function empty_trash() { rm -rI $GTD_TRASH/*; }

#=== EDIT =====================================================================
function edit_stuff() {  #$1 is id or alias
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

function list_stuff() {  #$1 is dir
	[ $showhelp == true ] && usage_list && return
	check_and_make_dirs
	for fn in $(ls "$1/" | sort -n -t '.' -k 1); do
		path="$1/$fn"
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
	[ $showhelp == true ] && usage_install && return
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

function process_command() {
	[ $# -eq 0 ] && usage && return 0  #No arg, show usage

	for arg in "$@"; do  #general flag: --help/debug/version/verbose
		case $arg in
			--debug) debug=true;;
			--help|-h|-\?) showhelp=true;;
			--verbose|-v) verbose=true;;
			--version) echo "0.01 2016-10-10 paulo.dx@gmail.com"
				return 0;;
		esac
	done

	case "$1" in  #$1 is command
		add|a) add_stuff "$GTD_INBOX";;
		remove|rm|delete|del) remove_stuff $2;;
		empty-trash) empty_trash;;
		list|l) list_stuff $GTD_INBOX;;
		list-trash) list_stuff $GTD_TRASH;;
		view|v) view_stuff $2;;
		edit|e) edit_stuff $2;;
		install) install;;
		uninstall) echo "Please just manually remove $INSTALL_DEST."
			echo "You data is in $GTD_ROOT, take care of it.";;
		shell) gtd_shell;;
		help|-h|--help|-\?) usage;;
		*) echo "Incorrect command: $1"; usage;;
	esac
	return 0
}

function gtd_shell() {
	[ $showhelp == true ] && usage_shell && return
	while : ; do  # infinite loop
		printf "gtd~ "
		read args
		process_command $args
		(( $? != 0 )) && break			
	done
}

#=== MAIN =====================================================================
process_command $@
