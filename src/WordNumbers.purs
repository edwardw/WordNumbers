-- | This is a purescript reimplementation of a series of blog posts:
-- |    part 1: http://conway.rutgers.edu/~ccshan/wiki/blog/posts/WordNumbers1/
-- |    part 2: http://conway.rutgers.edu/~ccshan/wiki/blog/posts/WordNumbers2/
-- |    part 3: http://conway.rutgers.edu/~ccshan/wiki/blog/posts/WordNumbers3/
-- |    part 4: http://conway.rutgers.edu/~ccshan/wiki/blog/posts/WordNumbers4/
-- | in which the following problem is tackled:
-- |    If the integers from 1 to 999,999,999 are written as words, sorted alphabetically,
-- |    and concatenated, what is the 51 billionth letter?

module WordNumbers where

import Prelude hiding ((*>), (<*))
import Data.Array as A
import Data.BigInt (BigInt, fromInt, fromString, toNumber)
import Data.Either (Either(..), note)
import Data.Foldable (foldr)
import Data.Int as Int
import Data.Lazy (Lazy, defer, force)
import Data.List.Lazy as ZL
import Data.Map as M
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap, wrap)
import Data.String as String
import Data.String.CodeUnits (fromCharArray, toCharArray)
import Data.String.Utils (words)
import Data.Tuple (Tuple(..), fst, snd)
import Data.Typelevel.Undefined (undefined)

-- | Part 1. Write the problem down as a program, specifically, exploring the algebraic
-- | structure of the problem and expressing it in purescript.

-- A lazy list of string. Helps to overcome the orphan rules.
newtype ZSL = ZSL (ZL.List (Array Char))

derive instance eqZSL :: Eq ZSL

derive instance newtypeZString :: Newtype ZSL _

instance showZString :: Show ZSL where
  show = show <<< A.fromFoldable <<< map fromCharArray <<< unwrap

instance semiringZSList :: Semiring ZSL where
  zero = wrap ZL.nil
  one = wrap $ ZL.singleton []
  add x y = wrap $ (unwrap x ) <> (unwrap y)
  mul xss yss = wrap $ ado
    xs <- unwrap xss
    ys <- unwrap yss
    in xs <> ys

-- The semiring above is generated by characters: every character maps to an element
-- of this semiring. Let us represent this property by a type class.
class Character a where
  char :: Char -> a

instance characterChar :: Character Char where
  char = identity

instance characterArray :: Character a => Character (Array a) where
  char c = [char c]

instance characterList :: Character a => Character (ZL.List a) where
  char = ZL.singleton <<< char

instance characterZSL :: Character ZSL where
  char = wrap <<< char

-- Now we can extend this mapping from characters to strings by concatenating (multiplying)
-- its output.
product :: forall a. Semiring a => Array a -> a
product = foldr (*) one

string :: forall a. Semiring a => Character a => String -> a
string = product <<< map char <<< toCharArray

-- We can now express a choice of strings, such as a digit between "one" and "three",
-- not just as a list of strings but generically as a value of any type that is an instance
-- of Semiring and Character:
--    onetwothree :: forall a. Semiring a => Character a => a
--    onetwothree = string "one" + string "two" + string "three"

-- We can specify a choice of words more concisely as a space-delimited string.
sum :: forall a. Semiring a => ZL.List a -> a
sum = foldr (+) zero

strings :: forall a. Semiring a => Character a => String -> a
strings = sum <<< A.toUnfoldable <<< map string <<< words

-- Finally we can concisely define the list of 999,999,999 strings at the core of the problem,
-- in a way that expresses its repetitive structure.
-- Isn't algebra elegant?
ten1 :: forall a. Semiring a => Character a => a
ten1 = strings "one two three four five six seven eight nine"

ten2 :: forall a. Semiring a => Character a => a
ten2 = ten1
  + strings "ten eleven twelve"
  + (strings "thir four" + prefixes) * string "teen"
  + (strings "twen thir for" + prefixes) * string "ty" * (one + ten1)
  where prefixes = strings "fif six seven eigh nine"

