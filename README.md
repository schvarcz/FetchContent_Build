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

include("${fetchcontent_build_SOURCE_DIR}/UpdateFetchContent.cmake")
```

Then you may use like:

```cmake

FetchContent_Declare(
  minimal-cmake
  GIT_REPOSITORY git@github.com:schvarcz/minimal-cmake.git
  GIT_TAG        master
  GIT_PROGRESS   true
)

FetchContent_Populate(minimal-cmake)
# or #
FetchContent_Build(minimal-cmake)
# or #
FetchContent_Install(minimal-cmake)
```

----
### Things to do

- Put populate to false if I build (so next populate will change the status of ExternalProject to not compile anymore)
- Do a MakeAvailable decide if we should compile and/or install
- Find a way to not erase the source folder if you are starting a new build from scratch (maybe unsetting the url is the folder is not empty?)