namespace Shazdeh.Core
{
    /// <summary>
    /// FNV-1a over the board, the goals and the move count. Used by the determinism tests here and
    /// by the server to compare its replay against the hash the client submitted with a win.
    /// </summary>
    public static class StateHash
    {
        const ulong Offset = 14695981039346656037UL;
        const ulong Prime = 1099511628211UL;

        public static ulong Compute(LevelRun run)
        {
            if (run == null) return 0UL;

            ulong hash = Offset;
            hash = Mix(hash, 0xA1);
            hash = Mix(hash, (ulong)run.MovesLeft);
            hash = Mix(hash, (ulong)run.MovesUsed);
            hash = Mix(hash, (ulong)run.Status);
            hash = Mix(hash, run.Random.State);

            var board = run.Board;
            for (int y = 0; y < board.Height; y++)
            {
                for (int x = 0; x < board.Width; x++)
                {
                    var cell = board.At(x, y);
                    hash = Mix(hash, (ulong)((int)cell.Piece + 1));
                    hash = Mix(hash, (ulong)((int)cell.PowerUp + 1));
                    hash = Mix(hash, (ulong)((int)cell.Obstacle + 1));
                    hash = Mix(hash, (ulong)cell.ObstacleLayers);
                    hash = Mix(hash, cell.Blocked ? 1UL : 0UL);
                }
            }

            for (int i = 0; i < run.Goals.Count; i++)
            {
                hash = Mix(hash, (ulong)run.Goals.Progress(i));
                hash = Mix(hash, (ulong)run.Goals.Target(i));
            }

            return hash;
        }

        public static ulong Compute(Board board)
        {
            ulong hash = Offset;
            for (int y = 0; y < board.Height; y++)
            {
                for (int x = 0; x < board.Width; x++)
                {
                    var cell = board.At(x, y);
                    hash = Mix(hash, (ulong)((int)cell.Piece + 1));
                    hash = Mix(hash, (ulong)((int)cell.PowerUp + 1));
                }
            }
            return hash;
        }

        static ulong Mix(ulong hash, ulong value)
        {
            hash ^= value & 0xFF;
            hash *= Prime;
            hash ^= (value >> 8) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 16) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 24) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 32) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 40) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 48) & 0xFF;
            hash *= Prime;
            hash ^= (value >> 56) & 0xFF;
            hash *= Prime;
            return hash;
        }
    }
}
