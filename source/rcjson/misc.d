module rcjson.misc;

import std.exception;

/// Thrown if JSON parsing fails.
class JSONException : Exception {

    mixin basicExceptionCtors;

}
