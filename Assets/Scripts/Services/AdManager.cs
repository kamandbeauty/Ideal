using System;
using UnityEngine;

namespace RubyRun3D.Services
{
    public interface IRewardedAdProvider
    {
        bool IsReady(string placement);
        void Show(string placement, Action completed, Action<string> failed);
    }

    public sealed class AdManager
    {
        IRewardedAdProvider provider;
        public bool Enabled { get; private set; }
        public event Action AvailabilityChanged;

        public void ConfigureReviewedProvider(IRewardedAdProvider reviewedProvider, bool consentAllowsAds)
        {
            provider = consentAllowsAds ? reviewedProvider : null;
            Enabled = provider != null;
            AvailabilityChanged?.Invoke();
        }

        public bool IsRewardedAvailable(string placement) => Enabled && provider?.IsReady(placement) == true;

        public bool ShowRewarded(string placement, Action verifiedReward)
        {
            if (!IsRewardedAvailable(placement)) return false;
            provider.Show(placement, verifiedReward, reason => Debug.LogWarning($"Rewarded ad failed: {reason}"));
            return true;
        }
    }
}
