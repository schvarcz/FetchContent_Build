# FetchContent_Build

Add this to your build: 

```cmake
include(FetchContent)

FetchContent_Declare(
  FetchContent_Build
  GIT_REPOSITORY git@github.com:schvarcz/FetchContent_Build.git
  GIT_TAG        master
)

FetchContent_Populate("FetchContent_Build")
FetchContent_GetProperties("FetchContent_Buil")
list(APPEND CMAKE_MODULE_PATH "${fetchcontent_build_SOURCE_DIR}/cmake-modules")

include(FetchNBuildContent)
```

Then you may use like:

```cmake

FetchContent_Declare(
  minimal-cmake
  GIT_REPOSITORY git@github.com:schvarcz/minimal-cmake.git
  GIT_TAG        master
  GIT_PROGRESS   true
)

FetchContent_Build(minimal-cmake)
# or
FetchContent_Install(minimal-cmake)
```