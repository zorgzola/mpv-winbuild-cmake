get_property(src_asio_sdk TARGET asio-sdk PROPERTY _EP_SOURCE_DIR)
get_property(src_orender TARGET orender PROPERTY _EP_SOURCE_DIR)

# Apply the mpv-omniphony patch series (orender spatial audio, ASIO output,
# built-in spatial overlay, ...) on top of upstream mpv master, then commit
# the result. Committing matters: reset_head.sh (force-update / postremove-
# build) runs `git reset --hard` on this tree between builds, which silently
# drops uncommitted patches while the patch stamp survives — producing an
# upstream mpv without any omniphony feature. The commit marker also makes
# this idempotent: after a no-op reset the script detects the applied state
# and skips. git apply --3way needs the base blobs, hence the full
# (unfiltered) clone below.
set(APPLY_MPV_OMNI ${CMAKE_CURRENT_BINARY_DIR}/apply-mpv-omni-patches.sh)
file(WRITE ${APPLY_MPV_OMNI}
"#!/bin/bash
set -e
shopt -s nullglob
cd \$1
if git log -1 --format=%s 2>/dev/null | grep -q mpv-omniphony; then
    echo \"mpv-omniphony patches already applied, nothing to do\"
    exit 0
fi
patches=(\$2/mpv-omni-*.patch)
if [[ \${#patches[@]} -eq 0 ]]; then
    echo \"ERROR: no mpv-omni-*.patch found in \$2\" >&2
    exit 1
fi
echo \"Applying \${#patches[@]} mpv-omni patches\"
for p in \"\${patches[@]}\"; do
    echo \">> \$(basename \$p)\"
    git apply --3way \"\$p\"
done
git add -A
git commit -q --no-verify -m \"mpv-omniphony: apply orender spatial audio / ASIO / overlay patch series\"
echo \"All mpv-omni patches applied and committed\"")

ExternalProject_Add(mpv
    DEPENDS
        angle-headers
        asio-sdk
        orender
        ffmpeg
        fribidi
        lcms2
        libarchive
        libass
        libdvdnav
        libdvdread
        libiconv
        libjpeg
        libpng
        luajit
        rubberband
        uchardet
        openal-soft
        mujs
        vulkan
        shaderc
        libplacebo
        spirv-cross
        vapoursynth
        libsdl2
        subrandr
        libsixel
        curl
    GIT_REPOSITORY https://github.com/mpv-player/mpv.git
    SOURCE_DIR ${SOURCE_LOCATION}
    UPDATE_COMMAND ""
    PATCH_COMMAND ${EXEC} bash ${APPLY_MPV_OMNI} <SOURCE_DIR> ${CMAKE_CURRENT_SOURCE_DIR}
    CONFIGURE_COMMAND ${EXEC} CONF=1 meson setup <BINARY_DIR> <SOURCE_DIR>
        --prefix=${MINGW_INSTALL_PREFIX}
        --libdir=${MINGW_INSTALL_PREFIX}/lib
        --cross-file=${MESON_CROSS}
        --default-library=shared
        --prefer-static
        -Ddebug=true
        -Db_ndebug=true
        -Doptimization=3
        -Db_lto=true
        ${mpv_lto_mode}
        -Dlibmpv=true
        -Dpdf-build=enabled
        -Dlua=enabled
        -Djavascript=enabled
        -Dsdl2-gamepad=enabled
        -Dlibarchive=enabled
        -Dlibbluray=enabled
        -Dorender=enabled
        -Dasio=enabled
        -Dasio-sdk=${src_asio_sdk}
        -Ddvdnav=enabled
        -Duchardet=enabled
        -Drubberband=enabled
        -Dlcms2=enabled
        -Dopenal=enabled
        -Dspirv-cross=enabled
        -Dvulkan=enabled
        -Dvapoursynth=enabled
        -Dsubrandr=enabled
        -Dsixel=enabled
        ${mpv_gl}
        -Dlibcurl=enabled
        -Dc_args='-Wno-error=int-conversion'
    BUILD_COMMAND ${EXEC} LTO_JOB=1 PDB=1 ninja -C <BINARY_DIR>
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

ExternalProject_Add_Step(mpv strip-binary
    DEPENDEES build
    ${mpv_add_debuglink}
    COMMENT "Stripping mpv binaries"
)

ExternalProject_Add_Step(mpv copy-binary
    DEPENDEES strip-binary
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.exe                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.exe
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.com                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.com
    # orender.dll is dlopen'ed by ad_orender at runtime (ORENDER_LIB_NAME),
    # never linked — ship it next to mpv.exe so spatial audio works out of
    # the box.
    COMMAND ${CMAKE_COMMAND} -E copy ${src_orender}/omniphony-renderer/target/${TARGET_CPU}-pc-windows-${rust_target}/release/orender.dll ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/orender.dll
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/etc/mpv-register.bat              ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv-register.bat
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/etc/mpv-unregister.bat            ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv-unregister.bat
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.pdf                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/doc/manual.pdf
    COMMAND ${CMAKE_COMMAND} -E copy ${MINGW_INSTALL_PREFIX}/etc/fonts/fonts.conf   ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv/fonts.conf
    # BD-J jars. Ship the prebuilt jars in packages/bdj instead of the ones
    # built from upstream libbluray 1.5.1: they carry the on-demand VFSCache
    # (accessFileImp) chain needed for directory-based BD-J resources (e.g.
    # Top Gun's BDMV/JAR/00001/) that AppCache does not cover. Verified
    # against our statically linked libbluray (JNI-compatible, run34 test).
    # libbluray is statically linked into mpv.exe, so its runtime jar search
    # starts from the module paths (dl_get_path) = mpv.exe's directory.
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/bdj/libbluray-j2se-1.5.1.jar     ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/libbluray-j2se-1.5.1.jar
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/bdj/libbluray-awt-j2se-1.5.1.jar ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/libbluray-awt-j2se-1.5.1.jar
    ${mpv_copy_debug}
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv-2.dll          ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv-2.dll
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv.dll.a          ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv.dll.a
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/client.h       ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/client.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/stream_cb.h    ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/stream_cb.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render.h       ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render_gl.h    ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render_gl.h
    COMMENT "Copying mpv binaries and manual"
)

set(RENAME ${CMAKE_CURRENT_BINARY_DIR}/mpv-prefix/src/rename.sh)
file(WRITE ${RENAME}
"#!/bin/bash
cd $1
GIT=$(git rev-parse --short=10 HEAD)
mv $2 $2-git-\${GIT}")

ExternalProject_Add_Step(mpv copy-package-dir
    DEPENDEES copy-binary
    COMMAND chmod 755 ${RENAME}
    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-package ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-debug ${CMAKE_BINARY_DIR}/mpv-debug-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-debug-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMENT "Moving mpv package folder"
    LOG 1
)

force_rebuild_git(mpv)
force_meson_configure(mpv)
cleanup(mpv copy-package-dir)