ten3 :: forall a. Semiring a => Character a => a
ten3 = ten2 + ten1 * string "hundred" * (one + ten2)

ten6 :: forall a. Semiring a => Character a => a
ten6 = ten3 + ten3 * string "thousand" * (one + ten3)

ten9 :: forall a. Semiring a => Character a => a
ten9 = ten6 + ten3 * string "million" * (one + ten6)

-- Notice these definitions are abstract thus independent of `ZSL` above.
-- However, `ZSL` can be seen as the first interpretation we write for the problem
-- which serves as means of debug and sanity check:
--
--    ```
--    PSCi, version 0.13.6
--    Type :? for help
--    > import Prelude
--    > import Data.Array as A
--    > import Data.Foldable (foldr)
--    > import Data.List.Lazy as ZL
--    > import Data.Newtype
--    > import Data.String.CodeUnits (fromCharArray)
--    > import WordNumbers
--    > ZL.length $ unwrap (ten6 :: ZSL)
--    999999
--    > map fromCharArray <<< ZL.head $ unwrap (ten6 :: ZSL)
--    (Just "one")
--    > map fromCharArray <<< ZL.last $ unwrap (ten6 :: ZSL)
--    (Just "ninehundredninetyninethousandninehundredninetynine")
--    > foldr (+) 0 <<< map A.length $ unwrap (ten6 :: ZSL)
--    44872000
--    ```
--
-- The same check on `ten9` causes gc error though. We have to do better.


-- | Part 2. We will start to solve the problem efficiently, starting by counting
-- | the total length of all strings in `ten9`. The key idea is to think of converting
-- | lists of strings to polynomials, where each character gets mapped to the variable x,
-- | a string of length n gets mapped to x^n, and a list of strings gets mapped to a sum.
-- | Thus instead of a list of strings starting
-- |
-- |    ["one","two","three","four","five",...]
-- |
-- | we get a polynomial whose first few terms are
-- |
-- |    x^3 + x^3 + x^5 + x^4 + x^4 + ...
-- |
-- | If wen evaluate this polynomial at x = 1, we get the total number of terms, which is
-- | not terribly interesting. If we take the derivative first, we get
-- |
-- |    3x^2 + 3x^2 + 5x^4 + 4x^3 + 4x^3 + ...
-- |
-- | Now the evaluation at x = 1 gives the total length of all strings, as desired.
-- | That's where the idea of automatic differentiation comes in.
newtype Nat a = Nat a
type Count = Nat BigInt

derive instance eqNat :: Eq a => Eq (Nat a)

derive instance ordNat :: Ord a => Ord (Nat a)

instance showNat :: Show a => Show (Nat a) where
  show (Nat x) = show x

instance semiringNat :: Semiring (Nat BigInt) where
  zero = Nat zero
  one = Nat one
  add (Nat a) (Nat b) = Nat (a + b)
  mul (Nat a) (Nat b) = Nat (a * b)

instance characterNat :: Character (Nat BigInt) where
  char _ = one

-- Now we can count the total number of terminals easily in the grammar for `ten9`:
--
--    ```
--    > import WordNumbers
--    > (ten9 :: Count)
--    fromString "999999999"
--    ```

-- In general, the derivatives need to be a *module* over the scalars (the base semiring),
-- with addition (a monoid structure), and multiplication by scalars.
class (Semiring r, Semiring m) <= Module r m where
  applySecond :: r -> m -> m
  applyFirst :: m -> r -> m

infixl 4 applySecond as *>
infixl 4 applyFirst as <*

-- A derivative is a pair of a value and a derivative.
data Deriv r m = Deriv r m

derive instance eqDeriv :: (Eq r, Eq m) => Eq (Deriv r m)

