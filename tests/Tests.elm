module Tests exposing (..)

import Expect
import Json.Decode
import Json.Encode
import Json.InElm
import Json.InElm.Codec
import Json.InElm.Keypath
import Test exposing (Test)


objectWithStringFields : String
objectWithStringFields =
    Json.Encode.object
        [ ( "filename", Json.Encode.string "test.txt" )
        , ( "filetype", Json.Encode.string "textfile" )
        ]
        |> Json.Encode.encode 2


parseValueAt : Test
parseValueAt =
    Test.describe "parseValueAt tests"
        [ Test.test "parseValueAt should be able to, given a Keypath and JType, successfully decode a different value than the one that the Keypath and JType were initially derived from" <|
            \_ ->
                let
                    objJson : String -> Json.Encode.Value
                    objJson filename =
                        Json.Encode.object
                            [ ( "filename", Json.Encode.string filename )
                            ]

                    keypath : Json.InElm.Keypath
                    keypath =
                        Json.InElm.Keypath.init
                            |> Json.InElm.Keypath.at "filename"

                    node : Result Json.Decode.Error Json.InElm.Node
                    node =
                        Json.InElm.parseValueAt keypath (objJson "file2.txt")
                in
                Expect.equal (Result.map .value node) <|
                    Ok (Json.InElm.JString "file2.txt")
        ]


keypathToString : Test
keypathToString =
    Test.describe "Json.InElm.Keypath.toString should convert a KeyPath to a string"
        [ Test.test "when it is empty" <|
            \_ ->
                Expect.equal (Json.InElm.Keypath.toString Json.InElm.Keypath.init) ""
        , Test.test "when it is all fields" <|
            \_ ->
                Expect.equal
                    (Json.InElm.Keypath.toString
                        (Json.InElm.Keypath.init
                            |> Json.InElm.Keypath.at "hello"
                            |> Json.InElm.Keypath.at "world"
                            |> Json.InElm.Keypath.at "how"
                            |> Json.InElm.Keypath.at "are"
                            |> Json.InElm.Keypath.at "you"
                        )
                    )
                    ".hello.world.how.are.you"
        , Test.test "when there is an index involved" <|
            \_ ->
                Expect.equal
                    (Json.InElm.Keypath.toString
                        (Json.InElm.Keypath.init
                            |> Json.InElm.Keypath.at "hello"
                            |> Json.InElm.Keypath.at "world"
                            |> Json.InElm.Keypath.at "how"
                            |> Json.InElm.Keypath.index 1
                            |> Json.InElm.Keypath.at "are"
                            |> Json.InElm.Keypath.at "you"
                        )
                    )
                    ".hello.world.how[1].are.you"
        , Test.test "when there is a single value in an index" <|
            \_ ->
                Expect.equal
                    (Json.InElm.Keypath.toString
                        (Json.InElm.Keypath.init
                            |> Json.InElm.Keypath.index 9
                        )
                    )
                    "[9]"
        ]


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


parseJsonString : Test
parseJsonString =
    let
        nodeResult : Result Json.Decode.Error Json.InElm.Node
        nodeResult =
            Json.InElm.parseJsonString rawJson

        objectResult : Result () (List ( String, Json.InElm.Node ))
        objectResult =
            Result.toMaybe nodeResult
                |> Maybe.andThen (.value >> Json.InElm.toObject)
                |> Result.fromMaybe ()
                |> Debug.log "readme output"

        objectFields : List String
        objectFields =
            Result.map (List.map Tuple.first) objectResult
                |> Result.withDefault []
    in
    Test.describe "Json.InElm.parseJsonString should parse a `String` of JSON data into a `Json.InElm.Node`"
        [ Test.test "and the initial parsing operation should work" <|
            \_ ->
                Expect.ok nodeResult
        , Test.test "and the output should be a `Node` with an empty `KeyPath`" <|
            \_ ->
                Result.map (.schema >> .keypath) nodeResult
                    |> Expect.equal (Ok Json.InElm.Keypath.init)
        , Test.test "and the `Node`'s `value` should have type `JObject`" <|
            \_ ->
                Expect.ok objectResult
        , Test.test "and the `Node`'s `JObject`'s fields are as expected" <|
            \_ ->
                Expect.equalLists objectFields [ "name", "age", "address", "friends" ]
        ]


toNodes : Test
toNodes =
    let
        unsafeNode : Json.InElm.Node
        unsafeNode =
            Json.InElm.parseJsonString rawJson
                |> accursedUnutterable
    in
    Test.describe "Json.InElm.toNodes should get all possible `Node`s from a given `Node`"
        [ Test.test "when the top-level `Node` is a `JObject`" <|
            \_ ->
                Json.InElm.toNodes unsafeNode
                    |> List.length
                    |> Expect.greaterThan 1
        ]


accursedUnutterable : Result x a -> a
accursedUnutterable =
    Result.map always
        >> Result.mapError (Debug.log "error from accursedUnutterable")
        >> Result.withDefault
            (\_ -> Debug.todo "")
        >> (\func -> func ())


codecSchema : Test
codecSchema =
    let
        keypath : Json.InElm.Keypath
        keypath =
            Json.InElm.Keypath.init
                |> Json.InElm.Keypath.at "hello"
                |> Json.InElm.Keypath.at "world"
                |> Json.InElm.Keypath.at "how"
                |> Json.InElm.Keypath.index 0
                |> Json.InElm.Keypath.at "are"
                |> Json.InElm.Keypath.at "you"

        jTag : Json.InElm.JTag
        jTag =
            Json.InElm.Structure Json.InElm.SObject

        baseValue : Json.InElm.Schema
        baseValue =
            { keypath = keypath
            , tag = jTag
            }
    in
    Test.describe "Json.InElm.Codec.schema should"
        [ Test.test "encode a Json.InElm.Schema to a JSON value" <|
            \_ ->
                Json.InElm.Codec.schema.encode baseValue
                    |> Json.Decode.decodeValue Json.InElm.Codec.schema.decoder
                    |> accursedUnutterable
                    |> Expect.equal baseValue
        ]
