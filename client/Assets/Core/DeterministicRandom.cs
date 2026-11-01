using System.Collections.Generic;
using System.Text;

namespace Shazdeh.Core
{
    /// <summary>
    /// xorshift64* — the one random source in the game.
    ///
    /// It is deliberately not <c>System.Random</c>: System.Random's algorithm is not part of the
    /// .NET contract, it changed between runtimes, and the same seed must produce the same board on
    /// the client, on the server that re-validates a win, and in the tests. This is a fixed, tiny
    /// algorithm with a published sequence, so a replay is reproducible years from now.
    ///
    /// Contract: same seed + same call order = same numbers. Never share one instance between
    /// threads, and never call it from the view layer.
    /// </summary>
    public sealed class DeterministicRandom
    {
        const ulong FallbackSeed = 0x9E3779B97F4A7C15UL;

        ulong _state;

        public DeterministicRandom(ulong seed)
        {
            _state = seed == 0UL ? FallbackSeed : seed;
        }

        public ulong State => _state;

        public ulong NextULong()
        {
            ulong x = _state;
            x ^= x >> 12;
            x ^= x << 25;
            x ^= x >> 27;
            _state = x;
            return x * 2685821657736338717UL;
        }

        /// <summary>Uniform in [0, maxExclusive). Returns 0 for maxExclusive &lt;= 0.</summary>
        public int Next(int maxExclusive)
        {
            if (maxExclusive <= 0) return 0;
            return (int)(NextULong() % (ulong)maxExclusive);
        }

        /// <summary>Uniform in [minInclusive, maxExclusive).</summary>
        public int NextRange(int minInclusive, int maxExclusive)
        {
            if (maxExclusive <= minInclusive) return minInclusive;
            return minInclusive + Next(maxExclusive - minInclusive);
        }

        public float Next01() => (NextULong() >> 40) / (float)(1UL << 24);

        public T Pick<T>(IList<T> items)
        {
            if (items == null || items.Count == 0) return default(T);
            return items[Next(items.Count)];
        }

        /// <summary>Fisher-Yates, in place, deterministic.</summary>
        public void Shuffle<T>(IList<T> items)
        {
            if (items == null) return;
            for (int i = items.Count - 1; i > 0; i--)
            {
                int j = Next(i + 1);
                T tmp = items[i];
                items[i] = items[j];
                items[j] = tmp;
            }
        }

        public string StateHex()
        {
            var sb = new StringBuilder(16);
            sb.Append(_state.ToString("x16"));
            return sb.ToString();
        }
    }
}
