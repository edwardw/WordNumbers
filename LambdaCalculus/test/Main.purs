module Test.Main where

import Prelude
import Effect (Effect)
import Test.LambdaCalculus (testLambdaCalculus)
import Test.PCF (testPCF)
import Test.Unbound (testUnbound)
import Test.UnionFind (testUnionFind)

main :: Effect Unit
main = do
  testLambdaCalculus
  testPCF
  testUnionFind
  testUnbound
