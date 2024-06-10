module Json.InElm exposing (..)

import Dict
import Html
import Html.Events
import Iso8601
import Json.Decode
import Json.Encode
import Time


type KeyPath
    = KeyPath (List FieldAccessor)


initKeyPath : KeyPath
initKeyPath =
    KeyPath []


type alias Node =
    { value : JValue
    , keyPath : KeyPath
    , jType : Maybe JType
    }


type JValue
    = JString String
    | JInt Int
    | JFloat Float
    | JBool Bool
    | JTime Time.Posix
    | JList (List Node)
    | JObject (List ( String, Node ))
    | JNull


type JType
    = TString
    | TInt
    | TFloat
    | TBool
    | TTime
    | TNull


type FieldAccessor
    = At String
    | Index Int


at : String -> KeyPath -> KeyPath
at string (KeyPath kp) =
    KeyPath <| At string :: kp


index : Int -> KeyPath -> KeyPath
index int (KeyPath kp) =
    KeyPath <| Index int :: kp


withPath : KeyPath -> Node -> Node
withPath pathBuilder node =
    let
        withPathSoFar : Node
        withPathSoFar =
            { node
                | keyPath = pathBuilder
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
                        (List.indexedMap (\k v -> withPath (index k pathBuilder) v) value)
            }

        JObject value ->
            { withPathSoFar
                | value =
                    JObject
                        (List.map
                            (\( k, v ) ->
                                ( k, withPath (at k pathBuilder) v )
                            )
                            value
                        )
            }


toJType : JValue -> Maybe JType
toJType jValue =
    case jValue of
        JString _ ->
            Just TString

        JInt _ ->
            Just TInt

        JFloat _ ->
            Just TFloat

        JBool _ ->
            Just TBool

        JNull ->
            Just TNull

        JTime _ ->
            Just TTime

        JList _ ->
            Nothing

        JObject _ ->
            Nothing


nodeDecoder : Json.Decode.Decoder Node
nodeDecoder =
    let
        build v =
            { value = v, keyPath = initKeyPath, jType = toJType v }
    in
    Json.Decode.lazy
        (\() ->
            Json.Decode.oneOf
                [ Json.Decode.map (build << JString) Json.Decode.string
                , Json.Decode.map (build << JInt) Json.Decode.int
                , Json.Decode.map (build << JFloat) Json.Decode.float
                , Json.Decode.map (build << JBool) Json.Decode.bool
                , Json.Decode.map (build << JList) (Json.Decode.list (Json.Decode.lazy (\() -> nodeDecoder)))
                , Json.Decode.map (build << JObject) (Json.Decode.keyValuePairs (Json.Decode.lazy (\() -> nodeDecoder)))
                , Json.Decode.null (build JNull)
                , Json.Decode.map (build << JTime) Iso8601.decoder
                ]
        )


parseValue : Json.Decode.Value -> Result Json.Decode.Error Node
parseValue =
    Json.Decode.decodeValue
        (Json.Decode.map (withPath initKeyPath) nodeDecoder)


parseJsonString : String -> Result Json.Decode.Error Node
parseJsonString =
    Json.Decode.decodeString Json.Decode.value
        >> Result.andThen parseValue



{- the things we need, now, are:

   - an encoder / decoder pair for these json types
   - a way to render them in the view (i.e., a view combinator)

-}


keyPathToString : KeyPath -> String
keyPathToString (KeyPath kp) =
    List.foldl
        (\step acc ->
            acc
                ++ (case step of
                        Index i ->
                            String.concat [ "[", String.fromInt i, "]" ]

                        At f ->
                            String.concat [ ".", f ]
                   )
        )
        ""
        kp


runtimeDecoder : KeyPath -> JType -> Json.Decode.Value -> Result Json.Decode.Error JValue
runtimeDecoder (KeyPath kp) jType =
    let
        builder : Json.Decode.Decoder a -> Json.Decode.Decoder a
        builder =
            List.foldl
                (\step acc ->
                    acc
                        >> (case step of
                                At str ->
                                    Json.Decode.field str

                                Index i ->
                                    Json.Decode.index i
                           )
                )
                identity
                kp

        jDecoder : Json.Decode.Decoder JValue
        jDecoder =
            case jType of
                TString ->
                    Json.Decode.map JString <| builder Json.Decode.string

                TInt ->
                    Json.Decode.map JInt <| builder Json.Decode.int

                TFloat ->
                    Json.Decode.map JFloat <| builder Json.Decode.float

                TBool ->
                    Json.Decode.map JBool <| builder Json.Decode.bool

                TNull ->
                    Json.Decode.succeed JNull

                TTime ->
                    Json.Decode.map JTime <| builder Iso8601.decoder
    in
    Json.Decode.decodeValue jDecoder


view :
    { string : String -> Html.Html msg
    , int : Int -> Html.Html msg
    , float : Float -> Html.Html msg
    , bool : Bool -> Html.Html msg
    , time : Time.Posix -> Html.Html msg
    , null : Html.Html msg
    , list : List (Html.Html msg) -> Html.Html msg
    , object : { key : String, value : Html.Html msg } -> Html.Html msg
    , withKeyPath : Maybe (String -> Html.Html msg -> Html.Html msg)
    , withOnClick : Maybe (Node -> msg)
    }
    -> Node
    -> Html.Html msg
view ({ string, int, float, bool, time, null, list, object, withKeyPath, withOnClick } as funcs) node =
    let
        maybeWithKeyPath : Html.Html msg -> Html.Html msg
        maybeWithKeyPath =
            Maybe.map ((|>) (keyPathToString node.keyPath)) withKeyPath
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
    maybeWithKeyPath <|
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
