#!/bin/zsh

__import "core/core"
__import "print/print"

get_head_branch_name() {
    local head_branch

    if __git_version 1.7.10; then
        head_branch="$(git symbolic-ref -q --short HEAD)"
    else
        head_branch="${$(git symbolic-ref -q HEAD)#refs/heads/}"
    fi

    if [[ -z $head_branch ]]; then
        git rev-parse --short HEAD
        return 1
    fi
    __put "$head_branch\n"
}
get_remote_name() {
    local branch remote_name
    branch="$1"

    if [[ -z $branch ]]; then
        __die "too few arguments\n"
        return 1
    fi

    remote_name="$(git config branch.${branch}.remote)"
    if [[ -z $remote_name ]]; then
        __die "no remote repository\n"
        return 1
    fi

    __put "$remote_name\n"
}

__get_remote_state() {
    local    remote_name branch
    local    merge_branch remote_show
    local    state url
    local -a behind_ahead
    local -i behind ahead

    branch="$1"
    remote_name="$(get_remote_name "$branch")"

    if (( $status == 0 )); then
        merge_branch="${$(git config branch.${branch}.merge)#refs/heads/}"
        remote_show="$(git remote show "$remote_name")"
        state="$(grep "^ *$branch *pushes" <<<"$remote_show" | sed 's/.*(\(.*\)).*/\1/')"

        if [[ -z $state ]]; then
            behind_ahead=( ${(@f)"$(git rev-list \
                --left-right \
                --count \
                "$remote_name/$merge_branch"...$branch)"} )
            behind=$behind_ahead[1]
            ahead=$behind_ahead[2]

            if (( $behind > 0 )); then
                state="local out of date"
            else
                origin_head="${$(git ls-remote origin HEAD)[1]}"
                if ! git rev-parse -q "$origin_head" &>/dev/null; then
                    state="local out of date"
                elif (( $ahead > 0 )); then
                    state="fast-forwardable"
                else
                    state="up to date"
                fi
            fi
        fi

        url="$(grep '^ *Push' <<<"$remote_show" | sed 's/^.*URL: \(.*\)$/\1/')"
    else
        state="$remote_name"
    fi

    echo "$state"
    echo "$url"
}

__get_state() {
    local    branch
    local -a res
    local    state url

    if [[ ! -e .git ]]; then
        state="not git repo"
    fi

    branch="$(get_head_branch_name)"
    if (( $status == 0 )); then
        res=( ${(@f)"$(__get_remote_state "$branch")"} )
        state="$res[1]"
        url="$res[2]"
    else
        state="not on any branch"
    fi

    case "$state" in
        "local out of date")
            state="${fg[red]}${state}${reset_color}"
            ;;
        "up to date")
            state="${fg[green]}${state}${reset_color}"
            ;;
    esac
    __put "($state) '${url:-?}'\n"
}