# FetchContent_Build

`FetchContent_Build` is a complementary tool for the built-in `FetchContent_Populate`.
Very often used as part of the dependency solving step on a CMake project.

This module extendes [FetchContent_Populate](https://cmake.org/cmake/help/latest/module/FetchContent.html) module to enable building and installing external projects.

As part of dependency solving step, a cmake project has to make an external project available in the local build folder.
Sometimes, the dependency may be solved just by having the project downloaded, compiled and installed in a temporary folder such as your build folder. 


In order to use `FecthContent_Build` and `FecthContent_Install` , add this snippet code to your `CMakeLists.txt`: 

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

Then you may use `FetchContent_Build` just like `FetchContent_Populate`:

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
- Set default install dir if not the declaration was made before the include
- Do a MakeAvailable decide if we should compile and/or install
- Find a way to not erase the source folder if you are starting a new build from scratch (maybe unsetting the url is the folder is not empty?)