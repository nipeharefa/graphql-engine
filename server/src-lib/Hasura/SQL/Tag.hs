{-# LANGUAGE TemplateHaskell #-}

module Hasura.SQL.Tag
  ( BackendTag (..),
    HasTag (..),
    reify,
  )
where

import Hasura.Prelude
import Hasura.SQL.Backend
import Hasura.SQL.TH
import Language.Haskell.TH hiding (reify)

-- | A singleton-like GADT that associates a tag to each backend.
-- It is generated with Template Haskell for each 'Backend'. Its
-- declaration results in the following type:
--
--   data BackendTag (b :: BackendType) where
--     PostgresVanillaTag :: BackendTag ('Postgres 'Vanilla)
--     PostgresCitusTag   :: BackendTag ('Postgres 'Citus)
--     MSSQLTag           :: BackendTag 'MSSQL
--     ...
$( let name = mkName "BackendTag"
    in backendData
         -- the name of the type
         name
         -- the type variable
         [KindedTV (mkName "b") $ ConT ''BackendType]
         -- the constructor for each backend
         ( \b ->
             pure $
               GadtC
                 -- the name of the constructor (FooTag)
                 [getBackendTagName b]
                 -- no type argument
                 []
                 -- the resulting type (BackendTag 'Foo)
                 (AppT (ConT name) (getBackendTypeValue b))
         )
         -- deriving clauses
         []
 )

-- | This class describes how to get a tag for a given type.
-- We use it in AnyBackend: `case backendTag @b of`...
class HasTag (b :: BackendType) where
  backendTag :: BackendTag b

-- | This generates the instance of HasTag for every backend.
$( concat <$> forEachBackend \b -> do
     -- the name of the tag: FooTag
     let tagName = pure $ ConE $ getBackendTagName b
     -- the promoted version of b: 'Foo
     let promotedName = pure $ getBackendTypeValue b
     -- the instance:
     --  instance HasTag 'Foo          where backendTag = FooTag
     [d|instance HasTag $promotedName where backendTag = $tagName|]
 )

-- | How to convert back from a tag to a runtime value. This function
-- is generated with Template Haskell for each 'Backend'. The case
-- switch looks like this:
--
--   PostgresVanillaTag -> Postgres Vanilla
--   PostgresCitusTag   -> Postgres Citus
--   MSSQLTag           -> MSSQL
--   ...
reify :: BackendTag b -> BackendType
reify t =
  $( backendCase
       -- the expression on which we do the case switch
       [|t|]
       -- the pattern for a given backend: just its tag, no argument
       (\b -> pure $ ConP (getBackendTagName b) [])
       -- the body for a given backend: the backend constructor itself
       (\b -> pure $ getBackendValue b)
       -- no default case: every constructor should be handled
       Nothing
   )
