#if UNITY_EDITOR
using NUnit.Framework;
using RubyRun3D.Data;
using RubyRun3D.Services;
using UnityEngine;

namespace RubyRun3D.Tests
{
    public sealed class RubyRunEditModeTests
    {
        [TestCase(GateOperation.Multiply,2,10,20)]
        [TestCase(GateOperation.Multiply,3,10,30)]
        [TestCase(GateOperation.Add,10,10,20)]
        [TestCase(GateOperation.Add,20,10,30)]
        [TestCase(GateOperation.Subtract,3,10,7)]
        [TestCase(GateOperation.Subtract,10,10,0)]
        [TestCase(GateOperation.Divide,2,10,5)]
        public void GateOperationsAreCorrect(GateOperation operation,int value,int input,int expected)
        {
            var gate=ScriptableObject.CreateInstance<GateDefinition>();gate.operation=operation;gate.value=value;
            Assert.That(gate.Apply(input),Is.EqualTo(expected));Object.DestroyImmediate(gate);
        }

        [Test] public void AdManagerIsSafeWithoutProvider()
        {
            var ads=new AdManager();Assert.That(ads.IsRewardedAvailable("revive"),Is.False);
            Assert.That(ads.ShowRewarded("revive",()=>{}),Is.False);
        }

        [Test] public void UpgradePriceIncreasesMonotonically()
        {
            var definition=ScriptableObject.CreateInstance<UpgradeDefinition>();definition.basePrice=100;definition.priceMultiplier=1.5f;
            Assert.That(definition.PriceAt(2),Is.GreaterThan(definition.PriceAt(1)));Object.DestroyImmediate(definition);
        }
    }
}
#endif
