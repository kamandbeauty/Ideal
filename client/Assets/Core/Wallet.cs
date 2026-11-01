namespace Shazdeh.Core
{
    /// <summary>
    /// The two currencies, with the one rule that must never break: no balance goes negative.
    /// Offline it is the save's fields; when purchases arrive the server mirrors this class's rules,
    /// it does not replace them.
    /// </summary>
    public sealed class Wallet
    {
        public const long MaxBalance = 999999999L;

        readonly SaveData _data;

        public Wallet(SaveData data)
        {
            _data = data;
        }

        public long Coins => _data.coins;

        public long Potions => _data.potions;

        public bool CanAffordPotions(long amount) => amount >= 0 && _data.potions >= amount;

        public bool CanAffordCoins(long amount) => amount >= 0 && _data.coins >= amount;

        /// <summary>All-or-nothing: a task either costs its full price or is not built.</summary>
        public bool TrySpendPotions(long amount)
        {
            if (amount < 0) return false;
            if (_data.potions < amount) return false;
            _data.potions -= amount;
            return true;
        }

        public bool TrySpendCoins(long amount)
        {
            if (amount < 0) return false;
            if (_data.coins < amount) return false;
            _data.coins -= amount;
            return true;
        }

        public void Grant(long coins, long potions)
        {
            if (coins > 0) _data.coins = Clamp(_data.coins, coins);
            if (potions > 0) _data.potions = Clamp(_data.potions, potions);
        }

        public void Grant(RewardBundle reward) => Grant(reward.Coins, reward.Potions);

        static long Clamp(long balance, long delta)
        {
            if (delta >= MaxBalance - balance) return MaxBalance;
            return balance + delta;
        }
    }
}
