using System.Collections.Generic;
using Newtonsoft.Json;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    /// <summary>Chapter meta (districts, tasks, chests) → models. Same contract as LevelParser:
    /// errors are returned, never thrown.</summary>
    public static class DistrictParser
    {
        public static ChapterMeta Parse(string json, List<string> errors)
        {
            if (errors == null) errors = new List<string>();
            if (string.IsNullOrEmpty(json))
            {
                errors.Add("chapter meta is empty");
                return null;
            }

            ChapterJson dto;
            try
            {
                dto = JsonConvert.DeserializeObject<ChapterJson>(json);
            }
            catch (JsonException ex)
            {
                errors.Add("invalid chapter meta json: " + ex.Message);
                return null;
            }

            if (dto == null || dto.districts == null)
            {
                errors.Add("chapter meta has no districts");
                return null;
            }

            var meta = new ChapterMeta { Chapter = string.IsNullOrEmpty(dto.chapter) ? "ch01" : dto.chapter };

            for (int d = 0; d < dto.districts.Length; d++)
            {
                var source = dto.districts[d];
                var district = new DistrictDefinition
                {
                    Id = source.id,
                    Title = source.title,
                    TitleEn = string.IsNullOrEmpty(source.title_en) ? source.id : source.title_en
                };

                if (source.tasks != null)
                {
                    for (int t = 0; t < source.tasks.Length; t++)
                    {
                        var task = source.tasks[t];
                        district.Tasks.Add(new TaskDefinition
                        {
                            Key = task.key,
                            Title = task.title,
                            TitleEn = string.IsNullOrEmpty(task.title_en) ? task.key : task.title_en,
                            BuildAsset = task.build_asset,
                            PotionCost = task.potion_cost
                        });
                    }
                }

                if (source.chest != null)
                    district.Chest = new RewardBundle(source.chest.coins, source.chest.potions);

                meta.Districts.Add(district);
            }

            return meta;
        }

        public static List<string> Validate(ChapterMeta meta)
        {
            var errors = new List<string>();
            if (meta == null)
            {
                errors.Add("chapter meta is null");
                return errors;
            }

            if (meta.Districts.Count == 0) errors.Add("chapter has no districts");

            var districtIds = new HashSet<string>();
            var taskKeys = new HashSet<string>();

            for (int d = 0; d < meta.Districts.Count; d++)
            {
                var district = meta.Districts[d];
                if (string.IsNullOrEmpty(district.Id)) errors.Add("district " + d + " has no id");
                else if (!districtIds.Add(district.Id)) errors.Add("duplicate district id " + district.Id);

                if (district.Tasks.Count == 0)
                    errors.Add(district.Id + ": no tasks");

                for (int t = 0; t < district.Tasks.Count; t++)
                {
                    var task = district.Tasks[t];
                    if (string.IsNullOrEmpty(task.Key))
                        errors.Add(district.Id + ": task " + t + " has no key");
                    else if (!taskKeys.Add(task.Key))
                        errors.Add("duplicate task key " + task.Key);

                    if (task.PotionCost <= 0)
                        errors.Add(district.Id + ": task " + task.Key + " must cost more than 0 potions");
                    if (task.PotionCost > 500)
                        errors.Add(district.Id + ": task " + task.Key + " costs more than a district should");
                    if (string.IsNullOrEmpty(task.BuildAsset))
                        errors.Add(district.Id + ": task " + task.Key + " has no build asset");
                }

                if (district.Chest.Coins < 0 || district.Chest.Potions < 0)
                    errors.Add(district.Id + ": negative chest reward");
                if (district.Chest.IsEmpty)
                    errors.Add(district.Id + ": empty chest");
            }

            return errors;
        }
    }
}
