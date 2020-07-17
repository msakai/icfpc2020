module Message (
  Node (..),
  Token (..),
  Expr (..),
  toExpr,
  ) where

import Control.Applicative (empty)
import Control.Monad.Trans.State (StateT, runStateT, get, put)

import qualified Data.Tree as T

-----

data Node
  = Num Int
  | Var Int
  | Eq | Lt          -- 2 args
  | Succ | Pred      -- 1 arg
  | Add | Mul | Div  -- 2 arg
  | Mod | Dem        -- 1 arg
  | Send             -- 1 arg
  | Neg              -- 1 arg
  | S | C | B        -- 3 arg
  | T {- True, K combinator -} | F {- False, flip K -}  -- 2 arg
  | Pow2             -- 1 arg
  | I                -- 1 arg
  | Cons             -- 3 arg
  | Car | Cdr        -- 1 arg
  | Nil | IsNil      -- 1 arg
  | If0              -- 3 arg
  | Draw             -- 1 arg
  | Chkb             -- 2 arg
  | MulDraw          -- 1 arg
  | Apply            -- 2 arg
  deriving (Eq, Show)

data Token
  = TArg Node
  | TAp
  deriving (Eq, Show)

data Expr
  = Arg Node
  | Ap Expr Expr
  deriving (Eq, Show)

cataExpr :: (Node -> t) -> (t -> t -> t) -> Expr -> t
cataExpr f g = u
  where u (Arg a) = f a
        u (Ap l r) = g (u l) (u r)

-----

type Parser = StateT [Token] Maybe

runParser :: Parser a -> [Token] -> Maybe (a, [Token])
runParser = runStateT

token :: Parser Token
token = do
  tts <- get
  case tts of
    []    ->  empty
    t:ts  ->  put ts *> pure t

eof :: Parser ()
eof = do
  tts <- get
  case tts of
    []   ->  pure ()
    _:_  ->  empty

-----

expr :: Parser Expr
expr = do
  t <- token
  case t of
    TArg n -> pure (Arg n)
    TAp    -> Ap <$> expr <*> expr

toExpr :: [Token] -> Maybe Expr
toExpr = (fst <$>) . runParser (expr <* eof)

-- data Value = Val Node | Fun (Value -> Value)

-- FORMULA --> WHNF

{-
eval :: Expr -> Expr
eval e@(Arg _)  = e
eval (Ap {}) = undefined
  where
    eval1 e0@(Ap f e) = case eval f of
      w@(Ap {}) -> Ap w e1
      Arg n    -> case n of
        Succ     -> case e1 of
          Arg (Num i) -> Arg $ Num $ succ i
          _           -> Ap (Arg Succ) e1
        Pred     -> case e1 of
          Arg (Num i) -> Arg $ Num $ pred i
          _           -> Ap (Arg Pred) e1
        I        -> eval e
        Car      -> eval $ Ap e $ Arg T
        Cdr      -> eval $ Ap e $ Arg F
        _        -> e0
      where
        e1 = eval e
 -}

-----

toDataTree :: Expr -> T.Tree String
toDataTree = cataExpr f g
  where f a = T.Node (show a) []
        g l r = T.Node (show Apply) [l, r]

draw :: Expr -> IO ()
draw = putStr . T.drawTree . toDataTree

-----

_example0 :: Maybe (Expr, [Token])
_example0 =
  runParser expr [TAp, TAp, TArg Add, TArg $ Num 1, TArg $ Num 2]

_drawExample41 :: IO ()
_drawExample41 = let Just e = toExpr [ TAp, TAp, TArg B, TAp, TArg B, TAp, TAp, TArg S, TAp
                                     , TAp, TArg B, TAp, TArg B, TAp, TArg Cons, TArg (Num 0)
                                     , TAp, TAp, TArg C, TAp, TAp, TArg B, TArg B, TArg Cons
                                     , TAp, TAp, TArg C, TArg Cons, TArg Nil, TAp,  TAp, TArg C
                                     , TArg Cons,  TArg Nil, TAp, TArg C, TArg Cons]
                 in draw e