using UnityEngine;

namespace RubyRun3D.Services
{
    public enum UpgradeKind { RubyDamage,RubyHealth,ArmyDamage,ArmyCapacity }
    public sealed class UpgradeManager
    {
        readonly SaveManager save;
        public UpgradeManager(SaveManager manager)=>save=manager;
        public int Level(UpgradeKind kind)=>kind switch{UpgradeKind.RubyDamage=>save.Data.rubyDamageLevel,UpgradeKind.RubyHealth=>save.Data.rubyHealthLevel,UpgradeKind.ArmyDamage=>save.Data.armyDamageLevel,_=>save.Data.armyCapacityLevel};
        public int Price(UpgradeKind kind)=>Mathf.RoundToInt(80*Mathf.Pow(1.55f,Level(kind)-1));
        public float RubyDamage=>7+(save.Data.rubyDamageLevel-1)*1.8f;
        public float ArmyDamage=>4+(save.Data.armyDamageLevel-1)*.85f;
        public int ArmyCapacity=>80+(save.Data.armyCapacityLevel-1)*10;
        public float RubyHealth=>100+(save.Data.rubyHealthLevel-1)*15;
        public bool Purchase(UpgradeKind kind)
        {
            var price=Price(kind);if(save.Data.coins<price||Level(kind)>=20)return false;save.Data.coins-=price;
            switch(kind){case UpgradeKind.RubyDamage:save.Data.rubyDamageLevel++;break;case UpgradeKind.RubyHealth:save.Data.rubyHealthLevel++;break;case UpgradeKind.ArmyDamage:save.Data.armyDamageLevel++;break;case UpgradeKind.ArmyCapacity:save.Data.armyCapacityLevel++;break;}
            save.Save();return true;
        }
    }
}
