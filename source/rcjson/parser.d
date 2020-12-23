module rcjson.parser;

import std.range;
import std.traits;
import std.format;
import std.algorithm;
import std.exception;

import rcjson.misc;

/// Struct for parsing JSON.
struct JSONParser {

    /// Type of a JSON value
    enum Type {

        null_,
        boolean,
        number,
        string,
        array,
        object

    }

    /// Input taken by the parser.
    ForwardRange!dchar input;

    /// Current line number.
    size_t lineNumber = 1;

    @disable this();

    /// Start parsing using the given object, converting it to an InputRange.
    this(T)(T input)
    if (isForwardRange!T) {

        this.input = input.inputRangeObject;

    }

    /// Check the next type in the document.
    /// Returns: Type of the object.
    Type peekType() {

        skipSpace();

        // Nothing left
        if (input.empty) {

            throw new Exception("Unexpected end of file.");

        }

        with (Type)
        switch (input.front) {

            // Valid types
            case 'n': return null_;

            case 't':
            case 'f': return boolean;

            case '-':
            case '0':
                ..
            case '9': return number;

            case '"': return string;

            case '[': return array;
            case '{': return object;

            // Errors
            case ']':
            case '}':

                throw new Exception(
                    failMsg(input.front.format!"Unexpected '%s' (maybe there's a comma before it?)")
                );

            // Other errors
            default:

                throw new Exception(
                    failMsg(input.front.format!"Unexpected character '%s'")
                );

        }

    }

    /// Expect the next value to be null and skip to the next value.
    ///
    /// Despite the name, this function doesn't return.
    ///
    /// Throws: `JSONException` if the next item isn't a null.
    void getNull() {

        skipSpace();

        // Check the values
        enforce!JSONException(input.skipOver("null"), failFoundMsg("Expected null"));

    }

    /// Get a boolean and skip to the next value.
    /// Throws: `JSONException` if the next item isn't a boolean.
    /// Returns: The parsed boolean.
    bool getBoolean() {

        skipSpace();

        // Check the values
        if (input.skipOver("true")) return true;
        else if (input.skipOver("false")) return false;

        // Or fail
        else throw new JSONException(failFoundMsg("Expected boolean"));

    }

    /// Get the next number.
    ///
    /// The number will be verified according to the JSON spec, but is parsed using std. Because of this, you can
    /// request a string return value, in order to perform manual conversion if needed.
    ///
    /// Implementation note: If the number contains an uppercase E, it will be converted to lowercase.
    ///
    /// Params:
    ///     T = Type of the returned number, eg. `int` or `real`. Can also be a `string` type, if conversion should be
    ///         done manually, or the number is expected to be big.
    /// Throws: `JSONException` if the next item isn't a number.
    /// Returns: The matched number.
    T getNumber(T)()
    if (isNumeric!T || isSomeString!T) {

        skipSpace();

        // Match the string
        dstring number = input.skipOver("-") ? "-" : "";

        /// Push the current character, plus following digits, to the result string.
        /// Returns: Length of the matched string.
        size_t pushDigit() {

            size_t length;

            do {
                number ~= input.front;
                input.popFront;
                length++;
            }
            while (!input.empty && '0' <= input.front && input.front <= '9');

            return length;

        }

        // Check the first digit
        enforce!JSONException(!input.empty && '0' <= input.front && input.front <= '9',
            failFoundMsg("Expected number"));

        // Parse integer part
        const leadingZero = input.front == '0';
        const digits = pushDigit();

        // Check for leading zeros
        enforce!JSONException(!leadingZero || digits == 1,
                failMsg("Numbers cannot have leading zeros, found"));

        // Fractal part
        if (!input.empty && input.front == '.') pushDigit();

        // Exponent
        if (!input.empty && (input.front == 'e' || input.front == 'E')) {

            // Add the E
            number ~= 'e';
            input.popFront;

            // EOF?
            enforce!JSONException(!input.empty, "Unexpected EOF in exponent");

            // Check for sign
            if (input.front == '-' || input.front == '+') {
                number ~= input.front;
                input.popFront;
            }

            // Push the numbers
            // RFC 8259 actually allows leading zeros here
            enforce!JSONException(
                '0' <= input.front && input.front <= '9',
                failMsg(input.front.format!"Unexpected character '%s' in exponent")
            );

            // Push the digits
            pushDigit();

        }

        import std.conv : to;
        return number.to!T;

    }

