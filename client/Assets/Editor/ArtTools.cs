using System.Collections.Generic;
using System.Text;
using UnityEditor;
using UnityEngine;
using Shazdeh.Game;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// The art side of the menu: what is still missing, and a cache reset after an import.
    ///
    /// The authoritative check is `python3 tools/art/art.py --check` (it also validates sizes and alpha
    /// in the PNG headers, which the editor does not need to redo). This exists so an artist working
    /// inside Unity can see progress without opening a terminal.
    /// </summary>
    public static class ArtTools
    {
        [MenuItem("کاخ شازده/Report missing art")]
        public static void ReportMissing()
        {
            ArtLibrary.ResetCache();

            var missingRequired = new List<string>();
            foreach (var entry in ArtCatalog.Required())
            {
                if (!ArtLibrary.Has(entry.Id)) missingRequired.Add(entry.Id + " (" + entry.Width + "x" + entry.Height + ")");
            }

            int present = 0;
            var byGroup = new Dictionary<string, int>();
            for (int i = 0; i < ArtCatalog.All.Length; i++)
            {
                var entry = ArtCatalog.All[i];
                if (ArtLibrary.Has(entry.Id)) present++;

                byGroup.TryGetValue(entry.Group, out int count);
                byGroup[entry.Group] = count + 1;
            }

            var sb = new StringBuilder();
            sb.Append("[art] ").Append(present).Append(" of ").Append(ArtCatalog.Count).Append(" sprites present. Groups: ");
            foreach (var pair in byGroup) sb.Append(pair.Key).Append('=').Append(pair.Value).Append(' ');
            Debug.Log(sb.ToString());

            if (missingRequired.Count == 0)
            {
                Debug.Log("[art] every required sprite is present — the release gate (art.py --check --strict) would pass.");
                return;
            }

            Debug.LogWarning("[art] " + missingRequired.Count + " required sprite(s) still missing:\n  " +
                             string.Join("\n  ", missingRequired.ToArray()) +
                             "\nThe game draws token placeholders for these (docs/art.md).");
        }

        [MenuItem("کاخ شازده/Reload art cache")]
        public static void ReloadArt()
        {
            ArtLibrary.ResetCache();
            Debug.Log("[art] sprite cache cleared; the next frame will reload whatever exists.");
        }
    }
}
