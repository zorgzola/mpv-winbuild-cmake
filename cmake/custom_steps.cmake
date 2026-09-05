function(cleanup _name _last_step)
    get_property(_build_in_source TARGET ${_name} PROPERTY _EP_BUILD_IN_SOURCE)
    get_property(_git_repository TARGET ${_name} PROPERTY _EP_GIT_REPOSITORY)
    get_property(_url TARGET ${_name} PROPERTY _EP_URL)
    get_property(git_tag TARGET ${_name} PROPERTY _EP_GIT_TAG)
    get_property(git_remote_name TARGET ${_name} PROPERTY _EP_GIT_REMOTE_NAME)
    get_property(stamp_dir TARGET ${_name} PROPERTY _EP_STAMP_DIR)
    get_property(source_dir TARGET ${_name} PROPERTY _EP_SOURCE_DIR)

    if("${git_remote_name}" STREQUAL "" AND NOT "${git_tag}" STREQUAL "")
        # GIT_REMOTE_NAME is not set when commit hash is specified
        set(git_tag "")
    else()
        set(git_tag "@{u}")
    endif()

    if(_git_repository)
        if(_build_in_source)
            set(remove_cmd "git -C <SOURCE_DIR> clean -dfx")
        else()
            set(remove_cmd "find <BINARY_DIR> -mindepth 1 -delete && git -C <SOURCE_DIR> clean -df")
        endif()
        set(COMMAND_FORCE_UPDATE COMMAND bash -c "test -d <SOURCE_DIR>/.git && git -C <SOURCE_DIR> am --abort 2> /dev/null || true"
                                 COMMAND ${stamp_dir}/reset_head.sh
                                 COMMAND bash -c "test -d <SOURCE_DIR>/.git && git -C <SOURCE_DIR> restore . || true")
    endif()

    # <STAMP_DIR> doesn't resolve into full path, so <LOG_DIR> is used instead since its same folder.
    ExternalProject_Add_Step(${_name} fullclean
        COMMAND ${EXEC} find <LOG_DIR> -type f " ! -iname '*.cmake' " -size 0c -delete # remove 0 byte files which are stamp files
        ${COMMAND_FORCE_UPDATE}
        ALWAYS TRUE
        EXCLUDE_FROM_MAIN TRUE
        INDEPENDENT TRUE
        LOG 1
        COMMENT "Deleting all stamp files of ${_name} package"
    )

    ExternalProject_Add_Step(${_name} liteclean
        COMMAND ${EXEC} rm -f <LOG_DIR>/${_name}-build
                              <LOG_DIR>/${_name}-install
        ALWAYS TRUE
        EXCLUDE_FROM_MAIN TRUE
        INDEPENDENT TRUE
        LOG 1
        COMMENT "Deleting build, install stamp files of ${_name} package"
    )

    ExternalProject_Add_Step(${_name} postremovebuild
        DEPENDEES ${_last_step}
        COMMAND ${EXEC} ${remove_cmd}
        ${COMMAND_FORCE_UPDATE}
        LOG 1
        COMMENT "Deleting build directory of ${_name} package after install"
    )

    ExternalProject_Add_Step(${_name} removebuild
        DEPENDEES fullclean
        COMMAND ${EXEC} ${remove_cmd}
        ALWAYS TRUE
        EXCLUDE_FROM_MAIN TRUE
        INDEPENDENT TRUE
        LOG 1
        COMMENT "Deleting build directory of ${_name} package"
    )

    ExternalProject_Add_Step(${_name} removeprefix
        COMMAND ${EXEC} rm -rf <INSTALL_DIR> ${source_dir}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target rebuild_cache
        ALWAYS TRUE
        EXCLUDE_FROM_MAIN TRUE
        INDEPENDENT TRUE
        LOG 1
        COMMENT "Deleting everything about ${_name} package"
    )
    ExternalProject_Add_StepTargets(${_name} fullclean liteclean removeprefix removebuild)
endfunction()

