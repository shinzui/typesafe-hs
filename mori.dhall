let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/3522f4a51181d73c9c90fc27a7c0838bd29ae95f/package.dhall
        sha256:dcb19e2312e790bad14e622cc98a1281cd2298c5b564a2f0d0534d3c718d8803

in  Schema.Project::{
    , project = Schema.ProjectIdentity::{
      , name = "typesafe-hs"
      , namespace = "shinzui"
      , stableId = Some "project_01m5fqv7fve1gvz9mg7kqhn5h0"
      , type = Schema.PackageType.Library
      , language = Schema.Language.Haskell
      , lifecycle = Schema.Lifecycle.Active
      , description = Some
          "Transport-free Haskell client for TypeSafe's System One API: wire types, JSON codecs and pure helpers mirroring the official OpenAPI document"
      , domains = [ "AI", "API Client" ]
      }
    , repos =
      [ Schema.Repo::{ name = "typesafe-hs", github = Some "shinzui/typesafe-hs" }
      ]
    , packages =
      [ Schema.Package::{
        , name = "typesafe-hs"
        , type = Schema.PackageType.Library
        , language = Schema.Language.Haskell
        , path = Some "."
        , description = Some
            "Wire types, deterministic request encoding and lossless response decoding for POST /v1/systemone and GET /v1/models"
        }
      ]
    }
