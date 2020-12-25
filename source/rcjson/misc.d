module rcjson.misc;

import std.exception;
version (unittest) import rcjson.parser;

/// UDA used to exclude struct fields from serialization.
enum JSONExclude;

///
unittest {

    struct Product {

        string name;
        float price;

        @JSONExclude {
            float weight;
            string weightUnit;
        }

    }

    auto json = JSONParser(q{
        {
            "name": "foo",
            "price": 123,
            "weight": "500g"
        }
    });

    auto product = json.getStruct!Product((ref Product obj, wstring key) {

        import std.conv : to ;
        import std.uni : isAlpha;
        import std.algorithm : countUntil;

        if (key == "weight") {

            const value = json.getString;
            const splitIndex = value.countUntil!isAlpha;

            // Extract the unit
            obj.weight = value[0..splitIndex].to!float;
            obj.weightUnit = value[splitIndex..$].to!string;
        }

    });

    assert(product.name == "foo");
    assert(product.price == 123);
    assert(product.weight == 500f);
    assert(product.weightUnit == "g");

}

/// Thrown if JSON parsing fails.
class JSONException : Exception {

    mixin basicExceptionCtors;

}
