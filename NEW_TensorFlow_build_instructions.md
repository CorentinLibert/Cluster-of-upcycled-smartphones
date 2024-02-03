# Building Tensorflow Lite:

Here are the steps and modifications to do in order to build TensorFlow Lite for a armv7l device (32 bits) using musl libc.

1. Do modifications in tensorflow_src.
2. Compile tensorflow_src into tflite_build (with or without toolchain).
3. Do modifications in tflite_build.
4. Compile the project in tflite_build.

## In the folder tensorflow_src

Musl libc does not support `mallinfo()`, neither `mallinfo2()`. 

In `/tensorflow_src/tensorflow/lite/profiling/memory_info.cc`: Comment the code in the `#else` section around line 53 and add the following code instead:

```c
  result.total_allocated_bytes = -1;
  result.in_use_allocated_bytes = -1;
```

This is not a perfect fix, it would be better to not modify the code and define `__NO_MALLINFO__` instead. Since I'm not sure about where to define it, this will be done as a temporary solution. Another solution would be to use a similar function to get the same values but since it is not mandatory and it is not really important, let's just ignore it for now. 

References:
- [mallinfo documentation](https://man7.org/linux/man-pages/man3/mallinfo.3.html)
- [Forum discussion avout mallinfo() and mallinfo2()](https://www.openwall.com/lists/musl/2022/01/07/1)
- [getrusage() documentation](https://man7.org/linux/man-pages/man2/getrusage.2.html) to implement a possible solution.

## In the folder tflite_build

This has to be done because the TensorFlow project use `glibc`, which is the GNU Project's implementation of the C standard library. Our system currently are under Alpine Linux distribution, which use `musl libc`, another implementation of the C standard library. They are some compatibility issues between those two implementations that must be fix before compiling.

Comment following codes:

- In /flatbuffers/src/util.cpp: 394 ~ 413

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

- In /flatbuffers/include/flatbuffers/util.h: 205 ~ 233 and 243
```c
// clang-format off
// Use locale independent functions {strtod_l, strtof_l, strtoll_l, strtoull_l}.
// #if defined(FLATBUFFERS_LOCALE_INDEPENDENT) && (FLATBUFFERS_LOCALE_INDEPENDENT > 0)
//   class ClassicLocale {
//     #ifdef _MSC_VER
//       typedef _locale_t locale_type;
//     #else
//       typedef locale_t locale_type;  // POSIX.1-2008 locale_t type
//     #endif
//     ClassicLocale();
//     ~ClassicLocale();
//     locale_type locale_;
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

References:
- [Forum discussion about *_l() functions in musl libc](https://inbox.vuxu.org/musl/20201007193725.GX17637@brightrain.aerifal.cx/T/)
- [Musl libc strtoll and strtoull documentation](http://git.musl-libc.org/cgit/musl/tree/src/stdlib/strtol.c)
- [Glibc *_l() functions documentation](https://man.bsd.lv/DragonFly-5.6.1/man3/strtoll_l.3)
- [Uselocale documentation](https://man7.org/linux/man-pages/man3/uselocale.3.html)
- [Commented code](https://github.com/google/flatbuffers/issues/7587)


Then you have to 
