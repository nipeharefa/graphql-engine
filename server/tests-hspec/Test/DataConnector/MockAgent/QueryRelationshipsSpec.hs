{-# LANGUAGE QuasiQuotes #-}

module Test.DataConnector.MockAgent.QueryRelationshipsSpec
  ( spec,
  )
where

import Autodocodec.Extended (ValueWrapper (..))
import Data.Aeson qualified as Aeson
import Data.Aeson.KeyMap qualified as KM
import Data.HashMap.Strict qualified as HashMap
import Harness.Backend.DataConnector qualified as DataConnector
import Harness.Quoter.Graphql (graphql)
import Harness.Quoter.Yaml (yaml, yamlObjects)
import Harness.Test.BackendType (BackendType (..), defaultBackendTypeString, defaultSource)
import Harness.Test.Context qualified as Context
import Harness.TestEnvironment (TestEnvironment)
import Hasura.Backends.DataConnector.API qualified as API
import Test.Hspec (SpecWith, describe, it)
import Prelude

spec :: SpecWith TestEnvironment
spec =
  Context.runWithLocalTestEnvironment
    [ Context.Context
        { name = Context.Backend Context.DataConnector,
          mkLocalTestEnvironment = DataConnector.mkLocalTestEnvironmentMock,
          setup = DataConnector.setupMock sourceMetadata DataConnector.mockBackendConfig,
          teardown = DataConnector.teardownMock,
          customOptions = Nothing
        }
    ]
    tests

sourceMetadata :: Aeson.Value
sourceMetadata =
  let source = defaultSource DataConnector
      backendType = defaultBackendTypeString DataConnector
   in [yaml|
        name : *source
        kind: *backendType
        tables:
          - table: Genre
          - table: MediaType
          - table: Track
            object_relationships:
              - name: Genre
                using:
                  manual_configuration:
                    remote_table: Genre
                    column_mapping:
                      GenreId: GenreId
              - name: MediaType
                using:
                  manual_configuration:
                    remote_table: MediaType
                    column_mapping:
                      MediaTypeId: MediaTypeId
        configuration: {}
      |]

--------------------------------------------------------------------------------

tests :: Context.Options -> SpecWith (TestEnvironment, DataConnector.MockAgentEnvironment)
tests opts = do
  describe "Object Relationships Tests" $ do
    it "works with multiple object relationships" $
      DataConnector.runMockedTest opts $
        DataConnector.TestCase
          { _given =
              let albums =
                    [yamlObjects|
                      - Genre:
                          Name: "Rock"
                        MediaType:
                          Name: "MPEG audio file"
                        Name: "For Those About To Rock (We Salute You)"
                    |]
               in DataConnector.chinookMock {DataConnector._queryResponse = \_ -> API.QueryResponse albums},
            _whenRequest =
              [graphql|
                query getTrack {
                  Track(limit: 1) {
                    Name
                    Genre {
                      Name
                    }
                    MediaType {
                      Name
                    }
                  }
                }
              |],
            _whenQuery =
              Just
                ( API.QueryRequest
                    { _qrTable = API.TableName "Track",
                      _qrTableRelationships =
                        [ API.TableRelationships
                            { _trSourceTable = API.TableName "Track",
                              _trRelationships =
                                HashMap.fromList
                                  [ ( API.RelationshipName "Genre",
                                      API.Relationship
                                        { _rTargetTable = API.TableName "Genre",
                                          _rRelationshipType = API.ObjectRelationship,
                                          _rColumnMapping = HashMap.fromList [(API.ColumnName "GenreId", API.ColumnName "GenreId")]
                                        }
                                    ),
                                    ( API.RelationshipName "MediaType",
                                      API.Relationship
                                        { _rTargetTable = API.TableName "MediaType",
                                          _rRelationshipType = API.ObjectRelationship,
                                          _rColumnMapping =
                                            HashMap.fromList
                                              [(API.ColumnName "MediaTypeId", API.ColumnName "MediaTypeId")]
                                        }
                                    )
                                  ]
                            }
                        ],
                      _qrQuery =
                        API.Query
                          { _qFields =
                              KM.fromList
                                [ ("Name", API.ColumnField (ValueWrapper (API.ColumnName "Name"))),
                                  ( "Genre",
                                    API.RelField
                                      ( API.RelationshipField
                                          (API.RelationshipName "Genre")
                                          API.Query
                                            { _qFields =
                                                KM.fromList
                                                  [ ("Name", API.ColumnField (ValueWrapper (API.ColumnName "Name")))
                                                  ],
                                              _qLimit = Nothing,
                                              _qOffset = Nothing,
                                              _qWhere = Just (API.And (ValueWrapper [])),
                                              _qOrderBy = Nothing
                                            }
                                      )
                                  ),
                                  ( "MediaType",
                                    API.RelField
                                      ( API.RelationshipField
                                          (API.RelationshipName "MediaType")
                                          API.Query
                                            { _qFields =
                                                KM.fromList
                                                  [ ("Name", API.ColumnField (ValueWrapper (API.ColumnName "Name")))
                                                  ],
                                              _qLimit = Nothing,
                                              _qOffset = Nothing,
                                              _qWhere = Just (API.And (ValueWrapper [])),
                                              _qOrderBy = Nothing
                                            }
                                      )
                                  )
                                ],
                            _qLimit = Just 1,
                            _qOffset = Nothing,
                            _qWhere = Just (API.And (ValueWrapper {getValue = []})),
                            _qOrderBy = Nothing
                          }
                    }
                ),
            _then =
              [yaml|
                data:
                  Track:
                    - Genre:
                        Name: "Rock"
                      MediaType:
                        Name: "MPEG audio file"
                      Name: "For Those About To Rock (We Salute You)"
              |]
          }
