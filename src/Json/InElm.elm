module Json.InElm exposing
    ( JValue(..)
    , JProp(..)
    , JStructure(..)
    , Keypath
    , JTag(..)
    , Schema
    , Node
    , parseJsonString
    , parseValue
    , parseValueAt
    , toDecoder
    , toNodes
    , toString
    , toInt
    , toFloat
    , toBool
    , toTime
    , toList
    , toObject
    , toNull
    , view
    )

{-|


# JSON Document and Property Types

A "JSON document", here, is described as:

  - A JSON object
  - A list of JSON objects or scalar properties

For convenience, even though it's not in the JSON spec, I have included ISO8601 timestamp values as a "JSON property type".

@docs JValue
@docs JProp
@docs JStructure
@docs Keypath
@docs JTag
@docs Schema
@docs Node


# Parsing

@docs parseJsonString
@docs parseValue
@docs parseValueAt
@docs toDecoder


# Retrieving values from a `JValue`

@docs toNodes
@docs toString
@docs toInt
@docs toFloat
@docs toBool
@docs toTime
@docs toList
@docs toObject
@docs toNull


# Viewing a `Node`

@docs view

-}

import Dict
import Html
import Html.Events
import Iso8601
import Json.Decode
import Json.Encode
import Json.InElm.Internal
import Json.InElm.Keypath
import Json.InElm.Keypath.Internal
import Time



-- testing something here
-- JSON Document and Property Types


{-| A `JValue` represents a typed value within a JSON document.
-}
type JValue
    = JString String
    | JInt Int
    | JFloat Float
    | JBool Bool
    | JTime Time.Posix
    | JList (List Node)
    | JObject (List ( String, Node ))
    | JNull


{-| A `JProp` represents the type of a scalar property within a JSON document. These are regarded separately
from the `JValue` type for a few important reasons:

  - Since this package is concerned with parsing an arbitrary JSON document and lifting it into a type that allows it to be
    used within an Elm program, this means that the JSON schema is derived ad-hoc from user input.
  - And so, an ad-hoc JSON schema cannot exist without values.
  - However, if we are going to to store references to locations within that ad-hoc JSON schema, we are likely doing so because
    we would like to retrieve some value at a given location from a JSON document that is different from the original input.

In order to create a distinction between "a parsed JSON value" and "a reference to a location within a JSON document", it must
be the case that we have another way to represent the concept of "the expected type of a value at a location within a JSON document"
that is separate from "a value at a location within a JSON document, from which the type is derived".

Creating a second type was the most straightforward way to implement this behavior.

-}
type JProp
    = PString
    | PInt
    | PFloat
    | PBool
    | PTime
    | PNull


{-| A `JStructure` represents a property that has a structural type (i.e., a list or an object) within a JSON document.
-}
type JStructure
    = SObject
    | SList


{-| A `JTag` is a "tag" that is used to store the type of a given property (scalar or structural) in a JSON document.

`Json.InElm` doesn't actually _need_ to store this information in order to parse a JSON document, since it can be inferred directly from incoming data; however, it can be helpful to store this information for later retrieval and evaluation, so a type `JTag` that unions `JProp`s and `JStructure`s is provided.

-}
type JTag
    = Prop JProp
    | Structure JStructure


{-| A `Keypath` is a data structure that stores the JSON path to a value of a given key.

Elements in a `Keypath` are either the name of a field, or the index of an array.

Use the functions in the `Json.InElm.Keypath` module to work with `Keypath` values.

-}
type alias Keypath =
    Json.InElm.Keypath.Internal.Keypath


{-| A `Schema` describes the type of, and path to, a given `Node`.
-}
type alias Schema =
    { keypath : Keypath
    , tag : JTag
    }


{-| A `Node` is a reprentation of part of a JSON document, along with everything that is inside of it,
along with its "key path", which is its location within a JSON document.

This means that the output of the parser will always be a single `Node`; but depending on the input,
that `Node`'s `JValue` may have other `Node`s inside of it.

-}
type alias Node =
    { value : JValue
    , schema : Schema
    }



-- Parsing


{-| Parse a `Json.Decode.Value` to a `Node`.
-}
parseValue : Json.Decode.Value -> Result Json.Decode.Error Node
parseValue =
    Json.Decode.decodeValue
        (Json.Decode.map
            (withPath Json.InElm.Keypath.init)
            (toDecoder Json.InElm.Keypath.init)
        )


