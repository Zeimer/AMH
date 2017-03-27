{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}
import Problem

import Control.Monad
import Data.Random.Normal
import Control.Concurrent
import System.IO

type Fuel = Int

data Domain a b = Domain
	{ size :: Size
	, curIter :: Int
	, maxIter :: Int
	, curPath :: a
	, bestPath :: b
	, logging :: Bool
	}

instance Show (Domain Path Path) where
	show dom = "size = " ++ (show $ size dom) ++ ", iter = " ++ (show $ curIter dom) ++ "/" ++ (show $ maxIter dom) ++ ", curPath = " ++ (show $ pathLen $ curPath dom) ++ ", bestPath = " ++ (show $ pathLen $ bestPath dom)

instance Show (Domain Path [Path]) where
	show dom = "size = " ++ (show $ size dom) ++ ", iter = " ++ (show $ curIter dom) ++ "/" ++ (show $ maxIter dom) ++ ", curPath = " ++ (show $ pathLen $ curPath dom) ++ ", bestPath = " ++ (show $ pathLen $ head $ bestPath dom)

type Init a b = IO (a, b)
type Tweak a = forall b. Domain a b -> IO a
type Select b = forall a. Domain a b -> b -> b
type Restart a = forall b. Domain a b -> IO a

climb :: Init Path Path -> Tweak Path -> Select Path -> Domain Path Path -> MVar Float -> IO Path
climb init tweak select dom mvwrite = do
	(curPath, bestPath) <- init
	putMVar mvwrite $ pathLen bestPath

	climb' 0 tweak select $ dom {curPath = curPath, bestPath = bestPath} where

	climb' n tweak select dom = do
		if n > maxIter dom
		then return $ bestPath dom
		else do
			new <- tweak dom
			when ({-new <= bestPath dom &&-} logging dom) $ do
				hPutStrLn stderr $ show dom
			when (new <= bestPath dom) $ do
				tryTakeMVar mvwrite
				tryPutMVar mvwrite $ pathLen new -- putMVar
				return ()

			climb' (n + 1) tweak select $ dom {curIter = curIter dom + 1, bestPath = min new $ bestPath dom, curPath = select dom new}

randomTweak :: Int -> Tweak Path
randomTweak numOfSwaps dom = iterM numOfSwaps (swap $ size dom) (curPath dom)

bestNeighbour :: Int -> Size -> Tweak Path
bestNeighbour times size dom = liftM minimum $ replicateM times $ swap size (curPath dom) -- bestPath: 2 and 1

normalNeighbour :: Int -> Size -> Tweak Path
normalNeighbour times size dom = do
	let stddev = 1 / (fromIntegral size)
	r <- normalIO' (0.0, 1 + stddev) :: IO Float -- beware 1 + 
	let n = floor $ 1 + 20 * abs r
	liftM minimum $ replicateM times $ swap size (curPath dom)

swapN :: Int -> Size -> Path -> IO Path
swapN n size p = iterM n (swap size) p

replace :: Select b
replace _ new = new

climbR :: Int -> Init Path [Path] -> Tweak Path -> Select [Path] -> Restart Path -> Domain Path [Path] -> IO Path
climbR n init tweak select restart dom = do
	(initPath, _) <- init
	climbR' tweak select $ dom {curPath = initPath} where

	climbR' :: Tweak Path -> Select [Path] -> Domain Path [Path] -> IO Path
	climbR' tweak select dom = do
		if curIter dom > maxIter dom
		then return $ head $ bestPath dom
		else
			if (take n $ bestPath dom) == (replicate n (head $ bestPath dom))
			then do --climbR n init tweak select $ dom {bestPath = [head $ bestPath dom]}
				restartPath <- restart dom
				putStrLn $ "GONNA RESTART!"
				climbR' tweak select $ dom {curPath = restartPath, bestPath = [head $ bestPath dom]}
			else do
				new <- tweak dom
				when (logging dom) $ do
					putStrLn $ show dom

				climbR' tweak select $ dom {curIter = curIter dom + 1, bestPath = min new (head $ bestPath dom) : bestPath dom, curPath = head $ select dom [new]}


sleepMs :: Int -> IO ()
sleepMs n = threadDelay (n * 1000)

wut :: MVar Float -> Float -> IO ThreadId
wut mv acc = do
	sleepMs 1000
	len <- tryTakeMVar mv
	case len of
		Nothing -> do
			putStrLn $ show acc
			wut mv acc
		Just len' -> do
			putStrLn $ show len'
			wut mv len'

main = do
	(size, initPath) <- readInput

	let p = initPath

	let	dom = Domain {size = size, curIter = 0, maxIter = 3 + size, curPath = p, bestPath = p, logging = True}
		init = do
			p' <- iterM size (swap (20 + size `div` 2)) p
			return (p', p')
		--init = return (p, p)

		tweak = bestNeighbour 50 size
		select = replace

	{-mvwrite <- newEmptyMVar

	putMVar mvread $ 0.0

	forkIO $ climb init tweak select dom mvwrite >> return ()

	--putStrLn $ "climb (bestNeighbour 5) replace"
	--forkIO $ wut mvwrite 0.0 >> return ()
	--climb init tweak select dom mvwrite >> return ()


	-- wut mvwrite 0.0

	--m <- climb tweak select dom-}


	--m' <- liftM minimum $ replicateM 10 $ climb (iterM size (swap size) p) tweak select $ dom {logging = False}
	--putStrLn $ "With restarts: " ++ (show $ pathLen m')

	(p', _) <- init

	let	dom = Domain {size = size, curIter = 0, maxIter = 3 + size, curPath = p', bestPath = [p'], logging = True}
	--	init = return (p, [p])
		init' = return (p', [p']) --init >>= \(x, y) -> return (x, [y])
		tweak = bestNeighbour 100 size
		select = replace
		restart dom = iterM 2 (swap size) $ curPath dom

	

	mR <- climbR size init' tweak select restart dom

	return ()
