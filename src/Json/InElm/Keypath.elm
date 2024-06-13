module Json.InElm.Keypath exposing
    ( FieldAccessor
    , at
    , index
    , init
    , toString
    , fold
    )

{-|

@docs FieldAccessor
@docs at
@docs index
@docs init
@docs toString
@docs fold

-}

import Json.InElm.Keypath.Internal


type alias Keypath =
    Json.InElm.Keypath.Internal.Keypath


{-| Representation of a value used to access a field in a JSON document.
-}
type alias FieldAccessor =
    Json.InElm.Keypath.Internal.FieldAccessor


{-| To construct a `Keypath`, you must start with an empty value.
-}
init : Keypath
init =
    Json.InElm.Keypath.Internal.init


{-| Updates a `KeyPath` and adds the name of a field in a JSON document.
-}
at : String -> Keypath -> Keypath
at =
    Json.InElm.Keypath.Internal.at


{-| Updates a `KeyPath` and adds the value of an index in a JSON array.
-}
index : Int -> Keypath -> Keypath
index =
    Json.InElm.Keypath.Internal.index


{-| Renders a `Keypath` to a string.
-}
toString : Keypath -> String
toString =
    Json.InElm.Keypath.Internal.toString


{-| Fold over the values in a `KeyPath` to transform them into a value of some other type.

(Hint: `toString` implements `fold` directly! You can check out the source on Github to see how it's done.)

-}
fold : (a -> b -> b) -> { fromIndex : Int -> a, fromAt : String -> a } -> b -> Keypath -> b
fold =
    Json.InElm.Keypath.Internal.foldl
