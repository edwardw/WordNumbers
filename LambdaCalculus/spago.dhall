{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "my-project"
, dependencies =
    [ "console"
    , "contravariant"
    , "effect"
    , "exceptions"
    , "leibniz"
    , "newtype"
    , "node-readline"
    , "ordered-collections"
    , "parsing"
    , "profunctor"
    , "psci-support"
    , "refs"
    , "run"
    , "stringutils"
    , "test-unit"
    , "transformers"
    , "typelevel"
    ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs", "examples/**/*.purs" ]
}