instance showDeriv :: (Show r, Show m) => Show (Deriv r m) where
  show (Deriv r m) = "Deriv " <> show r <> " " <> show m

-- It satisfies the usual law for addition and Leibniz’s rule for multiplication.
instance semiringDeriv :: Module r m => Semiring (Deriv r m) where
  zero = Deriv zero zero
  one = Deriv one zero
  add (Deriv c1 m1) (Deriv c2 m2)
    = Deriv (c1 + c2) (m1 + m2)
  mul (Deriv c1 m1) (Deriv c2 m2)
    = Deriv (c1 * c2) ((c1 *> m2) + (m1 <* c2))

instance characterDeriv :: (Character r, Character m) => Character (Deriv r m) where
  char c = Deriv (char c) (char c)

-- To actually use these derivatives, we introduce a wrapper type to keep track of the units.
newtype Wrap s a = Wrap a

derive instance eqWrap :: Eq a => Eq (Wrap s a)

derive instance ordWrap :: Ord a => Ord (Wrap s a)

instance showWrap :: Show a => Show (Wrap s a) where
  show (Wrap x) = show x

instance semiringWrap :: Semiring a => Semiring (Wrap s a) where
  zero = Wrap zero
  one = Wrap one
  add (Wrap a) (Wrap b) = Wrap (a + b)
  mul (Wrap a) (Wrap b) = Wrap (a * b)

instance moduleWrap :: Semiring a => Module a (Wrap s a) where
  applySecond r (Wrap m) = Wrap (r * m)
  applyFirst (Wrap m) r = Wrap (m * r)

-- Here the units are numbers of characters, which we call volume.
data V
type Volume = Wrap V (Nat BigInt)

-- Each character has length one.
instance characterVolume :: Character (Wrap V (Nat BigInt)) where
  char _ = one

-- Check the progress again:
--
--    ```
--    > import WordNumbers
--    > (ten9 :: Deriv Count Volume)
--    Deriv fromString "999999999" fromString "70305000000"
--    ```
-- This is the second interpretation of the grammar. It makes counting length and
-- total length of all strings in `ten9` very cheap.


-- | Part 3. We will try to solve a slightly easier version of the problem:
-- |    If the integers from 1 to 999,999,999 are written as words in order and
-- |    concatenated, what is the 51 billionth letter?
-- | We solve this one by keeping track a binary tree corresponding to the productions
-- | in the grammar, computing the total length of each production and doing a search
-- | in this tree.
data Binary m =
  Binary m (Maybe (Tpl (Lazy (Binary m))
                       (Lazy (Binary m))))

newtype Tpl a b = Tpl (Tuple a b)

derive instance newtypeTpl :: Newtype (Tpl a b) _

derive instance eqTpl :: (Eq a, Eq b) => Eq (Tpl a b)

-- Characters create leaf nodes.
instance characterBinary :: Character m => Character (Binary m) where
  char c = Binary (char c) Nothing

-- The addition (i.e., alternate possibilities in the grammar) creates a branch.
-- The multiplication operation is a little more subtle, since we multiply two trees,
-- either of which may branch. We use left-to-right evaluation, taking by preference
-- the branches of the left tree.
instance semiringBinary :: Semiring m => Semiring (Binary m) where
  zero = Binary zero Nothing
  one = Binary one Nothing
  add b1@(Binary m1 _) b2@(Binary m2 _) =
    Binary
      (m1 + m2)
      (Just <<< wrap $ (Tuple (defer \_ -> b1)
                              (defer \_ -> b2)))
  mul b1@(Binary m1 c1) b2@(Binary m2 c2) =
    Binary
      (m1 * m2)
      ( case c1 of
          Just (Tpl t) -> Just <<< wrap $ Tuple (defer \_ -> force (fst t) * b2)
                                                (defer \_ -> force (snd t) * b2)
          Nothing -> case c2 of
            Nothing -> Nothing
            Just (Tpl t) -> Just <<< wrap $ Tuple (defer \_ -> b1 * force (fst t))
                                                  (defer \_ -> b1 * force (snd t))
      )