{-| Parse a `Json.Decode.Value` to a `Node`, at a given `KeyPath`.
-}
parseValueAt : Keypath -> Json.Decode.Value -> Result Json.Decode.Error Node
parseValueAt keypath =
    Json.Decode.decodeValue <| toDecoder keypath


{-| Parse a raw JSON string to a `Node`.
-}
parseJsonString : String -> Result Json.Decode.Error Node
parseJsonString =
    Json.Decode.decodeString Json.Decode.value
        >> Result.andThen parseValue


{-| Create a decoder to a `Node`, given a `Keypath`.
-}
toDecoder : Keypath -> Json.Decode.Decoder Node
toDecoder keypath =
    let
        builder : Json.Decode.Decoder a -> Json.Decode.Decoder a
        builder =
            Json.InElm.Keypath.fold
                (>>)
                { fromIndex = Json.Decode.index
                , fromAt = Json.Decode.field
                }
                identity
                keypath

        build v =
            { value = v
            , schema = Schema keypath <| toJTag v
            }
    in
    Json.Decode.lazy
        (\() ->
            Json.Decode.oneOf
                [ Json.Decode.map (build << JString) <| builder Json.Decode.string
                , Json.Decode.map (build << JInt) Json.Decode.int
                , Json.Decode.map (build << JFloat) Json.Decode.float
                , Json.Decode.map (build << JBool) Json.Decode.bool
                , Json.Decode.map (build << JList) (Json.Decode.list (Json.Decode.lazy (\() -> toDecoder keypath)))
                , Json.Decode.map (build << JObject) (Json.Decode.keyValuePairs (Json.Decode.lazy (\() -> toDecoder keypath)))
                , Json.Decode.null (build JNull)
                , Json.Decode.map (build << JTime) Iso8601.decoder
                ]
        )



-- Retrieving values from a `JValue`


{-| From a `Node`, get all possible `Node`s.
-}
toNodes : Node -> List Node
toNodes node =
    case node.value of
        JString _ ->
            List.singleton node

        JInt _ ->
            List.singleton node

        JFloat _ ->
            List.singleton node

        JBool _ ->
            List.singleton node

        JTime _ ->
            List.singleton node

        JList nodes ->
            node :: List.concatMap toNodes nodes

        JObject objects ->
            node :: List.concatMap (Tuple.second >> toNodes) objects

        JNull ->
            List.singleton node


{-| Try to get a `String` from a `JValue`.
-}
toString : JValue -> Maybe String
toString =
    fromJValue >> .string


{-| Try to get a `Int` from a `JValue`.
-}
toInt : JValue -> Maybe Int
toInt =
    fromJValue >> .int


{-| Try to get a `Float` from a `JValue`.
-}
toFloat : JValue -> Maybe Float
toFloat =
    fromJValue >> .float


{-| Try to get a `Bool` from a `JValue`.
-}
toBool : JValue -> Maybe Bool
toBool =
    fromJValue >> .bool


{-| Try to get a `Time` from a `JValue`.
-}
toTime : JValue -> Maybe Time.Posix
toTime =
    fromJValue >> .time


{-| Try to get a `List Node` from a `JValue`.
-}
toList : JValue -> Maybe (List Node)
toList =
    fromJValue >> .list


{-| Try to get a `List (String, Node)` from a `JValue`, where the `String`
value is the name of the field in the object.
-}
toObject : JValue -> Maybe (List ( String, Node ))
toObject =
    fromJValue >> .object


{-| Try to see if a `JValue` contains a JSON `null`.
-}
toNull : JValue -> Maybe ()
toNull =
    fromJValue >> .null



-- Viewing a `Node`


{-| Combinator that allows you to build a view function that renders a `Node`; i.e., if _you_ can provide all of the functions
to destructure a `Node`, we can display it for you!
-}
view :
    { string : String -> Html.Html msg
    , int : Int -> Html.Html msg
    , float : Float -> Html.Html msg
    , bool : Bool -> Html.Html msg
    , time : Time.Posix -> Html.Html msg
    , null : Html.Html msg
    , list : List (Html.Html msg) -> Html.Html msg
    , object : { key : String, value : Html.Html msg } -> Html.Html msg
    , withKeypath : Maybe (String -> Html.Html msg -> Html.Html msg)
    , withOnClick : Maybe (Node -> msg)
    }
    -> Node
    -> Html.Html msg
