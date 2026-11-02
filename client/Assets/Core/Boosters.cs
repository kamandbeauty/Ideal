using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// What the five boosters cost, and how many a player may hold.
    ///
    /// The prices are tuned to *this* game's rewards, not copied: a level pays 10 coins on a first
    /// clear, so a booster at 200 would be twenty levels of saving and at 40 it is four. The original's
    /// shop is priced against the original's economy; copying the number without the economy is how a
    /// rebuild ends up with a shop nobody can use.
    /// </summary>
    public static class BoosterCatalog
    {
        /// <summary>One slot per <see cref="BoosterKind"/>, in enum order.</summary>
        public const int Slots = 5;

        /// <summary>A fresh save starts able to feel each booster once.</summary>
        public const int StartOwned = 1;

        /// <summary>The count a chip can show without re-laying out.</summary>
        public const int MaxOwned = 9;

        public static int Price(BoosterKind kind)
        {
            switch (kind)
            {
                case BoosterKind.Mallet: return 40;      // one cell: cheapest, for the "just this one" moment
                case BoosterKind.Ram: return 60;         // a row
                case BoosterKind.Auger: return 60;       // a column
                case BoosterKind.Whirlwind: return 80;   // a shuffle, when the board is dead
                case BoosterKind.Falcon: return 100;     // three blasts: the strongest, the dearest
                default: return 40;
            }
        }

        public static string Name(BoosterKind kind)
        {
            switch (kind)
            {
                case BoosterKind.Mallet: return "پتک";
                case BoosterKind.Ram: return "قوچ";
                case BoosterKind.Auger: return "مته";
                case BoosterKind.Whirlwind: return "گردباد";
                case BoosterKind.Falcon: return "شاهین";
                default: return "بوستر";
            }
        }
    }

    /// <summary>
    /// The player's booster counts, on top of the save.
    ///
    /// Same shape as <see cref="Wallet"/>: the rules live here and are tested here, the save only holds
    /// the numbers, and nothing goes below zero. The list in the save is padded on construction, so a
    /// v1 save (which has no list at all) and a save someone hand-edited both become usable instead of
    /// throwing.
    /// </summary>
    public sealed class BoosterBag
    {
        readonly SaveData _data;

        public BoosterBag(SaveData data)
        {
            _data = data;
            Normalise();
        }

        public int Count(BoosterKind kind)
        {
            int index = (int)kind;
            if (index < 0 || index >= BoosterCatalog.Slots) return 0;
            return _data.boosters[index];
        }

        public bool Has(BoosterKind kind) => Count(kind) > 0;

        /// <summary>All-or-nothing, like every other purchase in the game.</summary>
        public bool TryConsume(BoosterKind kind)
        {
            int index = (int)kind;
            if (index < 0 || index >= BoosterCatalog.Slots) return false;
            if (_data.boosters[index] <= 0) return false;

            _data.boosters[index] = _data.boosters[index] - 1;
            return true;
        }

        /// <summary>Gives one back: used when the board refuses the move the booster asked for.</summary>
        public void Grant(BoosterKind kind, int amount = 1)
        {
            int index = (int)kind;
            if (index < 0 || index >= BoosterCatalog.Slots || amount <= 0) return;

            int next = _data.boosters[index] + amount;
            _data.boosters[index] = next > BoosterCatalog.MaxOwned ? BoosterCatalog.MaxOwned : next;
        }

        /// <summary>Buys `quantity` at the catalog price. Coins are spent only if the whole order fits.</summary>
        public bool Buy(BoosterKind kind, Wallet wallet, int quantity = 1)
        {
            if (wallet == null || quantity <= 0) return false;

            int index = (int)kind;
            if (index < 0 || index >= BoosterCatalog.Slots) return false;

            int room = BoosterCatalog.MaxOwned - _data.boosters[index];
            if (room <= 0) return false;
            if (quantity > room) quantity = room;

            long total = (long)BoosterCatalog.Price(kind) * quantity;
            if (!wallet.CanAffordCoins(total)) return false;
            if (!wallet.TrySpendCoins(total)) return false;

            _data.boosters[index] = _data.boosters[index] + quantity;
            return true;
        }

        /// <summary>Total owned, for the "you have N boosters" line on a shop screen.</summary>
        public int Total
        {
            get
            {
                int total = 0;
                for (int i = 0; i < BoosterCatalog.Slots; i++) total += _data.boosters[i];
                return total;
            }
        }

        void Normalise()
        {
            if (_data.boosters == null) _data.boosters = new List<int>(BoosterCatalog.Slots);

            while (_data.boosters.Count < BoosterCatalog.Slots) _data.boosters.Add(0);
            while (_data.boosters.Count > BoosterCatalog.Slots) _data.boosters.RemoveAt(_data.boosters.Count - 1);

            for (int i = 0; i < _data.boosters.Count; i++)
            {
                if (_data.boosters[i] < 0) _data.boosters[i] = 0;
                if (_data.boosters[i] > BoosterCatalog.MaxOwned) _data.boosters[i] = BoosterCatalog.MaxOwned;
            }
        }
    }
}
