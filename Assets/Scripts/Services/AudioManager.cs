using UnityEngine;

namespace RubyRun3D.Services
{
    public sealed class AudioManager
    {
        readonly AudioSource effects;
        readonly SaveManager save;
        readonly AudioClip click;
        readonly AudioClip positive;
        readonly AudioClip impact;

        public AudioManager(AudioSource source, SaveManager saveManager)
        {
            effects = source;
            save = saveManager;
            click = CreateTone("Click", 520, 0.07f);
            positive = CreateTone("Positive", 820, 0.14f);
            impact = CreateTone("Impact", 130, 0.16f);
        }

        public void PlayClick() => Play(click, 0.35f);
        public void PlayPositive() => Play(positive, 0.5f);
        public void PlayImpact() => Play(impact, 0.55f);
        public void Vibrate() { if (save.Data.vibration) Handheld.Vibrate(); }
        void Play(AudioClip clip, float volume) { if (save.Data.sound) effects.PlayOneShot(clip, volume); }

        static AudioClip CreateTone(string name, float frequency, float duration)
        {
            const int rate = 22050;
            var samples = new float[Mathf.CeilToInt(rate * duration)];
            for (var i = 0; i < samples.Length; i++)
            {
                var fade = 1f - (float)i / samples.Length;
                samples[i] = Mathf.Sin(2 * Mathf.PI * frequency * i / rate) * fade * 0.25f;
            }
            var clip = AudioClip.Create(name, samples.Length, 1, rate, false);
            clip.SetData(samples, 0);
            return clip;
        }
    }
}
