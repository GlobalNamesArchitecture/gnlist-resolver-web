module Models exposing (Model, Flags, initModel, currentToken)

import Material
import Routing exposing (Route(..))
import FileUpload.Models exposing (Upload, initUpload)
import Terms.Models exposing (Terms, initTerms)
import Target.Models exposing (Target, initTarget)
import Resolver.Models exposing (Resolver, initResolver)
import Errors exposing (Errors)
import Data.Token exposing (Token)


type alias Model =
    { route : Routing.Route
    , resolverUrl : String
    , localDomain : String
    , upload : Upload
    , terms : Terms
    , target : Target
    , resolver : Resolver
    , errors : Errors
    , softwareVersion : String
    , mdl : Material.Model
    }


type alias Flags =
    { resolverUrl : String
    , localDomain : String
    , dataSourcesIds : List Int
    , version : String
    }


initModel : Flags -> Routing.Route -> Model
initModel flags route =
    Model route
        flags.resolverUrl
        flags.localDomain
        initUpload
        initTerms
        (initTarget flags.dataSourcesIds)
        initResolver
        Nothing
        flags.version
        Material.model


currentToken : Model -> Maybe Token
currentToken { route } =
    case route of
        FileUpload ->
            Nothing

        Terms t ->
            Just t

        Target t ->
            Just t

        Resolver t ->
            Just t

        NotFoundRoute ->
            Nothing
