module Resolver.Helper
    exposing
        ( Input
        , ResolutionInput
        , ResolverProgress(..)
        , ExcelProgress(..)
        , resolutionResolverProgress
        , ingestionResolverProgress
        , resolutionInput
        , ingestionInput
        )

import Resolver.Models exposing (Resolver, Resolution, Ingestion, Stats(..), ProgressMetadata(..), TotalRecordCount(..), ExcelRowsCount(..), ProcessedRecordCount(..), NamesPerSecond(..))
import TimeDuration.Model exposing (..)


type alias Input =
    { total : TotalRecordCount
    , processed : ProcessedRecordCount
    , timeSpan : Seconds
    , velocity : List Velocity
    , estimate : Estimate
    }


type alias ResolutionInput =
    { total : TotalRecordCount
    , processed : ProcessedRecordCount
    , timeSpan : Seconds
    , speed : NamesPerSecond
    , estimate : Estimate
    }


type alias Velocity =
    { recordsNum : ProcessedRecordCount
    , timeSpan : Seconds
    }


type alias Estimate =
    { namesPerSec : NamesPerSecond
    , eta : TimeDuration
    }


estimate : TotalRecordCount -> ProcessedRecordCount -> List Velocity -> Estimate
estimate total processed velocity =
    let
        namesPerSec =
            normalizeVelocity velocity

        (NamesPerSecond speed) =
            namesPerSec

        (TotalRecordCount total_) =
            total

        (ProcessedRecordCount processed_) =
            processed

        eta =
            timeToSeconds <|
                toFloat (total_ - processed_)
                    / speed
    in
        Estimate namesPerSec (secondsToTimeDuration eta)


ingestionInput : ProgressMetadata -> Ingestion -> Maybe Resolution -> Input
ingestionInput (ProgressMetadata _ _ totalRecords _) ingestion mresolution =
    let
        processed =
            ingestion.ingestedRecords

        timeSpent =
            case mresolution of
                Nothing ->
                    ingestion.ingestionSpan

                Just resolution ->
                    timeToSeconds <|
                        resolution.start
                            - ingestion.ingestionStart

        vel =
            [ Velocity processed ingestion.ingestionSpan ]
    in
        Input totalRecords processed timeSpent vel (estimate totalRecords processed vel)


resolutionInput :
    ProgressMetadata
    -> Resolution
    -> Maybe Float
    -> ResolutionInput
resolutionInput (ProgressMetadata _ _ totalRecords _) resolution resolutionStop =
    let
        processed =
            resolution.resolvedRecords

        timeSpan =
            case resolutionStop of
                Nothing ->
                    resolution.timeSpan

                Just stop ->
                    timeToSeconds <| stop - resolution.start

        estimate =
            Estimate resolution.speed <|
                secondsToTimeDuration resolution.estimate
    in
        ResolutionInput totalRecords
            processed
            timeSpan
            resolution.speed
            estimate


occurrencesPerSecond : ProcessedRecordCount -> Seconds -> Float
occurrencesPerSecond (ProcessedRecordCount occurrences) (Seconds s) =
    toFloat occurrences / s


velocityOccurrencesPerSecond : Velocity -> Float
velocityOccurrencesPerSecond { recordsNum, timeSpan } =
    occurrencesPerSecond recordsNum timeSpan


normalizeVelocity : List Velocity -> NamesPerSecond
normalizeVelocity vs =
    NamesPerSecond <| average <| List.map velocityOccurrencesPerSecond vs


average : List Float -> Float
average xs =
    List.sum xs / (toFloat <| List.length xs)


type ResolverProgress a
    = Pending
    | InProgress Input
    | ResolutionInProgress ResolutionInput
    | ResolutionComplete ResolutionInput
    | Complete Input


type ExcelProgress a
    = ExcelInProgress Input
    | ExcelDone Input


ingestionResolverProgress : Resolver -> ResolverProgress Ingestion
ingestionResolverProgress { stats } =
    case stats of
        Unknown ->
            Pending

        NoStatsReceived ->
            Pending

        NotStarted ->
            Pending

        PendingResolution _ ->
            Pending

        Ingesting metadata ingestion ->
            InProgress <| ingestionInput metadata ingestion Nothing

        Resolving metadata ingestion resolution ->
            Complete <| ingestionInput metadata ingestion (Just resolution)

        BuildingExcel metadata ingestion resolution _ ->
            Complete <| ingestionInput metadata ingestion (Just resolution)

        Done metadata ingestion resolution _ ->
            Complete <| ingestionInput metadata ingestion (Just resolution)


resolutionResolverProgress : Resolver -> ResolverProgress Resolution
resolutionResolverProgress { stats } =
    case stats of
        Unknown ->
            Pending

        NoStatsReceived ->
            Pending

        NotStarted ->
            Pending

        PendingResolution _ ->
            Pending

        Ingesting _ _ ->
            Pending

        Resolving metadata _ resolution ->
            ResolutionInProgress <|
                resolutionInput metadata
                    resolution
                    Nothing

        BuildingExcel metadata _ resolution _ ->
            ResolutionComplete <| resolutionInput metadata resolution Nothing

        Done metadata _ resolution stop ->
            ResolutionComplete <|
                resolutionInput metadata
                    resolution
                    (Just stop)
