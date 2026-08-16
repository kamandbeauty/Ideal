using RubyRun3D.Data;
using UnityEngine;

namespace RubyRun3D.Services
{
    public static class PerformanceManager
    {
        public static void Apply(QualityProfile profile)
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            QualitySettings.SetQualityLevel((int)profile, true);
            var low = profile == QualityProfile.Low;
            QualitySettings.shadowDistance = low ? 18 : profile == QualityProfile.Medium ? 35 : 50;
            QualitySettings.lodBias = low ? 0.65f : profile == QualityProfile.Medium ? 1f : 1.4f;
            QualitySettings.globalTextureMipmapLimit = low ? 1 : 0;
        }
    }
}
