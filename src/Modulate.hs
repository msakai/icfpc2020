{-# LANGUAGE OverloadedStrings #-}

module Modulate
  ( modulate
  , modulate_
  , demodulate
  , demodulate_
  ) where

import Control.Applicative
import Data.Maybe (listToMaybe)
import Data.Attoparsec.ByteString.Lazy
  (Parser, parse, eitherResult)
import qualified Data.Attoparsec.ByteString.Char8 as A8

import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy.Char8 as L8 hiding (take, takeWhile)


import Numeric (showIntAtBase, readInt)

import Message (Expr (..), Prim (..))


-- | XXX
-- >>> modulate (Prim (Num 0))
-- "010"
--
-- >>> modulate (Prim Nil)
-- "00"
--
-- >>> modulate (Ap (Ap (Prim Cons) (Prim Nil)) (Prim Nil))
-- "110000"
--
-- >>> modulate (Prim (Num 1))
-- "01100001"
--
-- >>> modulate (Prim (Num (-1)))
-- "10100001"
--
-- >>> modulate (Ap (Ap (Prim Cons) (Prim (Num 1))) (Ap (Ap (Prim Cons) (Prim (Num 2))) (Prim Nil)))
-- "1101100001110110001000"
modulate :: Expr -> String
modulate e =
  either (error $ "modulate: unknown expr to modulate!: " ++ show e) id $
  modulate_ e

modulate_ :: Expr -> Either String String
modulate_ (Prim (Num n))     = Right $ modulateNum n
modulate_ (Prim Nil)         = Right "00"
modulate_ (Ap(Prim  Cons) e) = (++) "11" <$> modulate_ e
modulate_ (Ap e1 e2)         = (++) <$> modulate_ e1 <*> modulate_ e2
modulate_  e                 = Left $ "modulate: unknown expr to modulate!: " ++ show e


modulateNum :: Int -> String
modulateNum n =
    sn ++ ['1'|_<-[1..len]] ++ ('0': (if n==0 then "" else num))
  where
    sn = if signum n >= 0 then "01" else "10"
    len = length $ takeWhile (>0) $ iterate (`div`16) (abs n)
    num = reverse $ take (4*len) $ (reverse $ showIntAtBase 2 toChar (abs n) "") ++ (repeat '0')

toChar :: Int -> Char
toChar 0 = '0'
toChar _ = '1'

toInt :: Char -> Int
toInt '0' = 0
toInt _   = 1


-- | XXX
-- >>> demodulate "00"
-- Right (Prim Nil)
--
-- >>> demodulate "010"
-- Right (Prim (Num 0))
--
-- >>> demodulate "10100001"
-- Right (Prim (Num (-1)))
--
-- >>> demodulate "110000"
-- Right (Ap (Ap (Prim Cons) (Prim Nil)) (Prim Nil))
--
-- >>> demodulate "1101100001110110001000"
-- Right (Ap (Ap (Prim Cons) (Prim (Num 1))) (Ap (Ap (Prim Cons) (Prim (Num 2))) (Prim Nil)))
--
demodulate :: String -> Either String Expr
demodulate = demodulate_ . L8.pack

demodulate_ :: L8.ByteString -> Either String Expr
demodulate_ = eitherResult . parse demodP


demodP :: Parser Expr
demodP = A8.choice
  [ A8.string "00" *> pure (Prim Nil)
  , A8.string "11" *> (Ap <$> Ap (Prim Cons) <$> demodP <*> demodP)
  , demodNumP
  ]

demodNumP :: Parser Expr
demodNumP = do
  sig <- (A8.string "01" *> pure 1) <|> (A8.string "10" *> pure (-1))
  len <- (4*) . B.length <$> A8.takeWhile (=='1')
  _ <- A8.char '0'
  if len == 0
    then pure (Prim (Num 0))
    else do
    bstr <- B.unpack <$> A8.take len
    maybe (fail "readInt 2 failed.") (return . Prim . Num . (*sig))
      $ listToMaybe [ i | (i, "") <- readInt 2 (`elem`("01"::String)) toInt bstr ]
