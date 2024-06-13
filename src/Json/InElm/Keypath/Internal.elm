module Json.InElm.Keypath.Internal exposing (..)


type Keypath
    = Keypath (List FieldAccessor)


{-| -}
type FieldAccessor
    = At String
    | Index Int


{-| -}
at : String -> Keypath -> Keypath
at string (Keypath kp) =
    Keypath <| At string :: kp


{-| -}
index : Int -> Keypath -> Keypath
index int (Keypath kp) =
    Keypath <| Index int :: kp


{-| -}
toString : Keypath -> String
toString =
    foldl
        (::)
        { fromIndex = \value -> String.concat [ "[", String.fromInt value, "]" ]
        , fromAt = \value -> String.concat [ ".", value ]
        }
        []
        >> String.concat


init : Keypath
init =
    Keypath []


unwrap : Keypath -> List FieldAccessor
unwrap (Keypath fieldAccessors) =
    fieldAccessors


foldl : (a -> b -> b) -> { fromIndex : Int -> a, fromAt : String -> a } -> b -> Keypath -> b
foldl accumulate { fromIndex, fromAt } base (Keypath kp) =
    List.foldl
        (\step acc ->
            accumulate
                (case step of
                    At value ->
                        fromAt value

                    Index value ->
                        fromIndex value
                )
                acc
        )
        base
        kp
