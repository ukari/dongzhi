module Lib
  ( someFunc,
  )
where

someFunc :: IO ()
someFunc = let a = 0 :: Int in
    do
        b <- return 1 :: IO Int
        putStrLn $ show (a + b) ++ "someFunc"
