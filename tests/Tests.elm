module Tests exposing (..)

import Expect
import Json.Decode
import Json.Encode
import Json.InElm
import Test exposing (Test)


suite : Test
suite =
    Test.todo "Implement the first test. See https://package.elm-lang.org/packages/elm-explorations/test/latest for how to do this!"


nx : Test
nx =
    Test.todo <| Debug.toString <| Json.InElm.parseJsonString glossaryJson


decodeEncodeString : Test
decodeEncodeString =
    (Debug.toString >> Test.todo) <|
        (Json.Decode.decodeString Json.Decode.value objectWithStringFields
            |> Result.map (Json.Encode.encode 2)
        )


objectWithStringFields : String
objectWithStringFields =
    Json.Encode.object
        [ ( "filename", Json.Encode.string "test.txt" )
        , ( "filetype", Json.Encode.string "textfile" )
        ]
        |> Json.Encode.encode 2


runtimeDecoder : Test
runtimeDecoder =
    Test.describe "runtimeDecoder tests"
        [ Test.test "runtimeDecoder should be able to, given a KeyPath and JType, successfully decode a different value than the one that the KeyPath and JType were initially derived from" <|
            \_ ->
                let
                    objJson : String -> Json.Encode.Value
                    objJson filename =
                        Json.Encode.object
                            [ ( "filename", Json.Encode.string filename )
                            ]

                    keyPath : Json.InElm.KeyPath
                    keyPath =
                        Json.InElm.initKeyPath
                            |> Json.InElm.at "filename"

                    eval : Result Json.Decode.Error Json.InElm.JValue
                    eval =
                        Json.InElm.runtimeDecoder keyPath Json.InElm.TString <| objJson "file2.txt"
                in
                Expect.equal eval <|
                    Ok (Json.InElm.JString "file2.txt")
        ]



-- examples from json.org


glossaryJson : String
glossaryJson =
    """
{
    "glossary": {
        "title": "example glossary",
\t\t"GlossDiv": {
            "title": "S",
\t\t\t"GlossList": {
                "GlossEntry": {
                    "ID": "SGML",
\t\t\t\t\t"SortAs": "SGML",
\t\t\t\t\t"GlossTerm": "Standard Generalized Markup Language",
\t\t\t\t\t"Acronym": "SGML",
\t\t\t\t\t"Abbrev": "ISO 8879:1986",
\t\t\t\t\t"GlossDef": {
                        "para": "A meta-markup language, used to create markup languages such as DocBook.",
\t\t\t\t\t\t"GlossSeeAlso": ["GML", "XML"]
                    },
\t\t\t\t\t"GlossSee": "markup"
                }
            }
        }
    }
}
    """