view ({ string, int, float, bool, time, null, list, object, withKeypath, withOnClick } as funcs) node =
    let
        maybeWithKeypath : Html.Html msg -> Html.Html msg
        maybeWithKeypath =
            Maybe.map ((|>) (Json.InElm.Keypath.toString node.schema.keypath)) withKeypath
                |> Maybe.withDefault identity

        maybeWithOnClick : Html.Html msg -> Html.Html msg
        maybeWithOnClick html =
            Maybe.map
                (\toMsg ->
                    Html.div [ Html.Events.onClick <| toMsg node ] [ html ]
                )
                withOnClick
                |> Maybe.withDefault html
    in
    maybeWithKeypath <|
        case node.value of
            JString value ->
                maybeWithOnClick <| string value

            JInt value ->
                maybeWithOnClick <| int value

            JFloat value ->
                maybeWithOnClick <| float value

            JBool value ->
                maybeWithOnClick <| bool value

            JTime value ->
                maybeWithOnClick <| time value

            JNull ->
                null

            JList value ->
                list <|
                    List.map (view funcs) value

            JObject value ->
                list <|
                    List.map
                        (\( k, v ) ->
                            object { key = k, value = view funcs v }
                        )
                        value



-- Internals


withPath : Keypath -> Node -> Node
withPath keypath node =
    let
        withPathSoFar : Node
        withPathSoFar =
            { node
                | schema =
                    (\schema -> { schema | keypath = keypath }) node.schema
            }
    in
    case node.value of
        JString _ ->
            withPathSoFar

        JInt _ ->
            withPathSoFar

        JFloat _ ->
            withPathSoFar

        JBool _ ->
            withPathSoFar

        JNull ->
            withPathSoFar

        JTime _ ->
            withPathSoFar

        JList value ->
            { withPathSoFar
                | value =
                    JList
                        (List.indexedMap (\k v -> withPath (Json.InElm.Keypath.index k keypath) v) value)
            }

        JObject value ->
            { withPathSoFar
                | value =
                    JObject
                        (List.map
                            (\( k, v ) ->
                                ( k, withPath (Json.InElm.Keypath.at k keypath) v )
                            )
                            value
                        )
            }


toJProp : JValue -> Maybe JProp
toJProp jValue =
    case jValue of
        JString _ ->
            Just PString

        JInt _ ->
            Just PInt

        JFloat _ ->
            Just PFloat

        JBool _ ->
            Just PBool

        JNull ->
            Just PNull

        JTime _ ->
            Just PTime

        JList _ ->
            Nothing

        JObject _ ->
            Nothing


toJTag : JValue -> JTag
toJTag jValue =
    case jValue of
        JString _ ->
            Prop PString

        JInt _ ->
            Prop PInt

        JFloat _ ->
            Prop PFloat

        JBool _ ->
            Prop PBool

        JNull ->
            Prop PNull

        JTime _ ->
            Prop PTime

        JList _ ->
            Structure SList

        JObject _ ->
            Structure SObject


fromJValue :
    JValue
    ->
        { string : Maybe String
        , int : Maybe Int
        , float : Maybe Float
        , bool : Maybe Bool
        , time : Maybe Time.Posix
        , list : Maybe (List Node)
        , object : Maybe (List ( String, Node ))
        , null : Maybe ()
        }
fromJValue jvalue =
    let
        acc =
            { string = Nothing
            , int = Nothing
            , float = Nothing
            , bool = Nothing
            , time = Nothing
            , list = Nothing
            , object = Nothing
            , null = Nothing
            }
    in
    case jvalue of
        JString value ->
            { acc | string = Just value }

        JInt value ->
            { acc | int = Just value }

        JFloat value ->
            { acc | float = Just value }

        JBool value ->
            { acc | bool = Just value }

        JTime value ->
            { acc | time = Just value }

        JList value ->
            { acc | list = Just value }

        JObject value ->
            { acc | object = Just value }

        JNull ->
            { acc | null = Just () }
