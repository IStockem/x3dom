V ?= 0

SRC_DIR = src
TEST_DIR = test
TOOL_DIR = tools
DOC_DIR = doc

PREFIX = .
DIST_DIR = ${PREFIX}/dist

JS_ENGINE ?= `which node`
COMPILER = ${JS_ENGINE} ${TOOL_DIR}/uglify.js --unsafe

BASE_FILES = \
	${SRC_DIR}/lang/Array.js\
	${SRC_DIR}/x3dom-internals.js\
    ${SRC_DIR}/x3dmain.js\
	${SRC_DIR}/meta.js\
	${SRC_DIR}/debug.js\
	${SRC_DIR}/gfx_webgl.js\
	${SRC_DIR}/x3d.js\
    ${SRC_DIR}/mesh.js\
	${SRC_DIR}/x3d_follower.js\
	${SRC_DIR}/fields.js

MODULES = ${BASE_FILES}

HTML_INCLUDES = \
	<script type="text/javascript" src="../../src/lang/Array.js"></script> \
	<script type="text/javascript" src="../../src/x3dom-internals.js"></script> \
	<script type="text/javascript" src="../../src/x3dmain.js"></script> \
    <script type="text/javascript" src="../../src/debug.js"></script> \
	<script type="text/javascript" src="../../src/gfx_webgl.js"></script> \
	<script type="text/javascript" src="../../src/x3d.js"></script> \
	<script type="text/javascript" src="../../src/fields.js"></script> \

X3DOM = ${DIST_DIR}/x3dom.js
X3DOM_MIN = ${DIST_DIR}/x3dom.min.js

QUNIT_DIR = ${TEST_DIR}/qunit

X3DOM_VER = $(shell cat src/VERSION)
VER = sed "s/@VERSION/${X3DOM_VER}/"

DATE=$(shell git log -1 --pretty=format:%ad)

all: x3dom min lint
	@@echo "X3DOM build complete.

${DIST_DIR}:
	@@mkdir -p ${DIST_DIR}


ifeq ($(strip $(V)),0)
verbose = --quiet
else ifeq ($(strip $(V)),1)
verbose =
else
verbose = --verbose
endif

define clone_or_pull
-@@if test ! -d $(strip ${1})/.git; then \
		echo "Cloning $(strip ${1})..."; \
		git clone $(strip ${verbose}) --depth=1 $(strip ${2}) $(strip ${1}); \
	else \
		echo "Pulling $(strip ${1})..."; \
		git --git-dir=$(strip ${1})/.git pull $(strip ${verbose}) origin master; \
	fi
endef


${QUNIT_DIR}:
	$(call clone_or_pull, ${QUNIT_DIR}, git://github.com/jquery/qunit.git)

init: ${QUNIT_DIR}
x3dom: init ${X3DOM}
release: x3dom changelog


${X3DOM}: ${MODULES} | ${DIST_DIR}
	@@echo "Building" ${X3DOM}
	@@cat ${MODULES} | \
	sed 's/@DATE/'"${DATE}"'/' | \
	${VER} > ${X3DOM};


lint: x3dom
	@@if test ! -z ${JS_ENGINE}; then \
		echo "Checking X3DOM against JSLint..."; \
		${JS_ENGINE} ${TOOL_DIR}/jslint-check.js; \
	else \
		echo "You must have NodeJS installed in order to test X3DOM against JSLint."; \
	fi

min: ${X3DOM_MIN}

${X3DOM_MIN}: x3dom
	@@if test ! -z ${JS_ENGINE}; then \
		echo "Minifying X3DOM" ${X3DOM_MIN}; \
		${COMPILER} ${X3DOM} > ${X3DOM_MIN}.tmp; \
		sed '$ s#^\( \*/\)\(.\+\)#\1\n\2;#' ${X3DOM_MIN}.tmp > ${X3DOM_MIN}; \
		rm -rf ${X3DOM_MIN}.tmp; \
	else \
		echo "You must have NodeJS installed in order to minify X3DOM."; \
	fi

clean:
	@@echo "Removing Distribution directory:" ${DIST_DIR}
	@@rm -rf ${DIST_DIR}

	@@echo "Removing cloned directories"
	@@rm -rf test/qunit

	@@echo "Removing generated API documentation"
	@@rm -rf ${DOC_DIR}/api
	
runserver:
	@@echo "Running development server..."
	@@echo "Open your browser and visit http://localhost:8070/"
	python ${TOOL_DIR}/testserver.py

changelog:
	@@echo "Generating changelog this may take a while ..."
	@svn log --verbose --xml https://x3dom.svn.sourceforge.net/svnroot/x3dom/trunk | xsltproc --nowrite --nomkdir --nonet tools/svn2cl.xsl - > ChangeLog

docs:
	@@echo "Generating API documentation"
	@@if test ! -d "${DOC_DIR}/api"; then \
		mkdir ${DOC_DIR}/api; \
	fi
	${TOOL_DIR}/natural-docs/NaturalDocs -i ${SRC_DIR} -o HTML ${DOC_DIR}/api -p ${TOOL_DIR}/config
	
testrefresh:
	@@echo "Refreshing test cases header files."
	grep -rl '<!-- BEGIN:X3DOM -->' test/* | while read i; do ${TOOL_DIR}/sedml.sh $i "s/<!-- BEGIN:X3DOM -->.*<!-- END:X3DOM -->/<!-- BEGIN:X3DOM -->${HTML_INCLUDES}<!-- END:X3DOM -->/g" $i.tmp; done;
	
	
.PHONY: all x3dom lint min init changelog runserver docs refreshtests
