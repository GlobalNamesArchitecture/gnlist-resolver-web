module Update exposing (init, update)

import Material
import Messages exposing (Msg(..))
import Http
import RemoteData
import Models exposing (Model, Flags, currentToken, initModel)
import Navigation exposing (Location)
import Routing exposing (Route(..))
import FileUpload.Messages as FUM
import FileUpload.Update as FUU
import FileUpload.Ports as FUP
import Terms.Messages as TM
import Terms.Update as TU
import Terms.Helper as TH
import Target.Messages as DSM
import Target.Update as DSU
import Resolver.Messages as RM
import Resolver.Update as RU
import Resolver.Api as RA
import Data.Token as Token exposing (Token)
import Data.DataSource as DataSource


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Mdl msg_ ->
            Material.update Mdl msg_ model

        OnLocationChange location ->
            updateRoute location model

        FileUploadMsg msg_ ->
            updateUpload msg_ model

        TermsMsg msg_ ->
            updateTerms msg_ model

        TargetMsg msg_ ->
            updateTarget msg_ model

        ResolverMsg msg_ ->
            updateResolver msg_ model

        EmptyErrors ->
            emptyErrors model

        LoadDataSources v ->
            ( { model | dataSources = v }
            , Cmd.none
            )


updateRoute : Location -> Model -> ( Model, Cmd Msg )
updateRoute location model =
    let
        newRoute =
            Routing.parseLocation location

        command =
            routingCommand model newRoute
    in
        ( { model | route = newRoute }, command )


routingCommand : Model -> Route -> Cmd Msg
routingCommand model route =
    case route of
        Resolver token ->
            Cmd.batch
                [ Cmd.map ResolverMsg <| RA.queryResolutionProgress token
                , Cmd.map TargetMsg <| DSU.retrieveDataSource token
                ]

        Terms token ->
            if List.isEmpty model.terms.headers then
                Cmd.map TermsMsg <| TH.getTerms token
            else
                Cmd.none

        Target token ->
            Cmd.map TargetMsg <| DSU.retrieveDataSource token

        _ ->
            Cmd.none


updateUpload : FUM.Msg -> Model -> ( Model, Cmd Msg )
updateUpload msg model =
    let
        ( uploadModel, uploadCmd ) =
            FUU.update msg model.upload
    in
        ( { model | upload = uploadModel }, Cmd.map FileUploadMsg uploadCmd )


updateTerms : TM.Msg -> Model -> ( Model, Cmd Msg )
updateTerms msg model =
    let
        ( termsModel, termsCmd ) =
            TU.update msg model.terms
    in
        ( { model | terms = termsModel }, Cmd.map TermsMsg termsCmd )


updateTarget : DSM.Msg -> Model -> ( Model, Cmd Msg )
updateTarget msg model =
    let
        ( targetModel, targetCmd ) =
            DSU.update msg model.target
    in
        ( { model | target = targetModel }
        , Cmd.map TargetMsg targetCmd
        )


updateResolver : RM.Msg -> Model -> ( Model, Cmd Msg )
updateResolver msg model =
    let
        token =
            Maybe.withDefault (Token.fromString "") <| currentToken model

        ( resolverModel, resolverCmd ) =
            RU.update msg model.resolver token
    in
        ( { model | resolver = resolverModel }
        , Cmd.map ResolverMsg resolverCmd
        )


emptyErrors : Model -> ( Model, Cmd Msg )
emptyErrors model =
    let
        upload =
            .upload <| Tuple.first (updateUpload FUM.EmptyErrors model)

        resolver =
            .resolver <| Tuple.first (updateResolver RM.EmptyErrors model)
    in
        ( { model | upload = upload, resolver = resolver }, Cmd.none )


init : Flags -> Location -> ( Model, Cmd Msg )
init flags location =
    let
        currentRoute =
            Routing.parseLocation location

        model =
            initModel flags currentRoute
    in
        ( model
        , Cmd.batch
            [ FUP.isUploadSupported ()
            , routingCommand model currentRoute
            , loadDataSources model
            ]
        )


loadDataSources : Model -> Cmd Msg
loadDataSources { resolverUrl } =
    let
        datasourceUrl =
            resolverUrl ++ "/data_sources.json"
    in
        Http.get datasourceUrl DataSource.listDecoder
            |> RemoteData.sendRequest
            |> Cmd.map LoadDataSources