-- We will use these trees to keep track of the count and volume of the productions
-- (as in part 2), as well as the list of strings (so that we can see what letter we get).
type MeasureUnsorted = Tpl ZSL (Deriv Count Volume)

instance characterTuple :: (Character a, Character b) => Character (Tpl a b) where
  char c = wrap $ Tuple (char c) (char c)

instance semiringTuple :: (Semiring a, Semiring b) => Semiring (Tpl a b) where
  zero = wrap $ Tuple zero zero
  one = wrap $ Tuple one one
  add (Tpl t1) (Tpl t2) = wrap $ Tuple (fst t1 + fst t2) (snd t1 + snd t2)
  mul (Tpl t1) (Tpl t2) = wrap $ Tuple (fst t1 * fst t2) (snd t1 * snd t2)

deriv :: Binary MeasureUnsorted -> Deriv Count Volume
deriv (Binary (Tpl (Tuple _ b)) _) = b

volume :: Deriv Count Volume -> BigInt
volume (Deriv _ (Wrap (Nat v))) = v

searchUnsorted :: Binary MeasureUnsorted -> BigInt -> MeasureUnsorted
searchUnsorted (Binary m Nothing) _ = m
searchUnsorted (Binary _ (Just (Tpl (Tuple a b)))) i
  | a' <- force a, i < volume (deriv a') = searchUnsorted a' i
  | otherwise = wrap $ Tuple (fst x) (skip + snd x)
    where
    skip = deriv (force a)
    Tpl x = searchUnsorted (force b) (i - volume skip)

