#!/bin/bash

set -e
PYPATH="`python -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()'`"
APPNAME=$(python setup.py --name)
APPVERSION=$(python setup.py --version)
DOWNLOAD_CACHE_DIR=/tmp/${APPNAME}-build-download-cache
PROJECT_DIR=$(pwd)
BUILD_DIR=$(mktemp -d)
VENV_DIR=$(mktemp -d)
OUTPUT_DIR="${PROJECT_DIR}/debs"
FPM_BIN="${BUILD_DIR}/bin/fpm -f"

debug(){
    echo
    echo "=====>  Debug console  <======"
    echo
    bash
}

handlerror(){
    echo "==========> ERROR <==========="
    debug
}

cleanup(){
    echo "Cleaning up"
    rm -rf "${VENV_DIR}"
    rm -rf "${BUILD_DIR}"
}

trap 'handlerror ${LINENO}' ERR
trap cleanup EXIT

#
# Setup
#

mkdir -p $OUTPUT_DIR

echo "Building sdist package"
python setup.py -q sdist

echo "Changing dir to ${BUILD_DIR}"
cd "${BUILD_DIR}"

virtualenv --setuptools --no-site-packages "${VENV_DIR}"

rsync -a ${PROJECT_DIR}/ .

mkdir -p ${DOWNLOAD_CACHE_DIR}

#
# Buildout
#

cat > buildout.cfg <<EOF
[buildout]
download-cache = ${DOWNLOAD_CACHE_DIR}
develop = .
parts =
    application
#    compilestatic
    fpm

[application]
recipe = zc.recipe.egg
interpreter = python
eggs =
    ${APPNAME}

[compilestatic]
recipe = plone.recipe.command
command = \${buildout:bin-directory}/hhcms2-compilestatic --basedir=src/hhcms2/static
eggs =
    \${application:eggs}

[fpm]
recipe = rubygemsrecipe
gems =
    fpm

EOF

echo "Generated buildout.cfg:"
echo
cat buildout.cfg

wget -O bootstrap.py http://downloads.buildout.org/2/bootstrap.py

${VENV_DIR}/bin/pip install 'setuptools>=0.7'
${VENV_DIR}/bin/python bootstrap.py
${VENV_DIR}/bin/python ./bin/buildout

#
# Dependencies
#

if ! echo $@| grep -q -- '--nodeps';then
    for path in $(ls -1d eggs/*|grep -v $APPNAME);do
        fullname=$(basename $path)
        version=$(echo $fullname|awk -F- '{print $2}')
        name=$(echo $fullname|awk -F- '{print $1}')
        $FPM_BIN -s python -t deb --python-install-lib="${PYPATH}" --python-install-bin=/usr/bin -v "$version" "$name"
    done
fi

$FPM_BIN -s python -t deb --python-install-lib="${PYPATH}" --python-install-bin=/usr/bin setup.py

#
# Static files package
#

# pushd src/hhcms2/static/
# $FPM_BIN -s dir -t deb --prefix=/usr/share/$APPNAME-static -n "${APPNAME}-static" -v "${APPVERSION}" .
# cp *.deb $OUTPUT_DIR/
# popd

#
# Application package
#

# pushd deploy
# $FPM_BIN -s dir -t deb -x '*.deb' -x postinst -n "${APPNAME}" -v "${APPVERSION}" \
#     --config-files=etc/hhcms2/hhcms2.conf \
#     --config-files=etc/hhcms2/legacy/common.rc \
#     --config-files=etc/hhcms2/legacy/db.rc \
#     --config-files=etc/hhcms2/legacy/log.rc \
#     --config-files=etc/hhcms2/legacy/uwsgi.conf \
#     --config-files=etc/hhcms2/legacy/webdav.rc \
#     --config-files=etc/init/hhcms2.conf \
#     --post-install postinst \
#     --depends "uwsgi-plugin-python" \
#     --depends "python-${APPNAME} = ${APPVERSION}" \
#     --depends "${APPNAME}-static = ${APPVERSION}" \
#     --deb-changelog=../CHANGES.txt \
#     .

# cp *.deb $OUTPUT_DIR/
# popd

cp *.deb $OUTPUT_DIR/

# cat <<EOF
# ==============================
# Build finished!
# Press CTRL-D to cleanup.
# EOF
