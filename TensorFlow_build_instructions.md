# TensorFlow Lite build

Once you've cross-compile TensorFlow with you're custom toolchains, you still have to compile the TensorFlow Lite from it. This is done by running the following command in the `tflite-build` folder:

``` bash
cmake --build . -j
```

Before doing it, you have to do some modifications to the code in `tfbuild`. This has to be done because the TensorFlow project use `glibc`, which is the GNU Project's implementation of the C standard library. Our system currently are under Alpine Linux distribution, which use `musl libc`, another implementation of the C standard library. They are some compatibility issues between those two implementations that must be fix before compiling.

In `tflite-build/flatbuffers/include/flatbuffers/util.h`: Replace the call to `strtoull_l` and `strtoll_l`, which are local variant of `strtoull` and `strtoll` that does not exist in `musl libc`, at lines 228 and 229 by:

```c
    #define __strtoull_impl(s, pe, b)  ({ \
        locale_t old = uselocale(ClassicLocale::Get()); \
        unsigned long long result = strtoull(s, pe, b); \
        uselocale(old); \
        result; \
    })
    #define __strtoll_impl(s, pe, b)  ({ \
        locale_t old = uselocale(ClassicLocale::Get()); \
        long long result = strtoll(s, pe, b); \
        uselocale(old); \
        result; \
    })
```

References:
- [Forum discussion about *_l() functions in musl libc](https://inbox.vuxu.org/musl/20201007193725.GX17637@brightrain.aerifal.cx/T/)
- [Musl libc strtoll and strtoull documentation](http://git.musl-libc.org/cgit/musl/tree/src/stdlib/strtol.c)
- [Glibc *_l() functions documentation](https://man.bsd.lv/DragonFly-5.6.1/man3/strtoll_l.3)
- [Uselocale documentation](https://man7.org/linux/man-pages/man3/uselocale.3.html)
