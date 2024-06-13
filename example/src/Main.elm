module Main exposing (..)

import Browser
import Html
import Html.Attributes
import Html.Events
import Http
import Iso8601
import Json.Decode
import Json.Encode
import Json.InElm


main : Program () Model Msg
main =
    Browser.element
        { init = always init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    { rawJson : String
    , nodes : List Json.InElm.Node
    }


type Msg
    = ClickedNode Json.InElm.Node
    | GotJson (Result Http.Error Json.Decode.Value)
    | RequestedJson String


init : ( Model, Cmd Msg )
init =
    let
        rawJson : String
        rawJson =
            Json.Encode.object
                [ ( "filename", Json.Encode.string "test.txt" )
                , ( "filetype", Json.Encode.string "textfile" )
                , ( "values", Json.Encode.list Json.Encode.int [ 2, 4 ] )
                , ( "an_object"
                  , Json.Encode.object
                        [ ( "enabled", Json.Encode.bool False )
                        ]
                  )
                ]
                |> Json.Encode.encode 2
    in
    ( { rawJson = rawJson
      , nodes = []
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedNode node ->
            ( Maybe.map (always { model | nodes = node :: model.nodes }) node.jProp
                |> Maybe.withDefault model
            , Cmd.none
            )

        GotJson (Ok rawJson) ->
            ( { model | rawJson = Json.Encode.encode 2 rawJson, nodes = [] }
            , Cmd.none
            )

        GotJson (Err _) ->
            ( model
            , Cmd.none
            )

        RequestedJson url ->
            ( model
            , Http.get
                { url = url
                , expect = Http.expectJson GotJson Json.Decode.value
                }
            )


rawJsonInput : { model | rawJson : String } -> Html.Html Msg
rawJsonInput { rawJson } =
    Html.pre []
        [ Html.textarea
            [ Html.Attributes.value rawJson
            , Html.Attributes.rows 40
            , Html.Attributes.cols 80
            , Html.Events.onInput (Json.Decode.decodeString Json.Decode.value >> Result.mapError (Json.Decode.errorToString >> Http.BadBody) >> GotJson)
            ]
            []
        ]


view : Model -> Html.Html Msg
view model =
    let
        node : Result Json.Decode.Error Json.InElm.Node
        node =
            Json.InElm.parseJsonString model.rawJson

        nodeFailure : Html.Html Msg
        nodeFailure =
            Html.div []
                [ Html.text "Error initializing Node from raw JSON:"
                , Html.pre
                    []
                    [ Html.text model.rawJson ]
                ]
    in
    Html.div [ Html.Attributes.class "container" ]
        [ Html.div [ Html.Attributes.class "row" ]
            [ Html.div [ Html.Attributes.class "col" ]
                [ Html.h3 [] [ Html.text "JSON Payload" ]
                , Result.map viewAllNodes node
                    |> Result.withDefault nodeFailure
                , Html.h3 [] [ Html.text "Selected Nodes" ]
                , Html.div [] <| List.map viewSelectedNode model.nodes
                ]
            , Html.div [ Html.Attributes.class "col" ]
                [ rawJsonInput model
                ]
            ]
        ]


viewSelectedNode : Json.InElm.Node -> Html.Html Msg
viewSelectedNode node =
    let
        toPre : String -> Html.Html msg
        toPre str =
            Html.pre [] [ Html.text str ]
    in
    Json.InElm.view
        { string =
            \value -> String.concat [ "\"", value, "\"" ] |> toPre
        , int = String.fromInt >> toPre
        , float = String.fromFloat >> toPre
        , bool =
            \value ->
                toPre <|
                    if value then
                        "true"

                    else
                        "false"
        , time = Iso8601.fromTime >> toPre
        , null = toPre "null"
        , list = Html.div []
        , object =
            \{ key, value } ->
                Html.table
                    [ Html.Attributes.class "table table-bordered table-sm"
                    ]
                    [ Html.tr [] [ Html.td [] [ toPre <| key ++ ":" ], Html.td [] [ value ] ] ]
        , withKeypath =
            Just
                (\keypath html ->
                    Html.table [ Html.Attributes.class "table table-bordered table-sm" ]
                        [ Html.tr []
                            [ Html.td [] [ Html.text <| "Path: " ++ keypath ]
                            , Maybe.map (\t -> Html.td [] [ Html.text <| "Type: " ++ Debug.toString t ]) node.jProp
                                |> Maybe.withDefault (Html.text "")
                            , Html.td [] [ html ]
                            ]
                        ]
                )
        , withOnClick = Nothing
        }
        node


viewAllNodes : Json.InElm.Node -> Html.Html Msg
viewAllNodes =
    let
        toPre : String -> Html.Html msg
        toPre str =
            Html.pre [] [ Html.text str ]
    in
    Json.InElm.view
        { string =
            \value -> String.concat [ "\"", value, "\"" ] |> toPre
        , int = String.fromInt >> toPre
        , float = String.fromFloat >> toPre
        , bool =
            \value ->
                toPre <|
                    if value then
                        "true"

                    else
                        "false"
        , time = Iso8601.fromTime >> toPre
        , null = toPre "null"
        , list = Html.div []
        , object =
            \{ key, value } ->
                Html.table
                    [ Html.Attributes.class "table table-bordered table-sm"
                    ]
                    [ Html.tr [] [ Html.td [] [ toPre <| key ++ ":" ], Html.td [] [ value ] ] ]
        , withKeypath = Nothing
        , withOnClick = Just ClickedNode
        }
