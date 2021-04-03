# rcjson

**Deprecated** in favor of [rcserial:json](https://github.com/Soaku/rcserial).

---

rcjson is a simple JSON pull parser written according to [RFC](https://tools.ietf.org/html/rfc8259).

## Why another?

* It's a pull parser, making it more flexible.
* Minimalistic, should be faster than `std.json`, but probably won't reach world records.
* Range-based and lazy.
* Boost licensed.
* May eventually implement serialization in a similar fashion.
