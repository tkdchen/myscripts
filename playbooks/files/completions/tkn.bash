# bash completion for tkn                                  -*- shell-script -*-

__tkn_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__tkn_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__tkn_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__tkn_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__tkn_handle_go_custom_completion()
{
    __tkn_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly tkn allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __tkn_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __tkn_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __tkn_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __tkn_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __tkn_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __tkn_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __tkn_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __tkn_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __tkn_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subDir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __tkn_debug "Listing directories in $subdir"
            __tkn_handle_subdirs_in_dir_flag "$subdir"
        else
            __tkn_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__tkn_handle_reply()
{
    __tkn_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __tkn_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __tkn_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __tkn_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __tkn_custom_func >/dev/null; then
			# try command name qualified custom func
			__tkn_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__tkn_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__tkn_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__tkn_handle_flag()
{
    __tkn_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __tkn_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __tkn_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __tkn_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __tkn_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __tkn_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__tkn_handle_noun()
{
    __tkn_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __tkn_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __tkn_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__tkn_handle_command()
{
    __tkn_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_tkn_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __tkn_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__tkn_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __tkn_handle_reply
        return
    fi
    __tkn_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __tkn_handle_flag
    elif __tkn_contains_word "${words[c]}" "${commands[@]}"; then
        __tkn_handle_command
    elif [[ $c -eq 0 ]]; then
        __tkn_handle_command
    elif __tkn_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __tkn_handle_command
        else
            __tkn_handle_noun
        fi
    else
        __tkn_handle_noun
    fi
    __tkn_handle_word
}

_tkn_bundle_list()
{
    last_command="tkn_bundle_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--cache-dir=")
    two_word_flags+=("--cache-dir")
    local_nonpersistent_flags+=("--cache-dir")
    local_nonpersistent_flags+=("--cache-dir=")
    flags+=("--no-cache")
    local_nonpersistent_flags+=("--no-cache")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--remote-bearer=")
    two_word_flags+=("--remote-bearer")
    local_nonpersistent_flags+=("--remote-bearer")
    local_nonpersistent_flags+=("--remote-bearer=")
    flags+=("--remote-password=")
    two_word_flags+=("--remote-password")
    local_nonpersistent_flags+=("--remote-password")
    local_nonpersistent_flags+=("--remote-password=")
    flags+=("--remote-skip-tls")
    local_nonpersistent_flags+=("--remote-skip-tls")
    flags+=("--remote-username=")
    two_word_flags+=("--remote-username")
    local_nonpersistent_flags+=("--remote-username")
    local_nonpersistent_flags+=("--remote-username=")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_bundle_push()
{
    last_command="tkn_bundle_push"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--filenames=")
    two_word_flags+=("--filenames")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--filenames")
    local_nonpersistent_flags+=("--filenames=")
    local_nonpersistent_flags+=("-f")
    flags+=("--remote-bearer=")
    two_word_flags+=("--remote-bearer")
    local_nonpersistent_flags+=("--remote-bearer")
    local_nonpersistent_flags+=("--remote-bearer=")
    flags+=("--remote-password=")
    two_word_flags+=("--remote-password")
    local_nonpersistent_flags+=("--remote-password")
    local_nonpersistent_flags+=("--remote-password=")
    flags+=("--remote-skip-tls")
    local_nonpersistent_flags+=("--remote-skip-tls")
    flags+=("--remote-username=")
    two_word_flags+=("--remote-username")
    local_nonpersistent_flags+=("--remote-username")
    local_nonpersistent_flags+=("--remote-username=")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_bundle()
{
    last_command="tkn_bundle"

    command_aliases=()

    commands=()
    commands+=("list")
    commands+=("push")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_clustertask_create()
{
    last_command="tkn_clustertask_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from=")
    two_word_flags+=("--from")
    local_nonpersistent_flags+=("--from")
    local_nonpersistent_flags+=("--from=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertask_delete()
{
    last_command="tkn_clustertask_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--trs")
    local_nonpersistent_flags+=("--trs")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertask_describe()
{
    last_command="tkn_clustertask_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertask_list()
{
    last_command="tkn_clustertask_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_clustertask_logs()
{
    last_command="tkn_clustertask_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertask_start()
{
    last_command="tkn_clustertask_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--inputresource=")
    two_word_flags+=("--inputresource")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--inputresource")
    local_nonpersistent_flags+=("--inputresource=")
    local_nonpersistent_flags+=("-i")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--output=")
    two_word_flags+=("--output")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    flags+=("--outputresource=")
    two_word_flags+=("--outputresource")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outputresource")
    local_nonpersistent_flags+=("--outputresource=")
    local_nonpersistent_flags+=("-o")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--pod-template=")
    two_word_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template=")
    flags+=("--prefix-name=")
    two_word_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name=")
    flags+=("--serviceaccount=")
    two_word_flags+=("--serviceaccount")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--serviceaccount")
    local_nonpersistent_flags+=("--serviceaccount=")
    local_nonpersistent_flags+=("-s")
    flags+=("--showlog")
    local_nonpersistent_flags+=("--showlog")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--use-param-defaults")
    local_nonpersistent_flags+=("--use-param-defaults")
    flags+=("--use-taskrun=")
    two_word_flags+=("--use-taskrun")
    local_nonpersistent_flags+=("--use-taskrun")
    local_nonpersistent_flags+=("--use-taskrun=")
    flags+=("--workspace=")
    two_word_flags+=("--workspace")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workspace")
    local_nonpersistent_flags+=("--workspace=")
    local_nonpersistent_flags+=("-w")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertask()
{
    last_command="tkn_clustertask"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")
    commands+=("start")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_clustertriggerbinding_delete()
{
    last_command="tkn_clustertriggerbinding_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertriggerbinding_describe()
{
    last_command="tkn_clustertriggerbinding_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_clustertriggerbinding_list()
{
    last_command="tkn_clustertriggerbinding_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_clustertriggerbinding()
{
    last_command="tkn_clustertriggerbinding"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_completion()
{
    last_command="tkn_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_tkn_condition_delete()
{
    last_command="tkn_condition_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_condition_describe()
{
    last_command="tkn_condition_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_condition_list()
{
    last_command="tkn_condition_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_condition()
{
    last_command="tkn_condition"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_eventlistener_delete()
{
    last_command="tkn_eventlistener_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_eventlistener_describe()
{
    last_command="tkn_eventlistener_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_eventlistener_list()
{
    last_command="tkn_eventlistener_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_eventlistener_logs()
{
    last_command="tkn_eventlistener_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--tail=")
    two_word_flags+=("--tail")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--tail")
    local_nonpersistent_flags+=("--tail=")
    local_nonpersistent_flags+=("-t")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_eventlistener()
{
    last_command="tkn_eventlistener"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_help()
{
    last_command="tkn_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_hub_check-upgrade_task()
{
    last_command="tkn_hub_check-upgrade_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_check-upgrade()
{
    last_command="tkn_hub_check-upgrade"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_downgrade_task()
{
    last_command="tkn_hub_downgrade_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--to=")
    two_word_flags+=("--to")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_downgrade()
{
    last_command="tkn_hub_downgrade"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--to=")
    two_word_flags+=("--to")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_get_pipeline()
{
    last_command="tkn_hub_get_pipeline"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--version=")
    two_word_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_get_task()
{
    last_command="tkn_hub_get_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--as-clustertask")
    local_nonpersistent_flags+=("--as-clustertask")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--version=")
    two_word_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_get()
{
    last_command="tkn_hub_get"

    command_aliases=()

    commands=()
    commands+=("pipeline")
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_info_task()
{
    last_command="tkn_hub_info_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--version=")
    two_word_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_info()
{
    last_command="tkn_hub_info"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_install_task()
{
    last_command="tkn_hub_install_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--version=")
    two_word_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_install()
{
    last_command="tkn_hub_install"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_reinstall_task()
{
    last_command="tkn_hub_reinstall_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--version=")
    two_word_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_reinstall()
{
    last_command="tkn_hub_reinstall"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--from=")
    two_word_flags+=("--from")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--version=")
    two_word_flags+=("--version")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_search()
{
    last_command="tkn_hub_search"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--categories=")
    two_word_flags+=("--categories")
    local_nonpersistent_flags+=("--categories")
    local_nonpersistent_flags+=("--categories=")
    flags+=("--kinds=")
    two_word_flags+=("--kinds")
    local_nonpersistent_flags+=("--kinds")
    local_nonpersistent_flags+=("--kinds=")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--match=")
    two_word_flags+=("--match")
    local_nonpersistent_flags+=("--match")
    local_nonpersistent_flags+=("--match=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--platforms=")
    two_word_flags+=("--platforms")
    local_nonpersistent_flags+=("--platforms")
    local_nonpersistent_flags+=("--platforms=")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_upgrade_task()
{
    last_command="tkn_hub_upgrade_task"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--to=")
    two_word_flags+=("--to")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub_upgrade()
{
    last_command="tkn_hub_upgrade"

    command_aliases=()

    commands=()
    commands+=("task")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--to=")
    two_word_flags+=("--to")
    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_hub()
{
    last_command="tkn_hub"

    command_aliases=()

    commands=()
    commands+=("check-upgrade")
    commands+=("downgrade")
    commands+=("get")
    commands+=("info")
    commands+=("install")
    commands+=("reinstall")
    commands+=("search")
    commands+=("upgrade")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-server=")
    two_word_flags+=("--api-server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_pipeline_delete()
{
    last_command="tkn_pipeline_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--prs")
    local_nonpersistent_flags+=("--prs")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipeline_describe()
{
    last_command="tkn_pipeline_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipeline_list()
{
    last_command="tkn_pipeline_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_pipeline_logs()
{
    last_command="tkn_pipeline_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipeline_start()
{
    last_command="tkn_pipeline_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--filename=")
    two_word_flags+=("--filename")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--filename")
    local_nonpersistent_flags+=("--filename=")
    local_nonpersistent_flags+=("-f")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--output=")
    two_word_flags+=("--output")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--pod-template=")
    two_word_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template=")
    flags+=("--prefix-name=")
    two_word_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name=")
    flags+=("--resource=")
    two_word_flags+=("--resource")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--resource")
    local_nonpersistent_flags+=("--resource=")
    local_nonpersistent_flags+=("-r")
    flags+=("--serviceaccount=")
    two_word_flags+=("--serviceaccount")
    flags_with_completion+=("--serviceaccount")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tkn_handle_go_custom_completion")
    local_nonpersistent_flags+=("--serviceaccount")
    local_nonpersistent_flags+=("--serviceaccount=")
    local_nonpersistent_flags+=("-s")
    flags+=("--showlog")
    local_nonpersistent_flags+=("--showlog")
    flags+=("--task-serviceaccount=")
    two_word_flags+=("--task-serviceaccount")
    flags_with_completion+=("--task-serviceaccount")
    flags_completion+=("__tkn_handle_go_custom_completion")
    local_nonpersistent_flags+=("--task-serviceaccount")
    local_nonpersistent_flags+=("--task-serviceaccount=")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--use-param-defaults")
    local_nonpersistent_flags+=("--use-param-defaults")
    flags+=("--use-pipelinerun=")
    two_word_flags+=("--use-pipelinerun")
    flags_with_completion+=("--use-pipelinerun")
    flags_completion+=("__tkn_handle_go_custom_completion")
    local_nonpersistent_flags+=("--use-pipelinerun")
    local_nonpersistent_flags+=("--use-pipelinerun=")
    flags+=("--workspace=")
    two_word_flags+=("--workspace")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workspace")
    local_nonpersistent_flags+=("--workspace=")
    local_nonpersistent_flags+=("-w")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipeline()
{
    last_command="tkn_pipeline"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")
    commands+=("start")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_pipelinerun_cancel()
{
    last_command="tkn_pipelinerun_cancel"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipelinerun_delete()
{
    last_command="tkn_pipelinerun_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--ignore-running")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-running")
    local_nonpersistent_flags+=("-i")
    flags+=("--keep=")
    two_word_flags+=("--keep")
    local_nonpersistent_flags+=("--keep")
    local_nonpersistent_flags+=("--keep=")
    flags+=("--keep-since=")
    two_word_flags+=("--keep-since")
    local_nonpersistent_flags+=("--keep-since")
    local_nonpersistent_flags+=("--keep-since=")
    flags+=("--label=")
    two_word_flags+=("--label")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--pipeline=")
    two_word_flags+=("--pipeline")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--pipeline")
    local_nonpersistent_flags+=("--pipeline=")
    local_nonpersistent_flags+=("-p")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipelinerun_describe()
{
    last_command="tkn_pipelinerun_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--fzf")
    flags+=("-F")
    local_nonpersistent_flags+=("--fzf")
    local_nonpersistent_flags+=("-F")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipelinerun_list()
{
    last_command="tkn_pipelinerun_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--label=")
    two_word_flags+=("--label")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--reverse")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_pipelinerun_logs()
{
    last_command="tkn_pipelinerun_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--fzf")
    flags+=("-F")
    local_nonpersistent_flags+=("--fzf")
    local_nonpersistent_flags+=("-F")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--prefix")
    local_nonpersistent_flags+=("--prefix")
    flags+=("--task=")
    two_word_flags+=("--task")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--task")
    local_nonpersistent_flags+=("--task=")
    local_nonpersistent_flags+=("-t")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_pipelinerun()
{
    last_command="tkn_pipelinerun"

    command_aliases=()

    commands=()
    commands+=("cancel")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_resource_create()
{
    last_command="tkn_resource_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_resource_delete()
{
    last_command="tkn_resource_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_resource_describe()
{
    last_command="tkn_resource_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_resource_list()
{
    last_command="tkn_resource_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--type=")
    two_word_flags+=("--type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_resource()
{
    last_command="tkn_resource"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_task_create()
{
    last_command="tkn_task_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--from=")
    two_word_flags+=("--from")
    local_nonpersistent_flags+=("--from")
    local_nonpersistent_flags+=("--from=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_task_delete()
{
    last_command="tkn_task_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--trs")
    local_nonpersistent_flags+=("--trs")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_task_describe()
{
    last_command="tkn_task_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_task_list()
{
    last_command="tkn_task_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_task_logs()
{
    last_command="tkn_task_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_task_start()
{
    last_command="tkn_task_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--filename=")
    two_word_flags+=("--filename")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--filename")
    local_nonpersistent_flags+=("--filename=")
    local_nonpersistent_flags+=("-f")
    flags+=("--inputresource=")
    two_word_flags+=("--inputresource")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--inputresource")
    local_nonpersistent_flags+=("--inputresource=")
    local_nonpersistent_flags+=("-i")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    local_nonpersistent_flags+=("-l")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--output=")
    two_word_flags+=("--output")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    flags+=("--outputresource=")
    two_word_flags+=("--outputresource")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outputresource")
    local_nonpersistent_flags+=("--outputresource=")
    local_nonpersistent_flags+=("-o")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--pod-template=")
    two_word_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template")
    local_nonpersistent_flags+=("--pod-template=")
    flags+=("--prefix-name=")
    two_word_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name")
    local_nonpersistent_flags+=("--prefix-name=")
    flags+=("--serviceaccount=")
    two_word_flags+=("--serviceaccount")
    flags_with_completion+=("--serviceaccount")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tkn_handle_go_custom_completion")
    local_nonpersistent_flags+=("--serviceaccount")
    local_nonpersistent_flags+=("--serviceaccount=")
    local_nonpersistent_flags+=("-s")
    flags+=("--showlog")
    local_nonpersistent_flags+=("--showlog")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--use-param-defaults")
    local_nonpersistent_flags+=("--use-param-defaults")
    flags+=("--use-taskrun=")
    two_word_flags+=("--use-taskrun")
    flags_with_completion+=("--use-taskrun")
    flags_completion+=("__tkn_handle_go_custom_completion")
    local_nonpersistent_flags+=("--use-taskrun")
    local_nonpersistent_flags+=("--use-taskrun=")
    flags+=("--workspace=")
    two_word_flags+=("--workspace")
    two_word_flags+=("-w")
    local_nonpersistent_flags+=("--workspace")
    local_nonpersistent_flags+=("--workspace=")
    local_nonpersistent_flags+=("-w")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_task()
{
    last_command="tkn_task"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")
    commands+=("start")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_taskrun_cancel()
{
    last_command="tkn_taskrun_cancel"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_taskrun_delete()
{
    last_command="tkn_taskrun_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--clustertask=")
    two_word_flags+=("--clustertask")
    local_nonpersistent_flags+=("--clustertask")
    local_nonpersistent_flags+=("--clustertask=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--ignore-running")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-running")
    local_nonpersistent_flags+=("-i")
    flags+=("--keep=")
    two_word_flags+=("--keep")
    local_nonpersistent_flags+=("--keep")
    local_nonpersistent_flags+=("--keep=")
    flags+=("--keep-since=")
    two_word_flags+=("--keep-since")
    local_nonpersistent_flags+=("--keep-since")
    local_nonpersistent_flags+=("--keep-since=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--task=")
    two_word_flags+=("--task")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--task")
    local_nonpersistent_flags+=("--task=")
    local_nonpersistent_flags+=("-t")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_taskrun_describe()
{
    last_command="tkn_taskrun_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--fzf")
    flags+=("-F")
    local_nonpersistent_flags+=("--fzf")
    local_nonpersistent_flags+=("-F")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_taskrun_list()
{
    last_command="tkn_taskrun_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--label=")
    two_word_flags+=("--label")
    local_nonpersistent_flags+=("--label")
    local_nonpersistent_flags+=("--label=")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--reverse")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_taskrun_logs()
{
    last_command="tkn_taskrun_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--fzf")
    flags+=("-F")
    local_nonpersistent_flags+=("--fzf")
    local_nonpersistent_flags+=("-F")
    flags+=("--last")
    flags+=("-L")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-L")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--prefix")
    local_nonpersistent_flags+=("--prefix")
    flags+=("--step=")
    two_word_flags+=("--step")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--step")
    local_nonpersistent_flags+=("--step=")
    local_nonpersistent_flags+=("-s")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_taskrun()
{
    last_command="tkn_taskrun"

    command_aliases=()

    commands=()
    commands+=("cancel")
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("logs")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_triggerbinding_delete()
{
    last_command="tkn_triggerbinding_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_triggerbinding_describe()
{
    last_command="tkn_triggerbinding_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_triggerbinding_list()
{
    last_command="tkn_triggerbinding_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_triggerbinding()
{
    last_command="tkn_triggerbinding"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_triggertemplate_delete()
{
    last_command="tkn_triggertemplate_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_triggertemplate_describe()
{
    last_command="tkn_triggertemplate_describe"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tkn_triggertemplate_list()
{
    last_command="tkn_triggertemplate_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-namespaces")
    flags+=("-A")
    local_nonpersistent_flags+=("--all-namespaces")
    local_nonpersistent_flags+=("-A")
    flags+=("--allow-missing-template-keys")
    local_nonpersistent_flags+=("--allow-missing-template-keys")
    flags+=("--no-headers")
    local_nonpersistent_flags+=("--no-headers")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--show-managed-fields")
    local_nonpersistent_flags+=("--show-managed-fields")
    flags+=("--template=")
    two_word_flags+=("--template")
    flags_with_completion+=("--template")
    flags_completion+=("_filedir")
    local_nonpersistent_flags+=("--template")
    local_nonpersistent_flags+=("--template=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_triggertemplate()
{
    last_command="tkn_triggertemplate"

    command_aliases=()

    commands=()
    commands+=("delete")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="delete"
    fi
    commands+=("describe")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("desc")
        aliashash["desc"]="describe"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_version()
{
    last_command="tkn_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--check")
    local_nonpersistent_flags+=("--check")
    flags+=("--component=")
    two_word_flags+=("--component")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    flags+=("--context=")
    two_word_flags+=("--context")
    two_word_flags+=("-c")
    flags+=("--kubeconfig=")
    two_word_flags+=("--kubeconfig")
    two_word_flags+=("-k")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    flags_with_completion+=("--namespace")
    flags_completion+=("__tkn_handle_go_custom_completion")
    two_word_flags+=("-n")
    flags_with_completion+=("-n")
    flags_completion+=("__tkn_handle_go_custom_completion")
    flags+=("--no-color")
    flags+=("-C")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tkn_root_command()
{
    last_command="tkn"

    command_aliases=()

    commands=()
    commands+=("bundle")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("bundles")
        aliashash["bundles"]="bundle"
        command_aliases+=("tkb")
        aliashash["tkb"]="bundle"
    fi
    commands+=("clustertask")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("clustertasks")
        aliashash["clustertasks"]="clustertask"
        command_aliases+=("ct")
        aliashash["ct"]="clustertask"
    fi
    commands+=("clustertriggerbinding")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("clustertriggerbindings")
        aliashash["clustertriggerbindings"]="clustertriggerbinding"
        command_aliases+=("ctb")
        aliashash["ctb"]="clustertriggerbinding"
    fi
    commands+=("completion")
    commands+=("condition")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("cond")
        aliashash["cond"]="condition"
        command_aliases+=("conditions")
        aliashash["conditions"]="condition"
    fi
    commands+=("eventlistener")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("el")
        aliashash["el"]="eventlistener"
        command_aliases+=("eventlisteners")
        aliashash["eventlisteners"]="eventlistener"
    fi
    commands+=("help")
    commands+=("hub")
    commands+=("pipeline")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("p")
        aliashash["p"]="pipeline"
        command_aliases+=("pipelines")
        aliashash["pipelines"]="pipeline"
    fi
    commands+=("pipelinerun")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("pipelineruns")
        aliashash["pipelineruns"]="pipelinerun"
        command_aliases+=("pr")
        aliashash["pr"]="pipelinerun"
    fi
    commands+=("resource")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("res")
        aliashash["res"]="resource"
        command_aliases+=("resources")
        aliashash["resources"]="resource"
    fi
    commands+=("task")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("t")
        aliashash["t"]="task"
        command_aliases+=("tasks")
        aliashash["tasks"]="task"
    fi
    commands+=("taskrun")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("taskruns")
        aliashash["taskruns"]="taskrun"
        command_aliases+=("tr")
        aliashash["tr"]="taskrun"
    fi
    commands+=("triggerbinding")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("tb")
        aliashash["tb"]="triggerbinding"
        command_aliases+=("triggerbindings")
        aliashash["triggerbindings"]="triggerbinding"
    fi
    commands+=("triggertemplate")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("triggertemplates")
        aliashash["triggertemplates"]="triggertemplate"
        command_aliases+=("tt")
        aliashash["tt"]="triggertemplate"
    fi
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_tkn()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __tkn_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("tkn")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()
    local noun_aliases=()

    __tkn_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_tkn tkn
else
    complete -o default -o nospace -F __start_tkn tkn
fi

# ex: ts=4 sw=4 et filetype=sh
