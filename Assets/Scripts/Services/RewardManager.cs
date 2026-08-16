using System;

namespace RubyRun3D.Services
{
    public sealed class RewardManager
    {
        static readonly int[] Rewards={100,150,200,250,300,400,650};readonly SaveManager save;
        public RewardManager(SaveManager manager)=>save=manager;
        public bool CanClaim(out string reason)
        {
            var now=DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            if(now+300<save.Data.lastObservedUtc){reason="Device clock moved backwards";return false;}
            save.Data.lastObservedUtc=Math.Max(now,save.Data.lastObservedUtc);
            reason="";return save.Data.lastDailyClaimUtc==0||now-save.Data.lastDailyClaimUtc>=86400;
        }
        public int Claim()
        {
            if(!CanClaim(out _))return 0;var reward=Rewards[save.Data.dailyDay];save.Data.coins+=reward;
            save.Data.dailyDay=(save.Data.dailyDay+1)%7;save.Data.lastDailyClaimUtc=DateTimeOffset.UtcNow.ToUnixTimeSeconds();save.Save();return reward;
        }
    }
}
