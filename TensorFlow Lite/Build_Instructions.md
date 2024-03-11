# TensorFlow Lite build instructions for ARMv7 Alpine devices

This file explains thoroughly how to cross-compile TensorFlow Lite from source. This as been done and verified on a Linux Ubuntu 22.04 LTS with a AMD64 processor.

The following tutorial make use of `Docker` using a `arm32v7/alpine` image and of `qemu` for the compatibility layer.

## Requirements

Some requirements are needed in order to cross-compile. 

- Install `git` if not done yet: `sudo apt update && sudo apt install git` 
- Install `docker` on your host computer ([see documentation](https://docs.docker.com/engine/install/ubuntu/)).
- Install the qemu layer: `sudo apt update && sudo apt install qemu-user-static`

## Cross-compilation setup

Let's now setup the cross-compilation project and environment. 

Create a the project folder to store all the files, for example:

```bash
mkdir tflite-crosscompilation && cd tflite-crosscompilation
```

Now create a `src` folder for all the source and compiled code:

```bash
mkdir src && cd src
```

Now let's clone the tensorflow git project. We will work on the last stable version (`v2.16.1`):

```bash
git clone --branch "v2.16.1" https://github.com/tensorflow/tensorflow.git tensorflow_src
```

Then create the CMAKE build directory:

```bash
mdkir tflite_build
```

Add the following Dockerfile in the project directory:

```dockerfile
# Start image from Alpine Linux
FROM arm32v7/alpine:latest

# Could add --no-cache to apk add, however you will have to download everything each time
RUN apk update && \
    apk add \ 
        bash \
        cmake \
        curl \
        g++ \
        gcc \
        libstdc++ \
        git \
        musl \
        musl-dev \
        make \
        zip

# ==================================
# Download TensorFlow and toolchain
# ==================================
# ENV TENSORFLOW_VERSION 2.15
ENV SRC_PATH /tensorflow/armv7l_build/src
ENV TOOLCHAIN_PATH ${SRC_PATH}/toolchains

VOLUME /src /src

WORKDIR ${SRC_PATH}
```

You're project structure should look like this:
/tflite-crosscompilation\
├─ Dockerfile\
└─ /src \
   ├─ /tensorflow_src \
   └─ /tflite_build

## Modifications in the source code (Before the first compilation)

TensorFlow is implemented based on `glibc`, an implementation of the standard C library, while `alpine` works with `musl libc`, another implementation of the standard C library. As a result, some function used in TensorFlow don't exist and are not recognize in the alpine distribution. We must remove or modify these function calls int the TensorFlow source code to ensure compatibility.

### Mallinfo()

Musl libc does not support `mallinfo()`, neither `mallinfo2()`. 

In `/tensorflow_src/tensorflow/lite/profiling/memory_info.cc`: Comment the code in the `#else` section around line 53 and add the following code instead:

```c
  result.total_allocated_bytes = -1;
  result.in_use_allocated_bytes = -1;
```

---
**_NOTE_**\
This is not a perfect fix, it would be better to not modify the code and define `__NO_MALLINFO__` instead. Since I'm not sure about where to define it, this will be done as a temporary solution. Another solution would be to use a similar function to get the same values but since it is not mandatory and it is not really important, let's just ignore it for now. 

---

### Missing include <cstdint.h> (for v2.16.1)

For a reason or another the include `<cstdint.h>` to be missing or not be done. This result in types `int32_t`and `int64_t`no being recognize.

Add `#include <cstdint.h` in files:
- `/tensorflow_src/tensorflow/lite/tools/command_line_flags.h` at line 22.
- `/tensorflow_src/third_party/xla/third_party/tsl/tsl/util/stats_calculator.h` at line 28.

## Docker and Compilation

Now that the setup is done and that the source code has been modified to solve compatibility issues, let's build the docker and run it to compile the code. 

From the root of the project directory, build the docker image:

```bash
docker build -t tf-image .
```

Then run the container in iteractive mode and mounting the volume for the correct platform:

```bash
docker run --platform linux/arm -it -v ./src:/tensorflow/armv7l_build/src tf-image
```

You will enter the container at path `/tensorflow/armv7l_build/src`. From there, go into the `tflite_build` folder:

```bash
cd tflite_build
```

Now you can build the **TensorFlow** project with the command:

```bash
cmake ../tensorflow_src/tensorflow/lite/
```

OR with the `ARMCC_FLAGS`:

```bash
cmake -DCMAKE_C_FLAGS="${ARMCC_FLAGS}" \
  -DCMAKE_CXX_FLAGS="${ARMCC_FLAGS}" \   -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
  ../tensorflow_src/tensorflow/lite/
```

## Modifications in the source code (After the first compilation)

Once the **TensorFlow** project has been cross-compiled into the `tflite_build` folder, we still have to perform some compatibility modifications before being able to compile **TensorFlow Lite**.

### Flatbuffers

There is some compatibility issues with the `flatbuffers` library. 

Commant the following codes:

- In `/flatbuffers/src/util.cpp`, around lines 394 ~ 413:

```c
// Locale-independent code.
// #if defined(FLATBUFFERS_LOCALE_INDEPENDENT) && \
//     (FLATBUFFERS_LOCALE_INDEPENDENT > 0)

// // clang-format off
// // Allocate locale instance at startup of application.
// ClassicLocale ClassicLocale::instance_;

// #ifdef _MSC_VER
//   ClassicLocale::ClassicLocale()
//     : locale_(_create_locale(LC_ALL, "C")) {}
//   ClassicLocale::~ClassicLocale() { _free_locale(locale_); }
// #else
//   ClassicLocale::ClassicLocale()
//     : locale_(newlocale(LC_ALL, "C", nullptr)) {}
//   ClassicLocale::~ClassicLocale() { freelocale(locale_); }
// #endif
// // clang-format on

// #endif  // !FLATBUFFERS_LOCALE_INDEPENDENT
```

- In `/flatbuffers/include/flatbuffers/util.h`, around lines 205 ~ 233 and line 243:
```c
// clang-format off
// Use locale independent functions {strtod_l, strtof_l, strtoll_l, strtoull_l}.
// #if defined(FLATBUFFERS_LOCALE_INDEPENDENT) && (FLATBUFFERS_LOCALE_INDEPENDENT > 0)
//   class ClassicLocale {
//     #ifdef _MSC_VERa **static library** `libtensorflow-lite.a` (in the `tflite_build` directory)
//     static ClassicLocale instance_;
//   public:
//     static locale_type Get() { return instance_.locale_; }
//   };

//   #ifdef _MSC_VER
//     #define __strtoull_impl(s, pe, b) _strtoui64_l(s, pe, b, ClassicLocale::Get())
//     #define __strtoll_impl(s, pe, b) _strtoi64_l(s, pe, b, ClassicLocale::Get())
//     #define __strtod_impl(s, pe) _strtod_l(s, pe, ClassicLocale::Get())
//     #define __strtof_impl(s, pe) _strtof_l(s, pe, ClassicLocale::Get())
//   #else
//     #define __strtoull_impl(s, pe, b) strtoull_l(s, pe, b, ClassicLocale::Get())
//     #define __strtoll_impl(s, pe, b) strtoll_l(s, pe, b, ClassicLocale::Get())
//     #define __strtod_impl(s, pe) strtod_l(s, pe, ClassicLocale::Get())
//     #define __strtof_impl(s, pe) strtof_l(s, pe, ClassicLocale::Get())
//   #endif
// #else
  #define __strtod_impl(s, pe) strtod(s, pe)
  #define __strtof_impl(s, pe) static_cast<float>(strtod(s, pe))
  #ifdef _MSC_VER
    #define __strtoull_impl(s, pe, b) _strtoui64(s, pe, b)
    #define __strtoll_impl(s, pe, b) _strtoi64(s, pe, b)
  #else
    #define __strtoull_impl(s, pe, b) strtoull(s, pe, b)
    #define __strtoll_impl(s, pe, b) strtoll(s, pe, b)
  #endif
// #endif
```


### Linux/futex.h (for v2.16.1)

The header `linux/futex.h` does not exist in `alpine` linux (i.e. using `musl libc`).

In the file `tflite_build/pthreadpool_source/src/pthreads.c`, at line 18, around:

```c++
#if defined(__linux__)
```

Add `&& !defined(_LIBCPP_HAS_MUSL_LIBC)`, so that it becomes:

```c++
#if defined(__linux__) && !defined(_LIBCPP_HAS_MUSL_LIBC)
```

## Compile TensorFlow Lite

Now that all compatibility modifications have been done, there should be no more issues. You can compile **TensorFlow Lite** to obtain a **static library** `libtensorflow-lite.a` (in the `tflite_build` directory). To do that, from the `tflite_build` directory run the command:

```bash
cmake --build . -j
```

---
**_WARNING:_**
The compilation of **TensorFlow Lite** may take a lot of time (**around 30 minutes to an hour**) ! Be patient.

---

### Compile the `label_image` example

If you want to compile the `label_image` example and obtain the `label_image` executable, from the `tflite_build` directory run the command:

```bash
cmake --build . -j -t label_image
```

You will still obtain the **static library** `libtensorflow-lite.a` (in the `tflite_build` directory), but also the `label_image` executable in the folder `tflite_build/examples/label_image`.

## References

### Mallinfo()
- [mallinfo documentation](https://man7.org/linux/man-pages/man3/mallinfo.3.html)
- [Forum discussion avout mallinfo() and mallinfo2()](https://www.openwall.com/lists/musl/2022/01/07/1)
- [getrusage() documentation](https://man7.org/linux/man-pages/man2/getrusage.2.html) to implement a possible solution.

### Missing include <cstdint.h>
- ['uint32_t' does not name a type](https://stackoverflow.com/questions/11069108/uint32-t-does-not-name-a-type)

### Linux/futex.h
- [[libc++] Do not use futex if LIBCXX_HAS_MUSL_LIBC is ON](https://reviews.llvm.org/D76632)

### Flatbuffers
- [Forum discussion about *_l() functions in musl libc](https://inbox.vuxu.org/musl/20201007193725.GX17637@brightrain.aerifal.cx/T/)
- [Musl libc strtoll and strtoull documentation](http://git.musl-libc.org/cgit/musl/tree/src/stdlib/strtol.c)
- [Glibc *_l() functions documentation](https://man.bsd.lv/DragonFly-5.6.1/man3/strtoll_l.3)
- [Uselocale documentation](https://man7.org/linux/man-pages/man3/uselocale.3.html)
- [Commented code](https://github.com/google/flatbuffers/issues/7587)