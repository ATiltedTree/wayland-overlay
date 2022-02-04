# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_REMOVE_MODULES_LIST=( FindFreetype )
LUA_COMPAT=( luajit )
PYTHON_COMPAT=( python3_{8..10} )

inherit cmake lua-single python-single-r1 xdg

OBS_BROWSER_COMMIT="2a338b7c76d5dd0a6b23f1d49affefd40213b0e9"
CEF_DIR="cef_binary_4280_linux64"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/PatTheMav/obs-studio.git"
	EGIT_BRANCH="universal-build"
	EGIT_SUBMODULES=( plugins/obs-browser )
else
	SRC_URI="https://github.com/obsproject/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	SRC_URI+=" browser? ( https://github.com/obsproject/obs-browser/archive/${OBS_BROWSER_COMMIT}.tar.gz -> obs-browser-${OBS_BROWSER_COMMIT}.tar.gz )"
	KEYWORDS="~amd64 ~ppc64 ~x86"
fi
SRC_URI+=" browser? ( https://cdn-fastly.obsproject.com/downloads/${CEF_DIR}.tar.bz2 )"

DESCRIPTION="Software for Recording and Streaming Live Video Content"
HOMEPAGE="https://obsproject.com"

LICENSE="GPL-2"
SLOT="0"
IUSE="
	X +alsa browser decklink fdk jack lua nvenc pipewire
	pulseaudio python speex +ssl truetype v4l vlc wayland
"
REQUIRED_USE="
	browser? ( X || ( alsa pulseaudio ) )
	lua? ( ${LUA_REQUIRED_USE} )
	python? ( ${PYTHON_REQUIRED_USE} )
"

BDEPEND="
	lua? ( dev-lang/swig )
	python? ( dev-lang/swig )
"
DEPEND="
	dev-libs/glib:2
	dev-libs/jansson:=
	dev-qt/qtcore:5
	dev-qt/qtdeclarative:5
	dev-qt/qtgui:5[wayland?]
	dev-qt/qtmultimedia:5
	dev-qt/qtnetwork:5
	dev-qt/qtsql:5
	dev-qt/qtsvg:5
	dev-qt/qtwidgets:5
	dev-qt/qtxml:5
	media-libs/libglvnd
	media-libs/x264:=
	media-video/ffmpeg:=[x264]
	net-misc/curl
	sys-apps/dbus
	sys-libs/zlib:=
	virtual/udev
	X? (
		x11-libs/libX11
		x11-libs/libXcomposite
		x11-libs/libXfixes
		x11-libs/libXinerama
		x11-libs/libXrandr
		x11-libs/libxcb:=
	)
	alsa? ( media-libs/alsa-lib )
	browser? (
		app-accessibility/at-spi2-atk
		app-accessibility/at-spi2-core:2
		dev-libs/atk
		dev-libs/expat
		dev-libs/glib
		dev-libs/nspr
		dev-libs/nss
		media-libs/alsa-lib
		media-libs/fontconfig
		media-libs/mesa[gbm(+)]
		net-print/cups
		x11-libs/libdrm
		x11-libs/libXScrnSaver
		x11-libs/libXcursor
		x11-libs/libXdamage
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXtst
	)
	fdk? ( media-libs/fdk-aac:= )
	jack? ( virtual/jack )
	lua? ( ${LUA_DEPS} )
	nvenc? ( >=media-video/ffmpeg-4[video_cards_nvidia] )
	pipewire? ( media-video/pipewire:= )
	pulseaudio? ( media-sound/pulseaudio )
	python? ( ${PYTHON_DEPS} )
	speex? ( media-libs/speexdsp )
	ssl? ( net-libs/mbedtls:= )
	truetype? (
		media-libs/fontconfig
		media-libs/freetype
	)
	v4l? ( media-libs/libv4l )
	vlc? ( media-video/vlc:= )
	wayland? ( dev-libs/wayland )
"
RDEPEND="${DEPEND}"

QA_PREBUILT="
	usr/lib*/obs-plugins/chrome-sandbox
	usr/lib*/obs-plugins/libEGL.so
	usr/lib*/obs-plugins/libGLESv2.so
	usr/lib*/obs-plugins/libcef.so
	usr/lib*/obs-plugins/swiftshader/libEGL.so
	usr/lib*/obs-plugins/swiftshader/libGLESv2.so
"

PATCHES=(
	"${FILESDIR}"/0001-fix-wayland.patch
	"${FILESDIR}"/0002-without-x.patch
	"${FILESDIR}"/0003-disable-browser-and-vst.patch
	"${FILESDIR}"/0004-fix-build-without-scripting.patch
	"${FILESDIR}"/0005-fix-rtmp.patch
)

pkg_setup() {
	use lua && lua-single_pkg_setup
	use python && python-single-r1_pkg_setup
}

src_unpack() {
	default

	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
	elif use browser; then
		rm -d ${P}/plugins/obs-browser || die
		mv obs-browser-${OBS_BROWSER_COMMIT} ${P}/plugins/obs-browser || die
	fi
}

src_configure() {
	local libdir=$(get_libdir)
	local mycmakeargs=(
		$(usev browser -DCEF_ROOT_DIR=../${CEF_DIR})
		-DENABLE_BROWSER_SOURCE=$(usex browser)
		-DENABLE_VST=no
		-DENABLE_AJA=no
		-DENABLE_WAYLAND=$(usex wayland)
		-DENABLE_X11=$(usex X)
		-DENABLE_ALSA=$(usex alsa)
		-DENABLE_DECKLINK=$(usex decklink)
		-DENABLE_FREETYPE=$(usex truetype)
		-DENABLE_JACK=$(usex jack)
		-DENABLE_LIBFDK=$(usex fdk)
		-DENABLE_PIPEWIRE=$(usex pipewire)
		-DENABLE_PULSEAUDIO=$(usex pulseaudio)
		-DENABLE_SPEEXDSP=$(usex speex)
		-DENABLE_V4L2=$(usex v4l)
		-DENABLE_VLC=$(usex vlc)
		-DENABLE_RTMPS=$(usex ssl)
	)

	if [[ ${PV} != 9999 ]]; then
		mycmakeargs+=(
			-DOBS_VERSION_OVERRIDE=${PV}
		)
	fi

	if use lua || use python; then
		mycmakeargs+=(
			-DENABLE_SCRIPTING_LUA=$(usex !lua)
			-DENABLE_SCRIPTING_PYTHON=$(usex !python)
			-DENABLE_SCRIPTING=yes
		)
	else
		mycmakeargs+=( -DENABLE_SCRIPTING=no )
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# external plugins may need some things not installed by default, install them here
	insinto /usr/include/obs/UI/obs-frontend-api
	doins UI/obs-frontend-api/obs-frontend-api.h
}

pkg_postinst() {
	xdg_pkg_postinst

	if ! use alsa && ! use pulseaudio; then
		elog
		elog "For the audio capture features to be available,"
		elog "either the 'alsa' or the 'pulseaudio' USE-flag needs to"
		elog "be enabled."
		elog
	fi

	if use python; then
		ewarn "This ebuild applies a patch that is not yet accepted upstream,"
		ewarn "and while it fixes Python support at least to some extent, it"
		ewarn "may cause other issues."
		ewarn ""
		ewarn "Please report any such issues to the Gentoo maintainer."
	fi
}
