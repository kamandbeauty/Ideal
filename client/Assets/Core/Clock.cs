using System;

namespace Shazdeh.Core
{
    /// <summary>Injected time, so lives refill and save timestamps are testable without waiting.</summary>
    public interface IClock
    {
        long UtcNowUnix { get; }
    }

    public sealed class SystemClock : IClock
    {
        public long UtcNowUnix => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    }

    /// <summary>A clock the tests can move by hand.</summary>
    public sealed class ManualClock : IClock
    {
        long _now;

        public ManualClock(long startUnix = 1700000000L)
        {
            _now = startUnix;
        }

        public long UtcNowUnix => _now;

        public void Advance(long seconds)
        {
            _now += seconds;
        }
    }
}
