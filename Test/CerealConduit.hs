module Test.CerealConduit where

import Control.Monad.Identity
import Test.HUnit
import qualified Data.Conduit as C
import Data.Conduit.Cereal
import Data.Conduit.List
import Data.Serialize
import qualified Data.ByteString as BS
--import Test.Framework.Providers.HUnit
import System.Exit
import Data.Word
import qualified Data.List as L
import Prelude hiding (take)

sinktest1 :: Test
sinktest1 = TestCase (assertEqual "Handles starting with empty bytestring"
  (Right 1)
  (runIdentity $ (sourceList [BS.pack [], BS.pack [1]]) C.$$ (sinkGet getWord8)))

sinktest2 :: Test
sinktest2 = TestCase (assertEqual "Handles empty bytestring in middle"
  (Right [1, 3])
  (runIdentity $ (sourceList [BS.pack [1], BS.pack [], BS.pack [3]]) C.$$ (sinkGet (do
    x <- getWord8
    y <- getWord8
    return [x, y]))))

sinktest3 :: Test
sinktest3 = TestCase (assertBool "Handles no data"
  (case (runIdentity $ (sourceList []) C.$$ (sinkGet getWord8)) of
    Right _ -> False
    Left _ -> True))

sinktest4 :: Test
sinktest4 = TestCase (assertEqual "Consumes no data"
  (Right ())
  (runIdentity $ (sourceList [BS.pack [1]]) C.$$ (sinkGet $ return ())))

sinktest5 :: Test
sinktest5 = TestCase (assertEqual "Empty list"
  (Right ())
  (runIdentity $ (sourceList []) C.$$ (sinkGet $ return ())))

twoItemGet :: Get Word8
twoItemGet = do
  x <- getWord8
  y <- getWord8
  return $ x + y

conduittest1 :: Test
conduittest1 = TestCase (assertEqual "Handles starting with empty bytestring"
  (Right [])
  ((sourceList [BS.pack [], BS.pack [1]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest2 :: Test
conduittest2 = TestCase (assertEqual "Works when the get is split across items"
  (Right [3])
  ((sourceList [BS.pack [1], BS.pack [2]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest3 :: Test
conduittest3 = TestCase (assertEqual "Works when empty bytestring in middle of get"
  (Right [3])
  ((sourceList [BS.pack [1], BS.pack [], BS.pack [2]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest4 :: Test
conduittest4 = TestCase (assertEqual "Works when empty bytestring at end of get"
  (Right [3])
  ((sourceList [BS.pack [1, 2], BS.pack []]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest5 :: Test
conduittest5 = TestCase (assertEqual "Works when multiple gets are in an item"
  (Right [3, 7])
  ((sourceList [BS.pack [1, 2, 3, 4]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest6 :: Test
conduittest6 = TestCase (assertEqual "Works with leftovers"
  (Right [3])
  ((sourceList [BS.pack [1, 2, 3]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest7 :: Test
conduittest7 = let c = 10 in TestCase (assertEqual "Works with infinite lists"
  (Right $ L.replicate c ())
  ((sourceList [BS.pack [1, 2, 3]]) C.$= conduitGet (return ()) C.$$ take c))

conduittest8 :: Test
conduittest8 = let c = 10 in TestCase (assertEqual "Works with empty source and infinite lists"
  (Right $ L.replicate c ())
  ((sourceList []) C.$= conduitGet (return ()) C.$$ take c))

conduittest9 :: Test
conduittest9 = let c = 10 in TestCase (assertEqual "Works with two well-placed items"
  (Right [3, 7])
  ((sourceList [BS.pack [1, 2], BS.pack [3, 4]]) C.$= conduitGet twoItemGet C.$$ consume))

conduittest10 :: Test
conduittest10 = TestCase (assertBool "Failure works"
  (case (sourceList [BS.pack [1, 2], BS.pack [3, 4]]) C.$= conduitGet (getWord8 >> fail "omfg") C.$$ consume of
    Left _ -> True
    Right _ -> False))

conduittest11 :: Test
conduittest11 = TestCase (assertBool "Immediate failure works"
  (case (sourceList [BS.pack [1, 2], BS.pack [3, 4]]) C.$= conduitGet (fail "omfg") C.$$ consume of
    Left _ -> True
    Right _ -> False))

conduittest12 :: Test
conduittest12 = TestCase (assertBool "Immediate failure with empty input works"
  (case (sourceList []) C.$= conduitGet (fail "omfg") C.$$ consume of
    Left _ -> True
    Right _ -> False))

sinktests = TestList [ sinktest1
                     , sinktest2
                     , sinktest3
                     , sinktest4
                     , sinktest5
                     ]

conduittests = TestList [ conduittest1
                        , conduittest2
                        , conduittest3
                        , conduittest4
                        , conduittest5
                        , conduittest6
                        , conduittest7
                        , conduittest8
                        , conduittest9
                        , conduittest10
                        , conduittest11
                        , conduittest12
                        ]

hunittests = TestList [sinktests, conduittests]

--tests = hUnitTestToTests hunittests

main = do
  counts <- runTestTT hunittests
  if errors counts == 0 && failures counts == 0
    then exitSuccess
    else exitFailure
