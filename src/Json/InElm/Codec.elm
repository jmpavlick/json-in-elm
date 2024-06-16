module Json.InElm.Codec exposing (schema)

{-|


# Codec

A "codec" is a paired JSON encoder and decoder for a given type.

@docs schema

-}

import Bimap
import Iso8601
import Json.Decode
import Json.Encode
import Json.InElm
import Json.InElm.Keypath
import Json.InElm.Keypath.Internal


{-| Encoding and decoding for the `Json.InElm.Schema`.
-}
schema :
    { encode : Json.InElm.Schema -> Json.Encode.Value
    , decoder : Json.Decode.Decoder Json.InElm.Schema
    }
schema =
    let
        fieldname :
            { keypath : String
            , tag : String
            }
        fieldname =
            { keypath = "sk"
            , tag = "st"
            }
    in
    { encode =
        \value ->
            Json.Encode.object
                [ ( fieldname.keypath, keypath.encode value.keypath )
                , ( fieldname.tag, jTag.encode value.tag )
                ]
    , decoder =
        Json.Decode.map2
            Json.InElm.Schema
            (Json.Decode.field fieldname.keypath keypath.decoder)
            (Json.Decode.field fieldname.tag jTag.decoder)
    }


jTag :
    { encode : Json.InElm.JTag -> Json.Encode.Value
    , decoder : Json.Decode.Decoder Json.InElm.JTag
    }
jTag =
    let
        fieldname : String
        fieldname =
            "jt"
    in
    { encode =
        tag.encode fieldname <|
            \value ->
                case value of
                    Json.InElm.Prop prop ->
                        jProp.encode prop

                    Json.InElm.Structure structure ->
                        jStructure.encode structure
    , decoder =
        tag.decoder fieldname <|
            Json.Decode.oneOf
                [ Json.Decode.map Json.InElm.Prop
                    jProp.decoder
                , Json.Decode.map Json.InElm.Structure
                    jStructure.decoder
                ]
    }


jStructure :
    { encode : Json.InElm.JStructure -> Json.Encode.Value
    , decoder : Json.Decode.Decoder Json.InElm.JStructure
    }
jStructure =
    let
        bimap : Bimap.Bimap Json.InElm.JStructure
        bimap =
            Bimap.init
                (\slist sobject value ->
                    case value of
                        Json.InElm.SList ->
                            slist

                        Json.InElm.SObject ->
                            sobject
                )
                |> Bimap.variant "sl" Json.InElm.SList
                |> Bimap.variant "so" Json.InElm.SObject
                |> Bimap.build
    in
    { encode = Bimap.encoder bimap
    , decoder = Bimap.decoder bimap
    }


jProp :
    { encode : Json.InElm.JProp -> Json.Encode.Value
    , decoder : Json.Decode.Decoder Json.InElm.JProp
    }
jProp =
    let
        bimap : Bimap.Bimap Json.InElm.JProp
        bimap =
            Bimap.init
                (\pstring pint pfloat pbool ptime pnull value ->
                    case value of
                        Json.InElm.PString ->
                            pstring

                        Json.InElm.PInt ->
                            pint

                        Json.InElm.PFloat ->
                            pfloat

                        Json.InElm.PBool ->
                            pbool

                        Json.InElm.PTime ->
                            ptime

                        Json.InElm.PNull ->
                            pnull
                )
                |> Bimap.variant "s" Json.InElm.PString
                |> Bimap.variant "i" Json.InElm.PInt
                |> Bimap.variant "f" Json.InElm.PFloat
                |> Bimap.variant "b" Json.InElm.PBool
                |> Bimap.variant "t" Json.InElm.PTime
                |> Bimap.variant "n" Json.InElm.PNull
                |> Bimap.build
    in
    { encode = Bimap.encoder bimap
    , decoder = Bimap.decoder bimap
    }


keypath :
    { encode : Json.InElm.Keypath -> Json.Encode.Value
    , decoder : Json.Decode.Decoder Json.InElm.Keypath
    }
keypath =
    let
        fieldname : String
        fieldname =
            "keypath"
    in
    { encode =
        let
            toSegments : Json.InElm.Keypath -> Json.Encode.Value
            toSegments =
                Json.Encode.list identity
                    << List.reverse
                    << Json.InElm.Keypath.fold
                        (::)
                        { fromIndex = tag.encode "i" Json.Encode.int
                        , fromAt = tag.encode "a" Json.Encode.string
                        }
                        []
        in
        tag.encode
            fieldname
            toSegments
    , decoder =
        Json.Decode.map
            Json.InElm.Keypath.Internal.Keypath
        <|
            tag.decoder
                fieldname
                (Json.Decode.list <|
                    Json.Decode.oneOf
                        [ Json.Decode.map
                            Json.InElm.Keypath.Internal.Index
                          <|
                            tag.decoder "i" Json.Decode.int
                        , Json.Decode.map
                            Json.InElm.Keypath.Internal.At
                          <|
                            tag.decoder "a" Json.Decode.string
                        ]
                )
    }


tag :
    { encode : String -> (a -> Json.Encode.Value) -> (a -> Json.Encode.Value)
    , decoder : String -> Json.Decode.Decoder a -> Json.Decode.Decoder a
    }
tag =
    { encode =
        \fieldname toA value ->
            Json.Encode.object
                [ ( fieldname
                  , toA value
                  )
                ]
    , decoder =
        \fieldname fromA ->
            Json.Decode.field fieldname fromA
    }
