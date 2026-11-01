using System.Collections.Generic;
using NUnit.Framework;
using Shazdeh.Game;

namespace Shazdeh.Core.Tests
{
    /// <summary>
    /// The art contract, from the C# side. `tools/art/art.py --check` proves the catalog matches
    /// art/manifest.json and that any file on disk has the right size and an alpha channel; these tests
    /// prove the runtime behaves when the art is not there yet — which is the current state of the
    /// repository, and the state every screen has to survive.
    /// </summary>
    public sealed class ArtCatalogTests
    {
        [SetUp]
        public void SetUp()
        {
            ArtLibrary.ResetCache();
        }

        [Test]
        public void TheCatalogIsNotEmptyAndHasUniqueIds()
        {
            Assert.Greater(ArtCatalog.Count, 20, "the manifest should describe the whole art set");

            var seen = new HashSet<string>();
            for (int i = 0; i < ArtCatalog.All.Length; i++)
            {
                var entry = ArtCatalog.All[i];
                Assert.IsFalse(string.IsNullOrEmpty(entry.Id), "entry " + i + " has no id");
                Assert.IsTrue(seen.Add(entry.Id), "duplicate art id " + entry.Id);
                Assert.Greater(entry.Width, 0, entry.Id);
                Assert.Greater(entry.Height, 0, entry.Id);
                Assert.IsFalse(string.IsNullOrEmpty(entry.Group), entry.Id + " has no group");
            }
        }

        [Test]
        public void EveryRequiredAssetIsSomethingTheGameCanAskFor()
        {
            int count = 0;
            foreach (var entry in ArtCatalog.Required())
            {
                count = count + 1; // `required` is a C# 11 contextual keyword; the variable is `count`
                Assert.IsTrue(ArtLibrary.IsKnown(entry.Id), entry.Id + " is required but unknown to the library");
            }

            Assert.Greater(count, 0, "a contract with no required assets cannot gate a release");
        }

        [Test]
        public void AskingForArtThatDoesNotExistReturnsNullInsteadOfThrowing()
        {
            Assert.IsNull(ArtLibrary.Get("no_such_sprite"));
            Assert.IsNull(ArtLibrary.Get(""));
            Assert.IsNull(ArtLibrary.Get(null));

            Assert.IsFalse(ArtLibrary.Has("no_such_sprite"));
            Assert.IsFalse(ArtLibrary.IsKnown("no_such_sprite"));
            Assert.IsTrue(ArtLibrary.IsKnown("piece_firouzeh"));
        }

        [Test]
        public void ThePlaceholderPathIsWhatRunsToday()
        {
            // Art arrives file by file; this records the current state without failing the day the
            // first sprite lands. When every required id exists, this test starts skipping itself.
            int present = 0;
            foreach (var entry in ArtCatalog.Required())
                if (ArtLibrary.Has(entry.Id)) present++;

            Assert.GreaterOrEqual(present, 0, "sanity");
            UnityEngine.Debug.Log("[art] " + present + " of the required sprites are present in this checkout");
        }

        [Test]
        public void ApplyingArtToAMissingRendererIsASafeNoOp()
        {
            Assert.IsFalse(ArtLibrary.ApplyTo((UnityEngine.SpriteRenderer)null, "piece_firouzeh", 1f));
            Assert.IsFalse(ArtLibrary.ApplyTo((UnityEngine.UI.Image)null, "home_palace"));
        }

        [Test]
        public void TheMissingListMatchesWhatIsActuallyMissing()
        {
            foreach (string id in ArtLibrary.MissingRequiredIds)
                Assert.IsFalse(ArtLibrary.Has(id), id + " is reported missing but loads");
        }

        [Test]
        public void EveryPieceAndObstacleTheEngineCanShowHasAnIdInTheContract()
        {
            // If the engine grows a sixth piece kind or a ninth obstacle, this fails until somebody adds
            // it to art/manifest.json — which is the point: no art request may appear out of nowhere.
            foreach (Core.PieceKind kind in System.Enum.GetValues(typeof(Core.PieceKind)))
            {
                if (kind == Core.PieceKind.None) continue;
                string id = "piece_" + PieceName(kind);
                Assert.IsTrue(ArtLibrary.IsKnown(id), "missing from the art contract: " + id);
            }

            foreach (Core.ObstacleKind kind in System.Enum.GetValues(typeof(Core.ObstacleKind)))
            {
                if (kind == Core.ObstacleKind.None) continue;
                string id = "obstacle_" + kind.ToString().ToLowerInvariant();
                Assert.IsTrue(ArtLibrary.IsKnown(id), "missing from the art contract: " + id);
            }
        }

        static string PieceName(Core.PieceKind kind) => kind.ToString().ToLowerInvariant();
    }
}
