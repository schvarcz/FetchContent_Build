FetchContent_GetProperties("FetchContent_Build")
list(APPEND CMAKE_MODULE_PATH "${fetchcontent_build_SOURCE_DIR}/cmake-modules")
include(FetchNBuildContent)