using System;

namespace Shazdeh.Core
{
    /// <summary>
    /// Five lives, one back every 30 minutes, cap raised by a pass later.
    /// Refill is computed from a timestamp, never scheduled: no timers to miss, no job to run, and the
    /// same code works after the app has been closed for two days.
    /// </summary>
    public sealed class Lives
    {
        public const int RefillSeconds = 30 * 60;
        public const int DefaultMax = 5;

        readonly SaveData _data;
        readonly IClock _clock;

        public Lives(SaveData data, IClock clock)
        {
            _data = data;
            _clock = clock;
            if (_data.maxLives < 1) _data.maxLives = DefaultMax;
            if (_data.lives > _data.maxLives) _data.lives = _data.maxLives;
            if (_data.lives < 0) _data.lives = 0;
        }

        public int Max => _data.maxLives;

        /// <summary>Current lives, after materialising any refill that is due. Call it; it is cheap.</summary>
        public int Current
        {
            get
            {
                Refresh();
                return _data.lives;
            }
        }

        public bool IsFull => Current >= Max;

        public int NextRefillInSeconds
        {
            get
            {
                Refresh();
                if (_data.lives >= _data.maxLives) return 0;
                long elapsed = _clock.UtcNowUnix - _data.livesUpdatedAtUnix;
                long remaining = RefillSeconds - elapsed % RefillSeconds;
                if (remaining <= 0) remaining = RefillSeconds;
                return (int)Math.Min(int.MaxValue, remaining);
            }
        }

        /// <summary>Applies every refill earned since the last write. Returns how many were restored.</summary>
        public int Refresh()
        {
            if (_data.lives >= _data.maxLives)
            {
                // keep the timestamp current so the next lost life starts a fresh countdown
                _data.livesUpdatedAtUnix = _clock.UtcNowUnix;
                return 0;
            }

            long elapsed = _clock.UtcNowUnix - _data.livesUpdatedAtUnix;
            if (elapsed <= 0) return 0;

            long gained = elapsed / RefillSeconds;
            if (gained <= 0) return 0;

            int before = _data.lives;
            long restored = Math.Min(gained, _data.maxLives - _data.lives);
            _data.lives += (int)restored;
            _data.livesUpdatedAtUnix += restored * RefillSeconds;

            if (_data.lives >= _data.maxLives) _data.livesUpdatedAtUnix = _clock.UtcNowUnix;

            return _data.lives - before;
        }

        /// <summary>Spends one life. Refills first, so a life that came back while reading is not lost.</summary>
        public bool TrySpend()
        {
            Refresh();
            if (_data.lives <= 0) return false;

            if (_data.lives == _data.maxLives)
                _data.livesUpdatedAtUnix = _clock.UtcNowUnix; // start the countdown for the one being spent

            _data.lives--;
            return true;
        }

        public void Grant(int amount)
        {
            if (amount <= 0) return;
            _data.lives = Math.Min(_data.maxLives, _data.lives + amount);
        }

        public void BuyRefill(int amount, bool payCoins, Wallet wallet, long coinPrice)
        {
            if (amount <= 0) return;
            if (payCoins && wallet != null && coinPrice > 0)
            {
                if (!wallet.TrySpendCoins(coinPrice)) return;
            }
            Grant(amount);
        }
    }
}
