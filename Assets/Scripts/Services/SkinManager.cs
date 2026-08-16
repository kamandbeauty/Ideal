using System.Collections.Generic;
using UnityEngine;

namespace RubyRun3D.Services
{
    public readonly struct Skin
    {
        public readonly string Id,Name;public readonly int Price;public readonly Color Fur,Accent;
        public Skin(string id,string name,int price,Color fur,Color accent){Id=id;Name=name;Price=price;Fur=fur;Accent=accent;}
    }
    public sealed class SkinManager
    {
        readonly SaveManager save;
        public readonly IReadOnlyList<Skin> Skins=new[]{
            new Skin("classic","Ruby Classic",0,new Color(.92f,.28f,.1f),new Color(1f,.9f,.72f)),
            new Skin("ninja","Ruby Ninja",900,new Color(.12f,.14f,.2f),new Color(.55f,.25f,.9f)),
            new Skin("golden","Ruby Golden",2200,new Color(1f,.62f,.08f),new Color(1f,.95f,.55f)),
            new Skin("space","Ruby Space",3500,new Color(.25f,.22f,.62f),new Color(.25f,.9f,1f))};
        public SkinManager(SaveManager manager)=>save=manager;
        public Skin Selected{get{foreach(var skin in Skins)if(skin.Id==save.Data.selectedSkin)return skin;return Skins[0];}}
        public bool PurchaseOrEquip(Skin skin)
        {
            if(!save.Data.unlockedSkins.Contains(skin.Id)){if(save.Data.coins<skin.Price)return false;save.Data.coins-=skin.Price;save.Data.unlockedSkins.Add(skin.Id);}
            save.Data.selectedSkin=skin.Id;save.Save();return true;
        }
    }
}