    /// Skips over line breaks and advances line count.
    /// Returns: Matched line breaks.
    private dstring getLineBreaks() {

        import std.stdio : writeln;

        dstring match = "";

        /// Last matched separator
        dchar lineSep;

        loop: while (!input.empty)
        switch (input.front) {

            case '\n', '\r':

                // Match the next character
                match ~= input.front;

                // Using the same separator, or this is the first one
                if (lineSep == input.front || lineSep == dchar.init) {

                    // Advance line count
                    lineNumber++;

                }

                // Encountered a different one? Most likely CRLF, so we shouldn't count the LF.

                // Update the lineSep char
                lineSep = input.front;

                // Pop the character
                input.popFront();

                // Continue parsing
                continue;

            default: break loop;

        }

        // Return the match
        return match;

    }

    /// Skip whitespace in the document.
    private void skipSpace() {

        // RFC: See section 2.

        // Skip an indefinite amount
        while (!input.empty)
        switch (input.front) {

            // Line feed
            case '\n', '\r':

                // Skip over
                getLineBreaks();
                continue;

            // Remove whitespace
            case ' ', '\t':
                input.popFront();
                continue;

            // Stop on anything else
            default:
                return;

        }

    }

    /// Get array elements by iterating over them.
    /// Throws: `JSONException` if the next item isn't an array.
    /// Returns: A generator range yielding current array index.
    auto getArray() {

        import std.concurrency : Generator, yield;

        skipSpace();

        // Expect an array opening
        enforce!JSONException(input.skipOver("["), failFoundMsg("Expected array"));

        return new Generator!size_t({

            size_t index;

            // Skip over space
            skipSpace();

            // Check the contents
            while (!input.skipOver("]")) {

                // Require a comma after non-zero indexes
                enforce!JSONException(
                    !index || input.skipOver(","),
                    failMsg("Expected a comma between array elements")
                );

                // Expect an item
                yield(index++);

            }

        });

    }

    /// Fail with given message and include a line number.
    private string failMsg(string msg) {

        throw new JSONException(
            msg.format!"%s on line %s"(lineNumber)
        );

    }

    /// Fail with the given message and output the given message, including the next word in the input range.
    pragma(inline, true);
    private string failFoundMsg(string msg) {

        skipSpace();

        return failMsg(msg.format!"%s, found %s"(peekType));

    }

}

///
unittest {

    auto json = JSONParser(q{
        [
            "hello",
            "world",
            true,
            123,
            {
                "undefined": null,
                "int": 123,
                "negative": -123,
                "float": 123.213
            }
        ]
    });

    // Type validation
    assert(json.getBoolean.collectExceptionMsg == "Expected boolean, found array on line 2");

    // Checking types early
    assert(json.peekType == JSONParser.Type.array);

    /* foreach (index; json.getArray) { */

    /* } */

}

unittest {

    foreach (num; [
        "0",
        "123",
        "123.123",
        "-123",
        "-3",
        "-3.123",
        "0.123e2",
        "0.123e-2",
        "0.123e-2",
        "0.0123e-2",
    ]) {

        import std.conv : to;
        import std.string : toLower;

        auto res1 = JSONParser(num).getNumber!real;
        assert(res1 == num.to!real, format!`Number "%s" is parsed into a wrong number value, "%s"`(num, res1));

        auto res2 = JSONParser(num).getNumber!string;
        assert(res2 == num.toLower, format!`Number "%s" changes string value to "%s"`(num, res2));

    }

    // Invalid cases
    foreach (num; [
        "0123",
        "+123",
        "- 123",
        // Those will not fail instantly, requie checking next value
        // "123e123.123"
        // "123 123"
    ]) {

        assertThrown(JSONParser(num).getNumber!string,
            num.format!`Number "%s" is invalid, but doesn't throw when parsed`);

    }

}

unittest {

    import std.array : array;

    auto json = JSONParser("[false true]");

    assert(
        json.getArray.map!(i => json.getBoolean).array.collectExceptionMsg
        == "Expected a comma between array elements on line 1"
    );

}