function(force_rebuild_git _name)
    get_property(git_tag TARGET ${_name} PROPERTY _EP_GIT_TAG)
    get_property(git_reset TARGET ${_name} PROPERTY _EP_GIT_RESET)
    get_property(git_remote_name TARGET ${_name} PROPERTY _EP_GIT_REMOTE_NAME)
    get_property(stamp_dir TARGET ${_name} PROPERTY _EP_STAMP_DIR)
    get_property(source_dir TARGET ${_name} PROPERTY _EP_SOURCE_DIR)

    if("${git_remote_name}" STREQUAL "" AND NOT "${git_tag}" STREQUAL "")
        # GIT_REMOTE_NAME is not set when commit hash is specified
        set(reset "")
    elseif(NOT "${git_reset}" STREQUAL "")
        set(reset "${git_reset}")
    else()
        set(reset "@{u}") # eg: origin/master
    endif()

    # Wipe the stamps (and the broken checkout) of a package whose source dir
    # lost its .git — e.g. a clone interrupted mid-download. Without this,
    # plain `git`/`git -C <src>` walks up the directory tree and operates on
    # the *workspace* repository instead (fetching wrong remotes, resetting
    # unrelated HEADs). Clearing the download stamp makes the next build
    # re-clone from scratch.
    set(GIT_GUARD "
if [[ ! -d \"${source_dir}/.git\" ]]; then
    echo \"WARN: ${source_dir} is not a git repo (broken download); wiping ${_name} stamps to force re-clone\" >&2
    find \"${stamp_dir}\" -type f ! -iname '*.cmake' -size 0c -delete
    rm -f \"${stamp_dir}/${_name}-gitclone-lastrun.txt\" \"${stamp_dir}/HEAD\"
    cd /
    rm -rf \"${source_dir}\"
    exit 0
fi
")

file(WRITE ${stamp_dir}/reset_head.sh
"#!/bin/bash
set -e
${GIT_GUARD}
if [[ ! -f \"${stamp_dir}/${_name}-patch\"  || \"${stamp_dir}/${_name}-download\" -nt \"${stamp_dir}/${_name}-patch\" || ! -f \"${stamp_dir}/HEAD\" || \"$(cat ${stamp_dir}/HEAD)\" != \"$(git -C ${source_dir} rev-parse @{u})\" ]]; then
    git -C ${source_dir} reset --hard ${reset} -q
    if [[ -z \"${git_reset}\" ]]; then
        find \"${stamp_dir}\" -type f  ! -iname '*.cmake' -size 0c -delete
        echo \"Removing ${_name} stamp files.\"
        git -C ${source_dir} rev-parse HEAD > ${stamp_dir}/HEAD
    fi
else
    git -C ${source_dir} reset --hard -q
fi")
file(CHMOD ${stamp_dir}/reset_head.sh
PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

file(WRITE ${stamp_dir}/force_update.sh
"#!/bin/bash
set -e
${GIT_GUARD}cd \"${source_dir}\"
git am --abort 2> /dev/null || true
git fetch --filter=tree:0 --no-recurse-submodules || true
exec bash \"${stamp_dir}/reset_head.sh\"")
file(CHMOD ${stamp_dir}/force_update.sh
PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

    ExternalProject_Add_Step(${_name} force-update
        ALWAYS TRUE
        EXCLUDE_FROM_MAIN TRUE
        INDEPENDENT TRUE
        COMMAND ${stamp_dir}/force_update.sh
    )
    ExternalProject_Add_StepTargets(${_name} force-update)

    ExternalProject_Add_Step(${_name} write-head
        DEPENDERS patch
        INDEPENDENT TRUE
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMAND bash -c "git rev-parse HEAD > ${stamp_dir}/HEAD"
        LOG 1
    )

    if(EXISTS ${source_dir}/.git)
        ExternalProject_Add_Step(${_name} check-git
            DEPENDERS download
            INDEPENDENT TRUE
            WORKING_DIRECTORY ${stamp_dir}
            COMMAND ${CMAKE_COMMAND} -E touch <INSTALL_DIR>/src/${_name}-stamp/${_name}-download
            COMMAND ${CMAKE_COMMAND} -E copy ${_name}-gitinfo.txt ${_name}-gitclone-lastrun.txt
            LOG 1
        )
    else()
        # Source tree is gone (src_packages is never cached) but its stamps may
        # have been restored from the toolchain cache claiming the download is
        # done. Drop the whole download chain so ninja re-runs the clone;
        # otherwise configure fires against a non-existent source dir.
        execute_process(
            WORKING_DIRECTORY ${stamp_dir}
            COMMAND ${EXEC} rm -f ${_name}-gitclone-lastrun.txt ${_name}-download ${_name}-update ${_name}-patch ${_name}-mkdir HEAD
            ERROR_QUIET
        )
    endif()
endfunction()

function(force_rebuild_svn _name)
    ExternalProject_Add_Step(${_name} force-update
        DEPENDEES download update
        DEPENDERS patch build install
        COMMAND svn revert -R .
        COMMAND svn up
        WORKING_DIRECTORY <SOURCE_DIR>
        LOG 1
    )
endfunction()

function(force_rebuild_hg _name)
    ExternalProject_Add_Step(${_name} force-update
        DEPENDEES download update
        DEPENDERS patch build install
        COMMAND hg --config "extensions.purge=" purge --all
        COMMAND hg update -C
        WORKING_DIRECTORY <SOURCE_DIR>
        LOG 1
    )
endfunction()

function(force_meson_configure _name)
    ExternalProject_Add_Step(${_name} force-meson-configure
        DEPENDERS configure
        COMMAND ${EXEC} rm -rf <BINARY_DIR>/meson-*
        LOG 1
    )
endfunction()
