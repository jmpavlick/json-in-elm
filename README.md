# Json.InElm: JSON, _in_ Elm

If you are looking for a way to deserialize and serialize JSON values in Elm, this package might not be what you are looking for! If you've never read the docs for [elm/json](https://package.elm-lang.org/packages/elm/json/latest/), I suggest you go do that first.

Most of the time, your use-case for "doing JSON" looks something like this:

- I have an Elm type that I am using to represent something in my program
- I need to make a HTTP request, or handle an incoming value from a port
- I need a way to turn the JSON value that I get back from that operation, into a value of that Elm type that I have

For that, [elm/json](https://package.elm-lang.org/packages/elm/json/latest/) remains undefeated.

However, sometimes you don't know, need to know, or want to care about the JSON in your Elm program. Sometimes, you want to handle a JSON value by storing some kind of information about _the structure_ of that JSON value. For instance - what if you need to let your users map some value from an incoming webhook payload, to an input in your application? In that case, there's no possible way to know the incoming type of that payload at compile-time; and it's likely that your user doesn't care, either - they just want to map some field, of a given type, in a JSON document, to something else.

If that sounds like a situation that you need to handle, well, congratulations: this package is for you!

`Json.InElm` works by lifting any valid JSON document into a type, `Node`, that defines:

- The JSON path from the root of the document to a given field
- The type of that field
- The value of that field

## How to use it

``` elm
node : Result Json.Decode.Error Json.InElm.Node
node =
    Json.InElm.parseJsonString rawJwon

rawJson : String
rawJson =
    """
    {
        "name": "John",
        "age": 33,
        "address": {
            "city": "Davison",
            "country": "America"
    },
    "friends": [
        {
        "name": "Cakie",
        "hobbies": [ "plants", "fitness" ]
        },
        {
        "name": "Paulo",
        "hobbies": [ "BMX", "having a really great dog" ]
        }
    ]}
    """
```