answerUnsorted :: BigInt -> Array String
answerUnsorted n = [before, self, after']
  where
    target = n - fromInt 1
    Tpl (Tuple (ZSL a) b) = searchUnsorted ten9 target
    end = volume b
    str = case ZL.head a of
      Nothing -> ""
      Just s -> fromCharArray s
    local = Int.floor $ toNumber $ fromInt (String.length str) - (end - target)
    { before, after } = String.splitAt local str
    { before: self, after: after' } = String.splitAt 1 after

-- Hurray! We are getting somewhere. Now it is time to do some serious computing:
--
--    ```
--    > import Prelude
--    > import Data.BigInt
--    > import WordNumbers
--    > map answerUnsorted $ fromString "51000000000"
--    (Just ["sevenhundredthirtytwomil","l","ionsevenhundredninetysixthousandthreehundredsixtysix"])
--    ```
-- In this third interpretation of the grammar, we solve the problem in a weakened form, i.e. without
-- the sorting.


-- | Part 4. To sort our 999,999,999 strings in alphabetically order, we use a trie:
-- |              _____
-- |             /     \
-- |         'o'/       \'t'
-- |           /         \
-- |          |          /\
-- |       'n'|      'h'/  \'w'
-- |          |        /    \
-- |          |       |      |
-- |       'e'|    'r'|      |'o'
-- |        "one"     |      |
-- |                  |    "two"
-- |               'e'|
-- |                  |
-- |                  |
-- |               'e'|
-- |                  |
-- |               "three"
-- |
-- | That is, we group the strings by their first letter, then further divide each group of strings
-- | by their second letter, and so on. The result is a tree whose edges are each labeled by a letter
-- | and whose nodes are strings. Thus a trie.
data Trie c m
  = Trie { total :: m
         , label :: m
         , children :: ZMap c (Trie c m)
         }

derive instance eqTrie :: (Eq c, Eq m) => Eq (Trie c m)

instance showTrie :: (Show c, Show m) => Show (Trie c m) where
  show (Trie t) =
    "Trie { total = "
    <> show t.total
    <> ", label = "
    <> show t.label
    <> ", children = "
    <> show (unwrap t.children)
    <> " }"

-- A map with lazy values.
newtype ZMap k v = ZMap (M.Map k (Lazy v))

derive instance newtypeMap :: Newtype (ZMap k v) _

derive instance eqNTMap :: (Eq c, Eq m) => Eq (ZMap c m)

-- `Data.Lazy.Lazy` is an instance of `Semiring`, so we get `add` for free.
instance semiringZMap :: (Ord k, Semiring v) => Semiring (ZMap k v) where
  zero = wrap M.empty
  one = undefined
  add (ZMap a) (ZMap b) = wrap $ M.unionWith add a b
  mul = undefined

instance functorZMap :: Functor (ZMap k) where
  map f = wrap <<< map (\x -> (defer \_ -> f $ force x)) <<< unwrap

instance moduleMap :: (Ord k, Eq v, Semiring v) => Module v (ZMap k v) where
  applySecond r (ZMap m)
    | r == zero = wrap M.empty
    | otherwise = wrap $ map (\x -> defer \_ -> r * (force x)) m
  applyFirst (ZMap m) r
    | r == zero = wrap M.empty
    | otherwise = wrap $ map (\x -> defer \_ -> (force x) * r) m

instance characterTrie :: (Semiring m, Character m) => Character (Trie Char m) where
  char c =
    Trie
      { total: r
      , label: zero
      , children: wrap $ M.singleton c (defer \_ -> Trie { total: r
                                                         , label: r
                                                         , children: wrap M.empty
                                                         })
      }
    where
    r = char c

instance semiringTrie :: (Ord c, Eq m, Semiring m) => Semiring (Trie c m) where
  -- Be careful, in the original post, the `Monoid` and `Seminearring` are
  -- defined separately. The `Monoid` type class defines `zero` and `add`,
  -- whereas the `Seminearring` defines `one` and `mul`. If the following
  -- `children` field were to be set as `zero`, there would be a circular
  -- definition. It would blow up the stack right away.
  -- Should the compiler treat such circular definition as error?
  zero = Trie { total: zero, label: zero, children: wrap M.empty }
  one = Trie { total: one, label: one, children: wrap M.empty }
  add (Trie t1) (Trie t2) =
    Trie
      { total: t1.total + t2.total
      , label: t1.label + t2.label
      , children: t1.children + t2.children
      }
  mul (Trie t1) r@(Trie t2) =
    Trie
      { total: t1.total * t2.total
      , label: t1.label * t2.label
      , children: (t1.children <* r) + (r' *> t2.children)
      }
    where
    r' = Trie { total: t1.label
              , label: t1.label
              , children: wrap M.empty
              } :: Trie c m

search :: forall m. Semiring m
       => (m -> Boolean)
       -> Trie Char m
       -> Either String (Tuple String m)
search stop = searchTrie ZL.nil zero
  where
  searchTrie cs m (Trie t)
    | m' <- m + t.label, stop m' =
      Right $ Tuple (fromCharArray $ ZL.toUnfoldable $ ZL.reverse cs) m'
    | m' <- m + t.label, otherwise =
      searchMap cs m' (M.toUnfoldable $ unwrap t.children)

  searchMap cs m cts = case ZL.uncons cts of
    Just { head: Tuple c t, tail } ->
      if stop m' then
        searchTrie (c ZL.: cs) m ft
      else
        searchMap cs m' tail
      where
      ft@(Trie t') = force t
      m' = m + t'.total
    Nothing -> Left "Fell off the edge of a child list"

-- Progress checking:
--
--    ```
--    > import Prelude
--    > import Data.BigInt
--    > import Data.Either (note)
--    > import WordNumbers
--    > note "" (fromString "51000000000") >>= \i -> search ((_ >= i) <<< volume) ten9
--    (Right (Tuple "sixhundredseventysixmillionsevenhundredfortysixthousandfivehundredseventyfive" Deriv fromString "723302492" fromString "51000000000"))
--
-- It works smoothly! But there's more to the original problem:
--
--    Which one, and what is the sum of all the integers to that point?
--
-- To answer that, we need to keep track of the sum of a set of integers in addition to count and volume.
-- We call this sum the *mass*. Luckily for us. the same derivative trick also works here:
--
--    ["one","two","three","four",...]
--
-- can be treated as a polynomial of two variables x and y, whose first few terms are:
--
--    x^3y^1 + x^3y^2 + x^5y^3 + x^4y^4 + ...
--
-- If we evaluate its derivative with respect to y at x = y = 1, we get the mass.
data M

type Mass = Wrap M (Nat BigInt)

type Measure = Deriv Count (Tpl Volume Mass)

instance moduleTpl :: (Module r a, Module r b) => Module r (Tpl a b) where
  applySecond r (Tpl (Tuple a b)) =
    wrap $ Tuple (r *> a) (r *> b)
  applyFirst (Tpl (Tuple a b)) r =
    wrap $ Tuple (a <* r) (b <* r)

-- A letter by itself has no mass.
instance characterMass :: Character (Wrap M (Nat BigInt)) where
  char _ = zero

-- A new semiring to track the order of the strings and assigns the first string in the list the mass 0,
-- the second the mass 1, and so on.
newtype Numbered c = Numbered (Trie c Measure)

instance characterNumbered :: Character (Numbered Char) where
  char = Numbered <<< char

-- When adding two lists of strings together, the mass of each string in the second list increases
-- by the number of strings in the first list.
-- When multiplying, the mass of each string in the first list is scaled by the number of strings
-- in the second list.
instance semiringNumbered :: Ord c => Semiring (Numbered c) where
  zero = Numbered zero
  one = Numbered one
  add (Numbered a) (Numbered b) =
    Numbered (a + map f b)
    where
    Trie a' = a
    Deriv n _ = a'.total
    f (Deriv c (Tpl (Tuple v m))) = Deriv c (Tpl (Tuple v (Wrap (c * n) + m)))
  mul (Numbered a) (Numbered b) =
    Numbered (map f a * b)
    where
    Trie b' = b
    Deriv n _ = b'.total
    f (Deriv c (Tpl (Tuple v m))) = Deriv c (Tpl (Tuple v (m <* n)))

instance functorTrie :: Functor (Trie c) where
  map f (Trie { total, label, children }) =
    Trie
      { total: f total
      , label: f label
      , children: map (map f) children
      }

-- Finally, we are near the end of the journey. One detail: because our list of strings begins at “one”
-- rather than “zero”, we prepend an empty string (“one +”) to correct the masses.
answer :: Either String (Tuple String BigInt)
answer = note "Wrong big integer?" (fromString "51000000000") >>= answer'
  where
  answer' target =
    let
      Numbered grammar = one + ten9
      vol (Deriv _ (Tpl (Tuple (Wrap (Nat n)) _))) = n
      mass (Deriv _ (Tpl (Tuple _ (Wrap (Nat n))))) = n
      stop m = vol m >= target
      g (Tuple it m) =
        if target == vol m then
          Right $ Tuple it (mass m)
        else
          Left "The target letter does not end a string"
    in search stop grammar >>= g

-- The fourth and the final interpretation solves the problem in full.
--
-- This is pretty satisfying. Only the polynomial interpretation of a list of strings, the automatic
-- derivative, and the abstract algebra all coming together enables such an elegant solution. In the
-- end, one can't stop wondering what is data and what is program? The boundary is blurred. And is
-- this a manifestation of the Curry-Howard correspondence? The functions here can't be run in our
-- head any more, or at least very difficult to do; they read more like mathematical equations and
-- theorems now.
--
-- Also, in this setting, the lazy evaluation is crucial. Contrary to what I have led to believe,
-- the laziness *saves* memory here. In part 3 and 4, the binary tree and ordered map have to be
-- sprinkled with `Lazy` type, otherwise gc error ensues.
--
-- QED.
