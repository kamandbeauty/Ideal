using System.Collections.Generic;
using System.IO;
using Shazdeh.Content;
using Shazdeh.Core;
using UnityEngine;

namespace Shazdeh.Game
{
    public interface ISaveStore
    {
        /// <summary>Never fails: a corrupt or missing save comes back as a new one, with the reason in errors.</summary>
        SaveData Load(List<string> errors);

        void Save(SaveData data);

        string Location { get; }
    }

    /// <summary>
    /// One JSON file in the app's private storage, written through a temp file and a backup copy.
    /// Offline this is the whole source of truth (ADR 0001). The file is plain text on purpose: a
    /// support ticket can ask for it, and a human can read it.
    /// </summary>
    public sealed class FileSaveStore : ISaveStore
    {
        const string FileName = "shazdeh-save.json";

        readonly IClock _clock;
        readonly string _path;
        readonly string _backupPath;
        readonly string _tempPath;

        public FileSaveStore(IClock clock, string directory = null)
        {
            _clock = clock ?? new SystemClock();
            string root = string.IsNullOrEmpty(directory) ? Application.persistentDataPath : directory;
            _path = Path.Combine(root, FileName);
            _backupPath = _path + ".bak";
            _tempPath = _path + ".tmp";
        }

        public string Location => _path;

        public SaveData Load(List<string> errors)
        {
            if (errors == null) errors = new List<string>();

            var primary = TryRead(_path, errors);
            if (primary != null) return primary;

            var backup = TryRead(_backupPath, errors);
            if (backup != null)
            {
                errors.Add("recovered from backup save");
                return backup;
            }

            var fresh = SaveCodec.NewSave(_clock);
            errors.Add("no save found, starting a new one");
            return fresh;
        }

        SaveData TryRead(string path, List<string> errors)
        {
            try
            {
                if (!File.Exists(path)) return null;
                string json = File.ReadAllText(path);
                var localErrors = new List<string>();
                var data = SaveCodec.Decode(json, _clock, localErrors);
                errors.AddRange(localErrors);

                // A file that had to be replaced or repaired is not this file's data. Returning null
                // lets Load fall through to the backup, and only a corrupt backup starts a new save.
                return localErrors.Count == 0 ? data : null;
            }
            catch (IOException ex)
            {
                errors.Add("could not read " + Path.GetFileName(path) + ": " + ex.Message);
                return null;
            }
            catch (System.UnauthorizedAccessException ex)
            {
                errors.Add("no permission to read " + Path.GetFileName(path) + ": " + ex.Message);
                return null;
            }
        }

        public void Save(SaveData data)
        {
            if (data == null) return;

            data.version = SaveData.CurrentVersion;
            data.updatedAtUnix = _clock.UtcNowUnix;

            string json = SaveCodec.Encode(data);
            try
            {
                File.WriteAllText(_tempPath, json);

                if (File.Exists(_path))
                {
                    File.Copy(_path, _backupPath, true);
                    File.Delete(_path);
                }

                File.Move(_tempPath, _path);
            }
            catch (IOException ex)
            {
                // Never let a failed write take the session down; the player keeps playing, the save
                // is retried on the next change and the failure is visible in the log.
                Debug.LogError("save failed: " + ex.Message + " (" + _path + ")");
            }
        }
    }
}
